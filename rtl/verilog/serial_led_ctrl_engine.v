/*
 *  AUTHOR: Digital Runecaster
 *  Baremetal Systems 
 *
 * Version 0.1
 * Date: November 2021
 *
 */
`default_nettype none

module serial_led_ctrl_engine #(  
        parameter CLOCK_FREQ 		= 12000000,
        parameter LED_DATA_WORD 	= 32
    ) (
    clk_i,
    rst_i,
    output_en_i,
    wr_en_i,
    led_data_i,
    led_data_o,
    busy_o,
    led_data_ack_o
);

input                               clk_i;
input                               rst_i;
input                               wr_en_i;
input                               output_en_i;
input  	[LED_DATA_WORD -1 : 0]		led_data_i;
output 	                    		led_data_o;
output                              busy_o;
output                              led_data_ack_o;


reg 	[LED_DATA_WORD -1 : 0]      led_data_reg;
reg                                 engine_busy_reg;
reg                                 data_ack_reg;
reg                                 wr_en_reg;
reg                                 out_en_reg;
reg                                 led_serial_out;

localparam LED_PULSE_FREQ			= 800000;

`ifdef FORMAL
localparam LED_PULSE_TICK_COUNT 	= 16;
localparam TICK_COUNTER_WIDTH		= 5;
localparam PULSE_0_TICK_COUNT		= 4;
localparam PULSE_1_TICK_COUNT		= 12;
`else
localparam LED_PULSE_TICK_COUNT 	= $rtoi($floor((CLOCK_FREQ / LED_PULSE_FREQ) + 1));
localparam TICK_COUNTER_WIDTH		= $clog2(LED_PULSE_TICK_COUNT);
localparam PULSE_0_TICK_COUNT		= $floor((LED_PULSE_TICK_COUNT / 8) * 2);
localparam PULSE_1_TICK_COUNT		= $floor((LED_PULSE_TICK_COUNT / 8) * 6);
`endif

`ifndef FORMAL
initial
begin
$display("Pulse Tick Count: %d", LED_PULSE_TICK_COUNT);
$display("Tick Counter Width: %d", TICK_COUNTER_WIDTH);
$display("Pulse 0 Tick Count: %d", PULSE_0_TICK_COUNT);
$display("Pulse 1 Tick Count: %d", PULSE_1_TICK_COUNT);
end
`endif


reg [TICK_COUNTER_WIDTH - 1 : 0] 	led_tick_counter_reg;
reg [LED_DATA_WORD - 1 : 0] 		bit_count_reg;

initial
begin
    led_data_reg = 0;
    engine_busy_reg = 0;
    data_ack_reg = 0;
    led_serial_out = 0;
    wr_en_reg = 0;
    out_en_reg = 0;
	led_tick_counter_reg = 0;
	bit_count_reg = 0;
end

assign led_data_o = led_serial_out;
assign busy_o = engine_busy_reg;
assign led_data_ack_o = data_ack_reg;

/* reading in input signals */
always@(posedge clk_i)
begin
	if (rst_i) begin
		wr_en_reg <= 0;
		out_en_reg <= 0;
		data_ack_reg <= 0;
	end
	else begin
		wr_en_reg <= wr_en_i;
		out_en_reg <= output_en_i;

		if (wr_en_reg == 1'b0 && wr_en_i == 1'b1) begin
			data_ack_reg <= 1'b1;
		end
		else begin
			data_ack_reg <= 1'b0;
		end
	end	
end

/* serial pulse generation */
always@(posedge clk_i)
begin
	if (rst_i) begin
		led_tick_counter_reg <= 0;
		bit_count_reg <= 0;
	end
	else begin
		if (out_en_reg) begin
			if (engine_busy_reg == 1'b1) begin	
				if (led_tick_counter_reg < LED_PULSE_TICK_COUNT - 1) begin
					led_tick_counter_reg <= led_tick_counter_reg + 1'b1;
					bit_count_reg <= bit_count_reg;
				end
				else begin
					led_tick_counter_reg <= 0;
					bit_count_reg <= {bit_count_reg[LED_DATA_WORD - 2:0], 1'b1};
				end
			end
			else begin
				led_tick_counter_reg <= 0;
				bit_count_reg <= 0;
			end
		end
		else begin
			led_tick_counter_reg <= 0;
			bit_count_reg <= 0;
		end
	end
end

/* serial out generation, i.e. bit coding */
always@(posedge clk_i)
begin
	if (rst_i) begin
		led_serial_out <= 0;
	end
	else begin
		if (engine_busy_reg == 1'b1 && bit_count_reg[LED_DATA_WORD - 1] != 1'b1) begin
			if (led_data_reg[LED_DATA_WORD - 1] == 1'b1) begin
				if (led_tick_counter_reg < PULSE_1_TICK_COUNT) begin
					led_serial_out <= 1'b1;
				end
				else begin
					led_serial_out <= 1'b0;
				end
			end
			else begin
				if (led_tick_counter_reg < PULSE_0_TICK_COUNT) begin
					led_serial_out <= 1'b1;
				end
				else begin
					led_serial_out <= 1'b0;
				end
			end
		end	
		else begin
			led_serial_out <= 0;
		end
	end
end

/* data update */
always@(posedge clk_i)
begin
	if (rst_i) begin
		engine_busy_reg <= 0;
		led_data_reg <= 0;
	end
	else begin
		if (data_ack_reg == 1'b1 && engine_busy_reg == 1'b0) begin
			led_data_reg <= led_data_i;
		end
		else if (led_tick_counter_reg >= (LED_PULSE_TICK_COUNT - 1)) begin
			led_data_reg <= led_data_reg << 1;
		end
		else begin
			led_data_reg <= led_data_reg;
		end

		if (data_ack_reg == 1'b1 && wr_en_reg == 1'b1) begin
			engine_busy_reg <= 1'b1;
		end
		else if (bit_count_reg[LED_DATA_WORD - 1] == 1'b1) begin
			engine_busy_reg <= 1'b0;
		end
		else begin
			engine_busy_reg <= engine_busy_reg;
		end
	end
end

//
// FORMAL
//

`ifdef FORMAL
always@(posedge clk_i)
begin
	assert(led_tick_counter_reg < LED_PULSE_TICK_COUNT);
    assert(bit_count_reg )
end

always@(*)
begin
    assume(led_data_reg >= 0);
    assume(bit_count_reg >= 0);
    assume(led_data_i >= 0);
end
`endif
endmodule
