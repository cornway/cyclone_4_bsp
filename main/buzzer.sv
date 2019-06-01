
module mod_buzzer
#(
    parameter BUZ_PERIOD_MS = 3000
)
    (
        input logic clk_i_1MHz,
        input logic[$clog2(BUZ_PERIOD_MS) : 0] period_ms_i,
        input logic trig_i,
        input logic rst_i,
        input logic pin_act_lvl_i,

        output logic cyc_o,
        output logic pin_o
    );

    logic clk_1KHz;
    logic[$clog2(1000) : 0] clk_presc = '0;
    logic[$clog2(BUZ_PERIOD_MS) : 0] period = '0;

    enum logic[1 : 0] {BUZ_IDLE, BUZ_BEEP, BUZ_DONE} buzstate     = BUZ_IDLE,
                                                     buznextstate = BUZ_IDLE;
    assign clk_1KHz = clk_presc[$clog2(1000) - 1];

    always_ff @(posedge clk_i_1MHz) begin
        clk_presc <= clk_presc + 1'b1;
    end

    always_comb begin
        buzstate = buznextstate;
    end

    always @(posedge clk_1KHz) begin
        if (rst_i) begin
            buznextstate <= BUZ_IDLE;
            period <= '0;
            cyc_o <= '0;
            pin_o <= ~pin_act_lvl_i;
        end else begin
            case (buzstate)
                BUZ_IDLE :
                begin
                    if (trig_i) begin
                        period <= period_ms_i;
                        pin_o <= ~pin_act_lvl_i;
                        cyc_o <= '1;
                        buznextstate <= BUZ_BEEP;
                    end
                end
                BUZ_BEEP :
                begin
                    if (period == '0) begin
                        buznextstate <= BUZ_DONE;
                    end else begin
                        pin_o = ~pin_o;
                    end
                end
                BUZ_DONE :
                begin
                    period <= '0;
                    cyc_o <= '0;
                    pin_o <= ~pin_act_lvl_i;
                    buznextstate <= BUZ_IDLE;
                end
            endcase
        end
    end

endmodule
