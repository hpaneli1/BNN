`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    21:16:17 05/06/2018 
// Design Name: 
// Module Name:    single_portRAM 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module single_portRAM #(
                            parameter memDepth = 25,
                            parameter addressWidth = 16,
                            parameter dataWidth = 16,
                            parameter memFile = ""
)(
                            input clk,
                            input reset,
                            input [addressWidth-1:0] address,
                            input signed [dataWidth-1:0] data_in,
                            input rd_wrn,
                            output reg signed [dataWidth-1:0] data_out
    );
    
reg signed [dataWidth-1:0] mem [0:memDepth-1];

initial begin
    $readmemh(memFile, mem);
end

always @(posedge clk) begin
    if(rd_wrn == 1) begin
        data_out <= mem[address];
    end
    else if(rd_wrn == 0) begin
        mem[address] <= data_in;
    end
end
endmodule
