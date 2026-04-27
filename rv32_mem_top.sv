
module rv32_mem_top(

// system clock and synchronous reset
input clk,
input reset,

// from ex
input [31:0] pc_in,
input [31:0] iw_in,
input [31:0] alu_in,
input [4:0] wb_reg_in,
input wb_enable_in,
input w_enable_in,

// to wb
output reg [31:0] pc_out,
output reg [31:0] iw_out,
output reg [31:0] alu_out,
output reg [4:0] wb_reg_out,
output reg wb_enable_out,
output reg w_enable_out,    

// Data Forward Signals
output df_mem_enable,
output [4:0] df_mem_reg,
output [31:0] df_mem_data,

// memory interface
output [31:2] memif_addr,
input [31:0] memif_rdata,
output memif_we,
output [3:0] memif_be,
output [31:0] memif_wdata,

// io interface
output [31:2] io_addr,
input [31:0] io_rdata,
output io_we,
output [3:0] io_be,
output [31:0] io_wdata,

output [31:0] io_rdata_out,
output [31:0] mem_rdata_out,
input [31:0] rs2_data_in,

input wb_sel_in,
output reg wb_sel_out,
output df_wb_from_mem_mem

);


 //Data Forward Signals
assign df_mem_enable = wb_enable_in;
assign df_mem_reg = wb_reg_in;
assign df_mem_data = alu_in;
assign df_wb_from_mem_mem = wb_sel_in; 


//Forwarding Read Data to WB
assign io_rdata_out = io_rdata;
assign mem_rdata_out = memif_rdata;


/////////////////////////////////////////////////////////////
//                                                         //
//                  Memory Interfaces                      //
//                                                         //
/////////////////////////////////////////////////////////////

// Address Assignment
assign memif_addr = alu_in[31:2];
assign io_addr = alu_in[31:2];
    

//Write Enable Signals for MEM Interfaces
wire leadinga = alu_in[31];
assign memif_we = (!leadinga && w_enable_in)? 1'b1 : 1'b0;
//assign io_we = (memif_we)? 1'b0 : 1'b1;
assign io_we = ( leadinga && w_enable_in) ? 1'b1 : 1'b0;

//Byte Enable Signals - Same for io & ram
//Width Key: (0:Byte) (1:HW) (2:Wd)                     
wire [1:0] width = iw_in[13:12];

//Generate the byte enable(w_be) for the memory based on the addressd & width 
//Getting Correct Shape of Enabled Bytes
reg [3:0] d_be;
wire [3:0] preshift_d_be = (width == 2'b10) ? 4'b1111 :
                           (width == 2'b01) ? 4'b0011 : 4'b0001;


//ALU_out LSB's = n; To Construct Correct Byte Enable Signal
wire [1:0] n = alu_in[1:0];
always_comb begin
    case(n)
        2'b00: d_be = preshift_d_be;
        2'b01: d_be = preshift_d_be << 1;
        2'b10: d_be = preshift_d_be << 2;
        2'b11: d_be = preshift_d_be << 3;
    endcase
end

//Assign BE signals to formatted d_be wire
assign memif_be = d_be;
assign io_be = d_be; 

//Shifting Data to Write - In Case of Store
assign memif_wdata = rs2_data_in << (n * 8);
assign io_wdata = rs2_data_in << (n * 8);




//Latching iw & pc
always_ff @(posedge clk) begin
    if (reset) begin
        pc_out <= 32'b0;
        iw_out <= 32'b0;
        wb_reg_out <= 5'b0;
        wb_enable_out <= 1'b0;
        alu_out <= 32'b0;
        w_enable_out <= 1'b0;
        wb_sel_out <= 1'b0;
    end
    else begin
        pc_out <= pc_in;
        iw_out <= iw_in;
        wb_reg_out <= wb_reg_in;
        wb_enable_out <= wb_enable_in;
        alu_out <= alu_in;
        w_enable_out <= w_enable_in;
        wb_sel_out <= wb_sel_in;
    end
end


endmodule
