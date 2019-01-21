`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/16/2018 03:21:34 PM
// Design Name: 
// Module Name: convolutionTop
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module convolutionTop #(
    parameter filter_rows = 3,
    parameter filter_cols = 3,
    parameter image_rows = 32,
    parameter image_cols = 32,
    parameter depth = 16,
    parameter image_addressWidth = 16,
    parameter filterAddressWidth = 16,
    parameter dataWidth = 16,
    parameter imageFile = "G:\\RA\\BNN\\Matlab\\conv_image.txt",
    parameter filter_memfile = "G:\\RA\\BNN\\Matlab\\conv_filter.txt"
) (
    input clk,
    input reset,
    input go,
    output reg data_out,
    output reg done
    );
    
    wire [dataWidth-1:0] image_temp_in, filter_temp_in;
    reg [image_addressWidth-1:0] image_fetchAddress;
    reg [filterAddressWidth-1:0] filter_fetchAddress;
    reg startConvolution;
    reg [dataWidth-1:0] image_temp, filter_temp;
    reg rd_wrn;
    reg [image_addressWidth-1:0] image_address_in;
    reg [filterAddressWidth-1:0] filter_address_in;
    reg single_convDone;
    reg depthcounter;
    
    single_portRAM #(
                        .memDepth(image_rows*image_cols*depth),
                        .addressWidth(image_addressWidth),
                        .dataWidth(1'b1),
                        .memFile(imageFile)
    )imgMem(
                        .clk(clk),
                        .reset(reset),
                        .address(image_fetchAddress),
                        .data_in(1'b0),
                        .rd_wrn(1'b1),
                        .data_out(image_temp_in));
     
    single_portRAM #(
                        .memDepth(filter_rows*filter_cols*depth),
                        .addressWidth(filterAddressWidth),
                        .dataWidth(dataWidth),
                        .memFile(filter_memfile)
    )filterMem(
                        .clk(clk),
                        .reset(reset),
                        .address(filter_fetchAddress),
                        .data_in(1'b0),
                        .rd_wrn(rd_wrn),
                        .data_out(filter_temp_in));
    
    conv #(
                        .filter_rows(filter_rows),
                        .filter_cols(filter_cols),
                        .image_rows(image_rows),
                        .image_cols(image_cols),
                        .image_addressWidth(image_addressWidth),
                        .filter_addressWidth(filterAddressWidth),
                        .dataWidth(dataWidth),
                        .image_memFile(),
                        .filter_memFile()
    ) convolution1(
                        .clk(clk),
                        .reset(reset),
                        .startConv(startConvolution),
                        .image_data_in(image_temp),
                        .filter_data_in(filter_temp),
                        .rd_wrn(rd_wrn),
                        .image_address(image_address_in),
                        .filter_address(filter_address_in),
                        .data_out(data_out),
                        .convDone(done),
                        .one_convDone(single_convDone));
                        
    always @(posedge clk) begin
        if(reset) begin
            image_fetchAddress <= 0;
            filter_fetchAddress <= 0;
            image_address_in <= 0;
            filter_address_in <= 0;
        end
        
    
    
        
endmodule
