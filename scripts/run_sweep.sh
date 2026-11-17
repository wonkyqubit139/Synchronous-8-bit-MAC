#!/bin/bash
# synthesis + STA + gate level sim + power for each architecture config


# delay oriented abc script, used for the final design
DELAY_ABC="fx; mfs; strash; drf -l; balance; dc2; balance; strash; map -D 4000 -B 0.9; topo; stime -p"
# name:STAGES:FAST_ARITH:CLK_GATE:abc
CONFIGS=${CONFIGS:-"s1_f0_g0:1:0:0:default s2_f0_g0:2:0:0:default s3_f0_g0:3:0:0:default
 s1_f1_g0:1:1:0:default s2_f1_g0:2:1:0:default s3_f1_g0:3:1:0:default
 s2_f1_g1:2:1:1:default s3_f1_g1:3:1:1:default final:2:1:1:delay"}
for c in $CONFIGS; do
  IFS=: read n s f g a <<< "$c"; d=${WORK:-../work}/$n; rm -rf $d; mkdir -p $d
  abc=default; [ "$a" = delay ] && abc="$DELAY_ABC"
  ABC_SCRIPT="$abc" STAGES=$s FAST=$f CG=$g FULL_LIB=$STA_LIB LIB=$SYNTH_LIB OUT=$d CLK_PS=4000 \
      yosys -q -c synth.ys.tcl > $d/yosys.log 2>&1 || { echo "$n: SYNTH FAILED"; continue; }
  # area with the full library (the synthesis lib has some cells removed)
  yosys -q -p "read_liberty -lib $STA_LIB; read_verilog $d/mac8_netlist.v; hierarchy -top mac8; tee -q -o $d/stat_full.rpt stat -liberty $STA_LIB" > /dev/null 2>&1
  LIB=$STA_LIB NET=$d/mac8_netlist.v SDC=$PROJ/constraints/constraints.sdc OUT=$d ACT=0.1 \
      $STA -no_splash -exit sta.tcl > $d/sta.log 2>&1
  rm -f $d/gls.vvp
  # gate level sim, also gives the vcd for power
  LIB=$STA_LIB bash gls.sh $d $s > $d/gls_result.txt
  LIB=$STA_LIB NET=$d/mac8_netlist.v SDC=$PROJ/constraints/constraints.sdc VCD=$d/mac8_tb.vcd OUT=$d \
      $STA -no_splash -exit power_vcd.tcl > $d/power_vcd.log 2>&1
  if [ ! -s $d/summary.txt ] || [ ! -s $d/power_vcd.rpt ]; then echo "$n: STA FAILED (see $d/sta.log)"; continue; fi
  printf "%-9s area=%7.1f wns=%8s r2r=%7s Pvl=%.3f Pvcd=%.3f %s\n" $n \
    $(grep 'Chip area' $d/stat_full.rpt | awk '{print $NF}') $(awk '/wns_setup/{print $2}' $d/summary.txt) \
    $(grep slack $d/timing_reg2reg.rpt | awk '{print $1}') \
    $(awk '/^Total/{print $5*1000}' $d/power.rpt) $(awk '/^Total/{print $5*1000}' $d/power_vcd.rpt) "$(grep -oE 'PASS|FAIL' $d/gls_result.txt || echo GLS-ERROR)"
done
