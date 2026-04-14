`ifndef RX_DRIVER_SV
`define RX_DRIVER_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "uart_item.sv"

class rx_driver extends uvm_driver #(uart_item);
    `uvm_component_utils(rx_driver)

    virtual uart_bfm bfm_uart0;

    function new(string name = "rx_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_bfm)::get(this, "", "bfm_uart0", bfm_uart0))
            `uvm_fatal(get_full_name(), "BFM not set via uvm_config_db");
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        uart_item command;
    
        fork
            bfm_uart0.generate_clock(100_000_000, 0, 0);
            bfm_uart0.reset_pulse(1, 5, "Sync", 1);
        join_any

        forever begin
            seq_item_port.get_next_item(command);
            bfm_uart0.send(command.data);
            seq_item_port.item_done();
        end
    endtask : run_phase

endclass : rx_driver

`endif // RX_DRIVER_SV