
`timescale 1ns/1ns


module sdram_phy_if (sdram_iface_t phy);

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

sdram_iface_t sdram_if();
sdram_iface_t sdram_dut_if();
sdram_iface_host_t sdram_if_host();

spi_phy_if spi_phy_if_inst();

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
			.sd_dq(sdram_dut_if.Dq),
			.sd_cke(sdram_dut_if.Cke),
			.sd_clk(sdram_dut_if.Clk),
			.sd_cs(sdram_dut_if.Cs_n),
			.sd_ras(sdram_dut_if.Ras_n),
			.sd_cas(sdram_dut_if.Cas_n),
			.sd_we(sdram_dut_if.We_n),
			.sd_ldqm(sdram_dut_if.Dqm[0]),
			.sd_udqm(sdram_dut_if.Dqm[1]),
			.sd_bs0(sdram_dut_if.Ba[0]),
			.sd_bs1(sdram_dut_if.Ba[1]),
			.sd_sa(sdram_dut_if.Addr),

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

	sdram_test sdram_test_inst
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
			.clk(sdram_if_host.clk)
		);

	logic[15:0] spi2_xchg_data;

	task spi2_xchg_u16 (bit[15:0] data);

	begin
		automatic bit[15:0] data_o = '0;
		automatic bit[15:0] data_int = data;

		repeat (2) @(posedge clk_50M);
		spi_phy_if_inst.cs <= '0;
		spi_phy_if_inst.sck <= '0;

		repeat (16) begin
			{spi_phy_if_inst.mosi, data_int[15:1]} = data_int;
			#40;
			spi_phy_if_inst.sck <= '1;
			#40;
			data_o = {data_o[14:0], spi_phy_if_inst.miso};
			spi_phy_if_inst.sck <= '0;
		end
		@(posedge clk_50M);
		spi_phy_if_inst.sck <= '0;
		spi_phy_if_inst.cs <= '1;
		spi2_xchg_data <= data_o;
		#40;
	end
	endtask

	task spi2_read_u16 (bit[7:0] addr);
		spi2_xchg_u16({8'h80, addr});
		spi2_xchg_u16('0);
	endtask

	task spi2_read_mem_u16 (bit[31:0] addr);
		spi2_xchg_u16(16'hC000);
		spi2_xchg_u16(addr[15:0]);
		spi2_xchg_u16(addr[31:16]);
	endtask

	task spi2_write_mem_u16 (bit[31:0] addr, bit[15:0] data);
		spi2_xchg_u16(16'hC100);
		spi2_xchg_u16(addr[15:0]);
		spi2_xchg_u16(addr[31:16]);
		spi2_xchg_u16(data);
	endtask

	initial begin
		spi_phy_if_inst.cs <= '1;
		#100;
		spi2_write_mem_u16('0, 16'h1234);
		spi2_write_mem_u16(10, 16'h7777);
		spi2_read_mem_u16('0);
		spi2_read_mem_u16(10);
	end

endmodule


module sdram_test
	(
		output logic[31:0] wr_addr,
		output logic[15:0] wr_data,
		output logic wr_enable,

		output logic[31:0] rd_addr,
		output logic[15:0] rd_data,
		input logic rd_ready,
		output logic rd_enable,

		input logic busy,
		output logic rst_n,
		input logic clk
	);
	logic[15:0] data;

	initial begin
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
	end
endmodule
