# rccar — Drive-by-Wire FR RC Car

A hardware–software co-design project implementing a **Drive-by-Wire**, **FR (Front-engine, Rear-wheel drive)** layout RC car using a **distributed 4-node architecture**: two FPGAs (Digilent Nexys4 DDR) and two ESP32s (NodeMCU-32S) bridged wirelessly with ESP-NOW. Designed as a foundational build for future autonomous / agentic integrations.

## Architecture

```
   Switches + Paddles          2× Joysticks           Steering Servo            L298N + Motors
          │                         │                           │                         │
          ▼                         ▼                           ▼                         ▼
 ┌──────────────┐        ┌──────────────┐        ┌──────────────┐        ┌──────────────┐
 │  Controller  │  UART  │  Controller  │ ESP-NOW│     Car      │  UART  │     Car      │
 │     FPGA     │◄══════►│    ESP32     │◄══════►│    ESP32     │◄══════►│     FPGA     │
 │ (Dashboard)  │  9600  │  (Net Hub)   │  Ch.1  │ (Kinematics) │  9600  │    (ECU)     │
 └──────────────┘        └──────────────┘        └──────────────┘        └──────────────┘
         │                                                                        │
         └─ 7-seg speedometer                                      Horn (2.4 kHz) ──┘
```

| Node | Platform | Role |
|------|----------|------|
| **Controller FPGA** | Verilog @ 100 MHz | Command Dashboard — paddle-shift gearbox, config switches, telemetry speedometer |
| **Controller ESP32** | C++ / Arduino | Network Hub — joysticks + config → ESP-NOW; relays telemetry to the FPGA |
| **Car ESP32** | C++ / Arduino | Kinematic Brain — steering math, servo, packetizes drive command, relays telemetry |
| **Car FPGA** | Verilog @ 100 MHz | Engine Control Unit — slew-limited 20 kHz PWM to L298N, horn, IR speed encoder |

## Repository Layout

```
rccar/
├── 1_Controller_Node/
│   ├── Controller_ESP32/Controller_ESP32.ino
│   └── Controller_FPGA/
│       ├── src/            top_controller, transmission_control, switch_debouncer,
│       │                   uart_tx, uart_rx, telemetry_parser, seven_seg_mux
│       └── constraints/    controller.xdc
├── 2_Car_Node/
│   ├── Car_ESP32/Car_ESP32.ino
│   └── Car_FPGA/
│       ├── src/            top_car, uart_rx, car_fsm, slew_rate_limiter, pwm_generator,
│       │                   speed_encoder, uart_tx, car_horn, seven_seg_car
│       └── constraints/    car.xdc
└── README.md
```

## Data Flow & Protocols

**Config byte** (built by the Controller FPGA, used everywhere):
```
bit:   7 6   5 4        3 2          1 0
       0 0   throttling sensitivity  gear/top-speed
```

| Link | Medium | Frame |
|------|--------|-------|
| Controller FPGA → ESP32 | UART 9600 8N1 (1 ms inter-byte gap) | `[0xFC][config]` |
| ESP32 → Controller FPGA | UART 9600 8N1 | `[0xCF][real_speed][status]` |
| Controller ESP32 ↔ Car ESP32 | ESP-NOW, Wi-Fi **Channel 1** | `DrivePacket` out / `TelemetryPacket` back |
| Car ESP32 → Car FPGA | UART 9600 8N1 | `[0xAA][speed][command][0x55]` |
| Car FPGA → Car ESP32 | UART 9600 8N1 (every 100 ms) | `[0xCF][real_speed][status]` |

```c
struct DrivePacket     { int16_t x; int16_t y; uint8_t config; uint8_t horn; };   // packed
struct TelemetryPacket { uint8_t real_speed; uint8_t status; };                   // packed
// command byte to Car FPGA = [horn:3][direction:2][throttling:1:0]
```

### Protocol descriptions

Data moves in two directions — a **forward pipeline** that carries driver intent to the
motors, and a **reverse pipeline** that carries measured wheel speed back to the dashboard.
Every link is framed with a unique **sync byte** so a receiver can always re-align to the
start of a packet after noise or a reboot, and all UART hops run **9600 8N1**.

1. **Controller FPGA → Controller ESP32 (config, UART `0xFC`).**
   The dashboard FPGA packs the gear (from the paddle-shift FSM), sensitivity and throttling
   switches into one config byte and streams `[0xFC][config]` every ~50 ms. A ~1 ms idle
   "breather" gap separates the two bytes so the ESP32's byte-at-a-time parser never glues
   them together. The ESP32 hunts for `0xFC`, then takes the next byte as `config`.

2. **Controller ESP32 → Car ESP32 (drive, ESP-NOW).**
   The hub samples both joysticks + the horn button, attaches the latest `config`, and sends
   a `DrivePacket` over **ESP-NOW on Wi-Fi Channel 1** (connectionless, ~1 ms latency, no
   router). Both ESP32s call `WiFi.disconnect()` and lock channel 1 so the radios can't drift
   off hunting for access points. ESP-NOW already CRC-checks frames, so no sync byte is needed.

