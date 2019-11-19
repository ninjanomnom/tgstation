#define PIXELS 32

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
	x += dist * sin(deg)
	y += dist * cos(deg)
	NORMALIZE_STEP(place, x, y)
	return thing.Move(place, get_dir(thing.loc, place), x, y)

// Returns the direction from thingA to thingB in degrees
// EAST is 0 and goes counter clockwise
/proc/get_deg(atom/movable/thingA, atom/movable/thingB)
	var/turf/placeA = get_turf(thingA)
	var/turf/placeB = get_turf(thingB)
	var/stepbx = 0
	var/stepby = 0
	var/stepax = 0
	var/stepay = 0
	if(ismovableatom(thingB))
		stepbx = thingB.step_x
		stepby = thingB.step_y
	if(ismovableatom(thingA))
		stepax = thingA.step_x
		stepay = thingA.step_y
	var/x = ((placeB.x*PIXELS)+stepbx) - ((placeA.x*PIXELS)+stepax)
	var/y = ((placeB.y*PIXELS)+stepby) - ((placeA.y*PIXELS)+stepay)
	return ATAN2(y, x)
