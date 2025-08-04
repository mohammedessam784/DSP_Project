`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 31.07.2025 18:06:49
// Design Name: 
// Module Name: DSP
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module DSP
#(parameter
A0REG =0,
A1REG =1, 
B0REG =0, 
B1REG =1,
CREG  =1, 
DREG  =1, 
MREG  =1, 
PREG  =1, 
CARRYINREG  =1, 
CARRYOUTREG =1,  
OPMODEREG   =1,
CARRYINSEL ="OPMODE5",// CARRYIN or OPMODE5
B_INPUT    ="DIRECT",//(attribute = DIRECT) or (attribute = CASCADE). 
RSTTYPE    ="SYNC"// ASYNC or SYNC
)
(
input[17:0] A,
input[17:0] B,
input[47:0] C,
input[17:0] D,
input CLK,
input CARRYIN,
input [7:0]OPMODE,
input[17:0] BCIN,
input RSTA,
input RSTB,
input RSTM,
input RSTP,
input RSTC,
input RSTD,
input RSTCARRYIN,
input RSTOPMODE,
input CEA,
input CEB,
input CEM,
input CEP,
input CEC,
input CED,
input CECARRYIN,
input CEOPMODE,
input[47:0] PCIN,
output [17:0] BCOUT,
output [47:0] PCOUT,
output [35:0] M,
output [47:0] P,
output CARRYOUT,
output CARRYOUTF
    );
    
    
  wire [7:0] OPMODE_reg;
    Reg_Wire_module #(.RW(OPMODEREG), .N(8), .RSTTYPE(RSTTYPE)) OPMODE_REG
      (.clk(CLK), .clk_en(CEOPMODE), .rst(RSTOPMODE),
       .d(OPMODE), .q(OPMODE_reg));
  
    ///////////////////////D
wire [17:0] D_reg;
Reg_Wire_module #(.RW(DREG),.N(18),.RSTTYPE(RSTTYPE)) D_REG 
 (.clk(CLK),.clk_en(CED),.rst(RSTD),.d(D),.q(D_reg)); 
 /////////////////////B
wire [17:0] B0_reg;
generate 
if(B_INPUT=="DIRECT") begin : B_direct
     Reg_Wire_module #(.RW(B0REG),.N(18),.RSTTYPE(RSTTYPE)) B0_REG 
       (.clk(CLK),.clk_en(CEB),.rst(RSTB),.d(B),.q(B0_reg));  
end
else begin : B_from_BCIN
     Reg_Wire_module #(.RW(B0REG),.N(18),.RSTTYPE(RSTTYPE)) B0_REG 
       (.clk(CLK),.clk_en(CEB),.rst(RSTB),.d(BCIN),.q(B0_reg));  
end
endgenerate
 
 /////////////////////A
wire [17:0] A0_reg;
Reg_Wire_module #(.RW(A0REG),.N(18),.RSTTYPE(RSTTYPE)) A0_REG 
  (.clk(CLK),.clk_en(CEA),.rst(RSTA),.d(A),.q(A0_reg));  
////////////////////C  
wire [47:0] C_reg;
  Reg_Wire_module #(.RW(CREG),.N(48),.RSTTYPE(RSTTYPE)) C_REG 
    (.clk(CLK),.clk_en(CEC),.rst(RSTC),.d(C),.q(C_reg));  
 ////////////////////////////////////////////////////////////////////////////// 
wire [17:0] DB_adder;   
assign DB_adder =(~OPMODE_reg[6])?(D_reg+B0_reg):(D_reg-B0_reg);
wire [17:0] MUX1_out; 
assign MUX1_out =(OPMODE_reg[4])?DB_adder:B0_reg;

wire [17:0] B1_reg;
Reg_Wire_module #(.RW(B1REG),.N(18),.RSTTYPE(RSTTYPE)) B1_REG 
      (.clk(CLK),.clk_en(CEB),.rst(RSTB),.d(MUX1_out),.q(B1_reg));
wire [17:0] A1_reg;
Reg_Wire_module #(.RW(A1REG),.N(18),.RSTTYPE(RSTTYPE)) A1_REG 
            (.clk(CLK),.clk_en(CEA),.rst(RSTA),.d(A0_reg),.q(A1_reg)); 
 ////////////////////////////////////////////////////////////////           
wire [35:0] A1_mul_B1 ;                   
assign A1_mul_B1 =A1_reg*B1_reg; 
  wire [35:0] M_reg;        
 Reg_Wire_module #(.RW(MREG),.N(36),.RSTTYPE(RSTTYPE)) M_REG 
            (.clk(CLK),.clk_en(CEM),.rst(RSTM),.d(A1_mul_B1),.q(M_reg)); 
  
  wire  CYI_reg;
           generate   
            if(CARRYINSEL=="OPMODE5") begin : OPMODE5
                 Reg_Wire_module #(.RW(CARRYINREG),.N(1),.RSTTYPE(RSTTYPE)) CYI_REG 
                   (.clk(CLK),.clk_en(CECARRYIN),.rst(RSTCARRYIN ),.d(OPMODE_reg[5]),.q(CYI_reg));  
            end
            else begin : CARRYIN_SEL 
                 Reg_Wire_module #(.RW(CARRYINREG),.N(1),.RSTTYPE(RSTTYPE)) CYI_REG 
                  (.clk(CLK),.clk_en(CECARRYIN),.rst(RSTCARRYIN ),.d(CARRYIN),.q(CYI_reg));  
            end
            endgenerate  
  
//////////////////////////////////////////////////////////
/////mux_x
  wire  [47:0]X_MUX; 
  MUX_4x1 #(.N(48)) X_mux_inst 
    (.in0({48'h0}),.in1({12'h0,M_reg}),.in2(P),.in3({D_reg[11:0],A1_reg[17:0],B1_reg[17:0]}),.sel(OPMODE_reg[1:0]),.out(X_MUX));
    

  /////mux_z
  wire  [47:0]Z_MUX; 
   MUX_4x1 #(.N(48)) Z_mux_inst 
     (.in0({48'h0}),.in1(PCIN),.in2(P),.in3(C_reg),.sel(OPMODE_reg[3:2]),.out(Z_MUX));
     
//assign Z_MUX= OPMODE[2]?(OPMODE[3]?C_reg:PCIN):(OPMODE[3]?P:{48'h0});
 //////////////////////////////////////////
wire  [48:0]XZ_adder;

assign XZ_adder= (~OPMODE_reg[7])?(X_MUX+Z_MUX+CYI_reg):Z_MUX-(X_MUX+CYI_reg);

Reg_Wire_module #(.RW(PREG),.N(48),.RSTTYPE(RSTTYPE)) P_REG 
 (.clk(CLK),.clk_en(CEP),.rst(RSTP),.d(XZ_adder[47:0]),.q(P));
  
 Reg_Wire_module #(.RW(CARRYOUTREG),.N(1),.RSTTYPE(RSTTYPE)) CYO_REG 
  (.clk(CLK),.clk_en(CECARRYIN),.rst(RSTCARRYIN ),.d(XZ_adder[48]),.q(CARRYOUT));  
  
  
 assign PCOUT =P;
 assign CARRYOUTF =CARRYOUT;
 assign BCOUT =B1_reg ;   
 assign M =M_reg;   
 
endmodule




module MUX_4x1 #(
    parameter N = 8  
)(
    input  [N-1:0] in0,
    input  [N-1:0] in1,
    input  [N-1:0] in2,
    input  [N-1:0] in3,
    input  [1:0] sel,
    output reg [N-1:0] out
);

    always @(*) begin
        case (sel)
            2'b00: out = in0;
            2'b01: out = in1;
            2'b10: out = in2;
            2'b11: out = in3;
            default: out = {N{1'b0}};
        endcase
    end

endmodule







module Reg_Wire_module
#(
    parameter RW = 1,                // 1: register, 0: wire
    parameter N = 10,
    parameter RSTTYPE = "SYNC"       // "ASYNC" or "SYNC"
)
(
    input clk,
    input clk_en,
    input rst,
    input [N-1:0] d,
    output reg [N-1:0] q
);

generate
    if (RW == 1) begin : reg_logic
        if (RSTTYPE == "ASYNC") begin : async_rst
            always @(posedge clk or posedge rst) begin
                if (rst)
                    q <= {N{1'b0}};
                else if(clk_en)
                    q <= d;
            end
        end else begin : sync_rst
            always @(posedge clk) begin
                if (rst)
                    q <= {N{1'b0}};
                else if(clk_en)
                    q <= d;
            end
        end
    end else begin : wire_logic
        always @(*) begin
            q = d;
        end
    end
endgenerate

endmodule


