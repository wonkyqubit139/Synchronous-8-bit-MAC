// Testbench for mac8 (self-checking)
// the golden model is the spec (reset / accumulate / hold), and for the pipelined versions it also keeps a queue of
// in-flight products, so expected Y comes STAGES-1 cycles later, and reset empties the queue.
// Y is compared with the model after every clock edge, prints PASS/FAIL at the end.
// compile with -DGLS for gate level sim (the netlist has no parameters)

`timescale 1ns/1ps
`default_nettype none

module mac8_tb;
    parameter integer STAGES     = 2;
    parameter integer FAST_ARITH = 1;
    parameter integer CLK_GATE   = 1;
    parameter integer N_RANDOM   = 5000;  // random cycles in T8
    parameter integer SEED       = 20260929;
    parameter integer EN_PCT     = 75;  // % of cycles with enable=1 in T8
    localparam integer LAT       = STAGES;  // pipeline latency
    localparam real    TCLK      = 4.0;  // 4 ns = 250 MHz

    reg         clk = 1'b0;
    reg         reset, enable;
    reg  [7:0]  A, B;
    wire [19:0] Y;

`ifdef GLS
    mac8 dut (
`else
    mac8 #(.STAGES(STAGES), .FAST_ARITH(FAST_ARITH), .CLK_GATE(CLK_GATE)) dut (
