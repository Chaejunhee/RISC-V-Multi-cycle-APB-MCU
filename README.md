# 🚀 RISC-V/APB 기반 MCU 설계 (RISC-V/APB based MCU Design)

본 프로젝트는 **RISC-V RV32I Multi-Cycle CPU**와 **AMBA APB (Advanced Peripheral Bus)** 프로토콜을 기반으로 다양한 주변 장치(Peripheral)를 통합한 마이크로컨트롤러 유닛(MCU) 시스템을 **SystemVerilog**로 설계하고 FPGA 보드에서 검증한 결과물입니다.

---

## 1. 프로젝트 개요 (Project Overview)

### 목표 및 특징
*  **프로젝트 목표**: RV32I Multi-Cycle CPU 및 AMBA Bus Protocol을 사용하여 여러 주변 장치를 사용할 수 있는 MCU를 설계하고, C 기반 펌웨어 작성 및 검증을 완료하는 것입니다.
* **핵심 특징**:
    *  하드웨어 회로가 아닌 **ROM에 담긴 펌웨어**에 따라 동작을 결정하는 임베디드 시스템 구조입니다.
    *  **AMBA APB Bus**를 이용하여 여러 주변 장치들을 연결했습니다.

### 개발 환경 및 도구
| 구분 | 내용 | 출처 |
| :--- | :--- | :--- |
| **하드웨어** |  Digilent Basys 3 FPGA Board |
| **소프트웨어** |  Xilinx Vivado, PuTTy |
| **언어** |  SystemVerilog, C |

---

## 2. 시스템 아키텍처 (System Architecture)

 전체 시스템은 RV32I Core, APB Master (`APB_Master.sv`), 그리고 APB Slave 주변 장치들로 구성됩니다.

### 2.1. RISC-V RV32I Multi-Cycle CPU Core
*  **ISA**: RISC-V 명령어 세트 아키텍처의 기본 정수(Integer) 버전 32비트 명령어 (RV32I)를 구현했습니다.
*  **방식**: 하나의 명령어를 여러 단계(**Fetch, Decode, Execute, Memory, Write Back**)에 걸쳐 실행하는 **Multi-Cycle** 방식을 채택하여 클럭 효율이 높습니다.

### 2.2. AMBA APB Bus
*  **프로토콜**: AMBA 프로토콜 내에서 가장 낮은 대역폭을 가지며, 저속 저전력 주변 장치들을 연결하는 데 최적화된 버스입니다.
*  **전송**: **Non-pipelined** 방식으로 한 번에 하나의 전송만 처리하며, 주소와 데이터가 한 클럭 사이클에 동시에 처리되지 않습니다.
*  **상태 다이어그램**: 전송은 `IDLE` $\to$ `SETUP` $\to$ `ACCESS` 의 3단계로 이루어집니다..

### 2.3. 메모리 맵 (Memory Map)
 주변 장치들은 `0x1000_0000` 주소부터 할당됩니다.

| 주변 장치 (Peripheral) | 오프셋 (Offset) | 주소 (Base Address) | PSEL Index | 파일명 |
| :--- | :--- | :--- | :--- | :--- |
| **ROM** | N/A | `0x0000_0000` | N/A | `ROM.sv` |
| **RAM** | `0x0000` | `0x1000_0000` | `PSEL0` | `RAM.sv` |
| **GPO** | `0x1000` | `0x1000_1000` | `PSEL1` | `GPO.sv` |
| **GPI** | `0x2000` | `0x1000_2000` | `PSEL2` | `GPI.sv` |
| **GPIO** | `0x3000` | `0x1000_3000` | `PSEL3` | `GPIO.sv` |
| **UART** | `0x4000` | `0x1000_4000` | `PSEL4` | `uart.sv` |

---

## 3. 주변 장치 세부 설계 (Peripheral Details)

### 3.1. UART (`uart.sv`)
*  **레지스터 구조**: C 코드에서 Data Register(DR)는 `0x00` 오프셋, Status Register(SR)는 `0x04` 오프셋에 매핑됩니다.
    *  **`SR[0]` (RXNE)**: 수신 데이터 준비 플래그 (`slv_rx_ready_flag`와 연결).
    *  **`SR[1]` (TXC)**: 송신 준비 완료 플래그 (`~tx_busy`와 연결).
