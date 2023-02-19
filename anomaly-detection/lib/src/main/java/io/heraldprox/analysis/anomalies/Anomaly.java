//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import java.util.Date;

public class Anomaly {
    public final TestDevice receiver;
    public final TestDevice transmitter;
    public final Date from;
    public final Date to;

    public final EventList evidence;

    public final Detector detectedBy;

    public Anomaly(Detector detectedBy,TestDevice receiver, TestDevice transmitter, Date from, Date to, EventList evidence) {
        this.detectedBy = detectedBy;
        this.receiver = receiver;
        this.transmitter = transmitter;
        this.from = from;
        this.to = to;
        this.evidence = evidence;
    }

    public String toString() {
        return detectedBy.describe(this);
    }
}
