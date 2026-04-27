// Top rv32_ex_top.sv
module rv32_ex_top(

// system clock and synchronous reset
input clk,
input reset,

// from id
input [31:0] pc_in,
input [31:0] iw_in,
input [31:0] rs1_data_in,
input [31:0] rs2_data_in,
input [4:0] wb_reg_in,
input wb_enable_in,
input w_enable_in,
input [4:0] rs1_addr_in,
input [4:0] rs2_addr_in, 

// to mem
output reg [31:0] pc_out,
output reg [31:0] iw_out,
output reg [31:0] alu_out,
output reg [4:0] wb_reg_out,
output reg wb_enable_out,
output reg w_enable_out,
output reg [31:0] rs2_data_out,

// data hazard: df from ex
output df_ex_enable,
output [4:0] df_ex_reg,
output [31:0] df_ex_data,


// register df from wb (from mem_read)
input wb_sel_in,
output reg wb_sel_out,
output df_wb_from_mem_ex,   //Indicates Curr Instruction is LOAD in EX

//data forward from WB Stage
input df_wb_from_mem_wb,
input [4:0] df_wb_reg,
input [31:0] df_wb_data
);


//Wires
wire [31:0] alu_out_ex;

//Data Forward Signals
assign df_ex_enable = wb_enable_in;
assign df_ex_reg = wb_reg_in;
assign df_ex_data = alu_out_ex;
assign df_wb_from_mem_ex = wb_sel_in;



//Lab 9: Add logic to register rs1_reg and rs2_reg from ID to EX.
//If RAW Data Hazard Exsists- RS1 or RS2's data from ID is outdatted;
//Thus: Need to swap out for WB Stage's Updated Data

wire [31:0] rs1_data_selected = (df_wb_from_mem_wb && 
                              (df_wb_reg == rs1_addr_in) && 
                              (rs1_addr_in != 5'b0)) ? df_wb_data : rs1_data_in;

wire [31:0] rs2_data_selected = (df_wb_from_mem_wb && 
                              (df_wb_reg == rs2_addr_in) && 
                              (rs2_addr_in != 5'b0)) ? df_wb_data : rs2_data_in;







//Combo logic instantiation
alu_combo_logic mainLogic(
        .iw_in          (iw_in),
        .rs1_data_in    (rs1_data_selected),
        .rs2_data_in    (rs2_data_selected),
        .pc_in          (pc_in),
        .alu_out_ex     (alu_out_ex)  
    );



//Latching PassThrough Items
always @(posedge clk) begin
    if (reset) begin
        pc_out <= 32'b0;
        iw_out <= 32'b0;
        wb_reg_out <= 5'b0;
        w_enable_out <= 1'b0;
        wb_enable_out <= 1'b0;
        rs2_data_out <= 32'b0;
        wb_sel_out <= 1'b0;
        alu_out <= 32'b0;

    end
    else begin
        pc_out <= pc_in;
        iw_out <= iw_in;
        wb_reg_out <= wb_reg_in;
        wb_enable_out <= wb_enable_in;
        w_enable_out <= w_enable_in;
        //rs2_data_out <= rs2_data_in;
        rs2_data_out <= rs2_data_selected; 
        wb_sel_out <= wb_sel_in;
        alu_out <= alu_out_ex;
    end
end


endmodule 