*  **RX/TX 동작**: Data Register(`slv_reg0`)에 쓰기 접근 발생 시 `tx_start` 펄스가 발생하여 전송을 시작합니다..  RX 완료 신호(`rx_done`)가 들어오면 수신 데이터가 `slv_reg0`에 래치되고 `RXNE`가 설정됩니다.

### 3.2. GPO (`GPO.sv`)
*  **제어 레지스터**: Control Register(`cr`, `slv_reg0`)와 Output Data Register(`odr`, `slv_reg1`)가 있습니다.
*  **출력 로직**: `gpo[i]`는 `cr[i]`가 `1`일 때만 `odr[i]` 값을 출력하고, `0`일 때는 하이 임피던스 상태(`1'bz`)를 유지합니다.

### 3.3. GPI (`GPI.sv`)
*  **제어 레지스터**: Control Register(`cr`, `slv_reg0`)와 Input Data Register(`idr`)가 있습니다.
*  **입력 로직**: `idr[i]`는 `cr[i]`가 참일 때만 `gpi[i]` 값을 읽어옵니다.

### 3.4. GPIO (`GPIO.sv`)
*  **제어 레지스터**: Control Register(`cr`, `slv_reg0`), Output Data Register(`odr`, `slv_reg1`), Input Data Register(`idr`)가 있습니다.
*  **입출력 로직**: `cr[i]`가 `1`이면 출력으로 설정되어 `odr[i]`를 `gpio[i]`에 할당하고, `cr[i]`가 `0`이면 입력으로 설정되어 `gpio[i]`를 `idr[i]`에 할당합니다.

---

## 4. 펌웨어 및 검증 (Firmware & Verification)

### 4.1. C 언어 펌웨어 (Test Code)
C 언어로 작성된 펌웨어는 주변 장치들을 사용하여 MCU의 동작을 제어합니다.
*  **주요 기능**: 주기적으로 UART로 현재 상태, GPO 출력을 수행하고, GPI로 세팅 모드에 진입하여 UART로 모드를 전환하는 펌웨어 로직을 설계했습니다.
*  **UART 수신**: `while (!(UART_SR & UART_SR_RXNE))` 루프를 통해 수신이 완료될 때까지 대기(폴링)합니다.
*  **컴파일 문제 해결**: 컴파일러에서 RV32I set이 아닌 명령어(예: `addi sp, sp, -32` 등)가 컴파일되는 문제를 해결하기 위해, 컴파일러 옵션에 `-march=rv32i -mabi=ilp32 -O0 -nostdlib -std=c99`를 지정하여 RV32I 명령어만 사용하도록 강제했습니다.

### 4.2. SystemVerilog 검증 (Verification)
* **검증 대상**: APB-UART 주변 장치 (`dut (APB_UART)`)를 대상으로 검증을 수행했습니다.
* **Pass 조건**:
    *  **RX Pass**: `send_data == rdata`
    *  **TX Pass**: `wdata == received_data` 
*  **최종 결과**: 총 512번의 TX/RX 사이클 검증에서 **Pass tx: 512, rx: 512**를 달성했습니다.

---



## 5. 고찰 (Reflections)

 RV32I CPU에 APB Bus를 연결하고 주변 장치를 직접 설계·연결하는 경험을 통해 MCU에 가까운 시스템을 구현해보면서 임베디드 시스템의 구조와 동작 원리를 체감할 수 있었습니다[cite: 549, 658].  RV32I 명령어만 사용 가능했기 때문에 복잡한 기능 구현에 부족함을 느꼈으며, 하드웨어와 소프트웨어의 **조화로운 조합**이 필요하다는 것을 배웠습니다.

## 6. 동작 영상 (Demo Video)
프로젝트의 실제 동작 모습은 아래 링크에서 확인하실 수 있습니다.

[FPGA 동작 영상 (Basys 3)] (https://youtu.be/JyGLBVhcDjw)
