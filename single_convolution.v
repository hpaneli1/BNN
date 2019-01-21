`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/15/2018 12:13:52 PM
// Design Name: 
// Module Name: single_convolution
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
Instantiation Block
single_convolution #(
    .addressBitWidth(), //address BitWidth
    .paramBitWidth()
) uut (
    .clk(),
    .reset(),
    .startSingleConv(), //signal to start the module
    .Filter_rows(), // Number of filter rows
    .Filter_Cols(), // Number of Filter Columns
    .hm_address_img(), // current horizontal address 
    .vm_address_img(), // current vertical address
    .DPDone(), // signal saying address generation done
    .VME()
);
**/
module single_convolution #(
    parameter addressBitWidth = 16,
    parameter paramBitWidth = 16,
    parameter Filter_rows = 2,
    parameter Filter_Cols = 5
)(
    input clk,
    input reset,
    input startSingleConv,
//    input [paramBitWidth-1: 0] Filter_rows,
//    input [paramBitWidth-1: 0] Filter_Cols,
    output reg [addressBitWidth-1:0] hm_address_img,
    output reg [addressBitWidth-1:0] vm_address_img,
    output reg DPDone,
    output reg VME
    );
    
reg VMS, HME, HMS; //Horizonatal and vertical movement stop and enable signals for one dot product
reg [2:0] start = 3'b000,S1 = 3'b001, S2 = 3'b010, S3 = 3'b011, stop = 3'b100;
reg [2:0] current_state, next_state;
    
    /**
    Case 1: if reset is 1 then set the horizontal address to 0.
    case 2: if HME is one increment the horizontal address
    **/
    always @(posedge clk) begin
        if (HME) begin
            hm_address_img = hm_address_img + 1;
        end
        else if (reset || startSingleConv) begin
            hm_address_img <= 0;
        end
    end

    /**
    case 1: if reset then set the vm_address_img to 0
    case 2: if VME is 1 then increment the vm_address_img
    **/
    always @(posedge clk) begin
        if (reset || VMS || startSingleConv) begin
            vm_address_img <= 0;
        end
        else if (VME) begin
            vm_address_img <= vm_address_img + 1;
        end
    end
    
    /**
    when hm_address_img reaches the last row and vm_address_img reaches the last column of the dot product. 
    Raise the HMS otherwise HMS will always be at 0.
    When vm_address_img reaches the last column raise the VMS to 1 
    Otherwise VMS will be at 0
    **/
    always @(negedge clk) begin
        if (hm_address_img == Filter_rows-1 && vm_address_img == Filter_Cols-1) begin //need to stop at row 52 and column 63
            HMS <= 1'b1;
        end
        else if (vm_address_img == Filter_Cols-1) begin
            VMS <= 1'b1;
        end
        else begin
            HMS <= 1'b0;
            VMS <= 1'b0;
        end
    end
    
    //-------------------------- State Machine for one dot product----------------------------
    always @(posedge clk or posedge reset)begin
        if (reset) begin 
            current_state <= start;
        end
        else begin 
            current_state <= next_state;
        end
    end
    
    /**
    state machine to hold one dot product
    states Explanation
    start: will be in start untill it receives a startSingleConv signal
    S1: when horizontalMovement stop is reached go to stop.
    When vertical end is reached then go to next state
    else be in the same state
    S2: go to state 1
    stop: go to start
    **/
    always @(*) begin
        case (current_state)
            start:begin
                if (!startSingleConv) begin 
                    next_state = start;
                end
                else begin 
                    next_state = S1;
                end
            end
            S1: begin
                if(HMS) begin
                    next_state = stop;
                end
                else begin
                    next_state = S1;
                end
            end
            stop: begin
              next_state = start;
            end
        endcase
    end
    
    always @(*) begin
        DPDone = 1'b0;  HME = 1'b0; VME = 1'b0;
        case (current_state)
            start:begin
            end
            S1: begin
                if (VMS) begin
                    HME = 1'b1;
                end
                else begin
                    VME = 1'b1;
                end
            end
            stop: begin
              DPDone = 1'b1;
            end
        endcase
    end
endmodule
