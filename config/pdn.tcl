# power grid: met1 rails along the cell rows + vertical met4 straps, connected with vias

add_global_connection -net VPWR -pin_pattern {^VPWR$} -power
# VPB/VNB are the well/body pins, tie them to the supplies too
add_global_connection -net VPWR -pin_pattern {^VPB$}
add_global_connection -net VGND -pin_pattern {^VGND$} -ground
add_global_connection -net VGND -pin_pattern {^VNB$}
global_connect
set_voltage_domain -power VPWR -ground VGND
define_pdn_grid -name stdcell -pins met4 -starts_with POWER
add_pdn_stripe -grid stdcell -layer met1 -width 0.48 -followpins
add_pdn_stripe -grid stdcell -layer met4 -width 1.6 -pitch 27.2 -offset 13.6
add_pdn_connect -grid stdcell -layers {met1 met4}
pdngen