3. **Car ESP32 → Car FPGA (drive, UART `0xAA`…`0x55`).**
   The Car ESP32 does the kinematics (servo angle, speed, direction) and emits a 4-byte frame
   `[0xAA][speed][command][0x55]`. It is **bracketed** by a head (`0xAA`) and tail (`0x55`)
   byte: the Car FPGA's `car_fsm` only commits the values to the motors if the `0x55` tail
   arrives where expected, rejecting any truncated/corrupt packet.

4. **Car FPGA → Car ESP32 (telemetry, UART `0xCF`).**
   The `speed_encoder` counts IR pulses over a 100 ms window; the FPGA then streams
   `[0xCF][real_speed][status]` (again with 1 ms inter-byte gaps). The Car ESP32 parses it
   non-blockingly and re-packs it into a `TelemetryPacket`.

5. **Car ESP32 → Controller ESP32 (telemetry, ESP-NOW)** then
   **Controller ESP32 → Controller FPGA (telemetry, UART `0xCF`).**
   The telemetry rides ESP-NOW back to the hub, which immediately re-serializes it as
   `[0xCF][real_speed][status]`. The Controller FPGA's `telemetry_parser` recovers the speed
   and drives the 7-segment speedometer.

Sync bytes are deliberately distinct per direction so cross-talk can't be mis-framed:
`0xFC` = config out, `0xCF` = telemetry, `0xAA`/`0x55` = drive frame head/tail.

## Feature Highlights

- **Paddle-shift gearbox** (`transmission_control.v`): debounced up/down paddles drive a gear FSM → top-speed cap (50/75/100 %).
- **Steering** (Car ESP32): joystick X mapped to a servo around an 85° trim, range limited by the sensitivity bits, with a calibrated center + deadzone (no at-rest jiggle).
- **Throttle** (Car ESP32): joystick Y → 0–100 % duty + direction, calibrated center + deadzone.
- **Acceleration curve** (`slew_rate_limiter.v`): throttling bits select how fast PWM ramps to target (instant / 2.5 / 5 / 10 ms per step).
- **Motor drive** (`pwm_generator.v`): 20 kHz PWM to L298N `ENA/ENB`, direction on `IN1–IN4`.
- **Horn** (`car_horn.v`): 2.4 kHz PWM beep, forced to 0 when idle (direct-drive, Pmod JC1).
- **IR speedometer** (`speed_encoder.v`): 2-FF synchronizer + edge counter over a 100 ms window → live speed back to the Controller FPGA's 7-seg display.
- **Car 7-seg** (`seven_seg_car.v`): live PWM duty on the rightmost 3 digits (e.g. `100`/` 90`/` 80`).

## Pin Map (Nexys4 DDR, Artix-7 `xc7a100tcsg324-1`, 100 MHz on E3)

**Controller FPGA** — rst SW0 (J15); sensitivity SW1–2; throttling SW3–4; paddles JA1/JA2; UART `rx_pin` JB1 (D14) / `tx_out` JB2 (F16); 7-seg on the standard display pins.

**Car FPGA** — rst SW0 (J15); `rx_pin` JA4 (G17); L298N on JA1–3/7–9; `tx_pin` JB1 (D14); IR `sensor_pin` JB2 (F16, internal pull-up); horn JC1 (K1); 7-seg display; *temporary* bring-up LEDs LD0 (sensor) / LD1 (heartbeat).

## ESP32 Calibration

The joystick center values are board-specific — measure and set them, or the car will creep at rest:
- Controller: `JOY_CENTER_VAL`, `HARDWARE_DEADZONE`.
- Car: `JOY_X_CENTER` / `JOY_X_DEADZONE` (steering), `JOY_Y_CENTER` / `JOY_Y_DEADZONE` (throttle), `STEERING_CENTER` (servo trim).

## Build

- **FPGA:** open the `*.xpr` in Vivado (or add the `src/` + `constraints/` files to a new Nexys4 DDR project), then synthesize → implement → generate bitstream → program.
- **ESP32:** open each `.ino` in the Arduino IDE with the ESP32 board package; install **ESP32Servo**. Set each board's peer MAC (`carAddress` / `controllerAddress`) to your physical boards.

## Known bring-up notes

- **Temporary debug hooks** remain in the Car FPGA (`led[1:0]` + heartbeat) for IR-encoder bring-up; remove once the sensor is verified.
- The IR module's `DO` must actively toggle (tune its comparator pot) and **share ground** with the FPGA, or `real_speed` reads 0.
- Power-cycling the Controller ESP32 can stall the link on marginal USB power (Wi-Fi inrush brownout) — use a solid supply / add a bulk cap.
