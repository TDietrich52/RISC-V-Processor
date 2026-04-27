module alu_combo_logic(
    // from ID
    input [31:0] iw_in,
    input [31:0] rs1_data_in,
    input [31:0] rs2_data_in,
    input [31:0] pc_in,

    //Selected Result
    output reg [31:0] alu_out_ex
);
    

// ===============  Cutting Up Incoming Signals ===================== //
//    Break iw into: opcode, funct3, funct7, shamt values, ect.       //
// ================================================================== //

wire [6:0] opcode = iw_in[6:0];
wire [2:0] funct3 = iw_in[14:12];
wire [6:0] funct7 = iw_in[31:25];
wire [4:0] shamt = iw_in[24:20];
wire [31:0] i12_signed  = { {20{iw_in[31]}}, iw_in[31:20] };


//Fankenstiend signex[i12] for Store Commands
wire [31:0] s12_signed = {{20{iw_in[31]}}, iw_in[31:25], iw_in[11:7]};
wire [31:0] j_imm = { {12{iw_in[31]}}, iw_in[19:12], iw_in[20], iw_in[30:21]};




// =======================  COMBONATION LOGIC BELOW ================================= //
//       All possilbe operations  done in parrerllel to save computation time         //
// ================================================================================== //

// Register <---> Register Commands (R) 
wire [31:0] add_result = rs1_data_in + rs2_data_in;
wire [31:0] sub_result = rs1_data_in - rs2_data_in;
wire [31:0] sll_result = rs1_data_in << rs2_data_in[4:0];
wire [31:0] slt_result = ($signed(rs1_data_in) < $signed(rs2_data_in)) ? {31'b0, 1'b1} : 32'b0;
wire [31:0] sltu_result = (rs1_data_in < rs2_data_in) ? {31'b0, 1'b1} : 32'b0;
wire [31:0] xor_result = rs1_data_in ^ rs2_data_in;
wire [31:0] srl_result = rs1_data_in >> rs2_data_in[4:0];
wire [31:0] sra_result = $signed(rs1_data_in) >>> rs2_data_in[4:0];
wire [31:0] or_result = rs1_data_in | rs2_data_in;
wire [31:0] and_result = rs1_data_in & rs2_data_in;


//Register <---> Immedient  Commands (I)
wire [31:0] jalr_result = pc_in + 4;
//wire [31:0] jalr_result = rs1_data_in + i12_signed;
//LB, LH, LW, LBU, LH All Connect to  ADDI
wire [31:0] addi_result = rs1_data_in + i12_signed;
wire [31:0] slti_result = ($signed(rs1_data_in) < $signed(i12_signed)) ? {31'b0, 1'b1} : 32'b0;
wire [31:0] sltiu_result = (rs1_data_in < i12_signed) ? {31'b0, 1'b1} : 32'b0;
wire [31:0] xori_result = rs1_data_in ^ i12_signed;
wire [31:0] ori_result = rs1_data_in | i12_signed;
wire [31:0] andi_result = rs1_data_in & i12_signed;
wire [31:0] slli_result = rs1_data_in << shamt;
wire [31:0] srli_result = rs1_data_in >> shamt;
wire [31:0] srai_result = $signed(rs1_data_in) >>> shamt;

//Storage Commands (S)
wire [31:0] sb_result = rs1_data_in + s12_signed;

//Upper Immediant Commands (U)
wire [31:0] lui_result = {iw_in[31:12], 12'b0};
wire [31:0] auipc_result = {iw_in[31:12], 12'b0} + pc_in;

// Jump Commands (J)
//wire [31:0] jal_result = pc_in + 4; 
wire [31:0] jal_result = pc_in + (2 * j_imm);





// =======================  Selecting Desired Result ================================ //
//        Nested case statments to properly select wich wire to put to ALU_out        //
// ================================================================================== //
//Always_comb to select which signal output
always_comb begin
    case (opcode)
    
        // =====================(R) Register Instructions ============================
        7'b0110011: begin
            case (funct3)
                3'b000: alu_out_ex = (funct7[5]) ? sub_result : add_result;
                3'b001: alu_out_ex = sll_result;
                3'b010: alu_out_ex = slt_result;
                3'b011: alu_out_ex = sltu_result;
                3'b100: alu_out_ex = xor_result;
                3'b101: alu_out_ex = (funct7[5]) ? sra_result : srl_result;
                3'b110: alu_out_ex = or_result;
                3'b111: alu_out_ex = and_result;
                default: alu_out_ex = 32'b0;
            endcase
        end
        
        // =================== (I) Immediant Yellow Intructions =====================
        7'b0010011: begin
            case (funct3)
                3'b000: alu_out_ex = addi_result;
                3'b010: alu_out_ex = slti_result;
                3'b011: alu_out_ex = sltiu_result;
                3'b100: alu_out_ex = xori_result;
                3'b110: alu_out_ex = ori_result;
                3'b111: alu_out_ex = andi_result;
                3'b001: alu_out_ex = slli_result;
                3'b101: alu_out_ex = (funct7[5]) ? srai_result : srli_result;
                default: alu_out_ex = 32'b0;
            endcase
        end
                
         // ================== (I) Immediant Purple Insturctions =====================
         //LB, LH, LW, LBU, LHU all utilize ADDI result
         7'b0000011: alu_out_ex = addi_result;
         
         // ================== (S) Storage Instructions ==============================
         // SB, SH, SW all utilize SB's Result
         7'b0100011: alu_out_ex = sb_result;
         
         // ================= ECT Instructions =======================================
        7'b1100111: alu_out_ex = jalr_result;
        7'b1101111: alu_out_ex = jal_result;
        7'b0110111: alu_out_ex = lui_result;
        7'b0010111: alu_out_ex = auipc_result;
        
        

        default: alu_out_ex = 32'b0;
    endcase
end

endmodule
