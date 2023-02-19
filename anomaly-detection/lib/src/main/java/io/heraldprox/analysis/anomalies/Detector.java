//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import java.util.Date;
import java.util.Collection;

public interface Detector {
    public Collection<Anomaly> detect(TestFolder testRun,Date startBound,Date endBound);

    public String describe(Anomaly anomaly);
}
