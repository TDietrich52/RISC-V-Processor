module rv32_if_top #(parameter PC_RESET=0)(
    // system clock and synchronous reset
    input clk,
    input reset,
  
    // memory interface
    output [31:2] memif_addr,
    input [31:0] memif_data,
    
    // to id
    output reg [31:0] pc_out,
    output [31:0] iw_out,                           // Note: Registered in the Memory already
    // from id
    input jump_enable_in,
    input [31:0] jump_addr_in,

    // lab 9 
    input stall_flag
     );
     
  
  
reg [31:0] pc;                                      //Reg whose output will be the PC.
assign iw_out = memif_data;                         //Pump idata directly out via iw
assign memif_addr = pc[31:2];                       //PC directly drices memif_add

logic halt;


always @(posedge clk) begin
    if (reset) begin
        pc <= PC_RESET;
        pc_out <= PC_RESET;
        halt <= 1'b0;
    end
    else if(stall_flag) begin
        //Stalling - Chage no Regs
        pc   <= pc;
        pc_out <= pc;
    end 
    //If EBRAKE not Reached Yet
    else if (!halt) begin
            //Check if new iw = EBRAKE
            if (iw_out == 32'h00100073) begin
                halt <= 1'b1;
                pc   <= pc;
                pc_out <= pc;
            end
            //Check if Jump Needed
            else if (jump_enable_in) begin
                pc <= jump_addr_in;
                pc_out <= jump_addr_in;
            end
            //Increment like normal
            else begin
                pc <= pc + 4;
                pc_out <= pc;
            end
      end
end



endmodule

