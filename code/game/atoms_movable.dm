/atom/movable
	layer = OBJ_LAYER
	appearance_flags = TILE_BOUND|PIXEL_SCALE

	// Movement related vars
	step_size = 32
	var/walking = NONE
	var/move_resist = MOVE_RESIST_DEFAULT
	var/move_force = MOVE_FORCE_DEFAULT
	var/pull_force = PULL_FORCE_DEFAULT

	// Misc
	var/last_move = null
	var/last_move_time = 0
	var/anchored = FALSE
	var/datum/thrownthing/throwing = null
	var/throw_speed = 2 //How many tiles to move per ds when being thrown. Float values are fully supported
	var/throw_range = 7
	var/mob/pulledby = null
	var/initial_language_holder = /datum/language_holder
	var/datum/language_holder/language_holder
	var/verb_say = "says"
	var/verb_ask = "asks"
	var/verb_exclaim = "exclaims"
	var/verb_whisper = "whispers"
	var/verb_yell = "yells"
	var/speech_span
	var/inertia_dir = 0
	var/atom/inertia_last_loc
	var/inertia_moving = 0
	var/inertia_next_move = 0
	var/inertia_move_delay = 5
	var/pass_flags = 0
	var/atom/movable/moving_from_pull		//attempt to resume grab after moving instead of before.
	var/list/client_mobs_in_contents // This contains all the client mobs within this container
	var/list/acted_explosions	//for explosion dodging
	var/datum/forced_movement/force_moving = null	//handled soley by forced_movement.dm
	var/movement_type = GROUND		//Incase you have multiple types, you automatically use the most useful one. IE: Skating on ice, flippers on water, flying over chasm/space, etc.
	var/atom/movable/pulling
	var/grab_state = 0
	var/throwforce = 0
	var/datum/component/orbiter/orbiting
	var/can_be_z_moved = TRUE
	var/zfalling = FALSE
	var/brotation = BOUNDS_SIMPLE_ROTATE

/atom/movable/Initialize()
	. = ..()
	update_bounds(olddir=NORTH, newdir=dir) // bounds assume north but some things arent north by default for some god knows reason

/atom/movable/proc/can_zFall(turf/source, levels = 1, turf/target, direction)
	if(!direction)
		direction = DOWN
	if(!source)
		source = get_turf(src)
		if(!source)
			return FALSE
	if(!target)
		target = get_step_multiz(source, direction)
		if(!target)
			return FALSE
	return !(movement_type & FLYING) && has_gravity(source) && !throwing

/atom/movable/proc/onZImpact(turf/T, levels)
	var/atom/highest = T
	for(var/i in T.contents)
		var/atom/A = i
		if(!A.density)
			continue
		if(isobj(A) || ismob(A))
			if(A.layer > highest.layer)
				highest = A
	INVOKE_ASYNC(src, .proc/SpinAnimation, 5, 2)
	throw_impact(highest)
	return TRUE

//For physical constraints to travelling up/down.
/atom/movable/proc/can_zTravel(turf/destination, direction)
	var/turf/T = get_turf(src)
	if(!T)
		return FALSE
	if(!direction)
		if(!destination)
			return FALSE
		direction = get_dir(T, destination)
	if(direction != UP && direction != DOWN)
		return FALSE
	if(!destination)
		destination = get_step_multiz(src, direction)
		if(!destination)
			return FALSE
	return T.zPassOut(src, direction, destination) && destination.zPassIn(src, direction, T)

/atom/movable/vv_edit_var(var_name, var_value)
	switch(var_name)
		if("x")
			var/turf/T = locate(var_value, y, z)
			if(T)
				forceMove(T)
				return TRUE
			return FALSE
		if("y")
			var/turf/T = locate(x, var_value, z)
			if(T)
				forceMove(T)
				return TRUE
			return FALSE
		if("z")
			var/turf/T = locate(x, y, var_value)
			if(T)
				forceMove(T)
				return TRUE
			return FALSE
		if("loc")
			if(istype(var_value, /atom))
				forceMove(var_value)
				return TRUE
			else if(isnull(var_value))
				moveToNullspace()
				return TRUE
			return FALSE
	return ..()

