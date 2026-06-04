#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

// --- 1. HARDWARE PINS ---
const int JOY_X_PIN = 32; // Analog Joystick X-axis
const int JOY_Y_PIN = 33; // Analog Joystick Y-axis
const int HORN_PIN  = 25; // Joystick Digital Push Button

const int UART2_RX_PIN = 26; // <- Controller FPGA tx_out (config byte)
const int UART2_TX_PIN = 27; // -> Controller FPGA rx_in (telemetry)

// --- 2. NETWORK DATA STRUCTURES (Byte-identical to Car ESP32) ---
// The __attribute__((packed)) forces the ESP32 compiler to lock the size to exact bytes!
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

// TARGET MAC ADDRESS: Your Physical Car ESP32
uint8_t carAddress[] = {0x70, 0x4B, 0xCA, 0x57, 0xD2, 0xA4}; 
esp_now_peer_info_t peerInfo;

// =============================================================================
//  REVERSE PATH CALLBACK (Car -> Controller)
// =============================================================================
void OnDataRecv(const esp_now_recv_info_t *esp_now_info, const uint8_t *incomingData, int len) {
  if (len != sizeof(TelemetryPacket)) return;
  memcpy(&car_telem, incomingData, sizeof(car_telem));

  // ADD THIS PRINT LINE:
  Serial.println(car_telem.real_speed); 

  Serial2.write(0xCF);                 // Sync Byte 
  Serial2.write(car_telem.real_speed); // Speed Byte
  Serial2.write(car_telem.status);     // Status Byte
}

// =============================================================================
//  SETUP
// =============================================================================
void setup() {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, UART2_RX_PIN, UART2_TX_PIN);

  pinMode(HORN_PIN, INPUT_PULLUP);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();                    // <-- Kills background router searching

  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  WiFi.setTxPower(WIFI_POWER_8_5dBm);   // Prevent thermal brownouts

  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW Init Failed");
    return;
  }
  esp_now_register_recv_cb(OnDataRecv);

  memcpy(peerInfo.peer_addr, carAddress, 6);
  peerInfo.channel = 1;
  peerInfo.encrypt = false;
  esp_now_add_peer(&peerInfo);

  Serial.println("CONTROLLER ONLINE. Operational on Channel 1...");
}

// =============================================================================
//  MAIN LOOP: Parses Controller FPGA Commands & Transmits over Wi-Fi
// =============================================================================
enum FpgaState : uint8_t { WAIT_SYNC = 0, WAIT_CONFIG };

void loop() {
  static FpgaState tx_state = WAIT_SYNC;
  
  // Non-blocking UART parser for incoming Controller FPGA configuration frames
  while (Serial2.available() > 0) {
    uint8_t incoming = (uint8_t) Serial2.read();

    switch (tx_state) {
      case WAIT_SYNC:
        if (incoming == 0xFC) { // Forward Path Sync Byte from FPGA
          tx_state = WAIT_CONFIG;
        }
        break;

      case WAIT_CONFIG:
        drive_cmd.config = incoming; 
        drive_cmd.x = analogRead(JOY_X_PIN);
        drive_cmd.y = analogRead(JOY_Y_PIN);
        drive_cmd.horn = (digitalRead(HORN_PIN) == LOW) ? 1 : 0; 
        
        Serial.print("JOY_X (Steer): "); Serial.print(drive_cmd.x);
        Serial.print(" \t| JOY_Y (Throttle): "); Serial.println(drive_cmd.y);
        
        esp_now_send(carAddress, (uint8_t *) &drive_cmd, sizeof(drive_cmd));
        
        // ADD THIS PRINT LINE:
        Serial.println("Packet Sent to Car!"); 
        
        tx_state = WAIT_SYNC; 
        break;

      default:
        tx_state = WAIT_SYNC;
        break;
    }
  }
}