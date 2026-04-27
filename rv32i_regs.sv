module rv32i_regs(

// system clock and synchronous reset
input clk,
input reset,
// inputs
input [4:0] rs1_reg,
input [4:0] rs2_reg,
input wb_enable,
input [4:0] wb_reg,
input [31:0] wb_data,
// outputs
output [31:0] rs1_data,
output [31:0] rs2_data);



// Declare the Registers (32 Reg / 32'b Wide)
reg [31:0] registers [31:0];
integer i;


//"32:1 Mux" for both Registers
assign rs1_data = (rs1_reg == 5'd0) ? 32'b0 : registers[rs1_reg];
assign rs2_data = (rs2_reg == 5'd0) ? 32'b0 : registers[rs2_reg];



// Cear All Registers on CLK egde
always_ff @(posedge clk) begin
    if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
    end
    else begin
            if (wb_enable && (wb_reg != 5'd0)) registers[wb_reg] <= wb_data; 
            registers[0] <= 32'b0;
    end
 end
 
 
/*
 ila_0 ila_inst (
    .clk(clk),
    .probe0(reset),
    .probe1(registers[1]),
    .probe2(registers[2]),
    .probe3(registers[3]),
    .probe4(registers[4]),
    .probe5(registers[10])
);
*/


endmodule

