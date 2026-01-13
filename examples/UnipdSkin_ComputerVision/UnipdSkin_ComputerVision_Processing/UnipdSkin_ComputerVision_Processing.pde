/*
  PROJECT: UnipdSkin Visualization
  INSTITUTION: University of Padua (Unipd)
  AUTHOR: Muhammad Haseeb
  DESCRIPTION: 
    This sketch visualizes raw capacitive data from a flexible robot skin.
    It receives a 12x21 matrix of pressure values via Serial, processes the signal
    to remove noise, upscales the low-res grid using Computer Vision (OpenCV),
    and detects touch points using Blob Detection.
  
  DEPENDENCIES:
    - Processing Serial (Standard)
    - OpenCV for Processing (gab.opencv)
    - BlobDetection (blobDetection)
    - ControlP5 (controlP5)
*/

// ================== LIBRARIES ==================
import processing.serial.*;     // For reading data from the Arduino/Microcontroller
import gab.opencv.*;            // For advanced image processing (resizing, thresholding)
import org.opencv.imgproc.Imgproc; // Access to raw OpenCV constants (like INTER_LANCZOS4)
import org.opencv.core.*;       // OpenCV core types (Mat, Size, etc.)
import java.util.*;             // Java utilities (Arrays, Lists)
import blobDetection.*;         // For finding centroids/blobs in the binary image
import controlP5.*;             // For the GUI sidebar (sliders, buttons)

// ================== HARDWARE CONSTANTS ==================
// The physical dimensions of the sensor matrix (rows/columns)
int     SKIN_COLS          = 12;
int     SKIN_ROWS          = 21;
int     SKIN_CELLS         = SKIN_COLS * SKIN_ROWS; // Total pixels (252)

// ================== DISPLAY SETTINGS ==================
// The sensor is tiny (12x21), so we scale it up for the screen.
int     resizeFactor       = 43; 
int     DISPLAY_W          = SKIN_COLS * resizeFactor; 
int     DISPLAY_H          = SKIN_ROWS * resizeFactor;
int     SIDEBAR_WIDTH      = 300; // Extra width allocated for the ControlP5 UI

// ================== SERIAL COMMUNICATION ==================
int     SERIAL_PORT        = 0;       // Index of the USB port (Check console output to confirm)
int     SERIAL_RATE        = 115200;  // Baud rate (Must match Arduino code)
char    SKIN_DATA_EOS      = '\n';    // End of packet character (Newline)
char    SKIN_DATA_SEP      = ',';     // Data separator (Comma)

// ================== GLOBAL VARIABLES ==================
Serial  skinPort;                       // The serial connection object
int[]   skinBuffer = new int[SKIN_CELLS]; // Raw integer array to store incoming data
String  skinData      = null;           // Raw string buffer
boolean skinDataValid = false;          // Flag: true only after a full valid frame is received

// ================== CALIBRATION VARIABLES ==================
// Calibration calculates the "Baseline" (normal state) of the skin
// so we can detect changes (Touches) relative to it.
final int CAL_FRAMES = 50;              // How many frames to average during calibration
boolean calibrating  = false;           // State flag
int     calibLeft    = 0;               // Counter for remaining frames
long[]  acc          = new long[SKIN_CELLS]; // Accumulator for averaging
int[]   baseline     = new int[SKIN_CELLS];  // The calculated "zero" state
boolean baselineReady = false;          // Flag: true when calibration is finished
float   BASE_ALPHA    = 0.01f;          // Adaptive learning rate (how fast baseline follows drift)

// ================== SIGNAL PROCESSING ==================
int[]   work          = new int[SKIN_CELLS]; // The processed "Delta" values (Raw - Baseline)
int     quietCutoff   = 35;             // Noise Gate: signals below this are ignored
int     quietHysFrames= 2;              // Hysteresis: frames needed to confirm "quiet" state
int     quietStreak   = 0;              // Counter for quiet frames

// ================== AUTO-THRESHOLDING ==================
// Dynamically maps the min/max signal values to 0-255 grayscale
boolean autoThreshold = true;
int     thresholdMin  = 9300; // Lower bound (White/Background)
int     thresholdMax  = 9750; // Upper bound (Black/Touch)

// ================== COMPUTER VISION SETTINGS ==================
// Controlled via the Interface GUI
int     imgageProcessing = 4;    // Interpolation Mode: 4=Lanczos (Smooth), 2=Cubic (Sharp)
boolean enableThreshold  = true; // Toggle: View Binary Mask vs View Grayscale

// ================== IMAGES & OPENCV OBJECTS ==================
private OpenCV opencv; 
PImage  skinImage  = createImage(SKIN_COLS, SKIN_ROWS, RGB); // The 12x21 raw heatmap
private PImage destImg;                                      // The high-res upscaled image

// OpenCV Matrices (efficient image containers)
Mat  cvGray, cvResized, cvBinary;

// ================== BLOB DETECTION ==================
BlobDetection blobDetection;
boolean enableBlobDetection = true; // Toggle: Show Green Contours & Red Dots
float   thresholdBlob       = 0.5f; // Brightness level to define a "blob" edge
int     thresholdBlobMin    = 100;  // Minimum binary value

