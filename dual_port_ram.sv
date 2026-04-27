
module dual_port_ram #(parameter ADDR_WIDTH=15)(
// Clock
input clk,

// Instruction port (RO)
input [31:2] i_addr,                 //done
output reg [31:0] i_rdata,           //done

// Data port (RW)
input [31:2] d_addr,                 //Just ALU out
output reg [31:0] d_rdata,           //Data Read out from Mem
input d_we,                          //Write enable
input [3:0] d_be,                    //Byte Enable (Which Bytes in Word to Write)
input [31:0] d_wdata                 //Data To Write (Assumed Shifted into Place Already when Passed)
);


//Storing Raw Endian - need to shuffle to get into Little Endian from .txt
reg [31:0] i_rdata_raw;
assign i_rdata = {i_rdata_raw[7:0],i_rdata_raw[15:8],i_rdata_raw[23:16],i_rdata_raw[31:24]};


//Shuffling Endian for Read Data
reg [31:0] d_rdata_raw;
//assign d_rdata = {d_rdata_raw[7:0],d_rdata_raw[15:8],d_rdata_raw[23:16],d_rdata_raw[31:24]};
assign d_rdata = d_rdata_raw;

//Multi-demensional packed array initialized by bit stream from "ram.hex"
//  (* ram_init_file & "ram.hex" *) logic [3:0][7:0] ram[(2**ADDR_WIDTH)-1:0];
reg [31:0] ram [(2**ADDR_WIDTH)-1:0];

initial begin
    $readmemh("text.txt", ram, 0);
end


//Instruction Fetch
always @ (posedge clk) begin
    i_rdata_raw <= ram[i_addr];
end



//Data R/W
always @ (posedge clk) begin
    if(d_we) begin
        if (d_be[0]) ram[d_addr][7:0]   <= d_wdata[7:0];
        if (d_be[1]) ram[d_addr][15:8]  <= d_wdata[15:8];
        if (d_be[2]) ram[d_addr][23:16] <= d_wdata[23:16];
        if (d_be[3]) ram[d_addr][31:24] <= d_wdata[31:24];
    end
    d_rdata_raw <= ram[d_addr];
end


endmodule

