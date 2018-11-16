#----------------------------------------
#		author: Paolo Calao			
#		mail:	paolo.calao@gmail.com
#		title:	slack_histogram.tcl
#		description:
#			The command extracts all the cells whose slack falls in a specific slack window
#			and returns the slack distribution of such cells. 
#			Input parameters are the left edge left_edge and the right edge rigth_edge of the slack window.
#----------------------------------------


proc slack_histogram {left_edge right_edge} {
	set histogram_list [list]
	set num_windows 10
	set cell_collection [get_cells]
	foreach_in_collection temp_cell $cell_collection {
		set temp_cell_name [get_attribute $temp_cell full_name]
		set out_pin [get_pin -filter {direction==out} $temp_cell_name/*]
		set temp_slack [get_attribute $out_pin max_slack]
		set window_assigned false
		set $index 0
		while {!$window_assigned && $index < $num_windows} {
			set left_bound [expr ($right_edge - $left_edge) / $num_windows * $index + $left_edge]
			set right_bound [expr ($right_edge - $left_edge) / $num_windows * ($index + 1) + $left_edge]
			if {$temp_slack > $left_bound && $temp_slack <= $right_bound} {
				set histogram_list [lreplace $histogram_list $index $index [expr [lindex $histogram_list $index] + 1]]
				set window_assigned true
			}
			set $index [expr $index + 1]
		}
	}
}



slack_histogram 0 1
