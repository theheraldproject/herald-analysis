//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

public enum EventType {
    // From the log file
    LogDebug,
    LogFault,
    LogInfo,

    // From the contacts.csv file
    ContactDetected,
    ContactRead,
    ContactMeasure,
    ContactShare,
    ContactVisit,
    ContactIsHerald,
    ContactDeleted,

    // From the detection.csv file
    DetectionBroadcastIdLoggedBefore,
}
