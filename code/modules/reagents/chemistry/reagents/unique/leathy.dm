/obj/item/reagent_containers/cup/glass/drinkingglass/filled/leathy
	list_reagents = list(/datum/reagent/consumable/ethanol/leathy = 30)

/datum/reagent/consumable/ethanol/leathy
	name = "Leathy"
	description = "Dark and syrupy."
	boozepwr = 5 // Drunkeness is the least of your concerns now
	color = "#312619"
	quality = DRINK_FANTASTIC
	taste_description = "sweet... you think?"
	chemical_flags = REAGENT_DEAD_PROCESS | REAGENT_IGNORE_STASIS | REAGENT_NO_RANDOM_RECIPE
	metabolization_rate = 1 // TODO: REMOVE THIS

/**
 * Plans:
 *
 * Crafting: Moth wings + honey + fantastic quality drink + ectoplasm
 * Take all these to an altar and mix *on the altar*
 * The light must be at half or below
 * If you have all the ingredients mixed but dont meet the other criteria, vaporize all ingredients
 *
 * Crafting hint:
 * Instructions given through dreams, you *must* have the dream before you can craft it
 *
 * For the initial effects first:
 * Nothing obvious immediately, some messages about feeling wrong, like something is changing
 * Vomit once
 * Collapse
 * Rise into the air (maybe some dark rays + anti light emitting from the body?)
 * Use the displacement map filter to slough off the skin while greyscaling the mob underneath
 * Go back upright and descend back to the ground
 * Have the mob fade out to invisibility using fragile invisibility at this point
 * Leave behind the pile of "skin"
 *
 * Effects:
 * Fragile invisibility
 * ID stops working
 * Randomize fingerprints
 * Job traits?
 * Name censored from
 * - Security records
 * - Objectives
 * - Chat?
 */

/datum/reagent/consumable/ethanol/leathy/on_mob_life(mob/living/carbon/drinker, seconds_per_tick, times_fired)
	. = ..()
	var/datum/status_effect/forgotten_by_the_world/forgotten = drinker.has_status_effect(/datum/status_effect/forgotten_by_the_world)
	if(forgotten)
		forgotten.add_energy(metabolization_rate)
	else
		drinker.apply_status_effect(/datum/status_effect/forgotten_by_the_world, metabolization_rate)

//------------------
// STATUS EFFECT

/datum/status_effect/forgotten_by_the_world
	processing_speed = STATUS_EFFECT_NORMAL_PROCESS

	var/remaining_energy
	var/activated = FALSE

	var/degrade_time_start
	var/degrade_warned = FALSE

	var/static/list/fading_messages = list(
		"What was your name again?",
		"You see your reflection and you don't recognize the face.",
		"Did you always have this hair color?",
	)

	var/blackener_id = "leathy-blackener"
	var/obj/effect/abstract/leathy/blackener/blackener = new

	var/wavering_id = "leathy-wavering"
	var/gaussian_id = "leathy-gaussian"

/datum/status_effect/forgotten_by_the_world/Destroy()
	QDEL_NULL(blackener)
	return ..()

/datum/status_effect/forgotten_by_the_world/on_creation(mob/living/new_owner, starting_energy)
	// This is before parent call so we can cleanly cancel this from on_apply if we arent given any energy
	remaining_energy = starting_energy
	return ..()

/datum/status_effect/forgotten_by_the_world/on_apply()
	. = ..()
	if(remaining_energy <= 0)
		return FALSE
	degrade_time_start = world.time + 5 MINUTES
	owner.vis_contents += blackener // it does nothing yet

/datum/status_effect/forgotten_by_the_world/on_remove()
	. = ..()
	owner.vis_contents -= blackener
	if(activated)
		owner.remove_filter(blackener_id)
		owner.remove_filter(wavering_id)
		owner.remove_filter(gaussian_id)

