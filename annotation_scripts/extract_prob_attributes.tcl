#----------------------------------------
#		author: Paolo Calao			
#		mail:	paolo.calao@gmail.com
#		title:	static_probability.tcl
#
#		description:
#			TCL script (to be run in PrimeTime) which extracts (for each and every node
#			in the loaded design) the following attributes: full_name, static_probability, toggle_count.
#----------------------------------------

proc get_all_nets_switching_activity {} {
	set net_list [list]
	foreach net [get_nets] {
		set net_item [list]
		lappend net_item [get_attribute $net full_name]
		lappend net_item [get_attribute $net static_probability]
		lappend net_item [get_attribute $net toggle_count]
		lappend net_list $net_item
	}
	return $net_list
}

puts [get_all_nets_switching_activity]
