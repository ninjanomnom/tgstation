/obj/singularity
	name = "gravitational singularity"
	desc = "A gravitational singularity."
	icon = 'icons/obj/singularity.dmi'
	icon_state = "singularity_s1"
	anchored = TRUE
	density = TRUE
	move_resist = INFINITY
	layer = MASSIVE_OBJ_LAYER
	light_range = 6
	appearance_flags = 0
	step_size = 1
	movement_type = FLOATING | UNSTOPPABLE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF | FREEZE_PROOF
	obj_flags = CAN_BE_HIT | DANGEROUS_POSSESSION
	var/current_size = 1
	var/allowed_size = 1
	var/contained = 1 //Are we going to move around?
	var/energy = 100 //How strong are we?
	var/dissipate = 1 //Do we lose energy over time?
	var/dissipate_delay = 10
	var/dissipate_track = 0
	var/dissipate_strength = 1 //How much energy do we lose?
	var/move_self = 1 //Do we move on our own?
	var/grav_pull = 4 //How many tiles out do we pull?
	var/event_chance = 10 //Prob for event each tick
	var/target = null //its target. moves towards the target if it has one
	/// The direction of failed moves
	var/last_failed_movement = 0
	/// The next time movement will be calculated
	var/next_movement_change = 0
	var/last_warning
	var/consumedSupermatter = 0 //If the singularity has eaten a supermatter shard and can go to stage six
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF | FREEZE_PROOF
	obj_flags = CAN_BE_HIT | DANGEROUS_POSSESSION

/obj/singularity/Initialize(mapload, starting_energy = 50)
	//CARN: admin-alert for chuckle-fuckery.
	admin_investigate_setup()

	src.energy = starting_energy
	. = ..()
	START_PROCESSING(SSobj, src)
	GLOB.poi_list |= src
	GLOB.singularities |= src
	for(var/obj/machinery/power/singularity_beacon/singubeacon in GLOB.machines)
		if(singubeacon.active)
			target = singubeacon
			break
	AddElement(/datum/element/bsa_blocker)
	RegisterSignal(src, COMSIG_ATOM_BSA_BEAM, .proc/bluespace_reaction)

/obj/singularity/Destroy()
	STOP_PROCESSING(SSobj, src)
	GLOB.poi_list.Remove(src)
	GLOB.singularities.Remove(src)
	return ..()

/obj/singularity/Move(atom/newloc, direct)
	. = ..()
	if(!.)
		last_failed_movement = direct
	else
		last_failed_movement = NONE

/obj/singularity/attack_hand(mob/user)
	consume(user)
	return TRUE

/obj/singularity/attack_paw(mob/user)
	consume(user)

/obj/singularity/attack_alien(mob/user)
	consume(user)

/obj/singularity/attack_animal(mob/user)
	consume(user)

/obj/singularity/attackby(obj/item/W, mob/user, params)
	consume(user)
	return TRUE

// We don't drift around space, they drift around us
/obj/singularity/Process_Spacemove()
	return TRUE

/obj/singularity/blob_act(obj/structure/blob/B)
	return

/obj/singularity/attack_tk(mob/user)
	if(iscarbon(user))
		var/mob/living/carbon/C = user
		C.visible_message("<span class='danger'>[C]'s head begins to collapse in on itself!</span>", "<span class='userdanger'>Your head feels like it's collapsing in on itself! This was really not a good idea!</span>", "<span class='hear'>You hear something crack and explode in gore.</span>")
		var/turf/T = get_turf(C)
		for(var/i in 1 to 3)
			C.apply_damage(30, BRUTE, BODY_ZONE_HEAD)
			new /obj/effect/gibspawner/generic(T, C)
			stoplag(1)
		C.ghostize()
		var/obj/item/bodypart/head/rip_u = C.get_bodypart(BODY_ZONE_HEAD)
		rip_u.dismember(BURN) //nice try jedi
		qdel(rip_u)

/obj/singularity/ex_act(severity, target)
	if(!severity)
		return
	if(severity == 1 && current_size <= STAGE_TWO)
		investigate_log("has been destroyed by a heavy explosion.", INVESTIGATE_SINGULO)
		qdel(src)
		return
	energy -= round( (energy+1) / (severity+1), 1)

/obj/singularity/bullet_act(obj/projectile/P)
	qdel(P)
	return BULLET_ACT_HIT //Will there be an impact? Who knows.  Will we see it? No.

/obj/singularity/Bump(atom/A)
	. = ..()
	consume(A)

/obj/singularity/Bumped(atom/movable/AM)
	. = ..()
	consume(AM)

/obj/singularity/Crossed(atom/movable/AM, oldloc)
	. = ..()
	consume(AM)

/obj/singularity/Moved(atom/OldLoc, Dir)
	. = ..()
	for(var/i in bounds())
		if(i == src)
			continue
		consume(i)