/atom/movable/proc/start_pulling(atom/movable/AM, state, force = move_force, supress_message = FALSE)
	if(QDELETED(AM))
		return FALSE
	if(!(AM.can_be_pulled(src, state, force)))
		return FALSE

	// If we're pulling something then drop what we're currently pulling and pull this instead.
	if(pulling)
		if(state == 0)
			stop_pulling()
			return FALSE
		// Are we trying to pull something we are already pulling? Then enter grab cycle and end.
		if(AM == pulling)
			setGrabState(state)
			if(istype(AM,/mob/living))
				var/mob/living/AMob = AM
				AMob.grabbedby(src)
			return TRUE
		stop_pulling()
	if(AM.pulledby)
		log_combat(AM, AM.pulledby, "pulled from", src)
		AM.pulledby.stop_pulling() //an object can't be pulled by two mobs at once.
	pulling = AM
	AM.pulledby = src
	setGrabState(state)
	if(ismob(AM))
		var/mob/M = AM
		log_combat(src, M, "grabbed", addition="passive grab")
		if(!supress_message)
			M.visible_message("<span class='warning'>[src] grabs [M] passively.</span>", \
				"<span class='danger'>[src] grabs you passively.</span>")
	return TRUE

/atom/movable/proc/stop_pulling()
	if(pulling)
		pulling.pulledby = null
		var/mob/living/ex_pulled = pulling
		pulling = null
		setGrabState(0)
		if(isliving(ex_pulled))
			var/mob/living/L = ex_pulled
			L.update_mobility()// mob gets up if it was lyng down in a chokehold

/atom/movable/proc/Move_Pulled(atom/A)
	if(!pulling)
		return
	if(pulling.anchored || pulling.move_resist > move_force || !pulling.Adjacent(src))
		stop_pulling()
		return
	if(isliving(pulling))
		var/mob/living/L = pulling
		if(L.buckled && L.buckled.buckle_prevents_pull) //if they're buckled to something that disallows pulling, prevent it
			stop_pulling()
			return
	if(A == loc && pulling.density)
		return
	if(!Process_Spacemove(get_dir(pulling.loc, A)))
		return
	step(pulling, get_dir(pulling.loc, A))
	return TRUE

/mob/living/Move_Pulled(atom/A)
	. = ..()
	if(!. || !isliving(A))
		return
	var/mob/living/L = A
	set_pull_offsets(L, grab_state)

/atom/movable/proc/check_pulling()
	if(pulling)
		var/atom/movable/pullee = pulling
		if(pullee && get_dist(src, pullee) > 1)
			stop_pulling()
			return
		if(!isturf(loc))
			stop_pulling()
			return
		if(pullee && !isturf(pullee.loc) && pullee.loc != loc) //to be removed once all code that changes an object's loc uses forceMove().
			log_game("DEBUG:[src]'s pull on [pullee] wasn't broken despite [pullee] being in [pullee.loc]. Pull stopped manually.")
			stop_pulling()
			return
		if(pulling.anchored || pulling.move_resist > move_force)
			stop_pulling()
			return

#define ANGLE_ADJUST 10
/atom/movable/proc/handle_pulled_movement()
	if(pulling.anchored)
		return FALSE
	var/distance = bounds_dist(src, pulling)
	if(distance > 32)
		return FALSE
	. = TRUE // Nothing beyond this stops the pulling
	if(distance < 8)
		return
	var/angle = get_deg(pulling, src)
	if((angle % 45) > 1) // We arent directly on a cardinal from the thing
		var/tempA = WRAP(angle, 0, 45)
		if(tempA >= 22.5)
			angle += min(ANGLE_ADJUST, 45-tempA)
		else
			angle -= min(ANGLE_ADJUST, tempA)
	angle = SIMPLIFY_DEGREES(angle)
	degstep(pulling, angle, distance-8)
#undef ANGLE_ADJUST

/atom/movable/Move(atom/newloc, direct, _step_x, _step_y)
	if(SEND_SIGNAL(src, COMSIG_MOVABLE_PRE_MOVE, newloc, direct, _step_x, _step_y) & COMPONENT_MOVABLE_BLOCK_PRE_MOVE)
		return FALSE

	var/atom/oldloc = loc

	. = ..()

	last_move = direct
	setDir(direct)
	if(.)
		Moved(oldloc, direct)
		if(pulling && !handle_pulled_movement()) //we were pulling a thing and didn't lose it during our move.
			stop_pulling()
		if(has_buckled_mobs() && !handle_buckled_mob_movement(loc, direct, step_x, step_y))
			return FALSE
	else
		walk(src, NONE)

