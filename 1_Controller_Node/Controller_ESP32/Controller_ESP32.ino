#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

// --- 1. HARDWARE PINS ---
const int JOYSTICK_X_PIN = 32;
const int JOYSTICK_Y_PIN = 33;
const int JOYSTICK_SW_PIN = 25; // Connect joystick 'SW' to this pin

// UART2 default pins: RX = 16 (From FPGA), TX = 17 (To FPGA)

// --- 2. NETWORK DATA STRUCTURES ---
// What we send TO the car
typedef struct DrivePacket {
  int16_t x;
  int16_t y;
  uint8_t config; // The 8-bit dashboard switch byte from Controller FPGA
  uint8_t horn;   // 1 = Honk, 0 = Silent
} DrivePacket;

// What we receive FROM the car
typedef struct TelemetryPacket {
  uint8_t real_speed; // 0-100%
  uint8_t status;     // Battery or error codes
} TelemetryPacket;

DrivePacket drive_cmd;
TelemetryPacket car_telem;

// TARGET MAC ADDRESS: The Car ESP32 (1C:C3:AB:B9:8A:A4)
uint8_t carAddress[] = {0x1C, 0xC3, 0xAB, 0xB9, 0x8A, 0xA4}; 
esp_now_peer_info_t peerInfo;

// --- 3. CALLBACKS ---
void OnDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  // Silent success
}

void OnDataRecv(const esp_now_recv_info_t *esp_now_info, const uint8_t *incomingData, int len) {
  if (len == sizeof(TelemetryPacket)) {
    memcpy(&car_telem, incomingData, sizeof(car_telem));
    
    // Forward telemetry to the Controller FPGA's 7-segment display
    Serial2.write(0xCF); // Sync Byte
    Serial2.write(car_telem.real_speed);
    Serial2.write(car_telem.status);
  }
}

// --- 4. SETUP ---
void setup() {
  Serial.begin(115200); 
  Serial2.begin(9600, SERIAL_8N1, 16, 17); 

  // Initialize the Joystick Button with an internal Pull-Up resistor
  pinMode(JOYSTICK_SW_PIN, INPUT_PULLUP);

  WiFi.mode(WIFI_STA);
  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  if (esp_now_init() != ESP_OK) return;

  // FIX: Cast the callback to bypass the strict v3.0 type conversion error
  esp_now_register_send_cb((esp_now_send_cb_t)OnDataSent);
  esp_now_register_recv_cb(OnDataRecv);

  // Register the Car as a peer
  memcpy(peerInfo.peer_addr, carAddress, 6);
  peerInfo.channel = 1;  
  peerInfo.encrypt = false;
  if (esp_now_add_peer(&peerInfo) != ESP_OK) return;

  drive_cmd.config = 0x00; 
  drive_cmd.horn = 0;
}

// --- 5. MAIN LOOP ---
void loop() {
  drive_cmd.x = analogRead(JOYSTICK_X_PIN);
  drive_cmd.y = analogRead(JOYSTICK_Y_PIN);

  // Read the button: INPUT_PULLUP means LOW when pressed, HIGH when released.
  // We invert it so 1 = Pressed, 0 = Released.
  drive_cmd.horn = (digitalRead(JOYSTICK_SW_PIN) == LOW) ? 1 : 0;

  // Read the Controller FPGA config byte over UART
  while (Serial2.available() >= 2) {
    if (Serial2.read() == 0xFC) {
      drive_cmd.config = Serial2.read();
    }
  }

  // Blast the packet to the Car
  esp_now_send(carAddress, (uint8_t *) &drive_cmd, sizeof(drive_cmd));

  delay(20); // ~50Hz transmission rate
}