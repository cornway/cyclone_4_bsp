module mod_por
#(parameter POR_TICKS = 4)
       (
            input logic clk_i,

            output logic rst_o
        );

    logic[15 : 0] por_ticks = '0;

    always_ff @ (posedge clk_i) begin
        if (por_ticks < POR_TICKS) begin
            rst_o <= '1;
            por_ticks <= por_ticks + 1'd1;
        end else begin
            rst_o <= '0;
        end
    end

endmodule

module mod_presc
#(parameter PRESC_MAX = 256)
    (
        input logic clk_i,
        input logic[$clog2(PRESC_MAX) : 0] presc_i,
        input logic rst_i,

        output logic clk_o
    );

    logic[$clog2(PRESC_MAX) : 0] presc = '0;
    logic[$clog2(PRESC_MAX) - 1 : 0] presc_period_n2;

    assign presc_period_n2 = presc_i << 1;

    always_ff @ (posedge clk_i) begin
        if (rst_i) begin
            clk_o <= '0;
        end else if (presc >= presc_period_n2 >> 1) begin
            presc <= '0;
            clk_o <= ~clk_o;
        end else begin
            presc <= presc + 1'b1;
        end
    end

endmodule
