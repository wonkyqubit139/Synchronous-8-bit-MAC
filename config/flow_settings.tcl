# paths and settings used by pnr_flow.tcl

set PDK          $::env(PDK_ROOT)/sky130A
set SCL          $PDK/libs.ref/sky130_fd_sc_hd
set OL           $PDK/libs.tech/openlane
set TECH_LEF     $SCL/techlef/sky130_fd_sc_hd__nom.tlef
set CELL_LEF     $SCL/lef/sky130_fd_sc_hd.lef
set CELL_EF_LEF  $SCL/lef/sky130_ef_sc_hd.lef
set LIB_TT       $SCL/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
# extraction rules (uses the copy in pdk_extras if the pdk doesn't have it)
set RCX_RULES    $OL/rules.openrcx.sky130A.nom.calibre
if {![file exists $RCX_RULES]} { set RCX_RULES $::env(CFG)/pdk_extras/rules.openrcx.sky130A.nom.calibre }
set TRACKS_TCL   $::env(CFG)/tracks.tcl

# 100x100 um die, core inset a bit to leave room for the pins
set DIE_AREA     {0 0 100 100}
set CORE_AREA    {5.52 5.44 94.30 94.56}
set PL_DENSITY   0.72  ;# target placement density

# clock tree buffers, smaller than the openlane default (see pnr_flow.tcl)
set CTS_ROOT_BUF sky130_fd_sc_hd__clkbuf_4
set CTS_BUF_LIST {sky130_fd_sc_hd__clkbuf_2 sky130_fd_sc_hd__clkbuf_1}

# decaps first, then plain fill
set FILL_CELLS   {sky130_ef_sc_hd__decap_12 sky130_fd_sc_hd__decap_8 sky130_fd_sc_hd__decap_6
                  sky130_fd_sc_hd__decap_4 sky130_fd_sc_hd__decap_3 sky130_fd_sc_hd__fill_2
                  sky130_fd_sc_hd__fill_1}

# dont_use list = openlane's drc_exclude.cells
set DONT_USE_CELLS {}
set fh [open $::env(CFG)/pdk_extras/drc_exclude.cells]
foreach l [split [read $fh] "\n"] { if {[string trim $l] ne ""} { lappend DONT_USE_CELLS [string trim $l] } }
close $fh
