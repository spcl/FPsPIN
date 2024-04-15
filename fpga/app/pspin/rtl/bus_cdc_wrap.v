module bus_cdc_wrap #
(
    parameter WIDTH = 2
) (
    input  wire src_clk,
    input  wire dest_clk,
    input  wire [WIDTH-1:0] src_in,
    output wire [WIDTH-1:0] dest_out
);

`ifdef TARGET_SYNTHESIS
// XXX: array single CDC, should only be used for status signals
xpm_cdc_array_single #(
   .DEST_SYNC_FF(3),   // DECIMAL; range: 2-10
   .INIT_SYNC_FF(0),   // DECIMAL; 0=disable simulation init values, 1=enable simulation init values
   .SIM_ASSERT_CHK(0), // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   .SRC_INPUT_REG(1),  // DECIMAL; 0=do not register input, 1=register input
   .WIDTH(WIDTH)       // DECIMAL; range: 1-1024
) i_cdc (
   .dest_out, // WIDTH-bit output: src_in synchronized to the destination clock domain. This
                        // output is registered.

   .dest_clk, // 1-bit input: Clock signal for the destination clock domain.
   .src_clk,   // 1-bit input: optional; required when SRC_INPUT_REG = 1
   .src_in      // WIDTH-bit input: Input single-bit array to be synchronized to destination clock
                        // domain. It is assumed that each bit of the array is unrelated to the others. This
                        // is reflected in the constraints applied to this macro. To transfer a binary value
                        // losslessly across the two clock domains, use the XPM_CDC_GRAY macro instead.

);
`else
assign dest_out = src_in;
`endif

endmodule