# Anomaly Detector

This detector helps triage issues and correlates evidence for anomalies in
the Herald standard log files during a long running, multi device, efficacy
test.

## Quick start

Build the files first:-

```sh
./gradlew jar
```

And then execute the application:-

```sh
java -cp ./lib/build/libs/lib.jar io.heraldprox.analysis.anomalies.AnomalyDetector ./lib/data/2022-12-03-01 '2022-11-29 22:30:00' '2022-11-29 23:59:00'
```

Replacing the 2022-12-03-01 folder with your test folder, and the start and end date-times, respectively.

This will output a list of anomalies for you to investigate.

## Limitations

The app is currently limited to the following anomaly detection routines:-
- RSSI reception gap of 20 minutes

The app also currently does not:-
- Attempt root cause analysis
- Print out details of the events, of the relevant log file lines, from the anomaly information - just the timings

## License and Copyright

Apache-2.0 for all code. CC-BY 4.0 for all reference data (in the lib/data folder).

Copyright The Herald Project 2022.