`endif
        .clk(clk), .reset(reset), .enable(enable), .A(A), .B(B), .Y(Y)
    );

    always #(TCLK/2.0) clk = ~clk;

    // model state: expected Y + queue of ops in flight (valid, product)
    reg [19:0] model;
    reg        q_v [0:7];
    reg [15:0] q_p [0:7];
    integer    k;

    integer n_checks = 0, n_errors = 0;
    integer grp_checks [1:8];
    integer grp_errors [1:8];
    integer grp;
    integer seed;

    wire [19:0] expected = model;

    // one cycle: drive inputs on negedge, update the model on posedge, then check
    task step(input r, input e, input [7:0] a, input [7:0] b);
        begin
            @(negedge clk);
            reset = r; enable = e; A = a; B = b;
            @(posedge clk);
            // (unpipelined) model is exactly the spec
            if (LAT == 1) begin
                if (r)       model = 20'd0;
                else if (e)  model = model + a * b;
            // (pipelined) reset clears Y and drops everything in flight
            end else if (r) begin
                model = 20'd0;
                for (k = 0; k < 8; k = k + 1) q_v[k] = 1'b0;
            // else add oldest op, shift queue and push new one
            end else begin
                if (q_v[LAT-2]) model = model + q_p[LAT-2];
                for (k = 7; k > 0; k = k - 1) begin
                    q_v[k] = q_v[k-1]; q_p[k] = q_p[k-1];
                end
                q_v[0] = e; q_p[0] = a * b;
            end
            #0.5;  // let the output settle before checking
            check();
        end
    endtask

    // compare DUT with the model, only print the first 20 mismatches
    task check;
        begin
            n_checks = n_checks + 1;
            grp_checks[grp] = grp_checks[grp] + 1;
            if (Y !== expected) begin
                n_errors = n_errors + 1;
                grp_errors[grp] = grp_errors[grp] + 1;
                if (n_errors <= 20)
                    $display("  ERROR t=%0t grp=T%0d : Y=%0d expected=%0d (A=%0d B=%0d en=%b rst=%b)",
                             $time, grp, Y, expected, A, B, enable, reset);
            end
        end
    endtask

    // a few idle cycles so the last ops come out of the pipeline
    task drain;
        integer d;
        begin
            for (d = 0; d < LAT; d = d + 1) step(0, 0, $random(seed), $random(seed));
        end
    endtask

    integer i, a_i, b_i;
    reg [19:0] y_before;

    initial begin
        $dumpfile("mac8_tb.vcd");
        $dumpvars(0, mac8_tb);
        seed = SEED;
        for (k = 1; k <= 8; k = k + 1) begin grp_checks[k] = 0; grp_errors[k] = 0; end
        for (k = 0; k < 8; k = k + 1) begin q_v[k] = 1'b0; q_p[k] = 16'd0; end
        model = 20'd0;
        reset = 1; enable = 0; A = 0; B = 0;

        $display("--------------------------------------------------------------");
        $display(" mac8 self-checking testbench  STAGES=%0d FAST_ARITH=%0d CLK_GATE=%0d latency=%0d", STAGES, FAST_ARITH, CLK_GATE, LAT);
        $display("--------------------------------------------------------------");

        // T1: reset, also reset together with enable=1 (reset should win)
        grp = 1;
        for (i = 0; i < LAT + 2; i = i + 1) step(1, 0, 8'hFF, 8'hFF);
        for (i = 0; i < LAT + 1; i = i + 1) step(1, 1, 8'hFF, 8'hFF);
        if (Y !== 20'd0) begin
            n_errors = n_errors + 1; grp_errors[1] = grp_errors[1] + 1;
            $display("  ERROR: Y not zero after reset");
        end

        // T2: accumulate 3*4 + 10*10 + 7*9 + 1*1 = 176
        grp = 2;
        step(0, 1, 8'd3,  8'd4);
        step(0, 1, 8'd10, 8'd10);
        step(0, 1, 8'd7,  8'd9);
        step(0, 1, 8'd1,  8'd1);
        drain();
        if (Y !== 20'd176) begin
            n_errors = n_errors + 1; grp_errors[2] = grp_errors[2] + 1;
            $display("  ERROR: accumulate sum = %0d, expected 176", Y);
        end

        // T3: hold with enable=0 while A/B keep changing, then toggle enable
        grp = 3;
        y_before = Y;
        for (i = 0; i < 20; i = i + 1) step(0, 0, $random(seed), $random(seed));
        if (Y !== y_before) begin
            n_errors = n_errors + 1; grp_errors[3] = grp_errors[3] + 1;
            $display("  ERROR: hold changed Y from %0d to %0d", y_before, Y);
        end
        for (i = 0; i < 20; i = i + 1) step(0, i[0], $random(seed), $random(seed));
        drain();

        // T4: grid of A/B values + walking ones
        grp = 4;
        step(1, 0, 0, 0);
        for (a_i = 0; a_i < 256; a_i = a_i + 17)
            for (b_i = 0; b_i < 256; b_i = b_i + 51)
                step(0, 1, a_i[7:0], b_i[7:0]);
        for (a_i = 0; a_i < 8; a_i = a_i + 1)
            for (b_i = 0; b_i < 8; b_i = b_i + 1)
                step(0, 1, 8'd1 << a_i, 8'd1 << b_i);
        drain();

        // T5: boundary cases A=0, B=0, A=255, B=255
        grp = 5;
        step(1, 0, 0, 0);
        for (i = 0; i < 16; i = i + 1) step(0, 1, 8'd0,   $random(seed));
        for (i = 0; i < 16; i = i + 1) step(0, 1, $random(seed), 8'd0);
        drain();
        if (Y !== 20'd0) begin
            n_errors = n_errors + 1; grp_errors[5] = grp_errors[5] + 1;
            $display("  ERROR: A=0/B=0 accumulation produced %0d", Y);
        end
        for (i = 0; i < 16; i = i + 1) step(0, 1, 8'd255, $random(seed));
        for (i = 0; i < 16; i = i + 1) step(0, 1, $random(seed), 8'd255);
        step(0, 1, 8'd255, 8'd255);
        step(0, 1, 8'd0,   8'd255);
        step(0, 1, 8'd255, 8'd0);
        step(0, 1, 8'd1,   8'd255);
        step(0, 1, 8'd255, 8'd1);
        drain();

        // T6: 40 x 255*255 > 2^20, so the accumulator wraps around
        grp = 6;
        step(1, 0, 0, 0);
        for (i = 0; i < 40; i = i + 1) step(0, 1, 8'd255, 8'd255);
        drain();

        // T7: reset in the middle of a burst
        grp = 7;
        for (i = 0; i < 10; i = i + 1) step(0, 1, $random(seed), $random(seed));
        step(1, 1, 8'd200, 8'd200);
        for (i = 0; i < 10; i = i + 1) step(0, 1, $random(seed), $random(seed));
        drain();

        // T8: random A/B, ~1% reset, enable EN_PCT% of the time
        grp = 8;
        for (i = 0; i < N_RANDOM; i = i + 1)
            step(($random(seed) % 100) == 0,
                 ({$random(seed)} % 100) < EN_PCT,
                 $random(seed), $random(seed));
        drain();

        // summary table
        $display("--------------------------------------------------------------");
        $display(" Group                         checks   errors");
        $display(" T1 reset                      %6d   %6d", grp_checks[1], grp_errors[1]);
        $display(" T2 accumulate (enable=1)      %6d   %6d", grp_checks[2], grp_errors[2]);
        $display(" T3 hold (enable=0)            %6d   %6d", grp_checks[3], grp_errors[3]);
        $display(" T4 A/B combinations           %6d   %6d", grp_checks[4], grp_errors[4]);
        $display(" T5 boundary 0/255             %6d   %6d", grp_checks[5], grp_errors[5]);
        $display(" T6 wrap-around                %6d   %6d", grp_checks[6], grp_errors[6]);
        $display(" T7 reset mid-burst            %6d   %6d", grp_checks[7], grp_errors[7]);
        $display(" T8 random (%0d cycles)        %6d   %6d", N_RANDOM, grp_checks[8], grp_errors[8]);
        $display("--------------------------------------------------------------");
        if (n_errors == 0)
            $display(" RESULT: PASS  (%0d cycle checks, 0 errors)", n_checks);
        else
            $display(" RESULT: FAIL  (%0d cycle checks, %0d errors)", n_checks, n_errors);
        $display("==============================================================");
        $finish;
    end
endmodule

`default_nettype wire
