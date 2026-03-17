module mic_clk_gen(
	input clk,
	input rst_n,
	input vlt_on,
	input go_ult,
	output mc_clk
);

	parameter SYSTEM_FREQ = 48000000; // change depending on freq we plan on running
	localparam SYSTEM_PD = 1 / SYSTEM_FREQ;

	localparam POWERUP_TIME = 0.05;
	localparam MODECHNG_TIME = 0.01;

	localparam STD_FREQ = 2000000;
	localparam ULT_FREQ = 4800000;


	typedef enum logic [1:0] {IDLE, PWRUP, STD, ULT} state_t;
	
	state_t state, nxt_state;

	logic change_modes;

	logic [$clog2(POWERUP_TIME / SYSTEM_PD)-1:0] pu_clks;
	logic [$clog2(MODECHNG_TIME / SYSTEM_PD)-1:0] md_clks;




	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			pu_clks <= '0;
		end else if (powered) begin
			pu_clks <= $ceil(POWERUP_TIME / SYSTEM_PD);
		end else if (pu_clocks != 0) begin
			pu_clks <= pu_clocks - 1;
		end
	end

	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			md_clks <= '0;
		end else if (change_modes) begin
			md_clks <= $ceil(MODECHNG_TIME / SYSTEM_PD);
		end else if (md_clks != 0) begin
			md_clks <= md_clks - 1;
		end
	end



	pulse_gen #($ceil((SYSTEM_FREQ / STD_FREQ) / 2)) iSTD(
		.clk(clk), .rst_n(rst_n), .pulse(std_clk)
	);

	pulse_gen #($ceil((SYSTEM_FREQ / ULT_FREQ) / 2)) iULT(
		.clk(clk), .rst_n(rst_n), .pulse(ult_clk)
	);


	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			mc_clk <= 1'b0;
		end else if (state == STD) begin
			mc_clk <= std_clk;
		end else if (state == ULT) begin
			mc_clk <= ult_clk;
		end else begin
			mc_clk <= 1'b0;
		end
	end




	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			state <= IDLE;
		end else begin
			state <= nxt_state;
		end
	end


	always_comb begin
		nxt_state = state;
		powered = 1'b0;
		change_modes = 1'b0;


		case (state)
			IDLE : 	begin
				if (vlt_on) begin
					nxt_state = PWRUP;
					powered = 1'b1;
				end
			end

			PWRUP : begin
				if (pu_clks == 0) begin
					nxt_state = STD;
					change_modes = 1'b1;
				end

			end

			STD : begin
				if (md_clks == 0 && go_ult) begin
					nxt_state = ULT;
					change_modes = 1'b1;
				end
			end

			ULT : begin
				if (md_clks == 0 && !go_ult) begin
					nxt_state = STD;
					change_modes = 1'b1;
				end
			end
		endcase
	end

endmodule