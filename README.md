# RISC-V-Multi-cycle-APB-MCU


제공해주신 파일과 프로젝트 내용을 바탕으로 GitHub README 파일을 작성해 드리겠습니다. 프로젝트의 목표, 주요 구성 요소(RV32I CPU, AMBA APB), 주변 장치(RAM, GPO, GPI, GPIO, UART), 그리고 개발 환경 등을 포함하여 구조화된 문서를 작성했습니다.

RISC-V/APB 기반 MCU 설계 (RISC-V/APB based MCU Design)
1. 프로젝트 개요 (Project Overview)
본 프로젝트는 RISC-V RV32I Multi-Cycle CPU와 AMBA APB(Advanced Peripheral Bus) 프로토콜을 기반으로 다양한 주변 장치(Peripheral)를 통합한 마이크로컨트롤러 유닛(MCU) 시스템을 SystemVerilog로 설계 및 구현하고, FPGA 보드에서 검증하는 것을 목표로 합니다.



프로젝트 목표: RV32I Multi-Cycle CPU 및 AMBA Bus Protocol을 사용하여 여러 주변 장치를 사용할 수 있는 MCU를 설계하고, SystemVerilog Testbench를 통해 주변 장치 기능을 검증하며, C 기반 펌웨어를 작성하고 컴파일하는 것입니다.

핵심 기능 및 특징:

하드웨어 회로가 아닌 ROM에 저장된 펌웨어(Firmware)에 따라 동작이 결정됩니다.


버스(Bus)를 이용하여 여러 주변 장치들을 연결하여 임베디드 시스템 구조를 구현합니다.



개발 환경 및 도구:


하드웨어: Digilent Basys 3 FPGA Board 


소프트웨어: Xilinx Vivado, PuTTy 


언어: SystemVerilog, C 

2. 시스템 아키텍처 (System Architecture)
전체 MCU는 RV32I Core, APB Master(Manager), 그리고 다수의 APB Slave Peripheral로 구성됩니다.





2.1. RISC-V RV32I Multi-Cycle CPU Core
기본 정수(Integer) 버전 32비트 명령어 세트 아키텍처(ISA)인 RV32I를 구현하며, 하나의 명령어를 여러 단계(Cycle)에 걸쳐 실행하는 Multi-Cycle 방식을 채택하여 클럭 효율이 높습니다.

단계 (Phase)	역할 (Action)	RV32I 명령어와의 연관
Fetch	
PC가 가리키는 주소에서 명령어(IR)를 인출하고 PC를 +4로 업데이트합니다.

모든 명령어의 인출.

Decode	
IR의 레지스터 주소를 해독하고 레지스터 파일에서 데이터를 읽어옵니다.

R/I/S/B/U/J 타입 모두 해독.

Execute	
명령어 유형에 따라 ALU 연산을 수행합니다 (R-Type, I-Type, Branch 조건 검사 등).

R-Type 연산, I-Type 주소/데이터 계산, B-Type 분기 결정.

MemAccess	
메모리 접근이 필요한 명령어만 수행합니다.

Load (L-Type): 메모리에서 데이터 인출. Store (S-Type): 데이터를 메모리에 기록.

Write Back	
결과를 레지스터 파일에 기록합니다.

R-Type, Load (L-Type), U/J-Type의 결과를 레지스터에 기록.

2.2. AMBA APB Bus
APB는 ARM의 AMBA 프로토콜 중 가장 낮은 대역폭을 가지며, 전력 소비 최소화 및 설계 복잡성 감소에 중점을 둔 저속/저전력 주변 장치 연결에 최적화된 버스입니다.


특징: Non-pipelined 방식으로 한 번에 하나의 전송만 처리하며, 주소와 데이터가 한 클럭 사이클에 동시에 처리되지 않습니다.


APB 상태 다이어그램: IDLE → SETUP → ACCESS 의 3단계로 전송이 이루어집니다.




2.3. 메모리 맵 (Memory Map)
APB 주변 장치들은 다음과 같은 메모리 주소 범위에 할당됩니다.


주변 장치	베이스 주소 (Base Address)
UART		
0x1000_4000 (APB_BASE_ADDR + UART_OFFSET) 





GPIO		
0x1000_3000 (APB_BASE_ADDR + GPIO_OFFSET) 



GPI		
0x1000_2000 (APB_BASE_ADDR + GPI_OFFSET) 



GPO		
0x1000_1000 (APB_BASE_ADDR + GPO_OFFSET) 



RAM		
0x1000_0000 (APB_BASE_ADDR) 


ROM	0x0000_0000
3. 주변 장치 설계 (Peripheral Design)
3.1. RAM
APB Slave 형태로 구현되었으며, 메모리 접근이 발생하면 PSEL과 PENABLE이 HIGH일 때 다음 클럭에 PREADY가 HIGH로 설정됩니다.


메모리 크기: 2 
12
  (0x0000 ~ 0x0FFF)의 32비트 워드 메모리.


주소: PADDR[11:2]를 메모리 주소로 사용합니다.

