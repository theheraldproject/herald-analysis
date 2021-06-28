# Test Automation

This repository contains a simple test automation tool for remote control of test devices running the Herald demo app. The tool enables broadcasting of commands for action by all connected test devices, and also upload of status and log data from test devices to the server. The aim of this tool is to enable frequent regression testing on many real devices by reducing the time and effort required for a test run.

## Overview

The test automation solution consists of a central test server and any number of test clients. The test client has been integrated into the Herald demo app (not the Herald library). The HTTP test server exposes a REST API for the test clients to report current status and download pending commands for action. The supported commands are:

- **start** : Switch on SensorArray to detect other Herald devices and measure proximity to these devices.
- **stop** : Switch off SensorArray to stop detection and measurement.
- **upload(file)** : Upload *file* from test client to test server.
- **clear** : Clear all log files on the test client and reset user interface to default state, ready for another test.

The solution has been designed to minimise impact on test results. It uses HTTP instead of HTTPS because it is intended to only be used on a private network for testing purposes; but more importantly, this avoids the use of computationally expensive cryptographic functions, and also blocking functions such as `SecureRandom` that has been shown to halt execution on idle Android devices, thus skewing test results.

## Instruction

### Start test automation server

1. Clone `herald-analysis` repository and open a Terminal in the `test-automation` folder.
2. Start test server using the command `java -jar bin/automatedTestServer.jar [address] [port] [backlog] [threads] [upload]` where `address` is the server address, `port` is the server port, `backlog` is the HTTP request queue size, `threads` is the number of concurrent requests that can be handled by the server, and `upload` is the upload folder. As an example, `java -jar bin/automatedTestServer.jar 192.168.4.30 9999 100 10 ~/upload` will start a test server at `http://192.168.4.30:9999` that can queue up to 100 pending requests, process up to 10 requests concurrently, and stores uploaded files in `~/upload`.
3. Check test server is accessible using `curl` by executing `curl http://server:port` (e.g. `curl http://192.168.4.30:9999`). This should show help text listing all the support commands on the REST API.

While it is possible to use a web browser to access the REST API, it is not recommended. The command line tool `curl` is more reliable because web browsers often pre-fetch queries, thus generating unintentional calls that may introduce pending commands by accident (e.g. `http://server:port/broadcast?commands=clear` which clears all the logs and resets the devices).

### Enable test automation on Herald demo app

1. Clone `herald-for-ios` or `herald-for-android` repository
2. For Android, change `io.heraldprox.herald.app.AppDelegate.automatedTestServer` from `null` to `http://server:port` (e.g. `http://192.168.4.30:9999`).
3. For iOS, change `Herald-for-iOS\AppDelegate.swift` to set `automatedTestServer` from `nil` to `http://server:port` (e.g. `http://192.168.4.30:9999`).
4. Deploy and start Android and iOS demo app on test devices.
5. Ensure both Bluetooth and WiFi are enabled on the demo app, and the test device is connected to the same network as the server.

Changing the parameter `automatedTestServer` from `null` or `nil` to the address and port of the test server will mean:
- When the demo app starts, the SensorArray will be **off** by default (rather than **on**).
- The demo app will send a status report to the test server once a minute and download pending commands from the server for action. The status report will include the phone model, operating system (OS), OS version, and SensorArray status (on/off).
- Please note, the iOS demo app will reliably communicate with the server and action pending commands while the app is in the background only if SensorArray is **on**, otherwise communication between the iOS demo app and server will pause unless the demo app is in the foreground. While many iOS versions will support a short period of background activities, most will halt unless `Background Mode` for `Audio` has been enabled, however this is likely to skew test results. The recommendation is to either start the iOS demo app SensorArray manually using the switch on the user interface, or put the app in background mode once the start command has been actioned. Given background detection of both iOS and Android devices have already been proven in previous tests, this should be acceptable for most regression tests.

## Conduct test manually

1. Open a Terminal on the server and execute `curl http://server:port/status?csv` to confirm all test devices are connected to the server. This should list all connected devices and last seen time. Please note, the last seen time for iOS devices may not be recent if the demo app is in background mode. Move the iOS demo app to foreground to resume regular communication with the server if the SensorArray is **off**.
2. Start the test by executing `curl http://server:port/broadcast?commands=start` to **start** all test devices. Executing `curl http://server:port/status?csv` immediately should show most devices have **start** as the pending command. If the value is `null`, it means the command has already been delivered to the device.
3. Executing `curl http://server:port/status?csv` after a few minutes should show all test devices with status **on**, to confirm the SensorArray has been switched **on** correctly on the device. If it is showing **off** and there is a pending command of **start**, it is likely to be an iOS device where the demo app is running in the background or the screen lock has been automatically activated. Bring the iOS demo app to foreground will resolve this problem.
4. To end the test, execute `curl http://server:port/broadcast?commands=stop` to **stop** all test devices. Executing `curl http://server:port/status?csv` after a few minutes should show all test devices with status **off**.
5. To obtain test results, execute `curl http://server:port/macro?script=upload` to request all the efficacy test logs (e.g. `contacts.csv`, `detection.csv`, `battery.csv`) from all test devices. Alternatively, use `curl http://server:port/macro?script=upload&scope=all` to include the `log.txt` file, which can be > 1GB for long tests. The uploaded files shall be stored in the upload folder on the server (see `upload` parameter of the server). Files shall be organised automatically in a new sub-folder. Its name is derived from the time of the `script=upload` request. Files for each device are stored in a sub-folder named after the device model and payload (only retaining the letters and numbers).
6. To reset the test devices, ready for the next test, execute `curl http://server:port/broadcast?commands=clear`. This will clear all the demo app log files on the device and reset the user interface to default state.

## Conduct test automatically

The manual test sequence can be fully automated by executing `curl http://server:port/macro?script=test&for=N` where `N` is the number of hours (in decimal). For example, `curl http://server:port/macro?script=test&for=5.5` will run the test for 5 hours 30 minutes. The macro will issue a **start** command immediately, then issue a **stop** command after `N` hours, followed by the equivalent of `script=upload&scope=all` to obtain all log files from all devices.
