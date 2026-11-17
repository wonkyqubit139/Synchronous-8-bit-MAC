# DEF -> GDS in magic, using the real cell layouts from the pdk

set pdk  $env(PDK_ROOT)/sky130A
set scl  $pdk/libs.ref/sky130_fd_sc_hd
drc off
gds readonly true
gds rescale false
gds read $scl/gds/sky130_fd_sc_hd.gds
lef read $scl/techlef/sky130_fd_sc_hd__nom.tlef
def read $env(DEF)
load mac8
select top cell
puts "BBOX [box values]"
# min area fix, only when signoff.sh asks for it
if {[info exists env(ECO)] && $env(ECO) eq "1"} {
    source [file join [file dirname [info script]] magic_eco.tcl]
    min_area_eco
}
gds write $env(OUT)/mac8.gds
save $env(OUT)/mac8.mag
quit -noprompt
