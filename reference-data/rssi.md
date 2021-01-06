# RSSI Investigations

The Herald Project team have conducted basic research into
raw RSSI stability and have concluded it is stable enough,
given enough data, to provide for an accurate distance
analog for Digital Contact Tracing and other proximity or
density application use cases.

We are providing a set of tools and raw data from our own
measurements in order to allow the scientific community to
investigate the applicability and efficacy of their own
rssi to distance conversion algorithms.

## Current data collection code

Both the Herald Demonstration app for [Android] and [iOS]
and the Analysis demo app for [Android] and [iOS] in
this data analytics repository (the root 'app' folder) can
generate thousands of readings for RSSI over a few minutes.
This enables large datasets to be captured.

Moving phones' distance and orientations takes time. We
have also worked therefore on two robotic ways of performing
this distance and orientation calibration, and automated data
collection.

See the [Edison Python file](rssi-raw-edison/edison.py)
file for that automation script which moves two phones
along a piece of string. Below is an image of how that
test works:-

![Edison RSSI measurement test environment set up](rssi-raw-edison/test-environment.png)

## Current datasets

The below data sets are available:-

- RSSI & Accelerometer readings at different distances for 4 phones [Edison RSSI README](rssi-raw-edison/README.md)

## Further datasets

It should be noted that the background data to our Fair Efficacy
Formula tests also uses raw RSSI data for the protocols that
provide raw RSSI. These can be found on the
[Herald Results page](https://vmware.github.io/herald/efficacy/results)
on our website.

## Questions

If any have any questions about our datasets then please
log a GitHub Issue on this site and tag your issue with a 'Question' tag.