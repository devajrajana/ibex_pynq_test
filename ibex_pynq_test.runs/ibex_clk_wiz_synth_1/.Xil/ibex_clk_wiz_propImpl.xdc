set_property SRC_FILE_INFO {cfile:c:/Users/devaj/Desktop/ibex_pynq_test/ibex_pynq_test.gen/sources_1/ip/ibex_clk_wiz/ibex_clk_wiz.xdc rfile:../../../ibex_pynq_test.gen/sources_1/ip/ibex_clk_wiz/ibex_clk_wiz.xdc id:1 order:EARLY scoped_inst:inst} [current_design]
current_instance inst
set_property src_info {type:SCOPED_XDC file:1 line:54 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in1]] 0.080
