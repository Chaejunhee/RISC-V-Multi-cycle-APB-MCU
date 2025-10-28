`timescale 1ns / 1ps

module UART_Periph (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // External Interfaces Signals
    input  logic        rx,
    output logic        tx
);

    logic [7:0] rx_data;
    logic [7:0] tx_data;
    logic       rx_done;
    logic       tx_start;
    logic       tx_busy;

    APB_SlaveIntf_UART U_APB_SlaveIntf_UART (.*);
    uart U_UART (.*);
endmodule

// APB Slave 인터페이스 (slv_reg0 = DR, slv_reg1 = SR)
module APB_SlaveIntf_UART (
    // global signals
    input  logic        PCLK,
    input  logic        PRESET,
    // APB Interface Signals
    input  logic [ 3:0] PADDR,
    input  logic        PWRITE,
    input  logic        PENABLE,
    input  logic [31:0] PWDATA,
    input  logic        PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    // Internal Port
    input  logic [ 7:0] rx_data,   // UART로부터 수신된 데이터
    output logic [ 7:0] tx_data,   // UART로 전송할 데이터
    input  logic        rx_done,   // UART로부터 수신 완료 신호
    output logic        tx_start,  // UART로 전송 시작 신호 (펄스)
    input  logic        tx_busy    // UART로부터 전송 중 신호
);

    // 슬레이브 레지스터 정의 (C 코드: DR @ 0x00, SR @ 0x04)
    logic [31:0] slv_reg0;  // Data Register (DR, 0x00) - RX Data (Read), TX Data (Write)
    logic [31:0] slv_reg1;  // Status Register (SR, 0x04) - Status Flags (Read)

    // 내부 플래그/제어 신호
    logic        slv_tx_start;  // tx_start 출력 레지스터 (펄스)
    logic        slv_rx_ready_flag;  // RXNE (Status Reg Bit 0)

    // 주소 디코딩: PADDR[3:2]를 사용하여 4바이트 단위 주소 구분
    localparam DATA_REG_ADDR = 2'b00;  // Offset 0x00 (DR: slv_reg0)
    localparam STATUS_REG_ADDR = 2'b01;  // Offset 0x04 (SR: slv_reg1)

    // CPU Access Strobe Signals
    logic w_stb_dr_access;
    logic w_stb_sr_access;

    // DR 접근 (0x00)
    assign w_stb_dr_access = PSEL && PENABLE && (PADDR[3:2] == DATA_REG_ADDR);
    // SR 접근 (0x04)
    assign w_stb_sr_access = PSEL && PENABLE && (PADDR[3:2] == STATUS_REG_ADDR);

    // UART 코어 연결
    // slv_reg0의 하위 8비트가 TX 데이터 역할을 합니다.
    assign tx_data = slv_reg0[7:0];
    assign tx_start = slv_tx_start;

    //======================================================================
    // 1. PREADY (비블로킹)
    //======================================================================
    // PREADY는 PSEL/PENABLE이 HIGH일 때 다음 클록에 1 (즉시 응답)
    assign PREADY = PSEL;
    //======================================================================
    // 2. Data Register (DR: slv_reg0) & RXNE Flag (slv_rx_ready_flag)
    //======================================================================
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_reg0 <= 0;
            slv_rx_ready_flag <= 1'b0;
        end else begin
            // RX done이 들어오면 데이터 래치 및 플래그 설정
            if (rx_done) begin
                // slv_reg0에 수신 데이터 래치 (상위 24비트는 0으로 유지)
                slv_reg0[7:0]     <= rx_data;
                slv_rx_ready_flag <= 1'b1;
            end  // CPU가 Data Register (DR, 0x00)를 읽으면 플래그 클리어 (RX Polling Loop 탈출 핵심!)
            else if (slv_rx_ready_flag) begin
            // else if (w_stb_dr_access && !PWRITE) begin
                slv_rx_ready_flag <= 1'b0;
            end
            // CPU가 Data Register (DR, 0x00)에 쓸 때
            if (w_stb_dr_access && PWRITE) begin
                slv_reg0 <= PWDATA;  // 전체 32비트 저장 (TX 데이터는 하위 8비트)
            end
        end
    end

    //======================================================================
    // 3. TX Data Write 및 Start Pulse (slv_tx_start)
    //======================================================================
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            slv_tx_start <= 1'b0;
        end else begin
            slv_tx_start <= 1'b0;  // tx_start는 펄스

            // Data Register (0x00)에 쓰기 접근 발생 시
            if (w_stb_dr_access && PWRITE) begin
                slv_tx_start <= 1'b1;  // 전송 시작 펄스 발생
            end
        end
    end

    //======================================================================
    // 4. Status Register (SR: slv_reg1)
    //======================================================================
    always_comb begin
        // slv_reg1에 상태 비트 연결
        // Status Register Bit Definition:
        // [0]: RXNE (RX Data Not Empty) = slv_rx_ready_flag
        // [1]: TXC (TX Complete) = !tx_busy
        // [31:2]: Reserved (0)

        slv_reg1    = 32'h0;
        slv_reg1[0] = slv_rx_ready_flag;  // RXNE (수신 데이터 준비)
        slv_reg1[1] = ~tx_busy;  // TXC (송신 준비 완료. tx_busy의 반전)
    end


    //======================================================================
    // 5. PRDATA 출력 (Read data)
    //======================================================================
    always_comb begin
        PRDATA = 32'h0;
        if (PSEL && !PWRITE) begin
            case (PADDR[3:2])
                // 0x00: Data Register Read (slv_reg0)
                DATA_REG_ADDR: begin
                    PRDATA = rx_data;  // 수신된 32비트 (하위 8비트 유효)
                end
                // 0x04: Status Register Read (slv_reg1)
                STATUS_REG_ADDR: begin
                    PRDATA = slv_reg1;
                end
                default: PRDATA = 32'hFFFF_FFFF;
            endcase
        end
    end

endmodule  // APB_SlaveIntf_UART




module uart (
    input  logic       PCLK,
    input  logic       PRESET,
    //Internal Port
    output logic [7:0] rx_data,   //to interface rx data
    input  logic [7:0] tx_data,   //from interface tx data
    output logic       rx_done,   //to interface when rx done
    input  logic       tx_start,  // from interface when start tx
    output logic       tx_busy,   //to interface when tx working
    //External Port
    input  logic       rx,        //from pc
    output logic       tx         // to pc
);
    logic clk, rst;
    logic w_b_tick;

    assign clk = PCLK;
    assign rst = PRESET;

    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick),
        .rx     (rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .b_tick  (w_b_tick),
        .tx_busy (tx_busy),
        .tx      (tx)
    );

    baud_tick_generator U_B_TICK_GEN (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)


    );

endmodule


//////////////////////uart module
module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx_busy,
    output       tx

);

    localparam [1:0] IDLE = 2'b00, TX_START = 2'b01, TX_DATA = 2'b10, TX_STOP = 2'b11;

    reg [1:0] state_reg, state_next;
    reg tx_busy_reg, tx_busy_next;
    reg tx_reg, tx_next;
    reg [7:0] data_buf_reg, data_buf_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;

    assign tx_busy = tx_busy_reg;
    assign tx = tx_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= IDLE;
            tx_busy_reg    <= 1'b0;
            tx_reg         <= 1'b1;
            data_buf_reg   <= 8'h00;
            b_tick_cnt_reg <= 4'b0000;
            bit_cnt_reg    <= 3'b000;
        end else begin
            state_reg      <= state_next;
            tx_busy_reg    <= tx_busy_next;
            tx_reg         <= tx_next;
            data_buf_reg   <= data_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
        end
    end

    always @(*) begin
        //initialize
        state_next      = state_reg;
        tx_busy_next    = tx_busy_reg;
        tx_next         = tx_reg;
        data_buf_next   = data_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;

        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    b_tick_cnt_next = 0;
                    data_buf_next = tx_data;
                    state_next = TX_START;
                end
            end
            TX_START: begin
                tx_next = 1'b0;
                tx_busy_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        state_next      = TX_DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            TX_DATA: begin
                tx_next = data_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 0;
                            state_next = TX_STOP;
                        end else begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_buf_next = data_buf_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            TX_STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        state_next = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule

module uart_rx (
    input        clk,
    input        rst,
    input        b_tick,
    input        rx,
    output [7:0] rx_data,
    output       rx_done
);

    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    reg [1:0] state_reg, state_next;
    reg rx_done_reg, rx_done_next;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [7:0] rx_buff_reg, rx_buff_next;

    assign rx_data = rx_buff_reg;
    assign rx_done = rx_done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= IDLE;
            rx_done_reg    <= 1'b0;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            rx_buff_reg    <= 8'h00;
        end else begin
            state_reg      <= state_next;
            rx_done_reg    <= rx_done_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            rx_buff_reg    <= rx_buff_next;
        end
    end

    always @(*) begin
        state_next      = state_reg;
        rx_done_next    = rx_done_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        rx_buff_next    = rx_buff_reg;
        case (state_reg)
            IDLE: begin
                if (b_tick) begin
                    rx_done_next = 0;
                    if (!rx) begin
                        state_next      = START;
                        b_tick_cnt_next = 0;
                    end
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 23) begin
                        bit_cnt_next    = 0;
                        b_tick_cnt_next = 0;
                        state_next      = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 0) begin
                        rx_buff_next[7] = rx;
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end else if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next    = 0;
                            state_next      = STOP;
                        end else begin
                            bit_cnt_next    = bit_cnt_reg + 1;
                            b_tick_cnt_next = 0;
                            rx_buff_next    = rx_buff_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    rx_done_next = 1;
                    state_next   = IDLE;
                end
            end
        endcase
    end

endmodule

module baud_tick_generator (
    input  clk,
    input  rst,
    output b_tick
);

    parameter BAUDRATE = 9600 * 16;
    localparam BAUD_COUNT = 100_000_000 / BAUDRATE;

    reg [$clog2(BAUD_COUNT)-1:0] counter_reg;
    reg b_tick_reg;

    assign b_tick = b_tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick_reg  <= 0;
        end else begin
            if (counter_reg == BAUD_COUNT - 1) begin
                counter_reg <= 0;
                b_tick_reg  <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                b_tick_reg  <= 1'b0;
            end
        end
    end


endmodule
