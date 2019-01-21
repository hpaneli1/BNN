`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: EEHPC Lab
// Engineer: Hirenkumar Paneliya
// 
// Create Date: 06/20/2018 01:35:43 PM
// Design Name: 
// Module Name: Convolution
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


/**
Instantiation block for Convolution
Convolution #(
    .paramBitWidth(), //bits required for parameters
    .ImageAddressBitWidth(), // address bit width of the image address
    .FilterAddressBitWidth(), // filter address bit width
    .dataBitWidth(), // data bit width
    .maxImageSize(), // maximum image size in the entire network
    .maxFilterSize(), // maximum filter size in the entire network
    .oneImageMemFile(), // default memory values with the maximum image size
    .oneFilterMemFile() // defailt filter values with the maximum filter size
) uut (
    .clk(),
    .imageReady(), // signal to say that sending image values is started
    .filterReady(), // signal to say that sending filter values is started
    .fetchImageData(), // signal goes high when image values are being received
    .fetchFilterData(), // signal goes high when filter values are being received
    .go(), //start the module
    .reset(), // reset the module
    .ImageRows(), // Number of rows present in the input image
    .ImageColumns(), // Number of columns present in the input image
    .FilterRows(), // Number of rows present in the filter
    .FilterColumns(), // Number of columns present in the filter
    .considerOutputBuffer(), // output buffer values are considered when signal is high
    .startConvolution(), // start the convolution
    .getOBufferValues(), // signal goes high when upper module requests the data in the output buffer 
    .imageAddress(), // image address value to which the image pixel value to be stored
    .filterAddress(), // filter address value to which the filter value to be stored
    .filter_data_in(), // filter value to be stored in the filter address specified
    .image_data_in(), // image pixel value to be stored in the image address specified
    .oAddress(), // address value to which the data outputted has to be stored in the higher modules
    .data_out(), // data from the output buffer outputted to the higher modules
    .convolutionDone(), // signal goes high when convolution is completed
    .sendingData() // signal goes high when the outputBuffer values are being sent to the top modules
);
**/

module Convolution #(
    parameter paramBitWidth = 16,
    parameter ImageAddressBitWidth = 12,
    parameter FilterAddressBitWidth = 8,
    parameter dataBitWidth = 16,
    parameter maxImageSize = 25, //this is generally input image size in the layer1
    parameter maxFilterSize = 9, // check all the layers and determine max filter size without depth
    parameter oneImageMemFile = "",
    parameter oneFilterMemFile = ""
)(
    input clk,
    input imageReady,
    input filterReady,
    input fetchImageData,
    input fetchFilterData,
    input go,
    input reset,
    input considerOutputBuffer,
    input startConvolution,
    input getOBufferValues,
    input ValidConvolution,
    input [paramBitWidth-1: 0] ImageRows,
    input [paramBitWidth-1: 0] ImageColumns,
    input [paramBitWidth-1: 0] FilterRows,
    input [paramBitWidth-1: 0] FilterColumns,
    input [ImageAddressBitWidth-1: 0] imageAddress,
    input [FilterAddressBitWidth-1: 0] filterAddress,
    input signed [dataBitWidth-1: 0] filter_data_in,
    input signed [dataBitWidth-1: 0] image_data_in,
    output reg [ImageAddressBitWidth-1: 0] oAddress,
    output signed [dataBitWidth-1: 0] data_out,
    output reg convolutionDone,
    output reg sendingData
    );
    
    // parameters for state machine
    reg [3:0] current_state, next_state;
    reg [3:0] start = 4'b0000,S1 = 4'b0001, S2 = 4'b0010, S3 = 4'b0011, S4 = 4'b0100, S5=4'b0101, S6 = 4'b0110, S7=4'b0111, S8= 4'b1000, S9=4'b1001,S10=4'b1010, stop = 4'b1011;
    reg [3:0] out_current_state, out_next_state;
    reg [3:0] out_start = 4'b1100, out_S1 = 4'b1101, out_S2 = 4'b1110, out_stop = 4'b1111;
         
    reg isConvolutionRunning; // to determing whether the convolution is happening or not
    reg [ImageAddressBitWidth-1: 0] imageInputAddress; //this will be the input to the memory module
    reg [FilterAddressBitWidth-1: 0] filterInputAddress;
    reg signed [dataBitWidth-1: 0] img_data_in;
    reg signed [dataBitWidth-1: 0] fil_data_in;
    wire [dataBitWidth-1: 0] image_data_out; // this will be the output of the image memory
    wire [dataBitWidth-1: 0] filter_data_out;
    reg signed [dataBitWidth-1: 0] cellProductVal;
    reg signed [dataBitWidth-1: 0] onePatchVal;
    
    reg startSingleConv; //flag to start the dot product
    reg HS, VS, HE, VE; // Horizontal and vertical stop and enable signals
    wire DPDone; //flag to say one dot product done
    reg [ImageAddressBitWidth-1:0] h_address_img, v_address_img; //address varibales to tranverse in image
    wire [ImageAddressBitWidth-1:0] hm_address_img, vm_address_img; //address varibales to tranverse in image
    wire VME; // flag to know exactly when single convolution vertical address is incrementing
    wire [ImageAddressBitWidth-1:0] taddress, tfaddress;
    reg isOutside; //flag for knowing whether the addresses or outside the image or inside
    
    //signals to add the cell product values
    reg addProductVal;
    
    reg signed[ImageAddressBitWidth-1: 0] loadToAddress; //this will be the input to the memory module
    wire signed [dataBitWidth-1: 0] oBuffer_data_out; // this will be the output of the output buffer
    reg signed [dataBitWidth-1: 0] accumulatedVal; // this will be the output of the output buffer
    reg incrementAddress; // signal to increment the address to load the values to the memory
    reg oBuffer_writeEnable; //signal to write the previous + convolution values to the memory
    reg oBuffer_readEnable;
    
    // outputting the data
    reg oAddressEnable; //signal to increment the address
    reg oAddressStop; //signal to stop incrementing the address
    
    reg readModeEnable;
    wire [ImageAddressBitWidth-1: 0] oBuffermemDepth;
    
    single_port_RAM #(
        .memoryDepth(maxImageSize),
        .addressBitWidth(ImageAddressBitWidth),
        .dataBitWidth(dataBitWidth),
        .MEM_FILE(oneImageMemFile)
    ) imageBuffer(
        .clk(clk),
        .read_enable(isConvolutionRunning),
        .write_enable(fetchImageData),
        .address(imageInputAddress),
        .data_in(img_data_in),
        .data_out(image_data_out)
    );
    
    single_port_RAM #(
        .memoryDepth(maxFilterSize),
        .addressBitWidth(FilterAddressBitWidth),
        .dataBitWidth(dataBitWidth),
        .MEM_FILE(oneFilterMemFile)
    ) filterBuffer(
        .clk(clk),
        .read_enable(isConvolutionRunning),
        .write_enable(fetchFilterData),
        .address(filterInputAddress),
        .data_in(fil_data_in),
        .data_out(filter_data_out)
    );
    
    single_port_RAM #(
        .memoryDepth(maxImageSize),
        .addressBitWidth(ImageAddressBitWidth),
        .dataBitWidth(dataBitWidth),
        .MEM_FILE(oneImageMemFile)
    ) outputBuffer(
        .clk(clk),
        .read_enable(oBuffer_readEnable),
        .write_enable(!oBuffer_readEnable),
        .address(loadToAddress),
        .data_in(accumulatedVal),
        .data_out(oBuffer_data_out)
    );
    
    single_convolution #(
        .addressBitWidth(ImageAddressBitWidth),
        .paramBitWidth(paramBitWidth)
    ) singleConv(
        .clk(clk),
        .reset(reset),
        .Filter_rows(FilterRows),
        .Filter_Cols(FilterColumns),
        .startSingleConv(startSingleConv),
        .hm_address_img(hm_address_img),
        .vm_address_img(vm_address_img),
        .DPDone(DPDone),
        .VME(VME)
    );
    
    // ----------------------------------- values retrieving -----------------------------------------------------
    assign taddress = (h_address_img + hm_address_img) * ImageColumns + (v_address_img + vm_address_img);
    assign tfaddress = hm_address_img * FilterColumns + vm_address_img;
    assign data_out = (oBuffer_data_out > 0) ? oBuffer_data_out : 0;
    
 //   assign oBuffermemDepth = ValidConvolution ? ((ImageColumns-FilterColumns+1)*(ImageRows-FilterRows+1)) : maxImageSize;
    // ---------------------------------- For outputting the values ------------------------------------------------------------
    
    always @(posedge clk) begin
        if (oAddressEnable) begin
            oAddress<= oAddress + 1;
        end
        else if (reset || !sendingData)begin
            oAddress <= 0;
        end
    end
    
    always @(*) begin
        if((oAddress >= ImageRows * ImageColumns) && !(ValidConvolution)) begin
            oAddressStop <= 1'b1;
        end
        else if((oAddress >= (ImageRows) * (ImageColumns-FilterColumns+1)) && (ValidConvolution)) begin
            oAddressStop <= 1'b1;
        end
        else begin
            oAddressStop <= 1'b0;
        end
    end
    
//    always @(posedge clk) begin
//        data_out <= (oBuffer_data_out > 0) ? oBuffer_data_out : 0;
//    end
    // ---------------------------------- Writing values to the memory ---------------------------------------------------------
    
    // Once a patch convolution is made. Retreive the values at a particular address and add the patch value and write back the value
    
    always @(posedge clk) begin
        if (reset || startConvolution) begin
            loadToAddress <= -1;
        end
        else if (incrementAddress) begin
            loadToAddress <= loadToAddress + 1;
        end
        else if (sendingData) begin
            loadToAddress <= oAddress;
        end
    end
    
    // generating address increment signal
    always @(posedge clk) begin
        if (isConvolutionRunning && !addProductVal) begin
            incrementAddress <= 1;
        end
        else begin
            incrementAddress <= 0;
        end
    end
    
    always @(*) begin
        if (!isConvolutionRunning && addProductVal) begin
            oBuffer_writeEnable <= 1;
        end
        else begin
            oBuffer_writeEnable <= 0;
        end
    end
    
    always @(*) begin
        if ((isConvolutionRunning && addProductVal && !incrementAddress) || readModeEnable) begin
            oBuffer_readEnable <= 1;
        end
        else begin
            oBuffer_readEnable <= 0;
        end
    end
    
    always@(*) begin
        if (reset) begin
            accumulatedVal <= 0;
        end
        else if (considerOutputBuffer  && !isConvolutionRunning && addProductVal) begin
            accumulatedVal <= onePatchVal + oBuffer_data_out; 
        end
        else if (!isConvolutionRunning && addProductVal) begin
            accumulatedVal <= onePatchVal; 
        end
    end
    // ---------------------------------- Generating signals for adding the cell product values --------------------------------
    
    always @(posedge clk) begin
        if (isConvolutionRunning) begin
            addProductVal <= 1'b1;    
        end
        else begin
            addProductVal <= 1'b0;
        end
    end
    
    always @(posedge clk) begin
        if (isConvolutionRunning && addProductVal) begin
            onePatchVal <= cellProductVal + onePatchVal;
        end
        else begin
            onePatchVal <= 0;
        end
    end
    
    // ---------------------------------- Generating signals for the addresses -----------------------------------
/**
    Case 1: When current vertical address is outside the image enable signal isOutside
    Case 2: When current horizontal address is outside the image rows then enable isOutside
    Otherwise disable isOutside
    **/
    always @(posedge clk) begin
        if (!DPDone && isConvolutionRunning && ((v_address_img + vm_address_img) >= ImageColumns) && !(ValidConvolution)) begin
            isOutside <= 1'b1;
        end
//        else if (!DPDone && isConvolutionRunning && ((v_address_img + vm_address_img) >= (ImageColumns - FilterColumns+1)) && (ValidConvolution)) begin
//            isOutside <= 1'b1;
//        end
        else if (!DPDone && isConvolutionRunning && ((h_address_img + hm_address_img) >= ImageRows) && !(ValidConvolution)) begin
            isOutside <= 1'b1;
        end 
        else if (!DPDone && isConvolutionRunning && ((h_address_img + hm_address_img) >= (ImageRows)) && (ValidConvolution)) begin
            isOutside <= 1'b1;
        end
        else begin
            isOutside <= 1'b0;
        end
    end
        
    always @(negedge clk) begin
        if (isConvolutionRunning && !DPDone) begin
            filterInputAddress <= tfaddress;
        end
        else if (fetchFilterData) begin
            filterInputAddress <= filterAddress;
            fil_data_in <= filter_data_in;
        end
        else begin
            filterInputAddress <= 0;
        end
    end
    
    always @(negedge clk) begin
        if(fetchImageData) begin
            imageInputAddress <= imageAddress;
            img_data_in <= image_data_in;
        end
        else if (isConvolutionRunning && !DPDone) begin
            imageInputAddress <= taddress;
        end
        else begin
            imageInputAddress <= 0;
        end
    end
    
    always @(*) begin
        if (reset || isOutside) begin
            cellProductVal <= 0;
        end
        else if (isConvolutionRunning) begin
           cellProductVal <= image_data_out * filter_data_out; 
        end
    end  
      
    //----------------------------------- State Machine Starting --------------------------------------------------
    
    always @(posedge clk or posedge reset)begin
        if (reset) begin 
            current_state <= start;
        end
        else begin 
            current_state <= next_state;
        end
    end
    
    always @(*) begin
        HE = 1'b0; VE = 1'b0; VS = 1'b0; HS = 1'b0;
        case (current_state)
            start: begin
                if (!go) begin
                    next_state = start;
                    v_address_img = 0;
                    h_address_img = 0;
                end
                else begin
                    next_state = S1;
                end
            end
            S1: begin
                if (!imageReady) begin
                    next_state = S1;
                end
                else begin
                    next_state = S2;
                end
            end
            S2: begin
                if (fetchImageData) begin
                    next_state = S2;
                end
                else begin
                    next_state = S3;
                end
            end
            S3: begin
                if (!filterReady) begin
                    next_state = S3;
                end
                else begin
                    next_state = S4;
                end
            end
            S4: begin
                if(fetchFilterData) begin
                    next_state = S4;
                end
                else begin
                    next_state = S5;
                end
            end
            S5: begin
                if(!startConvolution) begin
                    h_address_img = 0;
                    v_address_img = 0;
                    next_state = S5;
                end
                else begin
                    readModeEnable = 1'b0;
                    next_state = S6;
                end
            end
            S6: begin
                next_state = S7;
            end
            S7: begin
                if (!DPDone) begin
                  next_state = S7;
                end
                else if (DPDone && h_address_img == (ImageRows-1) && v_address_img >= (ImageColumns-1) && !(ValidConvolution)) begin // Horizontal stop
                    h_address_img = 0;
                    v_address_img = 0;
                    next_state = S10;
                end
                else if (DPDone && h_address_img == (ImageRows-1) && v_address_img >= (ImageColumns - FilterColumns) && ValidConvolution) begin
                    h_address_img = 0;
                    v_address_img = 0;
                    next_state = S10;
                end
                else if (DPDone && h_address_img < (ImageRows-1) && v_address_img == (ImageColumns-1) && !(ValidConvolution)) begin // vertical stop
                    next_state = S6;
                    h_address_img = h_address_img + 1;
                    v_address_img = 0;
                end
                else if (DPDone && h_address_img < (ImageRows-1) && v_address_img == (ImageColumns - FilterColumns) && (ValidConvolution)) begin // vertical stop
                    next_state = S6;
                    h_address_img = h_address_img + 1;
                    v_address_img = 0;
                end
                else begin
                    next_state = S6;
                    v_address_img = v_address_img + 1;
                end
            end
            S10: begin
                next_state = stop;
            end
            stop: begin
                readModeEnable = 1'b1;
                next_state = S5;
            end
            default: begin
                next_state = start;
            end
        endcase
    end
    
    always @(*) begin
        startSingleConv = 1'b0; isConvolutionRunning = 1'b0; convolutionDone = 1'b0;
        case (current_state)
            start: begin
            end
            S1: begin
            end
            S2: begin
            end
            S3: begin
            end
            S4: begin
            end
            S5: begin
                convolutionDone = 1'b0;
            end
            S6: begin
                startSingleConv = 1'b1;
            end
            S7: begin
                isConvolutionRunning = 1'b1; 
            end
            S10: begin
            end
            stop: begin
                convolutionDone = 1'b1;
            end
        endcase
    end
    
    //----------------------------------- State Machine for outputting the data -----------------------------------
    
    always @(posedge clk or posedge reset)begin
        if (reset) begin 
            out_current_state <= out_start;
        end
        else begin 
            out_current_state <= out_next_state;
        end
    end
    
    always @(*) begin
        case (out_current_state)
            out_start: begin
                if (!getOBufferValues) begin
                    out_next_state = out_start;
                end
                else begin
                    out_next_state = out_S2;
                end
            end
            out_S2: begin
                if (oAddressStop) begin
                    out_next_state = out_stop;
                end
                else begin
                    out_next_state = out_S2;
                end
            end
            out_stop: begin
                out_next_state = out_start;
            end
        endcase
    end
    
    always @(*) begin
        oAddressEnable = 1'b0; sendingData = 1'b0;
        case (out_current_state)
            out_start: begin
            end
            out_S2: begin
                if (!oAddressStop) begin
                    oAddressEnable = 1'b1;
                end
                sendingData = 1'b1;
            end
            out_stop: begin
                sendingData = 1'b1;
            end
        endcase
    end
endmodule
