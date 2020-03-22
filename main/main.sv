
interface sdram_iface_t;
	wire[15:0] Dq;
	logic[11:0] Addr;
	logic[1:0] Ba;
	logic Clk;
	logic Cke;
	logic Cs_n;
	logic Ras_n;
	logic Cas_n;
	logic We_n;
	logic[1:0] Dqm;
endinterface

interface sdram_iface_host_t;
	logic[31:0] wr_addr;
    logic[15:0] wr_data;
    logic wr_enable;

    logic[31:0] rd_addr;
    logic[15:0] rd_data;
    logic rd_ready;
    logic rd_enable;

    logic busy;
    logic rst_n;
    logic clk;
endinterface

module project
#(parameter simulation = 0)
(
    input logic clk_50MHz,

    input logic button_a_i,
    input logic button_b_i,
    input logic button_c_i,
    input logic button_d_i,

    output logic buzz_o,
    output logic led_a_o,
    output logic led_b_o,
    output logic led_c_o,
    output logic led_d_o,

    inout wire[15:0] sd_dq,
    output logic sd_cke,
    output logic sd_clk,
    output logic sd_cs,
    output logic sd_ras,
    output logic sd_cas,
    output logic sd_we,
    output logic sd_ldqm,
    output logic sd_udqm,
    output logic sd_bs0,
    output logic sd_bs1,
    output logic[0:11] sd_sa,

    output logic[7:0] lcd_seg,
    output logic[3:0] lcd_dig,

    output logic[3:0] switch,

    input logic clk_sim_200MHz,
    input logic clk_sim_4MHz
);

    logic device_ready;
	 logic pll_locked, pll2_locked;

    logic por_reset;

    logic clk_pll_200MHz;
    logic clk_200MHz;

    logic clk_pll_4MHz;
    logic clk_4MHz;

    logic button_a;

    assign clk_200MHz = simulation ? clk_sim_200MHz : clk_pll_200MHz;
    assign clk_4MHz = simulation ? clk_sim_4MHz : clk_pll_4MHz;

    mod_por por
        (
            .clk_i  (clk_50MHz),
            .rst_o  (por_reset)
         );

    assign device_ready = simulation ? '1 : pll_locked && pll2_locked;

    pll pll_200MHz
        (
            .areset     (por_reset),
            .inclk0     (clk_50MHz),
            .c0         (clk_pll_200MHz),
            .locked     (pll_locked)
        );
    pll2 pll_4MmHz
        (
            .areset     (por_reset),
            .inclk0     (clk_50MHz),
            .c0         (clk_pll_4MHz),
            .locked     (pll2_locked)
        );

    logic buz_trig = '0;
    logic buz_busy;
    assign led_a_o = !buz_busy;

    mod_buzzer
    #(
        .simulation(simulation)
    ) buzzer (
            .clk_4M_i       (clk_4MHz),
            .period_ms_i    (simulation ? 10 : 600),
            .trig_i         (buz_trig),
            .rst_i          (por_reset),
            .cyc_o          (buz_busy),
            .pin_o          (buzz_o)
        );

    mod_button mod_button_a
        (
            .clk_i          (clk_4MHz),
            .pin_i          (button_a_i),
            .pin_o          (button_a)
        );

    always_ff @ (posedge clk_4MHz) begin
        if (!buz_busy) begin
            buz_trig <= button_a;
        end else begin
            buz_trig <= '0;
        end
    end

    sdram_iface_host_t sdram_if_host();

    sdram_controller sdram_uc
        (
            .wr_addr(sdram_if_host.wr_addr),
            .wr_data(sdram_if_host.wr_data),
            .wr_enable(sdram_if_host.wr_enable),
            .rd_addr(sdram_if_host.rd_addr),
            .rd_data(sdram_if_host.rd_data),
            .rd_ready(sdram_if_host.rd_ready),
            .rd_enable(sdram_if_host.rd_enable),

            .busy(sdram_if_host.busy),
            .rst_n(sdram_if_host.rst_n),
            .clk(sdram_if_host.clk),

            /* SDRAM SIDE */
            .addr(sd_sa),
            .bank_addr({sd_bs1, sd_bs0}),
            .data(sd_dq),
            .clock_enable(sd_cke),
            .cs_n(sd_cs),
            .ras_n(sd_ras),
            .cas_n(sd_cas),
            .we_n(sd_we),
            .data_mask_low(sd_ldqm),
            .data_mask_high(sd_udqm)
        );

endmodule
