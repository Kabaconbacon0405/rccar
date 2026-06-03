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
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { horn_pin }]; # Active Buzzer

## Pmod Header JB (Telemetry Hub)
# Top Row
set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { tx_pin }];     # FPGA TX -> ESP32 RX
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { sensor_pin }]; # KeyesEye Sensor OUT