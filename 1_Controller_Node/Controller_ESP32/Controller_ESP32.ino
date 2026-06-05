#include <esp_now.h>
#include <WiFi.h>
#include <esp_wifi.h>

// --- 1. HARDWARE PINS ---
const int JOY_X_PIN = 32; // Joystick 1: Pure Steering (X-axis)
const int JOY_Y_PIN = 33; // Joystick 2: Pure Throttle (Y-axis)
const int HORN_PIN  = 25; // Joystick Button for Horn

const int UART2_RX_PIN = 26; // <- Controller FPGA tx_out (config byte)
const int UART2_TX_PIN = 27; // -> Controller FPGA rx_in (telemetry)

// --- 2. DIGITAL FILTER CALIBRATION ---
const int JOY_CENTER_VAL = 2048; // Theoretical center of 12-bit ADC
const int HARDWARE_DEADZONE = 400; // Aggressive filter to completely kill ground bounce bleed

// --- 3. NETWORK DATA STRUCTURES ---
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

uint8_t carAddress[] = {0x70, 0x4B, 0xCA, 0x57, 0xD2, 0xA4}; 
esp_now_peer_info_t peerInfo;

// =============================================================================
//  REVERSE PATH CALLBACK (Car -> Controller)
// =============================================================================
void OnDataRecv(const esp_now_recv_info_t *esp_now_info, const uint8_t *incomingData, int len) {
  if (len != sizeof(TelemetryPacket)) return;
  memcpy(&car_telem, incomingData, sizeof(car_telem));

  Serial.print("Live Car Speed: "); Serial.println(car_telem.real_speed); 

  Serial2.write(0xCF);                 
  Serial2.write(car_telem.real_speed); 
  Serial2.write(car_telem.status);     
}

// =============================================================================
//  SETUP
// =============================================================================
void setup() {
  Serial.begin(115200);
  Serial2.begin(9600, SERIAL_8N1, UART2_RX_PIN, UART2_TX_PIN);

  pinMode(HORN_PIN, INPUT_PULLUP);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect(); 

  esp_wifi_set_promiscuous(true);
  esp_wifi_set_channel(1, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);

  WiFi.setTxPower(WIFI_POWER_8_5dBm);

  if (esp_now_init() != ESP_OK) {
    Serial.println("ESP-NOW Init Failed");
    return;
  }
  esp_now_register_recv_cb(OnDataRecv);

  memcpy(peerInfo.peer_addr, carAddress, 6);
  peerInfo.channel = 1;
  peerInfo.encrypt = false;
  esp_now_add_peer(&peerInfo);

  Serial.println("CONTROLLER ONLINE. Firewall Deadzones Activated...");
}

// =============================================================================
//  MAIN LOOP
// =============================================================================
enum FpgaState : uint8_t { WAIT_SYNC = 0, WAIT_CONFIG };

void loop() {
  static FpgaState tx_state = WAIT_SYNC;
  
  while (Serial2.available() > 0) {
    uint8_t incoming = (uint8_t) Serial2.read();

    switch (tx_state) {
      case WAIT_SYNC:
        if (incoming == 0xFC) { 
          tx_state = WAIT_CONFIG;
        }
        break;

      case WAIT_CONFIG: { // <-- Added opening brace to secure local scope
        drive_cmd.config = incoming; 
        
        // Read raw analog values from isolated joysticks.
        // The ESP32 shares ONE sample-and-hold across all ADC channels, so the
        // first read after switching channels carries residual charge from the
        // previous channel (X bleeding into Y). Take a throwaway read on each
        // channel first so the S/H settles before the sample we keep.
        analogRead(JOY_X_PIN);                       // settle
        int16_t raw_x = analogRead(JOY_X_PIN);
        analogRead(JOY_Y_PIN);                       // settle
        int16_t raw_y = analogRead(JOY_Y_PIN);
        
        // --- THE FIREWALL LOGIC ---
        if (abs(raw_y - JOY_CENTER_VAL) < HARDWARE_DEADZONE) {
          raw_y = JOY_CENTER_VAL;
        }
        if (abs(raw_x - JOY_CENTER_VAL) < HARDWARE_DEADZONE) {
          raw_x = JOY_CENTER_VAL;
        }

        drive_cmd.x = raw_x;
        drive_cmd.y = raw_y;
        drive_cmd.horn = (digitalRead(HORN_PIN) == LOW) ? 1 : 0; 
        
        // Debug output to monitor baseline isolation
        Serial.print("FILTERED X: "); Serial.print(drive_cmd.x);
        Serial.print(" \t| FILTERED Y: "); Serial.println(drive_cmd.y);
        
        esp_now_send(carAddress, (uint8_t *) &drive_cmd, sizeof(drive_cmd));
        
        tx_state = WAIT_SYNC; 
        break;
      } // <-- Added closing brace to seal local scope

      default:
        tx_state = WAIT_SYNC;
        break;
    }
  }
}