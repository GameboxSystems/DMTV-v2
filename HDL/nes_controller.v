`default_nettype none //disable implicit definitions by Verilog


module nes_controller(
	clk,
	data_out,
	nes_clock,
	nes_latch,
	nes_data
	);

input 					clk;
input   				nes_data;
output reg 		[7:0]	data_out;
output 					nes_clock;
output  				nes_latch;

reg 				nes_latch_r;
reg 				nes_clock_r;
reg 				nes_data_r;
//reg 		[7:0]   data_out_r;

assign nes_data 	= nes_data_r;
assign nes_clock 	= nes_clock_r;
assign nes_latch 	= nes_latch_r;
//assign data_out 	= data_out_r;


parameter			clk_div 	= 40;
reg 		[7:0] 	shifter 	= 8'b00000000;
integer 			clk_cnt,
					bits_cnt 	= 0;
reg 				half  		= 0;

/* State machine definitions
2'b00 = starting state
2'b01 = wait state
2'b10 = low state
2'b11 = high state 
*/

reg 		[1:0]   sm_state 	= 2'b00;

always @(posedge clk ) begin
	if (clk_cnt == ((clk_div/2)-1)) begin
		clk_cnt <= 0;
		half    <= 1'b1;		
	end
	else begin
		clk_cnt <= clk_cnt + 1;
		half    <= 1'b0;
	end
end

always @(posedge clk) begin
	if (shifter == 8'b00000000) begin
		data_out <= 0;
	end
	if (half == 1'b1) begin
		case (sm_state)
			2'b00: begin
				nes_latch_r <= 1'b1;
				nes_clock_r <= 1'b0;
				shifter   	  <= {nes_data_r,shifter[7:1]};
				bits_cnt      <= 0;
				sm_state      <= 2'b01;
			end
			2'b01: begin
				nes_latch_r  <= 1'b0;
				nes_clock_r  <= 1'b0;
				sm_state  	   <= 2'b10;
			end
			2'b10: begin
				if (bits_cnt == 0) begin
					data_out <= ~shifter;	
				end 
				shifter			<= {nes_data_r,shifter[7:1]};
				nes_clock_r   <= 1'b1;
				sm_state 		<= 2'b11;
			end
			2'b11: begin
				nes_clock_r <= 1'b0;
				if(bits_cnt == 6) begin
					sm_state 	<= 2'b00;
				end
				else begin
					bits_cnt 	<= bits_cnt + 1;
					sm_state 	<= 2'b10;
				end
			end
			default: begin
				sm_state <= 2'b00;
			end	
		endcase
	end
end
endmodule




















