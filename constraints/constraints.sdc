# timing constraints, 250 MHz target

set CLK_PERIOD 4.0

create_clock -name clk -period $CLK_PERIOD [get_ports clk]
# margin for jitter and skew
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition  0.15 [get_clocks clk]

# inputs arrive / outputs needed 20% of the period after the edge (same as openlane default)
set IO_DELAY [expr {0.2 * $CLK_PERIOD}]
set non_clk_inputs [get_ports {reset enable A[*] B[*]}]
set_input_delay  $IO_DELAY -clock clk $non_clk_inputs
set_output_delay $IO_DELAY -clock clk [all_outputs]

# input driver and output load, also openlane defaults
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y $non_clk_inputs
set_load 0.0334 [all_outputs]
set_max_transition 1.5 [current_design]
set_max_fanout 10 [current_design]