//Called after a successful Move(). By this point, we've already moved
/atom/movable/proc/Moved(atom/OldLoc, Dir, Forced = FALSE)
	SEND_SIGNAL(src, COMSIG_MOVABLE_MOVED, OldLoc, Dir, Forced)
	if (!inertia_moving)
		inertia_next_move = world.time + inertia_move_delay
		newtonian_move(Dir)
	if (length(client_mobs_in_contents))
		update_parallax_contents()

	return TRUE

/atom/movable/Destroy(force)
	QDEL_NULL(proximity_monitor)
	QDEL_NULL(language_holder)

	unbuckle_all_mobs(force=1)

	. = ..()
	if(loc)
		//Restore air flow if we were blocking it (movables with ATMOS_PASS_PROC will need to do this manually if necessary)
		if(((CanAtmosPass == ATMOS_PASS_DENSITY && density) || CanAtmosPass == ATMOS_PASS_NO) && isturf(loc))
			CanAtmosPass = ATMOS_PASS_YES
			air_update_turf(TRUE)
		loc.handle_atom_del(src)
	for(var/atom/movable/AM in contents)
		qdel(AM)
	moveToNullspace()
	invisibility = INVISIBILITY_ABSTRACT
	if(pulledby)
		pulledby.stop_pulling()

	if(orbiting)
		orbiting.end_orbit(src)
		orbiting = null

// Make sure you know what you're doing if you call this, this is intended to only be called by byond directly.
// You probably want CanPass()
/atom/movable/Cross(atom/movable/AM)
	SEND_SIGNAL(src, COMSIG_MOVABLE_CROSS, AM)
	return CanPass(AM, AM.loc, TRUE)

//oldloc = old location on atom, inserted when forceMove is called and ONLY when forceMove is called!
/atom/movable/Crossed(atom/movable/AM, oldloc)
	SEND_SIGNAL(src, COMSIG_MOVABLE_CROSSED, AM)

/atom/movable/Uncross(atom/movable/AM, atom/newloc)
	. = ..()
	if(SEND_SIGNAL(src, COMSIG_MOVABLE_UNCROSS, AM) & COMPONENT_MOVABLE_BLOCK_UNCROSS)
		return FALSE
	if(isturf(newloc) && !CheckExit(AM, newloc))
		return FALSE

/atom/movable/Uncrossed(atom/movable/AM)
	SEND_SIGNAL(src, COMSIG_MOVABLE_UNCROSSED, AM)

/atom/movable/Bump(atom/A)
	if(!A)
		CRASH("Bump was called with no argument.")
	SEND_SIGNAL(src, COMSIG_MOVABLE_BUMP, A)
	. = ..()
	if(!QDELETED(throwing))
		throwing.hit_atom(A)
		. = TRUE
		if(QDELETED(A))
			return
	A.Bumped(src)

/atom/movable/setDir(direct)
	var/old_dir = dir
	. = ..()
	update_bounds(olddir=old_dir, newdir=direct)

// Unless you have some really weird rotation try to implement a generic version of your rotation here and make a flag for it
/atom/movable/proc/update_bounds(olddir, newdir)
	SEND_SIGNAL(src, COMSIG_MOVABLE_UPDATE_BOUNDS, args)

	if(bound_width == bound_height && !bound_x && !bound_y) // We're a square and have no offset
		return

	if(brotation & BOUNDS_SIMPLE_ROTATE)
		var/rot = SIMPLIFY_DEGREES(dir2angle(newdir)-dir2angle(olddir))
		for(var/i in 90 to rot step 90)
			var/tempwidth = bound_width
			var/eastgap = CEILING(bound_width, 32) - bound_width - bound_x

			bound_width = bound_height
			bound_height = tempwidth

			bound_x = bound_y
			bound_y = eastgap

/atom/movable/proc/forceMove(atom/destination, _step_x, _step_y)
	. = FALSE
	if(destination)
		. = doMove(destination, _step_x, _step_y)
	else
		CRASH("No valid destination passed into forceMove")

/atom/movable/proc/moveToNullspace()
	return doMove(null)

