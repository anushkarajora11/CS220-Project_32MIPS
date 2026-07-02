`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Course: CS220 - Introduction to Computer Organization
// Project: 32-Bit MIPS Processor & FPGA Accelerator
// Module Name: tb_accelerator
// Description: Self-checking testbench to verify both modes of the FPGA hardware 
//              accelerator (Matrix-Vector multiplication and Dijkstra pathfinding).
//////////////////////////////////////////////////////////////////////////////////

module tb_accelerator();

    reg         clk;
    reg         rst_n;
    reg  [31:0] addr;
    reg         wr_en;
    reg         rd_en;
    reg  [31:0] wr_data;
    wire [31:0] rd_data;

    // Instantiate Unit Under Test (UUT)
    accelerator uut(
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_data(wr_data),
        .rd_data(rd_data)
    );

    // Clock generation (100 MHz)
    always #5 clk = ~clk;

    // Helper tasks for register communication
    task write_reg(input [31:0] w_addr, input [31:0] data);
        begin
            @(posedge clk);
            addr    = w_addr;
            wr_data = data;
            wr_en   = 1'b1;
            rd_en   = 1'b0;
            @(posedge clk);
            wr_en   = 1'b0;
        end
    endtask

    task read_reg(input [31:0] r_addr, output [31:0] data);
        begin
            @(posedge clk);
            addr  = r_addr;
            rd_en = 1'b1;
            wr_en = 1'b0;
            @(posedge clk);
            #1; // Wait for combinational output to settle
            data  = rd_data;
            rd_en = 1'b0;
        end
    endtask

    reg [31:0] csr_val;
    reg [31:0] y0, y1, y2;
    reg [31:0] d0, d1, d2, d3;

    initial begin
        // Initialize inputs
        clk     = 1'b0;
        rst_n   = 1'b0;
        addr    = 32'd0;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        wr_data = 32'd0;

        // Apply Reset
        #20;
        rst_n = 1'b1;
        #20;

        $display("==================================================");
        $display("RUNNING HARDWARE ACCELERATOR TESTBENCH");
        $display("==================================================");

        // ----------------------------------------------------------------------
        // Test Case 1: Matrix-Vector Multiplication (Mode 0)
        // ----------------------------------------------------------------------
        // Matrix M:
        // [  2   -3    1 ]
        // [  0    4    5 ]
        // [ -1    2   -2 ]
        // Vector V:
        // [  3 ]
        // [  2 ]
        // [ -1 ]
        // Expected Y = M * V:
        // Y[0] = 2*(3) + (-3)*(2) + 1*(-1) = 6 - 6 - 1 = -1
        // Y[1] = 0*(3) + 4*(2) + 5*(-1)    = 0 + 8 - 5 = 3
        // Y[2] = (-1)*(3) + 2*(2) + (-2)*(-1) = -3 + 4 + 2 = 3

        $display("\n[TC1] Configuring Matrix M and Vector V...");
        
        // Write Matrix M elements
        write_reg(32'h0000_8110, 32'd2);    // M[0][0]
        write_reg(32'h0000_8114, -32'd3);   // M[0][1]
        write_reg(32'h0000_8118, 32'd1);    // M[0][2]
        write_reg(32'h0000_811C, 32'd0);    // M[1][0]
        write_reg(32'h0000_8120, 32'd4);    // M[1][1]
        write_reg(32'h0000_8124, 32'd5);    // M[1][2]
        write_reg(32'h0000_8128, -32'd1);   // M[2][0]
        write_reg(32'h0000_812C, 32'd2);    // M[2][1]
        write_reg(32'h0000_8130, -32'd2);   // M[2][2]

        // Write Vector V elements
        write_reg(32'h0000_8134, 32'd3);    // V[0]
        write_reg(32'h0000_8138, 32'd2);    // V[1]
        write_reg(32'h0000_813C, -32'd1);   // V[2]

        $display("[TC1] Starting Matrix-Vector Multiplication (Mode 0)...");
        // Start mode 0 (CSR = 32'h0000_0001: Start=1, Reset=0, Mode=0)
        write_reg(32'h0000_8100, 32'h0000_0001);

        // Wait for Done
        read_reg(32'h0000_8100, csr_val);
        while (csr_val[0] == 1'b1) begin // Wait while busy is 1
            #10;
            read_reg(32'h0000_8100, csr_val);
        end

        // Read results
        read_reg(32'h0000_8140, y0);
        read_reg(32'h0000_8144, y1);
        read_reg(32'h0000_8148, y2);

        $display("[TC1] Result Vector Y:");
        $display("      Y[0] = %0d (Expected: -1)", $signed(y0));
        $display("      Y[1] = %0d (Expected: 3)", $signed(y1));
        $display("      Y[2] = %0d (Expected: 3)", $signed(y2));

        if (($signed(y0) == -1) && ($signed(y1) == 3) && ($signed(y2) == 3)) begin
            $display("[TC1] SUCCESS: Matrix-Vector multiplication correct!");
        end else begin
            $display("[TC1] FAILURE: Matrix-Vector multiplication output mismatch.");
            $finish;
        end

        // Reset Done bit
        write_reg(32'h0000_8100, 32'h0000_0002); // Write Reset=1

        // ----------------------------------------------------------------------
        // Test Case 2: Dijkstra Pathfinding (Mode 1)
        // ----------------------------------------------------------------------
        // 4-Node Graph weights:
        // Node 0 -> Node 1: weight 2
        // Node 0 -> Node 2: weight 5
        // Node 1 -> Node 2: weight 1
        // Node 1 -> Node 3: weight 4
        // Node 2 -> Node 3: weight 2
        // All self-loops are weight 0. Undefined edges are infinity (255).
        // Adjacency Matrix W:
        // [   0    2    5  255 ]
        // [ 255    0    1    4 ]
        // [ 255  255    0    2 ]
        // [ 255  255  255    0 ]
        // Expected Shortest Paths from Start Node 0:
        // Dist to 0: 0
        // Dist to 1: 2
        // Dist to 2: min(5, Dist(1)+1) = 3
        // Dist to 3: min(inf, Dist(1)+4, Dist(2)+2) = min(6, 5) = 5

        $display("\n[TC2] Configuring Dijkstra Adjacency Matrix W (Start Node = 0)...");

        // Row 0
        write_reg(32'h0000_8150, 32'd0);      // W[0][0] = 0
        write_reg(32'h0000_8154, 32'd2);      // W[0][1] = 2
        write_reg(32'h0000_8158, 32'd5);      // W[0][2] = 5
        write_reg(32'h0000_815C, 32'd255);    // W[0][3] = infinity

        // Row 1
        write_reg(32'h0000_8160, 32'd255);    // W[1][0] = infinity
        write_reg(32'h0000_8164, 32'd0);      // W[1][1] = 0
        write_reg(32'h0000_8168, 32'd1);      // W[1][2] = 1
        write_reg(32'h0000_816C, 32'd4);      // W[1][3] = 4

        // Row 2
        write_reg(32'h0000_8170, 32'd255);    // W[2][0] = infinity
        write_reg(32'h0000_8174, 32'd255);    // W[2][1] = infinity
        write_reg(32'h0000_8178, 32'd0);      // W[2][2] = 0
        write_reg(32'h0000_817C, 32'd2);      // W[2][3] = 2

        // Row 3
        write_reg(32'h0000_8180, 32'd255);    // W[3][0] = infinity
        write_reg(32'h0000_8184, 32'd255);    // W[3][1] = infinity
        write_reg(32'h0000_8188, 32'd255);    // W[3][2] = infinity
        write_reg(32'h0000_818C, 32'd0);      // W[3][3] = 0

        // Set Start Node to 0
        write_reg(32'h0000_8190, 32'd0);

        $display("[TC2] Starting Dijkstra Shortest Path Solver (Mode 1)...");
        // Start mode 1 (CSR = 32'h0000_0005: Start=1, Reset=0, Mode=1)
        write_reg(32'h0000_8100, 32'h0000_0005);

        // Wait for Done
        read_reg(32'h0000_8100, csr_val);
        while (csr_val[0] == 1'b1) begin // Wait while busy is 1
            #10;
            read_reg(32'h0000_8100, csr_val);
        end

        // Read resulting shortest distances
        read_reg(32'h0000_8194, d0);
        read_reg(32'h0000_8198, d1);
        read_reg(32'h0000_819C, d2);
        read_reg(32'h0000_81A0, d3);

        $display("[TC2] Shortest Path Distances from Node 0:");
        $display("      D[0] = %0d (Expected: 0)", d0);
        $display("      D[1] = %0d (Expected: 2)", d1);
        $display("      D[2] = %0d (Expected: 3)", d2);
        $display("      D[3] = %0d (Expected: 5)", d3);

        if ((d0 == 0) && (d1 == 2) && (d2 == 3) && (d3 == 5)) begin
            $display("[TC2] SUCCESS: Dijkstra solver correct!");
        end else begin
            $display("[TC2] FAILURE: Dijkstra output mismatch.");
            $finish;
        end

        $display("\n==================================================");
        $display("ALL HARDWARE ACCELERATOR TESTS PASSED!");
        $display("==================================================");
        $finish;
    end

endmodule