/obj/singularity/process()
	automatic_movement()

	if(current_size >= STAGE_TWO)
		radiation_pulse(src, min(5000, (energy*4.5)+1000), RAD_DISTANCE_COEFFICIENT*0.5)
		if(prob(event_chance))//Chance for it to run a special event TODO:Come up with one or two more that fit
			event()
	eat()
	dissipate()
	check_energy()

/obj/singularity/attack_ai() //to prevent ais from gibbing themselves when they click on one.
	return

/obj/singularity/proc/admin_investigate_setup()
	var/turf/T = get_turf(src)
	last_warning = world.time
	var/count = locate(/obj/machinery/field/containment) in urange(30, src, 1)
	if(!count)
		message_admins("A singulo has been created without containment fields active at [ADMIN_VERBOSEJMP(T)].")
	investigate_log("was created at [AREACOORD(T)]. [count?"":"<font color='red'>No containment fields were active</font>"]", INVESTIGATE_SINGULO)

/obj/singularity/proc/dissipate()
	if(!dissipate)
		return
	if(dissipate_track >= dissipate_delay)
		src.energy -= dissipate_strength
		dissipate_track = 0
	else
		dissipate_track++

/obj/singularity/proc/expand(force_size = 0)
	var/temp_allowed_size = src.allowed_size
	if(force_size)
		temp_allowed_size = force_size
	if(temp_allowed_size >= STAGE_SIX && !consumedSupermatter)
		temp_allowed_size = STAGE_FIVE
	switch(temp_allowed_size)
		if(STAGE_ONE)
			current_size = STAGE_ONE
			icon = 'icons/obj/singularity.dmi'
			icon_state = "singularity_s1"
			bound_width = 32
			bound_height = 32
			bound_x = 0
			bound_y = 0
			pixel_x = 0
			pixel_y = 0
			grav_pull = 4
			dissipate_delay = 10
			dissipate_track = 0
			dissipate_strength = 1
		if(STAGE_TWO)
			if(check_cardinals_range(1))
				current_size = STAGE_TWO
				icon = 'icons/effects/96x96.dmi'
				icon_state = "singularity_s3"
				bound_width = 96
				bound_height = 96
				bound_x = -32
				bound_y = -32
				pixel_x = -32
				pixel_y = -32
				grav_pull = 6
				dissipate_delay = 5
				dissipate_track = 0
				dissipate_strength = 5
		if(STAGE_THREE)
			if(check_cardinals_range(2))
				current_size = STAGE_THREE
				icon = 'icons/effects/160x160.dmi'
				icon_state = "singularity_s5"
				bound_width = 160
				bound_height = 160
				bound_x = -64
				bound_y = -64
				pixel_x = -64
				pixel_y = -64
				grav_pull = 8
				dissipate_delay = 4
				dissipate_track = 0
				dissipate_strength = 20
		if(STAGE_FOUR)
			if(check_cardinals_range(3))
				current_size = STAGE_FOUR
				icon = 'icons/effects/224x224.dmi'
				icon_state = "singularity_s7"
				bound_width = 224
				bound_height = 224
				bound_x = -96
				bound_y = -96
				pixel_x = -96
				pixel_y = -96
				grav_pull = 10
				dissipate_delay = 10
				dissipate_track = 0
				dissipate_strength = 10
		if(STAGE_FIVE)//this one also lacks a check for gens because it eats everything
			current_size = STAGE_FIVE
			icon = 'icons/effects/288x288.dmi'
			icon_state = "singularity_s9"
			bound_width = 288
			bound_height = 288
			bound_x = -128
			bound_y = -128
			pixel_x = -128
			pixel_y = -128
			grav_pull = 10
			dissipate = 0 //It cant go smaller due toe loss
		if(STAGE_SIX) //This only happens if a stage 5 singulo consumes a supermatter shard.
			current_size = STAGE_SIX
			icon = 'icons/effects/352x352.dmi'
			icon_state = "singularity_s11"
			bound_width = 352
			bound_height = 352
			bound_x = -160
			bound_y = -160
			pixel_x = -160
			pixel_y = -160
			grav_pull = 15
			dissipate = 0
	if(current_size == allowed_size)
		investigate_log("<font color='red'>grew to size [current_size]</font>", INVESTIGATE_SINGULO)
		return TRUE
	else if(current_size < (--temp_allowed_size))
		expand(temp_allowed_size)
	else
		return FALSE

/obj/singularity/proc/check_energy()
	if(energy <= 0)
		investigate_log("collapsed.", INVESTIGATE_SINGULO)
		qdel(src)
		return FALSE
	switch(energy)//Some of these numbers might need to be changed up later -Mport
		if(1 to 199)
			allowed_size = STAGE_ONE
		if(200 to 499)
			allowed_size = STAGE_TWO
		if(500 to 999)
			allowed_size = STAGE_THREE
		if(1000 to 1999)
			allowed_size = STAGE_FOUR
		if(2000 to INFINITY)
			if(energy >= 3000 && consumedSupermatter)
				allowed_size = STAGE_SIX
			else
				allowed_size = STAGE_FIVE
	if(current_size != allowed_size)
		expand()
	return TRUE

