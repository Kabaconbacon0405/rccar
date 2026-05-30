# rccar — Drive-by-Wire FR RC Car

A hardware-software co-design project implementing a **Drive-by-Wire**, **FR (Front-engine, Rear-wheel drive)** layout RC car using a **distributed 4-node architecture**. Designed as a foundational build for future autonomous / agentic integrations.

## Architecture

```
  [ Switches ]        [ Joystick ]                          [ Servo ]   [ L298N + Motors ]
       |                   |                                    ^               ^
       v                   v                                    |               |
 +--------------+   +--------------+   ESP-NOW   +-----------+   |   +-----------+
 | Controller   |UART| Controller  | =========> |    Car    |---+   |    Car    |
 |   FPGA       |<==>|   ESP32     | <========= |   ESP32   |UART=>|   FPGA    |
 | (Dashboard)  |9600| (Net Hub)   | telemetry  | (Kinematic|9600  | (ECU)     |
 +--------------+   +--------------+            |   Brain)  |      +-----------+
   7-seg display                                +-----------+
```

| Node | Platform | Role |
|------|----------|------|
| **Controller FPGA** | Verilog @ 100 MHz | Command Dashboard — reads config switches, displays telemetry |
| **Controller ESP32** | C++ / Arduino | Network Hub — joystick + config → ESP-NOW |
| **Car ESP32** | C++ / Arduino | Kinematic Brain — Ackerman steering, servo, packetizes drive cmd |
| **Car FPGA** | Verilog @ 100 MHz | Engine Control Unit — slew-limited 20 kHz PWM to L298N |

## Repository Layout

```
rccar/
├── 1_Controller_Node/
│   ├── Controller_ESP32/        # Arduino sketch (network hub)
│   └── Controller_FPGA/
│       ├── src/                 # Verilog sources
│       └── constraints/         # controller.xdc (Nexys4 DDR)
├── 2_Car_Node/
│   ├── Car_ESP32/               # Arduino sketch (kinematic brain)
│   └── Car_FPGA/
│       ├── src/                 # Verilog sources
│       └── constraints/         # car.xdc (Nexys4 DDR)
└── README.md
```

## Protocols

- **Controller FPGA ↔ Controller ESP32** — UART 9600 8N1.
  - Config out: sync `0xFC` + 1 config byte `[TopSpeed:2][Sensitivity:2][Throttling:2][Record:1][Play:1]`.
  - Telemetry in: sync `0xCF` + `[speed][status]`.
- **Controller ESP32 ↔ Car ESP32** — ESP-NOW (drive packet out, telemetry back).
- **Car ESP32 → Car FPGA** — UART 9600 8N1: `[0xAA sync][speed][speed][direction/config]`.

## FPGA Targets

Both FPGA designs target the **Digilent Nexys4 DDR** (Artix-7 `xc7a100tcsg324-1`), 100 MHz clock. Pin maps are in each node's `constraints/*.xdc`.

## Build

- **FPGA:** open the `*.xpr` in Vivado (or add the `src/` and `constraints/` files to a new project), then synthesize → implement → generate bitstream.
- **ESP32:** open the `.ino` sketches in the Arduino IDE with the ESP32 board package; install `ESP32Servo`.
