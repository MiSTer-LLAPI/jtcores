package require ::quartus::project
package require ::quartus::sta

project_open -revision S32 S32
create_timing_netlist -model slow -voltage 1100 -temperature 100
read_sdc
update_timing_netlist
report_timing -setup -npaths 30 -nworst 1 -detail full_path -show_routing -file output_files/S32.setup-paths.rpt
delete_timing_netlist
project_close
