`timescale 1ns/1ps

module cdc_request_capture #(
    parameter int WIDTH = 1,
    parameter int STABLE_CYCLES = 2
)(
    input  logic clk,
    input  logic rst,

    input  logic req_async,
    input  logic [WIDTH-1:0] data_async,
    input  logic accept_enable,

    output logic pending,
    output logic ack_out,
    output logic event_pulse,
    output logic [WIDTH-1:0] data_out
);

    localparam int CW =
        (STABLE_CYCLES <= 1) ?
        1 :
        $clog2(STABLE_CYCLES + 1);

    typedef enum logic {
        WAIT_REQUEST,
        WAIT_RELEASE
    } capture_state_t;

    capture_state_t state;

    logic req_meta;
    logic req_sync;

    logic [WIDTH-1:0] data_meta;
    logic [WIDTH-1:0] data_sync;
    logic [WIDTH-1:0] previous_sample;

    logic [CW-1:0] stable_count;
    logic [CW-1:0] release_count;

    always_comb begin
        pending =
            (state == WAIT_REQUEST) &&
            req_sync;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state           <= WAIT_REQUEST;
            req_meta        <= 1'b0;
            req_sync        <= 1'b0;
            data_meta       <= '0;
            data_sync       <= '0;
            previous_sample <= '0;
            stable_count    <= '0;
            release_count   <= '0;
            ack_out         <= 1'b0;
            event_pulse     <= 1'b0;
            data_out        <= '0;
        end else begin
            req_meta  <= req_async;
            req_sync  <= req_meta;
            data_meta <= data_async;
            data_sync <= data_meta;

            event_pulse <= 1'b0;

            case (state)

                WAIT_REQUEST: begin
                    ack_out       <= 1'b0;
                    release_count <= '0;

                    if (!req_sync || !accept_enable) begin
                        stable_count    <= '0;
                        previous_sample <= data_sync;
                    end else if (STABLE_CYCLES <= 1) begin
                        data_out        <= data_sync;
                        event_pulse     <= 1'b1;
                        ack_out         <= 1'b1;
                        stable_count    <= '0;
                        previous_sample <= data_sync;
                        state           <= WAIT_RELEASE;
                    end else if (
                        data_sync != previous_sample
                    ) begin
                        previous_sample <= data_sync;
                        stable_count    <= 1;
                    end else if (
                        stable_count >= STABLE_CYCLES - 1
                    ) begin
                        data_out    <= data_sync;
                        event_pulse <= 1'b1;
                        ack_out     <= 1'b1;
                        stable_count <= '0;
                        state       <= WAIT_RELEASE;
                    end else begin
                        stable_count <=
                            stable_count + 1'b1;
                    end
                end

                WAIT_RELEASE: begin
                    ack_out      <= 1'b1;
                    stable_count <= '0;

                    if (req_sync) begin
                        release_count <= '0;
                    end else if (STABLE_CYCLES <= 1) begin
                        ack_out       <= 1'b0;
                        release_count <= '0;
                        state         <= WAIT_REQUEST;
                    end else if (
                        release_count >= STABLE_CYCLES - 1
                    ) begin
                        ack_out       <= 1'b0;
                        release_count <= '0;
                        state         <= WAIT_REQUEST;
                    end else begin
                        release_count <=
                            release_count + 1'b1;
                    end
                end

                default: begin
                    state         <= WAIT_REQUEST;
                    ack_out       <= 1'b0;
                    event_pulse   <= 1'b0;
                    stable_count  <= '0;
                    release_count <= '0;
                end

            endcase
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (WIDTH > 0)
            else $fatal("WIDTH must be greater than zero");

        assert (STABLE_CYCLES > 0)
            else $fatal("STABLE_CYCLES must be greater than zero");
    end
`endif

endmodule


module level_synchronizer(
    input  logic clk,
    input  logic rst,
    input  logic async_in,
    output logic sync_out
);

    logic sync_meta;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sync_meta <= 1'b0;
            sync_out  <= 1'b0;
        end else begin
            sync_meta <= async_in;
            sync_out  <= sync_meta;
        end
    end

endmodule


module fare_calculation #(
    parameter int NUM_STATIONS = 10,
    parameter int BASE_FARE = 20,
    parameter int PER_STATION_FARE = 5
)(
    input  logic [3:0] source_station,
    input  logic [3:0] destination_station,

    output logic [3:0] distance,
    output logic [15:0] fare_amount,
    output logic valid_route
);

    logic [63:0] calculated_fare;
    logic [63:0] base_fare_wide;
    logic [63:0] per_station_fare_wide;
    logic [63:0] distance_wide;

    always_comb begin
        valid_route =
            (source_station < NUM_STATIONS) &&
            (destination_station < NUM_STATIONS) &&
            (source_station != destination_station);

        if (destination_station >= source_station)
            distance =
                destination_station -
                source_station;
        else
            distance =
                source_station -
                destination_station;

        base_fare_wide = {
            32'd0,
            $unsigned(BASE_FARE)
        };

        per_station_fare_wide = {
            32'd0,
            $unsigned(PER_STATION_FARE)
        };

        distance_wide = {
            60'd0,
            distance
        };

        calculated_fare =
            base_fare_wide +
            distance_wide *
            per_station_fare_wide;

        if (!valid_route)
            fare_amount = 16'd0;
        else if (
            calculated_fare >
            64'd65535
        )
            fare_amount = 16'hFFFF;
        else
            fare_amount = calculated_fare[15:0];
    end

`ifndef SYNTHESIS
    initial begin
        assert (NUM_STATIONS > 1)
            else $fatal("NUM_STATIONS must be greater than one");

        assert (NUM_STATIONS <= 16)
            else $fatal("NUM_STATIONS must fit in 4 bits");

        assert (BASE_FARE >= 0)
            else $fatal("BASE_FARE cannot be negative");

        assert (PER_STATION_FARE >= 0)
            else $fatal("PER_STATION_FARE cannot be negative");
    end
`endif

endmodule


module timebase_generator #(
    parameter int CLOCKS_PER_TICK = 10
)(
    input  logic clk,
    input  logic rst,
    output logic time_tick
);

    logic [31:0] tick_counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tick_counter <= 32'd0;
            time_tick    <= 1'b0;
        end else begin
            time_tick <= 1'b0;

            if (CLOCKS_PER_TICK <= 1) begin
                tick_counter <= 32'd0;
                time_tick    <= 1'b1;
            end else if (
                tick_counter >= CLOCKS_PER_TICK - 1
            ) begin
                tick_counter <= 32'd0;
                time_tick    <= 1'b1;
            end else begin
                tick_counter <=
                    tick_counter + 1'b1;
            end
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (CLOCKS_PER_TICK > 0)
            else $fatal("CLOCKS_PER_TICK must be greater than zero");
    end
`endif

endmodule


module payment_controller(
    input  logic clk,
    input  logic rst,

    input  logic new_transaction,
    input  logic clear_transaction,

    input  logic cash_enable,
    input  logic cash_insert_event,
    input  logic cash_reject_event,

    input  logic [9:0] captured_note_value,
    input  logic captured_note_valid,
    input  logic note_storage_available,

    input  logic [15:0] fare_amount,

    output logic [15:0] paid_amount,
    output logic payment_ok,
    output logic [15:0] change_amount,

    output logic fake_note_detected,

    output logic accepted_note_pulse,
    output logic [9:0] accepted_note_value,

    output logic rejected_note_pulse,
    output logic invalid_note_pulse,
    output logic storage_reject_pulse,

    output logic [7:0] rejected_note_count
);

    logic [16:0] candidate_paid_amount;

    function automatic logic valid_denomination(
        input logic [9:0] value
    );
        begin
            valid_denomination =
                (value == 10'd10)  ||
                (value == 10'd20)  ||
                (value == 10'd50)  ||
                (value == 10'd100) ||
                (value == 10'd200) ||
                (value == 10'd500);
        end
    endfunction

    always_comb begin
        candidate_paid_amount =
            {1'b0, paid_amount} +
            captured_note_value;

        payment_ok =
            (fare_amount != 16'd0) &&
            (paid_amount >= fare_amount);

        if (payment_ok)
            change_amount =
                paid_amount -
                fare_amount;
        else
            change_amount = 16'd0;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            paid_amount          <= 16'd0;
            fake_note_detected   <= 1'b0;
            accepted_note_pulse  <= 1'b0;
            accepted_note_value  <= 10'd0;
            rejected_note_pulse  <= 1'b0;
            invalid_note_pulse   <= 1'b0;
            storage_reject_pulse <= 1'b0;
            rejected_note_count  <= 8'd0;
        end else begin
            accepted_note_pulse  <= 1'b0;
            rejected_note_pulse  <= 1'b0;
            invalid_note_pulse   <= 1'b0;
            storage_reject_pulse <= 1'b0;

            if (new_transaction) begin
                paid_amount         <= 16'd0;
                fake_note_detected  <= 1'b0;
                accepted_note_value <= 10'd0;
                rejected_note_count <= 8'd0;
            end else if (clear_transaction) begin
                paid_amount         <= 16'd0;
                fake_note_detected  <= 1'b0;
                accepted_note_value <= 10'd0;
            end else if (cash_reject_event) begin
                rejected_note_pulse <= 1'b1;

                if (rejected_note_count != 8'hFF)
                    rejected_note_count <=
                        rejected_note_count + 1'b1;
            end else if (
                cash_enable &&
                !payment_ok &&
                cash_insert_event
            ) begin
                if (
                    !captured_note_valid ||
                    !valid_denomination(
                        captured_note_value
                    )
                ) begin
                    fake_note_detected  <= 1'b1;
                    rejected_note_pulse <= 1'b1;
                    invalid_note_pulse  <= 1'b1;

                    if (
                        rejected_note_count !=
                        8'hFF
                    )
                        rejected_note_count <=
                            rejected_note_count +
                            1'b1;
                end else if (
                    !note_storage_available ||
                    candidate_paid_amount[16]
                ) begin
                    rejected_note_pulse  <= 1'b1;
                    storage_reject_pulse <= 1'b1;

                    if (
                        rejected_note_count !=
                        8'hFF
                    )
                        rejected_note_count <=
                            rejected_note_count +
                            1'b1;
                end else begin
                    paid_amount <=
                        candidate_paid_amount[15:0];

                    accepted_note_value <=
                        captured_note_value;

                    accepted_note_pulse <= 1'b1;
                    fake_note_detected  <= 1'b0;
                end
            end
        end
    end

endmodule


module sequential_change_planner #(
    parameter int MAX_AMOUNT = 500
)(
    input  logic clk,
    input  logic rst,

    input  logic start,
    input  logic abort_plan,

    input  logic [15:0] requested_amount,

    input  logic [15:0] available_5,
    input  logic [15:0] available_10,
    input  logic [15:0] available_20,
    input  logic [15:0] available_50,
    input  logic [15:0] available_100,
    input  logic [15:0] available_200,
    input  logic [15:0] available_500,

    output logic busy,
    output logic done,
    output logic possible,

    output logic [15:0] use_5,
    output logic [15:0] use_10,
    output logic [15:0] use_20,
    output logic [15:0] use_50,
    output logic [15:0] use_100,
    output logic [15:0] use_200,
    output logic [15:0] use_500
);

    localparam int MAX_UNITS = MAX_AMOUNT / 5;
    localparam int RAW_AW = $clog2(MAX_UNITS + 1);
    localparam int AW = (RAW_AW < 7) ? 7 : RAW_AW;

    typedef enum logic [3:0] {
        P_IDLE,
        P_CLEAR,
        P_PREPARE_COIN,
        P_SCAN_AMOUNT,
        P_CHECK_RESULT,
        P_RECONSTRUCT,
        P_DONE
    } planner_state_t;

    planner_state_t pstate;

    logic reachable [0:MAX_UNITS];
    logic [AW-1:0] previous_amount [0:MAX_UNITS];
    logic [2:0] previous_denom [0:MAX_UNITS];
    logic [15:0] available_mem [0:6];

    logic [AW-1:0] clear_index;
    logic [AW-1:0] target_units;
    logic [AW-1:0] scan_index;
    logic [AW-1:0] reconstruct_index;

    logic [2:0] denom_index;
    logic [15:0] coin_iteration;

    logic [AW-1:0] denomination_units;
    logic [15:0] denomination_available;
    logic [15:0] useful_coin_limit;

    logic start_d;
    integer reset_index;

    always_comb begin
        case (denom_index)
            3'd0: denomination_units = 100;
            3'd1: denomination_units = 40;
            3'd2: denomination_units = 20;
            3'd3: denomination_units = 10;
            3'd4: denomination_units = 4;
            3'd5: denomination_units = 2;
            default: denomination_units = 1;
        endcase

        denomination_available = available_mem[denom_index];

        case (denom_index)
            3'd0: useful_coin_limit = target_units / 100;
            3'd1: useful_coin_limit = target_units / 40;
            3'd2: useful_coin_limit = target_units / 20;
            3'd3: useful_coin_limit = target_units / 10;
            3'd4: useful_coin_limit = target_units / 4;
            3'd5: useful_coin_limit = target_units / 2;
            default: useful_coin_limit = target_units;
        endcase

        if (useful_coin_limit > denomination_available)
            useful_coin_limit = denomination_available;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pstate            <= P_IDLE;
            start_d           <= 1'b0;
            clear_index       <= '0;
            target_units      <= '0;
            scan_index        <= '0;
            reconstruct_index <= '0;
            denom_index       <= 3'd0;
            coin_iteration    <= 16'd0;

            busy     <= 1'b0;
            done     <= 1'b0;
            possible <= 1'b0;

            use_5   <= 16'd0;
            use_10  <= 16'd0;
            use_20  <= 16'd0;
            use_50  <= 16'd0;
            use_100 <= 16'd0;
            use_200 <= 16'd0;
            use_500 <= 16'd0;

            for (reset_index = 0;
                 reset_index <= MAX_UNITS;
                 reset_index = reset_index + 1) begin
                reachable[reset_index] <= 1'b0;
                previous_amount[reset_index] <= '0;
                previous_denom[reset_index] <= 3'd0;
            end

            for (reset_index = 0;
                 reset_index < 7;
                 reset_index = reset_index + 1)
                available_mem[reset_index] <= 16'd0;
        end else begin
            start_d <= start;
            done <= 1'b0;

            if (abort_plan) begin
                pstate            <= P_IDLE;
                busy              <= 1'b0;
                possible          <= 1'b0;
                clear_index       <= '0;
                target_units      <= '0;
                scan_index        <= '0;
                reconstruct_index <= '0;
                denom_index       <= 3'd0;
                coin_iteration    <= 16'd0;
            end else begin
                case (pstate)
                    P_IDLE: begin
                        busy <= 1'b0;

                        if (start && !start_d) begin
                            busy <= 1'b1;
                            possible <= 1'b0;

                            use_5   <= 16'd0;
                            use_10  <= 16'd0;
                            use_20  <= 16'd0;
                            use_50  <= 16'd0;
                            use_100 <= 16'd0;
                            use_200 <= 16'd0;
                            use_500 <= 16'd0;

                            target_units <= requested_amount / 5;
                            clear_index <= '0;
                            denom_index <= 3'd0;
                            coin_iteration <= 16'd0;

                            available_mem[0] <= available_500;
                            available_mem[1] <= available_200;
                            available_mem[2] <= available_100;
                            available_mem[3] <= available_50;
                            available_mem[4] <= available_20;
                            available_mem[5] <= available_10;
                            available_mem[6] <= available_5;

                            if (requested_amount == 16'd0) begin
                                possible <= 1'b1;
                                pstate <= P_DONE;
                            end else if (
                                requested_amount > MAX_AMOUNT ||
                                (requested_amount % 5) != 0
                            ) begin
                                possible <= 1'b0;
                                pstate <= P_DONE;
                            end else begin
                                pstate <= P_CLEAR;
                            end
                        end
                    end

                    P_CLEAR: begin
                        reachable[clear_index] <= 1'b0;
                        previous_amount[clear_index] <= '0;
                        previous_denom[clear_index] <= 3'd0;

                        if (clear_index == MAX_UNITS) begin
                            reachable[0] <= 1'b1;
                            denom_index <= 3'd0;
                            coin_iteration <= 16'd0;
                            pstate <= P_PREPARE_COIN;
                        end else begin
                            clear_index <= clear_index + 1'b1;
                        end
                    end

                    P_PREPARE_COIN: begin
                        if (coin_iteration < useful_coin_limit) begin
                            scan_index <= target_units;
                            pstate <= P_SCAN_AMOUNT;
                        end else if (denom_index == 3'd6) begin
                            pstate <= P_CHECK_RESULT;
                        end else begin
                            denom_index <= denom_index + 1'b1;
                            coin_iteration <= 16'd0;
                        end
                    end

                    P_SCAN_AMOUNT: begin
                        if (scan_index >= denomination_units) begin
                            if (
                                !reachable[scan_index] &&
                                reachable[scan_index - denomination_units]
                            ) begin
                                reachable[scan_index] <= 1'b1;
                                previous_amount[scan_index] <=
                                    scan_index - denomination_units;
                                previous_denom[scan_index] <= denom_index;
                            end

                            if (scan_index == denomination_units) begin
                                coin_iteration <= coin_iteration + 1'b1;
                                pstate <= P_PREPARE_COIN;
                            end else begin
                                scan_index <= scan_index - 1'b1;
                            end
                        end else begin
                            coin_iteration <= coin_iteration + 1'b1;
                            pstate <= P_PREPARE_COIN;
                        end
                    end

                    P_CHECK_RESULT: begin
                        if (reachable[target_units]) begin
                            possible <= 1'b1;
                            reconstruct_index <= target_units;
                            pstate <= P_RECONSTRUCT;
                        end else begin
                            possible <= 1'b0;
                            pstate <= P_DONE;
                        end
                    end

                    P_RECONSTRUCT: begin
                        if (reconstruct_index == 0) begin
                            pstate <= P_DONE;
                        end else begin
                            case (previous_denom[reconstruct_index])
                                3'd0: use_500 <= use_500 + 1'b1;
                                3'd1: use_200 <= use_200 + 1'b1;
                                3'd2: use_100 <= use_100 + 1'b1;
                                3'd3: use_50  <= use_50  + 1'b1;
                                3'd4: use_20  <= use_20  + 1'b1;
                                3'd5: use_10  <= use_10  + 1'b1;
                                default: use_5 <= use_5 + 1'b1;
                            endcase

                            reconstruct_index <=
                                previous_amount[reconstruct_index];
                        end
                    end

                    P_DONE: begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        pstate <= P_IDLE;
                    end

                    default: begin
                        pstate <= P_IDLE;
                        busy <= 1'b0;
                        possible <= 1'b0;
                    end
                endcase
            end
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (MAX_AMOUNT >= 5)
            else $fatal("MAX_AMOUNT must be at least five");

        assert ((MAX_AMOUNT % 5) == 0)
            else $fatal("MAX_AMOUNT must be divisible by five");

        assert (MAX_AMOUNT <= 65535)
            else $fatal("MAX_AMOUNT must fit in requested_amount");
    end
`endif

