


module mod_button
#(
    parameter TIMEOUT = 100
)
    (
        input logic clk_i,
        input logic pin_i,

        output logic pin_o
    );

    logic[$clog2(TIMEOUT) : 0] shiftreg;

    assign shiftreg = {shiftreg[$clog2(TIMEOUT) - 1 : 0], pin_i};

    always_comb begin
        if (~shiftreg == '0) begin
            pin_o = '1;
        end else begin
            pin_o = '0;
        end
    end

endmodule
