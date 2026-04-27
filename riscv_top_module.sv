
module riscv_top_module(
    input CLK100,           // 100 MHz clock input
    output [9:0] LED,       // RGB1, RGB0, LED 9..0 placed from left to right
    output [2:0] RGB0,      
    output [2:0] RGB1,
    output [3:0] SS_ANODE,   // Anodes 3..0 placed from left to right
    output [7:0] SS_CATHODE, // Bit order: DP, G, F, E, D, C, B, A
    input [11:0] SW,         // SWs 11..0 placed from left to right
    input [3:0] PB,          // PBs 3..0 placed from left to right
    inout [23:0] GPIO,       // PMODA-C 1P, 1N, ... 3P, 3N order
    output [3:0] SERVO,      // Servo outputs
    output PDM_SPEAKER,      // PDM signals for mic and speaker
    input PDM_MIC_DATA,      
    output PDM_MIC_CLK,
    output ESP32_UART1_TXD,  // WiFi/Bluetooth serial interface 1
    input ESP32_UART1_RXD,
    output IMU_SCLK,         // IMU spi clk
    output IMU_SDI,          // IMU spi data input
    input IMU_SDO_AG,        // IMU spi data output (accel/gyro)
    input IMU_SDO_M,         // IMU spi data output (mag)
    output IMU_CS_AG,        // IMU cs (accel/gyro) 
    output IMU_CS_M,         // IMU cs (mag)
    input IMU_DRDY_M,        // IMU data ready (mag)
    input IMU_INT1_AG,       // IMU interrupt (accel/gyro)
    input IMU_INT_M,         // IMU interrupt (mag)
    output IMU_DEN_AG        // IMU data enable (accel/gyro)
    );
     
    // Terminate all of the unused outputs or i/o's
    //assign LED = 10'b0000000000;
    assign RGB0 = 3'b000;
    assign RGB1 = 3'b000;
    assign SS_ANODE = 4'b0000;
    assign SS_CATHODE = 8'b11111111;
    assign GPIO = 24'bzzzzzzzzzzzzzzzzzzzzzzzz;
    assign SERVO = 4'b0000;
    assign PDM_SPEAKER = 1'b0;
    assign PDM_MIC_CLK = 1'b0;
    assign ESP32_UART1_TXD = 1'b0;
    assign IMU_SCLK = 1'b0;
    assign IMU_SDI = 1'b0;
    assign IMU_CS_AG = 1'b1;
    assign IMU_CS_M = 1'b1;
    assign IMU_DEN_AG = 1'b0;
    
    //Wires
    reg pre_reset, reset, pre_push, push;                //Clock 
    wire clk = CLK100;                                   //Simpler clock name
    
    
    
    //Reset Signal
    always_ff @ (posedge(clk))
    begin
        //Reset Metastability 
        pre_reset <= PB[0];
        reset <= pre_reset;
        
        //PB GPIO Metastablitiy
        pre_push <= PB[1];
        push <= pre_push;
     end
         
    
//Initial Wires
wire [4:0] rs1_address_id_to_reg, rs2_address_id_to_reg, wb_reg_wb_to_reg, wb_reg_id_to_exe, wb_reg_exe_to_mem, wb_reg_mem_to_wb;
wire [31:0] rs1_data_reg_to_id, rs2_data_reg_to_id, i_rdata_ram_to_if, wb_data_wb_to_reg, rs1_data_id_to_exe, rs2_data_id_to_exe;
wire [31:0] pc_id_to_exe,iw_id_to_exe, alu_out_exe_to_mem, pc_mem_to_wb,iw_mem_to_wb, pc_exe_to_mem, iw_exe_to_mem, iw_if_to_id, pc_if_to_id, alu_out_mem_to_wb;
wire wb_enable_wb_to_reg, wb_enable_id_to_exe, wb_enable_exe_to_mem, wb_enable_mem_to_wb;

wire [31:2] i_addr_if_to_ram;

//Data Hazard Wires
wire df_wb_en, df_mem_en, df_ex_en;
wire [4:0] df_wb_add, df_mem_add, df_ex_add;
wire [31:0] df_wb_data, df_mem_data, df_ex_data;


//Jumping Logic Wires
wire jump_enable_sig;
wire [31:0] jump_address;

//Lab 8 Added Wires - WB and MEM Interfaces
wire [29:0] mem_ram_addr, mem_io_addr;
wire [31:0] mem_ram_rdata, mem_io_rdata;
wire [3:0] mem_ram_be, mem_io_be;
wire [31:0] mem_ram_wdata, mem_io_wdata;
wire mem_ram_we, mem_io_we, w_enable_id_to_exe, w_enable_exe_to_mem, w_enable_mem_to_wb;
wire [31:0] rs2_data_exe_to_mem, io_rdata_mem_wb, mem_rdata_mem_wb;


