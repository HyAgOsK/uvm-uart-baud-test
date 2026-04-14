`ifndef UART_ENV_SV
`define UART_ENV_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "rx_agent.sv"
`include "tx_agent.sv"
`include "scoreboard.sv"
`include "coverage.sv"

class uart_environment extends uvm_env;
    `uvm_component_utils(uart_environment)

    // RX Agent Components
    rx_agent rx_ag;
    scoreboard rx_scb;
    coverage rx_cov;

    // TX Agent Components
    tx_agent tx_ag;
    scoreboard tx_scb;
    coverage tx_cov;

    function new(string name = "uart_environment", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        rx_ag = rx_agent::type_id::create("rx_ag", this);
        rx_scb = scoreboard::type_id::create("rx_scb", this);
        rx_cov = coverage::type_id::create("rx_cov", this);
        tx_ag = tx_agent::type_id::create("tx_ag", this);
        tx_scb = scoreboard::type_id::create("tx_scb", this);
        tx_cov = coverage::type_id::create("tx_cov", this);
        rx_scb.set_agent_name("RX");
        rx_cov.set_agent_name("RX");
        tx_scb.set_agent_name("TX");
        tx_cov.set_agent_name("TX");
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        // ############# RX Agent Connections #############
        // Command Monitor's analysis port (ap_command) broadcasts to both Scoreboard and Coverage
        rx_ag.rx_mon.ap_command.connect(rx_scb.command_fifo.analysis_export);
        rx_ag.rx_mon.ap_command.connect(rx_cov.analysis_export);
        // Result Monitor's analysis port (ap_result) broadcasts to the Scoreboard only
        rx_ag.rx_mon.ap_result.connect(rx_scb.result_fifo.analysis_export);

        // ############# TX Agent Connections #############
        // Command Monitor's analysis port (ap_command) broadcasts to both Scoreboard and Coverage
        tx_ag.tx_mon.ap_command.connect(tx_scb.command_fifo.analysis_export);
        tx_ag.tx_mon.ap_command.connect(tx_cov.analysis_export);
        // Result Monitor's analysis port (ap_result) broadcasts to the Scoreboard only
        tx_ag.tx_mon.ap_result.connect(tx_scb.result_fifo.analysis_export);

    endfunction : connect_phase


endclass : uart_environment

`endif // UART_ENV_SV