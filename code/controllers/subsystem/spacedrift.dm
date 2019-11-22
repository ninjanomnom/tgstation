SUBSYSTEM_DEF(spacedrift)
	name = "Space Drift"
	priority = FIRE_PRIORITY_SPACEDRIFT
	wait = 1
	flags = SS_NO_INIT|SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	var/list/currentrun = list()
	var/list/processing = list()

/datum/controller/subsystem/spacedrift/stat_entry()
	..("P:[processing.len]")


/datum/controller/subsystem/spacedrift/fire(resumed = 0)
	if (!resumed)
		src.currentrun = processing.Copy()

	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun

	while (currentrun.len)
		var/atom/movable/AM = currentrun[currentrun.len]
		currentrun.len--
		if (!AM)
			processing -= AM
			if (MC_TICK_CHECK)
				return
			continue

		if (!AM.loc || AM.Process_Spacemove(0))
			AM.inertia_dir = 0

		if (!AM.inertia_dir)
			processing -= AM
			if (MC_TICK_CHECK)
				return
			continue

		var/old_dir = AM.dir
		AM.inertia_moving = TRUE
		step(AM, AM.inertia_dir, AM.step_size) // TODO: rework inertia to use degstep and angles
		AM.inertia_moving = FALSE

		AM.setDir(old_dir)
		if (MC_TICK_CHECK)
			return

