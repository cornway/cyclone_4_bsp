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

vlog -work work ../../main/tb.sv
vlog -work work ../../sim/sdram_sim.v

vsim work.top

view objects
view locals

view wave -undock

add wave *
add wave sdram_if_host/*
add wave sdram_uc/*
add wave sdram_if/*

run 20000ns

