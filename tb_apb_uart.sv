`timescale 1ns / 1ps
interface apb_master_if (
    input logic PCLK,
    input logic PRESET
);
    logic        transfer;
    logic        write;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    logic        ready;
    logic        rx;
    logic        tx;
endinterface  //apb_interf


class transaction;
    logic             transfer;
    logic             write;
    logic      [31:0] rdata;
    logic      [31:0] addr;
    rand logic [31:0] wdata;
    logic      [ 7:0] received_data;
    rand logic [ 7:0] send_data;

    constraint wdata_const {wdata inside {[32'h0000_0000 : 32'h0000_00ff]};}

    task automatic print(string name);
        $display("%t[%s], transfer = %h, write = %h, addr = %h, wdata = %h, rdata = %h, received_data = %h, send_data = %h", $time, name, transfer, write,
                 addr, wdata, rdata, received_data, send_data);
    endtask
endclass  //transaction


class env;
    transaction tr;

    virtual apb_master_if m_if;

    logic [7:0] received_data;

    int total_count_tx = 0;
    int total_count_rx = 0;
    int total_count_uart_cycle = 0;
    int pass_count_tx = 0;
    int pass_count_rx = 0;
    int pass_count_rx_done = 0;
    int fail_count_tx = 0;
    int fail_count_rx = 0;
    int fail_count_rx_done = 0;

    function new(virtual apb_master_if m_if);
        this.m_if = m_if;
        this.tr   = new();
    endfunction  //new()


    task automatic send(input logic [31:0] manager_addr, input logic [31:0] manager_wdata);
        tr.transfer = 1'b1;
        tr.write = 1'b1;
        m_if.transfer <= tr.transfer;
        m_if.write    <= tr.write;
        m_if.addr     <= manager_addr;
        m_if.wdata    <= manager_wdata;
        tr.print("SEND");
        @(posedge m_if.PCLK);
        m_if.transfer <= 1'b0;
        @(posedge m_if.PCLK);
        wait (m_if.ready);
        @(posedge m_if.PCLK);
    endtask

    task automatic receive(input logic [31:0] manager_addr);
        tr.transfer = 1'b1;
        tr.write = 1'b0;
        m_if.transfer <= tr.transfer;
        m_if.write    <= tr.write;
        m_if.addr     <= manager_addr;
        tr.print("RECEIVE");
        @(posedge m_if.PCLK);
        m_if.transfer <= 1'b0;
        @(posedge m_if.PCLK);
        wait (m_if.ready);
        tr.rdata = m_if.rdata;
        @(posedge m_if.PCLK);
    endtask

    task send_uart(input [7:0] send_data);
        integer i;
        begin
            // start bit
            m_if.rx = 0;
            #(104166);  // uart 9600bps bit time
            // data bit
            for (i = 0; i < 8; i = i + 1) begin
                m_if.rx = send_data[i];
                #(104166);  // uart 9600bps bit time 
            end
            // stopbit
            m_if.rx = 1;
            #(104166);  // uart 9600bps bit time
        end
        tr.print("SEND_UART");
    endtask


    task receive_uart();
        integer bit_count;
        begin
            // $display("receive_uart start");
            received_data = 0;
            //@(negedge m_if.tx);
            // middle of start bit
            #(104166 / 2);
            // start bit pass/fail
            if (m_if.tx) begin
                // fail
                $display("Fail Start bit");
            end
            // data bit pass/fail
            for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                #(104166);
                received_data[bit_count] = m_if.tx;
            end
            //#(104166);
        end
        tr.received_data = received_data;
        tr.print("RECEIVE_UART");
    endtask

    task automatic compare();
        total_count_tx++;
        total_count_rx++;
        if (tr.rdata[7:0] == tr.send_data) begin
            $display("rx PASS!");
            pass_count_rx++;
        end else begin
            $display("rx FAIL..");
            fail_count_rx++;
        end
        if (tr.wdata[7:0] == tr.received_data) begin
            $display("tx PASS!");
            pass_count_tx++;
        end else begin
            $display("tx FAIL..");
            fail_count_tx++;
        end
    endtask  //automatic

    task report();
        $display("========================================================");
        $display("===================== Test Report ======================");
        $display("========================================================");
        $display("=================   Total cycle : %3d  =================", total_count_uart_cycle);
        $display("==         Total    tx  :  %3d     rx  :  %3d         ==", total_count_tx, total_count_rx);
        $display("==         Pass     tx  :  %3d     rx  :  %3d         ==", pass_count_tx, pass_count_rx);
        $display("==         Fail     tx  :  %3d     rx  :  %3d         ==", fail_count_tx, fail_count_rx);
        $display("========================================================");
        $display("================= Test bench is finish =================");
        $display("========================================================");
    endtask  //report


    task automatic run(int loop);

        repeat (loop) begin
            tr.randomize();
            //external-> uart
            send_uart(tr.send_data);
            // uart->cpu
            receive(32'h1000_4000);
            //cpu->uart
            send(32'h1000_4000, tr.wdata);
            // //uart->external
            receive_uart();

            total_count_uart_cycle++;

            compare();
        end

        report();
    endtask
endclass

module tb_apb_uart ();
    logic                PCLK;
    logic                PRESET;

    logic         [31:0] PADDR;
    logic                PWRITE;
    logic                PENABLE;
    logic         [31:0] PWDATA;
    logic                PSEL_UART;
    logic         [31:0] PRDATA_UART;
    logic                PREADY_UART;

    env        apbSignalTester;

    apb_master_if m_if (
        PCLK,
        PRESET
    );


    UART_Periph U_UART_Periph (
        .*,
        .PSEL  (PSEL_UART),
        .PRDATA(PRDATA_UART),
        .PREADY(PREADY_UART),
        .tx    (m_if.tx),
        .rx    (m_if.rx)
    );




    APB_Master U_APB_Master (
        .*,
        .PSEL0  (),
        .PSEL1  (),
        .PSEL2  (),
        .PSEL3  (),
        .PSEL4  (PSEL_UART),
        .PSEL5  (),
        .PSEL6  (),
        .PSEL7  (),
        .PRDATA0(),
        .PRDATA1(),
        .PRDATA2(),
        .PRDATA3(),
        .PRDATA4(PRDATA_UART),
        .PRDATA5(),
        .PRDATA6(),
        .PRDATA7(),
        .PREADY0(),
        .PREADY1(),
        .PREADY2(),
        .PREADY3(),
        .PREADY4(PREADY_UART),
        .PREADY5(),
        .PREADY6(),
        .PREADY7(),

        .transfer(m_if.transfer),
        .ready   (m_if.ready),
        .write   (m_if.write),
        .addr    (m_if.addr),
        .wdata   (m_if.wdata),
        .rdata   (m_if.rdata)
    );
    always #5 PCLK = ~PCLK;



    initial begin
        apbSignalTester = new(m_if);

        PCLK = 0;
        PRESET = 1;
        #100;
        PRESET = 0;
        #100;

        apbSignalTester.run(512);

        $finish;
    end




endmodule
