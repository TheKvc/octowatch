# OctoWatch

OctoWatch is a lightweight, Bash-based dashboard for monitoring multiple 3D printers via OctoPrint’s API. Think of it as a stripped-down, resource-friendly alternative to projects like **OctoFarm** — designed for quick, real-time insights on low-end systems.

It displays real-time information—such as **print progress**, **elapsed/remaining time**, file name, and temperature data—in a clean, color-coded terminal interface.

[octowatch-demo](https://github.com/user-attachments/assets/f581abbe-ed32-4a55-901b-e1e54059282a)

---

## Features

- **Multi-Printer Monitoring:**
  - Monitor multiple 3D printers simultaneously with a single dashboard.
    ![Dashboard Screenshot](https://github.com/user-attachments/assets/7fa24bea-467f-415f-94b8-a197bb728918)

- **Real-Time Monitoring:**  
  - Displays printer status, print progress (with an integrated progress bar)
  - Elapsed and remaining hours, and estimated finish time. (The more you print, the better it predicts Finishing time)
- **Temperature Feedback:**  
  Shows bed and nozzle temperatures, color-coded based on a ±3°C tolerance compared to target values.
- **Resource-Friendly:**
  Loads quickly in the terminal, avoiding the sluggishness of browser-based interfaces. Ideal for Raspberry Pi and other low-end systems.
- **Easy Configuration:**
  Printer settings are stored in an INI file, making setup and adjustments straightforward. There is `printers-default.ini` is bundled with the repository, you can rename it and start editing it with settings of your networks. Some examples are already in the `ini` file for you to quick start.
- **Error Handling & Logging:**
  Logs events and errors to octowatch.log, ensuring you’re always informed of any issues. Logs errors to `octowatch.log` file in the same folder as the script.
- **ANSI & VT100 Formatting:**  
  Uses ANSI color codes and VT100 cursor control for a dynamic, refreshed and smooth terminal display.
- **Configurable Settings:**  
  Hack refresh intervals and customize display parameters directly in the script, by changing few variable values at the top of script.
- **Dependency Check:**  
  Automatically verifies required dependencies, installs them, if needed.

---

## Prerequisites

- **Bash** (v4+ recommended)
- Dependencies: `curl`, `jq`, `git`, `bc`, `awk`  
  (The script checks for and installs missing dependencies on Debian/Ubuntu systems.)

---

## Installation

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/TheKvc/octowatch.git
   cd octowatch
   ```

2. **Configure Your Printers:**

   Create or update the `printers.ini` file in the repository root.  
   Example format:
   ```ini
   [Printer1]
   api_key = YOUR_API_KEY_1
   base_url = http://printer1.local

   [Printer2]
   api_key = YOUR_API_KEY_2
   base_url = http://192.168.0.555
   ```
   Note: There is a Sample File provided in the repo, you can simply rename it to 'printers.ini' and change the internal template values as per your need.

   
  ```bash
  mv "printers-default.ini" "printers.ini"
  nano "printers.ini"
  chmod +x "octowatch.sh"
  ```

---

## Usage

Run the dashboard script:

```bash
./octowatch.sh
```

The script refreshes every few seconds (default interval is set in the script) and displays:

- **Printer:** The printer’s name as specified in the INI file.
- **Status:** Current state (e.g., *Printing*, *Operational*) with bed and nozzle temperatures.
- **File:** The currently printing file (trimmed if too long).
- **Progress:** A progress bar that shows the percentage (centered) and updates dynamically.
- **Elapsed Time / Remaining Time:** Timings in `hh:mm:ss` format, with an estimated finish time based on the current rate.

---

## Customization

- **Refresh Intervals:**  
  Modify `DEFAULT_INTERVAL` and `DEFAULT_SCREEN_REFRESH` in the script to change API fetch and screen refresh timings.
  ![image](https://github.com/user-attachments/assets/5288e327-49a4-4289-beae-50e050e3276c)

  If you reduce the interval to improve smoothness of screen refresh, it directly affects the performance of your octoprint server.
  While printing, I don't want to overload my octoprint server with unnecessary API calls, so I do it every 5 Seconds as i am using two Raspberry pi zero 2W as main controller for both of my Ender 3 Max and Ender 3 v2 3D printers.
  
- **Display Parameters:**  
  Adjust `FILE_NAME_MAX` and the progress bar length or characters in the `progress_bar` function.
- **Colors:**  
  ANSI color variables are defined at the top for easy customization.

---

## Screenshots

![Screenshot from 2025-03-26 09-27-18](https://github.com/user-attachments/assets/b0d7330e-ffbe-4951-a45f-5b17c5466e76)

Notice: Experimental Progress bar... 

![Screenshot from 2025-03-25 09-08-06](https://github.com/user-attachments/assets/83ac708e-15fb-48d9-9a18-1adbb43281a2)

---

## Logging

All error messages and significant events are logged in `octowatch.log` located in the repository folder.

---

## Contributing

Contributions and feedback are welcome! Please **open an issue** or **submit a pull request** if you have improvements or bug fixes.

---

## License

This project is licensed under the MIT License. 

---

## Enjoying OctoWatch?

If this project helps you keep an eye on your 3D printers efficiently, **please consider giving it a star on GitHub**. Your support helps improve the project and motivates further development!

---
