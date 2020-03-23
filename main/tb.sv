
`timescale 1ns/1ns

interface spi_phy_sim_if(input clock);
    bit sck;
    bit mosi;
    bit miso;
    bit cs;

    task xchg_u16 (bit[15:0] data, output bit[15:0] data_o);
		automatic bit[15:0] data_int = data;

		repeat (2) @(posedge clock);
		cs = '0;
		sck = '0;

		repeat (16) begin
			{mosi, data_int[15:1]} = data_int;
			#40;
			sck = '1;
			#40;
			data_o = {data_o[14:0], miso};
			sck = '0;
		end
		#40;
		sck = '0;
		cs = '1;
		@(posedge clock);
	endtask
endinterface

interface sdram_iface_sim_host_t;
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

	task test ();
		logic[15:0] data;

		wr_data 	<= '0;
		wr_enable 	<= '0;
		rd_addr 	<= '0;
		rd_enable 	<= '0;
		rst_n 		<= '0;

		#100;
		rst_n <= '1;

		#2000
		wait(!busy); @(posedge clk);

		wr_addr 	<= '0;
		wr_enable 	<= '1;
		wr_data 	<= 16'h5555;

		@(posedge clk);
		wr_enable 	<= '0;

		#2000
		wait(!busy); @(posedge clk);
		rd_addr 	<= '0;
		rd_enable 	<= '1;

		@(posedge clk);
		rd_enable 	<= '0;

		wait(!rd_ready);
	endtask
endinterface


module sdram_phy_if (sdram_phy_if_t phy);

	mt48lc8m16a2 mt48lc8m16a2_if
	(
	.Dq(phy.Dq),
	.Addr(phy.Addr),
	.Ba(phy.Ba),
	.Clk(phy.Clk),
	.Cke(phy.Cke),
	.Cs_n(phy.Cs_n),
	.Ras_n(phy.Ras_n),
	.Cas_n(phy.Cas_n),
	.We_n(phy.We_n),
	.Dqm(phy.Dqm)
	);

endmodule

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

always begin
	sdram_if_host.clk <= ~sdram_if_host.clk;
	#10;
end

initial begin
	sdram_if_host.clk <= '0;
	button_a <= '0;
	#100;
	button_a <= '1;
	#500;
	button_a <= '0;
end

sdram_phy_if_t sdram_if();
sdram_phy_if_t sdram_dut_if();
sdram_iface_sim_host_t sdram_if_host();

spi_phy_sim_if spi_phy_if_inst(clk_50M);

	project
		#(
			.simulation(1)
		) dut
		(
			.clk_50MHz(clk_50M),
			.clk_sim_200MHz(clk_200M),
			.clk_sim_4MHz(clk_4M),

			.button_a_i(button_a),

			//output logic buzz_o,
			//output logic led_a_o

			.sdram_phy(sdram_dut_if),

			.spi2_sck(spi_phy_if_inst.sck),
			.spi2_cs(spi_phy_if_inst.cs),
			.spi2_mosi(spi_phy_if_inst.mosi),
			.spi2_miso(spi_phy_if_inst.miso)
		);

	sdram_phy_if sdram_phy_if_inst
		(
			.phy(sdram_if)
		);

	sdram_phy_if sdram_dut_phy_if_inst
		(
			.phy(sdram_dut_if)
		);

	assign sdram_if.Clk = sdram_if_host.clk;
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
            .addr(sdram_if.Addr),
            .bank_addr(sdram_if.Ba),
            .data(sdram_if.Dq),
            .clock_enable(sdram_if.Cke),
            .cs_n(sdram_if.Cs_n),
            .ras_n(sdram_if.Ras_n),
            .cas_n(sdram_if.Cas_n),
            .we_n(sdram_if.We_n),
            .data_mask_low(sdram_if.Dqm[0]),
            .data_mask_high(sdram_if.Dqm[1])
        );

	logic[15:0] spi2_xchg_data = '0;

	task spi2_read_u16 (bit[7:0] addr);
		spi_phy_if_inst.xchg_u16({8'h80, addr}, spi2_xchg_data);
		spi_phy_if_inst.xchg_u16('0, spi2_xchg_data);
	endtask

	task spi2_read_mem_u16 (bit[31:0] addr);
		spi_phy_if_inst.xchg_u16(16'hC000, spi2_xchg_data);
		spi_phy_if_inst.xchg_u16(addr[15:0], spi2_xchg_data);
		spi_phy_if_inst.xchg_u16(addr[31:16], spi2_xchg_data);
	endtask

	task spi2_write_mem_u16 (bit[31:0] addr, bit[15:0] data);
		spi_phy_if_inst.xchg_u16(16'hC100, spi2_xchg_data);
		spi_phy_if_inst.xchg_u16(addr[15:0], spi2_xchg_data);
		spi_phy_if_inst.xchg_u16(addr[31:16], spi2_xchg_data);
		spi_phy_if_inst.xchg_u16(data, spi2_xchg_data);
	endtask

	initial begin
		sdram_if_host.test();
	end

	initial begin
		spi_phy_if_inst.cs <= '1;
		#100;
		spi2_write_mem_u16('0, 16'h1234);
		spi2_write_mem_u16(10, 16'h7777);
		spi2_read_mem_u16('0);
		spi2_read_mem_u16(10);
	end

endmodule
