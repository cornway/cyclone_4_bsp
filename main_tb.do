transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -work work ../../ip/pll/pll_bb.v
vlog -work work ../../ip/pll2/pll2_bb.v
vlog -work work ../../ip/sdram/stffrdhrn_sdram.sv

vlog -work work -suppress 8885 ../../main/main.sv
vlog -work work -suppress 8885 ../../main/misc.sv
vlog -work work -suppress 8885 ../../main/button.sv
vlog -work work -suppress 8885 ../../main/buzzer.sv
vlog -work work -suppress 8885 ../../common/utils/spi.sv
vlog -work work -suppress 8885 ../../common/utils/primitives.sv
vlog -work work -suppress 8885 ../../common/utils/sdram_wish.sv
vlog -work work -suppress 8885 ../../common/utils/audio_mix.sv
vlog -work work -suppress 8885 ../../common/utils/wishbus.sv
vlog -work work -suppress 8885 ../../common/utils/sfx_cpu.sv
vlog -work work -suppress 8885 ../../common/utils/sfxcpu_reg.sv
vlog -work work -suppress 8885 ../../common/utils/dt_4x8.sv

vlog -work work ../../main/tb.sv
vlog -work work ../../sim/sdram_sim.v

vsim work.top -displaymsgmode both

view objects
view locals

view wave -undock

add wave sdram_dut_if/*
add wave dut/spi2_host_if/*
add wave dut/sdram_wif/*
add wave dut/sdram_wish_if_inst/*
add wave dut/sdram_wish_if_inst/host/*

run 200us

