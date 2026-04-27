
module rv32_wb_top(
// system clock and synchronous reset
input clk,
input reset,

// from mem
input [31:0] pc_in,
input [31:0] iw_in,
input [31:0] alu_in,
input [4:0] wb_reg_in,
input wb_enable_in,
input w_enable_in,      //NEW

// register interface
output regif_wb_enable,
output [4:0] regif_wb_reg,
output [31:0] regif_wb_data,

output df_wb_enable,
output [4:0] df_wb_reg,
output [31:0] df_wb_data,

input [31:0] memif_rdata,
input [31:0] io_rdata,

//Lab 9 Signals
input wb_sel_in
);


 //Data Forward Signals
assign df_wb_enable = wb_enable_in;
assign df_wb_reg = wb_reg_in;
assign df_wb_data = regif_wb_data;

assign regif_wb_reg = wb_reg_in;
assign regif_wb_enable = wb_enable_in;

wire [31:0] raw_read_data;
reg [31:0] shifted_rdata, reg_ready_data;
//logic [31:0] shifted_rdata, reg_ready_data;



//2:1 MUX between rdata from MEM vs IO; (1 = IO | 0 = MEM) 
assign raw_read_data =(alu_in[31])? io_rdata : memif_rdata;

//Convert rdata to a 32-bit reg ready w/ shifting/zero stuffing/sign extension
//Width Key: (0:Byte) (1:HW) (2:Wd)                  
wire [1:0] width = iw_in[13:12];
wire sign_flag = iw_in[14];                              //Sign Flag (0: Signed | 1: Unsigned)

always_comb begin
    shifted_rdata = raw_read_data >> (8 * alu_in[1:0]);
    case(width)
        2'b00: reg_ready_data = (sign_flag) ? {24'b0, shifted_rdata[7:0]} : {{24{shifted_rdata[7]}}, shifted_rdata[7:0]};
        2'b01: reg_ready_data = (sign_flag) ? {16'b0, shifted_rdata[15:0]} : {{16{shifted_rdata[15]}}, shifted_rdata[15:0]};
        2'b10: reg_ready_data = shifted_rdata;
        default: reg_ready_data = 32'd0;
    endcase
end


//Mux for Write Back Value
//2:1 MUX between ALU & Read_Data based on iw sig (Indicating Load)
assign regif_wb_data = (wb_sel_in)? reg_ready_data : alu_in;


endmodule




