/*
  UnipdSkin.h - Library for Unipd Flexible Robot Skin.
  Based on Muca/FT5x06 drivers.
  Created for University of Padua Thesis.
*/

#ifndef UnipdSkin_h
#define UnipdSkin_h

#include "Arduino.h"
#include "Wire.h"

// I2C Address for the Controller
#define I2C_ADDRESS       0x38

// Register Definitions
#define MODE_NORMAL       0x00
#define MODE_TEST         0x40

// Matrix Dimensions (Raw Sensing)
#define NUM_RX            12 // Columns (Sensing)
#define NUM_TX            21 // Rows (Pull Ground)

// Legacy Definitions required for internal logic
#define NUM_COLUMNS       NUM_RX
#define NUM_ROWS          NUM_TX

// Data Type Definition
#define byte uint8_t

class UnipdSkin {
  public:
    UnipdSkin();

    // 1. Initialization
    // Returns 0 on success, 1 on failure
    bool init(); 
    
    // 2. Configuration for Raw Data
    // Set to true to enable the raw capacitive matrix reading
    void useRawData(bool useRaw);

    // 3. Update Function
    // Call this in the loop. Returns true if new data was read.
    bool updated();

    // 4. Data Access
    // The flat array containing raw values (size = NUM_TX * NUM_RX)
    unsigned int *grid;

    // Dimensions available to the user if needed
    unsigned int num_TX = NUM_TX;
    unsigned int num_RX = NUM_RX;

  private:
    // Internal Variables
    bool isInit = false;
    bool rawData = false;
    
    // Active line tracking (default all active)
    bool RX_lines[NUM_RX] = {1,1,1,1,1,1,1,1,1,1,1,1}; 
    bool TX_lines[NUM_TX] = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}; 

    // Internal Helper Functions
    void getRawData();
    byte setRegister(byte reg, byte val);
    void getRegisters(byte reg, byte size, byte * buffer);
};

#endif