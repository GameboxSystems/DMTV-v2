
`default_nettype none //disable implicit definitions by Verilog
//apio build --size 1k --type hx --pack vq100

module top( //top module and signals wired to FPGA pins
    vga_r,
    vga_g,
    vga_b,
    vga_hs,
    vga_vs,

    wclk,
	CLK40MHz,
    write_en,
    din,
	btnLft, //D10
	btnB, //D9
	btnUp, //D8
	btnDwn, //D7
	btnA //D11
);

parameter addr_width = 15;
parameter data_width = 2;
reg [data_width-1:0] mem [(1<<addr_width)-1:0];

reg  [data_width-1:0] dout;
wire [addr_width-1:0] raddr;
reg  [addr_width-1:0] raddr_r = 0;
assign raddr = raddr_r;

input wclk;
input write_en;
input btnLft;
input btnB;
input btnUp;
input btnDwn;
input btnA;
reg   write_en_r;
input [data_width-1:0] din;
wire [addr_width-1:0] waddr;
reg  [addr_width-1:0] waddr_r = 0;
assign waddr = waddr_r;

always @(negedge wclk) // Write memory
begin
  if(write_en == 0 && write_en_r == 1) begin // VSYNC
    mem[0] <= din;
    waddr_r <= 1;
    write_en_r <= 0;
  end
  else begin
    mem[waddr] <= din;
    waddr_r <= waddr_r + 1; // Increment address
    if(write_en == 1) begin
      write_en_r <= 1;
    end
  end
end

input               CLK40MHz;   // Oscillator input 40MHz
output   [4:0]           vga_r;      // VGA Red 5 bit
output   [5:0]           vga_g;      // VGA Green 6 bit
output   [4:0]           vga_b;      // VGA Blue 5 bit
output              vga_hs;     // H-sync pulse
output              vga_vs;     // V-sync pulse

parameter h_pulse   = 128;   //H-SYNC pulse width 128 * 25 ns (40 Mhz) = 3.213 uS
parameter h_bp      = 88;   //H-BP back porch pulse width
parameter h_pixels  = 800;  //H-PIX Number of pixels horizontally
parameter h_fp      = 40;   //H-FP front porch pulse width
parameter h_pol     = 1'b1; //H-SYNC polarity
parameter h_frame   = 1056;  //800 = 96 (H-SYNC) + 48 (H-BP) + 640 (H-PIX) + 16 (H-FP)
parameter v_pulse   = 4;    //V-SYNC pulse width
parameter v_bp      = 23;   //V-BP back porch pulse width
parameter v_pixels  = 600;  //V-PIX Number of pixels vertically
parameter v_fp      = 1;   //V-FP front porch pulse width
parameter v_pol     = 1'b1; //V-SYNC polarity
parameter v_frame   = 628;  //525 = 2 (V-SYNC) + 33 (V-BP) + 480 (V-PIX) + 10 (V-FP)
parameter rst		= 4'b1100;
parameter rstSL		= 1;

reg      [4:0]           vga_r_r;  //VGA colour registers 
reg      [5:0]           vga_g_r;
reg      [4:0]           vga_b_r;
reg                 vga_hs_r; //H-SYNC register
reg                 vga_vs_r; //V-SYNC register

assign  vga_r       = vga_r_r; //assign the output signals for VGA to the VGA registers
assign  vga_g       = vga_g_r;
assign  vga_b       = vga_b_r;
assign  vga_hs      = vga_hs_r;
assign  vga_vs      = vga_vs_r;

reg     [11:0]       timer_t = 12'b0; //8-bit timer with 0 initialisation
reg                 reset = 1;
reg     [12:0]       c_row;      //visible frame register row
reg     [12:0]       c_col;      //visible frame register column
reg     [12:0]       c_hor;      //complete frame register horizontally
reg     [12:0]       c_ver;      //complete frame register vertically
reg     [12:0]       scale_col;  //counter for scaling horizontally
reg     [12:0]       scale_row;  //counter for scaling vertically
//reg		[3:0]		dout3_mod = 3'b111;	//Counts and stores bits to be assigned to RGB bits
//reg		[3:0]		dout2_mod = 3'b010;
//reg		[3:0]		dout1_mod = 3'b011;
//reg		[3:0]		dout0_mod = 3'b000;
reg		[3:0]		clrRegCnt = 4'b0000;	//Color counting registry
reg 				SLCnt; //Scan Line enable count		
//reg		[23:0]		color;

//reg		[11:0]		palette [0:64];
reg		[15:0]		color;

reg                 disp_en; //display enable flag


always @ (posedge CLK40MHz) begin

	if(btnA == 1) begin
		if(clrRegCnt <= 4'b1101) begin
			clrRegCnt <= clrRegCnt + 4'b0001;
			end
		else begin
			clrRegCnt <= 4'b0001;
		end
	end
	
	if(btnB == 1) begin
		if(SLCnt < rstSL) begin
			SLCnt <= SLCnt + 1'b1;
		end
		else begin
			SLCnt <= 1'b0;
		end
	end

	/*if(btnUp == 1) begin
		if(clrRegCnt < 0'b000 || clrRegCnt > rst) begin
			clrRegCnt <= 3'b0;
			end
		else begin
			clrRegCnt <= clrRegCnt - 3'b001;
		end
	end*/

    if(timer_t > 836) begin //generate 10 uS RESET signal
        reset <= 0;
    end
    else begin
        reset <= 1;              //while in reset display is disabled
        timer_t <= timer_t + 1;
        disp_en <= 0;
    end

    if(reset == 1) begin         //while RESET is high init counters
        c_hor <= 0;
        c_ver <= 0;
        vga_hs_r <= 1;
        vga_vs_r <= 0;
        c_row <= 0;
        c_col <= 0;
        scale_col <= 55;
        scale_row <= 21;
    end
    else begin //update current beam position
        if(c_hor < h_frame - 1) begin
            c_hor <= c_hor + 1;
        end
        else begin
            c_hor <= 0;
            if(c_ver < v_frame - 1) begin
                c_ver <= c_ver + 1;
            end
            else begin
                c_ver <= 0;
            end
        end
    end
    if(c_hor < h_pixels + h_fp + 1 || c_hor > h_pixels + h_fp + h_pulse) begin //H-SYNC generator
        vga_hs_r <= ~h_pol;
    end
    else begin
        vga_hs_r <= h_pol;
    end
    if(c_ver < v_pixels + v_fp || c_ver > v_pixels + v_fp + v_pulse) begin     //V-SYNC generator
        vga_vs_r <= ~v_pol;
    end
    else begin
        vga_vs_r <= v_pol;
    end
    if(c_hor < h_pixels) begin //c_col and c_row counters are updated only in the visible time-frame
        c_col <= c_hor;
    end
    if(c_ver < v_pixels) begin
        c_row <= c_ver;
    end
    if(c_hor < h_pixels && c_ver < v_pixels) begin //VGA colour signals are enabled only in the visible time frame
        disp_en <= 1;
    end
    else begin
        disp_en <= 0;
    end
    if(disp_en == 1 && reset == 0) begin

        dout <= mem[raddr]; // Read memory

        if(c_row == 0 && c_col == 0) begin //reset scaling
              scale_col <= 55;
              scale_row <= 21;
        end

        if(c_row == 20 && c_col == 799) begin //reset address
              raddr_r <= 0;
        end

        if(c_col == 0 && c_row > 20 && c_row < 593) begin //reset at the start of each line
              scale_col <= 55;
              if(c_row == scale_row) begin
                scale_row <= scale_row + 4;
              end
              else if(raddr_r != 0) begin
                //set pixel buffer address back to beginning of line
                raddr_r <= raddr_r - 160;
              end
        end

		
		if(c_col > 54 && c_col < 694 && c_row > 20 && c_row < 592) begin //centered 480 x 432 area

			if(c_col == scale_col && c_col < 693) begin
			  scale_col <= scale_col + 4;
			  //increment pixel buffer address horizontally
			  raddr_r <= raddr_r + 1;
			end

			/*In the active frame, this colorizes the pixel data according to the current count from the MCU signal. SLcnt is the
			scan line toggle and clrRegCnt is the color count registery to determine color pallete. These counts are controlled
			by the MCU. There is only a debounce on the MCU side but not the FPGA side so transitions happen quickly.*/
						
			if(clrRegCnt == 4'b1101 && SLCnt == 1'b0) begin
				if(dout == 3) begin //Baby WAH
				  color <= 16'h9061;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h88B7;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'hFED3;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hAF55;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
			end

			if(clrRegCnt == 4'b1100 && SLCnt == 1'b0) begin
				if(dout == 3) begin //Glowing Moss
				  color <= 16'h3978;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h47F4;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'h45F3;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hFD9E;
	              vga_r_r[4:0] <= color[15:11];h9061
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b1011 && SLCnt == 1'b0) begin
				if(dout == 3) begin //Lost and faded
				  color <= 16'h738E;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h8D29;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'hC3EF;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hEDFE;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b1010 && SLCnt == 1'b0) begin
				if(dout == 3) begin //Angel
				  color <= 16'h3992;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h9622;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'hF2EB;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hC7BD;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b1001 && SLCnt == 1'b0) begin
				if(dout == 3) begin //Coolcumber
				  color <= 16'h0000;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h0738;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'h2C21;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hD757;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end


	        if(clrRegCnt == 4'b1000 && SLCnt == 1'b0) begin
				if(dout == 3) begin //Untitled #1
				  color <= 16'h04AF;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h662D;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'hD2CB;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hFFF5;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0111 && SLCnt == 1'b0) begin
				if(dout == 3) begin //VaporWavey2 
				//This one kicks ass
				  color <= 16'hFB99;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h067F;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'h074F;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hFFD2;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0110 && SLCnt == 1'b0) begin
				if(dout == 3) begin //Summer
				  color <= 16'hFA6A;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'hFC87;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'hEF0E;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hE7B8;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0101 && SLCnt == 1'b0) begin
				if(dout == 3) begin //VB
				  color <= 16'h4000;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h8000;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'hB800;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hF800;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0100 && SLCnt == 1'b0) begin
				if(dout == 3) begin //Retro
				  color <= 16'h6328;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'hF960;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'h6E53;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hFF11;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0011 && SLCnt == 1'b0) begin
				if(dout == 3) begin //VaporWavy
				  color <= 16'h422F;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h9312;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'hFCD0;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hFED0;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0010 && SLCnt == 1'b0) begin
				if(dout == 3) begin //zeldaaaaaa deeee exxxx
				  color <= 16'h59C4;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h6C68;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'h7E2F;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else begin
				  color <= 16'hFFF6;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end
			
			if(clrRegCnt == 4'b0001 && SLCnt == 1'b0) begin
				if(dout == 0) begin //GB, WORKS!!!
				  color <= 16'hD68B;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1) begin
				  color <= 16'hA548;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2) begin
				  color <= 16'h7405;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 3) begin
				  color <= 16'h4282;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b1101 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //Baby WAH
				  color <= 16'h9061;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h88B7;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'hFED3;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if (dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hAF55;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
			end

			if(clrRegCnt == 4'b1100 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //Glowing Moss
				  color <= 16'h3978;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h47F4;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'h45F3;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hFD9E;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b1011 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //Lost and faded
				  color <= 16'h738E;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h8D29;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'hC3EF;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hEDFE;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b1010 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //Angel
				  color <= 16'h3992;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h9622;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'hF2EB;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hC7BD;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b1001 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //Coolcumber
				  color <= 16'h0000;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h0738;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'h2C21;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hD757;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end


	        if(clrRegCnt == 4'b1000 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //Untitled #1
				  color <= 16'h04AF;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h662D;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'hD2CB;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hFFF5;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0111 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //VaporWavey2 
				//This one kicks ass
				  color <= 16'hFB99;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h067F;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'h074F;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hFFD2;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0110 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //Summer
				  color <= 16'hFA6A;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'hFC87;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'hEF0E;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hE7B8;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0101 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //VB
				  color <= 16'h4000;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h8000;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'hB800;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hF800;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0100 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //Retro
				  color <= 16'h6328;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'hF960;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'h6E53;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hFF11;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0011 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //VaporWavy
				  color <= 16'h422F;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h9312;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'hFCD0;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0  && (c_row % 2 == 0)) begin
				  color <= 16'hFED0;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end

	        if(clrRegCnt == 4'b0010 && SLCnt == 1'b1) begin
				if(dout == 3 && (c_row % 2 == 0)) begin //zelda dx
				  color <= 16'h59C4;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h6C68;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'h7E2F;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 0 && (c_row % 2 == 0)) begin
				  color <= 16'hFFF6;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end
			
			if(clrRegCnt == 4'b0001 && SLCnt == 1'b1) begin
				if(dout == 0 && (c_row % 2 == 0)) begin //DMG Theme
				  color <= 16'hD68B;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 1 && (c_row % 2 == 0)) begin
				  color <= 16'hA548;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 2 && (c_row % 2 == 0)) begin
				  color <= 16'h7405;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	            else if(dout == 3  && (c_row % 2 == 0)) begin
				  color <= 16'h4282;
	              vga_r_r[4:0] <= color[15:11];
	              vga_g_r[5:0] <= color[10:5];
	              vga_b_r[4:0] <= color[4:0]; 
	            end
	        end
			/*if(clrRegCnt == 4'b0000 ) begin //Default GB theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'hF0;
				  color_g <= 8'h83;
				  color_b <= 8'hF0;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h03;
				  color_g <= 8'h26;
				  color_b <= 8'h03;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'hB8;
				  color_g <= 8'hCA;
				  color_b <= 8'hF0;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hB9;
				  color_g <= 8'hCB;
				  color_b <= 8'hF0;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end

			if(clrRegCnt == 4'b0001) begin//Zelda DX Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'hA5;
				  color_g <= 8'h93;
				  color_b <= 8'h12;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'hB6;
				  color_g <= 8'hC8;
				  color_b <= 8'h24;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'hB7;
				  color_g <= 8'h6C;
				  color_b <= 8'hB7;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hFF;
				  color_g <= 8'hFF;
				  color_b <= 8'h5B;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end

			if(clrRegCnt == 4'b0010) begin//Pokemanz Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h7E;
				  color_g <= 8'h8E;
				  color_b <= 8'h3F;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'hC8;
				  color_g <= 8'h38;
				  color_b <= 8'h3C;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h36;
				  color_g <= 8'HD4;
				  color_b <= 8'hF8;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'h21;
				  color_g <= 8'hB0;
				  color_b <= 8'h91;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b0011) begin//Kirby Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'hC2;
				  color_g <= 8'hC2;
				  color_b <= 8'h69;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h77;
				  color_g <= 8'h33;
				  color_b <= 8'h7E;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h7E;
				  color_g <= 8'h68;
				  color_b <= 8'h68;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'h7F;
				  color_g <= 8'hEB;
				  color_b <= 8'h7F;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b0100) begin//Metroid Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'hC2;
				  color_g <= 8'h71;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h40;
				  color_g <= 8'hE7;
				  color_b <= 8'h06;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h6B;
				  color_g <= 8'h52;
				  color_b <= 8'h85;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hEA;
				  color_g <= 8'hFD;
				  color_b <= 8'hE1;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end		

			if(clrRegCnt == 4'b0101) begin//Super mario 6 golden coins Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h00;
				  color_g <= 8'h00;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h11;
				  color_g <= 8'h6C;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'hFD;
				  color_g <= 8'h6A;
				  color_b <= 8'h77;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hFE;
				  color_g <= 8'h7F;
				  color_b <= 8'h6B;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end		

			if(clrRegCnt == 4'b0110) begin//Greyscale Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h00;
				  color_g <= 8'h00;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h76;
				  color_g <= 8'h76;
				  color_b <= 8'h76;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h6B;
				  color_g <= 8'h6B;
				  color_b <= 8'h6B;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hFF;
				  color_g <= 8'hFF;
				  color_b <= 8'hFF;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b0111) begin//MegaMan Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'hE1;
				  color_g <= 8'h00;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'hE9;
				  color_g <= 8'h00;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h7F;
				  color_g <= 8'hE8;
				  color_b <= 8'h05;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hEC;
				  color_g <= 8'h7F;
				  color_b <= 8'h7F;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b1000) begin//GRAPEFRUIT Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h56;
				  color_g <= 8'h92;
				  color_b <= 8'hC6;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h7B;
				  color_g <= 8'h56;
				  color_b <= 8'h19;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h4F;
				  color_g <= 8'h2B;
				  color_b <= 8'hB6;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hFF;
				  color_g <= 8'h5F;
				  color_b <= 8'hDD;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end		

			if(clrRegCnt == 4'b1001) begin//SUPER GB Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h33;
				  color_g <= 8'hE1;
				  color_b <= 8'h05;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h6A;
				  color_g <= 8'h73;
				  color_b <= 8'h52;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h6D;
				  color_g <= 8'hE8;
				  color_b <= 8'h94;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'h7F;
				  color_g <= 8'h7E;
				  color_b <= 8'h6C;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b1010) begin//SPACEHAZE Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h33;
				  color_g <= 8'hC2;
				  color_b <= 8'h05;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h64;
				  color_g <= 8'h78;
				  color_b <= 8'hF8;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h49;
				  color_g <= 8'h3E;
				  color_b <= 8'h44;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'h2E;
				  color_g <= 8'h3F;
				  color_b <= 8'h4E;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	
			if(clrRegCnt == 4'b0000 && SLCnt == 1'b0) begin //Default GB theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'hF0;
				  color_g <= 8'h83;
				  color_b <= 8'hF0;	
	              vga_r_r <= color_r[7:0]; //ACCENT COLOR, NOT PRIMARY
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h03;
				  color_g <= 8'h26;
				  color_b <= 8'h03;	
	              vga_r_r <= ~color_r[7:0]; 
	              vga_g_r <= ~color_g[7:0];
	              vga_b_r <= ~color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'hB8;
				  color_g <= 8'hCA;
				  color_b <= 8'hF0;	
	              vga_r_r <= color_r[7:0]; //MAIN COLOR - BACKGROUND COLOR
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hB9;
				  color_g <= 8'hCB;
				  color_b <= 8'hF0;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end

			if(clrRegCnt == 4'b0001 && SLCnt == 1'b0) begin//Zelda DX Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'hA5;
				  color_g <= 8'h93;
				  color_b <= 8'h12;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'hB6;
				  color_g <= 8'hC8;
				  color_b <= 8'h24;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'hB7;
				  color_g <= 8'h6C;
				  color_b <= 8'hB7;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hFF;
				  color_g <= 8'hFF;
				  color_b <= 8'h5B;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end

			if(clrRegCnt == 4'b0010 && SLCnt == 1'b0) begin//Pokemanz Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h7E;
				  color_g <= 8'h8E;
				  color_b <= 8'h3F;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'hC8;
				  color_g <= 8'h38;
				  color_b <= 8'h3C;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h36;
				  color_g <= 8'HD4;
				  color_b <= 8'hF8;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'h21;
				  color_g <= 8'hB0;
				  color_b <= 8'h91;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b0011 && SLCnt == 1'b0) begin//Kirby Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'hC2;
				  color_g <= 8'hC2;
				  color_b <= 8'h69;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h77;
				  color_g <= 8'h33;
				  color_b <= 8'h7E;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h7E;
				  color_g <= 8'h68;
				  color_b <= 8'h68;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'h7F;
				  color_g <= 8'hEB;
				  color_b <= 8'h7F;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b0100 && SLCnt == 1'b0) begin//Metroid Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'hC2;
				  color_g <= 8'h71;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h40;
				  color_g <= 8'hE7;
				  color_b <= 8'h06;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h6B;
				  color_g <= 8'h52;
				  color_b <= 8'h85;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hEA;
				  color_g <= 8'hFD;
				  color_b <= 8'hE1;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end		

			if(clrRegCnt == 4'b0101 && SLCnt == 1'b0) begin//Super mario 6 golden coins Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h00;
				  color_g <= 8'h00;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h11;
				  color_g <= 8'h6C;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'hFD;
				  color_g <= 8'h6A;
				  color_b <= 8'h77;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hFE;
				  color_g <= 8'h7F;
				  color_b <= 8'h6B;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end		

			if(clrRegCnt == 4'b0110 && SLCnt == 1'b0) begin//Greyscale Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h00;
				  color_g <= 8'h00;
				  color_b <= 8'h00;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h76;
				  color_g <= 8'h76;
				  color_b <= 8'h76;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h6B;
				  color_g <= 8'h6B;
				  color_b <= 8'h6B;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hFF;
				  color_g <= 8'hFF;
				  color_b <= 8'hFF;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b0111 && SLCnt == 1'b0) begin//GRAPEFRUIT Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h56;
				  color_g <= 8'h92;
				  color_b <= 8'hC6;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h7B;
				  color_g <= 8'h56;
				  color_b <= 8'h19;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h4F;
				  color_g <= 8'h2B;
				  color_b <= 8'hB6;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'hFF;
				  color_g <= 8'h5F;
				  color_b <= 8'hDD;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end		

			if(clrRegCnt == 4'b1001 && SLCnt == 0) begin//SUPER GB Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h33;
				  color_g <= 8'hE1;
				  color_b <= 8'h05;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h6A;
				  color_g <= 8'h73;
				  color_b <= 8'h52;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h6D;
				  color_g <= 8'hE8;
				  color_b <= 8'h94;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'h7F;
				  color_g <= 8'h7E;
				  color_b <= 8'h6C;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b1000 && SLCnt == 0) begin//SPACEHAZE Theme
				if(dout == 3) begin //check pixel buffer data
				  color_r <= 8'h33;
				  color_g <= 8'hC2;
				  color_b <= 8'h05;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 2) begin
				  color_r <= 8'h64;
				  color_g <= 8'h78;
				  color_b <= 8'hF8;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else if(dout == 1) begin
				  color_r <= 8'h49;
				  color_g <= 8'h3E;
				  color_b <= 8'h44;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
	            else begin
				  color_r <= 8'h2E;
				  color_g <= 8'h3F;
				  color_b <= 8'h4E;	
	              vga_r_r <= color_r[7:0];
	              vga_g_r <= color_g[7:0];
	              vga_b_r <= color_b[7:0]; 
	            end
			end	

			if(clrRegCnt == 4'b0000 && SLCnt == 1'b1) begin //Default GB theme
					if(dout == 3 && (c_row % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'hF0;
					  color_g <= 8'h83;
					  color_b <= 8'hF0;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 2 && (c_row % 2 == 0)) begin
					  color_r <= 8'h03;
					  color_g <= 8'h26;
					  color_b <= 8'h03;	
		              vga_r_r <= ~color_r[7:0];
		              vga_g_r <= ~color_g[7:0];
		              vga_b_r <= ~color_b[7:0]; 
		            end
		            if(dout == 1 && (c_row % 2 == 0)) begin
					  color_r <= 8'hB8;
					  color_g <= 8'hCA;
					  color_b <= 8'hF0;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 0 && (c_row % 2 == 0)) begin
					  color_r <= 8'hB9;
					  color_g <= 8'hCB;
					  color_b <= 8'hF0;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end

				if(clrRegCnt == 4'b0001 && SLCnt == 1'b1) begin//Zelda DX Theme
					if(dout == 3 && (c_row % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'hA5;
					  color_g <= 8'h93;
					  color_b <= 8'h12;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 2 && (c_row % 2 == 0)) begin
					  color_r <= 8'hB6;
					  color_g <= 8'hC8;
					  color_b <= 8'h24;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 1 && (c_row % 2 == 0)) begin
					  color_r <= 8'hB7;
					  color_g <= 8'h6C;
					  color_b <= 8'hB7;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 0 && (c_row % 2 == 0)) begin
					  color_r <= 8'hFF;
					  color_g <= 8'hFF;
					  color_b <= 8'h5B;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end

				if(clrRegCnt == 4'b0010  && SLCnt == 1'b1) begin//Pokemanz Theme
					if(dout == 3 && (c_row % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'h7E;
					  color_g <= 8'h8E;
					  color_b <= 8'h3F;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 2 && (c_row % 2 == 0)) begin
					  color_r <= 8'hC8;
					  color_g <= 8'h38;
					  color_b <= 8'h3C;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            else if(dout == 1 && (c_row % 2 == 0)) begin
					  color_r <= 8'h36;
					  color_g <= 8'HD4;
					  color_b <= 8'hF8;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 0 && (c_row % 2 == 0)) begin
					  color_r <= 8'h21;
					  color_g <= 8'hB0;
					  color_b <= 8'h91;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end	

				if(clrRegCnt == 4'b0011 && SLCnt == 1'b1) begin//Kirby Theme
					if(dout == 3 && (c_row % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'hC2;
					  color_g <= 8'hC2;
					  color_b <= 8'h69;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 2 && (c_row % 2 == 0)) begin
					  color_r <= 8'h77;
					  color_g <= 8'h33;
					  color_b <= 8'h7E;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 1 && (c_row % 2 == 0)) begin
					  color_r <= 8'h7E;
					  color_g <= 8'h68;
					  color_b <= 8'h68;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 0 && (c_row % 2 == 0)) begin
					  color_r <= 8'h7F;
					  color_g <= 8'hEB;
					  color_b <= 8'h7F;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end	

				if(clrRegCnt == 4'b0100 && SLCnt == 1'b1) begin//Metroid Theme
					if(dout == 3 && (c_row % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'hC2;
					  color_g <= 8'h71;
					  color_b <= 8'h00;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 2 && (c_row % 2 == 0)) begin
					  color_r <= 8'h40;
					  color_g <= 8'hE7;
					  color_b <= 8'h06;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 1 && (c_row % 2 == 0)) begin
					  color_r <= 8'h6B;
					  color_g <= 8'h52;
					  color_b <= 8'h85;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 0 && (c_row % 2 == 0)) begin
					  color_r <= 8'hEA;
					  color_g <= 8'hFD;
					  color_b <= 8'hE1;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end		

				if(clrRegCnt == 4'b0101 && SLCnt == 1'b1) begin//Super mario 6 golden coins Theme
					if(dout == 3 && (c_row % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'h00;
					  color_g <= 8'h00;
					  color_b <= 8'h00;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 2 && (c_row % 2 == 0)) begin
					  color_r <= 8'h11;
					  color_g <= 8'h6C;
					  color_b <= 8'h00;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 1 && (c_row % 2 == 0)) begin
					  color_r <= 8'hFD;
					  color_g <= 8'h6A;
					  color_b <= 8'h77;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 0 && (c_row % 2 == 0)) begin
					  color_r <= 8'hFE;
					  color_g <= 8'h7F;
					  color_b <= 8'h6B;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end		

				if(clrRegCnt == 4'b0110 && SLCnt == 1'b1) begin//Greyscale Theme
					if(dout == 3 && (c_row % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'h00;
					  color_g <= 8'h00;
					  color_b <= 8'h00;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 2 && (c_row % 2 == 0)) begin
					  color_r <= 8'h76;
					  color_g <= 8'h76;
					  color_b <= 8'h76;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 1 && (c_row % 2 == 0)) begin
					  color_r <= 8'h6B;
					  color_g <= 8'h6B;
					  color_b <= 8'h6B;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 0 && (c_row % 2 == 0)) begin
					  color_r <= 8'hFF;
					  color_g <= 8'hFF;
					  color_b <= 8'hFF;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end	

				if(clrRegCnt == 4'b0111 && SLCnt == 1'b1) begin//GRAPEFRUIT Theme
					if(dout == 3 && (c_row % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'h56;
					  color_g <= 8'h92;
					  color_b <= 8'hC6;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 2 && (c_row % 2 == 0)) begin
					  color_r <= 8'h7B;
					  color_g <= 8'h56;
					  color_b <= 8'h19;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 1 && (c_row % 2 == 0)) begin
					  color_r <= 8'h4F;
					  color_g <= 8'h2B;
					  color_b <= 8'hB6;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            if(dout == 0 && (c_row % 2 == 0)) begin
					  color_r <= 8'hFF;
					  color_g <= 8'h5F;
					  color_b <= 8'hDD;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end		
				
				if(clrRegCnt == 4'b1001 && SLCnt == 1) begin//SUPER GB Theme
					if(dout == 3 && (c_col % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'h33;
					  color_g <= 8'hE1;
					  color_b <= 8'h05;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            else if(dout == 2 && (c_col % 2 == 0)) begin
					  color_r <= 8'h6A;
					  color_g <= 8'h73;
					  color_b <= 8'h52;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            else if(dout == 1 && (c_col % 2 == 0)) begin
					  color_r <= 8'h6D;
					  color_g <= 8'hE8;
					  color_b <= 8'h94;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            else if(dout == 0 && (c_col % 2 == 0)) begin
					  color_r <= 8'h7F;
					  color_g <= 8'h7E;
					  color_b <= 8'h6C;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end	

				if(clrRegCnt == 4'b1000 && SLCnt == 1) begin//SPACEHAZE Theme
					if(dout == 3 && (c_col % 2 == 0)) begin //check pixel buffer data
					  color_r <= 8'h33;
					  color_g <= 8'hC2;
					  color_b <= 8'h05;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            else if(dout == 2 && (c_col % 2 == 0)) begin
					  color_r <= 8'h64;
					  color_g <= 8'h78;
					  color_b <= 8'hF8;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            else if(dout == 1 && (c_col % 2 == 0)) begin
					  color_r <= 8'h49;
					  color_g <= 8'h3E;
					  color_b <= 8'h44;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
		            else if(dout == 0 && (c_col % 2 == 0)) begin
					  color_r <= 8'h2E;
					  color_g <= 8'h3F;
					  color_b <= 8'h4E;	
		              vga_r_r <= color_r[7:0];
		              vga_g_r <= color_g[7:0];
		              vga_b_r <= color_b[7:0]; 
		            end
				end*/			
			end
		else begin //everything else is black
			vga_r_r <= 0;
			vga_g_r <= 0;
			vga_b_r <= 0;
		end

		if(c_col >= 54 && c_col < 58)begin //*IMPORTANT* this section of pixel data is always garbled, so this column range has been given 0 or black values
			vga_r_r <= 5'b00000;
			vga_g_r <= 6'b00000;
			vga_b_r <= 5'b00000;
		end
	end
	else begin //when display is not enabled everything is black
		vga_r_r <= 0;
		vga_g_r <= 0;
		vga_b_r <= 0;
	end
end
endmodule