`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Course: CS220 - Introduction to Computer Organization
// Project: 32-Bit MIPS Processor & FPGA Accelerator
// Module Name: control
// Description: FSM-based 3-cycle MIPS control unit.
//              Generates control signals for datapath, ALU, RegFile, and Memory.
//////////////////////////////////////////////////////////////////////////////////

module control(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [5:0]  opcode,     // Instruction opcode: Inst[31:26]
    input  wire [5:0]  funct,      // R-type function code: Inst[5:0]
    input  wire        Zero,       // Zero output from ALU
    output reg  [1:0]  state,      // Current FSM state output (for datapath/debug)
    output reg         RegWrite,   // Register file write enable
    output reg  [1:0]  RegDst,     // Reg file destination selector (00: rt, 01: rd, 10: $ra)
    output reg         ALUSrcA,    // ALU operand A selector (0: rs, 1: shamt)
    output reg  [1:0]  ALUSrcB,    // ALU operand B selector (00: rt, 01: sign-extended imm, 10: zero-extended imm)
    output reg  [3:0]  ALUControl, // ALU operation control signal
    output reg         MemRead,    // Data memory read enable
    output reg         MemWrite,   // Data memory write enable
    output reg  [1:0]  MemToReg,   // Memory-to-Reg selector (00: ALUResult, 01: MemData, 10: PC_Return)
    output reg         PCWrite,    // Unconditional PC write enable
    output reg         PCSrc       // PC source selector (0: PC+4 / Branch / Jump Target, 1: handled conditionally)
);

    // State definitions
    localparam STATE_FETCH_DECODE  = 2'b00;
    localparam STATE_EXECUTE       = 2'b01;
    localparam STATE_WRITEBACK_MEM = 2'b10;

    reg [1:0] next_state;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_FETCH_DECODE;
        end else begin
            state <= next_state;
        end
    end

    // FSM Next State Logic & Control Signals
    always @(*) begin
        // Defaults
        next_state = STATE_FETCH_DECODE;
        RegWrite   = 1'b0;
        RegDst     = 2'b00;
        ALUSrcA    = 1'b0;
        ALUSrcB    = 2'b00;
        ALUControl = 4'b0000;
        MemRead    = 1'b0;
        MemWrite   = 1'b0;
        MemToReg   = 2'b00;
        PCWrite    = 1'b0;
        PCSrc      = 1'b0;

        case (state)
            STATE_FETCH_DECODE: begin
                // In Fetch/Decode, we fetch instruction (done by top memory)
                // and increment PC immediately (unconditional)
                PCWrite = 1'b1;
                PCSrc   = 1'b0; // Select normal PC increment (PC + 4)
                
                next_state = STATE_EXECUTE;
            end

            STATE_EXECUTE: begin
                // Decode instructions to configure ALU source and operations
                case (opcode)
                    6'b000000: begin // R-type instructions
                        // ALU Sources
                        if (funct == 6'b000000 || funct == 6'b000010) begin
                            ALUSrcA = 1'b1; // Use shamt for shifts (sll, srl)
                        end else begin
                            ALUSrcA = 1'b0; // Use Register rs
                        end
                        ALUSrcB = 2'b00;    // Use Register rt
                        
                        // ALU Control Decoder
                        case (funct)
                            6'b100000: ALUControl = 4'b0010; // add
                            6'b100010: ALUControl = 4'b0011; // sub
                            6'b100100: ALUControl = 4'b0000; // and
                            6'b100101: ALUControl = 4'b0001; // or
                            6'b100110: ALUControl = 4'b0100; // xor
                            6'b101010: ALUControl = 4'b0101; // slt
                            6'b000000: ALUControl = 4'b0110; // sll
                            6'b000010: ALUControl = 4'b0111; // srl
                            6'b100111: ALUControl = 4'b1000; // nor
                            default:   ALUControl = 4'b0000;
                        endcase
                        
                        next_state = STATE_WRITEBACK_MEM;
                    end

                    6'b001000: begin // addi
                        ALUSrcA    = 1'b0; // rs
                        ALUSrcB    = 2'b01; // sign-extended immediate
                        ALUControl = 4'b0010; // ADD
                        next_state = STATE_WRITEBACK_MEM;
                    end

                    6'b001100: begin // andi
                        ALUSrcA    = 1'b0; // rs
                        ALUSrcB    = 2'b10; // zero-extended immediate
                        ALUControl = 4'b0000; // AND
                        next_state = STATE_WRITEBACK_MEM;
                    end

                    6'b001101: begin // ori
                        ALUSrcA    = 1'b0; // rs
                        ALUSrcB    = 2'b10; // zero-extended immediate
                        ALUControl = 4'b0001; // OR
                        next_state = STATE_WRITEBACK_MEM;
                    end

                    6'b100011, 6'b101011: begin // lw, sw
                        ALUSrcA    = 1'b0; // rs
                        ALUSrcB    = 2'b01; // sign-extended immediate (offset)
                        ALUControl = 4'b0010; // ADD (base + offset)
                        next_state = STATE_WRITEBACK_MEM;
                    end

                    6'b000100: begin // beq
                        ALUSrcA    = 1'b0; // rs
                        ALUSrcB    = 2'b00; // rt
                        ALUControl = 4'b0011; // SUB (compare)
                        // If equal, write PC target
                        if (Zero) begin
                            PCWrite = 1'b1;
                            PCSrc   = 1'b1; // Select branch target
                        end
                        next_state = STATE_FETCH_DECODE; // Completes in Cycle 2
                    end

                    6'b000101: begin // bne
                        ALUSrcA    = 1'b0; // rs
                        ALUSrcB    = 2'b00; // rt
                        ALUControl = 4'b0011; // SUB (compare)
                        // If not equal, write PC target
                        if (!Zero) begin
                            PCWrite = 1'b1;
                            PCSrc   = 1'b1; // Select branch target
                        end
                        next_state = STATE_FETCH_DECODE; // Completes in Cycle 2
                    end

                    6'b000010: begin // j
                        PCWrite    = 1'b1;
                        PCSrc      = 1'b1; // PC source is jump target (handled in datapath)
                        next_state = STATE_FETCH_DECODE; // Completes in Cycle 2
                    end

                    6'b000011: begin // jal
                        PCWrite    = 1'b1;
                        PCSrc      = 1'b1; // PC source is jump target
                        next_state = STATE_WRITEBACK_MEM; // Transition to write return address to $ra
                    end

                    default: begin
                        next_state = STATE_FETCH_DECODE;
                    end
                endcase
            end

            STATE_WRITEBACK_MEM: begin
                next_state = STATE_FETCH_DECODE; // Always return to Fetch after writeback
                case (opcode)
                    6'b000000: begin // R-type
                        RegWrite = 1'b1;
                        RegDst   = 2'b01; // write to rd
                        MemToReg = 2'b00; // ALUResult
                    end

                    6'b001000, 6'b001100, 6'b001101: begin // addi, andi, ori
                        RegWrite = 1'b1;
                        RegDst   = 2'b00; // write to rt
                        MemToReg = 2'b00; // ALUResult
                    end

                    6'b100011: begin // lw
                        MemRead  = 1'b1;
                        RegWrite = 1'b1;
                        RegDst   = 2'b00; // write to rt
                        MemToReg = 2'b01; // MemData
                    end

                    6'b101011: begin // sw
                        MemWrite = 1'b1;
                    end

                    6'b000011: begin // jal
                        RegWrite = 1'b1;
                        RegDst   = 2'b10; // write to $ra (R31)
                        MemToReg = 2'b10; // PC_Return (stored PC + 4)
                    end

                    default: ;
                endcase
            end

            default: begin
                next_state = STATE_FETCH_DECODE;
            end
        endcase
    end

endmodule
