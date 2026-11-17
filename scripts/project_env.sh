#!/bin/bash
# sets up paths, source it: source scripts/project_env.sh
# only PDK_ROOT is needed (the folder that contains sky130A)

if [ -z "$PDK_ROOT" ] || [ ! -d "$PDK_ROOT/sky130A" ]; then
    echo "ERROR: set PDK_ROOT to the directory that contains sky130A/ (now: '${PDK_ROOT}')" >&2
    return 1 2>/dev/null || exit 1
fi
export PROJ=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export SKY130A=$PDK_ROOT/sky130A
export SCL=$SKY130A/libs.ref/sky130_fd_sc_hd
export STA_LIB=$SCL/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
export BUILD=$PROJ/build
mkdir -p "$BUILD"
# synthesis lib = tt lib minus the cells openlane doesn't allow
export SYNTH_LIB=$BUILD/synth_tt.lib
if [ ! -s "$SYNTH_LIB" ]; then
    X=$PROJ/config/pdk_extras
    python3 "$PROJ/scripts/liberty_filter.py" "$STA_LIB" "$SYNTH_LIB" --exclude \
        "$X/no_synth.cells" "$X/drc_exclude.cells" || return 1 2>/dev/null
fi
# use standalone sta if it's installed, otherwise openroad (it has opensta inside)
if command -v sta >/dev/null 2>&1; then export STA=sta; else export STA=openroad; fi
