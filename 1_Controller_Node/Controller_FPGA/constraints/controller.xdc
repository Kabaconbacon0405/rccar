## ==============================================================================
## NEXYS 4 / NEXYS A7 CONTROLLER DASHBOARD XDC
## ==============================================================================

## ------------------------------------------------------------------------------
## 1. Clock Signal (100 MHz)
## ------------------------------------------------------------------------------
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## ------------------------------------------------------------------------------
## 2. Onboard Switches
## ------------------------------------------------------------------------------
# SW0: Hardware Reset (rst_btn)
set_property PACKAGE_PIN J15 [get_ports rst_btn]
set_property IOSTANDARD LVCMOS33 [get_ports rst_btn]

# SW1 & SW2: Steering Sensitivity (sw_sens[0] and sw_sens[1])
set_property PACKAGE_PIN L16 [get_ports {sw_sens[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_sens[0]}]
set_property PACKAGE_PIN M13 [get_ports {sw_sens[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_sens[1]}]

# SW3 & SW4: Throttling Profile (sw_throt[0] and sw_throt[1])
set_property PACKAGE_PIN R15 [get_ports {sw_throt[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_throt[0]}]
set_property PACKAGE_PIN R17 [get_ports {sw_throt[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw_throt[1]}]

## ------------------------------------------------------------------------------
## 3. Pmod Header JA (Paddle Shifters / Crash Detectors)
## ------------------------------------------------------------------------------
# JA Pin 1: Right Crash Detector (Upshift)
set_property PACKAGE_PIN C17 [get_ports paddle_up]
set_property IOSTANDARD LVCMOS33 [get_ports paddle_up]

# JA Pin 2: Left Crash Detector (Downshift)
set_property PACKAGE_PIN D18 [get_ports paddle_down]
set_property IOSTANDARD LVCMOS33 [get_ports paddle_down]

## ------------------------------------------------------------------------------
## 4. Pmod Header JB (ESP32 UART Communication)
## ------------------------------------------------------------------------------
# JB Pin 1: RX (Receives Telemetry from ESP32 TX2 / Pin 17)
set_property PACKAGE_PIN D14 [get_ports rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports rx_pin]

# JB Pin 2: TX (Transmits Config Byte to ESP32 RX2 / Pin 16)
set_property PACKAGE_PIN F16 [get_ports tx_out]
set_property IOSTANDARD LVCMOS33 [get_ports tx_out]

## ------------------------------------------------------------------------------
## 5. 7-Segment Display (Cathodes A-G)
## ------------------------------------------------------------------------------
set_property PACKAGE_PIN T10 [get_ports {seg[0]}] ;# CA
set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
set_property PACKAGE_PIN R10 [get_ports {seg[1]}] ;# CB
set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
set_property PACKAGE_PIN K16 [get_ports {seg[2]}] ;# CC
set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
set_property PACKAGE_PIN K13 [get_ports {seg[3]}] ;# CD
set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
set_property PACKAGE_PIN P15 [get_ports {seg[4]}] ;# CE
set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
set_property PACKAGE_PIN T11 [get_ports {seg[5]}] ;# CF
set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
set_property PACKAGE_PIN L18 [get_ports {seg[6]}] ;# CG
set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]

## ------------------------------------------------------------------------------
## 6. 7-Segment Display (Anodes 0-7)
## ------------------------------------------------------------------------------
set_property PACKAGE_PIN J17 [get_ports {an[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
set_property PACKAGE_PIN J18 [get_ports {an[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property PACKAGE_PIN T9  [get_ports {an[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property PACKAGE_PIN J14 [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]
set_property PACKAGE_PIN P14 [get_ports {an[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[4]}]
set_property PACKAGE_PIN T14 [get_ports {an[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[5]}]
set_property PACKAGE_PIN K2  [get_ports {an[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[6]}]
set_property PACKAGE_PIN U13 [get_ports {an[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[7]}]