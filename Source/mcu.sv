`timescale 1ns / 1ps

module MCU (
    input  logic       clk,
    input  logic       reset,
    // External Port
    output logic [7:0] gpo,
    input  logic [7:0] gpi,
    inout  logic [7:0] gpio,
    input  logic       rx,
    output logic       tx
);




    wire         PCLK = clk;
    wire         PRESET = reset;
    // Internal Interface Signals
    logic        transfer;
    logic        ready;
    logic        write;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    logic [31:0] instrCode;
    logic [31:0] instrMemAddr;
    logic        busWe;
    logic [31:0] busAddr;
    logic [31:0] busWData;
    logic [31:0] busRData;

    // APB Interface Signals
    logic [31:0] PADDR;
    logic        PWRITE;
    logic        PENABLE;
    logic [31:0] PWDATA;

    logic        PSEL_RAM;
    logic [31:0] PRDATA_RAM;
    logic        PREADY_RAM;

    logic        PSEL_GPO;
    logic [31:0] PRDATA_GPO;
    logic        PREADY_GPO;

    logic        PSEL_GPI;
    logic [31:0] PRDATA_GPI;
    logic        PREADY_GPI;

    logic        PSEL_GPIO;
    logic [31:0] PRDATA_GPIO;
    logic        PREADY_GPIO;

    logic        PSEL_UART;
    logic [31:0] PRDATA_UART;
    logic        PREADY_UART;

    assign write = busWe;
    assign addr = busAddr;
    assign wdata = busWData;
    assign busRData = rdata;


    ROM U_ROM (
        .addr(instrMemAddr),
        .data(instrCode)
    );

    CPU_RV32I U_RV32I (.*);

    APB_Master U_APB_Master (
        .*,
        .PSEL0  (PSEL_RAM),
        .PSEL1  (PSEL_GPO),
        .PSEL2  (PSEL_GPI),
        .PSEL3  (PSEL_GPIO),
        .PSEL4  (PSEL_UART),
        .PSEL5  (),
        .PSEL6  (),
        .PSEL7  (),
        .PRDATA0(PRDATA_RAM),
        .PRDATA1(PRDATA_GPO),
        .PRDATA2(PRDATA_GPI),
        .PRDATA3(PRDATA_GPIO),
        .PRDATA4(PRDATA_UART),
        .PRDATA5(),
        .PRDATA6(),
        .PRDATA7(),
        .PREADY0(PREADY_RAM),
        .PREADY1(PREADY_GPO),
        .PREADY2(PREADY_GPI),
        .PREADY3(PREADY_GPIO),
        .PREADY4(PREADY_UART),
        .PREADY5(),
        .PREADY6(),
        .PREADY7()
    );

    RAM U_RAM (
        .*,
        .PSEL  (PSEL_RAM),
        .PRDATA(PRDATA_RAM),
        .PREADY(PREADY_RAM)
    );

    GPO_Periph U_GPO_Periph (
        .*,
        .PSEL  (PSEL_GPO),
        .PRDATA(PRDATA_GPO),
        .PREADY(PREADY_GPO)
    );

    GPI_Periph U_GPI_Periph (
        .*,
        .PSEL  (PSEL_GPI),
        .PRDATA(PRDATA_GPI),
        .PREADY(PREADY_GPI)
    );

    GPIO_Periph U_GPIO_Periph (
        .*,
        .PSEL  (PSEL_GPIO),
        .PRDATA(PRDATA_GPIO),
        .PREADY(PREADY_GPIO)
    );

    UART_Periph U_UART_Periph (
        .*,
        .PSEL  (PSEL_UART),
        .PRDATA(PRDATA_UART),
        .PREADY(PREADY_UART)
    );


endmodule
