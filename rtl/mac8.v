// 8-bit unsigned MAC (ELL734)
// Y <= Y + A*B on every clock with enable=1, sync active-high reset, 20-bit accumulator (wraps around)
// STAGES = pipeline depth (1 to 3), and FAST_ARITH = 0 uses plain * and + (baseline),
// FAST_ARITH = 1 uses my carry-save multiplier + kogge-stone adder, and CLK_GATE = 1 adds clock gating
// defaults are the final design that went through place and route

`default_nettype none

module mac8 #(
    parameter integer STAGES     = 2,
    parameter integer FAST_ARITH = 1,
    parameter integer CLK_GATE   = 1
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire [7:0]  A,
    input  wire [7:0]  B,
    output wire [19:0] Y
);

    // Y is just the accumulator register
    reg [19:0] acc;
    assign Y = acc;

    generate
    // FAST_ARITH = 0: behavioural version, yosys infers the multiplier and adder
    if (FAST_ARITH == 0) begin : g_behav
    // unpipelined baseline, multiply and add in the same cycle
    if (STAGES == 1) begin : g_baseline
        // product has to be its own 16-bit wire, {4'd0, A*B} directly truncates it to 8 bits (the tb caught this)
        wire [15:0] prod = A * B;
        always @(posedge clk) begin
            if (reset)
                acc <= 20'd0;
            else if (enable)
                acc <= acc + {4'd0, prod};
        end
    end
    // 2 stages: register the product, add it next cycle. v1_q is the valid bit of the op in flight
    else if (STAGES == 2) begin : g_pipe2
        reg [15:0] prod_q;
        reg        v1_q;

        always @(posedge clk) begin
            if (reset)
                v1_q <= 1'b0;
            else
                v1_q <= enable;
            if (enable)  // product reg only loads when there is an op (operand isolation)
                prod_q <= A * B;
        end

        always @(posedge clk) begin
            if (reset)
                acc <= 20'd0;
            else if (v1_q)
                acc <= acc + {4'd0, prod_q};
        end
    end
    // 3 stages: split the multiply into two 8x4 halves, combine them, then accumulate
    else begin : g_pipe3
        reg [11:0] pl_q, ph_q;
        reg [15:0] prod_q;
        reg        v1_q, v2_q;

        always @(posedge clk) begin
            if (reset) begin
                v1_q <= 1'b0;
                v2_q <= 1'b0;
            end else begin
                v1_q <= enable;
                v2_q <= v1_q;
            end
            if (enable) begin
                pl_q <= A * B[3:0];
                ph_q <= A * B[7:4];
            end
            if (v1_q)
                prod_q <= {4'd0, pl_q} + {ph_q, 4'd0};
        end

        always @(posedge clk) begin
            if (reset)
                acc <= 20'd0;
            else if (v2_q)
                acc <= acc + {4'd0, prod_q};
        end
    end

    // FAST_ARITH = 1: partial products -> carry-save tree, product kept as sum + carry so the
    // multiplier never needs its own carry-propagate adder
    end else begin : g_fast
        wire [15:0] r0, r1, r2, r3, r4, r5, r6, r7;
        pp_rows u_pp (.A(A), .B(B), .r0(r0), .r1(r1), .r2(r2), .r3(r3),
                      .r4(r4), .r5(r5), .r6(r6), .r7(r7));

        // CSA levels 1 and 2: 8 rows -> 6 -> 4
        wire [15:0] s1a, c1a, s1b, c1b, s2a, c2a, s2b, c2b;
        csa #(16) u_l1a (.x(r0),  .y(r1),  .z(r2),  .s(s1a), .c(c1a));
        csa #(16) u_l1b (.x(r3),  .y(r4),  .z(r5),  .s(s1b), .c(c1b));
        csa #(16) u_l2a (.x(s1a), .y(c1a), .z(s1b), .s(s2a), .c(c2a));
        csa #(16) u_l2b (.x(c1b), .y(r6),  .z(r7),  .s(s2b), .c(c2b));

        // level 2 outputs, only registered in the 3 stage version
        wire [15:0] q_s2a, q_c2a, q_s2b, q_c2b;

        // levels 3 and 4: 4 -> 3 -> 2, so ps + pc = A*B
        wire [15:0] s3, c3, ps, pc;
        csa #(16) u_l3 (.x(q_s2a), .y(q_c2a), .z(q_s2b), .s(s3), .c(c3));
        csa #(16) u_l4 (.x(s3),    .y(c3),    .z(q_c2b), .s(ps), .c(pc));

        // product (sum, carry) and its valid bit as seen by the accumulate stage
        wire [15:0] q_ps, q_pc;
        wire        v_acc;

        // accumulate: acc + ps + pc = one more CSA level + 20-bit kogge-stone adder
        // this loop (acc -> adder -> acc) is the critical path and can't be pipelined
        wire [19:0] as, ac, acc_nxt;
        csa #(20) u_acc_csa (.x(acc), .y({4'd0, q_ps}), .z({4'd0, q_pc}),
                             .s(as), .c(ac));
        ks_adder #(20) u_ks (.a(as), .b(ac), .s(acc_nxt));

        // 1 stage: no pipeline registers
        if (STAGES == 1) begin : g_f1
            assign {q_s2a, q_c2a, q_s2b, q_c2b} = {s2a, c2a, s2b, c2b};
            assign {q_ps, q_pc} = {ps, pc};
            assign v_acc = enable;
        // 2 stages (final design): register ps/pc after the CSA tree
        end else if (STAGES == 2) begin : g_f2
            assign {q_s2a, q_c2a, q_s2b, q_c2b} = {s2a, c2a, s2b, c2b};
            reg [15:0] ps_q, pc_q;
            reg        v_q;
            always @(posedge clk)
                if (reset) v_q <= 1'b0; else v_q <= enable;
            // gate the clock of the 32 product flops instead of putting a hold mux in front of each
            if (CLK_GATE) begin : g_cg
                wire gclk_p;
                clock_gate u_cg_p (.clk(clk), .en(enable), .gclk(gclk_p));
                always @(posedge gclk_p) begin ps_q <= ps; pc_q <= pc; end
            end else begin : g_nocg
                always @(posedge clk)
                    if (enable) begin ps_q <= ps; pc_q <= pc; end
            end
            assign {q_ps, q_pc} = {ps_q, pc_q};
            assign v_acc = v_q;
        // 3 stages: one more register cut after CSA level 2
        end else begin : g_f3
            reg [15:0] s2a_q, c2a_q, s2b_q, c2b_q, ps_q, pc_q;
            reg        v1_q, v2_q;
            always @(posedge clk)
                if (reset) begin v1_q <= 1'b0; v2_q <= 1'b0; end
                else       begin v1_q <= enable; v2_q <= v1_q; end
            if (CLK_GATE) begin : g_cg
                wire gclk_1, gclk_2;
                clock_gate u_cg_1 (.clk(clk), .en(enable), .gclk(gclk_1));
                clock_gate u_cg_2 (.clk(clk), .en(v1_q),   .gclk(gclk_2));
                always @(posedge gclk_1) begin
                    s2a_q <= s2a; c2a_q <= c2a; s2b_q <= s2b; c2b_q <= c2b;
                end
                always @(posedge gclk_2) begin ps_q <= ps; pc_q <= pc; end
            end else begin : g_nocg
                always @(posedge clk) begin
                    if (enable) begin
                        s2a_q <= s2a; c2a_q <= c2a; s2b_q <= s2b; c2b_q <= c2b;
                    end
                    if (v1_q) begin ps_q <= ps; pc_q <= pc; end
                end
            end
            assign {q_s2a, q_c2a, q_s2b, q_c2b} = {s2a_q, c2a_q, s2b_q, c2b_q};
            assign {q_ps, q_pc} = {ps_q, pc_q};
            assign v_acc = v2_q;
        end

        // accumulator clock only ticks when an op finishes or on reset, so idle cycles cost almost no clock power
        if (CLK_GATE && STAGES > 1) begin : g_acc_cg
            wire gclk_a;
            clock_gate u_cg_a (.clk(clk), .en(v_acc | reset), .gclk(gclk_a));
            always @(posedge gclk_a)
                acc <= reset ? 20'd0 : acc_nxt;
        end else begin : g_acc
            always @(posedge clk) begin
                if (reset)
                    acc <= 20'd0;
                else if (v_acc)
                    acc <= acc_nxt;
            end
        end
    end
    endgenerate

endmodule

`default_nettype wire

