// Generated by DDR High Performance Controller 18.1 [Altera, IP Toolbench 1.3.0 Build 625]
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
// ************************************************************
// Copyright (C) 1991-2019 Altera Corporation
// Any megafunction design, and related net list (encrypted or decrypted),
// support information, device programming or simulation file, and any other
// associated documentation or information provided by Altera or a partner
// under Altera's Megafunction Partnership Program may be used only to
// program PLD devices (but not masked PLD devices) from Altera.  Any other
// use of such megafunction design, net list, support information, device
// programming or simulation file, or any other related documentation or
// information is prohibited for any other purpose, including, but not
// limited to modification, reverse engineering, de-compiling, or use with
// any other silicon devices, unless such use is explicitly licensed under
// a separate agreement with Altera or a megafunction partner.  Title to
// the intellectual property, including patents, copyrights, trademarks,
// trade secrets, or maskworks, embodied in any such megafunction design,
// net list, support information, device programming or simulation file, or
// any other related documentation or information provided by Altera or a
// megafunction partner, remains with Altera, the megafunction partner, or
// their respective licensors.  No other licenses, including any licenses
// needed under any third party's intellectual property, are provided herein.

module sdram (
	local_address,
	local_write_req,
	local_read_req,
	local_burstbegin,
	local_wdata,
	local_be,
	local_size,
	global_reset_n,
	pll_ref_clk,
	soft_reset_n,
	csr_write_req,
	csr_read_req,
	csr_addr,
	csr_be,
	csr_wdata,
	csr_burst_count,
	csr_beginbursttransfer,
	local_ready,
	local_rdata,
	local_rdata_valid,
	local_refresh_ack,
	local_init_done,
	reset_phy_clk_n,
	mem_cs_n,
	mem_cke,
	mem_addr,
	mem_ba,
	mem_ras_n,
	mem_cas_n,
	mem_we_n,
	mem_dm,
	phy_clk,
	aux_full_rate_clk,
	aux_half_rate_clk,
	reset_request_n,
	csr_waitrequest,
	csr_rdata,
	csr_rdata_valid,
	mem_clk,
	mem_clk_n,
	mem_dq,
	mem_dqs);

	input	[20:0]	local_address;
	input		local_write_req;
	input		local_read_req;
	input		local_burstbegin;
	input	[31:0]	local_wdata;
	input	[3:0]	local_be;
	input	[2:0]	local_size;
	input		global_reset_n;
	input		pll_ref_clk;
	input		soft_reset_n;
	input		csr_write_req;
	input		csr_read_req;
	input	[15:0]	csr_addr;
	input	[3:0]	csr_be;
	input	[31:0]	csr_wdata;
	input		csr_burst_count;
	input		csr_beginbursttransfer;
	output		local_ready;
	output	[31:0]	local_rdata;
	output		local_rdata_valid;
	output		local_refresh_ack;
	output		local_init_done;
	output		reset_phy_clk_n;
	output	[0:0]	mem_cs_n;
	output	[0:0]	mem_cke;
	output	[11:0]	mem_addr;
	output	[1:0]	mem_ba;
	output		mem_ras_n;
	output		mem_cas_n;
	output		mem_we_n;
	output	[1:0]	mem_dm;
	output		phy_clk;
	output		aux_full_rate_clk;
	output		aux_half_rate_clk;
	output		reset_request_n;
	output		csr_waitrequest;
	output	[31:0]	csr_rdata;
	output		csr_rdata_valid;
	inout	[2:0]	mem_clk;
	inout	[2:0]	mem_clk_n;
	inout	[15:0]	mem_dq;
	inout	[1:0]	mem_dqs;
endmodule
