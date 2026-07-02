`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Course: CS220 - Introduction to Computer Organization
// Project: 32-Bit MIPS Processor & FPGA Accelerator
// Module Name: regfile
// Description: MIPS 32x32 register file. Register 0 is hardwired to 0.
//              Supports synchronous writes and asynchronous reads.
//////////////////////////////////////////////////////////////////////////////////

module regfile(
    input  wire        clk,        // Clock signal
    input  wire        rst_n,      // Active-low asynchronous reset
    input  wire [4:0]  A1,         // Read Register Address 1 (rs)
    input  wire [4:0]  A2,         // Read Register Address 2 (rt)
    input  wire [4:0]  A3,         // Write Register Address (rd or rt)
    input  wire [31:0] WD3,        // Write Data
    input  wire        WE3,        // Write Enable
    output wire [31:0] RD1,        // Read Data 1
    output wire [31:0] RD2         // Read Data 2
);

    reg [31:0] rf [31:0];
    integer i;

    // Synchronous write with active-low reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                rf[i] <= 32'd0;
            end
        end else if (WE3 && (A3 != 5'd0)) begin
            rf[A3] <= WD3;
        end
    end

    // Asynchronous read (Register 0 is always 0)
    assign RD1 = (A1 == 5'd0) ? 32'd0 : rf[A1];
    assign RD2 = (A2 == 5'd0) ? 32'd0 : rf[A2];

endmodule
