#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>
#include <ESP32Servo.h>
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

// --- 1. HARDWARE PINS & CALIBRATION ---
const int SERVO_PIN       = 18;
const int STEERING_CENTER = 95;   

const int JOY_X_CENTER   = 2048;
const int JOY_X_DEADZONE = 150; // Aligned for refined response

// Throttle (Y) calibration — measure your stick's raw resting value and set
// JOY_Y_CENTER to it (yours rests high, ~2900, which is why duty showed ~42).
const int JOY_Y_CENTER   = 2048;
const int JOY_Y_DEADZONE = 150;

const int UART2_RX_PIN = 16;      
const int UART2_TX_PIN = 17;      

Servo steeringServo;

// --- 2. NETWORK DATA STRUCTURES ---
typedef struct __attribute__((packed)) DrivePacket {
  int16_t x;
  int16_t y;
  uint8_t config;     
  uint8_t horn;
} DrivePacket;

typedef struct __attribute__((packed)) TelemetryPacket {
  uint8_t real_speed; 
  uint8_t status;
} TelemetryPacket;

DrivePacket     drive_cmd;
TelemetryPacket car_telem;

uint8_t controllerAddress[] = {0x1C, 0xC3, 0xAB, 0xCE, 0x49, 0x40};
esp_now_peer_info_t peerInfo;

volatile bool new_drive_cmd = false;

// =============================================================================
//  LIGHTWEIGHT WI-FI CALLBACK 
// =============================================================================
void OnDataRecv(const esp_now_recv_info_t *esp_now_info, const uint8_t *incomingData, int len) {
  if (len == sizeof(DrivePacket)) {
    memcpy(&drive_cmd, incomingData, sizeof(drive_cmd));
    new_drive_cmd = true;
  } else {
    Serial.println("WARNING: Size Mismatch!");
  }
}

// =============================================================================
//  SETUP
// =============================================================================
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); // Disable brownout loop
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, UART2_RX_PIN, UART2_TX_PIN);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect(); 

  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  WiFi.setTxPower(WIFI_POWER_8_5dBm);  

  if (esp_now_init() != ESP_OK) return;
  esp_now_register_recv_cb(OnDataRecv);

  memcpy(peerInfo.peer_addr, controllerAddress, 6);
  peerInfo.channel = 1;
  peerInfo.encrypt = false;
  esp_now_add_peer(&peerInfo);

  delay(500);
  steeringServo.attach(SERVO_PIN);
  steeringServo.write(STEERING_CENTER);

  Serial.println("CAR READY. Isolation processing online.");
}

// =============================================================================
//  MAIN LOOP
// =============================================================================
enum TelemState : uint8_t { WAIT_SYNC = 0, WAIT_SPEED, WAIT_STATUS };

void loop() {
  
  if (new_drive_cmd) {
    new_drive_cmd = false; 

    // --- A. THROTTLE CONVERSION ---
    uint8_t speed_mode = drive_cmd.config & 0b11;
    int max_pwm = 100;
    
    if      (speed_mode == 1) max_pwm = 80; 
    else if (speed_mode == 2) max_pwm = 90;
    else if (speed_mode == 3) max_pwm = 100;

    // Map centered around 2048
    // Throttle measured relative to the stick's ACTUAL resting value (not a
    // hard-coded 2048), with a deadzone, so a released stick yields EXACTLY 0
    // duty instead of leaking the resting offset (that was the phantom ~42).
    int y_offset = (int)drive_cmd.y - JOY_Y_CENTER;
    if (abs(y_offset) < JOY_Y_DEADZONE) y_offset = 0;

    int y_norm = (y_offset * max_pwm) / 2048;
    y_norm = constrain(y_norm, -max_pwm, max_pwm);

    uint8_t target_speed = (uint8_t) abs(y_norm);
    uint8_t direction    = (y_norm >= 0) ? 1 : 0;

    // --- B. STEERING SENSITIVITY ---
    uint8_t sens_mode = (drive_cmd.config >> 2) & 0b11;
    int max_angle = 40;
    if      (sens_mode == 1) max_angle = 30;
    else if (sens_mode == 2) max_angle = 15;
    else if (sens_mode == 3) max_angle = 0;            

    int x_offset = (int)drive_cmd.x - JOY_X_CENTER;          
    if (abs(x_offset) < JOY_X_DEADZONE) x_offset = 0;        

    int angle_delta = (x_offset * max_angle) / 2048;
    angle_delta = constrain(angle_delta, -max_angle, max_angle);

    int servo_angle = STEERING_CENTER + angle_delta;
    servo_angle = constrain(servo_angle, 0, 180);

    static int last_servo_angle = -1;
    if (servo_angle != last_servo_angle) {
        steeringServo.write(servo_angle);
        last_servo_angle = servo_angle;
    }

    // --- C. TRANSMIT TO CAR FPGA ---
    uint8_t throttling_mode = (drive_cmd.config >> 4) & 0b11;
    uint8_t command_byte = (drive_cmd.horn << 3) | (direction << 2) | throttling_mode;

    Serial2.write(0xAA);          
    Serial2.write(target_speed);  
    Serial2.write(command_byte);  
    Serial2.write(0x55);          
  }

  // --- REVERSE TELEMETRY HANDLING ---
  static TelemState rx_state      = WAIT_SYNC;
  static uint8_t    pending_speed = 0;
  static uint32_t   sync_ms       = 0;
  const  uint32_t   FRAME_TIMEOUT_MS = 20;   

  if (rx_state != WAIT_SYNC && (millis() - sync_ms) > FRAME_TIMEOUT_MS) {
    rx_state = WAIT_SYNC;
  }

  while (Serial2.available() > 0) {
    uint8_t incoming = (uint8_t) Serial2.read();
    switch (rx_state) {
      case WAIT_SYNC:
        if (incoming == 0xCF) {            
          rx_state = WAIT_SPEED;
          sync_ms  = millis();
        }
        break;
      case WAIT_SPEED:
        pending_speed = incoming;          
        rx_state = WAIT_STATUS;
        break;
      case WAIT_STATUS:
        car_telem.real_speed = pending_speed;
        car_telem.status     = incoming;
        esp_now_send(controllerAddress, (uint8_t *) &car_telem, sizeof(car_telem));
        rx_state = WAIT_SYNC;              
        break;
      default:
        rx_state = WAIT_SYNC;
        break;
    }
  }
}