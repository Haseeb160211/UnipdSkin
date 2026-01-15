# UnipdSkin: Flexible Robot Skin Library

This is the Arduino library for the **UnipdSkin** project (University of Padua). It allows you to read raw mutual capacitance data from flexible robot skins using the FT5x06 controller.

For full documentation, tutorials, and fabrication guides, visit the **[Wiki](https://github.com/Haseeb160211/UnipdSkin/wiki)**.

---

## 📺 Fabrication Tutorial
Learn how to build the sensor from scratch.
* **Watch the Video:** [YouTube Tutorial](https://youtu.be/mGCnoJLAu7Y)
* **Read the Guide:** [Fabrication Wiki Page](https://github.com/Haseeb160211/UnipdSkin/wiki/Fabrication-Guide:-Multi%E2%80%90Touch-Mutual-Capacitive-E%E2%80%90Skin)

---

## 🛠️ Setup

1.  **Download** this repository as a `.zip` file.
2.  **Install** it into your Arduino libraries folder. (Need help? See [Importing a .zip Library](https://www.arduino.cc/en/Guide/Libraries)).
3.  **Restart** the Arduino IDE.

---

## 🚀 Working

1.  **Connect** your board following the [Getting Started Guide](https://github.com/Haseeb160211/UnipdSkin/wiki/Getting-Started-with-UnipdSkin).
2.  **Upload** the Arduino example:
    * Go to `File > Examples > UnipdSkin > UnipdSkin_ComputerVision`.
3.  **Visualize** the results:
    * Navigate to the `UnipdSkin_ComputerVision_Processing` folder.
    * Open and run `UnipdSkin_ComputerVision_Processing.pde`.

> **⚠️ Important:** In the Processing file, don't forget to change the `SERIAL_PORT` variable (0, 1, 2...) to match your active board index.
