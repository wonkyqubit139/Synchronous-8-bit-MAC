#!/bin/bash
# run after ./run_all.sh all, prints PASS/FAIL for each test
# REF lines just compare with my reference run (numbers can shift a bit with other tool versions)

cd "$(dirname "$0")"; B=build; pass=0; fail=0
# small helpers
ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }
chk()  { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
num()  { awk -v k="$2" '$1==k{print $2}' "$1" 2>/dev/null; }
ref()  {
    awk -v n="$1" -v a="$2" -v b="$3" -v t="$4" 'BEGIN{ if (a=="") {printf "  REF   %-34s mine=?  reference=%s\n", n, b; exit}
        d=(b==0)?(a-b):(a-b)/((b<0)?-b:b)*100; s=(a==b)?"MATCH":((d<t && d>-t)?"CLOSE":"DIFFERENT");
        printf "  REF   %-34s mine=%-9s reference=%-9s %s\n", n, a, b, s }'; }

echo "T1  Project files present"
for f in rtl/mac8.v tb/mac8_tb.v tb/sky130_icg_model.v constraints/constraints.sdc config/pnr_flow.tcl \
         config/flow_settings.tcl config/pdn.tcl config/magic_gds.tcl config/magic_drc.tcl config/magic_eco.tcl \
         config/netgen_lvs.tcl scripts/project_env.sh scripts/synth.ys.tcl scripts/gls.sh scripts/signoff.sh \
         reports/synthesis.rpt reports/timing.rpt reports/area.rpt reports/power.rpt layout/mac8.gds \
         verification/drc.rpt verification/lvs.rpt report.pdf; do
    [ -s "$f" ] || bad "missing or empty: $f"
done
n=$(ls results/screenshots/*.png 2>/dev/null | wc -l); chk "all required files present, $n screenshots (expect 8)" "[ $fail = 0 ] && [ $n = 8 ]"

echo "T2  RTL compiles"
chk "iverilog compiles rtl/mac8.v + tb (final configuration)" "iverilog -g2005 -Wall -o /tmp/mac8_v.vvp tb/mac8_tb.v rtl/mac8.v 2>/tmp/mac8_w.txt"
echo "        warnings: $(grep -ci warning /tmp/mac8_w.txt) (timescale-inheritance warnings are harmless)"

echo "T3  RTL simulation, 8 architecture variants"
n=$(grep -l "RESULT: PASS" $B/sim/rtl_*.log 2>/dev/null | wc -l)
chk "8 of 8 variants print RESULT: PASS (found $n)" "[ $n = 8 ]"

echo "T4  Synthesis (9 configurations)"
for c in s1_f0_g0 final; do
    w=$B/work/$c
    chk "$c: gate-level netlist passes the testbench" "grep -q 'RESULT: PASS' $w/gls.log 2>/dev/null"
done
bw=$(num $B/work/s1_f0_g0/summary.txt wns_setup); fr=$(awk '/slack/{print $1; exit}' $B/work/final/timing_reg2reg.rpt 2>/dev/null)
chk "baseline FAILS 250 MHz as the assignment expects (WNS $bw ns < 0)" "awk 'BEGIN{exit !($bw < 0)}'"
chk "final design: accumulator loop meets 4 ns (reg-to-reg slack $fr ns >= 0)" "awk 'BEGIN{exit !($fr >= 0)}'"
fa=$(awk '/Chip area/{printf "%.1f",$NF}' $B/work/final/stat_full.rpt 2>/dev/null); ra=$(awk '/Chip area/{printf "%.1f",$NF}' reports/synth_sweep/final/stat_full.rpt)
ref "final synthesis area (um^2)" "$fa" "$ra" 5
ref "baseline setup WNS (ns)" "$bw" "$(num reports/synth_sweep/s1_f0_g0/summary.txt wns_setup)" 5

echo "T5  Place and route"
P=$B/pnr/run/reports; ws=$(num $P/6_signoff_summary.txt wns_setup_ns); wh=$(num $P/6_signoff_summary.txt wns_hold_ns)
chk "post-route setup slack $ws ns >= 0 (meets 4 ns / 250 MHz)" "awk 'BEGIN{exit !($ws >= 0)}'"
chk "post-route hold slack $wh ns >= 0" "awk 'BEGIN{exit !($wh >= 0)}'"
chk "detailed router reports 0 DRC violations" "[ ! -s $P/5_route_drc.rpt ]"
chk "antenna checker reports 0 net violations" "grep -q 'Found 0 net violations' $B/pnr/openroad.log"
da=$(awk '/DIEAREA/{gsub(/[()]/,""); print ($4-$2)*($5-$3)/1e6; exit}' $B/pnr/run/results/mac8.def)
chk "die area $da um^2 <= 10,000" "awk 'BEGIN{exit !($da <= 10000)}'"
ref "post-route setup slack (ns)" "$ws" "$(num reports/pnr/6_signoff_summary.txt wns_setup_ns)" 15
ref "post-route hold slack (ns)" "$wh" "$(num reports/pnr/6_signoff_summary.txt wns_hold_ns)" 50

echo "T6  Physical verification (Magic DRC, Netgen LVS)"
S=$B/pnr/run/signoff
chk "Magic full-deck DRC: $(grep -o 'Total DRC violations: [0-9]*' $S/drc.rpt)" "grep -q 'Total DRC violations: 0' $S/drc.rpt"
chk "Netgen LVS: $(grep 'Final result' $S/lvs.rpt | tail -1 | sed 's/Final result: //')" "grep -q 'Circuits match uniquely' $S/lvs.rpt"
[ -f $S/drc_before_eco.rpt ] && echo "        note: min-area fix applied in Magic ($(grep -c . $S/minarea_boxes_before_eco.txt) error boxes before it)"

echo "T7  Routed netlist: simulation and power at 250 MHz"
for e in 75 100; do chk "routed netlist passes the testbench at ${e}% enable" "grep -q 'RESULT: PASS' $B/postsim/en$e/gls.log 2>/dev/null"; done
p75=$(awk '/^Total/{printf "%.3f",$5*1000}' $B/postsim/en75/power_vcd.rpt 2>/dev/null)
p100=$(awk '/^Total/{printf "%.3f",$5*1000}' $B/postsim/en100/power_vcd.rpt 2>/dev/null)
chk "typical power (75% enable) $p75 mW <= 2 mW" "awk 'BEGIN{exit !(\"$p75\"+0 > 0 && $p75 <= 2)}'"
echo "  INFO  worst-case power (100% enable, random operands every cycle): $p100 mW (reference 2.006, 0.3% over 2 mW)"
ref "typical power (mW)" "$p75" "$(awk '/^Total/{printf "%.3f",$5*1000}' reports/pnr/power_postlayout_vcd_en75.rpt)" 5

echo; echo "SUMMARY: $pass passed, $fail failed"
[ $fail = 0 ] && echo "VERIFY: PASS" || { echo "VERIFY: FAIL"; exit 1; }
