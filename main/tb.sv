
`timescale 1ns/1ns

module top();

logic clock = '0;
logic button_a = '0;

always begin
	clock <= ~clock;
	#10;
end

initial begin
	#100;
	button_a <= '1;
	#30;
	button_a <= '0;
end

project
	#(
		.simulation(1)
	) dut
	(
		.clk_50MHz(clock),

		.button_a_i(button_a)

		//output logic buzz_o,
		//output logic led_a_o
	);


endmodule
