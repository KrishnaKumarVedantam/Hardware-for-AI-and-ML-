// =============================================================
// tb_compute_core.sv
// KWS Binary Conv2 Testbench — Icarus Verilog 12
// ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam
// =============================================================
`timescale 1ns/1ps

module tb_compute_core;

    localparam C_IN=4, C_OUT=4, K=3, L=8, PAD=1, OBITS=8;

    reg         clk,rst_n,start,act_valid,wt_valid;
    reg  [3:0]  act_in;
    reg  [2:0]  act_pos;
    reg  [11:0] wt_data;
    reg  [1:0]  wt_oc;
    wire        done,out_valid;
    wire signed [7:0] out_data;
    wire [1:0]  out_oc;
    wire [2:0]  out_pos;

    compute_core dut(
        .clk(clk),.rst_n(rst_n),.start(start),.done(done),
        .act_in(act_in),.act_pos(act_pos),.act_valid(act_valid),
        .wt_data(wt_data),.wt_oc(wt_oc),.wt_valid(wt_valid),
        .out_data(out_data),.out_oc(out_oc),.out_pos(out_pos),
        .out_valid(out_valid));

    initial clk=0; always #5 clk=~clk;

    // ── Capture all valid outputs via always block ──
    integer result[4][8];
    always @(posedge clk)
        if(out_valid) result[out_oc][out_pos] = $signed(out_data);

    integer expected[4][8];
    integer total_pass,total_fail,test_fail,i,oc_i,tc;

    // Clear result array
    task clear_result;
        integer a,b;
        for(a=0;a<4;a++) for(b=0;b<8;b++) result[a][b]='bx;
    endtask

    // Wait for done signal
    task wait_done;
        integer t; t=0;
        while(!done && t<2000) begin @(posedge clk); t=t+1; end
        @(posedge clk); // one extra cycle
    endtask

    // Check and report
    task check;
        input [8*32:0] tname;
        integer a,b;
        test_fail=0;
        for(a=0;a<4;a++) for(b=0;b<8;b++) begin
            if(result[a][b]!==expected[a][b]) begin
                test_fail++;
                $display("  MISMATCH [%0d][%0d] got=%0d exp=%0d",a,b,result[a][b],expected[a][b]);
            end
        end
        total_fail+=test_fail;
        if(test_fail==0) begin total_pass++; $display("  %0s: PASS",tname); end
        else $display("  %0s: FAIL (%0d errors)",tname,test_fail);
    endtask

    // Trigger compute
    task trigger;
        @(posedge clk); start<=1; @(posedge clk); start<=0;
        wait_done;
    endtask

    initial begin
        $dumpfile("tb_compute_core.vcd"); $dumpvars(0,tb_compute_core);
        rst_n=0;start=0;act_valid=0;wt_valid=0;
        act_in=0;act_pos=0;wt_data=0;wt_oc=0;
        total_pass=0;total_fail=0;
        repeat(4)@(posedge clk); rst_n=1; repeat(2)@(posedge clk);

        $display("==============================================");
        $display("tb_compute_core -- KWS Binary Conv2");
        $display("Venkata Krishna Kumar Vedantam | ECE 510 Spring 2026");
        $display("Reference: golden_reference.py (independent)");
        $display("==============================================");

        //==================================================
        // T1: all-agree (acts=1111, wts=FFF)
        // Expected all oc: [4,12,12,12,12,12,12,4]
        //==================================================
        $display("\n--- T1: all-agree ---");
        clear_result;
        for(i=0;i<8;i++) begin @(posedge clk); act_in<=4'hF;act_pos<=i[2:0];act_valid<=1; end
        @(posedge clk); act_valid<=0;
        for(oc_i=0;oc_i<4;oc_i++) begin @(posedge clk); wt_data<=12'hFFF;wt_oc<=oc_i[1:0];wt_valid<=1; end
        @(posedge clk); wt_valid<=0;
        for(oc_i=0;oc_i<4;oc_i++) begin
            expected[oc_i][0]=4; expected[oc_i][1]=12; expected[oc_i][2]=12; expected[oc_i][3]=12;
            expected[oc_i][4]=12;expected[oc_i][5]=12; expected[oc_i][6]=12; expected[oc_i][7]=4;
        end
        trigger; check("T1-all-agree");

        //==================================================
        // T2: all-disagree (acts=1111, wts=000)
        // Expected all oc: [-4,-12,-12,-12,-12,-12,-12,-4]
        //==================================================
        $display("\n--- T2: all-disagree ---");
        clear_result;
        for(i=0;i<8;i++) begin @(posedge clk); act_in<=4'hF;act_pos<=i[2:0];act_valid<=1; end
        @(posedge clk); act_valid<=0;
        for(oc_i=0;oc_i<4;oc_i++) begin @(posedge clk); wt_data<=12'h000;wt_oc<=oc_i[1:0];wt_valid<=1; end
        @(posedge clk); wt_valid<=0;
        for(oc_i=0;oc_i<4;oc_i++) begin
            expected[oc_i][0]=-4; expected[oc_i][1]=-12;expected[oc_i][2]=-12;expected[oc_i][3]=-12;
            expected[oc_i][4]=-12;expected[oc_i][5]=-12;expected[oc_i][6]=-12;expected[oc_i][7]=-4;
        end
        trigger; check("T2-all-disagree");

        //==================================================
        // T3: alternating
        // acts[p][ic]=(ic+p)%2  p=even:1010 p=odd:0101
        // wts[oc] alternates 101_010_101_010 / 010_101_010_101
        // Python: oc0=[-8,12,-12,12,-12,12,-12,8] oc1=[8,-12,12,-12,12,-12,12,-8]
        //==================================================
        $display("\n--- T3: alternating ---");
        clear_result;
        // acts
        for(i=0;i<8;i++) begin
            @(posedge clk);
            act_in<=(i%2==0)?4'b1010:4'b0101;
            act_pos<=i[2:0]; act_valid<=1;
        end
        @(posedge clk); act_valid<=0;
        // weights
        for(oc_i=0;oc_i<4;oc_i++) begin
            @(posedge clk);
            wt_data<=(oc_i%2==0)?12'b101_010_101_010:12'b010_101_010_101;
            wt_oc<=oc_i[1:0]; wt_valid<=1;
        end
        @(posedge clk); wt_valid<=0;
        expected[0][0]=-8;expected[0][1]=12;expected[0][2]=-12;expected[0][3]=12;
        expected[0][4]=-12;expected[0][5]=12;expected[0][6]=-12;expected[0][7]=8;
        expected[1][0]=8;expected[1][1]=-12;expected[1][2]=12;expected[1][3]=-12;
        expected[1][4]=12;expected[1][5]=-12;expected[1][6]=12;expected[1][7]=-8;
        expected[2][0]=-8;expected[2][1]=12;expected[2][2]=-12;expected[2][3]=12;
        expected[2][4]=-12;expected[2][5]=12;expected[2][6]=-12;expected[2][7]=8;
        expected[3][0]=8;expected[3][1]=-12;expected[3][2]=12;expected[3][3]=-12;
        expected[3][4]=12;expected[3][5]=-12;expected[3][6]=12;expected[3][7]=-8;
        trigger; check("T3-alternating");

        //==================================================
        // T4: random np.random.seed(42)
        // acts[p]={ic3,ic2,ic1,ic0}
        // ic0=[0,0,1,1,1,1,0,1] ic1=[0,1,0,1,0,1,1,0]
        // ic2=[0,0,1,1,1,0,1,1] ic3=[0,0,1,1,0,0,1,0]
        // out[0]=[0,2,-2,-4,-6,-4,0,0]
        //==================================================
        $display("\n--- T4: random (seed=42) ---");
        clear_result;
        begin
            // acts[p]={ic3,ic2,ic1,ic0}
            // p0={0,0,0,0}=0000 p1={0,0,1,0}=0010 p2={1,1,0,1}=1101
            // p3={1,1,1,1}=1111 p4={0,1,0,1}=0101 p5={0,0,1,1}=0011
            // p6={1,1,1,0}=1110 p7={0,1,0,1}=0101
            reg [3:0] ta[8];
            ta[0]=4'b0000;ta[1]=4'b0010;ta[2]=4'b1101;ta[3]=4'b1111;
            ta[4]=4'b0101;ta[5]=4'b0011;ta[6]=4'b1110;ta[7]=4'b0101;
            for(i=0;i<8;i++) begin @(posedge clk); act_in<=ta[i];act_pos<=i[2:0];act_valid<=1; end
        end
        @(posedge clk); act_valid<=0;
        begin
            reg [11:0] tw[4];
            tw[0]=12'b111_000_011_000;
            tw[1]=12'b111_000_101_100;
            tw[2]=12'b100_111_101_101;
            tw[3]=12'b000_010_010_011;
            for(oc_i=0;oc_i<4;oc_i++) begin @(posedge clk); wt_data<=tw[oc_i];wt_oc<=oc_i[1:0];wt_valid<=1; end
        end
        @(posedge clk); wt_valid<=0;
        expected[0][0]=0;expected[0][1]=2;expected[0][2]=-2;expected[0][3]=-4;
        expected[0][4]=-6;expected[0][5]=-4;expected[0][6]=0;expected[0][7]=0;
        expected[1][0]=2;expected[1][1]=0;expected[1][2]=4;expected[1][3]=-6;
        expected[1][4]=0;expected[1][5]=-6;expected[1][6]=-2;expected[1][7]=-2;
        expected[2][0]=-2;expected[2][1]=0;expected[2][2]=4;expected[2][3]=-2;
        expected[2][4]=4;expected[2][5]=2;expected[2][6]=2;expected[2][7]=-2;
        expected[3][0]=2;expected[3][1]=0;expected[3][2]=-4;expected[3][3]=2;
        expected[3][4]=0;expected[3][5]=2;expected[3][6]=2;expected[3][7]=2;
        trigger; check("T4-random-seed42");

        //==================================================
        // T5: all-zero (acts=0,wts=0) → 0 XOR 0 = 0 = agree → all +12
        //==================================================
        $display("\n--- T5: all-zero ---");
        clear_result;
        for(i=0;i<8;i++) begin @(posedge clk); act_in<=4'h0;act_pos<=i[2:0];act_valid<=1; end
        @(posedge clk); act_valid<=0;
        for(oc_i=0;oc_i<4;oc_i++) begin @(posedge clk); wt_data<=12'h000;wt_oc<=oc_i[1:0];wt_valid<=1; end
        @(posedge clk); wt_valid<=0;
        for(oc_i=0;oc_i<4;oc_i++) for(i=0;i<8;i++) expected[oc_i][i]=12;
        trigger; check("T5-all-zero");

        //==================================================
        // Summary
        //==================================================
        $display("\n==============================================");
        $display("Tests passed : %0d / 5", total_pass);
        $display("Total errors : %0d", total_fail);
        if(total_fail==0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $display("==============================================");
        $finish;
    end

    initial begin #2000000; $display("TIMEOUT"); $finish; end

endmodule