3.2. GPO (General Purpose Output)
GPO는 출력 전용 포트를 제어합니다.

레지스터:


slv_reg0: Control Register (cr) - 포트별 출력 활성화/비활성화 제어 (offset 0x00).





slv_reg1: Output Data Register (odr) - 실제 출력 데이터 (offset 0x04).




동작: gpo[i]는 cr[i]가 1일 때만 odr[i] 값을 출력하고, 0일 때는 하이 임피던스 상태(1'bz)를 유지합니다.

3.3. GPI (General Purpose Input)
GPI는 입력 전용 포트를 제어합니다.

레지스터:


slv_reg0: Control Register (cr) - 포트별 입력 활성화/비활성화 제어 (offset 0x00).





slv_reg1: Input Data Register (idr) - 실제 입력 데이터 (offset 0x04).



동작: idr[i]는 cr[i]가 1일 때만 gpi[i] 값을 읽어오고, 0일 때는 하이 임피던스(1'bz)를 출력합니다.

3.4. GPIO (General Purpose Input/Output)
GPIO는 입출력 겸용 포트를 제어합니다.

레지스터:


slv_reg0: Control Register (cr) - 포트별 방향 제어 (1: 출력, 0: 입력) (offset 0x00).






slv_reg1: Output Data Register (odr) - 출력 데이터 (offset 0x04).





slv_reg2: Input Data Register (idr) - 입력 데이터 (offset 0x08).


동작: cr[i]가 1이면 gpio[i]는 odr[i]를 출력하고, 0이면 하이 임피던스(1'bz)를 출력합니다. 입력 레지스터 idr[i]는 cr[i]가 0일 때 gpio[i] 값을 읽어옵니다.

3.5. UART (Universal Asynchronous Receiver/Transmitter)
UART 통신을 위한 주변 장치입니다.


구성: APB Interface UART와 Baud_tick_generator, TX/RX Control로 구성됩니다.



레지스터:


Data Register (DR): slv_reg0 (offset 0x00). RX 데이터 읽기, TX 데이터 쓰기.


Status Register (SR): slv_reg1 (offset 0x04). 상태 플래그 읽기.


RXNE (Bit 0): RX Data Not Empty. 수신 데이터 준비 상태.


TXC (Bit 1): TX Complete. 송신 준비 완료 (TX Busy의 반전).



TX/RX 동작 (APB Interface 기준):


TX: Data Register(slv_reg0)에 쓰기 접근 발생 시 tx_start 펄스가 발생하여 전송을 시작합니다.


RX: rx_done 신호가 들어오면 수신 데이터를 slv_reg0에 래치하고 slv_rx_ready_flag(RXNE)를 설정합니다. CPU가 Data Register를 읽으면 이 플래그가 클리어됩니다.

4. 펌웨어 및 검증 (Firmware and Verification)
4.1. C 언어 펌웨어 (C Firmware)
펌웨어는 주기적으로 UART를 통해 현재 상태와 GPO 출력을 수행합니다. 또한, GPI 입력을 통해 세팅 모드에 진입하여 UART로 모드를 전환할 수 있도록 설계되었습니다.



UART 수신 (UART_receive): Status Register의 UART_SR_RXNE 비트를 확인하여 수신이 완료될 때까지 대기(Polling)합니다.



UART 송신 (UART_send): UART Data Register에 값을 쓰고, TX 전송 시간만큼 지연(Delay)을 줍니다.


4.2. SystemVerilog 검증 (SystemVerilog Verification)
APB-UART 주변 장치를 DUT(Device Under Test)로 설정하고, environment에서 interface를 통해 임의의 데이터를 송수신하며 검증합니다.






RX Pass 조건: send_data == rdata 


TX Pass 조건: wdata == received_data 


결과: 총 512번의 TX/RX 사이클에 대해 모두 Pass를 확인했습니다.

4.3. 트러블슈팅 (Troubleshooting)
C 코드를 컴파일하는 과정에서 설계된 RV32I set이 아닌 다른 명령어(예: li)가 컴파일되는 문제가 발생했습니다.



해결책: C 코드에서 다른 명령어 세트를 유발하는 코드를 우회하고, 컴파일러 옵션에 -march=rv32i를 지정하여 RV32I 명령어만 사용하도록 강제했습니다.


5. 결론 및 고찰 (Conclusion)
본 프로젝트는 RV32I CPU에 APB Bus를 연결하고 주변 장치를 직접 설계·통합함으로써 MCU와 유사한 시스템을 구현했습니다. 이를 통해 임베디드 시스템의 구조와 동작 원리를 체감할 수 있었습니다.

https://youtu.be/JyGLBVhcDjw

당초 최대한 간단한 하드웨어를 설계하고 복잡한 소프트웨어로 제어하려 했으나 , RV32I 명령어 세트만으로는 복잡한 기능을 구현하기에 부족함을 느껴 , 하드웨어와 소프트웨어의 조화로운 조합이 중요하다는 것을 깨달았습니다.
