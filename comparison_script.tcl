#----------------------------------------
#		author: Paolo Calao			
#		mail:	paolo.calao@gmail.com
#		title:	comparison_script.tcl
#----------------------------------------

source ./pt_analysis.tcl
set fId [open "table_all_global.txt" w]
puts $fId "parameters	constraint	delta_slack	cpu_time" 

global kd
global ks
global kl

global percent_factor
global limit_sort_value

set algos [list {../dualVth.tcl}]
foreach temp_algo $algos {
	source $temp_algo
	set percents [list 0.75 0.75]
	foreach perc $percents {
		set percent_factor $perc
		set limits [list 0]
		foreach lim $limits {
			set limit_sort_value $lim
			set params [list [list -1 1 1]]
			foreach temp_param $params {
				puts $fId "---------------------------------------------------------------------------"
				set initial_slack [get_attribute [get_timing_path] slack]
				set kd [lindex $temp_param 0]
				set ks [lindex $temp_param 1] 
				set kl [lindex $temp_param 2]
				puts $fId "---- using Algo: $temp_algo	 parameters: kd $kd	ks $ks	kl $kl		percente_factor: $percent_factor	limit_sort_val: $limit_sort_value    initial_slack : $initial_slack"
				set constraints [list 0.1 0.2 0.3 0.4 0.45 0.5 0.55 0.6 0.66 0.7 0.76 0.8 0.84 0.9 0.96 1]
				set tot_cpu 0
				set tot_slack 0
				set tot_delta_slack 0
				foreach constr $constraints {
					set sec1 [clock milliseconds]
					dualVth -savings $constr
					set sec2 [clock milliseconds]
					set cpu_time [expr $sec2 - $sec1]
					set tot_cpu [expr $tot_cpu + $cpu_time]
					set finish_slack [get_attribute [get_timing_path] slack]
					set tot_slack [expr $tot_slack + $finish_slack]
					set delta_slack [expr 1.0 * ($initial_slack - $finish_slack) / $initial_slack]
					set tot_delta_slack [expr $tot_delta_slack + $delta_slack]
					puts $fId "	$constr		$finish_slack	$delta_slack		$cpu_time"
					change_hvt_to_lvt
				}
				set tot_slack [expr $tot_slack / [llength $constraints]]
				set tot_delta_slack [expr $tot_delta_slack / [llength $constraints]]
				set tot_cpu [expr $tot_cpu / [llength $constraints]]
				puts $fId "  tot slack: $tot_slack	tot_delta_slack: $tot_delta_slack	   tot cpu time:  $tot_cpu"
			}
		}
	}
}

close $fId
