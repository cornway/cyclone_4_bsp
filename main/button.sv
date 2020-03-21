


module mod_button
    (
        input logic clk_i,
        input logic pin_i,

        output logic pin_o,
        output logic evt_o
    );

    logic[3:0] shiftreg = '0;
    logic pin_int = '0, pin_int_prev = '0;

    assign pin_o = pin_int ^ pin_int_prev;
    assign evt_o = pin_int && !pin_int_prev;

    always_ff @(posedge clk_i) begin
        shiftreg = {shiftreg[2 : 0], pin_i};
        pin_int_prev <= pin_int;
    end

    always_comb begin
        if (shiftreg == '1) begin
            pin_int = '1;
        end else begin
            pin_int = '0;
        end
    end

endmodule
