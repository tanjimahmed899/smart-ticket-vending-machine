`timescale 1ns/1ps

package smart_ticket_vending_tb_cfg_pkg;

    parameter int CLK_PERIOD = 10;
    parameter int CLOCKS_PER_TICK_TB = 2;
    parameter int TICKET_EXPIRY_TICKS_TB = 1000;
    parameter int PAYMENT_TIMEOUT_CYCLES_TB = 40;
    parameter int INTERNAL_TIMEOUT_CYCLES_TB = 500;
    parameter int CHANGE_PLAN_TIMEOUT_CYCLES_TB = 20000;
    parameter int COMPENSATION_TIMEOUT_CYCLES_TB = 20000;
    parameter int MAX_CHANGE_TB = 100;
    parameter int MAX_COMPENSATION_TB = 100;
    parameter int REQUEST_STABLE_CYCLES_TB = 2;
    parameter int CARD_SLOTS_TB = 4;
    parameter int CARD_ID_WIDTH_TB = 8;
    parameter int MAX_TICKETS_TB = 8;
    parameter bit RUN_STRICT_SAFETY_TESTS = 1'b1;

    localparam int ACK_START       = 0;
    localparam int ACK_CANCEL      = 1;
    localparam int ACK_CLOSING     = 2;
    localparam int ACK_MAINTENANCE = 3;
    localparam int ACK_CASH        = 4;
    localparam int ACK_CARD_LOAD   = 5;
    localparam int ACK_CARD_TAP    = 6;
    localparam int ACK_RECHARGE    = 7;
    localparam int ACK_CARD_ISSUE  = 8;
    localparam int ACK_VALIDATE    = 9;

    localparam int CNT_TICKET       = 0;
    localparam int CNT_GATE_OPEN     = 1;
    localparam int CNT_INVALID       = 2;
    localparam int CNT_ALREADY_USED  = 3;
    localparam int CNT_EXPIRED       = 4;
    localparam int CNT_WRONG_STATION = 5;
    localparam int CNT_CARD_LOAD     = 6;
    localparam int CNT_RECHARGE      = 7;
    localparam int CNT_REFUND        = 8;
    localparam int CNT_CHANGE        = 9;
    localparam int CNT_COMPENSATION  = 10;
    localparam int CNT_ABORT         = 11;
    localparam int CNT_PAY_TIMEOUT   = 12;
    localparam int CNT_OP_TIMEOUT    = 13;
    localparam int CNT_WRONG_CARD    = 14;
    localparam int CNT_CARD_MISSING  = 15;
    localparam int CNT_LOW_BALANCE   = 16;

endpackage


module smart_ticket_wave_probe(
    input logic clk,
    input logic rst,

    input logic [5:0] state_code,
    input logic [5:0] nstate_code,
    input logic transaction_active,
    input logic transaction_aborted,

    input logic start,
    input logic start_ack,
    input logic cancel,
    input logic cancel_ack,

    input logic [3:0] source_station,
    input logic [3:0] destination_station,
    input logic [3:0] distance,
    input logic [15:0] fare_amount,
    input logic valid_route,

    input logic cash_insert,
    input logic cash_insert_ack,
    input logic [9:0] note_value,
    input logic note_valid_sensor,
    input logic [15:0] paid_amount,
    input logic payment_ok,
    input logic [15:0] change_amount,
    input logic fake_note_detected,
    input logic [7:0] rejected_note_count,

    input logic escrow_nonempty,
    input logic [15:0] escrow_value,
    input logic change_plan_busy,
    input logic change_dispensed_valid,
    input logic [15:0] change_dispensed_amount,
    input logic refund_valid,
    input logic [15:0] refund_amount,

    input logic ticket_id_valid,
    input logic [31:0] issued_ticket_id,
    input logic ticket_issued,
    input logic physical_ticket_issued,
    input logic digital_ticket_issued,
    input logic [7:0] paper_stock_count,
    input logic [15:0] active_ticket_count,

    input logic validate_req,
    input logic validate_ack,
    input logic [31:0] scanned_ticket_id,
    input logic [3:0] gate_station,
    input logic gate_open,
    input logic invalid_ticket,
    input logic already_used_ticket,
    input logic expired_ticket,
    input logic wrong_station_ticket,

    input logic rapid_mode,
    input logic card_load,
    input logic card_load_ack,
    input logic card_tap,
    input logic card_tap_ack,
    input logic [7:0] card_id,
    input logic card_loaded,
    input logic rapid_payment_ok,
    input logic [15:0] updated_balance,
    input logic rapid_liability_valid,
    input logic [15:0] rapid_liability_amount,

    input logic recharge_start,
    input logic recharge_ack,
    input logic recharge_done,

    input logic [31:0] total_revenue,
    input logic [31:0] total_cash_in,
    input logic [31:0] total_change_returned,
    input logic [31:0] total_refunded,
    input logic [31:0] total_recharge_amount,
    input logic [15:0] total_ticket_issued,
    input logic report_valid,

    input logic payment_timeout_error,
    input logic operation_timeout_error,
    input logic service_required,
    input logic [7:0] display_status_code,
    input logic [15:0] display_value
);

endmodule


module smart_ticket_vending_top_tb;

    import smart_ticket_vending_tb_cfg_pkg::*;

    logic clk;
    logic rst;

    logic start;
    logic cancel;
    logic closing_btn;
    logic maintenance_clear_req;

    logic [3:0] source_station;
    logic [3:0] destination_station;

    logic cash_insert;
    logic [9:0] note_value;
    logic note_valid_sensor;

    logic rapid_mode;

    logic card_load;
    logic card_tap;
    logic [CARD_ID_WIDTH_TB-1:0] card_id;
    logic [15:0] card_balance;

    logic recharge_start;
    logic [15:0] recharge_amount;

    logic card_issue_request;

    logic validate_req;
    logic [31:0] scanned_ticket_id;
    logic [3:0] gate_station;

    logic ticket_device_fault;

    logic start_ack;
    logic cancel_ack;
    logic closing_ack;
    logic maintenance_clear_ack;
    logic cash_insert_ack;
    logic card_load_ack;
    logic card_tap_ack;
    logic recharge_ack;
    logic card_issue_ack;
    logic validate_ack;

    logic [3:0] distance;
    logic [15:0] fare_amount;
    logic valid_route;

    logic [15:0] paid_amount;
    logic payment_ok;
    logic [15:0] change_amount;
    logic fake_note_detected;

    logic ticket_issued;
    logic physical_ticket_issued;
    logic digital_ticket_issued;
    logic [31:0] issued_ticket_id;
    logic ticket_id_valid;

    logic gate_open;
    logic invalid_ticket;
    logic already_used_ticket;
    logic expired_ticket;
    logic wrong_station_ticket;

    logic ticket_table_full;
    logic ticket_registration_failed;
    logic [15:0] active_ticket_count;

    logic card_issued;
    logic card_issue_failed;

    logic card_loaded;
    logic card_load_done;
    logic card_load_failed;
    logic [CARD_ID_WIDTH_TB-1:0] active_card_id;

    logic rapid_payment_ok;
    logic [15:0] updated_balance;
    logic low_balance_warning;
    logic wrong_card_error;
    logic card_not_loaded_error;

    logic recharge_done;
    logic recharge_failed;

    logic cash_liability_valid;
    logic [15:0] cash_liability_amount;
    logic rapid_liability_valid;
    logic [15:0] rapid_liability_amount;
    logic [CARD_ID_WIDTH_TB-1:0] rapid_liability_card_id;

    logic escrow_nonempty;
    logic [15:0] escrow_value;

    logic [16:0] rec1_count;
    logic [16:0] rec2_count;
    logic [16:0] rec3_count;

    logic [9:0] collection_box1_count;
    logic [9:0] collection_box2_count;

    logic rec1_full;
    logic rec2_full;
    logic rec3_full;
    logic collection_safe_warning;
    logic collection_full;

    logic [15:0] coin5_count;
    logic [15:0] note10_count;
    logic [15:0] note20_count;
    logic [15:0] note50_count;
    logic [15:0] note100_count;
    logic [15:0] note200_count;
    logic [15:0] note500_count;

    logic change_plan_busy;
    logic compensation_plan_busy;

    logic change_dispensed_valid;
    logic [15:0] change_dispensed_amount;
    logic compensation_valid;
    logic [15:0] compensation_amount;
    logic refund_valid;
    logic [15:0] refund_amount;

    logic [15:0] refund_10_count;
    logic [15:0] refund_20_count;
    logic [15:0] refund_50_count;
    logic [15:0] refund_100_count;
    logic [15:0] refund_200_count;
    logic [15:0] refund_500_count;

    logic [15:0] dispensed_5_count;
    logic [15:0] dispensed_10_count;
    logic [15:0] dispensed_20_count;
    logic [15:0] dispensed_50_count;
    logic [15:0] dispensed_100_count;
    logic [15:0] dispensed_200_count;
    logic [15:0] dispensed_500_count;

    logic [15:0] compensation_5_count;
    logic [15:0] compensation_10_count;
    logic [15:0] compensation_20_count;
    logic [15:0] compensation_50_count;
    logic [15:0] compensation_100_count;
    logic [15:0] compensation_200_count;
    logic [15:0] compensation_500_count;

    logic [7:0] paper_stock_count;
    logic [7:0] card_stock_count;
    logic low_stock_alert;
    logic paper_empty;
    logic card_empty;
    logic qr_only_mode;

    logic [31:0] total_revenue;
    logic [31:0] total_cash_in;
    logic [31:0] total_change_returned;
    logic [31:0] total_refunded;
    logic [31:0] total_recharge_amount;
    logic [15:0] total_ticket_issued;
    logic report_valid;
    logic accounting_overflow;

    logic transaction_active;
    logic transaction_aborted;
    logic payment_timeout_error;
    logic operation_timeout_error;
    logic service_required;
    logic cancel_allowed;
    logic [7:0] rejected_note_count;
    logic time_tick;
    logic [5:0] state_code;
    logic [5:0] nstate_code;
    logic [7:0] display_status_code;
    logic [15:0] display_value;

    integer pass_count;
    integer fail_count;

    integer ticket_count;
    integer gate_open_count;
    integer invalid_ticket_count;
    integer already_used_count;
    integer expired_count;
    integer wrong_station_count;
    integer card_load_count;
    integer recharge_count;
    integer refund_count;
    integer change_count;
    integer compensation_count;
    integer abort_count;
    integer payment_timeout_count;
    integer operation_timeout_count;
    integer wrong_card_count;
    integer card_missing_count;
    integer low_balance_count;

    logic [15:0] last_refund_amount;
    logic [15:0] last_change_amount;
    logic [15:0] last_compensation_amount;
    logic [31:0] sold_ticket_ids [0:31];

    logic [31:0] ticket_1;
    logic [31:0] ticket_2;
    logic [31:0] ticket_3;

    smart_ticket_vending_top #(
        .QR_ENABLED(1'b1),
        .CLOCKS_PER_TICK(CLOCKS_PER_TICK_TB),
        .TICKET_EXPIRY_TICKS(TICKET_EXPIRY_TICKS_TB),
        .PAYMENT_TIMEOUT_CYCLES(PAYMENT_TIMEOUT_CYCLES_TB),
        .INTERNAL_TIMEOUT_CYCLES(INTERNAL_TIMEOUT_CYCLES_TB),
        .CHANGE_PLAN_TIMEOUT_CYCLES(CHANGE_PLAN_TIMEOUT_CYCLES_TB),
        .COMPENSATION_TIMEOUT_CYCLES(COMPENSATION_TIMEOUT_CYCLES_TB),
        .MAX_CHANGE(MAX_CHANGE_TB),
        .MAX_COMPENSATION(MAX_COMPENSATION_TB),
        .REQUEST_STABLE_CYCLES(REQUEST_STABLE_CYCLES_TB),
        .CARD_SLOTS(CARD_SLOTS_TB),
        .CARD_ID_WIDTH(CARD_ID_WIDTH_TB),
        .MAX_TICKETS(MAX_TICKETS_TB)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .cancel(cancel),
        .closing_btn(closing_btn),
        .maintenance_clear_req(maintenance_clear_req),
        .source_station(source_station),
        .destination_station(destination_station),
        .cash_insert(cash_insert),
        .note_value(note_value),
        .note_valid_sensor(note_valid_sensor),
        .rapid_mode(rapid_mode),
        .card_load(card_load),
        .card_tap(card_tap),
        .card_id(card_id),
        .card_balance(card_balance),
        .recharge_start(recharge_start),
        .recharge_amount(recharge_amount),
        .card_issue_request(card_issue_request),
        .validate_req(validate_req),
        .scanned_ticket_id(scanned_ticket_id),
        .gate_station(gate_station),
        .ticket_device_fault(ticket_device_fault),
        .start_ack(start_ack),
        .cancel_ack(cancel_ack),
        .closing_ack(closing_ack),
        .maintenance_clear_ack(maintenance_clear_ack),
        .cash_insert_ack(cash_insert_ack),
        .card_load_ack(card_load_ack),
        .card_tap_ack(card_tap_ack),
        .recharge_ack(recharge_ack),
        .card_issue_ack(card_issue_ack),
        .validate_ack(validate_ack),
        .distance(distance),
        .fare_amount(fare_amount),
        .valid_route(valid_route),
        .paid_amount(paid_amount),
        .payment_ok(payment_ok),
        .change_amount(change_amount),
        .fake_note_detected(fake_note_detected),
        .ticket_issued(ticket_issued),
        .physical_ticket_issued(physical_ticket_issued),
        .digital_ticket_issued(digital_ticket_issued),
        .issued_ticket_id(issued_ticket_id),
        .ticket_id_valid(ticket_id_valid),
        .gate_open(gate_open),
        .invalid_ticket(invalid_ticket),
        .already_used_ticket(already_used_ticket),
        .expired_ticket(expired_ticket),
        .wrong_station_ticket(wrong_station_ticket),
        .ticket_table_full(ticket_table_full),
        .ticket_registration_failed(ticket_registration_failed),
        .active_ticket_count(active_ticket_count),
        .card_issued(card_issued),
        .card_issue_failed(card_issue_failed),
        .card_loaded(card_loaded),
        .card_load_done(card_load_done),
        .card_load_failed(card_load_failed),
        .active_card_id(active_card_id),
        .rapid_payment_ok(rapid_payment_ok),
        .updated_balance(updated_balance),
        .low_balance_warning(low_balance_warning),
        .wrong_card_error(wrong_card_error),
        .card_not_loaded_error(card_not_loaded_error),
        .recharge_done(recharge_done),
        .recharge_failed(recharge_failed),
        .cash_liability_valid(cash_liability_valid),
        .cash_liability_amount(cash_liability_amount),
        .rapid_liability_valid(rapid_liability_valid),
        .rapid_liability_amount(rapid_liability_amount),
        .rapid_liability_card_id(rapid_liability_card_id),
        .escrow_nonempty(escrow_nonempty),
        .escrow_value(escrow_value),
        .rec1_count(rec1_count),
        .rec2_count(rec2_count),
        .rec3_count(rec3_count),
        .collection_box1_count(collection_box1_count),
        .collection_box2_count(collection_box2_count),
        .rec1_full(rec1_full),
        .rec2_full(rec2_full),
        .rec3_full(rec3_full),
        .collection_safe_warning(collection_safe_warning),
        .collection_full(collection_full),
        .coin5_count(coin5_count),
        .note10_count(note10_count),
        .note20_count(note20_count),
        .note50_count(note50_count),
        .note100_count(note100_count),
        .note200_count(note200_count),
        .note500_count(note500_count),
        .change_plan_busy(change_plan_busy),
        .compensation_plan_busy(compensation_plan_busy),
        .change_dispensed_valid(change_dispensed_valid),
        .change_dispensed_amount(change_dispensed_amount),
        .compensation_valid(compensation_valid),
        .compensation_amount(compensation_amount),
        .refund_valid(refund_valid),
        .refund_amount(refund_amount),
        .refund_10_count(refund_10_count),
        .refund_20_count(refund_20_count),
        .refund_50_count(refund_50_count),
        .refund_100_count(refund_100_count),
        .refund_200_count(refund_200_count),
        .refund_500_count(refund_500_count),
        .dispensed_5_count(dispensed_5_count),
        .dispensed_10_count(dispensed_10_count),
        .dispensed_20_count(dispensed_20_count),
        .dispensed_50_count(dispensed_50_count),
        .dispensed_100_count(dispensed_100_count),
        .dispensed_200_count(dispensed_200_count),
        .dispensed_500_count(dispensed_500_count),
        .compensation_5_count(compensation_5_count),
        .compensation_10_count(compensation_10_count),
        .compensation_20_count(compensation_20_count),
        .compensation_50_count(compensation_50_count),
        .compensation_100_count(compensation_100_count),
        .compensation_200_count(compensation_200_count),
        .compensation_500_count(compensation_500_count),
        .paper_stock_count(paper_stock_count),
        .card_stock_count(card_stock_count),
        .low_stock_alert(low_stock_alert),
        .paper_empty(paper_empty),
        .card_empty(card_empty),
        .qr_only_mode(qr_only_mode),
        .total_revenue(total_revenue),
        .total_cash_in(total_cash_in),
        .total_change_returned(total_change_returned),
        .total_refunded(total_refunded),
        .total_recharge_amount(total_recharge_amount),
        .total_ticket_issued(total_ticket_issued),
        .report_valid(report_valid),
        .accounting_overflow(accounting_overflow),
        .transaction_active(transaction_active),
        .transaction_aborted(transaction_aborted),
        .payment_timeout_error(payment_timeout_error),
        .operation_timeout_error(operation_timeout_error),
        .service_required(service_required),
        .cancel_allowed(cancel_allowed),
        .rejected_note_count(rejected_note_count),
        .time_tick(time_tick),
        .state_code(state_code),
        .nstate_code(nstate_code),
        .display_status_code(display_status_code),
        .display_value(display_value)
    );

    smart_ticket_wave_probe wave_probe (
        .clk(clk),
        .rst(rst),
        .state_code(state_code),
        .nstate_code(nstate_code),
        .transaction_active(transaction_active),
        .transaction_aborted(transaction_aborted),
        .start(start),
        .start_ack(start_ack),
        .cancel(cancel),
        .cancel_ack(cancel_ack),
        .source_station(source_station),
        .destination_station(destination_station),
        .distance(distance),
        .fare_amount(fare_amount),
        .valid_route(valid_route),
        .cash_insert(cash_insert),
        .cash_insert_ack(cash_insert_ack),
        .note_value(note_value),
        .note_valid_sensor(note_valid_sensor),
        .paid_amount(paid_amount),
        .payment_ok(payment_ok),
        .change_amount(change_amount),
        .fake_note_detected(fake_note_detected),
        .rejected_note_count(rejected_note_count),
        .escrow_nonempty(escrow_nonempty),
        .escrow_value(escrow_value),
        .change_plan_busy(change_plan_busy),
        .change_dispensed_valid(change_dispensed_valid),
        .change_dispensed_amount(change_dispensed_amount),
        .refund_valid(refund_valid),
        .refund_amount(refund_amount),
        .ticket_id_valid(ticket_id_valid),
        .issued_ticket_id(issued_ticket_id),
        .ticket_issued(ticket_issued),
        .physical_ticket_issued(physical_ticket_issued),
        .digital_ticket_issued(digital_ticket_issued),
        .paper_stock_count(paper_stock_count),
        .active_ticket_count(active_ticket_count),
        .validate_req(validate_req),
        .validate_ack(validate_ack),
        .scanned_ticket_id(scanned_ticket_id),
        .gate_station(gate_station),
        .gate_open(gate_open),
        .invalid_ticket(invalid_ticket),
        .already_used_ticket(already_used_ticket),
        .expired_ticket(expired_ticket),
        .wrong_station_ticket(wrong_station_ticket),
        .rapid_mode(rapid_mode),
        .card_load(card_load),
        .card_load_ack(card_load_ack),
        .card_tap(card_tap),
        .card_tap_ack(card_tap_ack),
        .card_id(card_id),
        .card_loaded(card_loaded),
        .rapid_payment_ok(rapid_payment_ok),
        .updated_balance(updated_balance),
        .rapid_liability_valid(rapid_liability_valid),
        .rapid_liability_amount(rapid_liability_amount),
        .recharge_start(recharge_start),
        .recharge_ack(recharge_ack),
        .recharge_done(recharge_done),
        .total_revenue(total_revenue),
        .total_cash_in(total_cash_in),
        .total_change_returned(total_change_returned),
        .total_refunded(total_refunded),
        .total_recharge_amount(total_recharge_amount),
        .total_ticket_issued(total_ticket_issued),
        .report_valid(report_valid),
        .payment_timeout_error(payment_timeout_error),
        .operation_timeout_error(operation_timeout_error),
        .service_required(service_required),
        .display_status_code(display_status_code),
        .display_value(display_value)
    );

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin : waveform_capture
        $shm_open("smart_ticket_vending_v6.shm");
        $shm_probe("AS", smart_ticket_vending_top_tb.wave_probe);
        $shm_probe("AS", smart_ticket_vending_top_tb.dut);

        $dumpfile("smart_ticket_vending_v6.vcd");
        $dumpvars(0, smart_ticket_vending_top_tb.wave_probe);
        $dumpvars(0, smart_ticket_vending_top_tb.dut);
    end

    always @(posedge ticket_issued) begin
        sold_ticket_ids[ticket_count] = issued_ticket_id;
        ticket_count = ticket_count + 1;
    end

    always @(posedge gate_open)
        gate_open_count = gate_open_count + 1;

    always @(posedge invalid_ticket)
        invalid_ticket_count = invalid_ticket_count + 1;

    always @(posedge already_used_ticket)
        already_used_count = already_used_count + 1;

    always @(posedge expired_ticket)
        expired_count = expired_count + 1;

    always @(posedge wrong_station_ticket)
        wrong_station_count = wrong_station_count + 1;

    always @(posedge card_load_done)
        card_load_count = card_load_count + 1;

    always @(posedge recharge_done)
        recharge_count = recharge_count + 1;

    always @(posedge refund_valid) begin
        last_refund_amount = refund_amount;
        refund_count = refund_count + 1;
    end

    always @(posedge change_dispensed_valid) begin
        last_change_amount = change_dispensed_amount;
        change_count = change_count + 1;
    end

    always @(posedge compensation_valid) begin
        last_compensation_amount = compensation_amount;
        compensation_count = compensation_count + 1;
    end

    always @(posedge transaction_aborted)
        abort_count = abort_count + 1;

    always @(posedge payment_timeout_error)
        payment_timeout_count = payment_timeout_count + 1;

    always @(posedge operation_timeout_error)
        operation_timeout_count = operation_timeout_count + 1;

    always @(posedge wrong_card_error)
        wrong_card_count = wrong_card_count + 1;

    always @(posedge card_not_loaded_error)
        card_missing_count = card_missing_count + 1;

    always @(posedge low_balance_warning)
        low_balance_count = low_balance_count + 1;

    logic [5:0] previous_state_code;
    integer generate_id_wait_cycles;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            previous_state_code <= 6'h3F;
            generate_id_wait_cycles <= 0;
        end else begin
            if (state_code == 6'd10) begin
                if (ticket_id_valid) begin
                    generate_id_wait_cycles <= 0;
                end else begin
                    generate_id_wait_cycles <= generate_id_wait_cycles + 1;

                    if (generate_id_wait_cycles >= 20) begin
                        $display(
                            "[DIAG] Ticket-ID handshake stalled: request=%0b serviced=%0b valid=%0b id=%0d sequence=%0d",
                            dut.generate_ticket_id,
                            dut.u_ticket_id.request_serviced,
                            ticket_id_valid,
                            issued_ticket_id,
                            dut.u_ticket_id.sequence_counter
                        );
                        $fatal(1, "Ticket-ID generator did not acknowledge state 10");
                    end
                end
            end else begin
                generate_id_wait_cycles <= 0;
            end
            if (state_code != previous_state_code) begin
                $display(
                    "[TRACE] t=%0t state %0d -> %0d, next=%0d paid=%0d fare=%0d escrow=%0d",
                    $time,
                    previous_state_code,
                    state_code,
                    nstate_code,
                    paid_amount,
                    fare_amount,
                    escrow_value
                );
                previous_state_code <= state_code;
            end

            if (operation_timeout_error) begin
                $display(
                    "[DIAG] Operation timeout: state=%0d next=%0d change_busy=%0b change_done=%0b compensation_busy=%0b",
                    state_code,
                    nstate_code,
                    change_plan_busy,
                    change_dispensed_valid,
                    compensation_plan_busy
                );
            end

            if (service_required && previous_state_code != 6'd40) begin
                $display(
                    "[DIAG] SERVICE_ERROR entry: state=%0d next=%0d timeout_source=%0d escrow=%0d cash_liability=%0b/%0d rapid_liability=%0b/%0d",
                    state_code,
                    nstate_code,
                    dut.u_fsm.timeout_source_state,
                    escrow_value,
                    cash_liability_valid,
                    cash_liability_amount,
                    rapid_liability_valid,
                    rapid_liability_amount
                );

                $display(
                    "[DIAG] change planner: state=%0d busy=%0b done=%0b possible=%0b requested=%0d use5=%0d use10=%0d use20=%0d use50=%0d",
                    dut.u_cash_inventory.u_change_planner.pstate,
                    change_plan_busy,
                    dut.change_plan_done,
                    dut.change_possible,
                    change_amount,
                    dut.u_cash_inventory.change_use_5,
                    dut.u_cash_inventory.change_use_10,
                    dut.u_cash_inventory.change_use_20,
                    dut.u_cash_inventory.change_use_50
                );

                $display(
                    "[DIAG] ticket ID: request=%0b serviced=%0b valid=%0b id=%0d sequence=%0d",
                    dut.generate_ticket_id,
                    dut.u_ticket_id.request_serviced,
                    ticket_id_valid,
                    issued_ticket_id,
                    dut.u_ticket_id.sequence_counter
                );

                $display(
                    "[DIAG] failure pulses: change_failed=%0b commit_failed=%0b ticket_issue_failed=%0b registry_commit_failed=%0b compensation_failed=%0b",
                    dut.change_failed,
                    dut.commit_failed,
                    dut.ticket_issue_failed,
                    dut.registry_commit_failed,
                    dut.compensation_failed
                );

                $fatal(1, "Unexpected SERVICE_ERROR during self-checking tests");
            end
        end
    end

    function automatic logic ack_value(input integer ack_id);
        begin
            case (ack_id)
                ACK_START:       ack_value = start_ack;
                ACK_CANCEL:      ack_value = cancel_ack;
                ACK_CLOSING:     ack_value = closing_ack;
                ACK_MAINTENANCE: ack_value = maintenance_clear_ack;
                ACK_CASH:        ack_value = cash_insert_ack;
                ACK_CARD_LOAD:   ack_value = card_load_ack;
                ACK_CARD_TAP:    ack_value = card_tap_ack;
                ACK_RECHARGE:    ack_value = recharge_ack;
                ACK_CARD_ISSUE:  ack_value = card_issue_ack;
                ACK_VALIDATE:    ack_value = validate_ack;
                default:         ack_value = 1'bx;
            endcase
        end
    endfunction

    function automatic integer counter_value(input integer counter_id);
        begin
            case (counter_id)
                CNT_TICKET:        counter_value = ticket_count;
                CNT_GATE_OPEN:      counter_value = gate_open_count;
                CNT_INVALID:        counter_value = invalid_ticket_count;
                CNT_ALREADY_USED:   counter_value = already_used_count;
                CNT_EXPIRED:        counter_value = expired_count;
                CNT_WRONG_STATION:  counter_value = wrong_station_count;
                CNT_CARD_LOAD:      counter_value = card_load_count;
                CNT_RECHARGE:       counter_value = recharge_count;
                CNT_REFUND:         counter_value = refund_count;
                CNT_CHANGE:         counter_value = change_count;
                CNT_COMPENSATION:   counter_value = compensation_count;
                CNT_ABORT:          counter_value = abort_count;
                CNT_PAY_TIMEOUT:    counter_value = payment_timeout_count;
                CNT_OP_TIMEOUT:     counter_value = operation_timeout_count;
                CNT_WRONG_CARD:     counter_value = wrong_card_count;
                CNT_CARD_MISSING:   counter_value = card_missing_count;
                CNT_LOW_BALANCE:    counter_value = low_balance_count;
                default:            counter_value = -1;
            endcase
        end
    endfunction

    task automatic check_true(
        input logic condition,
        input string message
    );
        begin
            if (condition === 1'b1) begin
                pass_count = pass_count + 1;
                $display("[PASS] %s", message);
            end else begin
                fail_count = fail_count + 1;
                $error("[FAIL] %s", message);
            end
        end
    endtask

    task automatic check_value(
        input logic [63:0] actual,
        input logic [63:0] expected,
        input string message
    );
        begin
            if (actual === expected) begin
                pass_count = pass_count + 1;
                $display("[PASS] %s: %0d", message, actual);
            end else begin
                fail_count = fail_count + 1;
                $error(
                    "[FAIL] %s: expected=%0d actual=%0d",
                    message,
                    expected,
                    actual
                );
            end
        end
    endtask

    task automatic wait_ack_level(
        input integer ack_id,
        input logic expected_level,
        input integer max_cycles,
        input string request_name
    );
        integer cycle_index;
        begin
            for (cycle_index = 0;
                 cycle_index < max_cycles;
                 cycle_index = cycle_index + 1) begin
                @(negedge clk);
                if (ack_value(ack_id) === expected_level)
                    return;
            end

            fail_count = fail_count + 1;
            $fatal(
                1,
                "[FAIL] Timeout waiting for %s ack=%0b; state=%0d next=%0d",
                request_name,
                expected_level,
                state_code,
                nstate_code
            );
        end
    endtask

    task automatic wait_counter_at_least(
        input integer counter_id,
        input integer target_value,
        input integer max_cycles,
        input string event_name
    );
        integer cycle_index;
        begin
            for (cycle_index = 0;
                 cycle_index < max_cycles;
                 cycle_index = cycle_index + 1) begin
                @(negedge clk);
                if (counter_value(counter_id) >= target_value)
                    return;
            end

            fail_count = fail_count + 1;
            $fatal(
                1,
                "[FAIL] Timeout waiting for %s count=%0d, actual=%0d; state=%0d next=%0d",
                event_name,
                target_value,
                counter_value(counter_id),
                state_code,
                nstate_code
            );
        end
    endtask

    task automatic wait_for_state(
        input logic [5:0] expected_state,
        input integer max_cycles,
        input string state_name
    );
        integer cycle_index;
        begin
            for (cycle_index = 0;
                 cycle_index < max_cycles;
                 cycle_index = cycle_index + 1) begin
                @(negedge clk);
                if (state_code === expected_state)
                    return;
            end

            fail_count = fail_count + 1;
            $fatal(
                1,
                "[FAIL] Timeout waiting for state %s (%0d), current=%0d next=%0d",
                state_name,
                expected_state,
                state_code,
                nstate_code
            );
        end
    endtask

    task automatic wait_for_idle(input integer max_cycles);
        integer cycle_index;
        begin
            for (cycle_index = 0;
                 cycle_index < max_cycles;
                 cycle_index = cycle_index + 1) begin
                @(negedge clk);
                if ((state_code === 6'd0) && !transaction_active)
                    return;
            end

            fail_count = fail_count + 1;
            $fatal(
                1,
                "[FAIL] Timeout waiting for IDLE, current state=%0d next=%0d",
                state_code,
                nstate_code
            );
        end
    endtask

    task automatic wait_paid_amount(
        input logic [15:0] expected_amount,
        input integer max_cycles
    );
        integer cycle_index;
        begin
            for (cycle_index = 0;
                 cycle_index < max_cycles;
                 cycle_index = cycle_index + 1) begin
                @(negedge clk);
                if (paid_amount === expected_amount)
                    return;
            end

            fail_count = fail_count + 1;
            $fatal(
                1,
                "[FAIL] Timeout waiting for paid_amount=%0d, actual=%0d; state=%0d",
                expected_amount,
                paid_amount,
                state_code
            );
        end
    endtask

    task automatic wait_rapid_payment_ok(input integer max_cycles);
        integer cycle_index;
        begin
            for (cycle_index = 0;
                 cycle_index < max_cycles;
                 cycle_index = cycle_index + 1) begin
                @(negedge clk);
                if (rapid_payment_ok === 1'b1)
                    return;
            end

            fail_count = fail_count + 1;
            $fatal(
                1,
                "[FAIL] Timeout waiting for rapid_payment_ok; state=%0d next=%0d",
                state_code,
                nstate_code
            );
        end
    endtask

    task automatic send_start_request(
        input logic requested_rapid_mode,
        input logic [3:0] requested_source,
        input logic [3:0] requested_destination
    );
        begin
            @(negedge clk);
            rapid_mode = requested_rapid_mode;
            source_station = requested_source;
            destination_station = requested_destination;
            start = 1'b1;

            wait_ack_level(ACK_START, 1'b1, 100, "start");

            @(negedge clk);
            start = 1'b0;

            wait_ack_level(ACK_START, 1'b0, 100, "start release");
        end
    endtask

    task automatic send_cancel_request;
        begin
            @(negedge clk);
            cancel = 1'b1;

            wait_ack_level(ACK_CANCEL, 1'b1, 200, "cancel");

            @(negedge clk);
            cancel = 1'b0;

            wait_ack_level(ACK_CANCEL, 1'b0, 100, "cancel release");
        end
    endtask

    task automatic send_closing_request;
        begin
            @(negedge clk);
            closing_btn = 1'b1;

            wait_ack_level(ACK_CLOSING, 1'b1, 100, "closing");

            @(negedge clk);
            closing_btn = 1'b0;

            wait_ack_level(ACK_CLOSING, 1'b0, 100, "closing release");
        end
    endtask

    task automatic send_cash_request(
        input logic [9:0] requested_note_value,
        input logic requested_sensor_valid
    );
        begin
            @(negedge clk);
            note_value = requested_note_value;
            note_valid_sensor = requested_sensor_valid;
            cash_insert = 1'b1;

            wait_ack_level(ACK_CASH, 1'b1, 100, "cash insert");

            @(negedge clk);
            cash_insert = 1'b0;

            wait_ack_level(ACK_CASH, 1'b0, 100, "cash insert release");
        end
    endtask

    task automatic send_card_load_request(
        input logic [CARD_ID_WIDTH_TB-1:0] requested_card_id,
        input logic [15:0] requested_balance
    );
        begin
            @(negedge clk);
            card_id = requested_card_id;
            card_balance = requested_balance;
            card_load = 1'b1;

            wait_ack_level(ACK_CARD_LOAD, 1'b1, 100, "card load");

            @(negedge clk);
            card_load = 1'b0;

            wait_ack_level(ACK_CARD_LOAD, 1'b0, 100, "card load release");
        end
    endtask

    task automatic send_card_tap_request(
        input logic [CARD_ID_WIDTH_TB-1:0] requested_card_id
    );
        begin
            @(negedge clk);
            card_id = requested_card_id;
            card_tap = 1'b1;

            wait_ack_level(ACK_CARD_TAP, 1'b1, 100, "card tap");

            @(negedge clk);
            card_tap = 1'b0;

            wait_ack_level(ACK_CARD_TAP, 1'b0, 100, "card tap release");
        end
    endtask

    task automatic send_recharge_request(
        input logic [CARD_ID_WIDTH_TB-1:0] requested_card_id,
        input logic [15:0] requested_recharge_amount
    );
        begin
            @(negedge clk);
            card_id = requested_card_id;
            recharge_amount = requested_recharge_amount;
            recharge_start = 1'b1;

            wait_ack_level(ACK_RECHARGE, 1'b1, 100, "recharge");

            @(negedge clk);
            recharge_start = 1'b0;

            wait_ack_level(ACK_RECHARGE, 1'b0, 100, "recharge release");
        end
    endtask

    task automatic send_validate_request(
        input logic [31:0] requested_ticket_id,
        input logic [3:0] requested_gate_station
    );
        begin
            @(negedge clk);
            scanned_ticket_id = requested_ticket_id;
            gate_station = requested_gate_station;
            validate_req = 1'b1;

            wait_ack_level(ACK_VALIDATE, 1'b1, 100, "ticket validation");

            @(negedge clk);
            validate_req = 1'b0;

            wait_ack_level(ACK_VALIDATE, 1'b0, 100, "validation release");
        end
    endtask

    task automatic initialize_inputs;
        integer array_index;
        begin
            start = 1'b0;
            cancel = 1'b0;
            closing_btn = 1'b0;
            maintenance_clear_req = 1'b0;
            source_station = 4'd0;
            destination_station = 4'd0;
            cash_insert = 1'b0;
            note_value = 10'd0;
            note_valid_sensor = 1'b0;
            rapid_mode = 1'b0;
            card_load = 1'b0;
            card_tap = 1'b0;
            card_id = '0;
            card_balance = 16'd0;
            recharge_start = 1'b0;
            recharge_amount = 16'd0;
            card_issue_request = 1'b0;
            validate_req = 1'b0;
            scanned_ticket_id = 32'd0;
            gate_station = 4'd0;
            ticket_device_fault = 1'b0;

            pass_count = 0;
            fail_count = 0;
            ticket_count = 0;
            gate_open_count = 0;
            invalid_ticket_count = 0;
            already_used_count = 0;
            expired_count = 0;
            wrong_station_count = 0;
            card_load_count = 0;
            recharge_count = 0;
            refund_count = 0;
            change_count = 0;
            compensation_count = 0;
            abort_count = 0;
            payment_timeout_count = 0;
            operation_timeout_count = 0;
            wrong_card_count = 0;
            card_missing_count = 0;
            low_balance_count = 0;
            last_refund_amount = 16'd0;
            last_change_amount = 16'd0;
            last_compensation_amount = 16'd0;
            ticket_1 = 32'd0;
            ticket_2 = 32'd0;
            ticket_3 = 32'd0;

            for (array_index = 0;
                 array_index < 32;
                 array_index = array_index + 1)
                sold_ticket_ids[array_index] = 32'd0;
        end
    endtask

    initial begin : main_test_sequence
        integer previous_count;
        integer previous_abort_count;
        integer previous_refund_count;
        integer previous_ticket_count;
        integer previous_wrong_card_count;
        integer previous_low_balance_count;
        integer previous_timeout_count;
        integer previous_gate_count;
        integer previous_wrong_station_count;
        integer previous_used_count;
        integer previous_expired_count;
        integer previous_recharge_count;
        integer previous_card_load_count;

        initialize_inputs();

        rst = 1'b1;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (3) @(posedge clk);

        $display("\n============================================================");
        $display("SMART TICKET VENDING MACHINE SELF-CHECKING TESTBENCH");
        $display("============================================================\n");

        check_value(state_code, 6'd0, "Reset state is IDLE");
        check_value(paper_stock_count, 8'd10, "Initial paper stock");
        check_value(card_stock_count, 8'd5, "Initial card stock");
        check_value(rec1_count, 17'd20, "Initial recycler 1 count");
        check_value(rec2_count, 17'd40, "Initial recycler 2 count");
        check_value(rec3_count, 17'd7, "Initial recycler 3 count");
        check_true(!escrow_nonempty, "Escrow is initially empty");

        $display("\n[TEST 1] Idle cash request is drained and cannot leak");
        previous_count = rejected_note_count;
        previous_refund_count = refund_count;
        send_cash_request(10'd10, 1'b1);
        repeat (5) @(posedge clk);
        check_value(paid_amount, 16'd0, "Idle cash request did not alter paid amount");
        check_true(!escrow_nonempty, "Idle cash request did not enter escrow");
        check_value(state_code, 6'd0, "Machine remained IDLE after idle cash request");

        if (RUN_STRICT_SAFETY_TESTS) begin
            check_true(
                (rejected_note_count > previous_count) ||
                (refund_count > previous_refund_count),
                "Acknowledged idle cash request produced an explicit reject or return"
            );
        end

        $display("\n[TEST 2] Cash sale, invalid note, change and ticket validation");
        send_start_request(1'b0, 4'd0, 4'd1);
        wait_for_state(6'd3, 100, "WAIT_PAYMENT");
        check_value(distance, 4'd1, "Cash route distance");
        check_value(fare_amount, 16'd25, "Cash route fare");
        check_value(paid_amount, 16'd0, "No stale cash entered new transaction");

        send_cash_request(10'd30, 1'b1);
        repeat (6) @(posedge clk);
        check_value(rejected_note_count, 8'd1, "Invalid denomination rejection count");
        check_true(fake_note_detected, "Invalid denomination raised fake-note indication");
        wait_for_state(6'd3, 100, "WAIT_PAYMENT after invalid note");

        send_cash_request(10'd20, 1'b1);
        wait_paid_amount(16'd20, 50);
        send_cash_request(10'd10, 1'b1);

        previous_ticket_count = ticket_count;
        previous_count = change_count;
        wait_counter_at_least(CNT_TICKET, previous_ticket_count + 1, 25000, "cash ticket issue");
        wait_counter_at_least(CNT_CHANGE, previous_count + 1, 25000, "cash change dispense");
        wait_for_idle(200);

        ticket_1 = sold_ticket_ids[previous_ticket_count];
        check_true(ticket_1 != 32'd0, "First ticket received a non-zero ID");
        check_value(last_change_amount, 16'd5, "First sale change amount");
        check_value(total_revenue, 32'd25, "Revenue after first sale");
        check_value(total_cash_in, 32'd30, "Cash-in after first sale");
        check_value(total_change_returned, 32'd5, "Returned change after first sale");
        check_value(total_ticket_issued, 16'd1, "Ticket count after first sale");
        check_value(paper_stock_count, 8'd9, "Paper stock after first sale");

        previous_wrong_station_count = wrong_station_count;
        send_validate_request(ticket_1, 4'd2);
        wait_counter_at_least(
            CNT_WRONG_STATION,
            previous_wrong_station_count + 1,
            100,
            "wrong-station validation"
        );

        previous_gate_count = gate_open_count;
        send_validate_request(ticket_1, 4'd1);
        wait_counter_at_least(
            CNT_GATE_OPEN,
            previous_gate_count + 1,
            100,
            "valid ticket gate open"
        );

        previous_used_count = already_used_count;
        send_validate_request(ticket_1, 4'd1);
        wait_counter_at_least(
            CNT_ALREADY_USED,
            previous_used_count + 1,
            100,
            "already-used ticket detection"
        );

        $display("\n[TEST 3] Cash cancellation refunds escrow");
        send_start_request(1'b0, 4'd0, 4'd5);
        wait_for_state(6'd3, 100, "WAIT_PAYMENT");
        check_value(fare_amount, 16'd45, "Cancellation test fare");
        send_cash_request(10'd20, 1'b1);
        wait_paid_amount(16'd20, 50);
        repeat (3) @(posedge clk);

        previous_refund_count = refund_count;
        previous_abort_count = abort_count;
        send_cancel_request();
        wait_counter_at_least(CNT_REFUND, previous_refund_count + 1, 200, "cash refund");
        wait_counter_at_least(CNT_ABORT, previous_abort_count + 1, 200, "cancel abort");
        wait_for_idle(200);

        check_value(last_refund_amount, 16'd20, "Cancelled cash refund amount");
        check_value(refund_20_count, 16'd1, "Refunded 20-value note count");
        check_true(!escrow_nonempty, "Escrow cleared after cancellation");
        check_value(total_refunded, 32'd20, "Refund accounting after cancellation");
        check_value(total_revenue, 32'd25, "Cancellation did not change revenue");

        $display("\n[TEST 4] Payment timeout without inserted funds");
        send_start_request(1'b0, 4'd0, 4'd2);
        wait_for_state(6'd3, 100, "WAIT_PAYMENT");
        previous_timeout_count = payment_timeout_count;
        previous_abort_count = abort_count;
        wait_counter_at_least(
            CNT_PAY_TIMEOUT,
            previous_timeout_count + 1,
            PAYMENT_TIMEOUT_CYCLES_TB + 30,
            "payment timeout"
        );
        wait_counter_at_least(CNT_ABORT, previous_abort_count + 1, 100, "timeout abort");
        wait_for_idle(100);
        check_value(total_refunded, 32'd20, "Empty timeout did not create refund");

        $display("\n[TEST 5] Second cash sale with change");
        send_start_request(1'b0, 4'd2, 4'd6);
        wait_for_state(6'd3, 100, "WAIT_PAYMENT");
        check_value(fare_amount, 16'd40, "Second cash-sale fare");
        send_cash_request(10'd50, 1'b1);

        previous_ticket_count = ticket_count;
        previous_count = change_count;
        wait_counter_at_least(CNT_TICKET, previous_ticket_count + 1, 25000, "second cash ticket");
        wait_counter_at_least(CNT_CHANGE, previous_count + 1, 25000, "second cash change");
        wait_for_idle(200);

        ticket_2 = sold_ticket_ids[previous_ticket_count];
        check_value(last_change_amount, 16'd10, "Second sale change amount");
        check_value(total_revenue, 32'd65, "Revenue after two completed cash sales");
        check_value(total_cash_in, 32'd80, "Cash-in after two completed cash sales");
        check_value(total_change_returned, 32'd15, "Cumulative returned change");
        check_value(total_ticket_issued, 16'd2, "Ticket count after two cash sales");

        $display("\n[TEST 6] Load card and perform rapid-card sale");
        previous_card_load_count = card_load_count;
        send_card_load_request(8'hA5, 16'd100);
        wait_counter_at_least(CNT_CARD_LOAD, previous_card_load_count + 1, 100, "card load");
        check_true(card_loaded, "Rapid card is loaded");
        check_value(active_card_id, 8'hA5, "Loaded card ID");
        check_value(updated_balance, 16'd100, "Loaded card balance");

        send_start_request(1'b1, 4'd1, 4'd5);
        wait_for_state(6'd3, 100, "WAIT_PAYMENT rapid");
        check_value(fare_amount, 16'd40, "Rapid-card fare");

        send_cash_request(10'd10, 1'b1);
        repeat (5) @(posedge clk);
        check_value(paid_amount, 16'd0, "Wrong-mode cash did not enter rapid transaction");
        check_true(!escrow_nonempty, "Wrong-mode cash did not enter escrow");

        previous_ticket_count = ticket_count;
        send_card_tap_request(8'hA5);
        wait_counter_at_least(CNT_TICKET, previous_ticket_count + 1, 1000, "rapid ticket issue");
        wait_for_idle(200);

        ticket_3 = sold_ticket_ids[previous_ticket_count];
        check_value(updated_balance, 16'd60, "Balance after rapid-card purchase");
        check_value(total_revenue, 32'd105, "Revenue includes rapid-card sale");
        check_value(total_cash_in, 32'd80, "Rapid-card sale did not change cash-in");
        check_value(total_ticket_issued, 16'd3, "Ticket count after rapid-card sale");

        previous_gate_count = gate_open_count;
        send_validate_request(ticket_3, 4'd5);
        wait_counter_at_least(CNT_GATE_OPEN, previous_gate_count + 1, 100, "rapid ticket validation");

        $display("\n[TEST 7] Wrong rapid-card ID aborts transaction");
        send_start_request(1'b1, 4'd0, 4'd1);
        wait_for_state(6'd3, 100, "WAIT_PAYMENT rapid wrong card");
        previous_wrong_card_count = wrong_card_count;
        previous_abort_count = abort_count;
        send_card_tap_request(8'hB6);
        wait_counter_at_least(CNT_WRONG_CARD, previous_wrong_card_count + 1, 100, "wrong-card error");
        wait_counter_at_least(CNT_ABORT, previous_abort_count + 1, 100, "wrong-card abort");
        wait_for_idle(100);
        check_value(updated_balance, 16'd60, "Wrong card did not change loaded-card balance");

        $display("\n[TEST 8] Low card balance aborts transaction");
        send_start_request(1'b1, 4'd0, 4'd9);
        wait_for_state(6'd3, 100, "WAIT_PAYMENT low balance");
        check_value(fare_amount, 16'd65, "Low-balance test fare");
        previous_low_balance_count = low_balance_count;
        previous_abort_count = abort_count;
        send_card_tap_request(8'hA5);
        wait_counter_at_least(CNT_LOW_BALANCE, previous_low_balance_count + 1, 100, "low-balance warning");
        wait_counter_at_least(CNT_ABORT, previous_abort_count + 1, 100, "low-balance abort");
        wait_for_idle(100);
        check_value(updated_balance, 16'd60, "Low-balance attempt did not debit card");

        $display("\n[TEST 9] Rapid-card cancellation restores card balance");
        send_start_request(1'b1, 4'd0, 4'd4);
        wait_for_state(6'd3, 100, "WAIT_PAYMENT rapid cancellation");
        previous_refund_count = refund_count;
        previous_abort_count = abort_count;
        previous_ticket_count = ticket_count;

        fork
            begin
                send_card_tap_request(8'hA5);
            end
            begin
                wait_rapid_payment_ok(100);
                send_cancel_request();
            end
        join

        wait_counter_at_least(CNT_REFUND, previous_refund_count + 1, 300, "rapid-card refund");
        wait_counter_at_least(CNT_ABORT, previous_abort_count + 1, 300, "rapid-card cancel abort");
        wait_for_idle(300);

        check_value(last_refund_amount, 16'd40, "Rapid-card rollback amount");
        check_value(updated_balance, 16'd60, "Rapid-card rollback restored balance");
        check_value(ticket_count, previous_ticket_count, "Cancelled rapid transaction issued no ticket");
        check_value(total_revenue, 32'd105, "Cancelled rapid transaction did not alter revenue");
        check_value(total_refunded, 32'd60, "Refund accounting includes rapid rollback");

        $display("\n[TEST 10] Recharge loaded rapid card");
        previous_recharge_count = recharge_count;
        send_recharge_request(8'hA5, 16'd20);
        wait_counter_at_least(CNT_RECHARGE, previous_recharge_count + 1, 200, "card recharge");
        wait_for_idle(100);
        check_value(updated_balance, 16'd80, "Card balance after recharge");
        check_value(total_recharge_amount, 32'd20, "Recharge accounting");

        if (RUN_STRICT_SAFETY_TESTS) begin
            $display("\n[TEST 11] Wrong-mode requests must not reset valid payment timeout");
            send_start_request(1'b1, 4'd0, 4'd1);
            wait_for_state(6'd3, 100, "WAIT_PAYMENT wrong-mode timeout test");
            previous_timeout_count = payment_timeout_count;

            repeat (8)
                send_cash_request(10'd10, 1'b1);

            repeat (5) @(posedge clk);
            check_true(
                payment_timeout_count > previous_timeout_count,
                "Wrong-mode cash traffic did not postpone rapid payment timeout"
            );

            if (transaction_active) begin
                send_cancel_request();
                wait_for_idle(200);
            end
        end

        $display("\n[TEST 12] Unused ticket expires");
        repeat (
            TICKET_EXPIRY_TICKS_TB * CLOCKS_PER_TICK_TB + 20
        ) @(posedge clk);

        previous_expired_count = expired_count;
        send_validate_request(ticket_2, 4'd6);
        wait_counter_at_least(CNT_EXPIRED, previous_expired_count + 1, 100, "expired ticket detection");

        $display("\n[TEST 13] Closing request generates report");
        send_closing_request();
        repeat (10) @(posedge clk);
        check_true(report_valid, "Closing mode generated revenue report");
        check_value(display_status_code, 8'hA0, "Display shows report status");
        check_true(!service_required, "No service-required condition in nominal tests");
        check_value(operation_timeout_count, 0, "No operation timeout in nominal tests");
        check_true(!accounting_overflow, "No accounting overflow");

        $display("\n============================================================");
        $display("TESTBENCH COMPLETE: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("============================================================\n");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "%0d TEST(S) FAILED", fail_count);
        end
    end

    initial begin : global_watchdog
        repeat (250000) @(posedge clk);
        $fatal(1, "Global simulation watchdog expired");
    end

endmodule
