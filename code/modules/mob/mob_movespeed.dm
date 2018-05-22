
//Current movespeed modification list format: list(id = list( \
	priority, \
	oldstyle slowdown/speedup amount, \
	))

/mob/proc/add_movespeed_modifier(id, priority = 0, override = FALSE, oldstyle_slowdown = 0)
	if(LAZYACCESS(movespeed_modification, id) && !override)
		return
	LAZYSET(movespeed_modification, id, list(priority, oldstyle_slowdown))
	sort_movespeed_modlist()
	update_movespeed()

/mob/proc/remove_movespeed_modifier(id)
	LAZYREMOVE(movespeed_modification, id)
	UNSETEMPTY(movespeed_modification)
	update_movespeed()

/mob/proc/update_movespeed(resort = FALSE)
	if(resort)
		sort_movespeed_modlist()
	. = CONFIG_GET(number/mob_base_pixel_speed)
	if(isnull(.))
		. = 32
	for(var/id in movespeed_modification)
		var/list/data = movespeed_modification[id]
		var/oldstyle_slowdown = data[MOVESPEED_DATA_INDEX_OLDSTYLE_SLOWDOWN]
		if(oldstyle_slowdown > 0)
			. /= (oldstyle_slowdown + 1)
		else if(oldstyle_slowdown > 0)
			. *= ((-oldstyle_slowdown) + 1)
	cached_movespeed = .

/mob/proc/count_oldstyle_slowdown()
	. = 0
	for(var/id in movespeed_modification)
		var/list/data = movespeed_modification[id]
		. += data[MOVESPEED_DATA_INDEX_OLDSTYLE_SLOWDOWN]

/proc/movespeed_data_null_check(list/data)		//Determines if a data list is not meaningful and should be discarded.
	. = TRUE
	if(data[MOVESPEED_DATA_INDEX_OLDSTYLE_SLOWDOWN])
		. = FALSE

/mob/proc/sort_movespeed_modlist()			//Verifies it too. Sorts highest priority (first applied) to lowest priority (last applied)
	if(!movespeed_modification)
		return
	var/list/assembled = list()
	for(var/our_id in movespeed_modification)
		var/list/our_data = movespeed_modification[our_id]
		if(!islist(our_data) || (our_data.len < MOVESPEED_DATA_INDEX_PRIORITY) || movespeed_data_null_check(our_data))
			movespeed_modification -= our_id
			continue
		var/our_priority = our_data[MOVESPEED_DATA_INDEX_PRIORITY]
		var/resolved = FALSE
		for(var/their_id in assembled)
			var/list/their_data = assembled[their_id]
			if(their_data[MOVESPEED_DATA_INDEX_PRIORITY < our_priority])
				assembled.Insert(assembled.Find(their_id), our_id)
				assembled[our_id] = our_data
				resolved = TRUE
				break
		if(!resolved)
			assembled[our_id] = our_data
	movespeed_modification = assembled
	UNSETEMPTY(movespeed_modification)