/datum/status_effect/forgotten_by_the_world/tick(seconds_between_ticks)
	if(world.time > degrade_time_start)
		if(!degrade_warned)
			if(activated)
				to_chat(owner, span_warning("You cannot hide from reality forever."))
			else
				to_chat(owner, span_notice("Ugh... what did you drink last night?"))
			degrade_warned = TRUE
		use_energy(1)

	if(!activated && SPT_PROB(remaining_energy * 2, seconds_between_ticks))
		to_chat(owner, span_notice(pick(fading_messages)))
		var/original_alpha = owner.alpha
		animate(owner, time=5 SECONDS, easing=BOUNCE_EASING, alpha=10)
		animate(time=2 SECONDS, alpha=original_alpha)

/datum/status_effect/forgotten_by_the_world/proc/use_energy(amount)
	remaining_energy -= amount
	if(remaining_energy <= 0)
		qdel(src)
		return

/datum/status_effect/forgotten_by_the_world/proc/add_energy(amount)
	remaining_energy += amount
	degrade_time_start = max(world.time, degrade_time_start) + (amount * 10 SECONDS)
	if(!activated && remaining_energy >= 10)
		and_now_we_begin()

/datum/status_effect/forgotten_by_the_world/proc/censor_block(text_to_replace)
	var/static/regex/everything = regex(".", "g")
	return everything.Replace(text_to_replace, "█")

/datum/status_effect/forgotten_by_the_world/proc/and_now_we_begin()
	set waitfor = FALSE

	activated = TRUE

	forget_your_name()
	addtimer(CALLBACK(src, PROC_REF(forget_your_skin)), 1 SECONDS)

/datum/status_effect/forgotten_by_the_world/proc/forget_your_name()
	to_chat(owner, span_warning("Something is horribly wrong. What was your name again?"))
	sleep(5 SECONDS)
	if(owner.get_idcard(TRUE))
		to_chat(owner, span_warning("You have your id on you, let's see..."))
	else
		to_chat(owner, span_warning("If only you had your id on you..."))
	sleep(5 SECONDS)
	to_chat(owner, span_warning("That's right, your name was [censor_block(owner.name)]!"))
	sleep(1 SECONDS)
	to_chat(owner, span_warning("Wait, that can't be right..."))

/datum/status_effect/forgotten_by_the_world/proc/forget_your_skin()
	owner.add_filter(blackener_id, 1, layering_filter(render_source=blackener.render_target, blend_mode=BLEND_INSET_OVERLAY))
	blackener.alpha = 0
	animate(blackener, time=10, alpha=240)

	owner.add_filter(wavering_id, 1, wave_filter(x=10, y=0, size=5, offset=0))
	var/wave_filter = owner.get_filter(wavering_id)
	animate(wave_filter, time=0, loop=-1, flags=ANIMATION_PARALLEL, offset=0)
	animate(offset=-1, time=3 SECONDS)

	owner.add_filter(gaussian_id, 1, gauss_blur_filter(size=0.5))

	sleep(10 SECONDS)

	owner.AddComponent(/datum/component/fragile_invisibility, onVisible=CALLBACK(src, PROC_REF(on_invis_broken)))

//---------------
// STUFF

/datum/status_effect/forgotten_by_the_world/proc/on_invis_broken()
	use_energy(0.5)

//----------------
// EFFECTS OBJECTS

/obj/effect/abstract/leathy
	icon = 'icons/effects/leathy.dmi'
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	plane = FLOAT_PLANE
	layer = FLOAT_LAYER

/obj/effect/abstract/leathy/shifting_shadows
	icon = 'icons/effects/leathy.dmi'
	icon_state = "shifting-shadows"

/obj/effect/abstract/leathy/shifting_shadows/Initialize(mapload)
	. = ..()
	add_filter("gauss", 1, gauss_blur_filter(4))
	add_filter("drop_shadow", 1, drop_shadow_filter(size=2, offset=1))

/obj/effect/abstract/leathy/mob_curtain
	icon = 'icons/effects/leathy.dmi'
	icon_state = "default-curtain"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/abstract/leathy/blackener
	icon_state = "blackener"
	render_target = "*LEATHY BLACKENER"
