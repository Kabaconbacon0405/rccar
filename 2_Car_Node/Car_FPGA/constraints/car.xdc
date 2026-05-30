## ------------------------------------------------------------------------
## Nexys4 DDR Rev. C Constraint File for Car Node (FR Layout)
## ------------------------------------------------------------------------

## Clock signal (100 MHz)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L12P_T1_MRCC_35 Sch=clk100mhz
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## Switches
# Using Switch 0 for Reset (Active High - Flip DOWN to run the car)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { rst }]; #IO_L24N_T3_RS0_15 Sch=sw[0]


## Pmod Header JA (Master Car Connection Hub)
# Top Row
set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { ena }];      #IO_L20N_T3_A19_15 Sch=ja[1] (L298N ENA)
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { in1 }];      #IO_L21N_T3_DQS_A18_15 Sch=ja[2] (L298N IN1)
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { in2 }];      #IO_L21P_T3_DQS_15 Sch=ja[3] (L298N IN2)
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { rx_pin }];   #IO_L18N_T2_A23_15 Sch=ja[4] (ESP32 TX)

# Bottom Row
set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { enb }];      #IO_L16N_T2_A27_15 Sch=ja[7] (L298N ENB)
set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { in3 }];      #IO_L16P_T2_A28_15 Sch=ja[8] (L298N IN3)
set_property -dict { PACKAGE_PIN F18   IOSTANDARD LVCMOS33 } [get_ports { in4 }];      #IO_L22N_T3_A16_15 Sch=ja[9] (L298N IN4)
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { horn_pin }]; #IO_L22P_T3_A17_15 Sch=ja[10] (Active Buzzer)