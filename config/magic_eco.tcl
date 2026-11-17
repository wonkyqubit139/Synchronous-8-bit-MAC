# fixes min area errors (met1-4 .6 rule) left by the router.
# each tiny island is extended with a wire of the router's own width, along that layer's routing direction.
# signoff.sh tries centre / plus / minus and keeps the one that passes both DRC and LVS.

proc min_area_eco {} {
    select top cell
    # error boxes written by magic_drc.tcl
    set byl [dict create]
    set fh [open $::env(ECO_BOXES)]
    foreach line [split [read $fh] "\n"] {
        if {[llength $line] == 5} { dict lappend byl [lindex $line 0] [lrange $line 1 4] }
    }
    close $fh
    # min area (um^2), direction, wire width for each layer
    array set rule {metal1 {0.083 h 0.14} metal2 {0.0676 v 0.14} metal3 {0.24 h 0.30} metal4 {0.24 v 0.30}}
    set shift [expr {[info exists ::env(ECO_SHIFT)] ? $::env(ECO_SHIFT) : "centre"}]
    set fixed 0
    dict for {layer boxes} $byl {
        # merge boxes that touch into one island
        set isl {}
        foreach b $boxes {
            lassign $b x0 y0 x1 y1
            set merged 0
            for {set i 0} {$i < [llength $isl]} {incr i} {
                lassign [lindex $isl $i] a0 b0 a1 b1
                if {$x0 <= $a1 + 0.01 && $x1 >= $a0 - 0.01 && $y0 <= $b1 + 0.01 && $y1 >= $b0 - 0.01} {
                    lset isl $i [list [expr {min($a0,$x0)}] [expr {min($b0,$y0)}] [expr {max($a1,$x1)}] [expr {max($b1,$y1)}]]
                    set merged 1; break
                }
            }
            if {!$merged} { lappend isl [list $x0 $y0 $x1 $y1] }
        }
        lassign $rule($layer) amin dir wmin
        set len [expr {1.1 * $amin / $wmin}]
        foreach r $isl {
            lassign $r x0 y0 x1 y1
            # horizontal layers grow in x, vertical layers in y
            if {$dir eq "h"} {
                set yc [expr {($y0+$y1)/2.0}]; set y0 [expr {$yc-$wmin/2.0}]; set y1 [expr {$yc+$wmin/2.0}]
                switch $shift {
                    plus    { set x1 [expr {$x0+$len}] }
                    minus   { set x0 [expr {$x1-$len}] }
                    default { set xc [expr {($x0+$x1)/2.0}]; set x0 [expr {$xc-$len/2.0}]; set x1 [expr {$xc+$len/2.0}] }
                }
            } else {
                set xc [expr {($x0+$x1)/2.0}]; set x0 [expr {$xc-$wmin/2.0}]; set x1 [expr {$xc+$wmin/2.0}]
                switch $shift {
                    plus    { set y1 [expr {$y0+$len}] }
                    minus   { set y0 [expr {$y1-$len}] }
                    default { set yc [expr {($y0+$y1)/2.0}]; set y0 [expr {$yc-$len/2.0}]; set y1 [expr {$yc+$len/2.0}] }
                }
            }
            # box needs 4 separate args, passing one string gave the wrong box
            box {*}[lmap v [list $x0 $y0 $x1 $y1] {format %.3fum $v}]
            puts "ECO box (internal units): [box values]"
            paint $layer
            puts [format "ECO %s island patched (%s): x %.3f..%.3f  y %.3f..%.3f um" $layer $shift $x0 $x1 $y0 $y1]
            incr fixed
        }
    }
    puts "ECO_PATCHES $fixed"
    select top cell
    return $fixed
}