/atom/movable/proc/doMove(atom/destination, _step_x=0, _step_y=0)
	. = FALSE

	if(destination == loc && _step_x == step_x && _step_y == step_y) // Force move in place?
		Moved(loc, NONE, TRUE)
		return TRUE

	var/atom/oldloc = loc
	var/area/oldarea = get_area(oldloc)
	var/area/destarea = get_area(destination)
	var/list/old_bounds = bounds()

	loc = destination
	step_x = _step_x
	step_y = _step_y

	if(oldloc && oldloc != loc)
		oldloc.Exited(src, destination)
		if(oldarea && oldarea != destarea)
			oldarea.Exited(src, destination)

	var/list/new_bounds = bounds()

	for(var/i in old_bounds)
		if(i in new_bounds)
			continue
		var/atom/thing = i
		thing.Uncrossed(src)

	if(!loc) // I hope you know what you're doing
		return TRUE

	var/turf/oldturf = get_turf(oldloc)
	var/turf/destturf = get_turf(destination)
	var/oldz = (oldturf ? oldturf.z : null)
	var/newz = (destturf ? destturf.z : null)
	if(oldz != newz)
		onTransitZ(oldz, newz)

	destination.Entered(src, oldloc)
	if(destarea && oldarea != destarea)
		destarea.Entered(src, oldloc)

	for(var/i in new_bounds)
		if(i in old_bounds)
			continue
		var/atom/thing = i
		thing.Crossed(src, oldloc)

	Moved(oldloc, NONE, TRUE)
	return TRUE

/atom/movable/proc/onTransitZ(old_z,new_z)
	SEND_SIGNAL(src, COMSIG_MOVABLE_Z_CHANGED, old_z, new_z)
	for (var/item in src) // Notify contents of Z-transition. This can be overridden IF we know the items contents do not care.
		var/atom/movable/AM = item
		AM.onTransitZ(old_z,new_z)

/atom/movable/proc/setMovetype(newval)
	movement_type = newval

//Called whenever an object moves and by mobs when they attempt to move themselves through space
//And when an object or action applies a force on src, see newtonian_move() below
//Return 0 to have src start/keep drifting in a no-grav area and 1 to stop/not start drifting
//Mobs should return 1 if they should be able to move of their own volition, see client/Move() in mob_movement.dm
//movement_dir == 0 when stopping or any dir when trying to move
/atom/movable/proc/Process_Spacemove(movement_dir = 0)
	if(has_gravity(src))
		return 1

	if(pulledby)
		return 1

	if(throwing)
		return 1

	if(!isturf(loc))
		return 1

	if(locate(/obj/structure/lattice) in range(1, get_turf(src))) //Not realistic but makes pushing things in space easier
		return 1

	return 0


/atom/movable/proc/newtonian_move(direction) //Only moves the object if it's under no gravity
	if(!loc || Process_Spacemove(0))
		inertia_dir = 0
		return 0

	inertia_dir = direction
	if(!direction)
		return 1
	inertia_last_loc = loc
	SSspacedrift.processing[src] = src
	return 1

/atom/movable/proc/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	set waitfor = 0
	SEND_SIGNAL(src, COMSIG_MOVABLE_IMPACT, hit_atom, throwingdatum)
	return hit_atom.hitby(src, throwingdatum=throwingdatum)

/atom/movable/hitby(atom/movable/AM, skipcatch, hitpush = TRUE, blocked, datum/thrownthing/throwingdatum)
	if(!anchored && hitpush && (!throwingdatum || (throwingdatum.force >= (move_resist * MOVE_FORCE_PUSH_RATIO))))
		step(src, AM.dir)
	..()

/atom/movable/proc/safe_throw_at(atom/target, range, speed, mob/thrower, spin = TRUE, diagonals_first = FALSE, datum/callback/callback, force = MOVE_FORCE_STRONG, params)
	if((force < (move_resist * MOVE_FORCE_THROW_RATIO)) || (move_resist == INFINITY))
		return
	return throw_at(target, range, speed, thrower, spin, diagonals_first, callback, force, params)

