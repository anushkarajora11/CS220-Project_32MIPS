`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Course: CS220 - Introduction to Computer Organization
// Project: 32-Bit MIPS Processor & FPGA Accelerator
// Module Name: tb_mips_top
// Description: System-level testbench for the 32-bit MIPS Processor and 
//              FPGA Accelerator integration. Preloads a test machine code 
//              program that configures the accelerator, starts it, polls for 
//              completion, reads the result, and writes it to the board LEDs.
//////////////////////////////////////////////////////////////////////////////////

module tb_mips_top();

    reg         clk;
    reg         rst_n;
    reg  [3:0]  switches;
    reg  [3:0]  buttons;
    wire [3:0]  leds;
    wire [5:0]  rgb_leds;

    // Instantiate Top-Level Module
    mips_top uut(
        .clk(clk),
        .rst_n(rst_n),
        .switches(switches),
        .buttons(buttons),
        .leds(leds),
        .rgb_leds(rgb_leds)
    );

    // Clock generation (50 MHz for simulation display ease)
    always #10 clk = ~clk;

    // Monitor internal registers for verification
    wire [31:0] current_pc     = uut.PC;
    wire [31:0] current_inst   = uut.Instruction;
    wire [1:0]  fsm_state      = uut.core_inst.state;
    wire        mem_write      = uut.MemWrite;
    wire [31:0] mem_addr       = uut.DataAddr;
    wire [31:0] mem_wdata      = uut.WriteData;

    initial begin
        // Initialize I/Os
        clk      = 1'b0;
        rst_n    = 1'b0;
        switches = 4'b1010;
        buttons  = 4'b0000;

        $display("==================================================");
        $display("RUNNING INTEGRATED MIPS CORE + ACCELERATOR TESTBENCH");
        $display("==================================================");

        // Preload MIPS Instruction Memory with Hex Machine Code
        // Program logic:
        // 0x00: $s0 = 0x00008000 (base address of MMIO)
        // 0x04: $t0 = 2          (matrix element M[0][0])
        // 0x08: M[0][0] <= $t0   (write to 0x8110)
        // 0x0c: $t1 = -1         (matrix element M[0][1])
        // 0x10: M[0][1] <= $t1   (write to 0x8114)
        // 0x14: $t2 = 3          (vector element V[0])
        // 0x18: V[0] <= $t2      (write to 0x8134)
        // 0x1c: $t3 = 2          (vector element V[1])
        // 0x20: V[1] <= $t3      (write to 0x8138)
        // 0x24: $t4 = 1          (start trigger, Mode=0, Start=1)
        // 0x28: CSR <= $t4       (write to 0x8100)
        // 0x2c: $t5 = CSR        (poll read from 0x8100)
        // 0x30: $t6 = $t5 & 1    (check busy bit 0)
        // 0x34: if ($t6 != 0) goto 0x2c (poll again)
        // 0x38: $t7 = Y[0]       (read result from 0x8140)
        // 0x3c: LEDs <= $t7      (write to 0x8008)
        // 0x40: infinite loop
        
        uut.ram_inst[0]  = 32'h34108000; // 0x00: ori $s0, $zero, 0x8000
        uut.ram_inst[1]  = 32'h20080002; // 0x04: addi $t0, $zero, 2
        uut.ram_inst[2]  = 32'hae080110; // 0x08: sw $t0, 0x110($s0)
        uut.ram_inst[3]  = 32'h2009ffff; // 0x0c: addi $t1, $zero, -1
        uut.ram_inst[4]  = 32'hae090114; // 0x10: sw $t1, 0x114($s0)
        uut.ram_inst[5]  = 32'h200a0003; // 0x14: addi $t2, $zero, 3
        uut.ram_inst[6]  = 32'hae0a0134; // 0x18: sw $t2, 0x134($s0)
        uut.ram_inst[7]  = 32'h200b0002; // 0x1c: addi $t3, $zero, 2
        uut.ram_inst[8]  = 32'hae0b0138; // 0x20: sw $t3, 0x138($s0)
        uut.ram_inst[9]  = 32'h200c0001; // 0x24: addi $t4, $zero, 1
        uut.ram_inst[10] = 32'hae0c0100; // 0x28: sw $t4, 0x100($s0)
        uut.ram_inst[11] = 32'h8e0d0100; // 0x2c: lw $t5, 0x100($s0)
        uut.ram_inst[12] = 32'h31ae0001; // 0x30: andi $t6, $t5, 1
        uut.ram_inst[13] = 32'h15c0fffd; // 0x34: bne $t6, $zero, -3 (poll loop)
        uut.ram_inst[14] = 32'h8e0f0140; // 0x38: lw $t7, 0x140($s0)
        uut.ram_inst[15] = 32'hae0f0008; // 0x3c: sw $t7, 0x008($s0)
        uut.ram_inst[16] = 32'h08000010; // 0x40: j 16 (infinite loop)

        // Clear Data Memory
        for (integer k = 0; k < 4096; k = k + 1) begin
            uut.ram_data[k] = 32'd0;
        end

        // Release Reset
        #40;
        rst_n = 1'b1;

        // Run simulation for 2000 ns to let the code execute
        #2000;

        $display("\n==================================================");
        $display("SIMULATION COMPLETED");
        $display("==================================================");
        $display("Final Board Outputs:");
        $display("      LEDs     = %b (Expected: 0100)", leds);
        $display("      RGB LEDs = %b", rgb_leds);

        if (leds == 4'b0100) begin
            $display("SUCCESS: MIPS Core correctly programmed and verified the FPGA Accelerator!");
        end else begin
            $display("FAILURE: Expected LEDs = 0100, got %b", leds);
        end
        $display("==================================================");
        $finish;
    end

    // Monitor printouts
    always @(posedge clk) begin
        if (rst_n) begin
            if (fsm_state == 2'b00) begin
                $display("[PC=0x%h] Instruction: 0x%h (State: FETCH/DECODE)", current_pc, current_inst);
            end
            if (mem_write && fsm_state == 2'b10) begin
                $display("      >>> MMIO Write: Addr = 0x%h, Data = %0d (%h)", mem_addr, $signed(mem_wdata), mem_wdata);
            end
        end
    end

endmodule