//Lab 9 Added Wires - Controlled Dataforwarding & Stall Logic for Load Execution
wire wb_sel_id_exe, wb_sel_exe_mem, wb_sel_mem_wb;  //Is the iw passing a load?
wire exe_iw_load_signal, mem_iw_load_signal;        //Is current iw in this stage a load?
wire [4:0] rs1_addr_id_to_ex, rs2_addr_id_to_ex;    //Address passed to EX to check if data invalid 
wire stall_flag_id_if;

    // =================================================================//
    //                         Instantiations                           //
    // ================================================================ //

   //Instantiate Registers                                                          regs
   rv32i_regs regs_inst(
    .clk                (clk),
    .reset              (reset),
    .rs1_reg            (rs1_address_id_to_reg),
    .rs2_reg            (rs2_address_id_to_reg),
    .wb_enable          (wb_enable_wb_to_reg),
    .wb_reg             (wb_reg_wb_to_reg),
    .wb_data            (wb_data_wb_to_reg),
    .rs1_data           (rs1_data_reg_to_id),
    .rs2_data           (rs2_data_reg_to_id)
    ); 


    //Instantiate Dual Port RAM                                                     RAM
    dual_port_ram ram_inst (
     .clk(clk),   
     .i_addr(i_addr_if_to_ram),
     .i_rdata(i_rdata_ram_to_if),
     .d_addr(mem_ram_addr),
     .d_rdata(mem_ram_rdata), 
     .d_we(mem_ram_we),
     .d_be(mem_ram_be),
     .d_wdata(mem_ram_wdata)
     );



    //Instantiate I/O Interface                                                      I/O
    io_interface io_inst (
     .clk(clk),   
     .addr(mem_io_addr),
     .rdata(mem_io_rdata), 
     .we(mem_io_we),
     .be(mem_io_be),
     .wdata(mem_io_wdata),
     .pb(push),
     .leds(LED[7:0])
     );
 

    // Instruction Fetch Instant.                                                   if
    rv32_if_top intructionFetch(
    .clk(clk),
    .reset(reset),
    .memif_addr(i_addr_if_to_ram),
    .memif_data(i_rdata_ram_to_if),
    .pc_out(pc_if_to_id),
    .iw_out(iw_if_to_id),
    // from id
    .jump_enable_in(jump_enable_sig),      
    .jump_addr_in(jump_address),
    //Lab 9
    .stall_flag(stall_flag_id_if)                
     );
     
     
    //Instruction Decode Instant.                                                   id
     rv32_id_top id_inst (
    .clk(clk),
    .reset(reset),
    // from IF
    .pc_in(pc_if_to_id),
    .iw_in(iw_if_to_id),
    // register interface
    .regif_rs1_reg(rs1_address_id_to_reg),
    .regif_rs2_reg(rs2_address_id_to_reg),
    .regif_rs1_data(rs1_data_reg_to_id),
    .regif_rs2_data(rs2_data_reg_to_id),
    // to EX
    .pc_out(pc_id_to_exe),
    .iw_out(iw_id_to_exe),
    .wb_reg_out(wb_reg_id_to_exe),
    .wb_enable_out(wb_enable_id_to_exe),
    .w_enable_out(w_enable_id_to_exe),
    .rs1_data_out(rs1_data_id_to_exe),       
    .rs2_data_out(rs2_data_id_to_exe),      
    .rs1_addr_out(rs1_addr_id_to_ex),          //ADDED - MAY NOT NEED - Lab 09
    .rs2_addr_out(rs2_addr_id_to_ex),          //ADDED - MAY NOT NEED - Lab 09
     // data hazard: df from ex
    .df_ex_enable(df_ex_en),
    .df_ex_reg(df_ex_add),
    .df_ex_data(df_ex_data),
    // data hazard: df from mem
    .df_mem_enable(df_mem_en),
    .df_mem_reg(df_mem_add),
    .df_mem_data(df_mem_data),
    // data hazard: df from wb
    .df_wb_enable(df_wb_en),
    .df_wb_reg(df_wb_add),
    .df_wb_data(df_wb_data),
    //Jumping Signal Logic
     .jump_enable_out(jump_enable_sig),
     .jump_addr_out(jump_address),
    //Lab 9 Signals
    .wb_sel_out(wb_sel_id_exe),
    .df_wb_from_mem_ex(exe_iw_load_signal),
    .df_wb_from_mem_mem(mem_iw_load_signal),
    .stall_flag(stall_flag_id_if)
    );


    //Execution Top Instant.                                                        exe
    rv32_ex_top ex_inst (
    .clk(clk),
    .reset(reset),
    // from id
    .pc_in(pc_id_to_exe),
    .iw_in(iw_id_to_exe),
    .rs1_data_in(rs1_data_id_to_exe),
    .rs2_data_in(rs2_data_id_to_exe),
    .wb_reg_in(wb_reg_id_to_exe),
    .wb_enable_in(wb_enable_id_to_exe),
    .w_enable_in(w_enable_id_to_exe),
    .rs1_addr_in(rs1_addr_id_to_ex),          //ADDED - MAY NOT NEED - Lab 09
    .rs2_addr_in(rs2_addr_id_to_ex),          //ADDED - MAY NOT NEED - Lab 09
    
    // to mem
    .pc_out(pc_exe_to_mem),
    .iw_out(iw_exe_to_mem),
    .alu_out(alu_out_exe_to_mem),
    .wb_reg_out(wb_reg_exe_to_mem),
    .wb_enable_out(wb_enable_exe_to_mem),
    .w_enable_out(w_enable_exe_to_mem),
    .rs2_data_out(rs2_data_exe_to_mem),
    
    // data hazard: df from ex
    .df_ex_enable(df_ex_en),
    .df_ex_reg(df_ex_add),
    .df_ex_data(df_ex_data),

    // Lab 9 Signals
    .wb_sel_in(wb_sel_id_exe),
    .wb_sel_out(wb_sel_exe_mem),
    .df_wb_from_mem_ex(exe_iw_load_signal),
    //Data Forward from WB
    .df_wb_from_mem_wb(wb_sel_mem_wb),
    .df_wb_reg(df_wb_add),
    .df_wb_data(df_wb_data)
    );


    
    //Memory Top Instant.                                                           mem
    rv32_mem_top mem_stage (
    .clk(clk),
    .reset(reset),
    // from ex
    .pc_in(pc_exe_to_mem),
    .iw_in(iw_exe_to_mem),               //ADDED - MAY NOT NEED
    .alu_in(alu_out_exe_to_mem),         //ADDED - MAY NOT NEED
    .wb_reg_in(wb_reg_exe_to_mem),
    .wb_enable_in(wb_enable_exe_to_mem),
    .w_enable_in(w_enable_exe_to_mem),
    // to wb
    .pc_out(pc_mem_to_wb),
    .iw_out(iw_mem_to_wb),
    .alu_out(alu_out_mem_to_wb),
    .wb_reg_out(wb_reg_mem_to_wb),
    .wb_enable_out(wb_enable_mem_to_wb),
    .w_enable_out(w_enable_mem_to_wb),
    
     // data hazard: df from mem
    .df_mem_enable(df_mem_en),
    .df_mem_reg(df_mem_add),
    .df_mem_data(df_mem_data),
    
    // memory interface
    .memif_addr(mem_ram_addr),  
    .memif_rdata(mem_ram_rdata),
    .memif_we(mem_ram_we),
    .memif_be(mem_ram_be),
    .memif_wdata(mem_ram_wdata),

    // io interface
    .io_addr(mem_io_addr),
    .io_rdata (mem_io_rdata),
    .io_we (mem_io_we),
    .io_be (mem_io_be),
    .io_wdata (mem_io_wdata),

    //Lab 8 Additions
    .io_rdata_out(io_rdata_mem_wb),
    .mem_rdata_out(mem_rdata_mem_wb),
    .rs2_data_in(rs2_data_exe_to_mem),

    //Lab 9 Signals
    .wb_sel_in(wb_sel_exe_mem),
    .wb_sel_out(wb_sel_mem_wb),
    .df_wb_from_mem_mem(mem_iw_load_signal)
    );

     
     //Write Back Instant.                                                          wb
     rv32_wb_top wb_stage (
    .clk(clk),
    .reset(reset),

    // from mem
    .pc_in(pc_mem_to_wb),
    .iw_in(iw_mem_to_wb),
    .alu_in(alu_out_mem_to_wb),
    .wb_reg_in(wb_reg_mem_to_wb),
    .wb_enable_in(wb_enable_mem_to_wb),
    .w_enable_in(w_enable_mem_to_wb),

    // register interface
    .regif_wb_enable(wb_enable_wb_to_reg),
    .regif_wb_reg(wb_reg_wb_to_reg),
    .regif_wb_data(wb_data_wb_to_reg),

    //Data Forward from WB
    .df_wb_enable(df_wb_en),
    .df_wb_reg(df_wb_add),
    .df_wb_data(df_wb_data),

    //Lab 8 Additions
    .memif_rdata(mem_rdata_mem_wb),
    .io_rdata(io_rdata_mem_wb),

    //Lab 9 Signals
    .wb_sel_in(wb_sel_mem_wb)
);




// Logic Analyzer Section

ila_0 ila_inst (
    .clk(clk),
    .probe0(reset),
    .probe1(pc_if_to_id),
    .probe2(iw_if_to_id),
    .probe3(mem_ram_wdata),
    .probe4(w_enable_id_to_exe),
    .probe5(alu_out_exe_to_mem),
    .probe6(pc_exe_to_mem),
    .probe7(rs2_data_exe_to_mem),
    .probe8(mem_ram_addr),
    .probe9(mem_ram_rdata),
    .probe10(mem_ram_we),
    .probe11(mem_ram_be),
    .probe12(wb_enable_wb_to_reg),
    .probe13(wb_reg_wb_to_reg),
    .probe14(wb_data_wb_to_reg),
    .probe15(alu_out_mem_to_wb)
);


endmodule
