
module rv32_id_top(
    // system clock and synchronous reset
    input clk,
    input reset,
    
    // from if
    input [31:0] pc_in,
    input [31:0] iw_in,
    
    // register interface
    output [4:0] regif_rs1_reg,
    output [4:0] regif_rs2_reg,
    input [31:0] regif_rs1_data,
    input [31:0] regif_rs2_data,
    
    // to ex
    output reg [31:0] pc_out,
    output reg [31:0] iw_out,
    output reg [4:0] wb_reg_out,
    output reg wb_enable_out,
    output reg w_enable_out,
    output reg [31:0] rs1_data_out,
    output reg [31:0] rs2_data_out,
    output reg [4:0] rs1_addr_out,
    output reg [4:0] rs2_addr_out,
    
    // data hazard: df from ex
    input df_ex_enable,
    input [4:0] df_ex_reg,
    input [31:0] df_ex_data,
    
    // data hazard: df from mem
    input df_mem_enable,
    input [4:0] df_mem_reg,
    input [31:0] df_mem_data,
    
    // data hazard: df from wb
    input df_wb_enable,
    input [4:0] df_wb_reg,
    input [31:0] df_wb_data,
    
    //Jump Logic Signal
    output jump_enable_out,
    output [31:0] jump_addr_out,

    //Lab 9 Signals
    output reg wb_sel_out,
    input df_wb_from_mem_ex,        // register df from ex
    input df_wb_from_mem_mem,       // register df from mem
    output stall_flag

);



//Saved Data Handling for Cycle Stalls - LAB 9
reg [31:0] saved_pc, saved_iw;
reg relay_data_flag;                           //"Flag" for when stalled iw/pc needed
wire [31:0] iw_selected;

wire [31:0] active_iw = (relay_data_flag) ? saved_iw : iw_selected;
wire [31:0] active_pc = (relay_data_flag) ? saved_pc : pc_in;


//Registers 
assign regif_rs1_reg = active_iw[19:15];
assign regif_rs2_reg = active_iw[24:20];


//Simple and Nice Data Forwarding :)
//========================================================//
//                  Data Forwarding Block                 //
//========================================================//

// Leading MUX Between Stages WB, MEM, Default
wire [31:0] rs1_data_pre_selected = (df_mem_enable && (df_mem_reg == regif_rs1_reg)) ? df_mem_data :
                                    (df_wb_enable &&  (df_wb_reg == regif_rs1_reg)) ? df_wb_data : 
                                    regif_rs1_data;                         

wire [31:0] rs2_data_pre_selected = (df_mem_enable &&(df_mem_reg == regif_rs2_reg)) ? df_mem_data :
                                    (df_wb_enable  && (df_wb_reg == regif_rs2_reg)) ? df_wb_data : 
                                    regif_rs2_data;  


//Check if ALU df Mux combo good?
wire [31:0] rs1_selected = (df_ex_enable && (df_ex_reg == regif_rs1_reg)) ? df_ex_data : rs1_data_pre_selected;
wire [31:0] rs2_selected = (df_ex_enable && (df_ex_reg == regif_rs2_reg)) ? df_ex_data : rs2_data_pre_selected;

//========================================================//
//                  Jump Logic Blocks                     //
//========================================================//

//NOP Stalling Logic to lag pipeline
reg use_nop_sig;
assign iw_selected = (use_nop_sig)? 32'h00000013 : iw_in;  //MUX'ed iw selection (based on previous iw)

//Jump Logic Signals
wire [6:0] iw_opcode = active_iw[6:0];
wire [2:0] iw_funct3 = active_iw[14:12];

