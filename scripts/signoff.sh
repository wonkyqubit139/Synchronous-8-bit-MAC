#!/bin/bash
# sign-off for a pnr run: GDS, magic DRC, extraction, netgen LVS

set -e
R=$(realpath $1); C=$(realpath $(dirname $0)/../config)
RC=$PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc
S=$R/signoff; rm -rf $S; mkdir -p $S/ext
DEF=$R/results/mac8.def OUT=$S magic -dnull -noconsole -rcfile $RC $C/magic_gds.tcl > $S/magic_gds.log 2>&1
GDS=$S/mac8.gds OUT=$S  magic -dnull -noconsole -rcfile $RC $C/magic_drc.tcl > $S/magic_drc.log 2>&1
ext() { rm -rf $S/ext; mkdir -p $S/ext
        GDS=$S/mac8.gds OUT=$S/ext magic -dnull -noconsole -rcfile $RC $C/magic_ext.tcl > $S/magic_ext.log 2>&1; }
lvs() { LAYOUT=$S/ext/mac8_extracted.spice VERILOG=$R/results/mac8_pnr_pwr.v OUT=$S \
        netgen -batch source $C/netgen_lvs.tcl > $S/netgen.log 2>&1; }
# the router sometimes leaves a tiny metal island below min area (metN.6). fix it in magic
# and only keep the patch if DRC and LVS both pass
if grep -qE "\(met[1-4]\.6\)" $S/drc.rpt; then
    cp $S/drc.rpt $S/drc_before_eco.rpt; cp $S/mac8.gds $S/mac8_before_eco.gds; cp $S/minarea_boxes.txt $S/minarea_boxes_before_eco.txt
    eco_ok=0
    for sh in centre plus minus; do
        ECO=1 ECO_SHIFT=$sh ECO_BOXES=$S/minarea_boxes_before_eco.txt DEF=$R/results/mac8.def OUT=$S magic -dnull -noconsole -rcfile $RC $C/magic_gds.tcl > $S/magic_eco.log 2>&1
        GDS=$S/mac8.gds OUT=$S magic -dnull -noconsole -rcfile $RC $C/magic_drc.tcl > $S/magic_drc.log 2>&1
        ext; lvs
        if grep -q "Total DRC violations: 0" $S/drc.rpt && grep -q "Circuits match uniquely" $S/lvs.rpt; then
            echo "ECO : placement '$sh' passes DRC and LVS"; grep -E "^ECO .*patched" $S/magic_eco.log; eco_ok=1; break
        fi
        echo "ECO : placement '$sh' rejected (DRC or LVS failed)"
    done
    if [ $eco_ok = 0 ]; then
        echo "ECO : no placement passed; reporting the un-patched layout"
        cp $S/mac8_before_eco.gds $S/mac8.gds; cp $S/drc_before_eco.rpt $S/drc.rpt; ext; lvs
    fi
else
    ext; lvs
fi
echo "GDS : $(ls -la $S/mac8.gds | awk '{print $5}') bytes"
echo "DRC : $(grep 'Total DRC violations' $S/drc.rpt)"
echo "LVS : $(grep 'Final result' $S/lvs.rpt | tail -1)"
