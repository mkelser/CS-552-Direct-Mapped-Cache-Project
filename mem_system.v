/* $Author: karu $ */
/* $LastChangedDate: 2009-04-24 09:28:13 -0500 (Fri, 24 Apr 2009) $ */
/* $Rev: 77 $ */

module mem_system(/*AUTOARG*/
   // Outputs
   DataOut, Done, Stall, CacheHit, err,
   // Inputs
   Addr, DataIn, Rd, Wr, createdump, clk, rst
   );
   
   input [15:0] Addr;
   input [15:0] DataIn;
   input        Rd;
   input        Wr;
   input        createdump;
   input        clk;
   input        rst;
   
   output [15:0] DataOut;
   output reg Done;
   output reg Stall;
   output reg CacheHit;
   output err;
   
   reg [15:0] addrCache;
   
   wire [7:0] indexCache;
   
   wire [15:0] addrMemory;
   
   reg [15:0] data_inCache;
   wire [15:0] data_outCache;
   
   wire [15:0] data_inMemory;
   wire [15:0] data_outMemory;
   
   wire [4:0] tag_inCache;
   wire [4:0] tag_outCache;
   
   reg [4:0] tag_inMemory;
   
   reg enableCache;
   
   wire [3:0] busyMemory;
   
   wire [2:0] offsetCache;
   
   reg [2:0] offsetMemory;
   
   wire stallMemory;
   
   wire hitCache;
   
   reg writeCache;
   
   reg wrMemory;
   
   reg rdMemory;
   
   reg compCache;
   
   wire dirtyCache;
   
   wire validCache;
   
   wire errCache;
   wire errMemory;
   
   wire [4:0] currentState;
   reg [4:0] nextState;
   
   localparam
   IDLE = 5'b00000, // 0
   COMP_RD = 5'b00001, // 1
   COMP_WR = 5'b00010, // 2
   WR_BACK0 = 5'b00011, // 3
   WR_BACK1 = 5'b00100, // 4
   WR_BACK2 = 5'b00101, // 5
   WR_BACK3 = 5'b00110, // 6
   MEM_RD0 = 5'b00111, // 7
   HOLD0 = 5'b10001, // 17
   CACHE_WR0 = 5'b01011, // 11
   MEM_RD1 = 5'b01000, // 8
   HOLD1 = 5'b10010, // 18
   CACHE_WR1 = 5'b01100, // 12
   MEM_RD2 = 5'b01001, // 9
   HOLD2 = 5'b10011, // 19
   CACHE_WR2 = 5'b01101, // 13
   MEM_RD3 = 5'b01010, // 10
   HOLD3 = 5'b10100, // 20
   CACHE_WR3 = 5'b01110, // 14 
   FINSH_WR = 5'b01111, // 15
   NON_HIT_DONE = 5'b10000, // 16
   UNKNOWN = 5'b10101, // 21
   DONE = 5'b10110; // 22

   /* data_mem = 1, inst_mem = 0 *
    * needed for cache parameter */
   parameter memtype = 0;
   cache #(0 + memtype) c0(// Outputs
                          .tag_out              (tag_outCache),
                          .data_out             (data_outCache),
                          .hit                  (hitCache),
                          .dirty                (dirtyCache),
                          .valid                (validCache),
                          .err                  (errCache),
                          // Inputs
                          .enable               (enableCache),
                          .clk                  (clk),
                          .rst                  (rst),
                          .createdump           (createdump),
                          .tag_in               (tag_inCache),
                          .index                (indexCache),
                          .offset               (offsetCache),
                          .data_in              (data_inCache),
                          .comp                 (compCache),
                          .write                (writeCache),
                          .valid_in             (1'b1)
                         );

   four_bank_mem mem(// Outputs
                     .data_out          (data_outMemory),
                     .stall             (stallMemory),
                     .busy              (busyMemory),
                     .err               (errMemory),
                     // Inputs
                     .clk               (clk),
                     .rst               (rst),
                     .createdump        (createdump),
                     .addr              (addrMemory),
                     .data_in           (data_inMemory),
                     .wr                (wrMemory),
                     .rd                (rdMemory)
                    );
   
   // flop the current state of the cache controller finite state machine
   dff state [4:0] (.q(currentState), .d(nextState), .clk(clk), .rst(rst));
   
   // assign the data input for four back memory to the data output assigned below
   assign data_inMemory = DataOut;
   
   // decode the tag, index, and offset from cache adrress
   assign tag_inCache = addrCache[15:11];
   assign indexCache = addrCache[10:3];
   assign offsetCache = addrCache[2:0];
   
   always @(*) begin
      Done = 1'b0;
      CacheHit = 1'b0;
      Stall = 1'b1;
      compCache = 1'b0;
      writeCache = 1'b0;
      enableCache = 1'b0;
      addrCache = Addr;
      offsetMemory = 3'b000;
      tag_inMemory = Addr[15:11];
      data_inCache = DataIn;
      wrMemory = 1'b0;
      rdMemory = 1'b0;
      case (currentState)
         COMP_WR : begin
            compCache = 1'b1;
            writeCache = 1'b1;
            enableCache = 1'b1;
            nextState = (validCache & hitCache) ? DONE : 
                        ((~hitCache | ~validCache) & ~dirtyCache) ? MEM_RD0 : 
                        (Wr | dirtyCache) ? WR_BACK0 : 
                        UNKNOWN;
         end       
         COMP_RD : begin
            compCache = 1'b1;
            enableCache = 1'b1;
            nextState = (validCache & hitCache) ? DONE : 
                        ((~validCache| ~hitCache) & ~dirtyCache) ? MEM_RD0 : 
                        dirtyCache ? WR_BACK0 : 
                        UNKNOWN;
         end        
         WR_BACK0 : begin
            enableCache = 1'b1;
            addrCache = {{Addr[15:3]}, 3'b000};
            tag_inMemory = tag_outCache;
            wrMemory = 1'b1;
            nextState = ~stallMemory ? WR_BACK1 : WR_BACK0;
         end      
         WR_BACK1 : begin
            enableCache = 1'b1;
            addrCache = {{Addr[15:3]}, 3'b010};
            offsetMemory = 3'b010;
            tag_inMemory = tag_outCache;
            wrMemory = 1'b1;
            nextState = ~stallMemory ? WR_BACK2 : WR_BACK1;
         end       
         WR_BACK2 : begin
            enableCache = 1'b1;
            addrCache = {{Addr[15:3]}, 3'b100};
            tag_inMemory = tag_outCache;
            offsetMemory = 3'b100;
            wrMemory = 1'b1;
            nextState = ~stallMemory ? WR_BACK3 : WR_BACK2;
         end    
         WR_BACK3 : begin
            enableCache = 1'b1;
            addrCache = {Addr[15:3], 3'b110};
            offsetMemory = 3'b110;
            tag_inMemory = tag_outCache;
            wrMemory = 1'b1;
            nextState = ~stallMemory ? MEM_RD0 : WR_BACK3;
         end  
         MEM_RD0 : begin
            rdMemory = 1'b1;
            nextState = ~stallMemory ? HOLD0 : MEM_RD0;
         end       
         HOLD0 : begin
            rdMemory = 1'b1;
            nextState = CACHE_WR0;
         end
         CACHE_WR0 : begin
            writeCache = 1'b1;
            enableCache = 1'b1;
            addrCache = {{Addr[15:3]}, 3'b000};
            data_inCache = data_outMemory;
            nextState = MEM_RD1;
         end   
         MEM_RD1 : begin
            offsetMemory = 3'b010;
            rdMemory = 1'b1;
            nextState = ~stallMemory ? HOLD1 : MEM_RD1;
         end    
         HOLD1 : begin
            rdMemory = 1'b1;
            nextState = CACHE_WR1;
         end
         CACHE_WR1 : begin
            writeCache = 1'b1;
            enableCache = 1'b1;
            addrCache = {{Addr[15:3]}, 3'b010};
            offsetMemory = 3'b010;
            data_inCache = data_outMemory;
            nextState = MEM_RD2;
         end
         MEM_RD2 : begin
            offsetMemory = 3'b100;
            rdMemory = 1'b1;
            nextState = ~stallMemory ? HOLD2 : MEM_RD2;
         end      
         HOLD2 : begin
            rdMemory = 1'b1;
            nextState = CACHE_WR2;
         end
         CACHE_WR2 : begin
            writeCache = 1'b1;
            enableCache = 1'b1;
            addrCache = {{Addr[15:3]}, {3'b100}};
            offsetMemory = 3'b100;
            data_inCache = data_outMemory;
            nextState = MEM_RD3;
         end 
         MEM_RD3 : begin
            offsetMemory = 3'b110;
            rdMemory = 1'b1;
            nextState = ~stallMemory ? HOLD3 : MEM_RD3;
         end     
         HOLD3 : begin
            rdMemory = 1'b1;
            nextState = CACHE_WR3;
         end                        
         CACHE_WR3 : begin
            writeCache = 1'b1;
            enableCache = 1'b1;
            addrCache = {{Addr[15:3]}, {3'b110}};
            offsetMemory = 3'b110;
            data_inCache = data_outMemory;
            nextState = (Wr & ~Rd) ? FINSH_WR : NON_HIT_DONE;
         end       
         FINSH_WR : begin
            compCache = 1'b1;
            writeCache = 1'b1;
            enableCache = 1'b1;
            nextState = NON_HIT_DONE;
         end      
         NON_HIT_DONE : begin
            Done = 1'b1;
            Stall = 1'b0;
            enableCache = 1'b1;
            nextState = (Wr & ~Rd) ? COMP_WR : 
                        (~Wr & Rd) ? COMP_RD : 
                        IDLE;
         end
         DONE : begin
            Done = 1'b1;
            CacheHit = 1'b1;
            Stall = 1'b0;
            enableCache = 1'b1;
            nextState = (Wr & ~Rd) ? COMP_WR : 
                        (~Wr & Rd) ? COMP_RD :
                        IDLE;
         end
         UNKNOWN : begin
            nextState = (Wr & Rd) ? UNKNOWN : IDLE;
         end
         default : begin
            Stall = 1'b0;
            enableCache = 1'b1;
            nextState = (~Wr & ~Rd) ? IDLE : 
                        (Wr & ~Rd) ? COMP_WR : 
                        (~Wr & Rd) ? COMP_RD : 
                        UNKNOWN;
         end  
      endcase
   end
      
   assign addrMemory = {tag_inMemory, addrCache[10:3], offsetMemory};
   assign DataOut = data_outCache;

   assign err = errCache | errMemory;

endmodule // mem_system

// DUMMY LINE FOR REV CONTROL :9:
