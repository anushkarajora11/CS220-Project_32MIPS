`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Course: CS220 - Introduction to Computer Organization
// Project: 32-Bit MIPS Processor & FPGA Accelerator
// Module Name: mips_top
// Description: Top-level module integrating the MIPS core, Instruction Memory,
//              Data Memory, Memory-Mapped Peripherals, and the Accelerator.
//////////////////////////////////////////////////////////////////////////////////

module mips_top(
    input  wire        clk,
    input  wire        rst_n,
    
    // Physical Board I/O (PYNQ-Z2 mapping)
    input  wire [3:0]  switches,    // 4 slide switches
    input  wire [3:0]  buttons,     // 4 push buttons
    output wire [3:0]  leds,        // 4 green LEDs
    output wire [5:0]  rgb_leds     // 2 RGB LEDs (3-bits each: R-G-B)
);

    // Memory Arrays (16 KB each: 4096 words of 32 bits)
    reg [31:0] ram_inst [4095:0];   // Instruction Memory
    reg [31:0] ram_data [4095:0];   // Data Memory

    // Internal bus connections
    wire [31:0] PC;
    wire [31:0] Instruction;
    wire [31:0] DataAddr;
    wire [31:0] WriteData;
    reg  [31:0] ReadData;
    wire        MemRead;
    wire        MemWrite;

    // Peripheral registers
    reg  [3:0]  leds_reg;
    reg  [5:0]  rgb_leds_reg;

    // Output assignments
    assign leds     = leds_reg;
    assign rgb_leds = rgb_leds_reg;

    // 1. Instruction Fetch (ROM read)
    // Align address to word bounds (divide by 4)
    assign Instruction = ram_inst[PC[13:2]];

    // 2. MIPS Core Instance
    mips_core core_inst(
        .clk(clk),
        .rst_n(rst_n),
        .PC(PC),
        .Instruction(Instruction),
        .DataAddr(DataAddr),
        .WriteData(WriteData),
        .ReadData(ReadData),
        .MemRead(MemRead),
        .MemWrite(MemWrite)
    );

    // 3. Hardware Accelerator Instance
    wire        acc_wr_en;
    wire        acc_rd_en;
    wire [31:0] acc_rd_data;

    assign acc_wr_en = MemWrite && (DataAddr[31:12] == 20'h00008) && (DataAddr[11:8] == 4'h1);
    assign acc_rd_en = MemRead  && (DataAddr[31:12] == 20'h00008) && (DataAddr[11:8] == 4'h1);

    accelerator acc_inst(
        .clk(clk),
        .rst_n(rst_n),
        .addr(DataAddr),
        .wr_en(acc_wr_en),
        .rd_en(acc_rd_en),
        .wr_data(WriteData),
        .rd_data(acc_rd_data)
    );

    // 4. Memory-Mapped I/O (MMIO) Read Decode
    always @(*) begin
        ReadData = 32'd0;
        if (MemRead) begin
            if (DataAddr[15:14] == 2'b01) begin
                // Address range: 0x0000_4000 to 0x0000_7FFF (Data Memory)
                ReadData = ram_data[DataAddr[13:2]];
            end else if (DataAddr[31:12] == 20'h00008) begin
                // Address range: 0x0000_8000 to 0x0000_8FFF (MMIO Space)
                if (DataAddr[11:8] == 4'h0) begin
                    // Peripheral Space (0x8000 to 0x80FF)
                    case (DataAddr[7:0])
                        8'h00: ReadData = {28'd0, switches};
                        8'h04: ReadData = {28'd0, buttons};
                        8'h08: ReadData = {28'd0, leds_reg};
                        8'h0C: ReadData = {26'd0, rgb_leds_reg};
                        default: ReadData = 32'd0;
                    endcase
                end else if (DataAddr[11:8] == 4'h1) begin
                    // Accelerator Space (0x8100 to 0x81FF)
                    ReadData = acc_rd_data;
                end
            end
        end
    end

    // 5. Memory-Mapped I/O (MMIO) Write Decode
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            leds_reg     <= 4'd0;
            rgb_leds_reg <= 6'd0;
        end else if (MemWrite) begin
            if (DataAddr[15:14] == 2'b01) begin
                // Address range: 0x0000_4000 to 0x0000_7FFF (Data Memory)
                ram_data[DataAddr[13:2]] <= WriteData;
            end else if (DataAddr[31:12] == 20'h00008) begin
                // Address range: 0x0000_8000 to 0x0000_8FFF (MMIO Space)
                if (DataAddr[11:8] == 4'h0) begin
                    // Peripherals Space
                    case (DataAddr[7:0])
                        8'h08: leds_reg     <= WriteData[3:0];
                        8'h0C: rgb_leds_reg <= WriteData[5:0];
                        default: ;
                    endcase
                end
            end
        end
    end

endmodule
