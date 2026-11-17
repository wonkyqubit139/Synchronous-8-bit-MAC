#!/bin/bash
# runs the whole flow or one step: ./run_all.sh check|sim|synth|pnr|signoff|postsim|all
# everything goes into build/, the reference results in reports/ layout/ verification/ are not touched

set -u
cd "$(dirname "$0")"
source scripts/project_env.sh || exit 1
step=${1:-all}

# are all the tools and pdk files there?
do_check() {
    local ok=1
    for t in iverilog vvp yosys openroad magic netgen python3; do
        if command -v $t >/dev/null; then printf "  %-9s OK   %s\n" $t "$(command -v $t)"
        else printf "  %-9s MISSING\n" $t; ok=0; fi
    done
    echo "  STA via   $STA"
    for f in "$STA_LIB" "$SCL/lef/sky130_fd_sc_hd.lef" "$SCL/gds/sky130_fd_sc_hd.gds" \
             "$SKY130A/libs.tech/magic/sky130A.magicrc" "$SKY130A/libs.tech/netgen/sky130A_setup.tcl"; do
        [ -f "$f" ] && echo "  PDK file  OK   $f" || { echo "  PDK file  MISSING $f"; ok=0; }
    done
    [ $ok = 1 ] && echo "CHECK: PASS" || { echo "CHECK: FAIL"; exit 1; }
}

# RTL sim of all 8 variants
do_sim() {
    mkdir -p $BUILD/sim; local fail=0
    for c in 1:0:0 2:0:0 3:0:0 1:1:0 2:1:0 3:1:0 2:1:1 3:1:1; do
        IFS=: read s f g <<< "$c"; log=$BUILD/sim/rtl_s${s}_f${f}_g${g}.log
        rm -f $BUILD/sim/tb.vvp
        iverilog -g2005 -Wall -P mac8_tb.STAGES=$s -P mac8_tb.FAST_ARITH=$f -P mac8_tb.CLK_GATE=$g \
            -o $BUILD/sim/tb.vvp tb/mac8_tb.v rtl/mac8.v 2> $BUILD/sim/compile_s${s}_f${f}_g${g}.log
        if [ ! -f $BUILD/sim/tb.vvp ]; then echo "  STAGES=$s FAST_ARITH=$f CLK_GATE=$g : COMPILE FAILED"; fail=1; continue; fi
        (cd $BUILD/sim && vvp -n tb.vvp > $log && mv -f mac8_tb.vcd mac8_tb_s${s}_f${f}_g${g}.vcd)
        r=$(grep -o "RESULT: .*" $log || echo "RESULT: NO RESULT LINE")
        echo "  STAGES=$s FAST_ARITH=$f CLK_GATE=$g : $r"; echo "$r" | grep -q PASS || fail=1
    done
    [ $fail = 0 ] && echo "SIM: PASS" || { echo "SIM: FAIL"; exit 1; }
}

# synthesis + STA + gate level sim + power for 9 configs
do_synth() {
    (cd scripts && WORK=$BUILD/work bash run_sweep.sh) | tee $BUILD/synth_sweep.txt
    grep -q "FAIL\|ERROR\|FAILED" $BUILD/synth_sweep.txt && { echo "SYNTH: FAIL"; exit 1; }
    echo "SYNTH: PASS (compare build/synth_sweep.txt with reports/synthesis.rpt)"
}

# place and route the final netlist
do_pnr() {
    [ -s $BUILD/work/final/mac8_netlist.v ] || { echo "run './run_all.sh synth' first"; exit 1; }
    mkdir -p $BUILD/pnr; rm -rf $BUILD/pnr/run
    CFG=$PROJ/config NETLIST=$BUILD/work/final/mac8_netlist.v SDC=$PROJ/constraints/constraints.sdc \
        RUN=$BUILD/pnr/run openroad -no_splash -exit config/pnr_flow.tcl > $BUILD/pnr/openroad.log 2>&1
    grep -E "^\[ERROR" $BUILD/pnr/openroad.log && { echo "PNR: FAIL (see build/pnr/openroad.log)"; exit 1; }
    cat $BUILD/pnr/run/reports/6_signoff_summary.txt; echo "PNR: done"
}

# GDS, DRC, LVS
do_signoff() {
    [ -s $BUILD/pnr/run/results/mac8.def ] || { echo "run './run_all.sh pnr' first"; exit 1; }
    bash scripts/signoff.sh $BUILD/pnr/run
    echo "If DRC is not 0, see the guide, Stage 4, test T6."
}

# sim of the routed netlist + power with real parasitics, at 75% and 100% enable
do_postsim() {
    [ -s $BUILD/pnr/run/results/mac8_pnr.v ] || { echo "run './run_all.sh pnr' first"; exit 1; }
    for e in 75 100; do
        d=$BUILD/postsim/en$e; rm -rf $d; mkdir -p $d
        r=$(cd scripts && EN_PCT=$e NETLIST=$BUILD/pnr/run/results/mac8_pnr.v bash gls.sh $d 2)
        (cd scripts && LIB=$STA_LIB NET=$BUILD/pnr/run/results/mac8_pnr.v SDC=$PROJ/constraints/constraints.sdc \
            VCD=$d/mac8_tb.vcd SPEF=$BUILD/pnr/run/results/mac8.spef OUT=$d $STA -no_splash -exit power_vcd.tcl > $d/power.log 2>&1)
        p=$(awk '/^Total/{printf "%.3f", $5*1000}' $d/power_vcd.rpt 2>/dev/null)
        echo "  enable ${e}%: $r   power ${p:-?} mW"
    done
}

case $step in
    check) do_check ;; sim) do_sim ;; synth) do_synth ;; pnr) do_pnr ;; signoff) do_signoff ;; postsim) do_postsim ;;
    all) do_check; do_sim; do_synth; do_pnr; do_signoff; do_postsim ;;
    *) echo "usage: ./run_all.sh check|sim|synth|pnr|signoff|postsim|all"; exit 1 ;;
esac
