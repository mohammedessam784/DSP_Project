`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for DSP48A1-style “DSP” module
// Exercises reset plus four dynamic OPMODE paths with self-checking.
//===============================================================================
module tb_DSP;

  // Clock & Reset
  reg         CLK;             // 100 MHz clock
  reg         rst;             // global synchronous reset

  // DUT inputs
  reg  [17:0] A, B, D;         // data inputs
  reg  [47:0] C;               // wide C-port input
  reg  [17:0] BCIN;            // cascade B input
  reg  [47:0] PCIN;            // cascade P input
  reg         CARRYIN;         // carry-in bit
  reg  [7:0]  OPMODE;          // dynamic function control

  // DUT outputs
  wire [17:0] BCOUT;           // cascade B output
  wire [35:0] M;               // multiplier output
  wire [47:0] P, PCOUT;        // accumulator outputs
  wire        CARRYOUT;        // adjacent-slice carry
  wire        CARRYOUTF;       // fabric carry

  // All CE & RST signals tied to rst/1 unless overridden
  wire RSTA       = rst,
       RSTB       = rst,
       RSTM       = rst,
       RSTP       = rst,
       RSTC       = rst,
       RSTD       = rst,
       RSTCARRYIN = rst,
       RSTOPMODE  = rst;

  wire CEA        = 1'b1,
       CEB        = 1'b1,
       CEM        = 1'b1,
       CEP        = 1'b1,
       CEC        = 1'b1,
       CED        = 1'b1,
       CECARRYIN  = 1'b1,
       CEOPMODE   = 1'b1;

  // Instantiate the DUT with default parameters
  DSP dut (
    .A           (A),
    .B           (B),
    .C           (C),
    .D           (D),
    .CLK         (CLK),
    .CARRYIN     (CARRYIN),
    .OPMODE      (OPMODE),
    .BCIN        (BCIN),
    .RSTA        (RSTA),
    .RSTB        (RSTB),
    .RSTM        (RSTM),
    .RSTP        (RSTP),
    .RSTC        (RSTC),
    .RSTD        (RSTD),
    .RSTCARRYIN  (RSTCARRYIN),
    .RSTOPMODE   (RSTOPMODE),
    .CEA         (CEA),
    .CEB         (CEB),
    .CEM         (CEM),
    .CEP         (CEP),
    .CEC         (CEC),
    .CED         (CED),
    .CECARRYIN   (CECARRYIN),
    .CEOPMODE    (CEOPMODE),
    .PCIN        (PCIN),
    .BCOUT       (BCOUT),
    .PCOUT       (PCOUT),
    .M           (M),
    .P           (P),
    .CARRYOUT    (CARRYOUT),
    .CARRYOUTF   (CARRYOUTF)
  );

  // Clock generator: toggle every 5 ns ? 100 MHz
  initial begin
    CLK = 0;
    forever #5 CLK = ~CLK;
  end

reg [47:0] prevP; reg prevC;
  // Waveform dump
  initial begin
    $dumpfile("tb_DSP.vcd");
    $dumpvars(0, tb_DSP);
  end
//------------------------------------------------------------------------
    // 2. Stimulus & Self-Checking
    //------------------------------------------------------------------------
    initial begin
      // ------------------------------------------------------------
      // 2.1 Reset verification
      // ------------------------------------------------------------
      rst      = 1;                  // assert reset high
      // drive all inputs to random / nonzero
      A        = 18'h3A5;
      B        = 18'h1C2;
      C        = 48'h1234_5678_ABCD;
      D        = 18'h0F0;
      BCIN     = 18'h055;
      PCIN     = 48'h00FF_FF00;
      CARRYIN  = 1'b1;
      OPMODE   = 8'hFF;
      // wait one falling edge to sample outputs under reset
      @(negedge CLK);
      @(negedge CLK);
      @(negedge CLK);
      @(negedge CLK);
      @(negedge CLK);
      // check that all outputs are zero
      if (BCOUT !== 0 || M !== 0 || P !== 0 || PCOUT !== 0 ||
          CARRYOUT !== 0 || CARRYOUTF !== 0)
        $display("ERROR: Reset failed at time %0t", $time);
      else
        $display("PASS: Reset cleared outputs at time %0t", $time);
  
      rst = 0;                       // deassert reset
      @(posedge CLK);                // align to a clock
      // ------------------------------------------------------------
          // 2.2 DSP Path 1: pre-subtract, multiply, post-add accumulate
          // OPMODE = 8'b1101_1101
          // D-B ? *A ? +C
          // Expected BCOUT=0x0F, M=0x12C, P=PCOUT=0x32, CARRYOUT=0
          // ------------------------------------------------------------
        OPMODE   = 8'b1101_1101;
          A        = 18'd20;
          B        = 18'd10;
          C        = 48'd350;
          D        = 18'd25;
            BCIN     = $random ;
            PCIN     = $random;
            CARRYIN  = $random ;
          repeat (4) @(negedge CLK);     // wait 4 pipeline stages
       
          $display("---- Path 1 Results ----");
          if (BCOUT !== 18'h0F)       $display("FAIL1: BCOUT=%h", BCOUT); else $display("PASS1: BCOUT");
          if (M     !== 36'h12C)       $display("FAIL1: M=%h", M);       else $display("PASS1: M");
          if (P     !== 48'h032)       $display("FAIL1: P=%h", P);       else $display("PASS1: P");
          if (PCOUT !== 48'h032)       $display("FAIL1: PCOUT=%h", PCOUT); else $display("PASS1: PCOUT");
          if ({CARRYOUT,CARRYOUTF} !== 2'b00) $display("FAIL1: CARRY=%b/%b", CARRYOUT, CARRYOUTF);
          else                                $display("PASS1: CARRY");
          
         // ------------------------------------------------------------
              // 2.3 DSP Path 2: pre-add, multiply, no post accumulation
              // OPMODE = 8'b0001_0000
              // D+B ? *A, P=0
              // Expected BCOUT=0x23, M=0x2BC, P/PCOUT=0, CARRY=0
              // ------------------------------------------------------------
              OPMODE   = 8'b0001_0000;
              A        = 18'd20;
              B        = 18'd10;
              C        = 48'd350;
              D        = 18'd25;
                     BCIN     = $random ;
                     PCIN     = $random;
                     CARRYIN  = $random ;
              repeat (3) @(negedge CLK);     // 3-stage longest path
          
              $display("---- Path 2 Results ----");
              if (BCOUT !== 18'h023)       $display("FAIL2: BCOUT=%h", BCOUT); else $display("PASS2: BCOUT");
              if (M     !== 36'h2BC)       $display("FAIL2: M=%h", M);       else $display("PASS2: M");
              if ({P,PCOUT} !== {48'h0,48'h0}) $display("FAIL2: P/PCOUT=%h/%h", P, PCOUT);
              else                            $display("PASS2: P/PCOUT");
              if ({CARRYOUT,CARRYOUTF} !== 2'b00) $display("FAIL2: CARRY=%b/%b", CARRYOUT, CARRYOUTF);
              else                                  $display("PASS2: CARRY");
              
        // ------------------------------------------------------------
                  // 2.4 DSP Path 3: no pre, P-feedback through X & Z
                  // OPMODE = 8'b0000_1010
                  // BCOUT=B, M=A*B, P & CARRY hold previous values
                  // ------------------------------------------------------------
                  // Capture previous P & carry                  
                  prevP    = P; prevC = CARRYOUT;
                  OPMODE   = 8'b0000_1010;
                  A        = 18'd20;
                  B        = 18'd10;
                  C        = 48'd350;
                  D        = 18'd25;
                 BCIN     = $random ;
                  PCIN     = $random;
                CARRYIN  = $random ;
                  repeat (3) @(negedge CLK);
              
                  $display("---- Path 3 Results ----");
                  if (BCOUT !== 18'h00A)       $display("FAIL3: BCOUT=%h", BCOUT); else $display("PASS3: BCOUT");
                  if (M     !== 36'h0C8)       $display("FAIL3: M=%h", M);       else $display("PASS3: M");
                  if ({P,PCOUT} !== {prevP,prevP}) $display("FAIL3: P/PCOUT=%h/%h", P, PCOUT);
                  else                             $display("PASS3: P/PCOUT");
                  if ({CARRYOUT,CARRYOUTF} !== {prevC,prevC}) $display("FAIL3: CARRY=%b/%b", CARRYOUT, CARRYOUTF);
                  else                                         $display("PASS3: CARRY");      
      // ------------------------------------------------------------
                      // 2.5 DSP Path 4: no pre, post-subtract with concat X & PCIN Z
                      // OPMODE = 8'b1010_0111
                      // X = {D[11:0],A,B}; Z=PCIN; P=Z-(X+CIN)
                      // Expected BCOUT=0x6, M=0x1E, P/PCOUT=0xFE6FFFEC0BB1, CARRY=1
                      // ------------------------------------------------------------
                      OPMODE   = 8'b1010_0111;
                      A        = 18'd5;
                      B        = 18'd6;
                      C        = 48'd350;     // unused
                      D        = 18'd25;
                      PCIN     = 48'd3000 ;
                       BCIN     = $random;
                      CARRYIN  = $random ;
                      repeat (3) @(negedge CLK);
                  
                      $display("---- Path 4 Results ----");
                      if (BCOUT !== 18'h006)       $display("FAIL4: BCOUT=%h", BCOUT); else $display("PASS4: BCOUT");
                      if (M     !== 36'h01E)       $display("FAIL4: M=%h", M);       else $display("PASS4: M");
                      if ({P,PCOUT} !== {48'hFE6FFFEC0BB1, 48'hFE6FFFEC0BB1})
                        $display("FAIL4: P/PCOUT=%h/%h", P, PCOUT);
                      else
                        $display("PASS4: P/PCOUT");
                      if ({CARRYOUT,CARRYOUTF} !== 2'b11)
                        $display("FAIL4: CARRY=%b/%b", CARRYOUT, CARRYOUTF);
                      else
                        $display("PASS4: CARRY");
                  
                      $display("All tests completed at time %0t", $time);
                      #20;        
               
          
   $stop;
   end   


endmodule
