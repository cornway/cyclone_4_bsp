
`timescale 1ns/1ns

module top();

logic clk_4M = '0;
logic clk_50M = '0;
logic clk_200M = '0;
logic button_a = '0;

always begin
	clk_200M <= ~clk_200M;
	#5;
end

always begin
	clk_50M <= ~clk_50M;
	#10ns;
end

always begin
	clk_4M <= ~clk_4M;
	#50;
end

initial begin
	#100;
	button_a <= '1;
	#500;
	button_a <= '0;
end

project
	#(
		.simulation(1)
	) dut
	(
		.clk_50MHz(clk_50M),
		.clk_sim_200MHz(clk_200M),
		.clk_sim_4MHz(clk_4M),

		.button_a_i(button_a)

		//output logic buzz_o,
		//output logic led_a_o
	);


endmodule
