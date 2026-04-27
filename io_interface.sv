module io_interface(
    // system clock and reset
    input clk,
    
    // io interface from mem_top
    input  [31:2] addr,
    output reg [31:0] rdata,
    input  we,
    input  [3:0] be,
    input  [31:0] wdata,
    
    //GPIO Connections
    input  pb,
    output reg [7:0] leds
);

reg [31:0] ram [3:0];


//Data R/W
always @ (posedge clk) begin

    ram[1] <= {31'd0, pb};
    
    if(we) begin
        if (be[0]) ram[addr[3:2]][7:0]   <= wdata[7:0];
        if (be[1]) ram[addr[3:2]][15:8]  <= wdata[15:8];
        if (be[2]) ram[addr[3:2]][23:16] <= wdata[23:16];
        if (be[3]) ram[addr[3:2]][31:24] <= wdata[31:24];
    end
    
    rdata <= ram[addr[3:2]];
    leds <= ram[0][7:0];
end

endmodule 