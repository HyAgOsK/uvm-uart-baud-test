`ifndef UART_TEST_SV
`define UART_TEST_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "environment.sv"
`include "random_sequence.sv"

class uart_test extends uvm_test;
    `uvm_component_utils(uart_test)

    uart_environment uart_env;

    function new(string name = "uart_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "uart_env.rx_ag", "is_active", UVM_ACTIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "uart_env.tx_ag", "is_active", UVM_ACTIVE);
        uart_env = uart_environment::type_id::create("uart_env", this);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        random_sequence rx_rnd_seq;
        random_sequence tx_rnd_seq;
        phase.raise_objection(this);
        rx_rnd_seq = random_sequence::type_id::create("rx_rnd_seq");
        tx_rnd_seq = random_sequence::type_id::create("tx_rnd_seq");
        `uvm_info(get_full_name(), "Starting RANDOM SEQUENCE on RX sequencer...", UVM_LOW)
        `uvm_info(get_full_name(), "Starting RANDOM SEQUENCE on TX sequencer...", UVM_LOW)
        fork
            rx_rnd_seq.start(uart_env.rx_ag.rx_sqr);
            tx_rnd_seq.start(uart_env.tx_ag.tx_sqr);
        join
        // Prevent the test from ending until all transactions have been processed by the scoreboard
        wait (uart_env.rx_scb.match_count + uart_env.rx_scb.mismatch_count == rx_rnd_seq.item_count);
        wait (uart_env.tx_scb.match_count + uart_env.tx_scb.mismatch_count == tx_rnd_seq.item_count);
        #100ns;
        phase.drop_objection(this);
    endtask : run_phase

endclass : uart_test

class uart_cfg_base_test extends uvm_test;

    virtual uart_bfm   bfm_uart0;
    virtual reg_if_bfm bfm_reg0;

    function new(string name = "uart_cfg_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual uart_bfm)::get(this, "", "bfm_uart0", bfm_uart0))
            `uvm_fatal(get_full_name(), "Virtual interface bfm_uart0 not found")

        if (!uvm_config_db#(virtual reg_if_bfm)::get(this, "", "bfm_reg0", bfm_reg0))
            `uvm_fatal(get_full_name(), "Virtual interface bfm_reg0 not found")
    endfunction : build_phase

    task automatic start_infrastructure();
        fork
            bfm_uart0.generate_clock(100_000_000, 0, 0);
            bfm_reg0.generate_clock(100_000_000, 0, 0);
            bfm_reg0.monitor_csr();
        join_none

        bfm_reg0.reset_pulse(1, 5, "Sync", 1);
        repeat (10) @(posedge bfm_reg0.clk);
    endtask : start_infrastructure

    task automatic configure_uart(
        input bit       parity_enable,
        input bit       parity_type,
        input bit       stop_bit,
        input bit [2:0] data_len,
        input bit [4:0] baud_code
    );
        bfm_reg0.configure_csr(0, parity_enable, parity_type, stop_bit, data_len, baud_code);
        repeat (10) @(posedge bfm_reg0.clk);
        bfm_reg0.get_csr();
    endtask : configure_uart

endclass : uart_cfg_base_test


class uart_baud_rate_test extends uart_cfg_base_test;
    `uvm_component_utils(uart_baud_rate_test)

    function new(string name = "uart_baud_rate_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task automatic run_one_baud_test(
        input bit [4:0] baud_code,
        input real      baud_real,
        input byte      rx_payload,
        input byte      tx_payload
    );
        byte rx_data;
        byte tx_data;

        `uvm_info(get_full_name(),
                  $sformatf("==== Testing baud rate %0.0f bps ====", baud_real),
                  UVM_LOW)

        // 8 data bits, no parity, 1 stop bit
        configure_uart(0, 0, 0, 3'd7, baud_code);

        // RX path: serial line -> DUT -> register interface
        fork
            begin
                bfm_uart0.send(rx_payload, 8, baud_real, "none", 0);
            end
            begin
                bfm_reg0.uart_receive(rx_data);
            end
        join

        if (rx_data !== rx_payload) begin
            `uvm_fatal(get_full_name(),
                       $sformatf("RX failed for baud %0.0f: expected 0x%02h, got 0x%02h",
                                 baud_real, rx_payload, rx_data))
        end

        // TX path: register interface -> DUT -> serial line
        bfm_reg0.get_csr();

        fork
            begin
                bfm_reg0.uart_send(tx_payload);
            end
            begin
                bfm_uart0.receive_tx(tx_data, 8, baud_real, "none", 0);
            end
        join

        if (tx_data !== tx_payload) begin
            `uvm_fatal(get_full_name(),
                       $sformatf("TX failed for baud %0.0f: expected 0x%02h, got 0x%02h",
                                 baud_real, tx_payload, tx_data))
        end

        `uvm_info(get_full_name(),
                  $sformatf("Baud rate %0.0f bps PASSED", baud_real),
                  UVM_LOW)
    endtask : run_one_baud_test

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        start_infrastructure();

        // alguns baud rates relevantes
        run_one_baud_test(5'd12,  9600.0,   8'h55, 8'hA3);
        run_one_baud_test(5'd19,  57600.0,  8'hC3, 8'h5A);
        run_one_baud_test(5'd21,  115200.0, 8'h0F, 8'hF0);

        #200ns;
        phase.drop_objection(this);
    endtask : run_phase

endclass : uart_baud_rate_test


class uart_parity_error_test extends uart_cfg_base_test;
    `uvm_component_utils(uart_parity_error_test)

    function new(string name = "uart_parity_error_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        byte rx_data_ok;
        byte rx_data_bad;

        phase.raise_objection(this);

        start_infrastructure();

        // OBS:
        // No RTL atual, parity_type = 1 casa com o comportamento de "even"
        // usado pelo BFM, embora exista comentário contraditório no tx_uart.sv.
        // Configuração: 8E1
        configure_uart(1, 1, 0, 3'd7, 5'd21);

        // 1) quadro com paridade correta
        fork
            begin
                bfm_uart0.send(8'hA5, 8, 115200.0, "even", 0);
            end
            begin
                bfm_reg0.uart_receive(rx_data_ok);
            end
        join

        bfm_reg0.get_csr();

        if (rx_data_ok !== 8'hA5) begin
            `uvm_fatal(get_full_name(),
                       $sformatf("Correct parity frame failed: expected 0xA5, got 0x%02h",
                                 rx_data_ok))
        end

        if (bfm_reg0.rx_error !== 1'b0) begin
            `uvm_fatal(get_full_name(),
                       "rx_error should be 0 for a correct parity frame")
        end

        `uvm_info(get_full_name(),
                  "Correct parity frame PASSED",
                  UVM_LOW)

        // 2) quadro com erro de paridade injetado propositalmente
        fork
            begin
                bfm_uart0.send_with_bad_parity(8'h3C, 8, 115200.0, "even", 0);
            end
            begin
                bfm_reg0.uart_receive(rx_data_bad);
            end
        join

        repeat (10) @(posedge bfm_reg0.clk);
        bfm_reg0.get_csr();

        if (bfm_reg0.rx_error !== 1'b1) begin
            `uvm_error(get_full_name(),
                       {"Parity error was injected, but rx_error did not assert. ",
                        "This likely indicates an RTL issue in the error flag propagation/latching path."})
        end
        else begin
            `uvm_info(get_full_name(),
                      "Parity error detection PASSED",
                      UVM_LOW)
        end

        #200ns;
        phase.drop_objection(this);
    endtask : run_phase

endclass : uart_parity_error_test

`endif // UART_TEST_SV