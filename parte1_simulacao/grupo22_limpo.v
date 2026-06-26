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

    wire [6:0] opcode = instruction[6:0];

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

module Reg_mem(clock, reset, regWrite, readReg1, readReg2, writeReg, writeData, readData1, readData2);
    input clock, reset, regWrite;
    input [4:0] readReg1, readReg2, writeReg;
    input [31:0] writeData;
    output [31:0] readData1, readData2;

    reg [31:0] registers [0:31];
    integer i;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 32'b0;
        end
        else begin
            if (regWrite && writeReg != 5'b00000)
                registers[writeReg] <= writeData;

            registers[0] <= 32'b0;
        end
    end

    assign readData1 = (readReg1 == 5'b00000) ? 32'b0 : registers[readReg1];
    assign readData2 = (readReg2 == 5'b00000) ? 32'b0 : registers[readReg2];
endmodule

module data_mem(clock, reset, memRead, memWrite, address, writeData, readData);
    input clock, reset, memRead, memWrite;
    input [31:0] address, writeData;
    output reg [31:0] readData;

    reg [7:0] memory [0:127];
    integer i;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 128; i = i + 1)
                memory[i] <= 8'b0;
        end
        else if (memWrite) begin
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

module Instruction_mem(clock, address, instruction);
    input clock;
    input [31:0] address;
    output reg [31:0] instruction;

    reg [31:0] instructions [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            instructions[i] = 32'b0;

        instructions[0] = 32'b00000000101000000110000010010011;
        instructions[1] = 32'b00000000001100000110000100010011;
        instructions[2] = 32'b01000000001000001000000110110011;
        instructions[3] = 32'b00000000001100001111001000110011;
        instructions[4] = 32'b00000000001000001101001010110011;
        instructions[5] = 32'b00000000001100000000000000100011;
        instructions[6] = 32'b00000000000000000000001100000011;
        instructions[7] = 32'b00000000001100110000010001100011;
        instructions[8] = 32'b00000110001100000110001110010011;
        instructions[9] = 32'b00000000111100000110010000010011;
    end

    always @(*) begin
        instruction = instructions[address[6:2]];
    end
endmodule

module pc(pcIn, pcOut, clock, reset);
    input [31:0] pcIn;
    input clock, reset;
    output reg [31:0] pcOut;

    always @(posedge clock or posedge reset) begin
        if (reset)
            pcOut <= 32'b0;
        else
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

module data_pathR5(clockDP, resetDP);
    input clockDP, resetDP;

    wire [31:0] pcInDP, pcOutDP;
    wire [31:0] instructionDP;
    wire branchDP, memReadDP, memToRegDP, memWriteDP, aluSrcDP, regWriteDP;
    wire [1:0] aluOpDP;
    wire [31:0] readData1DP, readData2DP, immGenOutDP;
    wire [3:0] aluCtrlDP;
    wire [31:0] muxAluOutDP, aluOutDP, readMemDP, writeRegDataDP;
    wire [31:0] add4OutDP, addBranchDP;
    wire aluZeroDP, branchTakenDP;

    pc pcDP(pcInDP, pcOutDP, clockDP, resetDP);
    Instruction_mem insMem(clockDP, pcOutDP, instructionDP);

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
        regWriteDP,
        instructionDP[19:15],
        instructionDP[24:20],
        instructionDP[11:7],
        writeRegDataDP,
        readData1DP,
        readData2DP
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

module data_path_tb;
    reg clock;
    reg reset;
    integer i;

    data_pathR5 dut(.clockDP(clock), .resetDP(reset));

    initial begin
        clock = 1'b0;
        forever #5 clock = ~clock;
    end

    initial begin
        $dumpfile("grupo22.vcd");
        $dumpvars(0, data_path_tb);

        reset = 1'b1;
        #12 reset = 1'b0;

        repeat (16) begin
            @(posedge clock);
            #1;
            $display("PC=%0d  instr=%b", dut.pcDP.pcOut, dut.instructionDP);
        end

        $display("\nRegistradores:");
        for (i = 0; i < 32; i = i + 1)
            $display("x%0d = %0d", i, dut.regMem.registers[i]);

        $display("\nMemoria:");
        for (i = 0; i < 32; i = i + 1)
            $display("mem[%0d] = %0d", i, dut.dataMem.memory[i]);

        $finish;
    end
endmodule
