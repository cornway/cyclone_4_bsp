transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -work work ../../ip/pll/pll_bb.v
vlog -work work ../../ip/pll2/pll2_bb.v

vlog -work work ../../main/main.sv
vlog -work work ../../main/misc.sv
vlog -work work ../../main/button.sv
vlog -work work ../../main/buzzer.sv
vlog -work work ../../main/tb.sv

vsim work.top

view objects
view locals

view wave -undock

add wave *
add wave dut/*
add wave dut/buzzer/*
add wave dut/mod_button_a/*

run 4000ns

