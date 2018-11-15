#----------------------------------------
#		author: Paolo Calao			
#		mail:	paolo.calao@gmail.com
#		title:	low_power_plugin.tcl
#----------------------------------------

proc dualVth {args} {
	parse_proc_arguments -args $args results
	set savings $results(-savings)
#puts "Optimization started...."
#
#Initialize the data structures. One list containing each lvt cell of the design paired with an integer value initialized at 0. 
#One dictionary used as a cache by the function that swap cells from lvt to hvt. It memorizes the association between the ref cells and their correct (of the same size) alternative cell in the library. 
	global lvt_cell_list
	global alt_cell_dict
	set alt_cell_dict [dict create]
	set lvt_cell_list [init_cell_list [get_cells]]
	set start_power [get_attribute [get_design] leakage_power]
#puts "Initial leakage power:  $start_power"
#	set size_list [llength $lvt_cell_list]
#puts "Number of design cells:  $size_list"
	save_leakage $start_power $savings
	return
}

define_proc_attributes dualVth \
-info "Post-Synthesis Dual-Vth cell assignment" \
-define_args \
{
	{-savings "minimum % of leakage savings in range [0, 1]" lvt float required}
}

#Input: a generic collection
#Output: a list of lists, each containing in the first position an element of the collection and in the second position an integer value (here initialized to 0). 
proc init_cell_list {collection} {
	set temp_list [list]
	foreach_in_collection item $collection {
		set item_list [list]
		lappend item_list $item
		lappend item_list 0
		lappend temp_list $item_list
	}
	return $temp_list
}

#Changes the vth of a cell to the one required. if the current threshold is equals to the threshold required nothing changes.
#Assumption: in the library every ref_cell is available with both LL and LH threshold voltage and the same size.
#If this assumption is not respected, the function <accurate_change_cell_vth>, at the end of the file, should be used instead. 
#
#Input: a cell of the design; the required threshold voltage for that cell (valid arguments are LL and LH); a global variable called alt_cell_dict already initialized.
#Output: void
#Side effect: the global dictionary 'alt_cell_dict' will be modified if a swap of cell occurs, it will be added an entry containing <ref_cell -> alternative_cell>. Cells are eventually re-sized.
proc change_cell_vth {cell final_vt} {
	global alt_cell_dict
	set cell_full_name [get_attribute $cell full_name]
	set cell_name [get_attribute $cell ref_name]
	set cell_vt [lindex [split $cell_name {_}] 1]
	if {[regexp {S} $cell_vt]} { append final_vt "S" }
	if {!($final_vt eq $cell_vt)} {
		if {[dict exists $alt_cell_dict $cell_name]} {
			set final_cell_name [dict get $alt_cell_dict $cell_name]
			size_cell $cell_full_name $final_cell_name
		} else {
			set final_cell [regsub $cell_vt $cell_name $final_vt]
			size_cell $cell_full_name $final_cell
			dict set alt_cell_dict $cell_name $final_cell
		}
	}
}

#Input: leakage power at the beginning of the optimization
#Output: current leakage savings 
proc get_current_savings {start_power} {
	set current_design [get_design]
	set current_power [get_attribute $current_design leakage_power]
	return [expr ($start_power - $current_power) / $start_power]
}

