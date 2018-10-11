/proc/walk_for(atom/movable/thing, direct, lag, speed, until)
	set waitfor = FALSE
	walk(thing, direct, lag, speed)
	sleep(until)
	walk(thing, NONE)

// Like step but you move on an angle instead of a cardinal direction
/proc/degstep(atom/movable/thing, deg, dist)
	var/x = thing.step_x
	var/y = thing.step_y
	var/turf/place = thing.loc
	x += dist * cos(deg)
	y += dist * sin(deg)
	NORMALIZE_STEP(place, x, y)
	return thing.Move(place, get_dir(thing.loc, place), x, y)

// Returns the direction from thingA to thingB in degrees
// EAST is 0 and goes counter clockwise
/proc/get_deg(atom/movable/thingA, atom/movable/thingB)
	var/turf/placeA = get_turf(thingA)
	var/turf/placeB = get_turf(thingB)
	var/x = ((placeB.x*32)+thingB.step_x) - ((placeA.x*32)+thingA.step_x)
	var/y = ((placeB.y*32)+thingB.step_y) - ((placeA.y*32)+thingA.step_y)
	return ATAN2(x, y)