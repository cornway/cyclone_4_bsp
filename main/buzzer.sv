
module mod_buzzer
#(
    parameter simulation = 0
)
    (
        input logic clk_4M_i,
        input logic[31 : 0] period_ms_i,
        input logic trig_i,
        input logic rst_i,

        output logic cyc_o,
        output logic pin_o
    );

    logic pin_int = '0, pin_int_sim = '0;
    logic[10 : 0] clk_4M_cnt = '0;
    logic[31 : 0] period = '0;

    enum logic[1 : 0] {state_idle, state_beep, state_done} beep_state     = state_idle,
                                                     beep_state_next = state_idle;

    always_ff @(posedge clk_4M_i) begin
        if (simulation) begin
            pin_int_sim <= ~pin_int_sim;
        end
    end

    assign pin_o = simulation ? pin_int_sim : pin_int;

    always_comb begin
        beep_state = beep_state_next;
    end

    always @(posedge clk_4M_i, posedge rst_i) begin
        if (rst_i) begin
            beep_state_next <= state_idle;
            cyc_o <= '0;
            period <= '0;
        end else begin
            case (beep_state)
                state_idle :
                begin
                    if (trig_i) begin
                        cyc_o <= '1;
                        period <= period_ms_i;
                        clk_4M_cnt <= '0;
                        beep_state_next <= state_beep;
                    end
                end
                state_beep :
                begin
                    if (period == '0) begin
                        beep_state_next <= state_done;
                    end else begin
                        if (clk_4M_cnt == (simulation ? 10 : 2000)) begin
                            clk_4M_cnt <= '0;
                            period <= period - pin_int;
                            pin_int <= ~pin_int;
                        end else begin
                            clk_4M_cnt <= clk_4M_cnt + 1'b1;
                        end
                    end
                end
                state_done :
                begin
                    cyc_o <= '0;
                    beep_state_next <= state_idle;
                end
            endcase
        end
    end

endmodule