/obj/singularity/proc/eat()
	if(!isturf(loc))
		return
	for(var/i in obounds(src, grav_pull*16))
		CHECK_TICK
		var/atom/sucker = i
		if(QDELETED(sucker))
			continue
		sucker.singularity_pull(src, current_size)

/obj/singularity/proc/consume(atom/A)
	set waitfor = FALSE
	if(CHECK_TICK && QDELETED(A))
		return
	var/gain = A.singularity_act(current_size, src)
	energy += gain
	if(istype(A, /obj/machinery/power/supermatter_crystal) && !consumedSupermatter)
		desc = "[initial(desc)] It glows fiercely with inner fire."
		name = "supermatter-charged [initial(name)]"
		consumedSupermatter = TRUE
		set_light(10)

/obj/singularity/proc/automatic_movement(force_move = NONE)
	if(!move_self)
		return

	if(!last_failed_movement && world.time < next_movement_change)
		return
	next_movement_change = world.time + 3 SECONDS

	var/movement_dir
	if(force_move)
		movement_dir = force_move
	else if(target && prob(60))
		movement_dir = get_dir(src,target) //moves to a singulo beacon, if there is one
	else
		movement_dir = pick(GLOB.alldirs - last_failed_movement)

	walk(src, movement_dir)

/obj/singularity/proc/check_cardinals_range(range)
	for(var/turf/place in bounds(src, (range*32) - bound_width + 32))
		if(!can_move(place))
			return FALSE
	return TRUE

/obj/singularity/proc/can_move(turf/T)
	if(!T)
		return FALSE
	if((locate(/obj/machinery/field/containment) in T)||(locate(/obj/machinery/shieldwall) in T))
		return FALSE
	else if(locate(/obj/machinery/field/generator) in T)
		var/obj/machinery/field/generator/G = locate(/obj/machinery/field/generator) in T
		if(G && G.active)
			return FALSE
	else if(locate(/obj/machinery/power/shieldwallgen) in T)
		var/obj/machinery/power/shieldwallgen/S = locate(/obj/machinery/power/shieldwallgen) in T
		if(S && S.active)
			return FALSE
	return TRUE

/obj/singularity/proc/event()
	var/numb = rand(1,4)
	switch(numb)
		if(1)//EMP
			emp_area()
		if(2)//Stun mobs who lack optic scanners
			mezzer()
		if(3,4) //Sets all nearby mobs on fire
			if(current_size < STAGE_SIX)
				return FALSE
			combust_mobs()
		else
			return FALSE
	return TRUE

/obj/singularity/proc/combust_mobs()
	for(var/mob/living/carbon/C in urange(20, src, 1))
		C.visible_message("<span class='warning'>[C]'s skin bursts into flame!</span>", \
						  "<span class='userdanger'>You feel an inner fire as your skin bursts into flames!</span>")
		C.adjust_fire_stacks(5)
		C.IgniteMob()

/obj/singularity/proc/mezzer()
	for(var/mob/living/carbon/M in oviewers(8, src))
		if(isbrain(M)) //Ignore brains
			continue

		if(M.stat == CONSCIOUS)
			if (ishuman(M))
				var/mob/living/carbon/human/H = M
				if(istype(H.glasses, /obj/item/clothing/glasses/meson))
					var/obj/item/clothing/glasses/meson/MS = H.glasses
					if(MS.vision_flags == SEE_TURFS)
						to_chat(H, "<span class='notice'>You look directly into the [src.name], good thing you had your protective eyewear on!</span>")
						return

		M.apply_effect(60, EFFECT_STUN)
		M.visible_message("<span class='danger'>[M] stares blankly at the [src.name]!</span>", \
						"<span class='userdanger'>You look directly into the [src.name] and feel weak.</span>")

/obj/singularity/proc/emp_area()
	empulse(src, 8, 10)

/obj/singularity/singularity_act()
	var/gain = (energy/2)
	var/dist = max((current_size - 2),1)
	explosion(src.loc,(dist),(dist*2),(dist*4))
	qdel(src)
	return(gain)

/obj/singularity/proc/bluespace_reaction()
	investigate_log("has been shot by bluespace artillery and destroyed.", INVESTIGATE_SINGULO)
	qdel(src)

/obj/singularity/deadchat_controlled
	move_self = FALSE

/obj/singularity/deadchat_controlled/Initialize(mapload, starting_energy)
	. = ..()
	AddComponent(/datum/component/deadchat_control, DEMOCRACY_MODE, list(
	 "up" = CALLBACK(GLOBAL_PROC, .proc/_step, src, NORTH),
	 "down" = CALLBACK(GLOBAL_PROC, .proc/_step, src, SOUTH),
	 "left" = CALLBACK(GLOBAL_PROC, .proc/_step, src, WEST),
	 "right" = CALLBACK(GLOBAL_PROC, .proc/_step, src, EAST)))
