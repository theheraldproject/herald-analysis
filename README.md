# Fair Efficacy Formula Analysis Scripts

R analysis scripts for the Fair Efficacy Formula for proximity detection protocols in contact tracing apps

## How to use

1. Download and install the protocol test application on two or more
phones.
1. Pick one of the suggested formal tests
1. After running the desired test download the test results CSV folders
1. Place this in a folder named after the phone from the test

Now run the test run analysis script:-

1. Open TestAnalysis.R in RStudio
1. Edit the folder name to be the folder above your phone name subfolders
1. Edit the start and end times to be 10 minutes before and after your test
1. Edit the Contact Event (CE) start and end times to be the time the phones were ALL in contact with each other (i.e. the time the last phone was brought in to the room, and just before the time you turned bluetooth off on the first phone)
1. Select all lines
1. Run the script

This script should be ran for every test

## The output

You will see an accuracy graph and a report graph generated for each phone.

- Report graph - shows communication between that phone and all other phones. If all goes well you should see solid lines (as dots join each other)
- Accuracy graph - shows the RSSI received for each phone during the test. Each phone is colour coded. Expect lots of spurious values, but each colour phone should mostly be the same RSSI value if kept at a constant distance during the test

You also get three summary statistics CSV files:-

- summary-discovery-pairs.csv - Shows a true/false grid for each phone pairing for detection only
- formal-summary.csv - Shows all detection, continuity, and longevity stats as per the Fair Efficacy Formula
- formal-continuity.csv - Shows detection and continuity stats per phone pairing

## Accuracy testing

Accuracy testing works differently. Use the Bluetooth Calibration app to generate data for each phone pairing of interest at all the indicated distances on that app. Then open the FormalAccuracy.R file, read the instructions, and run the script.

This will generate a formal accuracy analysis CSV file, whose data is also used in the fair efficacy formula.

You only need run this script for a representative sample of phone pairs once to generate your accuracy data.

## License & Copyright

Copyright 2020 VMware, Inc.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Assistance

Please report issues here and email oss-coc@vmware.com with any code of conduct open source issues.
