
module project
#(parameter simulation = 0)
(
    input logic clk_50MHz,

    input logic button_a_i,

    output logic buzz_o,
    output logic led_a_o,

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

endmodule
