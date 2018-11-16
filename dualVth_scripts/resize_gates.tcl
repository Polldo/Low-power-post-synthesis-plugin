#----------------------------------------
#		author: Paolo Calao			
#		mail:	paolo.calao@gmail.com
#		title:	resize_gates.tcl
#		description:
#			 Command to be run in DC to re-size standard gates.
#----------------------------------------

proc cells_resizing {cell_list size} {
	foreach cell_name $cell_list {
		set cell [get_cell $cell_name]
		set cell_ref [split [get_attribute $cell ref_name] {_}]
		set current_vth [lindex $cell_ref 1]
		set current_size [regsub {.*X} [get_attribute $cell ref_name] ""]
		set resized_cell ""
		set alt_cells_collection [get_alternative_lib_cells $cell]
		foreach_in_collection alt_cell $alt_cells_collection {
			set alt_ref [split [get_attribute $cell ref_name] {_}]
			set alt_vth [lindex $alt_ref 1]
			set alt_size [regsub {.*X} [get_attribute $alt_cell base_name] ""]
			if {($current_vth eq $alt_vth) && (($size eq {min} && $alt_size < $current_size) || ($size eq {max} && $alt_size > $current_size))} {
				set resized_cell $alt_cell
				set current_size $alt_size
			}
		}
		if {$resized_cell != ""} {
			puts [get_attribute $cell ref_name]
			size_cell $cell_name $resized_cell
			puts [get_attribute $cell ref_name]
		}
	}

}



#EXAMPLES
set cell_list "U89 U90 U92"
cells_resizing $cell_list max

