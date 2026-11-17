// simple model of the sky130 clock gate cell for gate level sim
// (yosys can't make a model for it from the liberty file)

`timescale 1ns/1ps
module sky130_fd_sc_hd__dlclkp_1 (input CLK, input GATE, output GCLK);
    reg en_l;
    always @(CLK or GATE) if (!CLK) en_l = GATE;
    assign GCLK = CLK & en_l;
endmodule
