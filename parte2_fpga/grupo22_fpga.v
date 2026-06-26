module alu(inputA, inputB, aluCtrl, aluResult, zero);
    input  [31:0] inputA, inputB;
    input  [3:0]  aluCtrl;
    output reg [31:0] aluResult;
    output zero;

    always @(*) begin
        case (aluCtrl)
            4'b0000: aluResult = inputA + inputB;
            4'b0001: aluResult = inputA - inputB;
            4'b0010: aluResult = inputA & inputB;
            4'b0011: aluResult = inputA | inputB;
            4'b0100: aluResult = inputA >> inputB[4:0];
            default: aluResult = 32'b0;
        endcase
    end

    assign zero = (aluResult == 32'b0);
endmodule

module Alu_Control(funct7, funct3, aluOp, aluCtrl);
    input  [6:0] funct7;
    input  [2:0] funct3;
    input  [1:0] aluOp;
    output reg [3:0] aluCtrl;

    always @(*) begin
        case (aluOp)
            2'b00: aluCtrl = 4'b0000;
            2'b01: aluCtrl = 4'b0001;

            2'b10: begin
                case (funct3)
                    3'b000: aluCtrl = (funct7 == 7'b0100000) ? 4'b0001 : 4'b0000;
                    3'b111: aluCtrl = 4'b0010;
                    3'b101: aluCtrl = 4'b0100;
                    default: aluCtrl = 4'b0000;
                endcase
            end

            2'b11: begin
                case (funct3)
                    3'b110: aluCtrl = 4'b0011;
                    default: aluCtrl = 4'b0000;
                endcase
            end

            default: aluCtrl = 4'b0000;
        endcase
    end
endmodule

module Control(opcode, branch, memRead, memToReg, aluOp, memWrite, aluSrc, regWrite);
    input  [6:0] opcode;
    output reg branch, memRead, memToReg, memWrite, aluSrc, regWrite;
    output reg [1:0] aluOp;

    always @(*) begin
        branch   = 1'b0;
        memRead  = 1'b0;
        memToReg = 1'b0;
        aluOp    = 2'b00;
        memWrite = 1'b0;
        aluSrc   = 1'b0;
        regWrite = 1'b0;

        case (opcode)
            7'b0000011: begin
                memRead  = 1'b1;
                memToReg = 1'b1;
                aluSrc   = 1'b1;
                regWrite = 1'b1;
            end

            7'b0100011: begin
                memWrite = 1'b1;
                aluSrc   = 1'b1;
            end

            7'b0110011: begin
                aluOp    = 2'b10;
                regWrite = 1'b1;
            end

            7'b0010011: begin
                aluOp    = 2'b11;
                aluSrc   = 1'b1;
                regWrite = 1'b1;
            end

            7'b1100011: begin
                branch = 1'b1;
                aluOp  = 2'b01;
            end
        endcase
    end
endmodule

