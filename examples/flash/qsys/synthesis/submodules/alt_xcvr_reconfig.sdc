# (C) 2001-2012 Altera Corporation. All rights reserved.
# Your use of Altera Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License Subscription 
# Agreement, Altera MegaCore Function License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


# (C) 2001-2012 Altera Corporation. All rights reserved.
# Your use of Altera Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License Subscription 
# Agreement, Altera MegaCore Function License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


# SDC file for alt_xcvr_reconfig
# You will need to adjust the constraints based on your design
#**************************************************************
# Create Clock
#  -enable and edit these two constraints to fit your design
#**************************************************************
# Note - the source for the mgmt_clk_clk should be set to whatever parent port drives the alt_xcvr_reconfig's mgmt_clk_clk port
#create_clock -period 10ns  -name {mgmt_clk_clk} [get_ports {mgmt_clk_clk}]

# Note that the source clock should be the mgmt_clk_clk, or whichever parent clock is driving it
#create_generated_clock -name sv_reconfig_pma_testbus_clk -source [get_ports {mgmt_clk_clk}] -divide_by 1  [get_registers *sv_xcvr_reconfig_basic:s5|*alt_xcvr_arbiter:pif*|*grant*]


#**************************************************************
# False paths
#**************************************************************
#testbus not an actual clock - set asynchronous to all other clocks
#set_clock_groups -exclusive -group [get_clocks {sv_reconfig_pma_testbus_clk}]

set_false_path -from {*|alt_xcvr_reconfig_basic:basic|sv_xcvr_reconfig_basic:s5|pif_interface_sel}
