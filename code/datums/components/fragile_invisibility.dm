/atom/movable/proc/test_fragile_invisibility()
	AddComponent(/datum/component/fragile_invisibility)

/datum/component/fragile_invisibility
	var/invisibility_level
	var/animating = FALSE
	var/time_to_get_out_of_here

	var/datum/callback/onVisible
	var/datum/callback/onHide

/datum/component/fragile_invisibility/Initialize(invisibility_level=INVISIBILITY_OBSERVER, datum/callback/onVisible, datum/callback/onHide)
	if(!ismovable(parent))
		return COMPONENT_INCOMPATIBLE

	src.invisibility_level = invisibility_level
	src.onVisible = onVisible
	src.onHide = onHide

/datum/component/fragile_invisibility/RegisterWithParent()
	var/atom/movable/owner = parent

	INVOKE_ASYNC(src, PROC_REF(StartInvisibility))

	RegisterSignal(owner, COMSIG_MOVABLE_BUMP, PROC_REF(OnBump))

/datum/component/fragile_invisibility/UnregisterFromParent()
	var/atom/movable/owner = parent

	owner.RemoveInvisibility(type)

	UnregisterSignal(owner, COMSIG_MOVABLE_BUMP)

/datum/component/fragile_invisibility/proc/StartInvisibility()
	var/atom/movable/owner = parent

	var/current_alpha = owner.alpha
	animate(owner, alpha=0, time=2 SECONDS)
	animate(alpha=0, time=0.5 SECONDS)
	animate(alpha=current_alpha, time=0)

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

	var/current_alpha = owner.alpha
	owner.alpha = 0
	animate(owner, alpha=current_alpha, time=2 SECONDS)

	onVisible?.InvokeAsync() // This happens at the start of the fade in

	sleep(2 SECONDS - 1)

	while(world.time < time_to_get_out_of_here)
		sleep(time_to_get_out_of_here - world.time)

	StartInvisibility()

	onHide?.InvokeAsync() // This happens after fully fading out

	// Yeah doing this after sleeping after leaving the earlier loop means people could avoid invisibility cooldown by doing things during the fade out.
	// I'll let it slide because it makes the animation look better, and if they can pull it off within the short period they have they deserve it.
	animating = FALSE

/datum/component/fragile_invisibility/proc/OnBump(atom/movable/source)
	SIGNAL_HANDLER

	BreakInvisibility(5 SECONDS)
