`ifndef TX_DRIVER_SV
`define TX_DRIVER_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "uart_item.sv"

class tx_driver extends uvm_driver #(uart_item);
    `uvm_component_utils(tx_driver)

    virtual reg_if_bfm bfm_reg0;

    function new(string name = "tx_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual reg_if_bfm)::get(this, "", "bfm_reg0", bfm_reg0))
            `uvm_fatal(get_full_name(), "BFM not set via uvm_config_db");
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        uart_item command;
    
        fork
            bfm_reg0.generate_clock(100_000_000, 0, 0);
            bfm_reg0.reset_pulse(1, 5, "Sync", 1);
            bfm_reg0.monitor_csr();
        join_any

        bfm_reg0.configure_csr(0, 0, 0, 0, 3'd7, 5'd21);
        bfm_reg0.get_csr();

        forever begin
            seq_item_port.get_next_item(command);
            bfm_reg0.uart_send(command.data);
            seq_item_port.item_done();
        end
    endtask : run_phase

endclass : tx_driver

`endif // RX_DRIVER_SV