#include <esp_now.h>
#include <WiFi.h>
#include <ESP32Servo.h>

// --- 1. HARDWARE PINS ---
const int SERVO_PIN = 18; // Connect the front steering servo signal wire here
// UART2 default pins: RX = 16, TX = 17 (Connect TX to Car FPGA)

Servo steeringServo;

// --- 2. NETWORK DATA STRUCTURES ---
typedef struct DrivePacket {
  int16_t x;
  int16_t y;
  uint8_t config; 
  uint8_t horn;
} DrivePacket;

typedef struct TelemetryPacket {
  uint8_t real_speed;
  uint8_t status;
} TelemetryPacket;

DrivePacket drive_cmd;
TelemetryPacket car_telem;

// TARGET MAC ADDRESS: The Controller ESP32 (1C:C3:AB:B9:91:E8)
uint8_t controllerAddress[] = {0x1C, 0xC3, 0xAB, 0xB9, 0x91, 0xE8};
esp_now_peer_info_t peerInfo;


// --- 3. SLEW RATE LIMITER VARIABLES ---
int current_servo_angle = 90;
int target_servo_angle  = 90;
unsigned long last_servo_update = 0;

// The "Pacemaker": Milliseconds to wait before moving the servo 1 degree.
// Increase this number (e.g., 10 or 15) if the ESP32 still reboots.
// Decrease this number (e.g., 2 or 3) if the steering feels too sluggish.
const int SERVO_SPEED_DELAY = 5; 


// --- 4. CALLBACKS ---
void OnDataRecv(const esp_now_recv_info_t *esp_now_info, const uint8_t *incomingData, int len) {
  if (len == sizeof(DrivePacket)) {
    memcpy(&drive_cmd, incomingData, sizeof(drive_cmd));
    
    // --- A. TOP SPEED MATH ---
    uint8_t speed_mode = drive_cmd.config & 0b00000011; 
    int max_pwm = 100;
    if (speed_mode == 0) max_pwm = 100;
    else if (speed_mode == 1) max_pwm = 50;
    else if (speed_mode == 2) max_pwm = 75;
    
    int y_norm = map(drive_cmd.y, 0, 4095, -max_pwm, max_pwm);
    if (abs(y_norm) < 10) y_norm = 0; 
    
    uint8_t target_speed = abs(y_norm);
    uint8_t direction = (y_norm >= 0) ? 1 : 0;

    // --- B. SENSITIVITY STEERING MATH ---
    uint8_t sens_mode = (drive_cmd.config >> 2) & 0b00000011; 
    int max_angle = 30; 
    if (sens_mode == 1) max_angle = 20;
    else if (sens_mode == 2) max_angle = 10;
    else if (sens_mode == 3) max_angle = 0; 

    // UPDATE TARGET ANGLE ONLY (Do not write directly to servo here!)
    target_servo_angle = map(drive_cmd.x, 0, 4095, 90 - max_angle, 90 + max_angle);

    // --- C. EXTRACT THROTTLING ---
    uint8_t throttling_mode = (drive_cmd.config >> 4) & 0b00000011;

    // --- D. PACK AND TRANSMIT TO FPGA ---
    uint8_t command_byte = (drive_cmd.horn << 3) | (direction << 2) | throttling_mode;

    Serial2.write(0xAA);         
    Serial2.write(target_speed); 
    Serial2.write(command_byte); 
    Serial2.write(0x55);         

    // --- E. SEND TELEMETRY BACK ---
    car_telem.real_speed = target_speed;
    car_telem.status = 1; 
    esp_now_send(controllerAddress, (uint8_t *) &car_telem, sizeof(car_telem));
  }
}


// --- 5. SETUP ---
void setup() {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, 16, 17);

  steeringServo.attach(SERVO_PIN);
  steeringServo.write(90); // Start mechanically centered

  WiFi.mode(WIFI_STA);
  if (esp_now_init() != ESP_OK) return;
  esp_now_register_recv_cb(OnDataRecv);

  memcpy(peerInfo.peer_addr, controllerAddress, 6);
  peerInfo.channel = 1;  
  peerInfo.encrypt = false;
  esp_now_add_peer(&peerInfo);
}


// --- 6. MAIN LOOP (The Limiter Engine) ---
void loop() {
  // Check if enough time has passed to step the servo
  if (millis() - last_servo_update >= SERVO_SPEED_DELAY) {
    
    // If the servo is not at the target, move it exactly 1 degree
    if (current_servo_angle < target_servo_angle) {
      current_servo_angle++;
      steeringServo.write(current_servo_angle);
    } 
    else if (current_servo_angle > target_servo_angle) {
      current_servo_angle--;
      steeringServo.write(current_servo_angle);
    }
    
    // Reset the timer
    last_servo_update = millis();
  }
}