module immGen(instruction, immediate);
    input  [31:0] instruction;
    output reg [31:0] immediate;

    wire [6:0] opcode;
    assign opcode = instruction[6:0];

    always @(*) begin
        case (opcode)
            7'b0000011,
            7'b0010011:
                immediate = {{20{instruction[31]}}, instruction[31:20]};

            7'b0100011:
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

            7'b1100011:
                immediate = {{19{instruction[31]}}, instruction[31], instruction[7],
                             instruction[30:25], instruction[11:8], 1'b0};

            default:
                immediate = 32'b0;
        endcase
    end
endmodule

module Reg_mem(clock, reset, enable, regWrite, readReg1, readReg2,
               writeReg, writeData, readData1, readData2,
               debugReg, debugData);

    input clock, reset, enable, regWrite;
    input [4:0] readReg1, readReg2, writeReg, debugReg;
    input [31:0] writeData;
    output [31:0] readData1, readData2, debugData;

    reg [31:0] registers [0:31];
    integer i;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end
        else begin
            if (enable && regWrite && writeReg != 5'b00000)
                registers[writeReg] <= writeData;

            registers[0] <= 32'b0;
        end
    end

    assign readData1 = (readReg1 == 5'b00000) ? 32'b0 : registers[readReg1];
    assign readData2 = (readReg2 == 5'b00000) ? 32'b0 : registers[readReg2];
    assign debugData = (debugReg == 5'b00000) ? 32'b0 : registers[debugReg];
endmodule

module data_mem(clock, reset, enable, memRead, memWrite, address, writeData, readData);
    input clock, reset, enable, memRead, memWrite;
    input [31:0] address, writeData;
    output reg [31:0] readData;

    reg [7:0] memory [0:127];
    integer i;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 128; i = i + 1)
                memory[i] <= 8'b0;
        end
        else if (enable && memWrite) begin
            memory[address[6:0]] <= writeData[7:0];
        end
    end

    always @(*) begin
        if (memRead)
            readData = {{24{memory[address[6:0]][7]}}, memory[address[6:0]]};
        else
            readData = 32'b0;
    end
endmodule

module Instruction_mem(address, instruction);
    input [31:0] address;
    output reg [31:0] instruction;

    always @(*) begin
        case (address[6:2])
            5'd0: instruction = 32'b00000000101000000110000010010011;
            5'd1: instruction = 32'b00000000001100000110000100010011;
            5'd2: instruction = 32'b01000000001000001000000110110011;
            5'd3: instruction = 32'b00000000001100001111001000110011;
            5'd4: instruction = 32'b00000000001000001101001010110011;
            5'd5: instruction = 32'b00000000001100000000000000100011;
            5'd6: instruction = 32'b00000000000000000000001100000011;
            5'd7: instruction = 32'b00000000001100110000010001100011;
            5'd8: instruction = 32'b00000110001100000110001110010011;
            5'd9: instruction = 32'b00000000111100000110010000010011;
            default: instruction = 32'b0;
        endcase
    end
endmodule

module pc(pcIn, pcOut, clock, reset, enable);
    input [31:0] pcIn;
    input clock, reset, enable;
    output reg [31:0] pcOut;

    always @(posedge clock or posedge reset) begin
        if (reset)
            pcOut <= 32'b0;
        else if (enable)
            pcOut <= pcIn;
    end
endmodule

module somador(a, b, result);
    input [31:0] a, b;
    output [31:0] result;

    assign result = a + b;
endmodule

module mux2In(input0, input1, result, select);
    input [31:0] input0, input1;
    input select;
    output [31:0] result;

    assign result = select ? input1 : input0;
endmodule

module data_pathR5(clockDP, resetDP, enableDP, debugRegAddr, debugRegData, pcValue);
    input clockDP, resetDP, enableDP;
    input [4:0] debugRegAddr;
    output [31:0] debugRegData, pcValue;

    wire [31:0] pcInDP, pcOutDP;
    wire [31:0] instructionDP;
    wire branchDP, memReadDP, memToRegDP, memWriteDP, aluSrcDP, regWriteDP;
    wire [1:0] aluOpDP;
    wire [31:0] readData1DP, readData2DP, immGenOutDP;
    wire [3:0] aluCtrlDP;
    wire [31:0] muxAluOutDP, aluOutDP, readMemDP, writeRegDataDP;
    wire [31:0] add4OutDP, addBranchDP;
    wire aluZeroDP, branchTakenDP;

    assign pcValue = pcOutDP;

    pc pcDP(pcInDP, pcOutDP, clockDP, resetDP, enableDP);
    Instruction_mem insMem(pcOutDP, instructionDP);

    Control ctrlDP(
        instructionDP[6:0],
        branchDP,
        memReadDP,
        memToRegDP,
        aluOpDP,
        memWriteDP,
        aluSrcDP,
        regWriteDP
    );

    Reg_mem regMem(
        clockDP,
        resetDP,
        enableDP,
        regWriteDP,
        instructionDP[19:15],
        instructionDP[24:20],
        instructionDP[11:7],
        writeRegDataDP,
        readData1DP,
        readData2DP,
        debugRegAddr,
        debugRegData
    );

    immGen immGenDP(instructionDP, immGenOutDP);

    Alu_Control aluControlDP(
        instructionDP[31:25],
        instructionDP[14:12],
        aluOpDP,
        aluCtrlDP
    );

    mux2In muxAlu(readData2DP, immGenOutDP, muxAluOutDP, aluSrcDP);
    alu aluDP(readData1DP, muxAluOutDP, aluCtrlDP, aluOutDP, aluZeroDP);

    data_mem dataMem(
        clockDP,
        resetDP,
        enableDP,
        memReadDP,
        memWriteDP,
        aluOutDP,
        readData2DP,
        readMemDP
    );

    mux2In muxDataMem(aluOutDP, readMemDP, writeRegDataDP, memToRegDP);

    somador add4(32'd4, pcOutDP, add4OutDP);
    somador addBranch(pcOutDP, immGenOutDP, addBranchDP);

    assign branchTakenDP = branchDP & aluZeroDP;

    mux2In muxPC(add4OutDP, addBranchDP, pcInDP, branchTakenDP);
endmodule

module button_pulse(clock, reset, button_n, pulse);
    input clock, reset, button_n;
    output reg pulse;

    reg s0, s1;
    reg debounced;
    reg debounced_ant;
    reg [19:0] count;

    wire pressed;
    assign pressed = ~button_n;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            s0 <= 1'b0;
            s1 <= 1'b0;
            debounced <= 1'b0;
            debounced_ant <= 1'b0;
            count <= 20'd0;
            pulse <= 1'b0;
        end
        else begin
            s0 <= pressed;
            s1 <= s0;

            if (s1 != debounced) begin
                count <= count + 20'd1;

                if (count == 20'd999999) begin
                    debounced <= s1;
                    count <= 20'd0;
                end
            end
            else begin
                count <= 20'd0;
            end

            debounced_ant <= debounced;
            pulse <= debounced & ~debounced_ant;
        end
    end
endmodule

module seg7(valor, display);
    input [3:0] valor;
    output reg [6:0] display;

    always @(*) begin
        case (valor)
            4'h0: display = 7'b1000000;
            4'h1: display = 7'b1111001;
            4'h2: display = 7'b0100100;
            4'h3: display = 7'b0110000;
            4'h4: display = 7'b0011001;
            4'h5: display = 7'b0010010;
            4'h6: display = 7'b0000010;
            4'h7: display = 7'b1111000;
            4'h8: display = 7'b0000000;
            4'h9: display = 7'b0010000;
            4'hA: display = 7'b0001000;
            4'hB: display = 7'b0000011;
            4'hC: display = 7'b1000110;
            4'hD: display = 7'b0100001;
            4'hE: display = 7'b0000110;
            4'hF: display = 7'b0001110;
            default: display = 7'b1111111;
        endcase
    end
endmodule

module DE2_115(
    input CLOCK_50,
    input [3:0] KEY,
    input [17:0] SW,
    output [17:0] LEDR,
    output [8:0] LEDG,
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5,
    output [6:0] HEX6,
    output [6:0] HEX7
);

    wire reset;
    wire stepPulse;
    wire regPulse;

    reg [4:0] regIndex;
    wire [31:0] regValue;
    wire [31:0] pcValue;

    wire [5:0] pcIndex;
    wire [3:0] pcTens, pcOnes;
    wire [3:0] regTens, regOnes;

    assign reset = ~KEY[1];

    button_pulse botaoClock(CLOCK_50, reset, KEY[0], stepPulse);
    button_pulse botaoReg(CLOCK_50, reset, KEY[2], regPulse);

    data_pathR5 cpu(
        CLOCK_50,
        reset,
        stepPulse,
        regIndex,
        regValue,
        pcValue
    );

    always @(posedge CLOCK_50 or posedge reset) begin
        if (reset)
            regIndex <= 5'd0;
        else if (regPulse) begin
            if (SW[1])
                regIndex <= (regIndex == 5'd0) ? 5'd31 : regIndex - 5'd1;
            else
                regIndex <= (regIndex == 5'd31) ? 5'd0 : regIndex + 5'd1;
        end
    end

    assign pcIndex = pcValue[6:2];

    assign pcTens = (pcIndex >= 6'd30) ? 4'd3 :
                    (pcIndex >= 6'd20) ? 4'd2 :
                    (pcIndex >= 6'd10) ? 4'd1 : 4'd0;

    assign pcOnes = pcIndex - (pcTens * 4'd10);

    assign regTens = (regIndex >= 5'd30) ? 4'd3 :
                     (regIndex >= 5'd20) ? 4'd2 :
                     (regIndex >= 5'd10) ? 4'd1 : 4'd0;

    assign regOnes = regIndex - (regTens * 4'd10);

    assign LEDR = regValue[17:0];
    assign LEDG[4:0] = regIndex;
    assign LEDG[8:5] = 4'b0000;

    seg7 h0(regValue[3:0], HEX0);
    seg7 h1(regValue[7:4], HEX1);
    seg7 h2(regValue[11:8], HEX2);
    seg7 h3(regValue[15:12], HEX3);

    seg7 h4(regOnes, HEX4);
    seg7 h5(regTens, HEX5);

    seg7 h6(pcOnes, HEX6);
    seg7 h7(pcTens, HEX7);
endmodule
