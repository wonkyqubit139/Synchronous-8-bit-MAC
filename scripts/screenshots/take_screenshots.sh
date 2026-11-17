#!/bin/bash
# screenshots of the real tool windows (openroad gui, klayout, gtkwave) for results/screenshots
# run after ./run_all.sh pnr and sim. starts a virtual display if there isn't one (needs Xvfb, openbox, xdotool, imagemagick)

set -u; cd "$(dirname "$0")/../.."; X=$PWD/scripts/screenshots; O=${OUT:-build/screenshots}; mkdir -p $O
[ -n "${PDK_ROOT:-}" ] || { echo "set PDK_ROOT first"; exit 1; }; ln -sfn $PDK_ROOT build/pdk_link
if [ -z "${DISPLAY:-}" ]; then
    Xvfb :99 -screen 0 1600x1000x24 -nolisten tcp >/dev/null 2>&1 & sleep 2; export DISPLAY=:99
    openbox >/dev/null 2>&1 & sleep 1
fi
# wait for the window, close klayout's tip popup if it shows up, resize and grab the screen
grab() {
    sleep $3; local w; w=$(xdotool search --onlyvisible --name "$1" | head -1)
    for t in $(xdotool search --onlyvisible --name "^Tip$" 2>/dev/null); do xdotool windowactivate --sync $t key Return; done
    xdotool windowactivate --sync $w windowsize $w 1600 1000 windowmove $w 0 0; sleep 3
    import -window root $2; echo "wrote $2"
}
export QT_QPA_PLATFORM=xcb
for s in "floorplan 1_floorplan.def 01_floorplan" "placement 2_placement.def 02_placement" \
         "cts 3_cts.def 03_clock_tree" "route x 04_routing"; do
    set -- $s; STAGE=$1 STAGE_DEF=$2 openroad -no_splash -gui $X/or_view.tcl > $O/openroad_$1.log 2>&1 &
    grab OpenROAD $O/$3.png 14; pkill -f "openroad -no_splash -gui"; sleep 1
done
klayout -nc -rd gds=$PWD/layout/mac8.gds -rd lyp=$PWD/build/pdk_link/sky130A/libs.tech/klayout/tech/sky130A.lyp \
        -rm $X/kl_open.py > $O/klayout.log 2>&1 &
grab KLayout $O/05_final_layout.png 12; pkill klayout
V=build/sim/mac8_tb_s2_f1_g1.vcd
for v in "06_waveform_reset_accumulate_hold 0 70000" "07_waveform_random 2000000 2060000"; do
    set -- $v; T0=$2 T1=$3 gtkwave -S $X/gtk.tcl $V > $O/gtkwave.log 2>&1 &
    grab GTKWave $O/$1.png 8; pkill gtkwave; sleep 1
done
echo "Screenshots in $O/ (compare with results/screenshots/)"