endmodule

module cash_inventory_controller #(
    parameter int RECYCLER_CAPACITY = 60,
    parameter int BOX_CAPACITY = 500,
    parameter int SAFE_BOX_THRESHOLD = 400,

    parameter int INIT_NOTE10 = 20,
    parameter int INIT_NOTE20 = 20,
    parameter int INIT_NOTE50 = 10,
    parameter int INIT_NOTE100 = 10,
    parameter int INIT_NOTE200 = 5,
    parameter int INIT_NOTE500 = 2,
    parameter int INIT_COIN5 = 100,

    parameter int MAX_CHANGE = 500,
    parameter int MAX_COMPENSATION = 500
)(
    input  logic clk,
    input  logic rst,

    input  logic new_transaction,
    input  logic clear_transaction,
    input  logic manual_settlement,

    input  logic accepted_note_pulse,
    input  logic [9:0] accepted_note_value,
    input  logic [9:0] candidate_note_value,

    input  logic start_change_plan,
    input  logic start_compensation_plan,
    input  logic abort_planners,

    input  logic [15:0] requested_change,
    input  logic [15:0] compensation_amount,

    input  logic dispense_change,
    input  logic commit_escrow,
    input  logic return_escrow,
    input  logic dispense_compensation,

    output logic note_storage_available,
    output logic escrow_commit_possible,
    output logic escrow_nonempty,
    output logic [15:0] escrow_value,

    output logic change_plan_busy,
    output logic change_plan_done,
    output logic change_possible,

    output logic compensation_plan_busy,
    output logic compensation_plan_done,
    output logic compensation_possible,

    output logic change_done,
    output logic change_failed,

    output logic commit_done,
    output logic commit_failed,

    output logic refund_done,

    output logic compensation_done,
    output logic compensation_failed,

    output logic [15:0] committed_amount,
    output logic [15:0] refund_amount,
    output logic [15:0] change_dispensed_amount,
    output logic [15:0] compensation_dispensed_amount,

    output logic [15:0] refund_10_count,
    output logic [15:0] refund_20_count,
    output logic [15:0] refund_50_count,
    output logic [15:0] refund_100_count,
    output logic [15:0] refund_200_count,
    output logic [15:0] refund_500_count,

    output logic [15:0] dispensed_5_count,
    output logic [15:0] dispensed_10_count,
    output logic [15:0] dispensed_20_count,
    output logic [15:0] dispensed_50_count,
    output logic [15:0] dispensed_100_count,
    output logic [15:0] dispensed_200_count,
    output logic [15:0] dispensed_500_count,

    output logic [15:0] compensation_5_count,
    output logic [15:0] compensation_10_count,
    output logic [15:0] compensation_20_count,
    output logic [15:0] compensation_50_count,
    output logic [15:0] compensation_100_count,
    output logic [15:0] compensation_200_count,
    output logic [15:0] compensation_500_count,

    output logic [16:0] rec1_count,
    output logic [16:0] rec2_count,
    output logic [16:0] rec3_count,

    output logic [9:0] collection_box1_count,
    output logic [9:0] collection_box2_count,

    output logic rec1_full,
    output logic rec2_full,
    output logic rec3_full,

    output logic collection_safe_warning,
    output logic collection_full,

    output logic [15:0] coin5_count,
    output logic [15:0] note10_count,
    output logic [15:0] note20_count,
    output logic [15:0] note50_count,
    output logic [15:0] note100_count,
    output logic [15:0] note200_count,
    output logic [15:0] note500_count
);

    logic [15:0] inv5;
    logic [15:0] inv10;
    logic [15:0] inv20;
    logic [15:0] inv50;
    logic [15:0] inv100;
    logic [15:0] inv200;
    logic [15:0] inv500;

    logic [15:0] escrow_10;
    logic [15:0] escrow_20;
    logic [15:0] escrow_50;
    logic [15:0] escrow_100;
    logic [15:0] escrow_200;
    logic [15:0] escrow_500;

    logic [16:0] rec1_sum;
    logic [16:0] rec2_sum;
    logic [16:0] rec3_sum;

    logic [16:0] refund_effective_10;
    logic [16:0] refund_effective_20;
    logic [16:0] refund_effective_50;
    logic [16:0] refund_effective_100;
    logic [16:0] refund_effective_200;
    logic [16:0] refund_effective_500;
    logic [31:0] refund_effective_value_wide;
    logic [15:0] refund_effective_value;
    logic return_escrow_pulse;

    logic dispense_change_d;
    logic commit_escrow_d;
    logic return_escrow_d;
    logic dispense_compensation_d;

    logic [15:0] change_use_5;
    logic [15:0] change_use_10;
    logic [15:0] change_use_20;
    logic [15:0] change_use_50;
    logic [15:0] change_use_100;
    logic [15:0] change_use_200;
    logic [15:0] change_use_500;

    logic [15:0] compensation_use_5;
    logic [15:0] compensation_use_10;
    logic [15:0] compensation_use_20;
    logic [15:0] compensation_use_50;
    logic [15:0] compensation_use_100;
    logic [15:0] compensation_use_200;
    logic [15:0] compensation_use_500;

    logic [15:0] planned_inv10;
    logic [15:0] planned_inv20;
    logic [15:0] planned_inv50;
    logic [15:0] planned_inv100;
    logic [15:0] planned_inv200;
    logic [15:0] planned_inv500;

    logic [9:0] planned_box1;
    logic [9:0] planned_box2;

    logic change_plan_valid;
    logic compensation_plan_valid;

    logic [31:0] escrow_value_wide;
    logic [31:0] change_plan_amount;
    logic [31:0] compensation_plan_amount;

    integer candidate_10;
    integer candidate_20;
    integer candidate_50;
    integer candidate_100;
    integer candidate_200;
    integer candidate_500;

    integer candidate_overflow;
    integer escrow_overflow;
    integer collection_free;

    integer free1;
    integer free2;
    integer free3;

    integer remaining;
    integer take_count;
    integer overflow_count;

    integer box1_space;
    integer box2_space;
    integer box1_add;
    integer box2_add;

    function automatic integer calculate_overflow(
        input integer c10,
        input integer c20,
        input integer c50,
        input integer c100,
        input integer c200,
        input integer c500
    );

        integer f1;
        integer f2;
        integer f3;

        integer rem;
        integer take;
        integer total;

        begin
            total = 0;

            f2 =
                RECYCLER_CAPACITY -
                (inv10 + inv20);

            if (f2 < 0)
                f2 = 0;

            rem = c10;
            take =
                (rem > f2) ?
                f2 :
                rem;

            rem = rem - take;
            f2  = f2 - take;
            total = total + rem;

            rem = c20;
            take =
                (rem > f2) ?
                f2 :
                rem;

            rem = rem - take;
            total = total + rem;

            f1 =
                RECYCLER_CAPACITY -
                (inv50 + inv100);

            if (f1 < 0)
                f1 = 0;

            rem = c50;
            take =
                (rem > f1) ?
                f1 :
                rem;

            rem = rem - take;
            f1  = f1 - take;
            total = total + rem;

            rem = c100;
            take =
                (rem > f1) ?
                f1 :
                rem;

            rem = rem - take;
            total = total + rem;

            f3 =
                RECYCLER_CAPACITY -
                (inv200 + inv500);

            if (f3 < 0)
                f3 = 0;

            rem = c200;
            take =
                (rem > f3) ?
                f3 :
                rem;

            rem = rem - take;
            f3  = f3 - take;
            total = total + rem;

            rem = c500;
            take =
                (rem > f3) ?
                f3 :
                rem;

            rem = rem - take;
            total = total + rem;

            calculate_overflow =
                total;
        end

    endfunction

    sequential_change_planner #(
        .MAX_AMOUNT(MAX_CHANGE)
    ) u_change_planner (
        .clk(clk),
        .rst(rst),

        .start(start_change_plan),
        .abort_plan(abort_planners),

        .requested_amount(
            requested_change
        ),

        .available_5(inv5),
        .available_10(inv10),
        .available_20(inv20),
        .available_50(inv50),
        .available_100(inv100),
        .available_200(inv200),
        .available_500(inv500),

        .busy(change_plan_busy),
        .done(change_plan_done),
        .possible(change_possible),

        .use_5(change_use_5),
        .use_10(change_use_10),
        .use_20(change_use_20),
        .use_50(change_use_50),
        .use_100(change_use_100),
        .use_200(change_use_200),
        .use_500(change_use_500)
    );

    sequential_change_planner #(
        .MAX_AMOUNT(MAX_COMPENSATION)
    ) u_compensation_planner (
        .clk(clk),
        .rst(rst),

        .start(
            start_compensation_plan
        ),

        .abort_plan(
            abort_planners
        ),

        .requested_amount(
            compensation_amount
        ),

        .available_5(inv5),
        .available_10(inv10),
        .available_20(inv20),
        .available_50(inv50),
        .available_100(inv100),
        .available_200(inv200),
        .available_500(inv500),

        .busy(
            compensation_plan_busy
        ),

        .done(
            compensation_plan_done
        ),

        .possible(
            compensation_possible
        ),

        .use_5(
            compensation_use_5
        ),

        .use_10(
            compensation_use_10
        ),

        .use_20(
            compensation_use_20
        ),

        .use_50(
            compensation_use_50
        ),

        .use_100(
            compensation_use_100
        ),

        .use_200(
            compensation_use_200
        ),

        .use_500(
            compensation_use_500
        )
    );

    always_comb begin
        candidate_10  = escrow_10;
        candidate_20  = escrow_20;
        candidate_50  = escrow_50;
        candidate_100 = escrow_100;
        candidate_200 = escrow_200;
        candidate_500 = escrow_500;

        case (candidate_note_value)
            10'd10:
                candidate_10 =
                    candidate_10 + 1;

            10'd20:
                candidate_20 =
                    candidate_20 + 1;

            10'd50:
                candidate_50 =
                    candidate_50 + 1;

            10'd100:
                candidate_100 =
                    candidate_100 + 1;

            10'd200:
                candidate_200 =
                    candidate_200 + 1;

            10'd500:
                candidate_500 =
                    candidate_500 + 1;

            default: begin
            end
        endcase

        candidate_overflow =
            calculate_overflow(
                candidate_10,
                candidate_20,
                candidate_50,
                candidate_100,
                candidate_200,
                candidate_500
            );

        escrow_overflow =
            calculate_overflow(
                escrow_10,
                escrow_20,
                escrow_50,
                escrow_100,
                escrow_200,
                escrow_500
            );

        collection_free =
            (2 * BOX_CAPACITY) -
            collection_box1_count -
            collection_box2_count;

        case (candidate_note_value)
            10'd10,
            10'd20,
            10'd50,
            10'd100,
            10'd200,
            10'd500:
                note_storage_available =
                    candidate_overflow <=
                    collection_free;

            default:
                note_storage_available =
                    1'b0;
        endcase

        escrow_commit_possible =
            escrow_overflow <=
            collection_free;

        escrow_nonempty =
            (escrow_10  != 0) ||
            (escrow_20  != 0) ||
            (escrow_50  != 0) ||
            (escrow_100 != 0) ||
            (escrow_200 != 0) ||
            (escrow_500 != 0);

        escrow_value_wide =
            (escrow_10  * 10)  +
            (escrow_20  * 20)  +
            (escrow_50  * 50)  +
            (escrow_100 * 100) +
            (escrow_200 * 200) +
            (escrow_500 * 500);

        if (escrow_value_wide > 16'hFFFF)
            escrow_value = 16'hFFFF;
        else
            escrow_value =
                escrow_value_wide[15:0];
    end

    always_comb begin
        return_escrow_pulse =
            return_escrow &&
            !return_escrow_d;

        refund_effective_10 =
            {1'b0, escrow_10} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd10) ?
             17'd1 : 17'd0);

        refund_effective_20 =
            {1'b0, escrow_20} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd20) ?
             17'd1 : 17'd0);

        refund_effective_50 =
            {1'b0, escrow_50} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd50) ?
             17'd1 : 17'd0);

        refund_effective_100 =
            {1'b0, escrow_100} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd100) ?
             17'd1 : 17'd0);

        refund_effective_200 =
            {1'b0, escrow_200} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd200) ?
             17'd1 : 17'd0);

        refund_effective_500 =
            {1'b0, escrow_500} +
            ((accepted_note_pulse &&
              accepted_note_value == 10'd500) ?
             17'd1 : 17'd0);

        refund_effective_value_wide =
            (refund_effective_10  * 10)  +
            (refund_effective_20  * 20)  +
            (refund_effective_50  * 50)  +
            (refund_effective_100 * 100) +
            (refund_effective_200 * 200) +
            (refund_effective_500 * 500);

        if (
            refund_effective_value_wide >
            32'd65535
        )
            refund_effective_value =
                16'hFFFF;
        else
            refund_effective_value =
                refund_effective_value_wide[15:0];
    end

    always_comb begin
        planned_inv10  = inv10;
        planned_inv20  = inv20;
        planned_inv50  = inv50;
        planned_inv100 = inv100;
        planned_inv200 = inv200;
        planned_inv500 = inv500;

        planned_box1 =
            collection_box1_count;

        planned_box2 =
            collection_box2_count;

        overflow_count = 0;

        free2 =
            RECYCLER_CAPACITY -
            (inv10 + inv20);

        if (free2 < 0)
            free2 = 0;

        remaining = escrow_10;

        take_count =
            (remaining > free2) ?
            free2 :
            remaining;

        planned_inv10 =
            inv10 + take_count;

        remaining =
            remaining -
            take_count;

        free2 =
            free2 -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        remaining = escrow_20;

        take_count =
            (remaining > free2) ?
            free2 :
            remaining;

        planned_inv20 =
            inv20 + take_count;

        remaining =
            remaining -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        free1 =
            RECYCLER_CAPACITY -
            (inv50 + inv100);

        if (free1 < 0)
            free1 = 0;

        remaining = escrow_50;

        take_count =
            (remaining > free1) ?
            free1 :
            remaining;

        planned_inv50 =
            inv50 + take_count;

        remaining =
            remaining -
            take_count;

        free1 =
            free1 -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        remaining = escrow_100;

        take_count =
            (remaining > free1) ?
            free1 :
            remaining;

        planned_inv100 =
            inv100 + take_count;

        remaining =
            remaining -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        free3 =
            RECYCLER_CAPACITY -
            (inv200 + inv500);

        if (free3 < 0)
            free3 = 0;

        remaining = escrow_200;

        take_count =
            (remaining > free3) ?
            free3 :
            remaining;

        planned_inv200 =
            inv200 + take_count;

        remaining =
            remaining -
            take_count;

        free3 =
            free3 -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        remaining = escrow_500;

        take_count =
            (remaining > free3) ?
            free3 :
            remaining;

        planned_inv500 =
            inv500 + take_count;

        remaining =
            remaining -
            take_count;

        overflow_count =
            overflow_count +
            remaining;

        box1_space =
            BOX_CAPACITY -
            collection_box1_count;

        box2_space =
            BOX_CAPACITY -
            collection_box2_count;

        box1_add =
            (overflow_count > box1_space) ?
            box1_space :
            overflow_count;

        overflow_count =
            overflow_count -
            box1_add;

        box2_add =
            (overflow_count > box2_space) ?
            box2_space :
            overflow_count;

        planned_box1 =
            collection_box1_count +
            box1_add;

        planned_box2 =
            collection_box2_count +
            box2_add;
    end

    always_comb begin
        change_plan_amount =
            (change_use_5   * 5)   +
            (change_use_10  * 10)  +
            (change_use_20  * 20)  +
            (change_use_50  * 50)  +
            (change_use_100 * 100) +
            (change_use_200 * 200) +
            (change_use_500 * 500);

        compensation_plan_amount =
            (compensation_use_5   * 5)   +
            (compensation_use_10  * 10)  +
            (compensation_use_20  * 20)  +
            (compensation_use_50  * 50)  +
            (compensation_use_100 * 100) +
            (compensation_use_200 * 200) +
            (compensation_use_500 * 500);

        change_plan_valid =
            change_possible &&
            (change_use_5   <= inv5)   &&
            (change_use_10  <= inv10)  &&
            (change_use_20  <= inv20)  &&
            (change_use_50  <= inv50)  &&
            (change_use_100 <= inv100) &&
            (change_use_200 <= inv200) &&
            (change_use_500 <= inv500) &&
            (
                change_plan_amount ==
                requested_change
            );

        compensation_plan_valid =
            compensation_possible &&
            (compensation_use_5   <= inv5)   &&
            (compensation_use_10  <= inv10)  &&
            (compensation_use_20  <= inv20)  &&
            (compensation_use_50  <= inv50)  &&
            (compensation_use_100 <= inv100) &&
            (compensation_use_200 <= inv200) &&
            (compensation_use_500 <= inv500) &&
            (
                compensation_plan_amount ==
                compensation_amount
            );
    end

    always_comb begin
        rec1_sum =
            {1'b0, inv50} +
            {1'b0, inv100};

        rec2_sum =
            {1'b0, inv10} +
            {1'b0, inv20};

        rec3_sum =
            {1'b0, inv200} +
            {1'b0, inv500};

        rec1_count = rec1_sum;
        rec2_count = rec2_sum;
        rec3_count = rec3_sum;

        rec1_full =
            rec1_sum >=
            $unsigned(RECYCLER_CAPACITY);

        rec2_full =
            rec2_sum >=
            $unsigned(RECYCLER_CAPACITY);

        rec3_full =
            rec3_sum >=
            $unsigned(RECYCLER_CAPACITY);

        collection_safe_warning =
            (collection_box1_count >=
             SAFE_BOX_THRESHOLD) ||
            (collection_box2_count >=
             SAFE_BOX_THRESHOLD);

        collection_full =
            (collection_box1_count >=
             BOX_CAPACITY) &&
            (collection_box2_count >=
             BOX_CAPACITY);

        coin5_count  = inv5;
        note10_count = inv10;
        note20_count = inv20;
        note50_count = inv50;
        note100_count = inv100;
        note200_count = inv200;
        note500_count = inv500;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            inv5   <= INIT_COIN5;
            inv10  <= INIT_NOTE10;
            inv20  <= INIT_NOTE20;
            inv50  <= INIT_NOTE50;
            inv100 <= INIT_NOTE100;
            inv200 <= INIT_NOTE200;
            inv500 <= INIT_NOTE500;

            collection_box1_count <= 10'd0;
            collection_box2_count <= 10'd0;

            escrow_10  <= 16'd0;
            escrow_20  <= 16'd0;
            escrow_50  <= 16'd0;
            escrow_100 <= 16'd0;
            escrow_200 <= 16'd0;
            escrow_500 <= 16'd0;

            dispense_change_d       <= 1'b0;
            commit_escrow_d         <= 1'b0;
            return_escrow_d         <= 1'b0;
            dispense_compensation_d <= 1'b0;

            change_done         <= 1'b0;
            change_failed       <= 1'b0;
            commit_done         <= 1'b0;
            commit_failed       <= 1'b0;
            refund_done         <= 1'b0;
            compensation_done   <= 1'b0;
            compensation_failed <= 1'b0;

            committed_amount <= 16'd0;
            refund_amount <= 16'd0;
            change_dispensed_amount <= 16'd0;
            compensation_dispensed_amount <=
                16'd0;

            refund_10_count  <= 16'd0;
            refund_20_count  <= 16'd0;
            refund_50_count  <= 16'd0;
            refund_100_count <= 16'd0;
            refund_200_count <= 16'd0;
            refund_500_count <= 16'd0;

            dispensed_5_count   <= 16'd0;
            dispensed_10_count  <= 16'd0;
            dispensed_20_count  <= 16'd0;
            dispensed_50_count  <= 16'd0;
            dispensed_100_count <= 16'd0;
            dispensed_200_count <= 16'd0;
            dispensed_500_count <= 16'd0;

            compensation_5_count   <= 16'd0;
            compensation_10_count  <= 16'd0;
            compensation_20_count  <= 16'd0;
            compensation_50_count  <= 16'd0;
            compensation_100_count <= 16'd0;
            compensation_200_count <= 16'd0;
            compensation_500_count <= 16'd0;
        end else begin
            dispense_change_d <=
                dispense_change;

            commit_escrow_d <=
                commit_escrow;

            return_escrow_d <=
                return_escrow;

            dispense_compensation_d <=
                dispense_compensation;

            change_done         <= 1'b0;
            change_failed       <= 1'b0;
            commit_done         <= 1'b0;
            commit_failed       <= 1'b0;
            refund_done         <= 1'b0;
            compensation_done   <= 1'b0;
            compensation_failed <= 1'b0;

            if (new_transaction) begin
                committed_amount <= 16'd0;
                refund_amount <= 16'd0;
                change_dispensed_amount <= 16'd0;
                compensation_dispensed_amount <=
                    16'd0;

                refund_10_count  <= 16'd0;
                refund_20_count  <= 16'd0;
                refund_50_count  <= 16'd0;
                refund_100_count <= 16'd0;
                refund_200_count <= 16'd0;
                refund_500_count <= 16'd0;

                dispensed_5_count   <= 16'd0;
                dispensed_10_count  <= 16'd0;
                dispensed_20_count  <= 16'd0;
                dispensed_50_count  <= 16'd0;
                dispensed_100_count <= 16'd0;
                dispensed_200_count <= 16'd0;
                dispensed_500_count <= 16'd0;

                compensation_5_count   <= 16'd0;
                compensation_10_count  <= 16'd0;
                compensation_20_count  <= 16'd0;
                compensation_50_count  <= 16'd0;
                compensation_100_count <= 16'd0;
                compensation_200_count <= 16'd0;
                compensation_500_count <= 16'd0;
            end

            if (clear_transaction) begin
                dispense_change_d       <= 1'b0;
                commit_escrow_d         <= 1'b0;
                return_escrow_d         <= 1'b0;
                dispense_compensation_d <= 1'b0;
            end

            if (manual_settlement) begin
                escrow_10  <= 16'd0;
                escrow_20  <= 16'd0;
                escrow_50  <= 16'd0;
                escrow_100 <= 16'd0;
                escrow_200 <= 16'd0;
                escrow_500 <= 16'd0;
            end

            if (
                accepted_note_pulse &&
                !return_escrow_pulse
            ) begin
                case (accepted_note_value)
                    10'd10:
                        escrow_10 <=
                            escrow_10 + 1'b1;

                    10'd20:
                        escrow_20 <=
                            escrow_20 + 1'b1;

                    10'd50:
                        escrow_50 <=
                            escrow_50 + 1'b1;

                    10'd100:
                        escrow_100 <=
                            escrow_100 + 1'b1;

                    10'd200:
                        escrow_200 <=
                            escrow_200 + 1'b1;

                    10'd500:
                        escrow_500 <=
                            escrow_500 + 1'b1;

                    default: begin
                    end
                endcase
            end

            if (
                commit_escrow &&
                !commit_escrow_d
            ) begin
                if (
                    escrow_commit_possible
                ) begin
                    committed_amount <=
                        escrow_value;

                    inv10  <= planned_inv10;
                    inv20  <= planned_inv20;
                    inv50  <= planned_inv50;
                    inv100 <= planned_inv100;
                    inv200 <= planned_inv200;
                    inv500 <= planned_inv500;

                    collection_box1_count <=
                        planned_box1;

                    collection_box2_count <=
                        planned_box2;

                    escrow_10  <= 16'd0;
                    escrow_20  <= 16'd0;
                    escrow_50  <= 16'd0;
                    escrow_100 <= 16'd0;
                    escrow_200 <= 16'd0;
                    escrow_500 <= 16'd0;

                    commit_done <= 1'b1;
                end else begin
                    commit_failed <= 1'b1;
                end
            end

            if (
                dispense_change &&
                !dispense_change_d
            ) begin
                if (change_plan_valid) begin
                    inv5 <=
                        inv5 -
                        change_use_5;

                    inv10 <=
                        inv10 -
                        change_use_10;

                    inv20 <=
                        inv20 -
                        change_use_20;

                    inv50 <=
                        inv50 -
                        change_use_50;

                    inv100 <=
                        inv100 -
                        change_use_100;

                    inv200 <=
                        inv200 -
                        change_use_200;

                    inv500 <=
                        inv500 -
                        change_use_500;

                    dispensed_5_count <=
                        change_use_5;

                    dispensed_10_count <=
                        change_use_10;

                    dispensed_20_count <=
                        change_use_20;

                    dispensed_50_count <=
                        change_use_50;

                    dispensed_100_count <=
                        change_use_100;

                    dispensed_200_count <=
                        change_use_200;

                    dispensed_500_count <=
                        change_use_500;

                    change_dispensed_amount <=
                        requested_change;

                    change_done <= 1'b1;
                end else begin
                    change_failed <= 1'b1;
                end
            end

            if (return_escrow_pulse) begin
                refund_10_count <=
                    refund_effective_10[16] ?
                    16'hFFFF :
                    refund_effective_10[15:0];

                refund_20_count <=
                    refund_effective_20[16] ?
                    16'hFFFF :
                    refund_effective_20[15:0];

                refund_50_count <=
                    refund_effective_50[16] ?
                    16'hFFFF :
                    refund_effective_50[15:0];

                refund_100_count <=
                    refund_effective_100[16] ?
                    16'hFFFF :
                    refund_effective_100[15:0];

                refund_200_count <=
                    refund_effective_200[16] ?
                    16'hFFFF :
                    refund_effective_200[15:0];

                refund_500_count <=
                    refund_effective_500[16] ?
                    16'hFFFF :
                    refund_effective_500[15:0];

                refund_amount <=
                    refund_effective_value;

                escrow_10  <= 16'd0;
                escrow_20  <= 16'd0;
                escrow_50  <= 16'd0;
                escrow_100 <= 16'd0;
                escrow_200 <= 16'd0;
                escrow_500 <= 16'd0;

                refund_done <= 1'b1;
            end

            if (
                dispense_compensation &&
                !dispense_compensation_d
            ) begin
                if (
                    compensation_plan_valid
                ) begin
                    inv5 <=
                        inv5 -
                        compensation_use_5;

                    inv10 <=
                        inv10 -
                        compensation_use_10;

                    inv20 <=
                        inv20 -
                        compensation_use_20;

                    inv50 <=
                        inv50 -
                        compensation_use_50;

                    inv100 <=
                        inv100 -
                        compensation_use_100;

                    inv200 <=
                        inv200 -
                        compensation_use_200;

                    inv500 <=
                        inv500 -
                        compensation_use_500;

                    compensation_5_count <=
                        compensation_use_5;

                    compensation_10_count <=
                        compensation_use_10;

                    compensation_20_count <=
                        compensation_use_20;

                    compensation_50_count <=
                        compensation_use_50;

                    compensation_100_count <=
                        compensation_use_100;

                    compensation_200_count <=
                        compensation_use_200;

                    compensation_500_count <=
                        compensation_use_500;

                    compensation_dispensed_amount <=
                        compensation_amount;

                    compensation_done <= 1'b1;
                end else begin
                    compensation_failed <= 1'b1;
                end
            end
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (RECYCLER_CAPACITY > 0)
            else $fatal("RECYCLER_CAPACITY must be positive");

        assert (RECYCLER_CAPACITY <= 65535)
            else $fatal("RECYCLER_CAPACITY must fit in 16-bit inventories");

        assert (INIT_NOTE10 >= 0 && INIT_NOTE10 <= 65535)
            else $fatal("INIT_NOTE10 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE20 >= 0 && INIT_NOTE20 <= 65535)
            else $fatal("INIT_NOTE20 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE50 >= 0 && INIT_NOTE50 <= 65535)
            else $fatal("INIT_NOTE50 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE100 >= 0 && INIT_NOTE100 <= 65535)
            else $fatal("INIT_NOTE100 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE200 >= 0 && INIT_NOTE200 <= 65535)
            else $fatal("INIT_NOTE200 must fit in 16 bits and cannot be negative");

        assert (INIT_NOTE500 >= 0 && INIT_NOTE500 <= 65535)
            else $fatal("INIT_NOTE500 must fit in 16 bits and cannot be negative");

        assert (INIT_COIN5 >= 0 && INIT_COIN5 <= 65535)
            else $fatal("INIT_COIN5 must fit in 16 bits and cannot be negative");

        assert (
            INIT_NOTE50 + INIT_NOTE100 <=
            RECYCLER_CAPACITY
        ) else $fatal("Initial recycler 1 inventory exceeds capacity");

        assert (
            INIT_NOTE10 + INIT_NOTE20 <=
            RECYCLER_CAPACITY
        ) else $fatal("Initial recycler 2 inventory exceeds capacity");

        assert (
            INIT_NOTE200 + INIT_NOTE500 <=
            RECYCLER_CAPACITY
        ) else $fatal("Initial recycler 3 inventory exceeds capacity");

        assert (BOX_CAPACITY > 0)
            else $fatal("BOX_CAPACITY must be positive");

        assert (BOX_CAPACITY <= 1023)
            else $fatal("BOX_CAPACITY must fit in 10 bits");

        assert (SAFE_BOX_THRESHOLD >= 0)
            else $fatal("SAFE_BOX_THRESHOLD cannot be negative");

        assert (SAFE_BOX_THRESHOLD <= BOX_CAPACITY)
            else $fatal("SAFE_BOX_THRESHOLD cannot exceed BOX_CAPACITY");
    end
`endif

endmodule


module cash_liability_manager(
    input  logic clk,
    input  logic rst,

    input  logic commit_done,
    input  logic [15:0] committed_amount,

    input  logic change_done,
    input  logic [15:0] change_dispensed_amount,

    input  logic compensation_done,
    input  logic [15:0] compensation_dispensed_amount,

    input  logic ticket_sale_complete,
    input  logic manual_settlement,

    output logic cash_liability_valid,
    output logic [15:0] cash_liability_amount
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cash_liability_valid  <= 1'b0;
            cash_liability_amount <= 16'd0;
        end else if (
            manual_settlement ||
            ticket_sale_complete
        ) begin
            cash_liability_valid  <= 1'b0;
            cash_liability_amount <= 16'd0;
        end else if (
            compensation_done &&
            cash_liability_valid
        ) begin
            if (
                compensation_dispensed_amount >=
                cash_liability_amount
            ) begin
                cash_liability_valid  <= 1'b0;
                cash_liability_amount <= 16'd0;
            end else begin
                cash_liability_amount <=
                    cash_liability_amount -
                    compensation_dispensed_amount;
            end
        end else if (
            change_done &&
            cash_liability_valid
        ) begin
            if (
                change_dispensed_amount >=
                cash_liability_amount
            ) begin
                cash_liability_valid  <= 1'b0;
                cash_liability_amount <= 16'd0;
            end else begin
                cash_liability_amount <=
                    cash_liability_amount -
                    change_dispensed_amount;
            end
        end else if (commit_done) begin
            cash_liability_valid <=
                committed_amount != 16'd0;

            cash_liability_amount <=
                committed_amount;
        end
    end

endmodule


module ticket_stock_monitor #(
    parameter int INIT_PAPER_STOCK = 10,
    parameter int INIT_CARD_STOCK = 5,
    parameter int LOW_THRESHOLD = 3,
    parameter bit QR_ENABLED = 1'b1
)(
    input  logic clk,
    input  logic rst,

    input  logic issue_ticket_request,
    input  logic card_issue_event,
    input  logic ticket_device_fault,

    output logic [7:0] paper_stock_count,
    output logic [7:0] card_stock_count,

    output logic low_stock_alert,
    output logic paper_empty,
    output logic card_empty,
    output logic qr_only_mode,
    output logic ticket_available,

    output logic ticket_issue_done,
    output logic ticket_issue_failed,

    output logic physical_ticket_issued,
    output logic digital_ticket_issued,

    output logic card_issued,
    output logic card_issue_failed
);

    logic issue_request_d;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            paper_stock_count <=
                INIT_PAPER_STOCK;

            card_stock_count <=
                INIT_CARD_STOCK;

            issue_request_d <= 1'b0;

            ticket_issue_done   <= 1'b0;
            ticket_issue_failed <= 1'b0;

            physical_ticket_issued <=
                1'b0;

            digital_ticket_issued <=
                1'b0;

            card_issued       <= 1'b0;
            card_issue_failed <= 1'b0;
        end else begin
            issue_request_d <=
                issue_ticket_request;

            ticket_issue_done   <= 1'b0;
            ticket_issue_failed <= 1'b0;

            physical_ticket_issued <=
                1'b0;

            digital_ticket_issued <=
                1'b0;

            card_issued       <= 1'b0;
            card_issue_failed <= 1'b0;

            if (
                issue_ticket_request &&
                !issue_request_d
            ) begin
                if (ticket_device_fault) begin
                    ticket_issue_failed <=
                        1'b1;
                end else if (
                    paper_stock_count !=
                    0
                ) begin
                    paper_stock_count <=
                        paper_stock_count -
                        1'b1;

                    physical_ticket_issued <=
                        1'b1;

                    ticket_issue_done <=
                        1'b1;
                end else if (QR_ENABLED) begin
                    digital_ticket_issued <=
                        1'b1;

                    ticket_issue_done <=
                        1'b1;
                end else begin
                    ticket_issue_failed <=
                        1'b1;
                end
            end

            if (card_issue_event) begin
                if (
                    card_stock_count !=
                    0
                ) begin
                    card_stock_count <=
                        card_stock_count -
                        1'b1;

                    card_issued <=
                        1'b1;
                end else begin
                    card_issue_failed <=
                        1'b1;
                end
            end
        end
    end

    always_comb begin
        paper_empty =
            paper_stock_count ==
            0;

        card_empty =
            card_stock_count ==
            0;

        qr_only_mode =
            QR_ENABLED &&
            paper_empty;

        ticket_available =
            !ticket_device_fault &&
            (
                !paper_empty ||
                QR_ENABLED
            );

        low_stock_alert =
            (paper_stock_count <=
             LOW_THRESHOLD) ||
            (card_stock_count <=
             LOW_THRESHOLD);
    end

`ifndef SYNTHESIS
    initial begin
        assert (INIT_PAPER_STOCK >= 0 && INIT_PAPER_STOCK <= 255)
            else $fatal("INIT_PAPER_STOCK must fit in eight bits and cannot be negative");

        assert (INIT_CARD_STOCK >= 0 && INIT_CARD_STOCK <= 255)
            else $fatal("INIT_CARD_STOCK must fit in eight bits and cannot be negative");

        assert (LOW_THRESHOLD >= 0 && LOW_THRESHOLD <= 255)
            else $fatal("LOW_THRESHOLD must fit in eight bits and cannot be negative");
    end
`endif

endmodule


module ticket_id_generator(
    input  logic clk,
    input  logic rst,

    input  logic generate_request,

    output logic [31:0] ticket_id,
    output logic ticket_id_valid
);

    logic request_serviced;
    logic [31:0] sequence_counter;

    // Sticky request/valid handshake:
    // - A new ID is allocated once when generate_request first becomes active.
    // - ticket_id_valid remains asserted until generate_request is released.
    // This prevents the FSM from missing a one-cycle valid pulse because of
    // nonblocking-assignment or state-transition timing.
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            request_serviced <= 1'b0;
            sequence_counter <= 32'd1;
            ticket_id        <= 32'd0;
            ticket_id_valid  <= 1'b0;
        end else if (!generate_request) begin
            request_serviced <= 1'b0;
            ticket_id_valid  <= 1'b0;
        end else begin
            ticket_id_valid <= 1'b1;

            if (!request_serviced) begin
                ticket_id <= sequence_counter;
                request_serviced <= 1'b1;

                if (sequence_counter == 32'hFFFF_FFFF)
                    sequence_counter <= 32'd1;
                else
                    sequence_counter <= sequence_counter + 1'b1;
            end
        end
    end

`ifndef SYNTHESIS
    // The generated ID must remain non-zero whenever it is declared valid
    // after the first serviced request clock.
    always @(posedge clk) begin
        if (!rst && ticket_id_valid)
            assert (ticket_id != 32'd0)
                else $error("ticket_id_valid asserted with zero ticket ID");
    end
`endif

endmodule


module ticket_registry #(
    parameter int MAX_TICKETS = 16,
    parameter int EXPIRY_TICKS = 30
)(
    input  logic clk,
    input  logic rst,
    input  logic time_tick,

    input  logic reserve_request,
    input  logic release_request,

    output logic reserve_done,
    output logic reserve_failed,
    output logic reservation_active,

    input  logic commit_request,
    input  logic [31:0] commit_ticket_id,
    input  logic [3:0] commit_destination,

    output logic registry_commit_done,
    output logic registry_commit_failed,

    input  logic validate_event,
    input  logic [31:0] scanned_ticket_id,
    input  logic [3:0] gate_station,

    output logic registry_available,
    output logic ticket_table_full,
    output logic ticket_registration_failed,
    output logic [15:0] active_ticket_count,

    output logic gate_open,
    output logic invalid_ticket,
    output logic already_used_ticket,
    output logic expired_ticket,
    output logic wrong_station_ticket
);

    localparam int IW =
        (MAX_TICKETS <= 1) ?
        1 :
        $clog2(MAX_TICKETS);

    logic [31:0]
        id_mem [0:MAX_TICKETS-1];

    logic [3:0]
        destination_mem [0:MAX_TICKETS-1];

    logic [31:0]
        issue_time_mem [0:MAX_TICKETS-1];

    logic valid_mem
        [0:MAX_TICKETS-1];

    logic used_mem
        [0:MAX_TICKETS-1];

    logic [31:0] current_time;

    logic [IW-1:0] reservation_index;

    logic allocation_found;
    logic [IW-1:0] allocation_index;

    logic match_found;
    logic [IW-1:0] match_index;

    logic validation_success;
    logic same_cycle_commit_validation;

    logic reserve_d;
    logic release_d;
    logic commit_d;

    logic reserve_pulse;
    logic release_pulse;
    logic commit_pulse;

    integer search_index;
    integer reset_index;
    integer active_count_temp;

    always_comb begin
        reserve_pulse =
            reserve_request &&
            !reserve_d;

        release_pulse =
            release_request &&
            !release_d;

        commit_pulse =
            commit_request &&
            !commit_d;
    end

    always_comb begin
        allocation_found = 1'b0;
        allocation_index = '0;

        match_found = 1'b0;
        match_index = '0;

        active_count_temp = 0;

        for (
            search_index = 0;
            search_index < MAX_TICKETS;
            search_index = search_index + 1
        ) begin
            if (
                !allocation_found &&
                (
                    !valid_mem[
                        search_index
                    ] ||
                    used_mem[
                        search_index
                    ] ||
                    (
                        current_time -
                        issue_time_mem[
                            search_index
                        ] >=
                        EXPIRY_TICKS
                    )
                ) &&
                (
                    !reservation_active ||
                    reservation_index !=
                    search_index
                )
            ) begin
                allocation_found = 1'b1;
                allocation_index =
                    search_index;
            end

            if (
                valid_mem[
                    search_index
                ] &&
                !used_mem[
                    search_index
                ] &&
                (
                    current_time -
                    issue_time_mem[
                        search_index
                    ] <
                    EXPIRY_TICKS
                )
            )
                active_count_temp =
                    active_count_temp +
                    1;

            if (
                !match_found &&
                valid_mem[
                    search_index
                ] &&
                id_mem[
                    search_index
                ] ==
                scanned_ticket_id
            ) begin
                match_found = 1'b1;
                match_index =
                    search_index;
            end
        end

        validation_success =
            validate_event &&
            match_found &&
            !used_mem[
                match_index
            ] &&
            (
                current_time -
                issue_time_mem[
                    match_index
                ] <
                EXPIRY_TICKS
            ) &&
            (
                gate_station ==
                destination_mem[
                    match_index
                ]
            );

        if (
            !allocation_found &&
            validation_success &&
            (
                !reservation_active ||
                reservation_index !=
                match_index
            )
        ) begin
            allocation_found = 1'b1;
            allocation_index =
                match_index;
        end

        registry_available =
            !reservation_active &&
            allocation_found;

        ticket_table_full =
            !reservation_active &&
            !allocation_found;

        active_ticket_count =
            active_count_temp;

        same_cycle_commit_validation =
            commit_pulse &&
            reservation_active &&
            validate_event &&
            (
                scanned_ticket_id ==
                commit_ticket_id
            );
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            current_time <= 32'd0;

            reservation_active <=
                1'b0;

            reservation_index <=
                '0;

            reserve_d <= 1'b0;
            release_d <= 1'b0;
            commit_d <= 1'b0;

            reserve_done   <= 1'b0;
            reserve_failed <= 1'b0;

            registry_commit_done <=
                1'b0;

            registry_commit_failed <=
                1'b0;

            ticket_registration_failed <=
                1'b0;

            gate_open            <= 1'b0;
            invalid_ticket       <= 1'b0;
            already_used_ticket  <= 1'b0;
            expired_ticket       <= 1'b0;
            wrong_station_ticket <= 1'b0;

            for (
                reset_index = 0;
                reset_index < MAX_TICKETS;
                reset_index = reset_index + 1
            ) begin
                id_mem[
                    reset_index
                ] <= 32'd0;

                destination_mem[
                    reset_index
                ] <= 4'd0;

                issue_time_mem[
                    reset_index
                ] <= 32'd0;

                valid_mem[
                    reset_index
                ] <= 1'b0;

                used_mem[
                    reset_index
                ] <= 1'b0;
            end
        end else begin
            reserve_d <=
                reserve_request;

            release_d <=
                release_request;

            commit_d <=
                commit_request;

            reserve_done   <= 1'b0;
            reserve_failed <= 1'b0;

            registry_commit_done <=
                1'b0;

            registry_commit_failed <=
                1'b0;

            ticket_registration_failed <=
                1'b0;

            gate_open            <= 1'b0;
            invalid_ticket       <= 1'b0;
            already_used_ticket  <= 1'b0;
            expired_ticket       <= 1'b0;
            wrong_station_ticket <= 1'b0;

            if (time_tick)
                current_time <=
                    current_time +
                    1'b1;

            if (release_pulse) begin
                reservation_active <=
                    1'b0;
            end

            if (reserve_pulse) begin
                if (reservation_active) begin
                    reserve_failed <=
                        1'b1;
                end else if (allocation_found) begin
                    reservation_active <=
                        1'b1;

                    reservation_index <=
                        allocation_index;

                    reserve_done <=
                        1'b1;
                end else begin
                    reserve_failed <=
                        1'b1;
                end
            end

            if (commit_pulse) begin
                if (reservation_active) begin
                    id_mem[
                        reservation_index
                    ] <=
                        commit_ticket_id;

                    destination_mem[
                        reservation_index
                    ] <=
                        commit_destination;

                    issue_time_mem[
                        reservation_index
                    ] <=
                        current_time;

                    valid_mem[
                        reservation_index
                    ] <= 1'b1;

                    used_mem[
                        reservation_index
                    ] <= 1'b0;

                    reservation_active <=
                        1'b0;

                    registry_commit_done <=
                        1'b1;
                end else begin
                    registry_commit_failed <=
                        1'b1;

                    ticket_registration_failed <=
                        1'b1;
                end
            end

            if (validate_event) begin
                if (same_cycle_commit_validation) begin
                    if (
                        gate_station !=
                        commit_destination
                    ) begin
                        wrong_station_ticket <=
                            1'b1;
                    end else begin
                        gate_open <= 1'b1;

                        used_mem[
                            reservation_index
                        ] <= 1'b1;
                    end
                end else if (!match_found) begin
                    invalid_ticket <=
                        1'b1;
                end else if (
                    used_mem[
                        match_index
                    ]
                ) begin
                    already_used_ticket <=
                        1'b1;
                end else if (
                    current_time -
                    issue_time_mem[
                        match_index
                    ] >=
                    EXPIRY_TICKS
                ) begin
                    expired_ticket <=
                        1'b1;
                end else if (
                    gate_station !=
                    destination_mem[
                        match_index
                    ]
                ) begin
                    wrong_station_ticket <=
                        1'b1;
                end else begin
                    gate_open <=
                        1'b1;

                    used_mem[
                        match_index
                    ] <= 1'b1;
                end
            end
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (MAX_TICKETS > 0)
            else $fatal("MAX_TICKETS must be greater than zero");

        assert (MAX_TICKETS <= 65535)
            else $fatal("MAX_TICKETS must fit in active_ticket_count");

        assert (EXPIRY_TICKS > 0)
            else $fatal("EXPIRY_TICKS must be greater than zero");
    end
`endif

endmodule


module rapid_card_controller #(
    parameter int CARD_SLOTS = 16,
    parameter int CARD_ID_WIDTH = 8
)(
    input  logic clk,
    input  logic rst,

    input  logic card_load_event,
    input  logic card_load_allowed,

    input  logic [CARD_ID_WIDTH-1:0]
        captured_load_card_id,

    input  logic [15:0]
        captured_initial_balance,

    input  logic new_transaction,
    input  logic clear_transaction,
    input  logic manual_settlement,

    input  logic rapid_enable,
    input  logic card_tap_event,

    input  logic [CARD_ID_WIDTH-1:0]
        captured_tap_card_id,

    input  logic [15:0] fare_amount,

    input  logic rapid_refund_request,

    input  logic recharge_execute,

    input  logic [CARD_ID_WIDTH-1:0]
        recharge_card_id,

    input  logic [15:0]
        recharge_amount,

    input  logic ticket_sale_complete,

    output logic card_loaded,
    output logic card_load_done,
    output logic card_load_failed,

    output logic [CARD_ID_WIDTH-1:0]
        active_card_id,

    output logic [15:0] updated_balance,

    output logic rapid_payment_ok,
    output logic low_balance_warning,
    output logic debit_active,

    output logic wrong_card_error,
    output logic card_not_loaded_error,

    output logic rapid_refund_done,
    output logic [15:0] rapid_refund_amount,

    output logic rapid_liability_valid,
    output logic [15:0] rapid_liability_amount,

    output logic [CARD_ID_WIDTH-1:0]
        rapid_liability_card_id,

    output logic recharge_done,
    output logic recharge_failed
);

    localparam int IW =
        (CARD_SLOTS <= 1) ?
        1 :
        $clog2(CARD_SLOTS);

    logic [CARD_ID_WIDTH-1:0]
        card_id_mem [0:CARD_SLOTS-1];

    logic [15:0]
        card_balance_mem [0:CARD_SLOTS-1];

    logic card_valid_mem
        [0:CARD_SLOTS-1];

    logic [IW-1:0] active_index;
    logic [IW-1:0] liability_index;

    logic load_card_found;
    logic [IW-1:0] load_card_index;

    logic recharge_card_found;
    logic [IW-1:0] recharge_card_index;

    logic free_slot_found;
    logic [IW-1:0] free_slot_index;

    logic refund_request_d;
    logic recharge_execute_d;

    logic [16:0] recharge_sum;

    integer search_index;
    integer reset_index;

    always_comb begin
        load_card_found = 1'b0;
        load_card_index = '0;

        recharge_card_found = 1'b0;
        recharge_card_index = '0;

        free_slot_found = 1'b0;
        free_slot_index = '0;

        for (
            search_index = 0;
            search_index < CARD_SLOTS;
            search_index = search_index + 1
        ) begin
            if (
                !load_card_found &&
                card_valid_mem[
                    search_index
                ] &&
                card_id_mem[
                    search_index
                ] ==
                captured_load_card_id
            ) begin
                load_card_found = 1'b1;
                load_card_index =
                    search_index;
            end

            if (
                !recharge_card_found &&
                card_valid_mem[
                    search_index
                ] &&
                card_id_mem[
                    search_index
                ] ==
                recharge_card_id
            ) begin
                recharge_card_found = 1'b1;
                recharge_card_index =
                    search_index;
            end

            if (
                !free_slot_found &&
                !card_valid_mem[
                    search_index
                ]
            ) begin
                free_slot_found = 1'b1;
                free_slot_index =
                    search_index;
            end
        end

        if (recharge_card_found)
            recharge_sum =
                {
                    1'b0,
                    card_balance_mem[
                        recharge_card_index
                    ]
                } +
                {
                    1'b0,
                    recharge_amount
                };
        else
            recharge_sum = 17'd0;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            active_index    <= '0;
            liability_index <= '0;

            card_loaded      <= 1'b0;
            card_load_done   <= 1'b0;
            card_load_failed <= 1'b0;

            active_card_id  <= '0;
            updated_balance <= 16'd0;

            rapid_payment_ok    <= 1'b0;
            low_balance_warning <= 1'b0;
            debit_active        <= 1'b0;

            wrong_card_error <= 1'b0;
            card_not_loaded_error <=
                1'b0;

            refund_request_d <= 1'b0;
            recharge_execute_d <=
                1'b0;

            rapid_refund_done   <= 1'b0;
            rapid_refund_amount <= 16'd0;

            rapid_liability_valid <=
                1'b0;

            rapid_liability_amount <=
                16'd0;

            rapid_liability_card_id <=
                '0;

            recharge_done   <= 1'b0;
            recharge_failed <= 1'b0;

            for (
                reset_index = 0;
                reset_index < CARD_SLOTS;
                reset_index = reset_index + 1
            ) begin
                card_id_mem[
                    reset_index
                ] <= '0;

                card_balance_mem[
                    reset_index
                ] <= 16'd0;

                card_valid_mem[
                    reset_index
                ] <= 1'b0;
            end
        end else begin
            refund_request_d <=
                rapid_refund_request;

            recharge_execute_d <=
                recharge_execute;

            card_load_done   <= 1'b0;
            card_load_failed <= 1'b0;

            rapid_refund_done <=
                1'b0;

            recharge_done   <= 1'b0;
            recharge_failed <= 1'b0;

            wrong_card_error <= 1'b0;

            card_not_loaded_error <=
                1'b0;

            if (manual_settlement) begin
                rapid_liability_valid <=
                    1'b0;

                rapid_liability_amount <=
                    16'd0;

                rapid_liability_card_id <=
                    '0;

                rapid_payment_ok <=
                    1'b0;

                low_balance_warning <=
                    1'b0;

                debit_active <=
                    1'b0;

                card_loaded <=
                    1'b0;

                active_card_id <=
                    '0;

                updated_balance <=
                    16'd0;
            end else if (card_load_event) begin
                rapid_payment_ok <=
                    1'b0;

                low_balance_warning <=
                    1'b0;

                debit_active <=
                    1'b0;

                if (!card_load_allowed) begin
                    card_load_failed <=
                        1'b1;
                end else if (load_card_found) begin
                    active_index <=
                        load_card_index;

                    active_card_id <=
                        card_id_mem[
                            load_card_index
                        ];

                    updated_balance <=
                        card_balance_mem[
                            load_card_index
                        ];

                    card_loaded <=
                        1'b1;

                    card_load_done <=
                        1'b1;
                end else if (free_slot_found) begin
                    card_id_mem[
                        free_slot_index
                    ] <=
                        captured_load_card_id;

                    card_balance_mem[
                        free_slot_index
                    ] <=
                        captured_initial_balance;

                    card_valid_mem[
                        free_slot_index
                    ] <= 1'b1;

                    active_index <=
                        free_slot_index;

                    active_card_id <=
                        captured_load_card_id;

                    updated_balance <=
                        captured_initial_balance;

                    card_loaded <=
                        1'b1;

                    card_load_done <=
                        1'b1;
                end else begin
                    card_load_failed <=
                        1'b1;
                end
            end else if (new_transaction) begin
                rapid_payment_ok <=
                    1'b0;

                low_balance_warning <=
                    1'b0;

                debit_active <=
                    1'b0;

                rapid_refund_amount <=
                    16'd0;
            end else if (
                recharge_execute &&
                !recharge_execute_d
            ) begin
                if (
                    recharge_card_found &&
                    recharge_amount !=
                    16'd0 &&
                    !recharge_sum[16]
                ) begin
                    card_balance_mem[
                        recharge_card_index
                    ] <=
                        recharge_sum[15:0];

                    if (
                        card_loaded &&
                        recharge_card_index ==
                        active_index
                    )
                        updated_balance <=
                            recharge_sum[15:0];

                    recharge_done <=
                        1'b1;
                end else begin
                    recharge_failed <=
                        1'b1;
                end
            end else if (
                rapid_refund_request &&
                !refund_request_d
            ) begin
                if (rapid_liability_valid) begin
                    card_balance_mem[
                        liability_index
                    ] <=
                        card_balance_mem[
                            liability_index
                        ] +
                        rapid_liability_amount;

                    if (
                        card_loaded &&
                        liability_index ==
                        active_index
                    )
                        updated_balance <=
                            card_balance_mem[
                                liability_index
                            ] +
                            rapid_liability_amount;

                    rapid_refund_amount <=
                        rapid_liability_amount;

                    rapid_liability_valid <=
                        1'b0;

                    rapid_liability_amount <=
                        16'd0;

                    rapid_liability_card_id <=
                        '0;
                end else begin
                    rapid_refund_amount <=
                        16'd0;
                end

                rapid_payment_ok <=
                    1'b0;

                low_balance_warning <=
                    1'b0;

                debit_active <=
                    1'b0;

                rapid_refund_done <=
                    1'b1;
            end else if (
                rapid_enable &&
                card_tap_event &&
                !debit_active &&
                !rapid_liability_valid
            ) begin
                if (!card_loaded) begin
                    card_not_loaded_error <=
                        1'b1;
                end else if (
                    captured_tap_card_id !=
                    active_card_id
                ) begin
                    wrong_card_error <=
                        1'b1;
                end else if (
                    card_balance_mem[
                        active_index
                    ] >=
                    fare_amount
                ) begin
                    card_balance_mem[
                        active_index
                    ] <=
                        card_balance_mem[
                            active_index
                        ] -
                        fare_amount;

                    updated_balance <=
                        card_balance_mem[
                            active_index
                        ] -
                        fare_amount;

                    liability_index <=
                        active_index;

                    rapid_liability_valid <=
                        1'b1;

                    rapid_liability_amount <=
                        fare_amount;

                    rapid_liability_card_id <=
                        active_card_id;

                    rapid_payment_ok <=
                        1'b1;

                    low_balance_warning <=
                        1'b0;

                    debit_active <=
                        1'b1;
                end else begin
                    updated_balance <=
                        card_balance_mem[
                            active_index
                        ];

                    rapid_payment_ok <=
                        1'b0;

                    low_balance_warning <=
                        1'b1;

                    debit_active <=
                        1'b0;
                end
            end else if (ticket_sale_complete) begin
                rapid_liability_valid <=
                    1'b0;

                rapid_liability_amount <=
                    16'd0;

                rapid_liability_card_id <=
                    '0;

                rapid_payment_ok <=
                    1'b0;

                debit_active <=
                    1'b0;
            end else if (clear_transaction) begin
                rapid_payment_ok <=
                    1'b0;

                low_balance_warning <=
                    1'b0;

                debit_active <=
                    1'b0;
            end
        end
    end

`ifndef SYNTHESIS
    initial begin
        assert (CARD_SLOTS > 0)
            else $fatal("CARD_SLOTS must be greater than zero");

        assert (CARD_ID_WIDTH > 0)
            else $fatal("CARD_ID_WIDTH must be greater than zero");
    end
`endif

endmodule


module revenue_report_controller(
    input  logic clk,
    input  logic rst,

    input  logic cash_commit_done,
    input  logic [15:0] cash_committed_amount,

    input  logic change_done,
    input  logic [15:0] change_dispensed_amount,

    input  logic ticket_sale_complete,
    input  logic [15:0] fare_amount,

    input  logic cash_refund_done,
    input  logic [15:0] cash_refund_amount,

    input  logic compensation_done,
    input  logic [15:0] compensation_amount,

    input  logic rapid_refund_done,
    input  logic [15:0] rapid_refund_amount,

    input  logic recharge_done,
    input  logic [15:0] recharge_amount,

    input  logic generate_report,
    input  logic clear_report,

    output logic [31:0] total_revenue,
    output logic [31:0] total_cash_in,
    output logic [31:0] total_change_returned,
    output logic [31:0] total_refunded,
    output logic [31:0] total_recharge_amount,
    output logic [15:0] total_ticket_issued,

    output logic report_valid,
    output logic accounting_overflow
);

    logic [17:0] refund_increment;

    logic [32:0] revenue_sum;
    logic [32:0] cash_sum;
    logic [32:0] change_sum;
    logic [32:0] refund_sum;
    logic [32:0] recharge_sum;

    always_comb begin
        refund_increment =
            {
                2'b00,
                cash_refund_done ?
                cash_refund_amount :
                16'd0
            } +
            {
                2'b00,
                compensation_done ?
                compensation_amount :
                16'd0
            } +
            {
                2'b00,
                rapid_refund_done ?
                rapid_refund_amount :
                16'd0
            };

        revenue_sum =
            {1'b0, total_revenue} +
            (
                ticket_sale_complete ?
                fare_amount :
                16'd0
            );

        cash_sum =
            {1'b0, total_cash_in} +
            (
                cash_commit_done ?
                cash_committed_amount :
                16'd0
            );

        change_sum =
            {1'b0, total_change_returned} +
            (
                change_done ?
                change_dispensed_amount :
                16'd0
            );

        refund_sum =
            {1'b0, total_refunded} +
            refund_increment;

        recharge_sum =
            {1'b0, total_recharge_amount} +
            (
                recharge_done ?
                recharge_amount :
                16'd0
            );
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            total_revenue         <= 32'd0;
            total_cash_in         <= 32'd0;
            total_change_returned <= 32'd0;
            total_refunded        <= 32'd0;
            total_recharge_amount <= 32'd0;
            total_ticket_issued   <= 16'd0;
            report_valid          <= 1'b0;
            accounting_overflow   <= 1'b0;
        end else begin
            if (generate_report)
                report_valid <=
                    1'b1;
            else if (clear_report)
                report_valid <=
                    1'b0;

            if (ticket_sale_complete) begin
                if (revenue_sum[32]) begin
                    total_revenue <=
                        32'hFFFF_FFFF;

                    accounting_overflow <=
                        1'b1;
                end else begin
                    total_revenue <=
                        revenue_sum[31:0];
                end

                if (
                    total_ticket_issued ==
                    16'hFFFF
                ) begin
                    total_ticket_issued <=
                        16'hFFFF;

                    accounting_overflow <=
                        1'b1;
                end else begin
                    total_ticket_issued <=
                        total_ticket_issued +
                        1'b1;
                end
            end

            if (cash_commit_done) begin
                if (cash_sum[32]) begin
                    total_cash_in <=
                        32'hFFFF_FFFF;

                    accounting_overflow <=
                        1'b1;
                end else begin
                    total_cash_in <=
                        cash_sum[31:0];
                end
            end

            if (change_done) begin
                if (change_sum[32]) begin
                    total_change_returned <=
                        32'hFFFF_FFFF;

                    accounting_overflow <=
                        1'b1;
                end else begin
                    total_change_returned <=
                        change_sum[31:0];
                end
            end

            if (refund_increment != 0) begin
                if (refund_sum[32]) begin
                    total_refunded <=
                        32'hFFFF_FFFF;

                    accounting_overflow <=
                        1'b1;
                end else begin
                    total_refunded <=
                        refund_sum[31:0];
                end
            end

            if (recharge_done) begin
                if (recharge_sum[32]) begin
                    total_recharge_amount <=
                        32'hFFFF_FFFF;

                    accounting_overflow <=
                        1'b1;
                end else begin
                    total_recharge_amount <=
                        recharge_sum[31:0];
                end
            end
        end
    end

endmodule


module vending_fsm #(
    parameter int PAYMENT_TIMEOUT_CYCLES = 500,
    parameter int INTERNAL_TIMEOUT_CYCLES = 64,
    parameter int CHANGE_PLAN_TIMEOUT_CYCLES = 25000,
    parameter int COMPENSATION_TIMEOUT_CYCLES = 25000
)(
    input  logic clk,
    input  logic rst,

    input  logic start_event,
    input  logic cancel_event,
    input  logic cancel_request_pending,
    input  logic closing_event,
    input  logic recharge_start_event,
    input  logic maintenance_clear_event,

    input  logic valid_route,
    input  logic rapid_mode,

    input  logic payment_ok,
    input  logic rapid_payment_ok,

    input  logic wrong_card_error,
    input  logic card_not_loaded_error,

    input  logic invalid_note_pulse,
    input  logic storage_reject_pulse,
    input  logic payment_activity,
    input  logic payment_request_busy,

    input  logic low_balance_warning,

    input  logic stock_ticket_available,

    input  logic escrow_commit_possible,
    input  logic escrow_nonempty,

    input  logic cash_liability_valid,
    input  logic rapid_liability_valid,

    input  logic reserve_done,
    input  logic reserve_failed,

    input  logic change_plan_done,
    input  logic change_possible,

    input  logic change_done,
    input  logic change_failed,

    input  logic commit_done,
    input  logic commit_failed,

    input  logic cash_refund_done,
    input  logic rapid_refund_done,

    input  logic compensation_plan_done,
    input  logic compensation_possible,

    input  logic compensation_done,
    input  logic compensation_failed,

    input  logic ticket_id_valid,

    input  logic ticket_issue_done,
    input  logic ticket_issue_failed,

    input  logic registry_commit_done,
    input  logic registry_commit_failed,

    input  logic recharge_done,
    input  logic recharge_failed,

    output logic new_transaction,
    output logic cash_enable,

    output logic reserve_ticket_slot,
    output logic release_ticket_slot,
    output logic commit_ticket_registration,

    output logic start_change_plan,
    output logic start_compensation_plan,
    output logic abort_planners,

    output logic dispense_change,
    output logic commit_escrow,

    output logic return_escrow,
    output logic rapid_refund_request,

    output logic dispense_compensation,

    output logic generate_ticket_id,
    output logic issue_ticket_request,

    output logic clear_transaction,
    output logic manual_settlement,

    output logic generate_report,
    output logic recharge_execute,

    output logic transaction_active,
    output logic transaction_aborted,

    output logic payment_timeout_error,
    output logic operation_timeout_error,

    output logic service_required,
    output logic cancel_allowed,

    output logic [5:0] pstate_code,
    output logic [5:0] nstate_code
);

    typedef enum logic [5:0] {
        S_IDLE                    = 6'd0,
        S_CAPTURE_TRANSACTION     = 6'd1,
        S_CALCULATE_FARE          = 6'd2,
        S_WAIT_PAYMENT            = 6'd3,
        S_VERIFY_PAYMENT          = 6'd4,
        S_CHECK_STOCK             = 6'd5,
        S_RESERVE_TICKET          = 6'd6,
        S_WAIT_RESERVE            = 6'd7,
        S_START_CHANGE_PLAN       = 6'd8,
        S_WAIT_CHANGE_PLAN        = 6'd9,
        S_GENERATE_ID             = 6'd10,
        S_COMMIT_CASH             = 6'd11,
        S_DISPENSE_CHANGE         = 6'd12,
        S_ISSUE_TICKET            = 6'd13,
        S_REGISTER_TICKET         = 6'd14,
        S_WAIT_REGISTER           = 6'd15,
        S_TRANSACTION_DONE        = 6'd16,
        S_INVALID_ROUTE           = 6'd17,
        S_FAKE_NOTE_REJECT        = 6'd18,
        S_STORAGE_REJECT          = 6'd19,
        S_LOW_BALANCE             = 6'd20,
        S_CARD_NOT_LOADED         = 6'd21,
        S_WRONG_CARD              = 6'd22,
        S_TICKET_UNAVAILABLE      = 6'd23,
        S_TICKET_TABLE_FULL       = 6'd24,
        S_CHANGE_UNAVAILABLE      = 6'd25,
        S_REFUND_ABORT            = 6'd26,
        S_REFUND_SERVICE          = 6'd27,
        S_ABORT                   = 6'd28,
        S_CLOSING_MODE            = 6'd29,
        S_REVENUE_SUMMARY         = 6'd30,
        S_RECHARGE_EXECUTE        = 6'd31,
        S_RECHARGE_DONE           = 6'd32,
        S_RECHARGE_ERROR          = 6'd33,
        S_PAYMENT_TIMEOUT         = 6'd34,
        S_OPERATION_TIMEOUT       = 6'd35,
        S_START_COMPENSATION_PLAN = 6'd36,
        S_WAIT_COMPENSATION_PLAN  = 6'd37,
        S_DISPENSE_COMPENSATION   = 6'd38,
        S_RAPID_ROLLBACK          = 6'd39,
        S_SERVICE_ERROR           = 6'd40,
        S_RECOVERY_CLEAR          = 6'd41
    } state_t;

    state_t pstate;
    state_t nstate;
    state_t timeout_source_state;

    logic [31:0] payment_counter;
    logic [31:0] operation_counter;

    logic payment_timeout_reached;
    logic operation_timeout_reached;

    logic operation_wait_state;
    logic [31:0] operation_timeout_limit;

    logic funds_present;

    always_comb begin
        payment_timeout_reached =
            PAYMENT_TIMEOUT_CYCLES != 0 &&
            payment_counter >=
            PAYMENT_TIMEOUT_CYCLES - 1;

        operation_wait_state =
            (pstate == S_WAIT_RESERVE) ||
            (pstate == S_WAIT_CHANGE_PLAN) ||
            (pstate == S_GENERATE_ID) ||
            (pstate == S_COMMIT_CASH) ||
            (pstate == S_DISPENSE_CHANGE) ||
            (pstate == S_ISSUE_TICKET) ||
            (pstate == S_WAIT_REGISTER) ||
            (pstate == S_REFUND_ABORT) ||
            (pstate == S_REFUND_SERVICE) ||
            (pstate == S_RECHARGE_EXECUTE) ||
            (pstate == S_WAIT_COMPENSATION_PLAN) ||
            (pstate == S_DISPENSE_COMPENSATION) ||
            (pstate == S_RAPID_ROLLBACK);

        if (pstate == S_WAIT_CHANGE_PLAN)
            operation_timeout_limit =
                CHANGE_PLAN_TIMEOUT_CYCLES;
        else if (
            pstate ==
            S_WAIT_COMPENSATION_PLAN
        )
            operation_timeout_limit =
                COMPENSATION_TIMEOUT_CYCLES;
        else
            operation_timeout_limit =
                INTERNAL_TIMEOUT_CYCLES;

        operation_timeout_reached =
            operation_wait_state &&
            operation_timeout_limit != 0 &&
            operation_counter >=
            operation_timeout_limit - 1;

        funds_present =
            escrow_nonempty ||
            cash_liability_valid ||
            rapid_liability_valid;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pstate <= S_IDLE;

            timeout_source_state <=
                S_IDLE;

            payment_counter <=
                32'd0;

            operation_counter <=
                32'd0;
        end else begin
            pstate <= nstate;

            if (
                pstate !=
                S_WAIT_PAYMENT
            )
                payment_counter <=
                    32'd0;
            else if (payment_activity)
                payment_counter <=
                    32'd0;
            else if (
                !payment_timeout_reached
            )
                payment_counter <=
                    payment_counter +
                    1'b1;

            if (
                !operation_wait_state ||
                nstate != pstate
            )
                operation_counter <=
                    32'd0;
            else if (
                !operation_timeout_reached
            )
                operation_counter <=
                    operation_counter +
                    1'b1;

            if (
                operation_timeout_reached &&
                nstate ==
                S_OPERATION_TIMEOUT
            )
                timeout_source_state <=
                    pstate;
        end
    end

    always_comb begin
        nstate = pstate;

        case (pstate)

            S_IDLE: begin
                if (closing_event)
                    nstate =
                        S_CLOSING_MODE;
                else if (recharge_start_event)
                    nstate =
                        S_RECHARGE_EXECUTE;
                else if (start_event)
                    nstate =
                        S_CAPTURE_TRANSACTION;
            end

            S_CAPTURE_TRANSACTION:
                nstate =
                    S_CALCULATE_FARE;

            S_CALCULATE_FARE: begin
                if (valid_route)
                    nstate =
                        S_WAIT_PAYMENT;
                else
                    nstate =
                        S_INVALID_ROUTE;
            end

            S_WAIT_PAYMENT: begin
                if (cancel_event)
                    nstate =
                        S_REFUND_ABORT;
                else if (cancel_request_pending)
                    nstate =
                        S_WAIT_PAYMENT;
                else if (storage_reject_pulse)
                    nstate =
                        S_STORAGE_REJECT;
                else if (invalid_note_pulse)
                    nstate =
                        S_FAKE_NOTE_REJECT;
                else if (wrong_card_error)
                    nstate =
                        S_WRONG_CARD;
                else if (card_not_loaded_error)
                    nstate =
                        S_CARD_NOT_LOADED;
                else if (
                    rapid_mode &&
                    low_balance_warning
                )
                    nstate =
                        S_LOW_BALANCE;
                else if (
                    !payment_request_busy &&
                    (
                        (!rapid_mode && payment_ok) ||
                        (rapid_mode &&
                         rapid_payment_ok)
                    )
                )
                    nstate =
                        S_VERIFY_PAYMENT;
                else if (
                    payment_timeout_reached &&
                    !payment_activity &&
                    !payment_request_busy
                )
                    nstate =
                        S_PAYMENT_TIMEOUT;
            end

            S_VERIFY_PAYMENT: begin
                if (cancel_event)
                    nstate =
                        S_REFUND_ABORT;
                else if (cancel_request_pending)
                    nstate =
                        S_VERIFY_PAYMENT;
                else if (
                    !rapid_mode &&
                    !escrow_commit_possible
                )
                    nstate =
                        S_REFUND_ABORT;
                else
                    nstate =
                        S_CHECK_STOCK;
            end

            S_CHECK_STOCK: begin
                if (cancel_event)
                    nstate =
                        S_REFUND_ABORT;
                else if (cancel_request_pending)
                    nstate =
                        S_CHECK_STOCK;
                else if (
                    !stock_ticket_available
                )
                    nstate =
                        S_TICKET_UNAVAILABLE;
                else
                    nstate =
                        S_RESERVE_TICKET;
            end

            S_RESERVE_TICKET:
                nstate =
                    S_WAIT_RESERVE;

            S_WAIT_RESERVE: begin
                if (cancel_event)
                    nstate =
                        S_REFUND_ABORT;
                else if (cancel_request_pending)
                    nstate =
                        S_WAIT_RESERVE;
                else if (reserve_done)
                    nstate =
                        rapid_mode ?
                        S_GENERATE_ID :
                        S_START_CHANGE_PLAN;
                else if (reserve_failed)
                    nstate =
                        S_TICKET_TABLE_FULL;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_OPERATION_TIMEOUT;
            end

            S_START_CHANGE_PLAN:
                nstate =
                    S_WAIT_CHANGE_PLAN;

            S_WAIT_CHANGE_PLAN: begin
                if (cancel_event)
                    nstate =
                        S_REFUND_ABORT;
                else if (cancel_request_pending)
                    nstate =
                        S_WAIT_CHANGE_PLAN;
                else if (change_plan_done)
                    nstate =
                        change_possible ?
                        S_GENERATE_ID :
                        S_CHANGE_UNAVAILABLE;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_OPERATION_TIMEOUT;
            end

            S_GENERATE_ID: begin
                if (cancel_event)
                    nstate =
                        S_REFUND_ABORT;
                else if (cancel_request_pending)
                    nstate =
                        S_GENERATE_ID;
                else if (ticket_id_valid)
                    nstate =
                        rapid_mode ?
                        S_ISSUE_TICKET :
                        S_COMMIT_CASH;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_OPERATION_TIMEOUT;
            end

            S_COMMIT_CASH: begin
                if (commit_done)
                    nstate =
                        S_DISPENSE_CHANGE;
                else if (commit_failed)
                    nstate =
                        S_REFUND_SERVICE;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_OPERATION_TIMEOUT;
            end

            S_DISPENSE_CHANGE: begin
                if (change_done)
                    nstate =
                        S_ISSUE_TICKET;
                else if (change_failed)
                    nstate =
                        S_START_COMPENSATION_PLAN;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_OPERATION_TIMEOUT;
            end

            S_ISSUE_TICKET: begin
                if (ticket_issue_done)
                    nstate =
                        S_REGISTER_TICKET;
                else if (ticket_issue_failed)
                    nstate =
                        rapid_mode ?
                        S_RAPID_ROLLBACK :
                        S_START_COMPENSATION_PLAN;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_OPERATION_TIMEOUT;
            end

            S_REGISTER_TICKET:
                nstate =
                    S_WAIT_REGISTER;

            S_WAIT_REGISTER: begin
                if (registry_commit_done)
                    nstate =
                        S_TRANSACTION_DONE;
                else if (
                    registry_commit_failed
                )
                    nstate =
                        rapid_mode ?
                        S_RAPID_ROLLBACK :
                        S_START_COMPENSATION_PLAN;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_OPERATION_TIMEOUT;
            end

            S_TRANSACTION_DONE:
                nstate =
                    S_IDLE;

            S_INVALID_ROUTE:
                nstate =
                    S_ABORT;

            S_FAKE_NOTE_REJECT,
            S_STORAGE_REJECT:
                nstate =
                    S_WAIT_PAYMENT;

            S_LOW_BALANCE,
            S_CARD_NOT_LOADED,
            S_WRONG_CARD:
                nstate =
                    S_ABORT;

            S_TICKET_UNAVAILABLE,
            S_TICKET_TABLE_FULL,
            S_CHANGE_UNAVAILABLE:
                nstate =
                    S_REFUND_ABORT;

            S_REFUND_ABORT: begin
                if (
                    (!rapid_mode &&
                     cash_refund_done) ||
                    (rapid_mode &&
                     rapid_refund_done)
                )
                    nstate =
                        S_ABORT;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_SERVICE_ERROR;
            end

            S_REFUND_SERVICE: begin
                if (
                    (!rapid_mode &&
                     cash_refund_done) ||
                    (rapid_mode &&
                     rapid_refund_done)
                )
                    nstate =
                        S_SERVICE_ERROR;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_SERVICE_ERROR;
            end

            S_ABORT:
                nstate =
                    S_IDLE;

            S_CLOSING_MODE:
                nstate =
                    S_REVENUE_SUMMARY;

            S_REVENUE_SUMMARY:
                nstate =
                    S_IDLE;

            S_RECHARGE_EXECUTE: begin
                if (recharge_done)
                    nstate =
                        S_RECHARGE_DONE;
                else if (recharge_failed)
                    nstate =
                        S_RECHARGE_ERROR;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_SERVICE_ERROR;
            end

            S_RECHARGE_DONE,
            S_RECHARGE_ERROR:
                nstate =
                    S_IDLE;

            S_PAYMENT_TIMEOUT:
                nstate =
                    funds_present ?
                    S_REFUND_ABORT :
                    S_ABORT;

            S_START_COMPENSATION_PLAN:
                nstate =
                    S_WAIT_COMPENSATION_PLAN;

            S_WAIT_COMPENSATION_PLAN: begin
                if (compensation_plan_done)
                    nstate =
                        compensation_possible ?
                        S_DISPENSE_COMPENSATION :
                        S_SERVICE_ERROR;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_SERVICE_ERROR;
            end

            S_DISPENSE_COMPENSATION: begin
                if (
                    compensation_done ||
                    compensation_failed
                )
                    nstate =
                        S_SERVICE_ERROR;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_SERVICE_ERROR;
            end

            S_RAPID_ROLLBACK: begin
                if (rapid_refund_done)
                    nstate =
                        S_SERVICE_ERROR;
                else if (
                    operation_timeout_reached
                )
                    nstate =
                        S_SERVICE_ERROR;
            end

            S_OPERATION_TIMEOUT: begin
                case (timeout_source_state)

                    S_WAIT_RESERVE,
                    S_WAIT_CHANGE_PLAN,
                    S_GENERATE_ID:
                        nstate =
                            S_REFUND_SERVICE;

                    S_COMMIT_CASH:
                        nstate =
                            escrow_nonempty ?
                            S_REFUND_SERVICE :
                            S_START_COMPENSATION_PLAN;

                    S_DISPENSE_CHANGE:
                        nstate =
                            S_START_COMPENSATION_PLAN;

                    S_ISSUE_TICKET,
                    S_WAIT_REGISTER:
                        nstate =
                            rapid_mode ?
                            S_RAPID_ROLLBACK :
                            S_START_COMPENSATION_PLAN;

                    default:
                        nstate =
                            S_SERVICE_ERROR;

                endcase
            end

            S_SERVICE_ERROR: begin
                if (maintenance_clear_event)
                    nstate =
                        S_RECOVERY_CLEAR;
            end

            S_RECOVERY_CLEAR:
                nstate =
                    S_IDLE;

            default:
                nstate =
                    S_IDLE;

        endcase
    end

    always_comb begin
        new_transaction = 1'b0;
        cash_enable = 1'b0;

        reserve_ticket_slot = 1'b0;
        release_ticket_slot = 1'b0;
        commit_ticket_registration =
            1'b0;

        start_change_plan = 1'b0;

        start_compensation_plan =
            1'b0;

        abort_planners = 1'b0;

        dispense_change = 1'b0;
        commit_escrow = 1'b0;

        return_escrow = 1'b0;
        rapid_refund_request =
            1'b0;

        dispense_compensation =
            1'b0;

        generate_ticket_id =
            1'b0;

        issue_ticket_request =
            1'b0;

        clear_transaction =
            1'b0;

        manual_settlement =
            1'b0;

        generate_report =
            1'b0;

        recharge_execute =
            1'b0;

        transaction_active =
            1'b0;

        transaction_aborted =
            1'b0;

        payment_timeout_error =
            1'b0;

        operation_timeout_error =
            1'b0;

        service_required =
            1'b0;

        cancel_allowed =
            1'b0;

        case (pstate)

            S_CAPTURE_TRANSACTION,
            S_CALCULATE_FARE,
            S_WAIT_PAYMENT,
            S_VERIFY_PAYMENT,
            S_CHECK_STOCK,
            S_RESERVE_TICKET,
            S_WAIT_RESERVE,
            S_START_CHANGE_PLAN,
            S_WAIT_CHANGE_PLAN,
            S_GENERATE_ID,
            S_COMMIT_CASH,
            S_DISPENSE_CHANGE,
            S_ISSUE_TICKET,
            S_REGISTER_TICKET,
            S_WAIT_REGISTER,
            S_FAKE_NOTE_REJECT,
            S_STORAGE_REJECT,
            S_TICKET_UNAVAILABLE,
            S_TICKET_TABLE_FULL,
            S_CHANGE_UNAVAILABLE,
            S_REFUND_ABORT,
            S_REFUND_SERVICE,
            S_PAYMENT_TIMEOUT,
            S_OPERATION_TIMEOUT,
            S_START_COMPENSATION_PLAN,
            S_WAIT_COMPENSATION_PLAN,
            S_DISPENSE_COMPENSATION,
            S_RAPID_ROLLBACK:
                transaction_active =
                    1'b1;

            default:
                transaction_active =
                    1'b0;

        endcase

        case (pstate)

            S_CAPTURE_TRANSACTION:
                new_transaction =
                    1'b1;

            S_WAIT_PAYMENT: begin
                cash_enable =
                    !rapid_mode;

                cancel_allowed =
                    1'b1;
            end

            S_VERIFY_PAYMENT,
            S_CHECK_STOCK,
            S_WAIT_RESERVE,
            S_WAIT_CHANGE_PLAN:
                cancel_allowed =
                    1'b1;

            S_RESERVE_TICKET:
                reserve_ticket_slot =
                    1'b1;

            S_START_CHANGE_PLAN:
                start_change_plan =
                    1'b1;

            S_GENERATE_ID: begin
                cancel_allowed =
                    1'b1;

                generate_ticket_id =
                    1'b1;
            end

            S_COMMIT_CASH:
                commit_escrow =
                    1'b1;

            S_DISPENSE_CHANGE:
                dispense_change =
                    1'b1;

            S_ISSUE_TICKET:
                issue_ticket_request =
                    1'b1;

            S_REGISTER_TICKET:
                commit_ticket_registration =
                    1'b1;

            S_REFUND_ABORT,
            S_REFUND_SERVICE: begin
                release_ticket_slot =
                    1'b1;

                abort_planners =
                    1'b1;

                if (rapid_mode)
                    rapid_refund_request =
                        1'b1;
                else
                    return_escrow =
                        1'b1;
            end

            S_START_COMPENSATION_PLAN: begin
                release_ticket_slot =
                    1'b1;

                start_compensation_plan =
                    1'b1;
            end

            S_WAIT_COMPENSATION_PLAN:
                release_ticket_slot =
                    1'b1;

            S_DISPENSE_COMPENSATION: begin
                release_ticket_slot =
                    1'b1;

                dispense_compensation =
                    1'b1;
            end

            S_RAPID_ROLLBACK: begin
                release_ticket_slot =
                    1'b1;

                rapid_refund_request =
                    1'b1;
            end

            S_TRANSACTION_DONE:
                clear_transaction =
                    1'b1;

            S_ABORT: begin
                clear_transaction =
                    1'b1;

                release_ticket_slot =
                    1'b1;

                abort_planners =
                    1'b1;

                transaction_aborted =
                    1'b1;
            end

            S_REVENUE_SUMMARY:
                generate_report =
                    1'b1;

            S_RECHARGE_EXECUTE:
                recharge_execute =
                    1'b1;

            S_PAYMENT_TIMEOUT:
                payment_timeout_error =
                    1'b1;

            S_OPERATION_TIMEOUT: begin
                operation_timeout_error =
                    1'b1;

                release_ticket_slot =
                    1'b1;

                abort_planners =
                    1'b1;
            end

            S_SERVICE_ERROR: begin
                service_required =
                    1'b1;

                release_ticket_slot =
                    1'b1;

                transaction_aborted =
                    1'b1;
            end

            S_RECOVERY_CLEAR: begin
                service_required =
                    1'b1;

                clear_transaction =
                    1'b1;

                manual_settlement =
                    1'b1;

                release_ticket_slot =
                    1'b1;

                abort_planners =
                    1'b1;

                transaction_aborted =
                    1'b1;
            end

            default: begin
            end

        endcase

        pstate_code = pstate;
        nstate_code = nstate;
    end

`ifndef SYNTHESIS
    initial begin
        assert (PAYMENT_TIMEOUT_CYCLES > 0)
            else $fatal("PAYMENT_TIMEOUT_CYCLES must be positive");

        assert (INTERNAL_TIMEOUT_CYCLES > 0)
            else $fatal("INTERNAL_TIMEOUT_CYCLES must be positive");

        assert (CHANGE_PLAN_TIMEOUT_CYCLES > 0)
            else $fatal("CHANGE_PLAN_TIMEOUT_CYCLES must be positive");

        assert (COMPENSATION_TIMEOUT_CYCLES > 0)
            else $fatal("COMPENSATION_TIMEOUT_CYCLES must be positive");
    end
`endif

endmodule


module display_controller(
    input  logic [5:0] state_code,

    input  logic [15:0] fare_amount,
    input  logic [15:0] paid_amount,

    input  logic payment_ok,
    input  logic qr_only_mode,
    input  logic low_stock_alert,

    input  logic report_valid,
    input  logic refund_valid,
    input  logic change_valid,
    input  logic compensation_valid,

    input  logic recharge_done,
    input  logic recharge_failed,

    input  logic service_required,
    input  logic ticket_table_full,
    input  logic accounting_overflow,

    output logic [7:0] display_status_code,
    output logic [15:0] display_value
);

    always_comb begin
        display_status_code = 8'h00;
        display_value = 16'd0;

        if (service_required) begin
            display_status_code =
                8'hEF;
        end else if (accounting_overflow) begin
            display_status_code =
                8'hF2;
        end else if (report_valid) begin
            display_status_code =
                8'hA0;
        end else if (recharge_done) begin
            display_status_code =
                8'hA1;
        end else if (recharge_failed) begin
            display_status_code =
                8'hA2;
        end else if (compensation_valid) begin
            display_status_code =
                8'hF1;
        end else if (refund_valid) begin
            display_status_code =
                8'hE6;
        end else if (change_valid) begin
            display_status_code =
                8'h56;
        end else if (ticket_table_full) begin
            display_status_code =
                8'hE5;
        end else begin
            case (state_code)

                6'd17:
                    display_status_code =
                        8'hE4;

                6'd18:
                    display_status_code =
                        8'hE1;

                6'd19:
                    display_status_code =
                        8'hE3;

                6'd20:
                    display_status_code =
                        8'hE2;

                6'd21:
                    display_status_code =
                        8'hED;

                6'd22:
                    display_status_code =
                        8'hEC;

                6'd23,
                6'd24:
                    display_status_code =
                        8'hE5;

                6'd25:
                    display_status_code =
                        8'hE7;

                6'd26,
                6'd27:
                    display_status_code =
                        8'hE6;

                6'd28:
                    display_status_code =
                        8'hE8;

                6'd33:
                    display_status_code =
                        8'hA2;

                6'd34:
                    display_status_code =
                        8'hE9;

                6'd35:
                    display_status_code =
                        8'hEE;

                6'd36,
                6'd37,
                6'd38,
                6'd39:
                    display_status_code =
                        8'hF1;

                6'd40,
                6'd41:
                    display_status_code =
                        8'hEF;

                default: begin
                    if (qr_only_mode)
                        display_status_code =
                            8'hC1;
                    else if (low_stock_alert)
                        display_status_code =
                            8'hB1;
                    else if (payment_ok) begin
                        display_status_code =
                            8'h55;

                        display_value =
                            paid_amount;
                    end else begin
                        display_status_code = {
                            2'b00,
                            state_code
                        };

                        display_value =
                            fare_amount;
                    end
                end

            endcase
        end
    end

endmodule


module smart_ticket_vending_top #(
    parameter bit QR_ENABLED = 1'b1,

    parameter int CLOCKS_PER_TICK = 10,
    parameter int TICKET_EXPIRY_TICKS = 30,

    parameter int PAYMENT_TIMEOUT_CYCLES = 500,
    parameter int INTERNAL_TIMEOUT_CYCLES = 64,
    parameter int CHANGE_PLAN_TIMEOUT_CYCLES = 25000,
    parameter int COMPENSATION_TIMEOUT_CYCLES = 25000,

    parameter int MAX_CHANGE = 500,
    parameter int MAX_COMPENSATION = 500,

    parameter int REQUEST_STABLE_CYCLES = 2,

    parameter int CARD_SLOTS = 16,
    parameter int CARD_ID_WIDTH = 8,

    parameter int MAX_TICKETS = 16
)(
    input  logic clk,
    input  logic rst,

    input  logic start,
    input  logic cancel,
    input  logic closing_btn,
    input  logic maintenance_clear_req,

    input  logic [3:0] source_station,
    input  logic [3:0] destination_station,

    input  logic cash_insert,
    input  logic [9:0] note_value,
    input  logic note_valid_sensor,

    input  logic rapid_mode,

    input  logic card_load,
    input  logic card_tap,

    input  logic [CARD_ID_WIDTH-1:0]
        card_id,

    input  logic [15:0] card_balance,

    input  logic recharge_start,
    input  logic [15:0] recharge_amount,

    input  logic card_issue_request,

    input  logic validate_req,
    input  logic [31:0] scanned_ticket_id,
    input  logic [3:0] gate_station,

    input  logic ticket_device_fault,

    output logic start_ack,
    output logic cancel_ack,
    output logic closing_ack,
    output logic maintenance_clear_ack,

    output logic cash_insert_ack,
    output logic card_load_ack,
    output logic card_tap_ack,
    output logic recharge_ack,
    output logic card_issue_ack,
    output logic validate_ack,

    output logic [3:0] distance,
    output logic [15:0] fare_amount,
    output logic valid_route,

    output logic [15:0] paid_amount,
    output logic payment_ok,
    output logic [15:0] change_amount,
    output logic fake_note_detected,

    output logic ticket_issued,
    output logic physical_ticket_issued,
    output logic digital_ticket_issued,

    output logic [31:0] issued_ticket_id,
    output logic ticket_id_valid,

    output logic gate_open,
    output logic invalid_ticket,
    output logic already_used_ticket,
    output logic expired_ticket,
    output logic wrong_station_ticket,

    output logic ticket_table_full,
    output logic ticket_registration_failed,
    output logic [15:0] active_ticket_count,

    output logic card_issued,
    output logic card_issue_failed,

    output logic card_loaded,
    output logic card_load_done,
    output logic card_load_failed,

    output logic [CARD_ID_WIDTH-1:0]
        active_card_id,

    output logic rapid_payment_ok,
    output logic [15:0] updated_balance,
    output logic low_balance_warning,

    output logic wrong_card_error,
    output logic card_not_loaded_error,

    output logic recharge_done,
    output logic recharge_failed,

    output logic cash_liability_valid,
    output logic [15:0] cash_liability_amount,

    output logic rapid_liability_valid,
    output logic [15:0] rapid_liability_amount,

    output logic [CARD_ID_WIDTH-1:0]
        rapid_liability_card_id,

    output logic escrow_nonempty,
    output logic [15:0] escrow_value,

    output logic [16:0] rec1_count,
    output logic [16:0] rec2_count,
    output logic [16:0] rec3_count,

    output logic [9:0] collection_box1_count,
    output logic [9:0] collection_box2_count,

    output logic rec1_full,
    output logic rec2_full,
    output logic rec3_full,

    output logic collection_safe_warning,
    output logic collection_full,

    output logic [15:0] coin5_count,
    output logic [15:0] note10_count,
    output logic [15:0] note20_count,
    output logic [15:0] note50_count,
    output logic [15:0] note100_count,
    output logic [15:0] note200_count,
    output logic [15:0] note500_count,

    output logic change_plan_busy,
    output logic compensation_plan_busy,

    output logic change_dispensed_valid,
    output logic [15:0] change_dispensed_amount,

    output logic compensation_valid,
    output logic [15:0] compensation_amount,

    output logic refund_valid,
    output logic [15:0] refund_amount,

    output logic [15:0] refund_10_count,
    output logic [15:0] refund_20_count,
    output logic [15:0] refund_50_count,
    output logic [15:0] refund_100_count,
    output logic [15:0] refund_200_count,
    output logic [15:0] refund_500_count,

    output logic [15:0] dispensed_5_count,
    output logic [15:0] dispensed_10_count,
    output logic [15:0] dispensed_20_count,
    output logic [15:0] dispensed_50_count,
    output logic [15:0] dispensed_100_count,
    output logic [15:0] dispensed_200_count,
    output logic [15:0] dispensed_500_count,

    output logic [15:0] compensation_5_count,
    output logic [15:0] compensation_10_count,
    output logic [15:0] compensation_20_count,
    output logic [15:0] compensation_50_count,
    output logic [15:0] compensation_100_count,
    output logic [15:0] compensation_200_count,
    output logic [15:0] compensation_500_count,

    output logic [7:0] paper_stock_count,
    output logic [7:0] card_stock_count,

    output logic low_stock_alert,
    output logic paper_empty,
    output logic card_empty,
    output logic qr_only_mode,

    output logic [31:0] total_revenue,
    output logic [31:0] total_cash_in,
    output logic [31:0] total_change_returned,
    output logic [31:0] total_refunded,
    output logic [31:0] total_recharge_amount,
    output logic [15:0] total_ticket_issued,

    output logic report_valid,
    output logic accounting_overflow,

    output logic transaction_active,
    output logic transaction_aborted,

    output logic payment_timeout_error,
    output logic operation_timeout_error,

    output logic service_required,
    output logic cancel_allowed,

    output logic [7:0] rejected_note_count,

    output logic time_tick,

    output logic [5:0] state_code,
    output logic [5:0] nstate_code,

    output logic [7:0] display_status_code,
    output logic [15:0] display_value
);

    localparam int START_WIDTH = 9;
    localparam int CASH_WIDTH = 11;

    localparam int CARD_LOAD_WIDTH =
        CARD_ID_WIDTH + 16;

    localparam int RECHARGE_WIDTH =
        CARD_ID_WIDTH + 16;

    localparam int VALIDATE_WIDTH = 36;

    logic start_pending;
    logic cancel_pending;
    logic closing_pending;
    logic maintenance_pending;

    logic cash_pending;
    logic card_load_pending;
    logic card_tap_pending;
    logic recharge_pending;
    logic card_issue_pending;
    logic validate_pending;

    logic start_grant;
    logic cancel_grant;
    logic closing_grant;
    logic maintenance_grant;

    logic cash_grant;
    logic card_load_grant;
    logic card_tap_grant;
    logic recharge_grant;
    logic card_issue_grant;
    logic validate_grant;

    logic start_event;
    logic cancel_event;
    logic closing_event;
    logic maintenance_clear_event;

    logic cash_insert_event;
    logic card_load_event;
    logic card_tap_event;
    logic recharge_start_event;
    logic card_issue_event;
    logic validate_event;

    logic [START_WIDTH-1:0]
        start_payload;

    logic [CASH_WIDTH-1:0]
        cash_payload;

    logic [CARD_LOAD_WIDTH-1:0]
        card_load_payload;

    logic [CARD_ID_WIDTH-1:0]
        card_tap_payload;

    logic [RECHARGE_WIDTH-1:0]
        recharge_payload;

    logic [VALIDATE_WIDTH-1:0]
        validate_payload;

    logic [3:0] transaction_source;
    logic [3:0] transaction_destination;
    logic transaction_rapid_mode;

    logic [31:0] transaction_epoch;
    logic [31:0] cash_request_epoch;
    logic [31:0] card_tap_request_epoch;

    logic cash_pending_d;
    logic card_tap_pending_d;

    logic cash_request_context_valid;
    logic card_tap_request_context_valid;

    logic cash_event_for_active_transaction;
    logic card_tap_event_for_active_transaction;
    logic cash_reject_event;

    logic active_cash_request_pending;
    logic active_card_request_pending;
    logic payment_ports_idle;

    logic [CARD_ID_WIDTH-1:0]
        recharge_card_id_reg;

    logic [15:0]
        recharge_amount_reg;

    logic [9:0]
        captured_note_value;

    logic captured_note_valid;

    logic [CARD_ID_WIDTH-1:0]
        captured_load_card_id;

    logic [15:0]
        captured_initial_balance;

    logic [CARD_ID_WIDTH-1:0]
        captured_tap_card_id;

    logic [31:0]
        captured_scanned_ticket_id;

    logic [3:0]
        captured_gate_station;

    logic ticket_device_fault_sync;

    logic idle_state;
    logic service_error_state;
    logic financial_clear;

    logic new_transaction;
    logic cash_enable;

    logic reserve_ticket_slot;
    logic release_ticket_slot;
    logic commit_ticket_registration;

    logic start_change_plan;
    logic start_compensation_plan;
    logic abort_planners;

    logic dispense_change;
    logic commit_escrow;

    logic return_escrow;
    logic rapid_refund_request;

    logic dispense_compensation;

    logic generate_ticket_id;
    logic issue_ticket_request;

    logic clear_transaction;
    logic manual_settlement;

    logic generate_report;
    logic recharge_execute;

    logic note_storage_available;
    logic escrow_commit_possible;

    logic accepted_note_pulse;
    logic [9:0] accepted_note_value;

    logic rejected_note_pulse;
    logic invalid_note_pulse;
    logic storage_reject_pulse;

    logic change_plan_done;
    logic change_possible;

    logic compensation_plan_done;
    logic compensation_possible;

    logic change_done;
    logic change_failed;

    logic commit_done;
    logic commit_failed;

    logic cash_refund_done;
    logic [15:0] cash_refund_amount;

    logic compensation_done;
    logic compensation_failed;

    logic [15:0]
        compensation_dispensed_amount;

    logic [15:0]
        committed_amount;

    logic rapid_refund_done;
    logic [15:0] rapid_refund_amount;

    logic debit_active;

    logic stock_ticket_available;

    logic ticket_issue_done;
    logic ticket_issue_failed;

    logic registry_available;
    logic reserve_done;
    logic reserve_failed;
    logic reservation_active;

    logic registry_commit_done;
    logic registry_commit_failed;

    logic payment_activity;
    logic payment_event_in_flight;
    logic payment_request_busy;
    logic report_clear;

    logic ticket_sale_complete;

    always_comb begin
        idle_state =
            state_code ==
            6'd0;

        service_error_state =
            state_code ==
            6'd40;

        financial_clear =
            !escrow_nonempty &&
            !cash_liability_valid &&
            !rapid_liability_valid;

        payment_ports_idle =
            !cash_pending &&
            !card_tap_pending &&
            !cash_insert_ack &&
            !card_tap_ack &&
            !cash_insert_event &&
            !card_tap_event;

        closing_grant =
            idle_state &&
            financial_clear &&
            payment_ports_idle &&
            closing_pending;

        card_load_grant =
            idle_state &&
            financial_clear &&
            payment_ports_idle &&
            !closing_pending &&
            card_load_pending;

        recharge_grant =
            idle_state &&
            financial_clear &&
            payment_ports_idle &&
            !closing_pending &&
            !card_load_pending &&
            recharge_pending;

        card_issue_grant =
            idle_state &&
            financial_clear &&
            payment_ports_idle &&
            !closing_pending &&
            !card_load_pending &&
            !recharge_pending &&
            card_issue_pending;

        start_grant =
            idle_state &&
            financial_clear &&
            payment_ports_idle &&
            !closing_pending &&
            !card_load_pending &&
            !recharge_pending &&
            !card_issue_pending &&
            start_pending;

        maintenance_grant =
            service_error_state &&
            maintenance_pending;

        active_cash_request_pending =
            cash_pending &&
            transaction_active &&
            !transaction_rapid_mode &&
            state_code == 6'd3 &&
            !payment_ok;

        active_card_request_pending =
            card_tap_pending &&
            transaction_active &&
            transaction_rapid_mode &&
            state_code == 6'd3 &&
            !rapid_payment_ok &&
            !debit_active;

        payment_event_in_flight =
            cash_event_for_active_transaction ||
            card_tap_event_for_active_transaction ||
            accepted_note_pulse ||
            invalid_note_pulse ||
            storage_reject_pulse ||
            wrong_card_error ||
            card_not_loaded_error ||
            low_balance_warning;

        payment_request_busy =
            active_cash_request_pending ||
            active_card_request_pending ||
            payment_event_in_flight;

        cancel_grant =
            cancel_allowed &&
            cancel_pending &&
            !payment_request_busy;

        // All requests are acknowledged so a request cannot leak into a
        // later transaction. Cash events that are not valid for the current
        // payment window are explicitly rejected below.
        cash_grant =
            cash_pending;

        card_tap_grant =
            card_tap_pending;

        validate_grant =
            validate_pending;
    end

    cdc_request_capture #(
        .WIDTH(START_WIDTH),
        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_start_capture (
        .clk(clk),
        .rst(rst),

        .req_async(start),

        .data_async({
            rapid_mode,
            source_station,
            destination_station
        }),

        .accept_enable(
            start_grant
        ),

        .pending(
            start_pending
        ),

        .ack_out(
            start_ack
        ),

        .event_pulse(
            start_event
        ),

        .data_out(
            start_payload
        )
    );

    cdc_request_capture #(
        .WIDTH(1),
        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_cancel_capture (
        .clk(clk),
        .rst(rst),

        .req_async(cancel),
        .data_async(1'b0),

        .accept_enable(
            cancel_grant
        ),

        .pending(
            cancel_pending
        ),

        .ack_out(
            cancel_ack
        ),

        .event_pulse(
            cancel_event
        ),

        .data_out()
    );

    cdc_request_capture #(
        .WIDTH(1),
        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_closing_capture (
        .clk(clk),
        .rst(rst),

        .req_async(
            closing_btn
        ),

        .data_async(1'b0),

        .accept_enable(
            closing_grant
        ),

        .pending(
            closing_pending
        ),

        .ack_out(
            closing_ack
        ),

        .event_pulse(
            closing_event
        ),

        .data_out()
    );

    cdc_request_capture #(
        .WIDTH(1),
        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_maintenance_capture (
        .clk(clk),
        .rst(rst),

        .req_async(
            maintenance_clear_req
        ),

        .data_async(1'b0),

        .accept_enable(
            maintenance_grant
        ),

        .pending(
            maintenance_pending
        ),

        .ack_out(
            maintenance_clear_ack
        ),

        .event_pulse(
            maintenance_clear_event
        ),

        .data_out()
    );

    cdc_request_capture #(
        .WIDTH(CASH_WIDTH),
        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_cash_capture (
        .clk(clk),
        .rst(rst),

        .req_async(
            cash_insert
        ),

        .data_async({
            note_valid_sensor,
            note_value
        }),

        .accept_enable(
            cash_grant
        ),

        .pending(
            cash_pending
        ),

        .ack_out(
            cash_insert_ack
        ),

        .event_pulse(
            cash_insert_event
        ),

        .data_out(
            cash_payload
        )
    );

    cdc_request_capture #(
        .WIDTH(
            CARD_LOAD_WIDTH
        ),

        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_card_load_capture (
        .clk(clk),
        .rst(rst),

        .req_async(
            card_load
        ),

        .data_async({
            card_id,
            card_balance
        }),

        .accept_enable(
            card_load_grant
        ),

        .pending(
            card_load_pending
        ),

        .ack_out(
            card_load_ack
        ),

        .event_pulse(
            card_load_event
        ),

        .data_out(
            card_load_payload
        )
    );

    cdc_request_capture #(
        .WIDTH(
            CARD_ID_WIDTH
        ),

        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_card_tap_capture (
        .clk(clk),
        .rst(rst),

        .req_async(
            card_tap
        ),

        .data_async(
            card_id
        ),

        .accept_enable(
            card_tap_grant
        ),

        .pending(
            card_tap_pending
        ),

        .ack_out(
            card_tap_ack
        ),

        .event_pulse(
            card_tap_event
        ),

        .data_out(
            card_tap_payload
        )
    );

    cdc_request_capture #(
        .WIDTH(
            RECHARGE_WIDTH
        ),

        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_recharge_capture (
        .clk(clk),
        .rst(rst),

        .req_async(
            recharge_start
        ),

        .data_async({
            card_id,
            recharge_amount
        }),

        .accept_enable(
            recharge_grant
        ),

        .pending(
            recharge_pending
        ),

        .ack_out(
            recharge_ack
        ),

        .event_pulse(
            recharge_start_event
        ),

        .data_out(
            recharge_payload
        )
    );

    cdc_request_capture #(
        .WIDTH(1),
        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_card_issue_capture (
        .clk(clk),
        .rst(rst),

        .req_async(
            card_issue_request
        ),

        .data_async(1'b0),

        .accept_enable(
            card_issue_grant
        ),

        .pending(
            card_issue_pending
        ),

        .ack_out(
            card_issue_ack
        ),

        .event_pulse(
            card_issue_event
        ),

        .data_out()
    );

    cdc_request_capture #(
        .WIDTH(
            VALIDATE_WIDTH
        ),

        .STABLE_CYCLES(
            REQUEST_STABLE_CYCLES
        )
    ) u_validate_capture (
        .clk(clk),
        .rst(rst),

        .req_async(
            validate_req
        ),

        .data_async({
            scanned_ticket_id,
            gate_station
        }),

        .accept_enable(
            validate_grant
        ),

        .pending(
            validate_pending
        ),

        .ack_out(
            validate_ack
        ),

        .event_pulse(
            validate_event
        ),

        .data_out(
            validate_payload
        )
    );

    level_synchronizer
    u_ticket_fault_sync (
        .clk(clk),
        .rst(rst),

        .async_in(
            ticket_device_fault
        ),

        .sync_out(
            ticket_device_fault_sync
        )
    );

    always_comb begin
        captured_note_valid =
            cash_payload[10];

        captured_note_value =
            cash_payload[9:0];

        captured_load_card_id =
            card_load_payload[
                CARD_LOAD_WIDTH-1:16
            ];

        captured_initial_balance =
            card_load_payload[15:0];

        captured_tap_card_id =
            card_tap_payload;

        captured_scanned_ticket_id =
            validate_payload[35:4];

        captured_gate_station =
            validate_payload[3:0];

        cash_event_for_active_transaction =
            cash_insert_event &&
            cash_request_context_valid &&
            cash_request_epoch ==
            transaction_epoch &&
            transaction_active &&
            !transaction_rapid_mode &&
            state_code == 6'd3 &&
            !payment_ok;

        cash_reject_event =
            cash_insert_event &&
            !cash_event_for_active_transaction;

        card_tap_event_for_active_transaction =
            card_tap_event &&
            card_tap_request_context_valid &&
            card_tap_request_epoch ==
            transaction_epoch &&
            transaction_active &&
            transaction_rapid_mode &&
            state_code == 6'd3 &&
            !rapid_payment_ok &&
            !debit_active;

        payment_activity =
            active_cash_request_pending ||
            active_card_request_pending ||
            cash_event_for_active_transaction ||
            card_tap_event_for_active_transaction ||
            accepted_note_pulse ||
            invalid_note_pulse ||
            storage_reject_pulse ||
            wrong_card_error ||
            card_not_loaded_error ||
            low_balance_warning;

        ticket_sale_complete =
            registry_commit_done;

        ticket_issued =
            ticket_sale_complete;

        change_dispensed_valid =
            change_done;

        compensation_valid =
            compensation_done;

        compensation_amount =
            compensation_dispensed_amount;

        refund_valid =
            cash_refund_done ||
            rapid_refund_done ||
            compensation_done;

        if (compensation_done)
            refund_amount =
                compensation_dispensed_amount;
        else if (rapid_refund_done)
            refund_amount =
                rapid_refund_amount;
        else
            refund_amount =
                cash_refund_amount;

        report_clear =
            new_transaction ||
            card_load_event ||
            recharge_start_event ||
            card_issue_event ||
            maintenance_clear_event;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            transaction_source <=
                4'd0;

            transaction_destination <=
                4'd0;

            transaction_rapid_mode <=
                1'b0;

            transaction_epoch <=
                32'd0;

            cash_request_epoch <=
                32'd0;

            card_tap_request_epoch <=
                32'd0;

            cash_pending_d <=
                1'b0;

            card_tap_pending_d <=
                1'b0;

            cash_request_context_valid <=
                1'b0;

            card_tap_request_context_valid <=
                1'b0;

            recharge_card_id_reg <=
                '0;

            recharge_amount_reg <=
                16'd0;
        end else begin
            cash_pending_d <=
                cash_pending;

            card_tap_pending_d <=
                card_tap_pending;

            if (cash_insert_event)
                cash_request_context_valid <=
                    1'b0;

            if (card_tap_event)
                card_tap_request_context_valid <=
                    1'b0;

            if (cash_pending && !cash_pending_d) begin
                cash_request_epoch <=
                    transaction_epoch;

                cash_request_context_valid <=
                    transaction_active &&
                    !transaction_rapid_mode &&
                    state_code == 6'd3;
            end

            if (card_tap_pending && !card_tap_pending_d) begin
                card_tap_request_epoch <=
                    transaction_epoch;

                card_tap_request_context_valid <=
                    transaction_active &&
                    transaction_rapid_mode &&
                    state_code == 6'd3;
            end

            if (new_transaction) begin
                transaction_epoch <=
                    transaction_epoch +
                    1'b1;

                cash_request_context_valid <=
                    1'b0;

                card_tap_request_context_valid <=
                    1'b0;

                transaction_rapid_mode <=
                    start_payload[8];

                transaction_source <=
                    start_payload[7:4];

                transaction_destination <=
                    start_payload[3:0];
            end

            if (recharge_start_event) begin
                recharge_card_id_reg <=
                    recharge_payload[
                        RECHARGE_WIDTH-1:16
                    ];

                recharge_amount_reg <=
                    recharge_payload[15:0];
            end

            if (clear_transaction) begin
                cash_request_context_valid <=
                    1'b0;

                card_tap_request_context_valid <=
                    1'b0;

                transaction_rapid_mode <=
                    1'b0;

                transaction_source <=
                    4'd0;

                transaction_destination <=
                    4'd0;
            end
        end
    end

    timebase_generator #(
        .CLOCKS_PER_TICK(
            CLOCKS_PER_TICK
        )
    ) u_timebase (
        .clk(clk),
        .rst(rst),

        .time_tick(
            time_tick
        )
    );

    fare_calculation u_fare (
        .source_station(
            transaction_source
        ),

        .destination_station(
            transaction_destination
        ),

        .distance(distance),
        .fare_amount(fare_amount),
        .valid_route(valid_route)
    );

    payment_controller u_payment (
        .clk(clk),
        .rst(rst),

        .new_transaction(
            new_transaction
        ),

        .clear_transaction(
            clear_transaction
        ),

        .cash_enable(
            cash_enable
        ),

        .cash_insert_event(
            cash_event_for_active_transaction
        ),

        .cash_reject_event(
            cash_reject_event
        ),

        .captured_note_value(
            captured_note_value
        ),

        .captured_note_valid(
            captured_note_valid
        ),

        .note_storage_available(
            note_storage_available
        ),

        .fare_amount(
            fare_amount
        ),

        .paid_amount(
            paid_amount
        ),

        .payment_ok(
            payment_ok
        ),

        .change_amount(
            change_amount
        ),

        .fake_note_detected(
            fake_note_detected
        ),

        .accepted_note_pulse(
            accepted_note_pulse
        ),

        .accepted_note_value(
            accepted_note_value
        ),

        .rejected_note_pulse(
            rejected_note_pulse
        ),

        .invalid_note_pulse(
            invalid_note_pulse
        ),

        .storage_reject_pulse(
            storage_reject_pulse
        ),

        .rejected_note_count(
            rejected_note_count
        )
    );

    cash_inventory_controller #(
        .MAX_CHANGE(
            MAX_CHANGE
        ),

        .MAX_COMPENSATION(
            MAX_COMPENSATION
        )
    ) u_cash_inventory (
        .clk(clk),
        .rst(rst),

        .new_transaction(
            new_transaction
        ),

        .clear_transaction(
            clear_transaction
        ),

        .manual_settlement(
            manual_settlement
        ),

        .accepted_note_pulse(
            accepted_note_pulse
        ),

        .accepted_note_value(
            accepted_note_value
        ),

        .candidate_note_value(
            captured_note_value
        ),

        .start_change_plan(
            start_change_plan
        ),

        .start_compensation_plan(
            start_compensation_plan
        ),

        .abort_planners(
            abort_planners
        ),

        .requested_change(
            change_amount
        ),

        .compensation_amount(
            cash_liability_amount
        ),

        .dispense_change(
            dispense_change
        ),

        .commit_escrow(
            commit_escrow
        ),

        .return_escrow(
            return_escrow
        ),

        .dispense_compensation(
            dispense_compensation
        ),

        .note_storage_available(
            note_storage_available
        ),

        .escrow_commit_possible(
            escrow_commit_possible
        ),

        .escrow_nonempty(
            escrow_nonempty
        ),

        .escrow_value(
            escrow_value
        ),

        .change_plan_busy(
            change_plan_busy
        ),

        .change_plan_done(
            change_plan_done
        ),

        .change_possible(
            change_possible
        ),

        .compensation_plan_busy(
            compensation_plan_busy
        ),

        .compensation_plan_done(
            compensation_plan_done
        ),

        .compensation_possible(
            compensation_possible
        ),

        .change_done(
            change_done
        ),

        .change_failed(
            change_failed
        ),

        .commit_done(
            commit_done
        ),

        .commit_failed(
            commit_failed
        ),

        .refund_done(
            cash_refund_done
        ),

        .compensation_done(
            compensation_done
        ),

        .compensation_failed(
            compensation_failed
        ),

        .committed_amount(
            committed_amount
        ),

        .refund_amount(
            cash_refund_amount
        ),

        .change_dispensed_amount(
            change_dispensed_amount
        ),

        .compensation_dispensed_amount(
            compensation_dispensed_amount
        ),

        .refund_10_count(
            refund_10_count
        ),

        .refund_20_count(
            refund_20_count
        ),

        .refund_50_count(
            refund_50_count
        ),

        .refund_100_count(
            refund_100_count
        ),

        .refund_200_count(
            refund_200_count
        ),

        .refund_500_count(
            refund_500_count
        ),

        .dispensed_5_count(
            dispensed_5_count
        ),

        .dispensed_10_count(
            dispensed_10_count
        ),

        .dispensed_20_count(
            dispensed_20_count
        ),

        .dispensed_50_count(
            dispensed_50_count
        ),

        .dispensed_100_count(
            dispensed_100_count
        ),

        .dispensed_200_count(
            dispensed_200_count
        ),

        .dispensed_500_count(
            dispensed_500_count
        ),

        .compensation_5_count(
            compensation_5_count
        ),

        .compensation_10_count(
            compensation_10_count
        ),

        .compensation_20_count(
            compensation_20_count
        ),

        .compensation_50_count(
            compensation_50_count
        ),

        .compensation_100_count(
            compensation_100_count
        ),

        .compensation_200_count(
            compensation_200_count
        ),

        .compensation_500_count(
            compensation_500_count
        ),

        .rec1_count(rec1_count),
        .rec2_count(rec2_count),
        .rec3_count(rec3_count),

        .collection_box1_count(
            collection_box1_count
        ),

        .collection_box2_count(
            collection_box2_count
        ),

        .rec1_full(rec1_full),
        .rec2_full(rec2_full),
        .rec3_full(rec3_full),

        .collection_safe_warning(
            collection_safe_warning
        ),

        .collection_full(
            collection_full
        ),

        .coin5_count(
            coin5_count
        ),

        .note10_count(
            note10_count
        ),

        .note20_count(
            note20_count
        ),

        .note50_count(
            note50_count
        ),

        .note100_count(
            note100_count
        ),

        .note200_count(
            note200_count
        ),

        .note500_count(
            note500_count
        )
    );

    cash_liability_manager
    u_cash_liability (
        .clk(clk),
        .rst(rst),

        .commit_done(
            commit_done
        ),

        .committed_amount(
            committed_amount
        ),

        .change_done(
            change_done
        ),

        .change_dispensed_amount(
            change_dispensed_amount
        ),

        .compensation_done(
            compensation_done
        ),

        .compensation_dispensed_amount(
            compensation_dispensed_amount
        ),

        .ticket_sale_complete(
            ticket_sale_complete
        ),

        .manual_settlement(
            manual_settlement
        ),

        .cash_liability_valid(
            cash_liability_valid
        ),

        .cash_liability_amount(
            cash_liability_amount
        )
    );

    ticket_stock_monitor #(
        .QR_ENABLED(
            QR_ENABLED
        )
    ) u_stock (
        .clk(clk),
        .rst(rst),

        .issue_ticket_request(
            issue_ticket_request
        ),

        .card_issue_event(
            card_issue_event
        ),

        .ticket_device_fault(
            ticket_device_fault_sync
        ),

        .paper_stock_count(
            paper_stock_count
        ),

        .card_stock_count(
            card_stock_count
        ),

        .low_stock_alert(
            low_stock_alert
        ),

        .paper_empty(
            paper_empty
        ),

        .card_empty(
            card_empty
        ),

        .qr_only_mode(
            qr_only_mode
        ),

        .ticket_available(
            stock_ticket_available
        ),

        .ticket_issue_done(
            ticket_issue_done
        ),

        .ticket_issue_failed(
            ticket_issue_failed
        ),

        .physical_ticket_issued(
            physical_ticket_issued
        ),

        .digital_ticket_issued(
            digital_ticket_issued
        ),

        .card_issued(
            card_issued
        ),

        .card_issue_failed(
            card_issue_failed
        )
    );

    ticket_id_generator
    u_ticket_id (
        .clk(clk),
        .rst(rst),

        .generate_request(
            generate_ticket_id
        ),

        .ticket_id(
            issued_ticket_id
        ),

        .ticket_id_valid(
            ticket_id_valid
        )
    );

    ticket_registry #(
        .MAX_TICKETS(
            MAX_TICKETS
        ),

        .EXPIRY_TICKS(
            TICKET_EXPIRY_TICKS
        )
    ) u_ticket_registry (
        .clk(clk),
        .rst(rst),

        .time_tick(
            time_tick
        ),

        .reserve_request(
            reserve_ticket_slot
        ),

        .release_request(
            release_ticket_slot
        ),

        .reserve_done(
            reserve_done
        ),

        .reserve_failed(
            reserve_failed
        ),

        .reservation_active(
            reservation_active
        ),

        .commit_request(
            commit_ticket_registration
        ),

        .commit_ticket_id(
            issued_ticket_id
        ),

        .commit_destination(
            transaction_destination
        ),

        .registry_commit_done(
            registry_commit_done
        ),

        .registry_commit_failed(
            registry_commit_failed
        ),

        .validate_event(
            validate_event
        ),

        .scanned_ticket_id(
            captured_scanned_ticket_id
        ),

        .gate_station(
            captured_gate_station
        ),

        .registry_available(
            registry_available
        ),

        .ticket_table_full(
            ticket_table_full
        ),

        .ticket_registration_failed(
            ticket_registration_failed
        ),

        .active_ticket_count(
            active_ticket_count
        ),

        .gate_open(
            gate_open
        ),

        .invalid_ticket(
            invalid_ticket
        ),

        .already_used_ticket(
            already_used_ticket
        ),

        .expired_ticket(
            expired_ticket
        ),

        .wrong_station_ticket(
            wrong_station_ticket
        )
    );

    rapid_card_controller #(
        .CARD_SLOTS(
            CARD_SLOTS
        ),

        .CARD_ID_WIDTH(
            CARD_ID_WIDTH
        )
    ) u_rapid_card (
        .clk(clk),
        .rst(rst),

        .card_load_event(
            card_load_event
        ),

        .card_load_allowed(
            idle_state &&
            financial_clear
        ),

        .captured_load_card_id(
            captured_load_card_id
        ),

        .captured_initial_balance(
            captured_initial_balance
        ),

        .new_transaction(
            new_transaction
        ),

        .clear_transaction(
            clear_transaction
        ),

        .manual_settlement(
            manual_settlement
        ),

        .rapid_enable(
            transaction_rapid_mode
        ),

        .card_tap_event(
            card_tap_event_for_active_transaction
        ),

        .captured_tap_card_id(
            captured_tap_card_id
        ),

        .fare_amount(
            fare_amount
        ),

        .rapid_refund_request(
            rapid_refund_request
        ),

        .recharge_execute(
            recharge_execute
        ),

        .recharge_card_id(
            recharge_card_id_reg
        ),

        .recharge_amount(
            recharge_amount_reg
        ),

        .ticket_sale_complete(
            ticket_sale_complete
        ),

        .card_loaded(
            card_loaded
        ),

        .card_load_done(
            card_load_done
        ),

        .card_load_failed(
            card_load_failed
        ),

        .active_card_id(
            active_card_id
        ),

        .updated_balance(
            updated_balance
        ),

        .rapid_payment_ok(
            rapid_payment_ok
        ),

        .low_balance_warning(
            low_balance_warning
        ),

        .debit_active(
            debit_active
        ),

        .wrong_card_error(
            wrong_card_error
        ),

        .card_not_loaded_error(
            card_not_loaded_error
        ),

        .rapid_refund_done(
            rapid_refund_done
        ),

        .rapid_refund_amount(
            rapid_refund_amount
        ),

        .rapid_liability_valid(
            rapid_liability_valid
        ),

        .rapid_liability_amount(
            rapid_liability_amount
        ),

        .rapid_liability_card_id(
            rapid_liability_card_id
        ),

        .recharge_done(
            recharge_done
        ),

        .recharge_failed(
            recharge_failed
        )
    );

    vending_fsm #(
        .PAYMENT_TIMEOUT_CYCLES(
            PAYMENT_TIMEOUT_CYCLES
        ),

        .INTERNAL_TIMEOUT_CYCLES(
            INTERNAL_TIMEOUT_CYCLES
        ),

        .CHANGE_PLAN_TIMEOUT_CYCLES(
            CHANGE_PLAN_TIMEOUT_CYCLES
        ),

        .COMPENSATION_TIMEOUT_CYCLES(
            COMPENSATION_TIMEOUT_CYCLES
        )
    ) u_fsm (
        .clk(clk),
        .rst(rst),

        .start_event(
            start_event
        ),

        .cancel_event(
            cancel_event
        ),

        .cancel_request_pending(
            cancel_pending
        ),

        .closing_event(
            closing_event
        ),

        .recharge_start_event(
            recharge_start_event
        ),

        .maintenance_clear_event(
            maintenance_clear_event
        ),

        .valid_route(
            valid_route
        ),

        .rapid_mode(
            transaction_rapid_mode
        ),

        .payment_ok(
            payment_ok
        ),

        .rapid_payment_ok(
            rapid_payment_ok
        ),

        .wrong_card_error(
            wrong_card_error
        ),

        .card_not_loaded_error(
            card_not_loaded_error
        ),

        .invalid_note_pulse(
            invalid_note_pulse
        ),

        .storage_reject_pulse(
            storage_reject_pulse
        ),

        .payment_activity(
            payment_activity
        ),

        .payment_request_busy(
            payment_request_busy
        ),

        .low_balance_warning(
            low_balance_warning
        ),

        .stock_ticket_available(
            stock_ticket_available
        ),

        .escrow_commit_possible(
            escrow_commit_possible
        ),

        .escrow_nonempty(
            escrow_nonempty
        ),

        .cash_liability_valid(
            cash_liability_valid
        ),

        .rapid_liability_valid(
            rapid_liability_valid
        ),

        .reserve_done(
            reserve_done
        ),

        .reserve_failed(
            reserve_failed
        ),

        .change_plan_done(
            change_plan_done
        ),

        .change_possible(
            change_possible
        ),

        .change_done(
            change_done
        ),

        .change_failed(
            change_failed
        ),

        .commit_done(
            commit_done
        ),

        .commit_failed(
            commit_failed
        ),

        .cash_refund_done(
            cash_refund_done
        ),

        .rapid_refund_done(
            rapid_refund_done
        ),

        .compensation_plan_done(
            compensation_plan_done
        ),

        .compensation_possible(
            compensation_possible
        ),

        .compensation_done(
            compensation_done
        ),

        .compensation_failed(
            compensation_failed
        ),

        .ticket_id_valid(
            ticket_id_valid
        ),

        .ticket_issue_done(
            ticket_issue_done
        ),

        .ticket_issue_failed(
            ticket_issue_failed
        ),

        .registry_commit_done(
            registry_commit_done
        ),

        .registry_commit_failed(
            registry_commit_failed
        ),

        .recharge_done(
            recharge_done
        ),

        .recharge_failed(
            recharge_failed
        ),

        .new_transaction(
            new_transaction
        ),

        .cash_enable(
            cash_enable
        ),

        .reserve_ticket_slot(
            reserve_ticket_slot
        ),

        .release_ticket_slot(
            release_ticket_slot
        ),

        .commit_ticket_registration(
            commit_ticket_registration
        ),

        .start_change_plan(
            start_change_plan
        ),

        .start_compensation_plan(
            start_compensation_plan
        ),

        .abort_planners(
            abort_planners
        ),

        .dispense_change(
            dispense_change
        ),

        .commit_escrow(
            commit_escrow
        ),

        .return_escrow(
            return_escrow
        ),

        .rapid_refund_request(
            rapid_refund_request
        ),

        .dispense_compensation(
            dispense_compensation
        ),

        .generate_ticket_id(
            generate_ticket_id
        ),

        .issue_ticket_request(
            issue_ticket_request
        ),

        .clear_transaction(
            clear_transaction
        ),

        .manual_settlement(
            manual_settlement
        ),

        .generate_report(
            generate_report
        ),

        .recharge_execute(
            recharge_execute
        ),

        .transaction_active(
            transaction_active
        ),

        .transaction_aborted(
            transaction_aborted
        ),

        .payment_timeout_error(
            payment_timeout_error
        ),

        .operation_timeout_error(
            operation_timeout_error
        ),

        .service_required(
            service_required
        ),

        .cancel_allowed(
            cancel_allowed
        ),

        .pstate_code(
            state_code
        ),

        .nstate_code(
            nstate_code
        )
    );

    revenue_report_controller
    u_revenue (
        .clk(clk),
        .rst(rst),

        .cash_commit_done(
            commit_done
        ),

        .cash_committed_amount(
            committed_amount
        ),

        .change_done(
            change_done
        ),

        .change_dispensed_amount(
            change_dispensed_amount
        ),

        .ticket_sale_complete(
            ticket_sale_complete
        ),

        .fare_amount(
            fare_amount
        ),

        .cash_refund_done(
            cash_refund_done
        ),

        .cash_refund_amount(
            cash_refund_amount
        ),

        .compensation_done(
            compensation_done
        ),

        .compensation_amount(
            compensation_dispensed_amount
        ),

        .rapid_refund_done(
            rapid_refund_done
        ),

        .rapid_refund_amount(
            rapid_refund_amount
        ),

        .recharge_done(
            recharge_done
        ),

        .recharge_amount(
            recharge_amount_reg
        ),

        .generate_report(
            generate_report
        ),

        .clear_report(
            report_clear
        ),

        .total_revenue(
            total_revenue
        ),

        .total_cash_in(
            total_cash_in
        ),

        .total_change_returned(
            total_change_returned
        ),

        .total_refunded(
            total_refunded
        ),

        .total_recharge_amount(
            total_recharge_amount
        ),

        .total_ticket_issued(
            total_ticket_issued
        ),

        .report_valid(
            report_valid
        ),

        .accounting_overflow(
            accounting_overflow
        )
    );

    display_controller
    u_display (
        .state_code(
            state_code
        ),

        .fare_amount(
            fare_amount
        ),

        .paid_amount(
            paid_amount
        ),

        .payment_ok(
            payment_ok
        ),

        .qr_only_mode(
            qr_only_mode
        ),

        .low_stock_alert(
            low_stock_alert
        ),

        .report_valid(
            report_valid
        ),

        .refund_valid(
            refund_valid
        ),

        .change_valid(
            change_dispensed_valid
        ),

        .compensation_valid(
            compensation_valid
        ),

        .recharge_done(
            recharge_done
        ),

        .recharge_failed(
            recharge_failed
        ),

        .service_required(
            service_required
        ),

        .ticket_table_full(
            ticket_table_full
        ),

        .accounting_overflow(
            accounting_overflow
        ),

        .display_status_code(
            display_status_code
        ),

        .display_value(
            display_value
        )
    );

`ifndef SYNTHESIS
    initial begin
        assert (MAX_CHANGE >= 5)
            else $fatal("MAX_CHANGE must be at least five");

        assert ((MAX_CHANGE % 5) == 0)
            else $fatal("MAX_CHANGE must be divisible by five");

        assert (MAX_CHANGE <= 65535)
            else $fatal("MAX_CHANGE must fit in requested_change");

        assert (MAX_COMPENSATION >= 5)
            else $fatal("MAX_COMPENSATION must be at least five");

        assert ((MAX_COMPENSATION % 5) == 0)
            else $fatal("MAX_COMPENSATION must be divisible by five");

        assert (MAX_COMPENSATION <= 65535)
            else $fatal("MAX_COMPENSATION must fit in compensation_amount");

        assert (MAX_TICKETS > 0)
            else $fatal("MAX_TICKETS must be positive");

        assert (MAX_TICKETS <= 65535)
            else $fatal("MAX_TICKETS must fit in active_ticket_count");

        assert (CARD_SLOTS > 0)
            else $fatal("CARD_SLOTS must be positive");
    end
`endif

endmodule
