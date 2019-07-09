// Direct powernet connection via terminal machinery.
// Note that this isn't for the terminal itself, which is an auxiliary entity; it's for whatever is connected to it.
/obj/item/weapon/stock_parts/power/terminal
	name = "wired connection"
	desc = "A power connection directly to the grid, via power cables."
	icon_state = "terminal"
	priority = 2
	var/obj/machinery/power/terminal/terminal
	var/terminal_dir = 0

/obj/item/weapon/stock_parts/power/terminal/on_uninstall(var/obj/machinery/machine)
	unset_terminal(loc, terminal)
	..()

/obj/item/weapon/stock_parts/power/terminal/Destroy()
	qdel(terminal)
	. = ..()

/obj/item/weapon/stock_parts/power/terminal/machine_process(var/obj/machinery/machine)
	if(!terminal)
		machine.update_power_channel(cached_channel)
		machine.power_change()
		return
	
	var/surplus = terminal.surplus()
	var/usage = machine.get_power_usage()
	terminal.draw_power(usage)
	if(surplus >= usage)
		return // had enough power and good to go.

	// Try and use other (local) sources of power to make up for the deficit.
	var/deficit = machine.use_power_oneoff(usage - surplus)
	if(deficit > 0)
		machine.update_power_channel(cached_channel)
		machine.power_change()

//Is willing to provide power if the wired contribution is nonnegligible and there is enough total local power to run the machine.
/obj/item/weapon/stock_parts/power/terminal/can_provide_power(var/obj/machinery/machine)
	if(terminal && terminal.surplus() && machine.can_use_power_oneoff(machine.get_power_usage(), LOCAL) <= 0)
		set_status(machine, PART_STAT_ACTIVE)
		cached_channel = machine.power_channel
		machine.update_power_channel(LOCAL)
		start_processing(machine)
		return TRUE
	return FALSE

/obj/item/weapon/stock_parts/power/terminal/can_use_power_oneoff(var/obj/machinery/machine, var/amount, var/channel)
	. = 0
	if(terminal && channel == LOCAL)
		return min(terminal.surplus(), amount)

/obj/item/weapon/stock_parts/power/terminal/use_power_oneoff(var/obj/machinery/machine, var/amount, var/channel)
	. = 0
	if(terminal && channel == LOCAL)
		return terminal.draw_power(amount)

/obj/item/weapon/stock_parts/power/terminal/not_needed(var/obj/machinery/machine)
	unset_status(machine, PART_STAT_ACTIVE)
	stop_processing(machine)

/obj/item/weapon/stock_parts/power/terminal/proc/set_terminal(var/obj/machinery/machine, var/obj/machinery/power/new_terminal)
	if(terminal)
		unset_terminal(machine, terminal)
	terminal = new_terminal
	terminal.master = src
	GLOB.destroyed_event.register(terminal, src, .proc/unset_terminal)
	set_status(machine, PART_STAT_CONNECTED)

/obj/item/weapon/stock_parts/power/terminal/proc/make_terminal(var/obj/machinery/machine)
	if(!machine)
		return
	var/obj/machinery/power/terminal/new_terminal = new (get_step(machine, terminal_dir))
	new_terminal.set_dir(terminal_dir ? GLOB.reverse_dir[terminal_dir] : machine.dir)
	new_terminal.connect_to_network()
	set_terminal(machine, new_terminal)

/obj/item/weapon/stock_parts/power/terminal/proc/unset_terminal(var/obj/machinery/power/old_terminal, var/obj/machinery/machine)
	GLOB.destroyed_event.unregister(old_terminal, src)
	terminal = null
	unset_status(machine, PART_STAT_CONNECTED)

/obj/item/weapon/stock_parts/power/terminal/proc/blocking_terminal_at_loc(var/obj/machinery/machine, var/turf/T, var/mob/user)
	. = FALSE
	var/check_dir = terminal_dir ? GLOB.reverse_dir[terminal_dir] : machine.dir
	for(var/obj/machinery/power/terminal/term in T)
		if(T.dir == check_dir)
			to_chat(user, "<span class='notice'>There is already a terminal here.</span>")
			return TRUE

/obj/item/weapon/stock_parts/power/terminal/attackby(obj/item/I, mob/user)
	var/obj/machinery/machine = loc
	if(!istype(machine))
		return ..()

	// Interactions inside machine only
	if (istype(I, /obj/item/stack/cable_coil) && !terminal)
		var/turf/T = get_step(machine, terminal_dir)
		if(terminal_dir && user.loc != T)
			return FALSE // Wrong terminal handler.
		if(blocking_terminal_at_loc(machine, T, user))
			return FALSE

		if(istype(T) && !T.is_plating())
			to_chat(user, "<span class='warning'>You must remove the floor plating in front of \the [machine] first.</span>")
			return TRUE
		var/obj/item/stack/cable_coil/C = I
		if(!C.can_use(10))
			to_chat(user, "<span class='warning'>You need ten lengths of cable for \the [machine].</span>")
			return TRUE
		user.visible_message("<span class='warning'>\The [user] adds cables to the \the [machine].</span>", \
							"You start adding cables to \the [machine] frame...")
		playsound(src.loc, 'sound/items/Deconstruct.ogg', 50, 1)
		if(do_after(user, 20, machine))
			if(C.can_use(10) && !terminal && (machine == loc) && machine.components_are_accessible(type) && !blocking_terminal_at_loc(machine, T, user))
				var/obj/structure/cable/N = T.get_cable_node()
				if (prob(50) && electrocute_mob(user, N, N))
					var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
					s.set_up(5, 1, machine)
					s.start()
					if(user.stunned)
						return TRUE
				C.use(10)
				user.visible_message(\
					"<span class='warning'>\The [user] has added cables to the \the [machine]!</span>",\
					"You add cables to the \the [machine].")
				make_terminal(machine)
		return TRUE

	if(isWirecutter(I) && terminal)
		var/turf/T = get_step(machine, terminal_dir)
		if(terminal_dir && user.loc != T)
			return FALSE // Wrong terminal handler.
		if(istype(T) && !T.is_plating())
			to_chat(user, "<span class='warning'>You must remove the floor plating in front of \the [machine] first.</span>")
			return TRUE
		user.visible_message("<span class='warning'>\The [user] dismantles the power terminal from \the [machine].</span>", \
							"You begin to cut the cables...")
		playsound(src.loc, 'sound/items/Deconstruct.ogg', 50, 1)
		if(do_after(user, 50, machine))
			if(terminal && (machine == loc) && machine.components_are_accessible(type))
				if (prob(50) && electrocute_mob(user, terminal.powernet, terminal))
					var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
					s.set_up(5, 1, machine)
					s.start()
					if(user.stunned)
						return TRUE
				new /obj/item/stack/cable_coil(T, 10)
				to_chat(user, "<span class='notice'>You cut the cables and dismantle the power terminal.</span>")
				qdel(terminal)
		return TRUE

/obj/item/weapon/stock_parts/power/terminal/buildable
	part_flags = PART_FLAG_HAND_REMOVE