// ================== SETUP FUNCTION ==================
// Runs once at the start of the program
void settings () {
  // Create window size: Visualization Area + Sidebar
  size(DISPLAY_W + SIDEBAR_WIDTH, DISPLAY_H);
  noSmooth(); // Disable anti-aliasing to keep pixel edges sharp during debugging
}

void setup () {
  noStroke();
  
  // 1. Debug: Print available ports to help user configure SERIAL_PORT index
  println("Available Serial Ports:");
  printArray(Serial.list());
  
  // 2. Initialize Computer Vision Logic
  opencv = new OpenCV(this, SKIN_COLS, SKIN_ROWS);
  cvGray    = new Mat();
  cvBinary  = new Mat();
  
  // 3. Initialize Serial Connection
  try {
    skinPort = new Serial(this, Serial.list()[SERIAL_PORT], SERIAL_RATE);
    println("Connected to: " + Serial.list()[SERIAL_PORT]);
  } catch (Exception e) {
    println("[ERROR] Could not connect to Serial Port! Check the index variable.");
  }

  // 4. Initialize Images
  // destination image is significantly larger (resizeFactor) than the source
  destImg = createImage(skinImage.width * resizeFactor, skinImage.height * resizeFactor, RGB);

  // 5. Initialize Blob Detection library
  blobDetection = new BlobDetection(destImg.width, destImg.height);
  blobDetection.setThreshold(thresholdBlob); 

  // 6. Setup the GUI (Loaded from Interface.pde)
  InterfaceSetup();  
  textSize(18);
}

// ================== MAIN DRAW LOOP ==================
// Runs repeatedly (~60 times per second)
void draw() {
  
  // 1. Draw UI Background
  // Creates the gray sidebar on the right side
  fill(180); 
  rect(DISPLAY_W, 0, SIDEBAR_WIDTH, height);

  // 2. Read Serial Data
  // Checks if new bytes are available and parses them into 'skinBuffer'
  readSkinBuffer();

  // 3. Handle Calibration Sequence
  // If calibrating, accumulate data and calculate averages
  if (skinDataValid && calibrating) {
    performCalibration();
    return; // Don't draw the heatmap while calibrating
  }

  // 4. Run the Processing Pipeline
  if (skinDataValid) {
    treatSkinData(); // Signal Processing (Baseline subtract, Noise gate)
    performCV();     // Image Processing (Upscale, Threshold, Draw)
  }
}

// ================== HELPER: READ SERIAL ==================
void readSkinBuffer() {
  if (skinPort == null) return;
  
  // Consume all available data to get the latest packet
  while (skinPort.available() > 0) {
    // Read until newline character
    skinData = skinPort.readStringUntil(SKIN_DATA_EOS);
    
    // Basic validation check
    if (skinData != null && skinData.length() > 10) { 
      // Split CSV string into integer array
      int[] incoming = int(split(skinData, SKIN_DATA_SEP));
      
      // Ensure we received exactly the right number of sensors (12x21 = 252)
      if (incoming.length == SKIN_CELLS) {
         skinBuffer = incoming;
         skinDataValid = true;
      }
    }
  }
}

// ================== HELPER: CALIBRATION ==================
void performCalibration() {
  // Accumulate values
  for (int i = 0; i < SKIN_CELLS; i++) acc[i] += skinBuffer[i];
  
  // Decrement frame counter
  if (--calibLeft <= 0) {
    // Finished: Calculate Average
    for (int i = 0; i < SKIN_CELLS; i++) baseline[i] = (int)(acc[i] / CAL_FRAMES);
    calibrating = false;
    baselineReady = true;
    println("[System] Calibration Complete.");
  }
  
  // Draw a loading bar for visual feedback
  fill(0); rect(0,0, DISPLAY_W, height); // clear screen
  fill(255); // White bar
  rect(10, height/2 - 20, map(CAL_FRAMES-calibLeft, 0, CAL_FRAMES, 0, DISPLAY_W-20), 40);
}

