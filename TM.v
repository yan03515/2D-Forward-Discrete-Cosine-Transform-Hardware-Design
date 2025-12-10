`timescale 1 ns / 10 ps

module TM;

parameter 	IN_WORD_SIZE = 8;
parameter 	OUT_WORD_SIZE = 18;
parameter 	DATA_COUNT = 256*256/8;
parameter   latency =24;


reg 							clk, rst_n;
wire	[IN_WORD_SIZE-1:0] 		x0, x1, x2, x3, x4, x5, x6, x7;
wire 	[OUT_WORD_SIZE-1:0] 	z0, z1, z2, z3, z4, z5, z6, z7;
wire							capture;
reg     [IN_WORD_SIZE*8-1:0]  	in_mem    [0:DATA_COUNT-1];
reg     [20:0]              	addr_count, cmp, err_cnt;
reg		mem_flag;
reg		[IN_WORD_SIZE*8-1:0]  x;
	
//===========================================//

initial
	begin
		//$fsdbDumpfile("dct.fsdb");
		//$fsdbDumpvars;
	end
	
initial begin
    $readmemh("./lena.txt", in_mem);    
end	

always @(posedge clk) begin
    if(~rst_n)
        addr_count <= 0;
    else
    if(mem_flag)
        addr_count <= addr_count + 1;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        x <= 0;    
    else
        x <= #1 in_mem[addr_count];
end



//---- gatesim -----//
initial
        $sdf_annotate("../dct.sdf", U_DCT);	

//-------------------//

DCT		U_DCT(
					.clk	(clk), 
					.rst_n	(rst_n),
					.x0		(x0),
					.x1		(x1),
					.x2		(x2),
					.x3		(x3),
					.x4		(x4),
					.x5		(x5),
					.x6		(x6),
					.x7		(x7),
					.z0		(z0),
					.z1		(z1),
					.z2		(z2),
					.z3		(z3),
					.z4		(z4),
					.z5		(z5),
					.z6		(z6),
					.z7		(z7),
					.ready	(capture)
				);



//*********************************
// 		control signal
//*********************************
assign x7 = {1'b0,x[IN_WORD_SIZE-1:0]};
assign x6 = {1'b0,x[IN_WORD_SIZE*2-1:IN_WORD_SIZE]};
assign x5 = {1'b0,x[IN_WORD_SIZE*3-1:IN_WORD_SIZE*2]};
assign x4 = {1'b0,x[IN_WORD_SIZE*4-1:IN_WORD_SIZE*3]};
assign x3 = {1'b0,x[IN_WORD_SIZE*5-1:IN_WORD_SIZE*4]};
assign x2 = {1'b0,x[IN_WORD_SIZE*6-1:IN_WORD_SIZE*5]};
assign x1 = {1'b0,x[IN_WORD_SIZE*7-1:IN_WORD_SIZE*6]};
assign x0 = {1'b0,x[IN_WORD_SIZE*8-1:IN_WORD_SIZE*7]};


// gen clock signal
parameter   t   = 10;
parameter   th  = t*0.5;

always #th clk = ~clk;


initial begin
    clk = 1;
    rst_n = 1;
    mem_flag = 0;
    #th rst_n = 0;
    #(t*2)      rst_n = 1;
    #(t*10)     mem_flag = 1;
    #(t*DATA_COUNT) mem_flag = 0;
    #(t*latency)
    #t      $finish;
end

integer	ff;

initial  begin
    ff = $fopen("dct_out.txt");
end 
always @(posedge clk) begin
    if(capture) begin
		$fdisplay(ff,"%H%H%H%H%H%H%H%H", z0,z1,z2,z3,z4,z5,z6,z7);        
    end
end


endmodule       