/atom/movable/proc/throw_at(atom/target, range, speed, mob/thrower, spin = TRUE, diagonals_first = FALSE, datum/callback/callback, force = MOVE_FORCE_STRONG, params) //If this returns FALSE then callback will not be called.
	. = FALSE
	if (!target || speed <= 0)
		return

	if(SEND_SIGNAL(src, COMSIG_MOVABLE_PRE_THROW, args) & COMPONENT_CANCEL_THROW)
		return

	if (pulledby)
		pulledby.stop_pulling()

	//They are moving! Wouldn't it be cool if we calculated their momentum and added it to the throw?
	if (thrower && thrower.last_move && thrower.client && thrower.client.move_delay >= world.time + world.tick_lag*2)
		var/user_momentum = thrower.step_size
		if (!user_momentum) //no movement_delay, this means they move once per byond tick, lets calculate from that instead.
			user_momentum = world.tick_lag

		user_momentum = 1 / user_momentum // convert from ds to the tiles per ds that throw_at uses.

		if (get_dir(thrower, target) & last_move)
			user_momentum = user_momentum //basically a noop, but needed
		else if (get_dir(target, thrower) & last_move)
			user_momentum = -user_momentum //we are moving away from the target, lets slowdown the throw accordingly
		else
			user_momentum = 0


		if (user_momentum)
			//first lets add that momentum to range.
			range *= (user_momentum / speed) + 1
			//then lets add it to speed
			speed += user_momentum
			if (speed <= 0)
				return//no throw speed, the user was moving too fast.

	. = TRUE // No failure conditions past this point.

	var/datum/thrownthing/TT = new()
	TT.thrownthing = src
	TT.target = target
	TT.target_turf = get_turf(target)
	TT.init_dir = get_dir(src, target)
	TT.maxrange = range
	TT.speed = speed
	TT.thrower = thrower
	TT.diagonals_first = diagonals_first
	TT.force = force
	TT.callback = callback
	if(thrower && params)
		var/list/calculated = calculate_projectile_angle_and_pixel_offsets(thrower, params)
		TT.angle = calculated[1]
		TT.sx = calculated[2]
		TT.sy = calculated[3]
	if(!QDELETED(thrower))
		TT.target_zone = thrower.zone_selected

	var/dist_x = abs(target.x - src.x)
	var/dist_y = abs(target.y - src.y)
	var/dx = (target.x > src.x) ? EAST : WEST
	var/dy = (target.y > src.y) ? NORTH : SOUTH

	if (dist_x == dist_y)
		TT.pure_diagonal = 1

	else if(dist_x <= dist_y)
		var/olddist_x = dist_x
		var/olddx = dx
		dist_x = dist_y
		dist_y = olddist_x
		dx = dy
		dy = olddx
	TT.dist_x = dist_x
	TT.dist_y = dist_y
	TT.dx = dx
	TT.dy = dy
	TT.diagonal_error = dist_x/2 - dist_y
	TT.start_time = world.time

	if(pulledby)
		pulledby.stop_pulling()

	throwing = TT
	if(spin)
		SpinAnimation(5, 1)

	SEND_SIGNAL(src, COMSIG_MOVABLE_POST_THROW, TT, spin)
	SSthrowing.processing[src] = TT
	if (SSthrowing.state == SS_PAUSED && length(SSthrowing.currentrun))
		SSthrowing.currentrun[src] = TT
	TT.tick()

/atom/movable/proc/handle_buckled_mob_movement(newloc, direct, _step_x, _step_y)
	for(var/m in buckled_mobs)
		var/mob/living/buckled_mob = m
		if(!buckled_mob.Move(newloc, direct, _step_x, _step_y))
			forceMove(buckled_mob.loc)
			last_move = buckled_mob.last_move
			inertia_dir = last_move
			buckled_mob.inertia_dir = last_move
			return 0
	return 1

/atom/movable/proc/force_pushed(atom/movable/pusher, force = MOVE_FORCE_DEFAULT, direction)
	return FALSE

/atom/movable/proc/force_push(atom/movable/AM, force = move_force, direction, silent = FALSE)
	. = AM.force_pushed(src, force, direction)
	if(!silent && .)
		visible_message("<span class='warning'>[src] forcefully pushes against [AM]!</span>", "<span class='warning'>You forcefully push against [AM]!</span>")

/atom/movable/proc/move_crush(atom/movable/AM, force = move_force, direction, silent = FALSE)
	. = AM.move_crushed(src, force, direction)
	if(!silent && .)
		visible_message("<span class='danger'>[src] crushes past [AM]!</span>", "<span class='danger'>You crush [AM]!</span>")

/atom/movable/proc/move_crushed(atom/movable/pusher, force = MOVE_FORCE_DEFAULT, direction)
	return FALSE

/atom/movable/CanPass(atom/movable/mover, turf/target)
	if(mover in buckled_mobs)
		return 1
	return ..()

// called when this atom is removed from a storage item, which is passed on as S. The loc variable is already set to the new destination before this is called.
/atom/movable/proc/on_exit_storage(datum/component/storage/concrete/S)
	return

// called when this atom is added into a storage item, which is passed on as S. The loc variable is already set to the storage item.
/atom/movable/proc/on_enter_storage(datum/component/storage/concrete/S)
	return

/atom/movable/proc/get_spacemove_backup()
	var/atom/movable/dense_object_backup
	for(var/A in orange(1, get_turf(src)))
		if(isarea(A))
			continue
		else if(isturf(A))
			var/turf/turf = A
			if(!turf.density)
				continue
			return turf
		else
			var/atom/movable/AM = A
			if(!AM.CanPass(src) || AM.density)
				if(AM.anchored)
					return AM
				dense_object_backup = AM
				break
	. = dense_object_backup

//called when a mob resists while inside a container that is itself inside something.
/atom/movable/proc/relay_container_resist(mob/living/user, obj/O)
	return


/atom/movable/proc/do_attack_animation(atom/A, visual_effect_icon, obj/item/used_item, no_effect)
	if(!no_effect && (visual_effect_icon || used_item))
		do_item_attack_animation(A, visual_effect_icon, used_item)

	if(A == src)
		return //don't do an animation if attacking self
	var/pixel_x_diff = 0
	var/pixel_y_diff = 0

	var/direction = get_dir(src, A)
	if(direction & NORTH)
		pixel_y_diff = 8
	else if(direction & SOUTH)
		pixel_y_diff = -8

	if(direction & EAST)
		pixel_x_diff = 8
	else if(direction & WEST)
		pixel_x_diff = -8

	animate(src, pixel_x = pixel_x + pixel_x_diff, pixel_y = pixel_y + pixel_y_diff, time = 2)
	animate(src, pixel_x = pixel_x - pixel_x_diff, pixel_y = pixel_y - pixel_y_diff, time = 2)

/atom/movable/proc/do_item_attack_animation(atom/A, visual_effect_icon, obj/item/used_item)
	var/image/I
	if(visual_effect_icon)
		I = image('icons/effects/effects.dmi', A, visual_effect_icon, A.layer + 0.1)
	else if(used_item)
		I = image(icon = used_item, loc = A, layer = A.layer + 0.1)
		I.plane = GAME_PLANE

		// Scale the icon.
		I.transform *= 0.75
		// The icon should not rotate.
		I.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA

		// Set the direction of the icon animation.
		var/direction = get_dir(src, A)
		if(direction & NORTH)
			I.pixel_y = -16
		else if(direction & SOUTH)
			I.pixel_y = 16

		if(direction & EAST)
			I.pixel_x = -16
		else if(direction & WEST)
			I.pixel_x = 16

		if(!direction) // Attacked self?!
			I.pixel_z = 16

	if(!I)
		return

	flick_overlay(I, GLOB.clients, 5) // 5 ticks/half a second

	// And animate the attack!
	animate(I, alpha = 175, pixel_x = 0, pixel_y = 0, pixel_z = 0, time = 3)

/atom/movable/vv_get_dropdown()
	. = ..()
	. += "<option value='?_src_=holder;[HrefToken()];adminplayerobservefollow=[REF(src)]'>Follow</option>"
	. += "<option value='?_src_=holder;[HrefToken()];admingetmovable=[REF(src)]'>Get</option>"

/atom/movable/proc/ex_check(ex_id)
	if(!ex_id)
		return TRUE
	LAZYINITLIST(acted_explosions)
	if(ex_id in acted_explosions)
		return FALSE
	acted_explosions += ex_id
	return TRUE

//TODO: Better floating
/atom/movable/proc/float(on)
	if(throwing)
		return
	if(on && !(movement_type & FLOATING))
		animate(src, pixel_y = pixel_y + 2, time = 10, loop = -1)
		sleep(10)
		animate(src, pixel_y = pixel_y - 2, time = 10, loop = -1)
		setMovetype(movement_type | FLOATING)
	else if (!on && (movement_type & FLOATING))
		animate(src, pixel_y = initial(pixel_y), time = 10)
		setMovetype(movement_type & ~FLOATING)

