// =====================================================
// Basys3 Traffic Light Controller (TOP + Controller)
// SW0: 1=System ON, 0=OFF
// SW1: 1=Automatic, 0=Manual
// BTN Center: Reset
// BTN Left:   Pause/Resume in Automatic
// BTN Right:  Step to next state in Manual
// LEDs: NS -> LED[2:0]  ( {R,Y,G} )
//       EW -> LED[15:13]( {R,Y,G} )
// 7-Seg (rightmost only) shows countdown 5→0 (0 holds 1s)
// =====================================================

module traffic_light_top(
    input         clk,          // 100 MHz (W5)
    input  [15:0] sw,           // sw[0]=enable, sw[1]=mode
    input         btnC,         // reset
    input         btnL,         // pause/resume (Auto)
    input         btnR,         // step (Manual)
    output [15:0] led,
    output [6:0]  seg,
    output [3:0]  an
);
    wire [2:0] ns_lights;
    wire [2:0] ew_lights;

    traffic_light_controller u_ctrl (
        .clk        (clk),
        .reset      (btnC),
        .enable_sw  (sw[0]),
        .mode_switch(sw[1]),
        .pause_btn  (btnL),
        .step_btn   (btnR),
        .ns_lights  (ns_lights),
        .ew_lights  (ew_lights),
        .seg        (seg),
        .an         (an)
    );

    // Map LEDs as requested
    assign led[2:0]    = ns_lights;  // LED0..2 = NS {R,Y,G}
    assign led[15:13]  = ew_lights;  // LED13..15 = EW {R,Y,G}
    assign led[12:3]   = 10'b0;      // others off
endmodule