// ================== HELPER: SIGNAL PROCESSING ==================
// Steps 3, 4, 5 of the pipeline
void treatSkinData() {
  skinImage.loadPixels();
  int vmin = 1_000_000, vmax = 0;

  for (int i = 0; i < SKIN_CELLS; i++) {
    int v = skinBuffer[i];

    // --- Adaptive Baseline Update ---
    // If the sensor is mostly stable (diff < 25), slowly update the baseline
    // to account for temperature drift or humidity changes.
    if (baselineReady) {
      int diff = abs(v - baseline[i]);
      if (diff <= 25) { 
        baseline[i] = (int)(BASE_ALPHA * v + (1f - BASE_ALPHA) * baseline[i]); 
      }
    }
    
    // --- Calculate Delta ---
    // Delta = Absolute Difference between Current Reading and Baseline
    int d = baselineReady ? abs(v - baseline[i]) : 0;
    
    // Hard noise floor (ignore tiny jitters < 15)
    if (d < 15) d = 0; 
    work[i] = d;

    // Track min/max for auto-scaling
    if (d < vmin) vmin = d;
    if (d > vmax) vmax = d;
  }

  // --- Auto-Thresholding ---
  // Adjusts the visual range to fit the current signal strength
  int span = max(10, vmax - vmin);
  if (autoThreshold) {
    thresholdMin = vmin + span / 20;   
    thresholdMax = vmax - span / 20;   
    // Update the UI Sliders so the user can see the values changing
    if (cp5 != null) {
      cp5.getController("thresholdMin").setValue(thresholdMin);
      cp5.getController("thresholdMax").setValue(thresholdMax);
    }
  }

  // --- Quiet/Noise Check ---
  // If the strongest signal is still very weak (below quietCutoff),
  // assume the sensor is empty and black out the screen to reduce noise.
  boolean isQuiet = (baselineReady && vmax <= quietCutoff);
  quietStreak = isQuiet ? (quietStreak + 1) : 0;
  
  if (quietStreak >= quietHysFrames) {
    Arrays.fill(skinImage.pixels, color(0)); 
    skinImage.updatePixels();
    return; // Exit early
  }

  // --- Render to Pixel Buffer ---
  // Map the Delta values to 0-255 grayscale based on thresholds
  float denom = max(1.0f, (float)(thresholdMax - thresholdMin));
  for (int i = 0; i < SKIN_CELLS; i++) {
    float t = (work[i] - thresholdMin) / denom;
    t = constrain(t, 0, 1);
    float g = 255.0f * t; 
    skinImage.pixels[i] = color(g, g, g); 
  }
  skinImage.updatePixels();
}

// ================== HELPER: COMPUTER VISION ==================
// Steps 6 - 11 of the pipeline
void performCV() {
  // 1. Load the 12x21 low-res image into OpenCV
  opencv.loadImage(skinImage);
  cvGray = opencv.getGray(); 

  // 2. Resize/Upscale
  // We use Lanczos or Cubic interpolation to smooth the tiny grid into a large image
  Size sz = new Size(destImg.width, destImg.height);
  cvResized = new Mat(destImg.height, destImg.width, cvGray.type());
  
  int interp = (imgageProcessing == 2) ? Imgproc.INTER_CUBIC : Imgproc.INTER_LANCZOS4;
  Imgproc.resize(cvGray, cvResized, sz, 0, 0, interp); 

  // 3. Binary Thresholding
  // Converts grayscale to pure Black & White (Blob vs Background)
  cvBinary = new Mat(destImg.height, destImg.width, CvType.CV_8UC1);
  Imgproc.threshold(cvResized, cvBinary, thresholdBlobMin, 255, Imgproc.THRESH_BINARY);
  
  // 4. Morphological Filtering (Noise Cleaning)
  // 'Open' removes small white noise specks. 'Close' fills small black holes inside blobs.
  Mat kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, new Size(5,5));
  Imgproc.morphologyEx(cvBinary, cvBinary, Imgproc.MORPH_OPEN, kernel);
  Imgproc.morphologyEx(cvBinary, cvBinary, Imgproc.MORPH_CLOSE, kernel);

  // 5. Visualization Decision
  // The toggle in the UI decides if we see the smooth grayscale or the raw binary mask
  if (enableThreshold) {
    opencv.toPImage(cvBinary, destImg);
  } else {
    opencv.toPImage(cvResized, destImg);
  }
  
  // Draw the final image to the screen at (0,0)
  image(destImg, 0, 0);

  // 6. Blob Detection
  // If enabled, find connected components (blobs) and draw them
  if (enableBlobDetection) {
    blobDetection.computeBlobs(destImg.pixels);
    drawBlobs();
  }
}

// ================== HELPER: DRAW BLOBS ==================
void drawBlobs() {
  Blob blob;
  for (int n = 0; n < blobDetection.getBlobNb(); n++) {
    blob = blobDetection.getBlob(n);
    if (blob != null) {
      
      // Draw Contours (Green Lines)
      strokeWeight(2); stroke(0, 255, 0);
      for (int m = 0; m < blob.getEdgeNb(); m++) {
        EdgeVertex eA = blob.getEdgeVertexA(m);
        EdgeVertex eB = blob.getEdgeVertexB(m);
        if (eA != null && eB != null) {
          // Coordinates are normalized (0.0 to 1.0), so we multiply by display dimensions
          line(eA.x*DISPLAY_W, eA.y*height, eB.x*DISPLAY_W, eB.y*height);
        }
      }
      
      // Draw Center (Red Dot)
      fill(255,0,0); noStroke();
      ellipse(blob.x*DISPLAY_W, blob.y*height, 10, 10);
    }
  }
}

// ================== HELPER: EXTERNAL CALIBRATION ==================
// Called by the "Calibrate" button in Interface.pde
void startCalibrationLocal() {
  java.util.Arrays.fill(acc, 0L); // Reset accumulators
  calibLeft = CAL_FRAMES;         // Reset frame counter
  calibrating = true;             // Enable flag
  baselineReady = false;          // Invalid baseline during calibration
  println("Calibrating...");
}
