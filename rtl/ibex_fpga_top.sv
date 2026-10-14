`timescale 1ns / 1ps

module ibex_fpga_top (
    input  logic       clk,
    input  logic       btn_reset,
    input  logic       uart_rx,
    output logic       uart_tx,
    output logic [3:0] led
);

    // ================================================================
    // CLOCK / RESET
    // ================================================================

    logic reset_n;
    logic ibex_clk;
    logic clk_locked;

    ibex_clk_wiz u_ibex_clk_wiz (
        .clk_out1 (ibex_clk),
        .reset    (btn_reset),
        .locked   (clk_locked),
        .clk_in1  (clk)
    );

    assign reset_n = ~btn_reset & clk_locked;


    // ================================================================
    // UART TX/RX
    // Clock       : 50 MHz (must match the clock-wizard output)
    // Baud rate   : 115200
    // Format      : 8-N-1
    //
    // MMIO:
    //   0x1060 = UART_TXDATA
    //   0x1064 = UART_STATUS (bit 0 = TX busy)
    //   0x1068 = UART_RXDATA (read received byte; clears available)
    //   0x106C = UART_RX_STATUS (bit 0 = byte available, bit 1 = RX busy)
    // ================================================================

    logic       uart_tx_start;
    logic [7:0] uart_tx_data;
    logic       uart_tx_busy;

    uart_tx #(
        .CLK_FREQ  (50_000_000),
        .BAUD_RATE (115_200)
    ) u_uart_tx (
        .clk       (ibex_clk),
        .rst_n     (reset_n),
        .tx_start  (uart_tx_start),
        .tx_data   (uart_tx_data),
        .tx        (uart_tx),
        .tx_busy   (uart_tx_busy)
    );

    // UART RX interface and holding register.
    logic [7:0] uart_rx_data;
    logic       uart_rx_valid;
    logic       uart_rx_busy;
    logic [7:0] uart_rx_data_hold;
    logic       uart_rx_available;
    logic       uart_rx_read;

    uart_rx #(
        .CLK_FREQ  (50_000_000),
        .BAUD_RATE (115_200)
    ) u_uart_rx (
        .clk      (ibex_clk),
        .rst_n    (reset_n),
        .rx       (uart_rx),
        .rx_data  (uart_rx_data),
        .rx_valid (uart_rx_valid),
        .rx_busy  (uart_rx_busy)
    );

    localparam logic [11:0] UART_TXDATA    = 12'h060;
    localparam logic [11:0] UART_STATUS    = 12'h064;
    localparam logic [11:0] UART_RXDATA    = 12'h068;
    localparam logic [11:0] UART_RX_STATUS = 12'h06C;

    // A read of UART_RXDATA acknowledges the held byte. A newly received
    // byte takes priority if it arrives on the same clock as the read.
    always_comb begin
        uart_rx_read = data_req && !data_gnt && !data_we &&
                       (data_addr[11:0] == UART_RXDATA);
    end

    always_ff @(posedge ibex_clk or negedge reset_n) begin
        if (!reset_n) begin
            uart_rx_data_hold <= 8'h00;
            uart_rx_available <= 1'b0;
        end else begin
            if (uart_rx_valid) begin
                uart_rx_data_hold <= uart_rx_data;
                uart_rx_available <= 1'b1;
            end else if (uart_rx_read) begin
                uart_rx_available <= 1'b0;
            end
        end
    end


    // ================================================================
    // INSTRUCTION INTERFACE
    // ================================================================

    logic        instr_req;
    logic        instr_gnt;
    logic        instr_rvalid;
    logic [31:0] instr_addr;
    logic [31:0] instr_rdata;

    logic [12:0] instr_bram_addr;
    logic [31:0] instr_bram_data;

    assign instr_bram_addr = instr_addr[14:2];

    ibex_program_bram u_program_bram (
        .clka  (ibex_clk),
        .ena   (instr_req),
        .wea   (1'b0),
        .addra (instr_bram_addr),
        .dina  (32'h0000_0000),
        .douta (instr_bram_data)
    );

    assign instr_rdata = instr_bram_data;

    always_ff @(posedge ibex_clk or negedge reset_n) begin
        if (!reset_n) begin
            instr_gnt    <= 1'b0;
            instr_rvalid <= 1'b0;
        end
        else begin
            instr_gnt    <= instr_req;
            instr_rvalid <= instr_gnt;
        end
    end


    // ================================================================
    // IBEX DATA INTERFACE
    // ================================================================

    logic        data_req;
    logic        data_gnt;
    logic        data_rvalid;
    logic        data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr;
    logic [31:0] data_wdata;
    logic [31:0] data_rdata;

    logic [31:0] data_rdata_reg;


    // ================================================================
    // CORDIC REGISTER MAP
    //
    // BASE = 0x0000_1000
    //
    // 0x1000 CTRL
    // 0x1004 CIRC_X
    // 0x1008 CIRC_Y
    // 0x100C CIRC_Z
    //
    // 0x1010 LIN_X
    // 0x1014 LIN_Y
    // 0x1018 LIN_Z
    //
    // 0x101C HYP_X
    // 0x1020 HYP_Y
    // 0x1024 HYP_Z
    //
    // 0x1028 START
    // 0x102C STATUS
    // 0x1030 LATENCY
    //
    // 0x1034 CIRC_X_OUT
    // 0x1038 CIRC_Y_OUT
    // 0x103C CIRC_Z_OUT
    //
    // 0x1040 LIN_X_OUT
    // 0x1044 LIN_Y_OUT
    // 0x1048 LIN_Z_OUT
    //
    // 0x104C HYP_X_OUT
    // 0x1050 HYP_Y_OUT
    // 0x1054 HYP_Z_OUT
    // ================================================================


    // ================================================================
    // CORDIC CONTROL / INPUT REGISTERS
    // ================================================================

    logic [31:0] cordic_ctrl;

    logic signed [31:0] cordic_circ_x;
    logic signed [31:0] cordic_circ_y;
    logic signed [31:0] cordic_circ_z;

    logic signed [31:0] cordic_lin_x;
    logic signed [31:0] cordic_lin_y;
    logic signed [31:0] cordic_lin_z;

    logic signed [31:0] cordic_hyp_x;
    logic signed [31:0] cordic_hyp_y;
    logic signed [31:0] cordic_hyp_z;


    // ================================================================
    // CORDIC OUTPUTS
    // ================================================================

    logic signed [31:0] cordic_circ_x_out;
    logic signed [31:0] cordic_circ_y_out;
    logic signed [31:0] cordic_circ_z_out;

    logic signed [31:0] cordic_lin_x_out;
    logic signed [31:0] cordic_lin_y_out;
    logic signed [31:0] cordic_lin_z_out;

    logic signed [31:0] cordic_hyp_x_out;
    logic signed [31:0] cordic_hyp_y_out;
    logic signed [31:0] cordic_hyp_z_out;

    logic [2:0]  cordic_status;
    logic        cordic_busy;
    logic        cordic_done;
    logic [31:0] cordic_latency;


    // ================================================================
    // CORDIC START CONTROL
    // ================================================================

    logic cordic_start;
    logic cordic_start_pending;


    // ================================================================
    // CORDIC INSTANCE
    // ================================================================

    cordic_top u_cordic (
        .clk        (ibex_clk),
        .rst_n      (reset_n),

        .start_i    (cordic_start),

        // Circular
        .circ_x_in  (cordic_circ_x),
        .circ_y_in  (cordic_circ_y),
        .circ_z_in  (cordic_circ_z),

        // Linear
        .lin_x_in   (cordic_lin_x),
        .lin_y_in   (cordic_lin_y),
        .lin_z_in   (cordic_lin_z),

        // Hyperbolic
        .hyp_x_in   (cordic_hyp_x),
        .hyp_y_in   (cordic_hyp_y),
        .hyp_z_in   (cordic_hyp_z),

        // Control
        .ctrl       (cordic_ctrl),

        // Circular outputs
        .circ_x_out (cordic_circ_x_out),
        .circ_y_out (cordic_circ_y_out),
        .circ_z_out (cordic_circ_z_out),

        // Linear outputs
        .lin_x_out  (cordic_lin_x_out),
        .lin_y_out  (cordic_lin_y_out),
        .lin_z_out  (cordic_lin_z_out),

        // Hyperbolic outputs
        .hyp_x_out  (cordic_hyp_x_out),
        .hyp_y_out  (cordic_hyp_y_out),
        .hyp_z_out  (cordic_hyp_z_out),

        // Status
        .status     (cordic_status),

        // Handshake
        .busy_o     (cordic_busy),
        .done_o     (cordic_done),
        .latency_o  (cordic_latency)
    );


    // ================================================================
    // DATA BUS RESPONSE
    // ================================================================

    always_ff @(posedge ibex_clk or negedge reset_n) begin

        if (!reset_n) begin
            data_gnt       <= 1'b0;
            data_rvalid    <= 1'b0;
            data_rdata_reg <= 32'h0000_0000;
        end

        else begin

            // Handshake
            data_gnt    <= data_req;
            data_rvalid <= data_gnt;

            // --------------------------------------------------------
            // READ
            // --------------------------------------------------------

            if (data_req && !data_gnt && !data_we) begin

                case (data_addr[11:0])

                    // ------------------------------------------------
                    // CORDIC STATUS
                    // ------------------------------------------------

                    12'h02C:
                        data_rdata_reg <= {29'd0, cordic_status};

                    // CORDIC LATENCY
                    12'h030:
                        data_rdata_reg <= cordic_latency;

                    // ------------------------------------------------
                    // CORDIC CIRCULAR OUTPUTS
                    // ------------------------------------------------

                    12'h034:
                        data_rdata_reg <= cordic_circ_x_out;

                    12'h038:
                        data_rdata_reg <= cordic_circ_y_out;

                    12'h03C:
                        data_rdata_reg <= cordic_circ_z_out;

                    // ------------------------------------------------
                    // CORDIC LINEAR OUTPUTS
                    // ------------------------------------------------

                    12'h040:
                        data_rdata_reg <= cordic_lin_x_out;

                    12'h044:
                        data_rdata_reg <= cordic_lin_y_out;

                    12'h048:
                        data_rdata_reg <= cordic_lin_z_out;

                    // ------------------------------------------------
                    // CORDIC HYPERBOLIC OUTPUTS
                    // ------------------------------------------------

                    12'h04C:
                        data_rdata_reg <= cordic_hyp_x_out;

                    12'h050:
                        data_rdata_reg <= cordic_hyp_y_out;

                    12'h054:
                        data_rdata_reg <= cordic_hyp_z_out;

                    // ------------------------------------------------
                    // UART STATUS
                    //
                    // bit 0 = TX busy
                    // ------------------------------------------------

                    UART_STATUS:
                        data_rdata_reg <= {31'd0, uart_tx_busy};

                    // Most recently received byte.
                    UART_RXDATA:
                        data_rdata_reg <= {24'd0, uart_rx_data_hold};

                    // bit 0 = unread byte available; bit 1 = receiver busy.
                    UART_RX_STATUS:
                        data_rdata_reg <= {30'd0, uart_rx_busy, uart_rx_available};

                    default:
                        data_rdata_reg <= 32'h0000_0000;

                endcase

            end

        end

    end

    assign data_rdata = data_rdata_reg;


    // ================================================================
    // CORDIC + UART REGISTER WRITE LOGIC
    // ================================================================

    always_ff @(posedge ibex_clk or negedge reset_n) begin

        if (!reset_n) begin

            // --------------------------------------------------------
            // CORDIC registers
            // --------------------------------------------------------

            cordic_ctrl <= 32'h0000_0000;

            cordic_circ_x <= 32'sd0;
            cordic_circ_y <= 32'sd0;
            cordic_circ_z <= 32'sd0;

            cordic_lin_x <= 32'sd0;
            cordic_lin_y <= 32'sd0;
            cordic_lin_z <= 32'sd0;

            cordic_hyp_x <= 32'sd0;
            cordic_hyp_y <= 32'sd0;
            cordic_hyp_z <= 32'sd0;

            cordic_start_pending <= 1'b0;
            cordic_start         <= 1'b0;

            // --------------------------------------------------------
            // UART registers
            // --------------------------------------------------------

            uart_tx_start <= 1'b0;
            uart_tx_data  <= 8'h00;

        end

        else begin

            // --------------------------------------------------------
            // CORDIC START PULSE
            // --------------------------------------------------------

            cordic_start <= cordic_start_pending;

            cordic_start_pending <= 1'b0;

            // --------------------------------------------------------
            // UART START PULSE
            // --------------------------------------------------------

            uart_tx_start <= 1'b0;


            // --------------------------------------------------------
            // WRITE REQUEST
            // --------------------------------------------------------

            if (data_req && !data_gnt && data_we) begin

                case (data_addr[11:0])

                    // =================================================
                    // CORDIC CONTROL
                    // =================================================

                    12'h000:
                        cordic_ctrl <= data_wdata;


                    // =================================================
                    // CIRCULAR INPUTS
                    // =================================================

                    12'h004:
                        cordic_circ_x <= data_wdata;

                    12'h008:
                        cordic_circ_y <= data_wdata;

                    12'h00C:
                        cordic_circ_z <= data_wdata;


                    // =================================================
                    // LINEAR INPUTS
                    // =================================================

                    12'h010:
                        cordic_lin_x <= data_wdata;

                    12'h014:
                        cordic_lin_y <= data_wdata;

                    12'h018:
                        cordic_lin_z <= data_wdata;


                    // =================================================
                    // HYPERBOLIC INPUTS
                    // =================================================

                    12'h01C:
                        cordic_hyp_x <= data_wdata;

                    12'h020:
                        cordic_hyp_y <= data_wdata;

                    12'h024:
                        cordic_hyp_z <= data_wdata;


                    // =================================================
                    // CORDIC START
                    // =================================================

                    12'h028:
                        if (data_wdata[0])
                            cordic_start_pending <= 1'b1;


                    // =================================================
                    // UART TX DATA
                    //
                    // Write one byte to start transmission.
                    // =================================================

                    UART_TXDATA:
                        if (!uart_tx_busy) begin
                            uart_tx_data  <= data_wdata[7:0];
                            uart_tx_start  <= 1'b1;
                        end


                    default:
                        ;

                endcase

            end

        end

    end


    // ================================================================
    // INSTRUCTION EXECUTION COUNTER
    // ================================================================

    logic [25:0] instruction_count;

    always_ff @(posedge ibex_clk or negedge reset_n) begin

        if (!reset_n) begin
            instruction_count <= 26'd0;
        end

        else if (instr_rvalid) begin
            instruction_count <= instruction_count + 26'd1;
        end

    end

    always_comb begin
        led = instruction_count[25:22];
    end


    // ================================================================
    // IBEX CORE
    // ================================================================

    logic alert_minor;
    logic alert_major_internal;
    logic alert_major_bus;
    logic core_sleep;

    ibex_top #(
        .BaseIsa          (ibex_pkg::BaseIsaRV32I),
        .PMPEnable        (1'b0),
        .PMPGranularity   (0),
        .PMPNumRegions    (4),
        .MHPMCounterNum   (0),
        .MHPMCounterWidth (40),
        .RV32E            (1'b0),
        .RV32M            (ibex_pkg::RV32MNone),
        .RV32B            (ibex_pkg::RV32BNone),
        .RV32ZC           (ibex_pkg::RV32Zca),
        .RegFile          (ibex_pkg::RegFileFPGA),
        .BranchTargetALU  (1'b0),
        .WritebackStage   (1'b0),
        .ICache           (1'b0),
        .ICacheECC        (1'b0),
        .BranchPredictor  (1'b0),
        .DbgTriggerEn     (1'b0),
        .DbgHwBreakNum    (1),
        .SecureIbex       (1'b0),
        .LockstepOffset   (1),
        .MemECC           (1'b0),
        .MemDataWidth     (32),
        .ICacheScramble   (1'b0),
        .ICacheScrNumPrinceRoundsHalf(2),
        .ICacheTweakInfection(1'b0),
        .DmBaseAddr       (32'h1A11_0000),
        .DmAddrMask       (32'h0000_0FFF),
        .DmHaltAddr       (32'h1A11_0800),
        .DmExceptionAddr  (32'h1A11_0808),
        .CsrMvendorId     (32'h0000_0000),
        .CsrMimpId        (32'h0000_0000)
    ) u_ibex_top (

        .clk_i                  (ibex_clk),
        .rst_ni                 (reset_n),

        .test_en_i              (1'b0),

        .ram_cfg_icache_tag_i   ('0),
        .ram_cfg_icache_tag_o   (),

        .ram_cfg_icache_data_i  ('0),
        .ram_cfg_icache_data_o  (),

        .cheriot_enable_i       (ibex_pkg::IbexMuBiOff),

        .hart_id_i              (32'h0000_0000),
        .boot_addr_i            (32'h0000_0000),
        .trvk_heap_base_addr_i  (32'h0000_0000),

        // ------------------------------------------------------------
        // Instruction interface
        // ------------------------------------------------------------

        .instr_req_o            (instr_req),
        .instr_gnt_i            (instr_gnt),
        .instr_rvalid_i         (instr_rvalid),
        .instr_addr_o           (instr_addr),
        .instr_rdata_i          (instr_rdata),
        .instr_rdata_intg_i     ('0),
        .instr_err_i            (1'b0),

        // ------------------------------------------------------------
        // Data interface
        // ------------------------------------------------------------

        .data_req_o             (data_req),
        .data_gnt_i             (data_gnt),
        .data_rvalid_i          (data_rvalid),
        .data_we_o              (data_we),
        .data_be_o              (data_be),
        .data_addr_o            (data_addr),
        .data_wdata_o           (data_wdata),
        .data_wdata_intg_o      (),
        .data_tag_o             (),
        .data_rdata_i           (data_rdata),
        .data_rdata_intg_i      ('0),
        .data_tag_i             (1'b0),
        .data_err_i             (1'b0),

        // ------------------------------------------------------------
        // Translation / debug
        // ------------------------------------------------------------

        .trvk_revbm_req_o       (),
        .trvk_revbm_gnt_i       (1'b0),
        .trvk_revbm_rvalid_i    (1'b0),
        .trvk_revbm_addr_o      (),
        .trvk_revbm_rdata_i     (32'h0000_0000),
        .trvk_revbm_rdata_intg_i('0),
        .trvk_revbm_err_i       (1'b0),

        // ------------------------------------------------------------
        // Interrupts
        // ------------------------------------------------------------

        .irq_software_i         (1'b0),
        .irq_timer_i            (1'b0),
        .irq_external_i         (1'b0),
        .irq_fast_i             ('0),
        .irq_nm_i               (1'b0),

        // ------------------------------------------------------------
        // Scrambling
        // ------------------------------------------------------------

        .scramble_key_valid_i   (1'b0),
        .scramble_key_i         ('0),
        .scramble_nonce_i       ('0),
        .scramble_req_o         (),

        // ------------------------------------------------------------
        // Debug
        // ------------------------------------------------------------

        .debug_req_i            (1'b0),

        .crash_dump_o           (),
        .double_fault_seen_o    (),

        // ------------------------------------------------------------
        // Fetch / counters
        // ------------------------------------------------------------

        .fetch_enable_i         (ibex_pkg::IbexMuBiOn),
        .mcounteren_writable_i  (ibex_pkg::IbexMuBiOff),

        // ------------------------------------------------------------
        // Alerts
        // ------------------------------------------------------------

        .alert_minor_o          (alert_minor),
        .alert_major_internal_o (alert_major_internal),
        .alert_major_bus_o      (alert_major_bus),

        .core_sleep_o           (core_sleep),

        // ------------------------------------------------------------
        // Scan / lockstep
        // ------------------------------------------------------------

        .scan_rst_ni            (1'b1),

        .lockstep_cmp_en_o      (),

        .data_req_shadow_o      (),
        .data_we_shadow_o       (),
        .data_be_shadow_o       (),
        .data_addr_shadow_o     (),
        .data_wdata_shadow_o    (),
        .data_wdata_intg_shadow_o(),

        .instr_req_shadow_o     (),
        .instr_addr_shadow_o    ()
    );

endmodule