// =====================================================
// Controller
// =====================================================
module traffic_light_controller(
    input  clk,               // 100MHz clock
    input  reset,             // BTN Center: reset
    input  enable_sw,         // SW0: 1=ON, 0=OFF
    input  mode_switch,       // SW1: 1=Automatic, 0=Manual
    input  pause_btn,         // BTN Left: pause/resume in Automatic
    input  step_btn,          // BTN Right: advance state in Manual
    output reg [2:0] ns_lights, // North-South: {Red, Yellow, Green}
    output reg [2:0] ew_lights, // East-West:   {Red, Yellow, Green}
    output reg [6:0] seg,       // 7-segment display (common anode, active-low)
    output reg [3:0] an         // Anode control (active-low)
);

    // State definitions
    localparam NS_GREEN_EW_RED  = 3'b000;
    localparam NS_YELLOW_EW_RED = 3'b001;
    localparam NS_RED_EW_GREEN  = 3'b010;
    localparam NS_RED_EW_YELLOW = 3'b011;
    localparam INITIAL_STATE    = 3'b100;

    // Timing parameters (seconds)
    localparam CLK_FREQ    = 100_000_000;
    localparam RED_TIME    = 5;
    localparam YELLOW_TIME = 1;
    localparam GREEN_TIME  = 5;

    reg  [2:0]  state, next_state;
    reg  [31:0] counter;          // counts clock cycles within a state
    reg  [31:0] time_limit;       // cycles till state change ( (secs+1)*CLK )
    reg  [3:0]  display_count;    // seconds remaining for 7-seg

    // 1 Hz tick generator
    reg  [31:0] sec_div;
    wire        sec_tick = (sec_div == CLK_FREQ-1);

    // Button sync and edge detection
    reg pause_s1, pause_s2, pause_prev;
    reg step_s1,  step_s2,  step_prev;
    reg rst_s1,   rst_s2;

    wire pause_pressed =  pause_s2 && !pause_prev;
    wire step_pressed  =  step_s2  && !step_prev;

    reg paused;

    // Synchronize inputs (metastability protection)
    always @(posedge clk) begin
        pause_s1  <= pause_btn;
        pause_s2  <= pause_s1;
        pause_prev<= pause_s2;

        step_s1   <= step_btn;
        step_s2   <= step_s1;
        step_prev <= step_s2;

        rst_s1    <= reset;
        rst_s2    <= rst_s1;
    end

    // Pause toggle in Automatic mode
    always @(posedge clk or posedge rst_s2) begin
        if (rst_s2)
            paused <= 1'b0;
        else if (enable_sw && mode_switch && pause_pressed)
            paused <= ~paused;
    end

    // Next-state and time limit (add +1s so '0' is visible for 1s)
    always @(*) begin
        case (state)
            INITIAL_STATE: begin
                next_state = NS_GREEN_EW_RED;
                time_limit = (RED_TIME    + 1) * CLK_FREQ;
            end
            NS_GREEN_EW_RED: begin
                next_state = NS_YELLOW_EW_RED;
                time_limit = (GREEN_TIME  + 1) * CLK_FREQ;
            end
            NS_YELLOW_EW_RED: begin
                next_state = NS_RED_EW_GREEN;
                time_limit = (YELLOW_TIME + 1) * CLK_FREQ;
            end
            NS_RED_EW_GREEN: begin
                next_state = NS_RED_EW_YELLOW;
                time_limit = (GREEN_TIME  + 1) * CLK_FREQ;
            end
            NS_RED_EW_YELLOW: begin
                next_state = NS_GREEN_EW_RED;
                time_limit = (YELLOW_TIME + 1) * CLK_FREQ;
            end
            default: begin
                next_state = INITIAL_STATE;
                time_limit = (RED_TIME    + 1) * CLK_FREQ;
            end
        endcase
    end

    // State machine & timers
    always @(posedge clk or posedge rst_s2) begin
        if (rst_s2) begin
            state         <= INITIAL_STATE;
            counter       <= 32'd0;
            display_count <= RED_TIME; // 5→0 visible
            sec_div       <= 32'd0;
        end else if (!enable_sw) begin
            // System OFF: safe all-red
            state         <= INITIAL_STATE;
            counter       <= 32'd0;
            display_count <= 4'd0;
            sec_div       <= 32'd0;
        end else if (mode_switch) begin
            // Automatic
            if (!paused) begin
                // 1 Hz tick
                if (sec_tick) sec_div <= 32'd0;
                else          sec_div <= sec_div + 1'b1;

                // run state timer
                if (counter >= time_limit - 1) begin
                    // after showing '0' for 1s, advance
                    state   <= next_state;
                    counter <= 32'd0;
                    sec_div <= 32'd0;

                    // load next state's countdown
                    case (next_state)
                        NS_GREEN_EW_RED:   display_count <= GREEN_TIME;
                        NS_YELLOW_EW_RED:  display_count <= YELLOW_TIME;
                        NS_RED_EW_GREEN:   display_count <= GREEN_TIME;
                        NS_RED_EW_YELLOW:  display_count <= YELLOW_TIME;
                        default:           display_count <= RED_TIME;
                    endcase
                end else begin
                    counter <= counter + 1;
                    if (sec_tick && display_count != 0)
                        display_count <= display_count - 1'b1;
                end
            end
        end else begin
            // Manual: step through with BTN Right
            sec_div <= 32'd0;
            counter <= 32'd0;
            if (step_pressed) begin
                state <= next_state;
                case (next_state)
                    NS_GREEN_EW_RED:   display_count <= GREEN_TIME;
                    NS_YELLOW_EW_RED:  display_count <= YELLOW_TIME;
                    NS_RED_EW_GREEN:   display_count <= GREEN_TIME;
                    NS_RED_EW_YELLOW:  display_count <= YELLOW_TIME;
                    default:           display_count <= RED_TIME;
                endcase
            end
        end
    end

    // Lights
    always @(*) begin
        if (!enable_sw) begin
            ns_lights = 3'b100; // all red
            ew_lights = 3'b100;
        end else begin
            case (state)
                INITIAL_STATE:     begin ns_lights = 3'b100; ew_lights = 3'b100; end
                NS_GREEN_EW_RED:   begin ns_lights = 3'b001; ew_lights = 3'b100; end
                NS_YELLOW_EW_RED:  begin ns_lights = 3'b010; ew_lights = 3'b100; end
                NS_RED_EW_GREEN:   begin ns_lights = 3'b100; ew_lights = 3'b001; end
                NS_RED_EW_YELLOW:  begin ns_lights = 3'b100; ew_lights = 3'b010; end
                default:           begin ns_lights = 3'b100; ew_lights = 3'b100; end
            endcase
        end
    end

    // 7-seg (enable only rightmost digit)
    always @(*) begin
        an = 4'b1110; // active-low anodes; rightmost digit ON
        if (enable_sw && mode_switch) begin
            case (display_count)
                4'd0: seg = 7'b1000000;  // 0
                4'd1: seg = 7'b1111001;  // 1
                4'd2: seg = 7'b0100100;  // 2
                4'd3: seg = 7'b0110000;  // 3
                4'd4: seg = 7'b0011001;  // 4
                4'd5: seg = 7'b0010010;  // 5
                4'd6: seg = 7'b0000010;  // 6
                4'd7: seg = 7'b1111000;  // 7
                4'd8: seg = 7'b0000000;  // 8
                4'd9: seg = 7'b0010000;  // 9
                default: seg = 7'b1111111; // off
            endcase
        end else begin
            seg = 7'b1111111; // off in Manual or when disabled
        end
    end

endmodule