`default_nettype none

// 3:2 compressor (a row of full adders): x + y + z = s + c
module csa #(parameter integer W = 16) (
    input  wire [W-1:0] x, y, z,
    output wire [W-1:0] s, c
);
    wire [W-1:0] maj = (x & y) | (x & z) | (y & z);
    assign s = x ^ y ^ z;
    assign c = {maj[W-2:0], 1'b0};
endmodule

// kogge-stone prefix adder, log2(W) levels of generate/propagate instead of a ripple chain
module ks_adder #(parameter integer W = 20) (
    input  wire [W-1:0] a, b,
    output wire [W-1:0] s
);
    localparam integer L = $clog2(W);
    wire [W-1:0] g [0:L];
    wire [W-1:0] p [0:L];
    assign g[0] = a & b;
    assign p[0] = a ^ b;

    genvar lv, i;
    generate
        for (lv = 0; lv < L; lv = lv + 1) begin : g_level
            for (i = 0; i < W; i = i + 1) begin : g_bit
                if (i >= (1 << lv)) begin : g_op
                    assign g[lv+1][i] = g[lv][i] | (p[lv][i] & g[lv][i-(1<<lv)]);
                    assign p[lv+1][i] = p[lv][i] & p[lv][i-(1<<lv)];
                end else begin : g_pass
                    assign g[lv+1][i] = g[lv][i];
                    assign p[lv+1][i] = p[lv][i];
                end
            end
        end
    endgenerate
    // carry into bit i is the group generate of all the bits below it
    assign s = p[0] ^ {g[L][W-2:0], 1'b0};
endmodule

// partial product rows, row j = (A & B[j]) shifted left by j
module pp_rows (
    input  wire [7:0]  A, B,
    output wire [15:0] r0, r1, r2, r3, r4, r5, r6, r7
);
    assign r0 = {8'd0, A & {8{B[0]}}};
    assign r1 = {7'd0, A & {8{B[1]}}, 1'b0};
    assign r2 = {6'd0, A & {8{B[2]}}, 2'b0};
    assign r3 = {5'd0, A & {8{B[3]}}, 3'b0};
    assign r4 = {4'd0, A & {8{B[4]}}, 4'b0};
    assign r5 = {3'd0, A & {8{B[5]}}, 5'b0};
    assign r6 = {2'd0, A & {8{B[6]}}, 6'b0};
    assign r7 = {1'd0, A & {8{B[7]}}, 7'b0};
endmodule

// clock gate: synthesis uses the real sky130 ICG cell, the else part is only for RTL sim
module clock_gate (
    input  wire clk,
    input  wire en,
    output wire gclk
);
`ifdef SKY130_CELLS
    sky130_fd_sc_hd__dlclkp_1 u_icg (.CLK(clk), .GATE(en), .GCLK(gclk));
`else
    // latch is transparent while clk is low, so gclk can't glitch
    reg en_l;
    always @(clk or en) if (!clk) en_l = en;
    assign gclk = clk & en_l;
`endif
endmodule

`default_nettype wire
