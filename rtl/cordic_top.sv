// ================================================================
// FILE     : cordic_top_gpio.v  (v5 - Full Hardware Gain)
// PROJECT  : Latency-Controlled Parallel Pipeline CORDIC Accelerator
// BOARD    : PYNQ-Z2 (Zynq XC7Z020)
// STUDENT  : Devaj Rajana
//
// CTRL WORD (32-bit):
//   [0]     = circ_op    (0=rotation, 1=vectoring)
//   [1]     = lin_op     (0=multiply, 1=divide)
//   [2]     = hyp_op     (0=rotation, 1=vectoring)
//   [7:3]   = circ_lat   (1-16 pipeline stages)
//   [12:8]  = lin_lat    (1-16 pipeline stages)
//   [17:13] = hyp_lat    (1-16 pipeline stages)
//   [18]    = lin_b_sign (sign bit for b scaling)
//   [23:19] = lin_b_shift(how many times b was halved, 0-15)
//
// GAIN CONSTANTS Q16.16:
//   K_CIR_INV = 0.6072529350 * 65536 = 39797 = 0x9B75
//   K_HYP_INV = 1.2074977235 * 65536 = 79156 = 0x13514
// ================================================================

`timescale 1ns / 1ps

// ================================================================
// Q16.16 MULTIPLIER
// result = (a * b) >> 16
// ================================================================
module q16_mul (
    input  wire signed [31:0] a,
    input  wire signed [31:0] b,
    output wire signed [31:0] result
);
    wire signed [63:0] product = a * b;
    assign result = product[47:16];
endmodule


// ================================================================
// SINGLE CORDIC STAGE
// ================================================================
module cordic_stage_p #(
    parameter integer DATA_WIDTH  = 32,
    parameter integer STAGE_INDEX = 0,
    parameter integer MODE_TYPE   = 0
)(
    input  wire signed [DATA_WIDTH-1:0] x_in,
    input  wire signed [DATA_WIDTH-1:0] y_in,
    input  wire signed [DATA_WIDTH-1:0] z_in,
    input  wire                          op,
    output reg  signed [DATA_WIDTH-1:0] x_out,
    output reg  signed [DATA_WIDTH-1:0] y_out,
    output reg  signed [DATA_WIDTH-1:0] z_out
);
    reg signed [31:0] angle_step;

    always @(*) begin
        if (MODE_TYPE == 0) begin
            case (STAGE_INDEX)
                0:  angle_step = 32'd2949120;
                1:  angle_step = 32'd1740992;
                2:  angle_step = 32'd919872;
                3:  angle_step = 32'd466944;
                4:  angle_step = 32'd234304;
                5:  angle_step = 32'd117312;
                6:  angle_step = 32'd58688;
                7:  angle_step = 32'd29312;
                8:  angle_step = 32'd14656;
                9:  angle_step = 32'd7328;
                10: angle_step = 32'd3664;
                11: angle_step = 32'd1832;
                12: angle_step = 32'd916;
                13: angle_step = 32'd458;
                14: angle_step = 32'd229;
                15: angle_step = 32'd114;
                default: angle_step = 32'd0;
            endcase
        end else if (MODE_TYPE == 1) begin
            case (STAGE_INDEX)
                0:  angle_step = 32'h00010000;
                1:  angle_step = 32'h00008000;
                2:  angle_step = 32'h00004000;
                3:  angle_step = 32'h00002000;
                4:  angle_step = 32'h00001000;
                5:  angle_step = 32'h00000800;
                6:  angle_step = 32'h00000400;
                7:  angle_step = 32'h00000200;
                8:  angle_step = 32'h00000100;
                9:  angle_step = 32'h00000080;
                10: angle_step = 32'h00000040;
                11: angle_step = 32'h00000020;
                12: angle_step = 32'h00000010;
                13: angle_step = 32'h00000008;
                14: angle_step = 32'h00000004;
                15: angle_step = 32'h00000002;
                default: angle_step = 32'h00000001;
            endcase
        end else begin
            case (STAGE_INDEX)
                0:  angle_step = 32'd2062438;
                1:  angle_step = 32'd959437;
                2:  angle_step = 32'd471921;
                3:  angle_step = 32'd234988;
                4:  angle_step = 32'd117375;
                5:  angle_step = 32'd58701;
                6:  angle_step = 32'd29318;
                7:  angle_step = 32'd14659;
                8:  angle_step = 32'd7329;
                9:  angle_step = 32'd3665;
                10: angle_step = 32'd1832;
                11: angle_step = 32'd916;
                12: angle_step = 32'd458;
                13: angle_step = 32'd229;
                14: angle_step = 32'd114;
                15: angle_step = 32'd57;
                default: angle_step = 32'd0;
            endcase
        end
    end

    // Hyperbolic starts at i=1 → shift by STAGE_INDEX+1
    wire signed [DATA_WIDTH-1:0] x_shift;
    wire signed [DATA_WIDTH-1:0] y_shift;

    generate
        if (MODE_TYPE == 2) begin
            assign x_shift = $signed(x_in) >>> (STAGE_INDEX + 1);
            assign y_shift = $signed(y_in) >>> (STAGE_INDEX + 1);
        end else begin
            assign x_shift = $signed(x_in) >>> STAGE_INDEX;
            assign y_shift = $signed(y_in) >>> STAGE_INDEX;
        end
    endgenerate

    // sigma: rotation=1 if z>=0, vectoring=1 if y<0
    wire sigma = op ? y_in[DATA_WIDTH-1] : ~z_in[DATA_WIDTH-1];

    always @(*) begin
        if (MODE_TYPE == 1) begin
            x_out = x_in;
            y_out = sigma ? (y_in + x_shift) : (y_in - x_shift);
            z_out = sigma ? (z_in - angle_step) : (z_in + angle_step);
        end else if (MODE_TYPE == 2) begin
            x_out = sigma ? (x_in + y_shift) : (x_in - y_shift);
            y_out = sigma ? (y_in + x_shift) : (y_in - x_shift);
            z_out = sigma ? (z_in - angle_step) : (z_in + angle_step);
        end else begin
            x_out = sigma ? (x_in - y_shift) : (x_in + y_shift);
            y_out = sigma ? (y_in + x_shift) : (y_in - x_shift);
            z_out = sigma ? (z_in - angle_step) : (z_in + angle_step);
        end
    end
endmodule


// ================================================================
// GENERIC PIPELINE
// ================================================================
module cordic_pipeline_generic #(
    parameter integer DATA_WIDTH    = 32,
    parameter integer MAX_STAGES    = 16,
    parameter integer LATENCY_WIDTH = 5,
    parameter integer MODE_TYPE     = 0
)(
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire signed [DATA_WIDTH-1:0]  x_in,
    input  wire signed [DATA_WIDTH-1:0]  y_in,
    input  wire signed [DATA_WIDTH-1:0]  z_in,
    input  wire                           op,
    input  wire [LATENCY_WIDTH-1:0]       latency_budget,
    output reg  signed [DATA_WIDTH-1:0]  x_out,
    output reg  signed [DATA_WIDTH-1:0]  y_out,
    output reg  signed [DATA_WIDTH-1:0]  z_out,
    output reg                            valid_out
);
    reg signed [DATA_WIDTH-1:0] xp [0:MAX_STAGES];
    reg signed [DATA_WIDTH-1:0] yp [0:MAX_STAGES];
    reg signed [DATA_WIDTH-1:0] zp [0:MAX_STAGES];
    reg                          op_p [0:MAX_STAGES];

    wire signed [DATA_WIDTH-1:0] xs [0:MAX_STAGES-1];
    wire signed [DATA_WIDTH-1:0] ys [0:MAX_STAGES-1];
    wire signed [DATA_WIDTH-1:0] zs [0:MAX_STAGES-1];

    always @(*) begin
        xp[0] = x_in; yp[0] = y_in; zp[0] = z_in; op_p[0] = op;
    end

    genvar i;
    generate
        for (i = 0; i < MAX_STAGES; i = i + 1) begin : stages
            cordic_stage_p #(
                .DATA_WIDTH(DATA_WIDTH),
                .STAGE_INDEX(i),
                .MODE_TYPE(MODE_TYPE)
            ) u_stg (
                .x_in(xp[i]), .y_in(yp[i]), .z_in(zp[i]),
                .op(op_p[i]),
                .x_out(xs[i]), .y_out(ys[i]), .z_out(zs[i])
            );
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    xp[i+1]<=0; yp[i+1]<=0; zp[i+1]<=0; op_p[i+1]<=0;
                end else begin
                    xp[i+1]<=xs[i]; yp[i+1]<=ys[i]; zp[i+1]<=zs[i];
                    op_p[i+1]<=op_p[i];
                end
            end
        end
    endgenerate

    always @(*) begin
        x_out     = xp[latency_budget];
        y_out     = yp[latency_budget];
        z_out     = zp[latency_budget];
        valid_out = 1'b1;
    end
endmodule


// ================================================================
// PROCESSOR-READY TOP MODULE
//
// Purpose:
//   Interface the existing multi-mode CORDIC datapath to the Ibex
//   RISC-V processor as a tightly-coupled coprocessor.
//
// Key interface change from cordic_top_gpio.v:
//   - Explicit one-cycle start_i input from the processor.
//   - Inputs/control are latched when an operation is accepted.
//   - done_o is sticky until the next accepted operation.
//   - busy_o indicates that the CORDIC transaction is in progress.
//   - latency_o reports the measured start-to-done cycle count.
//   - No ctrl-change detection and no AXI GPIO signals.
//
// ================================================================
module cordic_top (
    input  wire        clk,
    input  wire        rst_n,

    // Processor-issued operation request.
    // MUST be a one-clock pulse for each CORDIC operation.
    input  wire        start_i,

    // Circular inputs
    input  wire signed [31:0] circ_x_in,
    input  wire signed [31:0] circ_y_in,
    input  wire signed [31:0] circ_z_in,

    // Linear inputs
    input  wire signed [31:0] lin_x_in,
    input  wire signed [31:0] lin_y_in,
    input  wire signed [31:0] lin_z_in,

    // Hyperbolic inputs
    input  wire signed [31:0] hyp_x_in,
    input  wire signed [31:0] hyp_y_in,
    input  wire signed [31:0] hyp_z_in,

    // Control word
    input  wire [31:0] ctrl,

    // Circular outputs
    output wire signed [31:0] circ_x_out,
    output wire signed [31:0] circ_y_out,
    output wire signed [31:0] circ_z_out,

    // Linear outputs
    output wire signed [31:0] lin_x_out,
    output wire signed [31:0] lin_y_out,
    output wire signed [31:0] lin_z_out,

    // Hyperbolic outputs
    output wire signed [31:0] hyp_x_out,
    output wire signed [31:0] hyp_y_out,
    output wire signed [31:0] hyp_z_out,

    // Status: [2]=busy, [1]=done, [0]=ready
    output wire [2:0]  status,

    // Coprocessor handshake / measurement
    output wire        busy_o,
    output wire        done_o,
    output wire [31:0] latency_o
);

    // ================================================================
    // GAIN CONSTANTS Q16.16
    // ================================================================
    localparam signed [31:0] K_CIR_INV_Q16 = 32'h00009B75;
    localparam signed [31:0] K_HYP_INV_Q16 = 32'h00013514;

    // ================================================================
    // TRANSACTION INPUT REGISTERS
    //
    // Software writes the CSR values before issuing CUSTOM_0.
    // The processor-side integration presents those CSR values here.
    // Latching them on start prevents inputs from changing while the
    // multi-cycle CORDIC operation is in progress.
    // ================================================================
    reg [31:0]        ctrl_q;
    reg signed [31:0] circ_x_q, circ_y_q, circ_z_q;
    reg signed [31:0] lin_x_q,  lin_y_q,  lin_z_q;
    reg signed [31:0] hyp_x_q,  hyp_y_q,  hyp_z_q;

    wire circ_op = ctrl_q[0];
    wire lin_op  = ctrl_q[1];
    wire hyp_op  = ctrl_q[2];

    wire [4:0] circ_lat_raw = ctrl_q[7:3];
    wire [4:0] lin_lat_raw  = ctrl_q[12:8];
    wire [4:0] hyp_lat_raw  = ctrl_q[17:13];

    wire [4:0] circ_lat = (circ_lat_raw == 0) ? 5'd1 :
                          (circ_lat_raw > 16) ? 5'd16 : circ_lat_raw;
    wire [4:0] lin_lat  = (lin_lat_raw == 0) ? 5'd1 :
                          (lin_lat_raw > 16) ? 5'd16 : lin_lat_raw;
    wire [4:0] hyp_lat  = (hyp_lat_raw == 0) ? 5'd1 :
                          (hyp_lat_raw > 16) ? 5'd16 : hyp_lat_raw;

    wire [4:0] max_lat = (circ_lat >= lin_lat) ?
                         ((circ_lat >= hyp_lat) ? circ_lat : hyp_lat) :
                         ((lin_lat  >= hyp_lat) ? lin_lat  : hyp_lat);

    // ================================================================
    // COPROCESSOR CONTROL / LATENCY STATE
    //
    // start_i is a pulse generated by the Ibex execute-stage logic.
    // A request is accepted only while idle. The operation is complete
    // after max(circ_lat, lin_lat, hyp_lat) pipeline clocks.
    // ================================================================
    reg        busy_reg;
    reg        done_reg;
    reg [31:0] cycle_counter;
    reg [31:0] start_cycle;
    reg [31:0] latency_reg;
    reg [31:0] lat_counter;

    // A free-running 32-bit cycle counter is sufficient for benchmark
    // runs as long as a single measured transaction does not span the
    // full counter range.
    always @(posedge clk) begin
        if (!rst_n)
            cycle_counter <= 32'd0;
        else
            cycle_counter <= cycle_counter + 32'd1;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            ctrl_q      <= 32'd0;
            circ_x_q    <= 32'sd0;
            circ_y_q    <= 32'sd0;
            circ_z_q    <= 32'sd0;
            lin_x_q     <= 32'sd0;
            lin_y_q     <= 32'sd0;
            lin_z_q     <= 32'sd0;
            hyp_x_q     <= 32'sd0;
            hyp_y_q     <= 32'sd0;
            hyp_z_q     <= 32'sd0;

            busy_reg    <= 1'b0;
            done_reg    <= 1'b0;
            start_cycle <= 32'd0;
            latency_reg <= 32'd0;
            lat_counter <= 32'd0;
        end else begin
            // ----------------------------------------------------------
            // Accept a new transaction.
            // start_i should be a one-cycle pulse from Ibex.
            // ----------------------------------------------------------
            if (start_i && !busy_reg) begin
                ctrl_q   <= ctrl;

                circ_x_q <= circ_x_in;
                circ_y_q <= circ_y_in;
                circ_z_q <= circ_z_in;

                lin_x_q  <= lin_x_in;
                lin_y_q  <= lin_y_in;
                lin_z_q  <= lin_z_in;

                hyp_x_q  <= hyp_x_in;
                hyp_y_q  <= hyp_y_in;
                hyp_z_q  <= hyp_z_in;

                busy_reg    <= 1'b1;
                done_reg    <= 1'b0;
                lat_counter <= 32'd0;
                start_cycle <= cycle_counter;
            end
            // ----------------------------------------------------------
            // Wait for the selected pipeline depth.
            // For N stages, the newly latched transaction reaches the
            // selected output after N clocks; DONE is asserted on that
            // same clock edge.
            // ----------------------------------------------------------
            else if (busy_reg) begin
                if ((lat_counter + 32'd1) >= {27'd0, max_lat}) begin
                    lat_counter <= lat_counter + 32'd1;
                    latency_reg <= cycle_counter - start_cycle;
                    busy_reg    <= 1'b0;
                    done_reg    <= 1'b1;
                end else begin
                    lat_counter <= lat_counter + 32'd1;
                end
            end
        end
    end

    // ================================================================
    // HARDWARE x-INITIALIZATION
    // ================================================================
    wire signed [31:0] circ_x_pipe;
    wire signed [31:0] circ_y_pipe;
    wire signed [31:0] hyp_x_pipe;
    wire signed [31:0] hyp_y_pipe;

    // Rotation: substitute gain correction at the pipeline input.
    // Vectoring: use the software-provided x/y operands.
    assign circ_x_pipe = circ_op ? circ_x_q : K_CIR_INV_Q16;
    assign circ_y_pipe = circ_op ? circ_y_q : 32'sd0;

    assign hyp_x_pipe  = hyp_op  ? hyp_x_q  : K_HYP_INV_Q16;
    assign hyp_y_pipe  = hyp_op  ? hyp_y_q  : 32'sd0;

    // ================================================================
    // THREE PARALLEL CORDIC PIPELINES
    // ================================================================
    wire signed [31:0] circ_xr, circ_yr, circ_zr;
    wire signed [31:0] lin_xr,  lin_yr,  lin_zr;
    wire signed [31:0] hyp_xr,  hyp_yr,  hyp_zr;
    wire circ_vld, lin_vld, hyp_vld;

    cordic_pipeline_generic #(
        .DATA_WIDTH(32),
        .MAX_STAGES(16),
        .LATENCY_WIDTH(5),
        .MODE_TYPE(0)
    ) u_circ (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(circ_x_pipe),
        .y_in(circ_y_pipe),
        .z_in(circ_z_q),
        .op(circ_op),
        .latency_budget(circ_lat),
        .x_out(circ_xr),
        .y_out(circ_yr),
        .z_out(circ_zr),
        .valid_out(circ_vld)
    );

    cordic_pipeline_generic #(
        .DATA_WIDTH(32),
        .MAX_STAGES(16),
        .LATENCY_WIDTH(5),
        .MODE_TYPE(1)
    ) u_lin (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(lin_x_q),
        .y_in(lin_y_q),
        .z_in(lin_z_q),
        .op(lin_op),
        .latency_budget(lin_lat),
        .x_out(lin_xr),
        .y_out(lin_yr),
        .z_out(lin_zr),
        .valid_out(lin_vld)
    );

    cordic_pipeline_generic #(
        .DATA_WIDTH(32),
        .MAX_STAGES(16),
        .LATENCY_WIDTH(5),
        .MODE_TYPE(2)
    ) u_hyp (
        .clk(clk),
        .rst_n(rst_n),
        .x_in(hyp_x_pipe),
        .y_in(hyp_y_pipe),
        .z_in(hyp_z_q),
        .op(hyp_op),
        .latency_budget(hyp_lat),
        .x_out(hyp_xr),
        .y_out(hyp_yr),
        .z_out(hyp_zr),
        .valid_out(hyp_vld)
    );

    // ================================================================
    // HARDWARE GAIN CORRECTION
    // ================================================================
    wire signed [31:0] circ_x_gained;
    wire signed [31:0] hyp_x_gained;

    q16_mul u_circ_gain (
        .a(circ_xr),
        .b(K_CIR_INV_Q16),
        .result(circ_x_gained)
    );

    q16_mul u_hyp_gain (
        .a(hyp_xr),
        .b(K_HYP_INV_Q16),
        .result(hyp_x_gained)
    );

    // Rotation: gain already applied at the input.
    // Vectoring: apply gain correction to X magnitude.
    assign circ_x_out = circ_op ? circ_x_gained : circ_xr;
    assign circ_y_out = circ_yr;
    assign circ_z_out = circ_zr;

    assign lin_x_out  = lin_xr;
    assign lin_y_out  = lin_yr;
    assign lin_z_out  = lin_zr;

    assign hyp_x_out  = hyp_op ? hyp_x_gained : hyp_xr;
    assign hyp_y_out  = hyp_yr;
    assign hyp_z_out  = hyp_zr;

    // ================================================================
    // COPROCESSOR STATUS / HANDSHAKE
    // ================================================================
    assign busy_o    = busy_reg;
    assign done_o    = done_reg;
    assign latency_o = latency_reg;

    // [2] busy, [1] done, [0] ready
    assign status = {busy_reg, done_reg, ~busy_reg};

endmodule
