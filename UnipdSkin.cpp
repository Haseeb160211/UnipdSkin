/*
  UnipdSkin.cpp - Library for Unipd Flexible Robot Skin.
*/

#include "UnipdSkin.h"

// Constructor
UnipdSkin::UnipdSkin() {}

// 1. Initialization
bool UnipdSkin::init() {
  // Setup I2C
  // Note: Depending on your board, you might need to specify pins here 
  // e.g. Wire.begin(SDA_PIN, SCL_PIN) for ESP32
  Wire.begin(); 
  Wire.setClock(400000); // Fast I2C 400kHz
  Wire.setTimeout(200);

  byte initDone = -1;
  initDone = setRegister(0x00, MODE_NORMAL);

  if (initDone == 0) {
    delay(100);
    isInit = true;
    
    // Set auto-calibration mode internally
    setRegister(0xA7, 0x04); 
    return 0; // Success
  } else {
    Serial.println("[UnipdSkin] Error: I2C Connection Failed. Check SDA/SCL.");
    return 1; // Failure
  }
}

// 2. Enable Raw Data Mode
void UnipdSkin::useRawData(bool useRaw) {
  rawData = useRaw;
  
  // Allocate memory for the grid array
  // We do this dynamically to save RAM if the class is instantiated but not used in raw mode immediately
  if (grid == nullptr) {
      grid = new unsigned int[num_TX * num_RX];   
  }

  if(isInit && useRaw) {
    setRegister(0x00, MODE_TEST); // Switch controller to Test Mode to read raw values
    Serial.println("[UnipdSkin] Mode set to Raw Data Stream");
  }
}

// 3. Update Function
bool UnipdSkin::updated() {
  if (!isInit) return false;

  if(rawData) {
    getRawData();
    return true; // Data updated
  }
  return false;
}

// Internal: Fetch Raw Data from Matrix
void UnipdSkin::getRawData() {
  // Set Test/Read raw mode and Data Read Toggle mode
  setRegister(byte(0x00), byte(0xC0)); 
  
  byte buffer[2 * NUM_RX];
  byte gridTxAddr = 0;
  byte gridRxAddr = 0;
  
  // Iterate through rows (TX)
  for (unsigned int txAddr = 0; txAddr < NUM_TX; txAddr++) {
    if(TX_lines[txAddr] == true) {
      
      // Select the TX line
      setRegister(0x01, NUM_TX - 1 - txAddr); // TX lines seem to be inverted in hardware
      delayMicroseconds(50); // Small delay for signal stabilization
      
      // Read all RX columns for this row
      getRegisters(0x10, 2 * NUM_RX, buffer);

      gridRxAddr = 0;
      for (unsigned int rxAddr = 0; rxAddr < NUM_RX; rxAddr++) {
        if(RX_lines[rxAddr] == true) {
          // Combine High Byte and Low Byte
          grid[(gridTxAddr * num_RX) + gridRxAddr] = (buffer[2 * rxAddr] << 8) | (buffer[2 * rxAddr + 1]);
          gridRxAddr++;
        }
      }
      gridTxAddr++;
    }
  }
}

// Internal: Write I2C Register
byte UnipdSkin::setRegister(byte reg, byte val) {
  Wire.beginTransmission(I2C_ADDRESS);
  Wire.write(reg);
  Wire.write(val); 
  return Wire.endTransmission(false);
}

// Internal: Read Multiple Registers
void UnipdSkin::getRegisters(byte reg, byte size, byte * buffer) {
  Wire.beginTransmission(I2C_ADDRESS);
  Wire.write(reg);
  unsigned int st = Wire.endTransmission(false);
  
  if (st != 0) {
    // Optional: Handle I2C error here
  }
  
  Wire.requestFrom(I2C_ADDRESS, (int)size);
  byte i = 0;
  while (Wire.available()) {
    buffer[i++] = Wire.read();
  }
}