//===================== Mux Selecting if Conditional Jump Valid to be Enabled ========================
//if iw_opcode = 0x67 || 0x6F -> Jump Address
//if iw_opcode = 0x63 -> Check Condition 
wire is_branch = (iw_opcode == 7'h63);
wire is_jal    = (iw_opcode == 7'h6F);
wire is_jalr   = (iw_opcode == 7'h67);


//TEST: Does optimizing wires improve time or just adding extra logic gate!!!!!!!!!!!!!!!!!!!!!!!!11
wire eq   = (rs1_selected == rs2_selected);
wire slt  = ($signed(rs1_selected) < $signed(rs2_selected));
wire sltu = (rs1_selected < rs2_selected);


wire branch_valid_check =
    (iw_funct3 == 3'b000) ?  eq   :             // BEQ
    (iw_funct3 == 3'b001) ? ~eq   :             // BNE
    (iw_funct3 == 3'b100) ?  slt  :             // BLT
    (iw_funct3 == 3'b101) ? ~slt  :             // BGE
    (iw_funct3 == 3'b110) ?  sltu :             // BLTU
    (iw_funct3 == 3'b111) ? ~sltu :   1'b0;     // BGEU
    
assign jump_enable_out = is_jal || is_jalr || (is_branch && branch_valid_check);


//=====================Calculating Possible Jump Address ==================================
//1.) Branching ADD's
wire [31:0] branching_addr;
//wire [31:0] branch_imm = {{19{iw_in[31]}}, iw_in[31], iw_in[7], iw_in[30:25], iw_in[11:8], 1'b0};
wire [31:0] branch_imm = {{19{active_iw[31]}}, active_iw[31], active_iw[7], active_iw[30:25], active_iw[11:8], 1'b0};
assign branching_addr = active_pc + branch_imm;
//2.) JAL ADD's
wire [31:0] jal_addr;
wire [31:0] jal_imm = {{11{active_iw[31]}}, active_iw[31], active_iw[19:12], active_iw[20], active_iw[30:21], 1'b0};
assign jal_addr = active_pc + jal_imm;
//3.) JALR
wire [31:0] jalr_addr;
wire [31:0] jalr_imm = {{20{active_iw[31]}}, active_iw[31:20]};
assign jalr_addr = rs1_selected + jalr_imm;

//Selecting the Best Jump Address
//Default Value is JALR to save logic level time- assuming jump won't be enabled if it's not a jump anyways
assign jump_addr_out =
    (iw_opcode == 7'h63)? branching_addr:
    (iw_opcode == 7'h6F)? jal_addr: jalr_addr;








//Evil and Bad Data Forwarding :(
//==================================================================//
//             Loading DATA Hazard Logic Blocks                     //
//==================================================================//
//Goal: Remove NOPs after Loads. Stall one cycle & then data forward to EX. 
//ID will pass bad infomation in data, but this will be MUXed out in EX stage.
//Standard Data Forwarding won't work w/ LOAD because ALU is outputting Address
//When what is needed is a result fetched from memory in the MEM Stage

//ID current iw a branch or JALR? Logic Needs to be Controlled in ID -> For Step 7
wire id_needs_jump_data = is_branch || is_jalr;

//Step 6
//EX Has a LOAD iw that will change the value of one of ID's currently needed registers
//Meaning we will need the register data before MEM access is typically possible -> STALL NEEDED
//If EX's current iw is LOAD &  (EX's rd == rs1 or rs2) -> Raise Stall Flag
wire stall_datahazard_via_ex_iw;
assign stall_datahazard_via_ex_iw = (df_wb_from_mem_ex && 
        ((df_ex_reg == regif_rs1_reg) || (df_ex_reg == regif_rs2_reg)))? 1'b1: 1'b0;

//Step 7
// MEM has a LOAD and if ID is Branching with Logic needed in the LOAD
// May need to stall some cycles to allow for the ID to make right jump in pc
wire stall_load_in_mem_for_control;
assign stall_load_in_mem_for_control = df_wb_from_mem_mem && id_needs_jump_data &&
        ((df_mem_reg == regif_rs1_reg) || (df_mem_reg == regif_rs2_reg))? 1'b1: 1'b0;
//  (Load in MEM currently) && (ID is Branching rn) && (Rs1/2 Needed is in MEM Stage LOADing) 


//Final Stall Flag
assign stall_flag = stall_datahazard_via_ex_iw || stall_load_in_mem_for_control;




//Checking if OpCode = Writing to Register Command 
wire [4:0] rd = active_iw[11:7];    //Checking Funct. 7 for NOP
wire wb_sig =
    ((active_iw[6:0] == 7'b0110011) ||   // R-type
     (active_iw[6:0] == 7'b0010011) ||   // I-type ALU
     (active_iw[6:0] == 7'b0000011) ||   // loads
     (active_iw[6:0] == 7'b0110111) ||   // LUI
     (active_iw[6:0] == 7'b0010111) || // AUIPC
     (active_iw[6:0] == 7'b1101111) ||   // JAL
     (active_iw[6:0] == 7'b1100111)) &&   // JALR
     (rd != 5'd0);
     

//Checking if OpCode = Store Commands
wire w_sig = (active_iw[6:0] == 7'b0100011)? 1 : 0;

//Adding "Is Load?" Signal to Register across entire pipeline
wire wb_sel = (active_iw[6:0] == 7'b0000011) ? 1'b1 : 1'b0;


//Latching Parishable Goods
always @(posedge clk) begin
    if (reset) begin
        pc_out <= 32'b0;
        iw_out <= 32'b0;
        wb_enable_out <= 1'b0;
        wb_reg_out <= 5'b0;
        w_enable_out <=1'b0;
        use_nop_sig <= 1'b0;
        wb_sel_out <= 1'b0;
        rs1_data_out <= 0;
        rs2_data_out <= 0;
        rs1_addr_out <= 5'b0;
        rs2_addr_out <= 5'b0;
        relay_data_flag <= 1'b0;
    end
      

    //Stalled Cycle 
    else if(stall_flag) begin
        //Assuming a Stall Cycle Condition has been met- PASS NOP to EX, 
        //Save the Important Values and Set RELAY_DATA flag for next Cycle

        //Assure no currently saved iw/pc exsist (Do not overwrite data!)
        if (!relay_data_flag) begin  
            saved_pc <= pc_in;
            saved_iw <= iw_in;
        end

        //Flag Data To Be Relayed
        relay_data_flag <= 1'b1;

        // Passing NOP Data to Stall
        iw_out <= 32'h00000013;
        wb_enable_out <= 1'b0;
        w_enable_out <= 1'b0;
        wb_reg_out <= 5'b0;
        wb_sel_out <= 1'b0;
        rs1_data_out <= 32'b0;
        rs2_data_out <= 32'b0;
        rs1_addr_out <= 5'b0;
        rs2_addr_out <= 5'b0;
        end
    
    else
    //No Stalling Nonsense
    begin
        pc_out <= active_pc;
        iw_out <= active_iw;
        wb_enable_out <= wb_sig;     
        w_enable_out <= w_sig;
        wb_reg_out <= active_iw[11:7];
        use_nop_sig <= jump_enable_out;
        wb_sel_out <= wb_sel;     
        rs1_data_out <= rs1_selected;
        rs2_data_out <= rs2_selected;
        relay_data_flag <= 1'b0; 
        rs1_addr_out <= active_iw[19:15];
        rs2_addr_out <= active_iw[24:20];
    end
end


endmodule



