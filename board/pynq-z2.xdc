## ==============================================================================
## Course: CS220 - Introduction to Computer Organization
## Project: 32-Bit MIPS Processor & FPGA Accelerator
## File: pynq-z2.xdc
## Description: Physical constraints file mapping pins for AMD/Xilinx PYNQ-Z2 FPGA.
## ==============================================================================

## Clock Signal (125 MHz)
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

## Asynchronous Active-Low Reset (Using Push Button 0)
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## Slide Switches (switches[0] to switches[3])
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { switches[0] }];
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { switches[1] }];
set_property -dict { PACKAGE_PIN I16   IOSTANDARD LVCMOS33 } [get_ports { switches[2] }];
set_property -dict { PACKAGE_PIN I17   IOSTANDARD LVCMOS33 } [get_ports { switches[3] }];

## Push Buttons (buttons[0] to buttons[3] - Button 0 is shared/used as Reset rst_n)
# set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { buttons[0] }]; # Used as rst_n
set_property -dict { PACKAGE_PIN D20   IOSTANDARD LVCMOS33 } [get_ports { buttons[1] }];
set_property -dict { PACKAGE_PIN L20   IOSTANDARD LVCMOS33 } [get_ports { buttons[2] }];
set_property -dict { PACKAGE_PIN L19   IOSTANDARD LVCMOS33 } [get_ports { buttons[3] }];

## Green LEDs (leds[0] to leds[3])
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { leds[0] }];
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { leds[1] }];
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { leds[2] }];
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { leds[3] }];

## RGB LEDs (rgb_leds[0] to rgb_leds[5])
# RGB LED 4 (rgb_leds[0:2] -> R, G, B)
set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports { rgb_leds[0] }]; # Red
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { rgb_leds[1] }]; # Green
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { rgb_leds[2] }]; # Blue

# RGB LED 5 (rgb_leds[3:5] -> R, G, B)
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { rgb_leds[3] }]; # Red
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { rgb_leds[4] }]; # Green
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { rgb_leds[5] }]; # Blue
