#----------------------------------------
#		author: Paolo Calao			
#		mail:	paolo.calao@gmail.com
#		title:	vth_swap.tcl
#		description:
#			 Command to be run in DC to swap a sub-set of cells to a given threshold voltage.
#----------------------------------------

proc cells_swapping {cell_list final_vt} {
set debug_list [list]
	set final_vt "L[lindex [split $final_vt {}] 0]"
	#or regsub {VT} $final_vt {}
	set lib _nom_1.20V_25C.db:
	foreach cell $cell_list {
		set cell_name [get_attribute [get_cell $cell] ref_name]
		set current_vt [lindex [split $cell_name {_}] 1]
		set current_size [regsub {.*X} $cell_name ""]
		if {!($final_vt eq $current_vt)} {
			set alternative_cells [get_alternative_lib_cells $cell]
			set alternative_cell_found false
			foreach_in_collection alt_cell $alternative_cells {
				if {!$alternative_cell_found} {
					set alt_cell_name [get_attribute $alt_cell base_name]
					set alt_cell_vt [lindex [split $alt_cell_name {_}] 1]
					set alt_cell_size [regsub {.*X} $alt_cell_name ""]
					if {$alt_cell_vt eq $final_vt && $alt_cell_size eq $current_size} {
						set alternative_cell_found true
						set alt_cell_name [regsub {/.*} [get_attribute $alt_cell full_name] ""]
						append alt_cell_name $lib [get_attribute $alt_cell full_name]
						size_cell $cell $alt_cell_name
					}
				}
			}
		}
	}
	return $debug_list
}

set cell_list "U151 U96 U95"
set final_vt "LVT"; #first value passed by terminal
puts [cells_swapping $cell_list $final_vt]

