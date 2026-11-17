# LVS: extracted layout vs post-route verilog (with power pins) + sky130 cell spice

set pdk $env(PDK_ROOT)/sky130A
set scl $pdk/libs.ref/sky130_fd_sc_hd
set layout [readnet spice $env(LAYOUT)]
set source [readnet spice $scl/spice/sky130_fd_sc_hd.spice]
foreach f [glob $scl/spice/sky130_ef_sc_hd__*.spice] { readnet spice $f $source }
readnet verilog $env(VERILOG) $source
lvs "$layout mac8" "$source mac8" $pdk/libs.tech/netgen/sky130A_setup.tcl $env(OUT)/lvs.rpt
