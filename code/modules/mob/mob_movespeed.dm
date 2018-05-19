
//Current movespeed modification list format: list(id = list( \
	priority, \
	oldstyle slowdown/speedup amount, \
	))

/mob/proc/update_movespeed()
	. = 32
	var/base = CONFIG_GET(number/mob_base_pixel_speed)
	if(isnull(base))
		base = 32

/mob/proc/sort_movespeed_modlist()			//Verifies it too. Sorts highest priority (first applied) to lowest priority (last applied)
	if(!movespeed_modification)
		return
	var/list/assembled = list()
	for(var/our_id in movespeed_modification)
		var/list/our_data = movespeed_modification[our_id]
		if(!islist(our_data) || (our_data.len < MOVESPEED_DATA_INDEX_PRIORITY))
			movespeed_modification -= our_id
			continue
		var/our_priority = our_data[MOVESPEED_DATA_INDEX_PRIORITY]
		var/resolved = FALSE
		for(var/their_id in assembled)
			var/list/their_data = assembled[their_id]
			if(their_data[MOVESPEED_DATA_INDEX_PRIORITY < our_priority])
				assembled.Insert(Find(their_id), our_id)
				assembled[our_id] = our_data
				resolved = TRUE
				break
		if(!resolved)
			assembled[our_id] = our_data
