//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import static org.junit.Assert.assertNotNull;

import java.util.Date;

import org.junit.Test;

public class MovementTests {

	@Test
	public void test() {
		assertNotNull(new Movement(0, 0).toString());
		assertNotNull(new Movement(Long.MAX_VALUE, 0).toString());
		assertNotNull(new Movement(Long.MIN_VALUE, 0).toString());
		assertNotNull(new Movement(0, Double.MAX_VALUE).toString());
		assertNotNull(new Movement(0, -Double.MAX_VALUE).toString());
		assertNotNull(new Movement(null, 0).toString());
		assertNotNull(new Movement(new Date(0), 0d).toString());
	}

}
