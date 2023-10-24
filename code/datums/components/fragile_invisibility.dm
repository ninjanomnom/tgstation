/atom/movable/proc/test_fragile_invisibility()
	AddComponent(/datum/component/fragile_invisibility)

/datum/component/fragile_invisibility
	var/invisibility_level
	var/animating = FALSE
	var/time_to_get_out_of_here

	var/list/queued_invisibility_breaks

	var/datum/callback/onVisible
	var/datum/callback/onHide

	var/obj/effect/abstract/fader
	var/fader_filter_id = "fragile_invisibility_fader"

/datum/component/fragile_invisibility/Initialize(invisibility_level=INVISIBILITY_OBSERVER, datum/callback/onVisible, datum/callback/onHide)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE

	src.invisibility_level = invisibility_level
	src.onVisible = onVisible
	src.onHide = onHide

	fader = new
	fader.icon = 'icons/effects/leathy.dmi'
	fader.icon_state = "blackener"
	fader.render_target = "*[REF(fader)]"

/datum/component/fragile_invisibility/RegisterWithParent()
	var/atom/owner = parent
	owner.vis_contents += fader
	owner.add_filter(fader_filter_id, 1, alpha_mask_filter(render_source=fader.render_target))

	INVOKE_ASYNC(src, PROC_REF(StartInvisibility))

	if(ismovable(owner))
		RegisterSignal(owner, COMSIG_MOVABLE_BUMP, PROC_REF(OnAtomBump))
	if(ismob(owner))
		queued_invisibility_breaks = list()
		RegisterSignal(owner, COMSIG_ATOM_BUMPED, PROC_REF(OnMobBumped))
		RegisterSignals(owner, list(COMSIG_MOB_BEING_SWAPPED, COMSIG_LIVING_STARTING_SWAP), PROC_REF(OnSwap))
	else
		RegisterSignal(owner, COMSIG_ATOM_BUMPED, PROC_REF(OnAtomBumped))

/datum/component/fragile_invisibility/UnregisterFromParent()
	var/atom/movable/owner = parent
	owner.vis_contents -= fader
	owner.remove_filter(fader_filter_id)

	owner.RemoveInvisibility(type)

	UnregisterSignal(owner, COMSIG_MOVABLE_BUMP)

/datum/component/fragile_invisibility/proc/StartInvisibility()
	var/atom/movable/owner = parent

	animate(fader, alpha=100, time=2 SECONDS)

	sleep(2 SECONDS - 1)

	owner.SetInvisibility(invisibility_level, type)

/datum/component/fragile_invisibility/proc/BreakInvisibility(duration)
	set waitfor = FALSE

	time_to_get_out_of_here = max(time_to_get_out_of_here, world.time + duration)

	if(animating)
		return
	animating = TRUE

	var/atom/movable/owner = parent
	owner.RemoveInvisibility(type)

	animate(fader, alpha=255, time=2 SECONDS)

	onVisible?.InvokeAsync() // This happens at the start of the fade in

	sleep(2 SECONDS - 1)

	while(world.time < time_to_get_out_of_here)
		sleep(time_to_get_out_of_here - world.time)

	StartInvisibility()

	onHide?.InvokeAsync() // This happens after fully fading out

	// Yeah doing this after sleeping after leaving the earlier loop means people could avoid invisibility cooldown by doing things during the fade out.
	// I'll let it slide because it makes the animation look better, and if they can pull it off within the short period they have they deserve it.
	animating = FALSE

/// This is to queue breaking invisibility so that it can possibly be cancelled
/datum/component/fragile_invisibility/proc/QueueBreakInvisibility(duration, source)
	queued_invisibility_breaks[source] = addtimer(CALLBACK(src, PROC_REF(BreakInvisibility), duration), 0, TIMER_STOPPABLE)
	addtimer(CALLBACK(src, PROC_REF(ClearQueue)), 1)

/datum/component/fragile_invisibility/proc/ClearQueue()
	queued_invisibility_breaks = list()

// ATOM SIGNAL RECEIVER

/datum/component/fragile_invisibility/proc/OnAtomBump(atom/movable/source, atom/bumper)
	SIGNAL_HANDLER

	BreakInvisibility(4 SECONDS)

/datum/component/fragile_invisibility/proc/OnAtomBumped(atom/movable/source, atom/movable/bumper)
	SIGNAL_HANDLER

	BreakInvisibility(4 SECONDS)

// MOB SIGNAL RECEIVERS

/datum/component/fragile_invisibility/proc/OnMobBumped(mob/source, atom/bumper)
	SIGNAL_HANDLER

	if(!ismob(bumper))
		BreakInvisibility(4 SECONDS)
		return

	QueueBreakInvisibility(4 SECONDS, bumper)

/datum/component/fragile_invisibility/proc/OnSwap(mob/source, mob/swapper)
	SIGNAL_HANDLER

	var/timerid = queued_invisibility_breaks[swapper]
	if(!timerid)
		return
	deltimer(timerid)
