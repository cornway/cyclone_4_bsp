transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -work work ../../ip/pll/pll_bb.v
vlog -work work ../../ip/pll2/pll2_bb.v
vlog -work work ../../ip/sdram/stffrdhrn_sdram.sv

vlog -work work ../../main/main.sv
vlog -work work ../../main/misc.sv
vlog -work work ../../main/button.sv
vlog -work work ../../main/buzzer.sv
vlog -work work ../../common/utils/spi.sv
vlog -work work ../../common/utils/primitives.sv
vlog -work work ../../common/utils/sdram_wish.sv

vlog -work work ../../main/tb.sv
vlog -work work ../../sim/sdram_sim.v

vsim work.top

view objects
view locals

view wave -undock

add wave sdram_dut_if/*
add wave dut/spi2_host_if/*
add wave dut/sdram_wif/*
add wave dut/sdram_wish_if_inst/*
add wave dut/sdram_wish_if_inst/host/*

run 30000ns

