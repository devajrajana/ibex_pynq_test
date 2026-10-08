## ============================================================
## PYNQ-Z2 constraints for Ibex FPGA test
## ============================================================

## 125 MHz system clock
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports clk]

## ============================================================
## User LEDs
## ============================================================

set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

## ============================================================
## BTN0 - Processor reset
## ============================================================

set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports btn_reset]