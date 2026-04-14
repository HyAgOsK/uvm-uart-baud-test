`ifndef UART_ITEM_SV
`define UART_ITEM_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class uart_item extends uvm_sequence_item;
    `uvm_object_utils(uart_item)

    rand bit [7:0] data;

    function new(string name = "uart_item");
        super.new(name);
    endfunction : new
    
endclass : uart_item

`endif // UART_ITEM_SV