/* Language procs */
/atom/movable/proc/get_language_holder(shadow=TRUE)
	if(language_holder)
		return language_holder
	else
		language_holder = new initial_language_holder(src)
		return language_holder

/atom/movable/proc/grant_language(datum/language/dt, body = FALSE)
	var/datum/language_holder/H = get_language_holder(!body)
	H.grant_language(dt, body)

/atom/movable/proc/grant_all_languages(omnitongue=FALSE)
	var/datum/language_holder/H = get_language_holder()
	H.grant_all_languages(omnitongue)

/atom/movable/proc/get_random_understood_language()
	var/datum/language_holder/H = get_language_holder()
	. = H.get_random_understood_language()

/atom/movable/proc/remove_language(datum/language/dt, body = FALSE)
	var/datum/language_holder/H = get_language_holder(!body)
	H.remove_language(dt, body)

/atom/movable/proc/remove_all_languages()
	var/datum/language_holder/H = get_language_holder()
	H.remove_all_languages()

/atom/movable/proc/has_language(datum/language/dt)
	var/datum/language_holder/H = get_language_holder()
	. = H.has_language(dt)

/atom/movable/proc/copy_known_languages_from(thing, replace=FALSE)
	var/datum/language_holder/H = get_language_holder()
	. = H.copy_known_languages_from(thing, replace)

// Whether an AM can speak in a language or not, independent of whether
// it KNOWS the language
/atom/movable/proc/could_speak_in_language(datum/language/dt)
	. = TRUE

/atom/movable/proc/can_speak_in_language(datum/language/dt)
	var/datum/language_holder/H = get_language_holder()

	if(!H.has_language(dt))
		return FALSE
	else if(H.omnitongue)
		return TRUE
	else if(could_speak_in_language(dt) && (!H.only_speaks_language || H.only_speaks_language == dt))
		return TRUE
	else
		return FALSE

/atom/movable/proc/get_default_language()
	// if no language is specified, and we want to say() something, which
	// language do we use?
	var/datum/language_holder/H = get_language_holder()

	if(H.selected_default_language)
		if(can_speak_in_language(H.selected_default_language))
			return H.selected_default_language
		else
			H.selected_default_language = null


	var/datum/language/chosen_langtype
	var/highest_priority

	for(var/lt in H.languages)
		var/datum/language/langtype = lt
		if(!can_speak_in_language(langtype))
			continue

		var/pri = initial(langtype.default_priority)
		if(!highest_priority || (pri > highest_priority))
			chosen_langtype = langtype
			highest_priority = pri

	H.selected_default_language = .
	. = chosen_langtype

/* End language procs */
/atom/movable/proc/ConveyorMove(movedir)
	set waitfor = FALSE
	if(!anchored && has_gravity())
		step(src, movedir)

//Returns an atom's power cell, if it has one. Overload for individual items.
/atom/movable/proc/get_cell()
	return

/atom/movable/proc/can_be_pulled(user, grab_state, force)
	if(src == user || !isturf(loc))
		return FALSE
	if(anchored || throwing)
		return FALSE
	if(force < (move_resist * MOVE_FORCE_PULL_RATIO))
		return FALSE
	return TRUE

/// Updates the grab state of the movable
/// This exists to act as a hook for behaviour
/atom/movable/proc/setGrabState(newstate)
	grab_state = newstate

/obj/item/proc/do_pickup_animation(atom/target)
	set waitfor = FALSE
	if(!istype(loc, /turf))
		return
	var/image/I = image(icon = src, loc = loc, layer = layer + 0.1)
	I.plane = GAME_PLANE
	I.transform *= 0.75
	I.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA
	var/turf/T = get_turf(src)
	var/direction
	var/to_x = 0
	var/to_y = 0

	if(!QDELETED(T) && !QDELETED(target))
		direction = get_dir(T, target)
	if(direction & NORTH)
		to_y = 32
	else if(direction & SOUTH)
		to_y = -32
	if(direction & EAST)
		to_x = 32
	else if(direction & WEST)
		to_x = -32
	if(!direction)
		to_y = 16
	flick_overlay(I, GLOB.clients, 6)
	var/matrix/M = new
	M.Turn(pick(-30, 30))
	animate(I, alpha = 175, pixel_x = to_x, pixel_y = to_y, time = 3, transform = M, easing = CUBIC_EASING)
	sleep(1)
	animate(I, alpha = 0, transform = matrix(), time = 1)
