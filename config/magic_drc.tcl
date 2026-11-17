# full DRC on the gds, writes drc.rpt

gds read $env(GDS)
load mac8
select top cell
drc euclidean on
drc style drc(full)
drc check
drc catchup
set n [drc list count total]
set f [open $env(OUT)/drc.rpt w]
puts $f "Magic DRC report for mac8   style: drc(full)"
puts $f "GDS: $env(GDS)"
puts $f "-------------------------------------------------------------"
set why [drc listall why]
foreach {rule boxes} $why { puts $f "$rule : [llength $boxes] boxes" }
puts $f "-------------------------------------------------------------"
puts $f "Total DRC violations: $n"
close $f
# also save the min area error boxes (in um) for magic_eco.tcl
set fb [open $env(OUT)/minarea_boxes.txt w]
foreach {rule boxes} $why {
    if {[regexp {\((met[1-4])\.6\)} $rule -> m]} {
        foreach b $boxes { puts $fb "metal[string index $m 3] [lmap v $b {format %.3f [expr {$v * 0.005}]}]" }
    }
}
close $fb
puts "DRC_COUNT $n"
quit -noprompt
