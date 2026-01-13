/*
  PROJECT: UnipdSkin Visualization UI
  INSTITUTION: University of Padua (Unipd)
  DESCRIPTION: 
    This file handles the Graphical User Interface (GUI) using the ControlP5 library.
    It creates a sidebar with sliders, toggles, and buttons to control signal processing,
    computer vision parameters, and visualization modes in real-time.
*/

import controlP5.*; // Import the GUI library

// ================== GUI OBJECTS ==================
ControlP5 cp5;         // The main controller object
Accordion accordion;   // Collapsible menu container
RadioButton r1;        // Radio button group for Interpolation Mode

// ================== INTERFACE SETUP ==================
// Called once from the main setup() to initialize all UI elements

void InterfaceSetup() {
  cp5 = new ControlP5(this);
  
  // --------------------------------------------------------
  // GROUP 1: SIGNAL PROCESSING
  // Controls for raw sensor data calibration and filtering
  // --------------------------------------------------------
  Group gSignal = cp5.addGroup("Signal Processing")
    .setBackgroundColor(color(0, 64)) // Semi-transparent background
    .setBackgroundHeight(130);
      
  // Slider: Min Threshold (Background/White Level)
  // Adjusts the lower bound of the signal mapping
  cp5.addSlider("thresholdMin")
    .setPosition(10, 10).setRange(0, 20000)
    .setLabel("MIN THRESH").moveTo(gSignal);

  // Slider: Max Threshold (Touch/Black Level)
  // Adjusts the upper bound of the signal mapping
  cp5.addSlider("thresholdMax")
    .setPosition(10, 25).setRange(0, 20000)
    .setLabel("MAX THRESH").moveTo(gSignal);

  // Button: Calibrate
  // Triggers the baseline recalibration routine
  cp5.addButton("calib")
    .setValue(0).setPosition(10, 55).setSize(100, 20)
    .setLabel("CALIBRATE (C)").moveTo(gSignal);

  // Slider: Noise Gate
  // Sets the cutoff for "Quiet" mode (ignores tiny sensor noise)
  cp5.addSlider("quietCutoff")
    .setPosition(10, 90).setRange(0, 100).setValue(35)
    .setLabel("NOISE GATE").moveTo(gSignal);

  // --------------------------------------------------------
  // GROUP 2: VISUALIZATION
  // Controls for Image Processing (OpenCV) and View Modes
  // --------------------------------------------------------
  Group gCV = cp5.addGroup("Visualization")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(140); // Increased height to prevent cutoff

  // Radio Button: Interpolation Mode
  // Selects between Lanczos (Smooth, High Quality) or Cubic (Fast) upscaling
  r1 = cp5.addRadioButton("imgageProcessing")
    .setPosition(10, 10)
    .setSize(10, 10)
    .setColorForeground(color(120))
    .setColorLabel(color(255))
    .setItemsPerRow(1)                 // Vertical layout
    .setSpacingColumn(50)
    .addItem("LANCZOS4 (SMOOTH)", 4)  // Value 4 corresponds to Imgproc.INTER_LANCZOS4
    .addItem("CUBIC (FAST)", 2)       // Value 2 corresponds to Imgproc.INTER_CUBIC
    .activate(0)                      // Default selection: Lanczos
    .moveTo(gCV); 

  // Custom styling for Radio Button Labels
  for (Toggle t : r1.getItems()) {
    t.getCaptionLabel().setColorBackground(color(255, 0));
    t.getCaptionLabel().getStyle().moveMargin(-7, 0, 0, -3);
    t.getCaptionLabel().getStyle().movePadding(7, 0, 0, 3);
    t.getCaptionLabel().getStyle().backgroundWidth = 100;
    t.getCaptionLabel().getStyle().backgroundHeight = 13;
  }

  // Toggle: Binary View
  // Switches between Greyscale Heatmap (False) and Binary Mask (True)
  cp5.addToggle("enableThreshold")
    .setPosition(10, 60)
    .setSize(10, 10)
    .setLabel("BINARY VIEW")
    .setValue(true) 
    .moveTo(gCV);

  // Slider: Blob Threshold
  // Sets the brightness cutoff for converting Greyscale to Binary
  cp5.addSlider("thresholdBlobMin")
    .setPosition(10, 100).setRange(0, 255)
    .setLabel("BLOB THRESH").moveTo(gCV);

  // --------------------------------------------------------
  // GROUP 3: BLOB DETECTION
  // Controls for the Blob Analysis Overlay
  // --------------------------------------------------------
  Group gBlob = cp5.addGroup("Blob Detection")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(50);

  // Toggle: Show Blobs
  // Enables/Disables drawing of green contours and red center dots
  cp5.addToggle("enableBlobDetection")
    .setPosition(10, 10).setSize(10, 10)
    .setLabel("SHOW BLOBS")
    .setValue(false)
    .moveTo(gBlob);

  // --------------------------------------------------------
  // ACCORDION LAYOUT CONFIGURATION
  // --------------------------------------------------------
  // Places the accordion inside the designated Sidebar area
  accordion = cp5.addAccordion("acc")
    .setPosition(DISPLAY_W + 20, 20)   // Positioned to the right of the sensor display
    .setWidth(260)                 
    .addItem(gSignal)
    .addItem(gCV)
    .addItem(gBlob);

  accordion.open(0, 1, 2);           // Open all groups by default
  accordion.setCollapseMode(Accordion.MULTI);  // Allow multiple groups open at once
}

// ================== EVENT HANDLERS ==================

// Function triggered by the "CALIBRATE" button
public void calib() {
  if(skinPort != null) skinPort.write("c\n"); // Optional: Send reset cmd to microcontroller
  startCalibrationLocal();                    // Trigger local software calibration
}

// General Event Listener for ControlP5
void controlEvent(ControlEvent theEvent) {
  // Handle Radio Button Selection manually
  if (theEvent.isFrom(r1)) {
    imgageProcessing = (int) theEvent.getGroup().getValue();
  }

}