#Takes a cell and from that extracts slack, delay and leakage values. 
#These values will be normalized based on the boundaries (min and max slack, delay and leakage) between all the cells.
#The normalized values will be scaled by different constants and then their sum is returned. The constants were empirically found.
#
#Input: cell to calculate the parameter on.
#Output: list containing the cell and its parameter 
#parameter is calculated depending on area, leakage and slack of the cell. it will be used to sort the lvt cells
proc extract_cell_index {cell boundaries_params} {
#extracts values of the given cell
	set cell_name [get_attribute $cell full_name]
	set out_pin [get_pin -filter {direction==out} $cell_name/*]
	set slack [get_attribute $out_pin max_slack]
	set leakage [get_attribute $cell leakage_power]
	set delay_list [get_attribute [get_timing_arcs -of_objects $cell_name] delay_max]
	set delay [lindex [lsort -real -decreasing $delay_list] 0]
#exctracts the max and min values by the given matrix "boundaries_params"
	set max_slack [lindex [lindex $boundaries_params 0] 0]
	set min_slack [lindex [lindex $boundaries_params 1] 0]
	set max_delay [lindex [lindex $boundaries_params 0] 1]
	set min_delay [lindex [lindex $boundaries_params 1] 1]
	set max_leakage [lindex [lindex $boundaries_params 0] 2]
	set min_leakage [lindex [lindex $boundaries_params 1] 2]
#normalize the values of the given cell previously extracted
	if {$max_slack eq $min_slack} {set slack 0} else {set slack [expr ($slack - $min_slack) / ($max_slack - $min_slack)]}
	if {$max_delay eq $min_delay} {set delay 0} else {set delay [expr ($delay - $min_delay) / ($max_delay - $min_delay)]}
	if {$max_leakage eq $min_leakage} {set leakage 0} else {set leakage [expr ($leakage - $min_leakage) / ($max_leakage - $min_leakage)]}
#defining constants to confront the values
	set ks 1
	set kd -1
	set kl 1
	set result [expr $ks * $slack + $kd * $delay + $kl * $leakage]
	return $result
}

#Extracts the maxs and the mins slack, delay and leakage from all the current design's lvt cells.
#
#Input: global variable lvt_cell_list containing the design's cells.
#Output: list of 2 lists, the first containing the maxs for each parameter and the second containing the mins.
proc get_boundaries_params {} {
	global lvt_cell_list
	set max_slack -100
	set min_slack 100
	set max_delay -100
	set min_delay 100
	set max_leakage -100
	set min_leakage 100
	foreach temp_cell $lvt_cell_list {
		set cell [lindex $temp_cell 0]
		set cell_name [get_attribute $cell full_name]
		set out_pin [get_pin -filter {direction==out} $cell_name/*]
		set cell_slack [get_attribute $out_pin max_slack]
		set delay_list [get_attribute [get_timing_arcs -of_objects $cell_name] delay_max]
		set cell_delay [lindex [lsort -real -decreasing $delay_list] 0]
		set cell_leakage [get_attribute $cell leakage_power]
		if {$cell_delay > $max_delay} { set max_delay $cell_delay}
		if {$cell_delay < $min_delay} { set min_delay $cell_delay}
		if {$cell_leakage > $max_leakage} { set max_leakage $cell_leakage}
		if {$cell_leakage < $min_leakage} { set min_leakage $cell_leakage}
		if {$cell_slack > $max_slack && !($cell_slack eq INFINITY)} { set max_slack $cell_slack}
		if {$cell_slack < $min_slack && !($cell_slack eq INFINITY)} { set min_slack $cell_slack}
	} 
	return [list [list $max_slack $max_delay $max_leakage] [list $min_slack $min_delay $min_leakage]]
}

#Sorts the global list of lists <lvt_cell_list> based on the second element of each list. This parameter is a numeric value previously extracted from the attributes of the first item (a cell).
#The list is sorted such that the first elements contain the best cells to be swapped from lvt to hvt.  
#
#Input: global variable lvt_cell_list containing all the lvt cells.
#Output: void
#Side effect: the global list of lists <lvt_cell_list> is modified ->
# 		-> for each list the second element is modified according to the value extracted to the first element (the cell) using the function <extract_cell_index>
proc sort_lvt_cell_list {} {
	global lvt_cell_list
	set params_list [get_boundaries_params]
	for {set index 0} {$index < [llength $lvt_cell_list]} {incr index} {
		set temp_cell [lindex [lindex $lvt_cell_list $index] 0]
		set new_value [extract_cell_index $temp_cell $params_list]
		set new_item [list $temp_cell $new_value]
		set lvt_cell_list [lreplace $lvt_cell_list $index $index $new_item]
	}
	set lvt_cell_list [lsort -decreasing -real -index 1 $lvt_cell_list]
#puts $lvt_cell_list
}

#This is the core function of the optimization. It decides when and how many cells have to be swapped.
#Actually this function iteratively tries to swap from lvt to hvt a number of cells proportional to the leakage to be saved.
#It returns when the required savings is reached or when all the design's cells are already swapped to hvt.
#All parameters used, like that used to choose the number of cell to be swapped, have been chosen empirically after several attempts.
#
#Input: the initial leakage power; the leakage savings required.
#Output: void
#Directly Side effects on lvt_cell_list and indirectly side effects on alt_cell_dict. Cells are eventually re-sized.
proc save_leakage {start_power savings} {
	global lvt_cell_list
	set percent_factor 0.65
	set list_size [llength $lvt_cell_list]
	set init_list_size [llength $lvt_cell_list]
#puts "Number of design cells:  lvt [llength $lvt_cell_list]"
	set actual_savings [get_current_savings $start_power]
	while {$actual_savings < $savings && $list_size > 0} {
		set percentage_step [expr ($savings - $actual_savings) * $percent_factor]
		set cells_per_iteration [expr round($init_list_size * $percentage_step)]
		if {$cells_per_iteration < 3} {incr cells_per_iteration}  
#puts "Current savings:  $actual_savings"
#puts "Analyzing $cells_per_iteration cells"
		sort_lvt_cell_list
		set num_cell_changed 0
		for {set index 0} {$index < $cells_per_iteration && $index < $list_size} {incr index} {
			set temp_cell [lindex [lindex $lvt_cell_list $index] 0]
			change_cell_vth $temp_cell LH
			incr num_cell_changed
		}
		if {!($num_cell_changed eq 0)} {
			set lvt_to_hvt [expr $num_cell_changed - 1]
			set lvt_cell_list [lreplace $lvt_cell_list 0 $lvt_to_hvt] 
		}
		set list_size [llength $lvt_cell_list]
		set actual_savings [get_current_savings $start_power]
#puts "Saved $actual_savings of leakage power"
	}
	return
}

#Function to be use instead of <change_cell_vth> (see above) in the case the library doesn't contain both LL and LH version of a cell with the same size.
#This function changes the cell with the one of the required voltage threshold and with the most similar size.
#
#Input: a cell of the design; the required threshold voltage for that cell (valid arguments are LL and LH); a global variable called alt_cell_dict already initialized.
#Output: void
#Side effect: the global dictionary 'alt_cell_dict' will be modified if a swap of cell occurs, it will be added an entry containing <ref_cell -> alternative_cell> 
#proc accurate_change_cell_vth {cell final_vt} {
#	global alt_cell_dict
#	set cell_full_name [get_attribute $cell full_name]
#	set cell_name [get_attribute $cell ref_name]
#	set cell_vt [lindex [split $cell_name {_}] 1]
#	if {[regexp {S} $cell_vt]} { append final_vt "S" }
#	if {!($final_vt eq $cell_vt)} {
#		if {[dict exists $alt_cell_dict $cell_name]} {
#			set final_cell_name [dict get $alt_cell_dict $cell_name]
#			size_cell $cell_full_name $final_cell_name
#		} else {
#			set cell_size [regsub {.*X} $cell_name ""]
#			set alternative_cells [get_alternative_lib_cells $cell]
#			set size_delta 100 ;#delta between cell's size and alternative cell's size
#			set final_cell ""
#			foreach_in_collection alt_cell $alternative_cells {
#					set alt_cell_name [get_attribute $alt_cell base_name]
#					set alt_cell_vt [lindex [split $alt_cell_name {_}] 1]
#					set alt_cell_size [regsub {.*X} $alt_cell_name ""]
#					set alt_delta [expr abs($alt_cell_size - $cell_size)]
#					if {$alt_cell_vt eq $final_vt && $alt_delta < $size_delta} {
#						set size_delta $alt_delta
#						set final_cell $alt_cell
#					}
#			}
#			if {!($final_cell eq "")} {
#				set final_cell_name [get_attribute $final_cell full_name]
#				size_cell $cell_full_name $final_cell_name 
#				dict set alt_cell_dict $cell_name $final_cell_name
#			}
#		}
#	}
#}

