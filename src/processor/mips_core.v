`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Course: CS220 - Introduction to Computer Organization
// Project: 32-Bit MIPS Processor & FPGA Accelerator
// Module Name: mips_core
// Description: Processor core integrating control unit, ALU, register file,
//              and instruction/data datapaths.
//////////////////////////////////////////////////////////////////////////////////

module mips_core(
    input  wire        clk,
    input  wire        rst_n,
    
    // Instruction Memory Interface
    output wire [31:0] PC,
    input  wire [31:0] Instruction,
    
    // Data Memory Interface
    output wire [31:0] DataAddr,
    output wire [31:0] WriteData,
    input  wire [31:0] ReadData,
    output wire        MemRead,
    output wire        MemWrite
);

    // State signal for debugging and internal transitions
    wire [1:0] state;

    // Registers to hold state between cycles
    reg [31:0] PC_reg;
    reg [31:0] Instruction_reg;
    reg [31:0] PC_Return_reg;
    reg [31:0] ALUOut;
    reg [31:0] WriteData_reg;

    // Control signals
    wire        RegWrite;
    wire [1:0]  RegDst;
    wire        ALUSrcA;
    wire [1:0]  ALUSrcB;
    wire [3:0]  ALUControl;
    wire [1:0]  MemToReg;
    wire        PCWrite;
    wire        PCSrc;
    
    // Register File signals
    wire [4:0]  A1, A2;
    reg  [4:0]  A3;
    reg  [31:0] WD3;
    wire [31:0] RD1, RD2;
    
    // ALU signals
    reg  [31:0] SrcA;
    reg  [31:0] SrcB;
    wire [31:0] ALUResult;
    wire        Zero;

    // 1. Program Counter Register
    reg [31:0] PC_next;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PC_reg <= 32'd0;
        end else if (PCWrite) begin
            PC_reg <= PC_next;
        end
    end

    // Instruction Pointer output
    assign PC = PC_reg;

    // 2. Instruction & Return Address Latching
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Instruction_reg <= 32'd0;
            PC_Return_reg   <= 32'd0;
        end else if (state == 2'b00) begin // STATE_FETCH_DECODE
            Instruction_reg <= Instruction;
            PC_Return_reg   <= PC_reg + 32'd4; // Save return address (PC+4)
        end
    end

    // 3. ALUOut & WriteData Latching
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ALUOut        <= 32'd0;
            WriteData_reg <= 32'd0;
        end else if (state == 2'b01) begin // STATE_EXECUTE
            ALUOut        <= ALUResult;
            WriteData_reg <= RD2;
        end
    end

    // 4. Register File Connections
    assign A1 = Instruction_reg[25:21]; // rs
    assign A2 = Instruction_reg[20:16]; // rt

    // Destination Register selection
    always @(*) begin
        case (RegDst)
            2'b00:   A3 = Instruction_reg[20:16]; // rt
            2'b01:   A3 = Instruction_reg[15:11]; // rd
            2'b10:   A3 = 5'd31;                  // $ra (for jal)
            default: A3 = 5'd0;
        endcase
    end

    // Write Data selection
    always @(*) begin
        case (MemToReg)
            2'b00:   WD3 = ALUOut;          // ALUResult
            2'b01:   WD3 = ReadData;        // Memory data
            2'b10:   WD3 = PC_Return_reg;   // PC Return address (for jal)
            default: WD3 = ALUOut;
        endcase
    end

    regfile rf_inst(
        .clk(clk),
        .rst_n(rst_n),
        .A1(A1),
        .A2(A2),
        .A3(A3),
        .WD3(WD3),
        .WE3(RegWrite),
        .RD1(RD1),
        .RD2(RD2)
    );

    // 5. ALU Operands selection
    // Operand A
    always @(*) begin
        if (ALUSrcA) begin
            SrcA = {27'd0, Instruction_reg[10:6]}; // shamt field
        end else begin
            SrcA = RD1; // Register Read Data 1
        end
    end

    // Operand B (sign-extended or zero-extended immediate)
    wire [31:0] sign_ext_imm = {{16{Instruction_reg[15]}}, Instruction_reg[15:0]};
    wire [31:0] zero_ext_imm = {16'd0, Instruction_reg[15:0]};
    always @(*) begin
        case (ALUSrcB)
            2'b00:   SrcB = RD2;
            2'b01:   SrcB = sign_ext_imm;
            2'b10:   SrcB = zero_ext_imm;
            default: SrcB = RD2;
        endcase
    end

    alu alu_inst(
        .A(SrcA),
        .B(SrcB),
        .ALUControl(ALUControl),
        .ALUResult(ALUResult),
        .Zero(Zero)
    );

    // 6. PC Next Address Determination
    always @(*) begin
        if (PCSrc == 1'b0) begin
            PC_next = PC_reg + 32'd4;
        end else begin
            if (Instruction_reg[31:26] == 6'b000010 || Instruction_reg[31:26] == 6'b000011) begin
                PC_next = {PC_reg[31:28], Instruction_reg[25:0], 2'b00}; // J, JAL Target
            end else begin
                PC_next = PC_reg + {sign_ext_imm[29:0], 2'b00}; // Branch Target
            end
        end
    end

    // 7. Control Unit Instance
    control ctrl_inst(
        .clk(clk),
        .rst_n(rst_n),
        .opcode(Instruction_reg[31:26]),
        .funct(Instruction_reg[5:0]),
        .Zero(Zero),
        .state(state),
        .RegWrite(RegWrite),
        .RegDst(RegDst),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .ALUControl(ALUControl),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .MemToReg(MemToReg),
        .PCWrite(PCWrite),
        .PCSrc(PCSrc)
    );

    // 8. Outputs to Data Memory
    assign DataAddr  = ALUOut;
    assign WriteData = WriteData_reg;

endmodule
