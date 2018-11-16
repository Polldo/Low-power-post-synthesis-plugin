#----------------------------------------
#		author: Paolo Calao			
#		mail:	paolo.calao@gmail.com
#		title:	static_probability.tcl
#
#		description:
# 			Tcl script (to be run in PrimeTime) that parses the power report generated
#			by modelSim and calculates the static probability of each and every input port.
#----------------------------------------

proc find_line {match_string} {
	global fId
	set line_found false
	set line ""
	while {!$line_found && [gets $fId line] >= 0} {
		if {[regexp $match_string $line]} {
			set line_found true
		}
	}
	if {$line_found} {
		return $line
	} else {
		return -1
	}
}

proc collection_to_list_names {collection} {
	set lista [list]
	foreach_in_collection item $collection {
		lappend lista [get_attribute $item full_name]
	}
	return $lista
}

proc annotate_switching_activity {} {
	global fId
	set library_path "/aes_cipher_top_swa.txt"
	set fId [open $library_path r]
	set input_net_list [collection_to_list_names [all_inputs]]
	find_line "Power Report Interval"
	gets $fId pr_interval
	find_line "---"
	while {[gets $fId line] >= 0 && ![regexp {\-\-\-} $line]} {
		set line [regsub -all {.*/} $line ""]
		set line [regsub -all { +} $line {;}]
		set line [split $line {;}]
		set net_name [regsub {\(} [lindex $line 0] {[}]
		set net_name [regsub {\)} $net_name {]}]
		if {[lsearch -exact $input_net_list $net_name] >= 0} {
			set time_at_one [lindex $line 3]
			set static_probability [expr 1.0 * $time_at_one / $pr_interval]
			set toggle_count [lindex $line 1]
puts "$net_name $static_probability $toggle_count $pr_interval"
puts $line
			set_switching_activity $net_name -static_probability $static_probability -toggle_rate $toggle_count -period $pr_interval
		}
	}
}

puts [get_switching_activity key[13]]
annotate_switching_activity
puts [get_switching_activity key[13]]
