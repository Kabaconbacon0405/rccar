## ------------------------------------------------------------------------
## Nexys4 DDR Rev. C Constraint File for Car Node (FR Layout)
## ------------------------------------------------------------------------

## Clock signal (100 MHz)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }]; 
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Switches
# Using Switch 0 for Reset (Active High - Flip DOWN to run the car)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { rst }]; 

## Pmod Header JA (Master Car Connection Hub)
# Top Row
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { ena }];      # L298N ENA (Left Motor Speed)
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { in1 }];      # L298N IN1 (Left Motor Dir)
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { in2 }];      # L298N IN2 (Left Motor Dir)
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { rx_pin }];   # ESP32 TX -> FPGA RX

# Bottom Row
set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { enb }];      # L298N ENB (Right Motor Speed)
set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { in3 }];      # L298N IN3 (Right Motor Dir)
set_property -dict { PACKAGE_PIN F18   IOSTANDARD LVCMOS33 } [get_ports { in4 }];      # L298N IN4 (Right Motor Dir)
# (JA Pin 10 / G18 is now FREE — horn moved to Pmod JC below)

## Pmod Header JB (Telemetry Hub)
# Top Row
set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { tx_pin }];     # FPGA TX -> ESP32 RX
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { sensor_pin }]; # KeyesEye Sensor OUT (internal pull-up for open-collector DO)

## Pmod Header JC (Direct-Drive Speaker — Lab 7 method, no transistor)
set_property -dict { PACKAGE_PIN K1    IOSTANDARD LVCMOS33 } [get_ports { horn_pin }];   # JC Pin 1 -> Speaker (+)

## TEMP DEBUG: onboard LEDs for speed-encoder bring-up
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];     # LD0 = raw sensor level (F16)
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];     # LD1 = heartbeat

## 7-Segment Display — Cathodes seg[6:0] = {CG..CA}
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { seg[0] }];     # CA
set_property -dict { PACKAGE_PIN R10   IOSTANDARD LVCMOS33 } [get_ports { seg[1] }];     # CB
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { seg[2] }];     # CC
set_property -dict { PACKAGE_PIN K13   IOSTANDARD LVCMOS33 } [get_ports { seg[3] }];     # CD
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { seg[4] }];     # CE
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { seg[5] }];     # CF
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { seg[6] }];     # CG

## 7-Segment Display — Anodes an[7:0] (an[0] = rightmost digit)
set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { an[0] }];      # AN0 (ones)
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { an[1] }];      # AN1 (tens)
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { an[2] }];      # AN2 (hundreds)
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { an[3] }];      # AN3 (blank)
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { an[4] }];      # AN4 (blank)
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { an[5] }];      # AN5 (blank)
set_property -dict { PACKAGE_PIN K2    IOSTANDARD LVCMOS33 } [get_ports { an[6] }];      # AN6 (blank)
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { an[7] }];      # AN7 (blank)