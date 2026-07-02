`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Course: CS220 - Introduction to Computer Organization
// Project: 32-Bit MIPS Processor & FPGA Accelerator
// Module Name: accelerator
// Description: Memory-mapped hardware accelerator for FPGA.
//              Mode 0: 3x3 Matrix-Vector Multiplication (16-bit signed inputs, 32-bit outputs).
//              Mode 1: Dijkstra's shortest path finder for a 4-node graph.
//////////////////////////////////////////////////////////////////////////////////

module accelerator(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] addr,       // MMIO Address
    input  wire        wr_en,      // Write Enable
    input  wire        rd_en,      // Read Enable
    input  wire [31:0] wr_data,    // Write Data
    output reg  [31:0] rd_data     // Read Data
);

    // --- Register Declarations ---
    // CSR: bit 0 = busy, bit 1 = done, bit 2 = mode (0: Matrix-Mult, 1: Dijkstra)
    reg        busy;
    reg        done;
    reg        mode; // 0 for Matrix-Mult, 1 for Dijkstra

    // Matrix-Vector registers (16-bit signed values stored in 32-bit registers)
    reg signed [15:0] M [2:0][2:0]; // 3x3 Matrix
    reg signed [15:0] V [2:0];      // 3x1 Vector
    reg signed [31:0] Y [2:0];      // 3x1 Output Vector (Result)

    // Dijkstra registers (8-bit unsigned weights)
    reg [7:0] W [3:0][3:0]; // 4x4 Adjacency Matrix
    reg [1:0] start_node;   // Dijkstra Start Node
    reg [7:0] D [3:0];      // Shortest distances output

    // --- FSM States for Dijkstra ---
    localparam ST_IDLE  = 3'b000;
    localparam ST_INIT  = 3'b001;
    localparam ST_STEP  = 3'b010;
    localparam ST_DONE  = 3'b011;

    reg [2:0] state;
    reg [1:0] step_count;
    reg [3:0] visited;      // 4-bit mask for visited nodes

    // Dijkstra computation signals
    reg [1:0] u;
    reg [7:0] min_d;
    reg       found;
    
    // Select unvisited node with minimum distance
    always @(*) begin
        u = 2'd0;
        min_d = 8'hFF;
        found = 1'b0;

        if (!visited[0]) begin
            u = 2'd0;
            min_d = D[0];
            found = 1'b1;
        end
        if (!visited[1]) begin
            if (!found || (D[1] < min_d)) begin
                u = 2'd1;
                min_d = D[1];
                found = 1'b1;
            end
        end
        if (!visited[2]) begin
            if (!found || (D[2] < min_d)) begin
                u = 2'd2;
                min_d = D[2];
                found = 1'b1;
            end
        end
        if (!visited[3]) begin
            if (!found || (D[3] < min_d)) begin
                u = 2'd3;
                min_d = D[3];
                found = 1'b1;
            end
        end
    end

    // --- MMIO Write Interface ---
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy       <= 1'b0;
            done       <= 1'b0;
            mode       <= 1'b0;
            start_node <= 2'd0;
            state      <= ST_IDLE;
            step_count <= 2'd0;
            visited    <= 4'd0;

            // Clear Matrix/Vector registers
            for (i = 0; i < 3; i = i + 1) begin
                V[i] <= 16'd0;
                Y[i] <= 32'd0;
                for (j = 0; j < 3; j = j + 1) begin
                    M[i][j] <= 16'd0;
                end
            end

            // Clear Dijkstra registers
            for (i = 0; i < 4; i = i + 1) begin
                D[i] <= 8'hFF; // Initialize to infinity
                for (j = 0; j < 4; j = j + 1) begin
                    W[i][j] <= 8'hFF;
                end
            end
        end else begin
            // FSM Operations
            case (state)
                ST_IDLE: begin
                    if (wr_en && (addr[7:0] == 8'h00)) begin
                        if (wr_data[1]) begin // Write 1 to bit 1 is Reset
                            busy <= 1'b0;
                            done <= 1'b0;
                        end else if (wr_data[0] && !busy) begin // Write 1 to bit 0 is Start
                            busy <= 1'b1;
                            done <= 1'b0;
                            mode <= wr_data[2]; // Select Mode
                            if (wr_data[2] == 1'b0) begin
                                // Mode 0: Matrix-Vector Mult (Execute in 1 cycle)
                                Y[0]  <= M[0][0]*V[0] + M[0][1]*V[1] + M[0][2]*V[2];
                                Y[1]  <= M[1][0]*V[0] + M[1][1]*V[1] + M[1][2]*V[2];
                                Y[2]  <= M[2][0]*V[0] + M[2][1]*V[1] + M[2][2]*V[2];
                                state <= ST_DONE;
                            end else begin
                                // Mode 1: Dijkstra Shortest Path Finder
                                state <= ST_INIT;
                            end
                        end
                    end
                end

                ST_INIT: begin
                    // Initialize Dijkstra arrays
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i == start_node)
                            D[i] <= 8'd0;
                        else
                            D[i] <= 8'hFF; // infinity
                    end
                    visited    <= 4'b0000;
                    step_count <= 2'd0;
                    state      <= ST_STEP;
                end

                ST_STEP: begin
                    if (found && (min_d != 8'hFF)) begin
                        visited[u] <= 1'b1;
                        
                        // Relax edges from node u
                        for (i = 0; i < 4; i = i + 1) begin
                            if (!visited[i] && (W[u][i] != 8'hFF)) begin
                                if (D[u] + W[u][i] < D[i]) begin
                                    D[i] <= D[u] + W[u][i];
                                end
                            end
                        end
                        
                        step_count <= step_count + 1'b1;
                        if (step_count == 2'd3) begin
                            state <= ST_DONE;
                        end
                    end else begin
                        // No reachable unvisited nodes left, terminate early
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end
                
                default: state <= ST_IDLE;
            endcase

            // Register writes when idle
            if (wr_en && !busy && (state == ST_IDLE)) begin
                case (addr[7:0])
                    // Matrix M
                    8'h10: M[0][0] <= wr_data[15:0];
                    8'h14: M[0][1] <= wr_data[15:0];
                    8'h18: M[0][2] <= wr_data[15:0];
                    8'h1C: M[1][0] <= wr_data[15:0];
                    8'h20: M[1][1] <= wr_data[15:0];
                    8'h24: M[1][2] <= wr_data[15:0];
                    8'h28: M[2][0] <= wr_data[15:0];
                    8'h2C: M[2][1] <= wr_data[15:0];
                    8'h30: M[2][2] <= wr_data[15:0];

                    // Vector V
                    8'h34: V[0] <= wr_data[15:0];
                    8'h38: V[1] <= wr_data[15:0];
                    8'h3C: V[2] <= wr_data[15:0];

                    // Dijkstra Adjacency Matrix W
                    8'h50: W[0][0] <= wr_data[7:0];
                    8'h54: W[0][1] <= wr_data[7:0];
                    8'h58: W[0][2] <= wr_data[7:0];
                    8'h5C: W[0][3] <= wr_data[7:0];
                    8'h60: W[1][0] <= wr_data[7:0];
                    8'h64: W[1][1] <= wr_data[7:0];
                    8'h68: W[1][2] <= wr_data[7:0];
                    8'h6C: W[1][3] <= wr_data[7:0];
                    8'h70: W[2][0] <= wr_data[7:0];
                    8'h74: W[2][1] <= wr_data[7:0];
                    8'h78: W[2][2] <= wr_data[7:0];
                    8'h7C: W[2][3] <= wr_data[7:0];
                    8'h80: W[3][0] <= wr_data[7:0];
                    8'h84: W[3][1] <= wr_data[7:0];
                    8'h88: W[3][2] <= wr_data[7:0];
                    8'h8C: W[3][3] <= wr_data[7:0];

                    // Dijkstra Start Node
                    8'h90: start_node <= wr_data[1:0];

                    default: ;
                endcase
            end
        end
    end

    // --- MMIO Read Interface ---
    always @(*) begin
        rd_data = 32'd0;
        if (rd_en) begin
            case (addr[7:0])
                // CSR Read: {29'd0, mode, done, busy}
                8'h00: rd_data = {29'd0, mode, done, busy};

                // Matrix M
                8'h10: rd_data = {16'd0, M[0][0]};
                8'h14: rd_data = {16'd0, M[0][1]};
                8'h18: rd_data = {16'd0, M[0][2]};
                8'h1C: rd_data = {16'd0, M[1][0]};
                8'h20: rd_data = {16'd0, M[1][1]};
                8'h24: rd_data = {16'd0, M[1][2]};
                8'h28: rd_data = {16'd0, M[2][0]};
                8'h2C: rd_data = {16'd0, M[2][1]};
                8'h30: rd_data = {16'd0, M[2][2]};

                // Vector V
                8'h34: rd_data = {16'd0, V[0]};
                8'h38: rd_data = {16'd0, V[1]};
                8'h3C: rd_data = {16'd0, V[2]};

                // Result Y
                8'h40: rd_data = Y[0];
                8'h44: rd_data = Y[1];
                8'h48: rd_data = Y[2];

                // Dijkstra Adjacency Matrix W
                8'h50: rd_data = {24'd0, W[0][0]};
                8'h54: rd_data = {24'd0, W[0][1]};
                8'h58: rd_data = {24'd0, W[0][2]};
                8'h5C: rd_data = {24'd0, W[0][3]};
                8'h60: rd_data = {24'd0, W[1][0]};
                8'h64: rd_data = {24'd0, W[1][1]};
                8'h68: rd_data = {24'd0, W[1][2]};
                8'h6C: rd_data = {24'd0, W[1][3]};
                8'h70: rd_data = {24'd0, W[2][0]};
                8'h74: rd_data = {24'd0, W[2][1]};
                8'h78: rd_data = {24'd0, W[2][2]};
                8'h7C: rd_data = {24'd0, W[2][3]};
                8'h80: rd_data = {24'd0, W[3][0]};
                8'h84: rd_data = {24'd0, W[3][1]};
                8'h88: rd_data = {24'd0, W[3][2]};
                8'h8C: rd_data = {24'd0, W[3][3]};

                // Dijkstra Start Node
                8'h90: rd_data = {30'd0, start_node};

                // Dijkstra Output Distances
                8'h94: rd_data = {24'd0, D[0]};
                8'h98: rd_data = {24'd0, D[1]};
                8'h9C: rd_data = {24'd0, D[2]};
                8'hA0: rd_data = {24'd0, D[3]};

                default: rd_data = 32'd0;
            endcase
        end
    end

endmodule
