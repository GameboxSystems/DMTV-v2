`default_nettype none //disable implicit definitions by Verilog


module top(
	 clk,
	 vsync,
	 hsync,
	 r,
	 g,
	 b,
	 idata,
	 ihsync,
	 ivsync,
	 iclk,
	 btnA,
	 btnB,
	 btnStart,
	 btnSelect,
	 btnUp,
	 btnDown,
	 btnLeft,
	 btnRight,
	 nes_clock,
	 nes_latch,
	 nes_data);
	
	input clk;
	output vsync;
	output hsync;
	output [4:0] r;
	output [5:0] g;
	output [4:0] b;

	input[1:0] idata;
	input ihsync;
	input ivsync;
	input iclk;

	output 	reg				btnA;
	output 	reg				btnB;
	output	reg				btnStart;
	output 	reg				btnSelect;
	output 					btnUp;
	output 					btnDown;
	output					btnLeft;
	output					btnRight;

	output 					nes_clock;
	output 					nes_latch;
	input					nes_data;

	nes_controller nes_controller_inst(
	.clk(clk),
	.data_out(data_out),
	.nes_clock(nes_clock),
	.nes_latch(nes_latch),
	.nes_data(nes_data)
	);

	wire [7:0] 				data_out;
	wire [1:0] 				idata_i;
	wire 					iclk_i;
	wire 					ivsync_i;
	wire 					ihsync_i;

	assign 					btnA = 		((~data_out[0]) == 1'b1) ? 1'b0 : 1'b1;
	assign 					btnB = 		((~data_out[1]) == 1'b1) ? 1'b0 : 1'b1;
	assign 					btnStart = 	((~data_out[3]) == 1'b1) ? 1'b0 : 1'b1;
	assign 					btnSelect = ((~data_out[2]) == 1'b1) ? 1'b0 : 1'b1;
	assign 					btnUp = 	((~data_out[4]) == 1'b1) ? 1'b0 : 1'b1;
	assign 					btnDown = 	((~data_out[5]) == 1'b1) ? 1'b0 : 1'b1;
	assign 					btnLeft = 	((~data_out[6]) == 1'b1) ? 1'b0 : 1'b1;
	assign 					btnRight = 	((~data_out[7]) == 1'b1) ? 1'b0 : 1'b1;

	//bit 3 = select, bit 2 = start, bit 1 = B, bit 0 = A
	wire[3:0]  				nes_set;

	localparam 				pal_cnt_max = 13;
	integer  				pal_cnt 	= 1;
	reg  		   		    sl_mod 		= 0;
	reg    			   		sl_mode 	= 0;
	assign 					nes_set[0] = data_out[0]; 
	assign 					nes_set[1] = data_out[1]; 
	assign 					nes_set[2] = data_out[3]; 
	assign 					nes_set[3] = data_out[2]; 

	// VGA output variables
	
	// params for 640x576 following 800x600 timings @ 40 MHz
	localparam h_vis = 640; // visible area horizontal pixels
	localparam h_fp = 120; // horizontal front porch pixels
	localparam h_sync = 128; // horizontal sync active pixels
	localparam h_bp = 168; // horizontal back porch pixels

	localparam v_vis = 576; // visible area vertical pixels
	localparam v_fp = 13; // vertical front porch pixels
	localparam v_sync = 4; // vertical sync active pixels
	localparam v_bp = 35; // vertical back porch pixels


	// VGA output after next pixel
	
	reg      [4:0]           vga_r_r;  //VGA colour registers 
	reg      [5:0]           vga_g_r;
	reg      [4:0]           vga_b_r;
	//reg                 vga_hs_r; //H-SYNC register
	//reg                 vga_vs_r; //V-SYNC register

	assign  r       = vga_r_r; //assign the output signals for VGA to the VGA registers
	assign  g       = vga_g_r;
	assign  b       = vga_b_r;
	//assign  vga_hs      = vga_hs_r;
	//assign  vga_vs      = vga_vs_r;

	// horiz. counter
	reg[10:0] hcounter_next2;
	// vert. counter
	reg[9:0] vcounter_next2;
	// output pixel address computed from hcounter and vcounter
	wire[14:0] opixel_next2;
	// output pixel visiblity
	wire visible_next2;
	// horiz. sync signal
	wire hsync_next2;
	// vert. sync signal
	wire vsync_next2;
	

	// VGA output for next pixel

	// output pixel data
	reg[1:0] data_next1;
	// output pixel visiblity
	reg visible_next1;
	// horiz. sync signal
	reg hsync_next1;
	// vert. sync signal
	reg vsync_next1;
	

	// VGA output for right now
	
	// output pixel data
	reg[1:0] data_now;
	// output pixel visiblity
	reg visible_now;
	// horiz. sync signal
	reg hsync_now;
	// vert. sync signal
	reg vsync_now;
	
	// how many VGA frames (vsync) without GB data to blank display
	localparam framesmissing_to_blank = 2;

	// flag to blank screen due to GB data missing
	reg blank;

	// how many VGA frames have been output without GB input
	reg[1:0] framesmissing;

	// GB data decoding variables

	// memory for filtered edge detection
	reg iclk_state; // current internal input clock signal state
	reg iclk_prev1; // input clock signal 1 master clock cycle ago
	reg iclk_prev2; // input clock signal 2 master clock cycles ago
	reg iclk_prev3; // input clock signal 3 master clock cycles ago
	// iclk_state is changed, when current iclk and prev1-3 all agree.
	
	reg ivsync_state; // current internal input vsync signal state
	reg ivsync_prev1; // input vsync signal 1 master clock cycle ago
	reg ivsync_prev2; // input vsync signal 2 master clock cycles ago
	reg ivsync_prev3; // input vsync signal 3 master clock cycles ago
	// ivsync_state is changed, when current ivsync and prev1-3 all agree
	
	reg ihsync_state; // current internal input hsync signal state
	reg ihsync_prev1; // input hsync signal 1 master clock cycle ago
	reg ihsync_prev2; // input hsync signal 2 master clock cycles ago
	reg ihsync_prev3; // input hsync signal 3 master clock cycles ago
	reg ihsync_prev4; // input hsync signal 4 master clock cycles ago
	reg ihsync_prev5; // input hsync signal 5 master clock cycles ago

	// ihsync_state is changed, when current ihsync and prev1-3 all agree

	reg nes_set_clr = 0;
	reg[3:0] nes_clr_prev1;
	reg[3:0] nes_clr_prev2;
	reg[3:0] nes_clr_prev3;

	reg nes_set_sl = 0;
	reg[3:0] nes_sl_prev1;
	reg[3:0] nes_sl_prev2;
	reg[3:0] nes_sl_prev3;	
	
	// memory for synchronizing data to a moment before edge detect
	reg[1:0] idata_prev1; // input data 1 master clock cycle ago
	reg[1:0] idata_prev2; // input data 2 master clock cycles ago
	reg[1:0] idata_prev3; // input data 3 master clock cycles ago
	reg[1:0] idata_prev4; // input data 4 master clock cycles ago
	reg[1:0] idata_prev5; // input data 5 master clock cycles ago
	// when the ihsync state goes from high to low,
	// the input data is sampled from 5 master clock cycles in the past
	// this is because there is a very short period of time between
	// hsync negative edge and the setup of new data on the data lines
	
	// pixel counter for the next pixel in line to be decoded
	reg[14:0] ipixel;
	
	// when pixel data is to be written to memory
	// these variables contain the address and value for duration of the write cycle
	reg[14:0] ipixel_latched;
	reg[1:0] idata_latched;
	reg iwrite_latched;
	

	// reg for RGB output; [15:11] = red, [10:5] = green, [4:0] = blue
	wire[15:0] color;

	//Dual port ram inference
	reg [1:0] 	mem [(1<<15)-1:0];


	always @(posedge clk) begin
		// VGA signal generation

		data_next1 <= mem[opixel_next2];

		if(iwrite_latched) begin
			mem[ipixel_latched] <=idata_latched;
		end
		
		if(hcounter_next2 < h_vis + h_fp + h_sync + h_bp - 1) begin
			// the increment doesn't overflow horizontal pixel count
			
			hcounter_next2 <= hcounter_next2+1'd1; // increment the horizontal pixel position
		end else begin
			// the increment would overflow pixel count
			hcounter_next2 <= 0; // reset horizontal pixel position
			
			if(vcounter_next2 < v_vis + v_fp + v_sync + v_bp - 1) begin
				// the increment doesn't overflow vertical pixel count

				vcounter_next2 <= vcounter_next2+1'd1; // increment the vertical pixel position
			end else begin
				// the increment would overflow pixel count
				vcounter_next2 <= 0; // reset vertical pixel position

				// there have been framesmissing_to_blank frames without GB data
				// and blank has not been set
				if(blank == 0 && framesmissing >= framesmissing_to_blank) begin
					blank <= 1;
				end

				framesmissing <= framesmissing + 2'd1;
			end
		end

		// shift data marked for 2 clock cycles in the future
		// to one clock cycle in the future
		visible_next1 <= visible_next2;
		vsync_next1 <= vsync_next2;
		hsync_next1 <= hsync_next2;
		
		// shift data marked for 1 clock cycle in the future
		// to right now
		data_now <= data_next1;
		visible_now <= visible_next1;
		vsync_now <= vsync_next1;
		hsync_now <= hsync_next1;



		// GB input decoder

		// reset write latch
		// that is, by default we don't want to continue writing
		iwrite_latched <= 0;


		// input clock filtering and handling

		// if clock has been high for a while, change the clock state high
		if(iclk_prev3 && iclk_prev2 && iclk_prev1 && iclk && !iclk_state) begin
			iclk_state <= 1;
		end

		// if the clock has been low for a while, change the clock state low
		if(!iclk_prev3 && !iclk_prev2 && !iclk_prev1 && !iclk && iclk_state) begin
			iclk_state <= 0;

			// also, if the hsync is low, sample the data lines and store to memory
			if(ihsync_state == 0) begin
				ipixel <= ipixel+1'd1; // increment pixel count
				
				// store the current pixel address as write address
				// take data from a few clock cycles ago
				// initiate write
				ipixel_latched <= ipixel;
				idata_latched <= ~idata_prev5;
				iwrite_latched <= 1;
			end
		end


		// input hsync filtering and handling

		// if hsync has been high for a while, change the hsync state high
		if(ihsync_prev2 && ihsync_prev1 && ihsync && !ihsync_state) begin
			ihsync_state <= 1;
		end

		// if hsync has been low for a while, change the hsync state low
		if(!ihsync_prev2 && !ihsync_prev1 && !ihsync && ihsync_state) begin
			ihsync_state <= 0;

			ipixel <= ipixel+1'd1; // increment pixel count

			// store the current pixel address
			// take data from a few clock cycles ago
			// initiate write
			ipixel_latched <= ipixel;
			idata_latched <= ~idata_prev5;
			iwrite_latched <= 1;
		end


		// input vsync filtering and handling

		// if vsync has been high for a while, change the vsync state high
		if(ivsync_prev3 && ivsync_prev2 && ivsync_prev1 && ivsync && !ivsync_state) begin
			ivsync_state <= 1;

			// rising edge of vsync signals a start of a new frame
			ipixel <= 0;

			// clear blank flag and data missing counter
			blank <= 0;
			framesmissing <= 0;
		end

		// if vsync has been low for a while, change the vsync state low
		if(!ivsync_prev3 && !ivsync_prev2 && !ivsync_prev1 && !ivsync && ivsync_state) begin
			ivsync_state <= 0;
		end

		//if nes_set has been 4'b1101 for a while, change the nes_set_clr state high 
		if((nes_clr_prev3 == 4'b1101)  && (nes_clr_prev2 == 4'b1101) && (nes_clr_prev1 == 4'b1101) && (nes_set == 4'b1101) && !nes_set_clr) begin
			nes_set_clr <= 1;
		end	

		//if nes_set has been low for a while, change the nes_set_clr state low		
		if(!nes_clr_prev3 && !nes_clr_prev2 && !nes_clr_prev1 && !nes_set && nes_set_clr) begin
			nes_set_clr <= 0;

			pal_cnt <= pal_cnt + 1;
			if (pal_cnt > pal_cnt_max) begin
				pal_cnt <= 1;
			end
		end	

		//if nes_set has been 4'b1110 for a while, change the nes_set_sl state high 
		if((nes_sl_prev3 == 4'b1110)  && (nes_sl_prev2 == 4'b1110) && (nes_sl_prev1 == 4'b1110) && (nes_set == 4'b1110) && !nes_set_sl) begin
			nes_set_sl <= 1;
		end	

		//if nes_set has been low for a while, change the nes_set_clr state low		
		if(!nes_sl_prev3 && !nes_sl_prev2 && !nes_sl_prev1 && !nes_set && nes_set_sl) begin
			nes_set_sl <= 0;

			sl_mod <= !sl_mod;
		end	



		// shift current data to data from previous clock cycle
		iclk_prev1 <= iclk;
		ivsync_prev1 <= ivsync;
		ihsync_prev1 <= ihsync;
		idata_prev1 <= idata;
		nes_sl_prev1 <= nes_set;
		nes_clr_prev1 <= nes_set;

		// shift previous clock cycle data to data from 2 clock cycles ago
		iclk_prev2 <= iclk_prev1;
		ivsync_prev2 <= ivsync_prev1;
		ihsync_prev2 <= ihsync_prev1;
		idata_prev2 <= idata_prev1;
		nes_sl_prev2 <= nes_sl_prev1;
		nes_clr_prev2 <= nes_clr_prev1;

		// shift data from 2 clock cycles ago to data from 3 clock cycles ago
		iclk_prev3 <= iclk_prev2;
		ivsync_prev3 <= ivsync_prev2;
		ihsync_prev3 <= ihsync_prev2;
		idata_prev3 <= idata_prev2;
		nes_sl_prev3 <= nes_sl_prev2;
		nes_clr_prev3 <= nes_clr_prev2;

		// shift data from 3 clock cycles ago to data from 4 clock cycles ago
		idata_prev4 <= idata_prev3;
		ihsync_prev4 <= ihsync_prev3;

		// shift data from 4 clock cycles ago to data from 5 clock cycles ago
		idata_prev5 <= idata_prev4;
		ihsync_prev5 <= ihsync_prev4;
	end
	
	// assign output
	
	// compute the visibility signal for the pixel after 2 clock cycles
	assign visible_next2 = hcounter_next2 < h_vis && vcounter_next2 < v_vis;

	// compute the address in framebuffer for the pixel after 2 clock cycles
	// if pixel is not visible, default to address 0
	// otherwise address = vcount/4 * 160 + hcount/4
	assign opixel_next2[14:0] = visible_next2*(vcounter_next2[9:2]*8'd160 + hcounter_next2[10:2]);
	
	// compute hsync and vsync signals for the pixel after 2 clock cycles
	// polarity is positive for the svga 800x600
	assign hsync_next2 = (hcounter_next2 >= h_vis + h_fp && hcounter_next2 < h_vis + h_fp + h_sync);
	assign vsync_next2 = (vcounter_next2 >= v_vis + v_fp && vcounter_next2 < v_vis + v_fp + v_sync);

	// connect the hsync and vsync outputs to the corresponding register
	assign hsync = hsync_now;
	assign vsync = vsync_now;
	
	// assign actual output pixel data

	always @(posedge clk) begin
		if(visible_now) begin
			// VGA output is not in blanking. Output data.
			if(!blank) begin

				if(pal_cnt == 14 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h2108;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h51CC;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFB0C;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFDED;
		            end
		        end

				if(pal_cnt == 13 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h2081;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h2113;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFDC4;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hF79E;
		            end
		        end

				if(pal_cnt == 12 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h6260;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE3AC;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE466;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE56C;
		            end
		        end

		        if(pal_cnt == 11 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h738E;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h8D29;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hC3EF;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hEDFE;
		            end
		        end

		        if(pal_cnt == 10 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h1804;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h78E9;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hBA88;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hEFDA;
		            end
		        end

		        if(pal_cnt == 9 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h0000;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h0738;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h2C21;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hD757;
		            end
		        end


		        if(pal_cnt == 8 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h04AF;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h662D;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hD2CB;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFFF5;
		            end
		        end

		        if(pal_cnt == 7 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'hFB99;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h067F;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h074F;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFFD2;
		            end
		        end

		        if(pal_cnt == 6 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'hFA6A;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFC87;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hEF0E;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE7B8;
		            end
		        end

		        if(pal_cnt == 5 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h0000;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h5000;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hA000;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE800;
		            end
		        end

		        if(pal_cnt == 4 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h0000;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h632C;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hB5B6;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFFFF;
		            end
		        end

		        if(pal_cnt == 3 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h422F;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h9312;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFCD0;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFED0;
		            end
		        end

		        if(pal_cnt == 2 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h59C4;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h6C68;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h7E2F;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFFF6;
		            end
		        end
				
				if(pal_cnt == 1 && sl_mod == 1'b0) begin
					if(data_now == 0) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h01C1;
		            end
		            else if(data_now == 2) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h1B05;
		            end
		            else if(data_now == 1) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h8542;
		            end
		            else begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h95C2;
		            end
		        end

				if(pal_cnt == 14 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'd0;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'd26471;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'd46775;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'd65536;
		            end
		        end

				if(pal_cnt == 14 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h2108;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h51CC;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFB0C;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFDED;
		            end
		        end

				if(pal_cnt == 13 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h2081;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h2113;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFDC4;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hF79E;
		            end
		        end

				if(pal_cnt == 12 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h6260;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE3AC;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE466;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE56C;
		            end
		        end

		        if(pal_cnt == 11 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h738E;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h8D29;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hC3EF;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hEDFE;
		            end
		        end

		        if(pal_cnt == 10 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h1804;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h78E9;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hBA88;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hEFDA;
		            end
		        end

		        if(pal_cnt == 9 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h0000;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h0738;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h2C21;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hD757;
		            end
		        end


		        if(pal_cnt == 8 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h04AF;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h662D;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hD2CB;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFFF5;
		            end
		        end

		        if(pal_cnt == 7 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'hFB99;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h067F;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h074F;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFFD2;
		            end
		        end

		        if(pal_cnt == 6 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'hFA6A;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFC87;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hEF0E;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE7B8;
		            end
		        end

		        if(pal_cnt == 5 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h0000;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h5000;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hA000;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hE800;
		            end
		        end

		        if(pal_cnt == 4 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h0000;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h632C;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hB5B6;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFFFF;
		            end
		        end

		        if(pal_cnt == 3 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h422F;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h9312;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFCD0;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFED0;
		            end
		        end

		        if(pal_cnt == 2 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h59C4;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h6C68;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h7E2F;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'hFFF6;
		            end
		        end
				
				if(pal_cnt == 1 && sl_mod == 1'b1) begin
					if(data_now == 0 && (vcounter_next2 % 2 == 0)) begin 
					 	{vga_r_r, vga_g_r, vga_b_r} <= 16'h01C1;
		            end
		            else if(data_now == 1 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h1B05;
		            end
		            else if(data_now == 2 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h8542;
		            end
		            else if(data_now == 3 && (vcounter_next2 % 2 == 0)) begin
						{vga_r_r, vga_g_r, vga_b_r} <= 16'h95C2;
		            end
		        end
	        end
		end
		else begin
			// VGA output is in blanking. Display black.
			vga_r_r <= 5'b00000;
			vga_g_r <= 6'b000000;
			vga_b_r <= 5'b00000;
		end
	end
endmodule
