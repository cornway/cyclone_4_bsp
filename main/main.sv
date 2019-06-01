
module project 
(
    input logic clk_50MHz,

    input logic button_a_i,

    output logic buzz_o,
    output logic led_a_o
);

    logic device_ready;

    logic por_reset;

    logic pll_clock_o;
    logic[9 : 0] clock_presc = '0;
    logic clock_200MHz;
    logic clock_button;
    logic clock_1MHz;
    logic clock_core;

    logic button_a;

    assign clock_200MHz = pll_clock_o;
    assign clock_core = clock_200MHz;

    mod_por por
        (
            .clk_i  (clk_50MHz),
            .rst_o  (por_reset)
         );

    logic pll_locked;

    assign device_ready = pll_locked;

    assign clock_button = clock_presc[7];

    assign led_a_o = button_a;

    always_ff @ (posedge clock_200MHz) begin
        clock_presc <= clock_presc + 1'b1;
    end

    pll pll_main
        (
            .areset     (por_reset),
            .inclk0     (clk_50MHz),
            .c0         (pll_clock_o),
            .locked     (pll_locked)
        );

    mod_presc presc_1MHz
        (
            .clk_i      (clock_200MHz),
            .presc_i    (200),
            .rst_i      (por_reset),
            .clk_o      (clock_1MHz)
        );

    logic buz_trig = '0;
    logic buz_busy;

    mod_buzzer buzzer
        (
            .clk_i_1MHz     (clock_1MHz),
            .period_ms_i    (1000),
            .trig_i         (buz_trig),
            .rst_i          (por_reset),
            .pin_act_lvl_i  ('1),
            .cyc_o          (buz_busy),
            .pin_o          (buzz_o)
        );

    mod_button mod_button_a
        (
            .clk_i          (clock_button),
            .pin_i          (button_a_i),
            .pin_o          (button_a)
        );

    always_ff @ (posedge clock_core) begin
        if (!buz_busy) begin
            buz_trig <= button_a;
        end else begin
            buz_trig <= '0;
        end
    end

endmodule
