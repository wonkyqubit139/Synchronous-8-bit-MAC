# loads one pnr stage into the openroad gui for a screenshot (STAGE = floorplan / placement / cts / route)

set S build/pdk_link/sky130A/libs.ref/sky130_fd_sc_hd
set st $::env(STAGE)
if {$st eq "route"} {
    read_db build/pnr/run/results/mac8.odb
} else {
    read_lef $S/techlef/sky130_fd_sc_hd__nom.tlef
    read_lef $S/lef/sky130_fd_sc_hd.lef
    read_lef $S/lef/sky130_ef_sc_hd.lef
    read_def build/pnr/run/results/$::env(STAGE_DEF)
}
# hide the side panels so the layout gets more room
catch {gui::hide_widget "Charts"}
catch {gui::hide_widget "Inspector"}
catch {gui::hide_widget "Hierarchy Browser"}
catch {gui::hide_widget "Timing Report"}
switch $st {
    cts {
        read_liberty $S/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
        read_sdc constraints/constraints.sdc
        # highlight the clock nets, CTS buffers and clock gates
        foreach n [get_nets -hierarchical *clk*] { catch {gui::highlight_net [get_full_name $n] 0} }
        catch {select -type Inst -name clkbuf* -highlight 1}
        catch {select -type Inst -name *u_icg* -highlight 2}
    }
}
gui::fit
