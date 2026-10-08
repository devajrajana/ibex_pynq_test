`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer BAUD_RATE = 115_200
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       tx_start,
    input  logic [7:0] tx_data,

    output logic       tx,
    output logic       tx_busy
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer COUNTER_WIDTH = $clog2(CLKS_PER_BIT);

    logic [COUNTER_WIDTH-1:0] clk_count;
    logic [3:0]              bit_count;
    logic [9:0]              tx_shift;

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            clk_count <= '0;
            bit_count <= '0;
            tx_shift  <= 10'b1111111111;
        end

        else begin

            if (!tx_busy) begin

                tx <= 1'b1;

                if (tx_start) begin

                    // UART frame:
                    // bit 0      = start bit
                    // bits 1-8   = data
                    // bit 9      = stop bit

                    tx_shift  <= {1'b1, tx_data, 1'b0};

                    tx_busy   <= 1'b1;
                    clk_count <= '0;
                    bit_count <= 4'd0;

                    // Start bit
                    tx <= 1'b0;
                end

            end

            else begin

                if (clk_count == CLKS_PER_BIT - 1) begin

                    clk_count <= '0;

                    if (bit_count == 4'd9) begin

                        // Transmission complete
                        tx_busy   <= 1'b0;
                        tx        <= 1'b1;
                        bit_count <= '0;

                    end

                    else begin

                        bit_count <= bit_count + 1'b1;

                        tx <= tx_shift[bit_count + 1'b1];

                    end

                end

                else begin

                    clk_count <= clk_count + 1'b1;
                end

            end

        end

    end

endmodule