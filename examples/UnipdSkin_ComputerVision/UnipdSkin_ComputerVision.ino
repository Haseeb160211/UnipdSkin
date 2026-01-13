/*
  UnipdSkin_ComputerVision.ino
  Reads raw capacitive data from the UnipdSkin sensor and prints it
  as a comma-separated stream for computer vision processing (e.g., Python/OpenCV).
*/

#include <UnipdSkin.h>

// Create the skin object
UnipdSkin skin;

void setup() {
  // High baud rate recommended for fast data streaming
  Serial.begin(115200);

  // Initialize the skin sensor
  if(skin.init() == 0) {
     Serial.println("UnipdSkin Initialized.");
  } else {
     Serial.println("UnipdSkin Init Failed!");
     while(1); // Stop execution
  }
  
  // Enable Raw Data Mode
  skin.useRawData(true); 
}

void loop() {
  sendRawData();
}

void sendRawData() {
  // Check if the sensor has updated data
  if (skin.updated()) {
    
    // Loop through the entire grid (TX * RX)
    for (int i = 0; i < NUM_TX * NUM_RX; i++) {
      
      // Print value
      if (skin.grid[i] > 0) {
        Serial.print(skin.grid[i]);
      } else {
        Serial.print("0"); // Ensure we print 0 for clarity
      }
      
      // Print comma separator, except for the last element
      if (i != (NUM_TX * NUM_RX) - 1) {
        Serial.print(",");
      }
    }
    // Newline indicates end of frame
    Serial.println();
  }
  
  // Small delay to prevent I2C bus saturation (optional)
  // delay(1); 
}