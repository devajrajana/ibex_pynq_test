
`timescale 1ns / 1ps

module uart_rx #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,

    output logic [7:0] rx_data,
    output logic       rx_valid,
    output logic       rx_busy
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;
    localparam integer COUNT_WIDTH  = $clog2(CLKS_PER_BIT + 1);

    localparam logic [1:0] IDLE  = 2'd0;
    localparam logic [1:0] START = 2'd1;
    localparam logic [1:0] DATA  = 2'd2;
    localparam logic [1:0] STOP  = 2'd3;

    logic [1:0] state;
    logic [COUNT_WIDTH-1:0] clk_count;
    logic [2:0] bit_count;
    logic [7:0] rx_shift;

    // Synchronize the external UART input to the FPGA clock.
    logic rx_sync_1;
    logic rx_sync_2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;
        end else begin
            rx_sync_1 <= rx;
            rx_sync_2 <= rx_sync_1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            clk_count <= '0;
            bit_count <= '0;
            rx_shift  <= 8'h00;
            rx_data   <= 8'h00;
            rx_valid  <= 1'b0;
            rx_busy   <= 1'b0;
        end else begin
            // One-cycle pulse when a complete byte is received.
            rx_valid <= 1'b0;

            case (state)

                IDLE: begin
                    rx_busy   <= 1'b0;
                    clk_count <= '0;
                    bit_count <= '0;

                    // UART start bit is LOW.
                    if (rx_sync_2 == 1'b0) begin
                        state   <= START;
                        rx_busy <= 1'b1;
                    end
                end

                START: begin
                    // Sample halfway through the start bit.
                    if (clk_count == HALF_BIT - 1) begin
                        clk_count <= '0;

                        if (rx_sync_2 == 1'b0) begin
                            state     <= DATA;
                            bit_count <= 3'd0;
                        end else begin
                            // False start bit.
                            state   <= IDLE;
                            rx_busy <= 1'b0;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= '0;

                        // UART sends least-significant bit first.
                        rx_shift[bit_count] <= rx_sync_2;

                        if (bit_count == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        state     <= IDLE;
                        rx_busy   <= 1'b0;

                        // Accept only a valid HIGH stop bit.
                        if (rx_sync_2 == 1'b1) begin
                            rx_data  <= rx_shift;
                            rx_valid <= 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: begin
                    state     <= IDLE;
                    clk_count <= '0;
                    rx_busy   <= 1'b0;
                end

            endcase
        end
    end

endmodule
