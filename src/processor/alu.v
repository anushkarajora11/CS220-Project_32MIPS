`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Course: CS220 - Introduction to Computer Organization
// Project: 32-Bit MIPS Processor & FPGA Accelerator
// Module Name: alu
// Description: 32-bit Arithmetic Logic Unit (ALU) supporting logical, arithmetic,
//              comparison, and shift operations.
//////////////////////////////////////////////////////////////////////////////////

module alu(
    input  wire [31:0] A,          // Input operand A
    input  wire [31:0] B,          // Input operand B
    input  wire [3:0]  ALUControl, // Control signal specifying operation
    output reg  [31:0] ALUResult,  // ALU output result
    output wire        Zero        // Asserted if ALUResult is 0 (for branch evaluation)
);

    always @(*) begin
        case (ALUControl)
            4'b0000: ALUResult = A & B;             // AND
            4'b0001: ALUResult = A | B;             // OR
            4'b0010: ALUResult = A + B;             // ADD
            4'b0011: ALUResult = A - B;             // SUB (Subtract)
            4'b0100: ALUResult = A ^ B;             // XOR
            4'b0101: ALUResult = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0; // SLT (Set Less Than - Signed)
            4'b0110: ALUResult = B << A[4:0];       // SLL (Shift Left Logical) - A holds shift amount
            4'b0111: ALUResult = B >> A[4:0];       // SRL (Shift Right Logical) - A holds shift amount
            4'b1000: ALUResult = ~(A | B);          // NOR
            default: ALUResult = 32'd0;
        endcase
    end

    assign Zero = (ALUResult == 32'd0) ? 1'b1 : 1'b0;

endmodule
