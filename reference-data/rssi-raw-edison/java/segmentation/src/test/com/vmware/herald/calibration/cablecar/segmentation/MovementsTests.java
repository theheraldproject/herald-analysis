//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.segmentation;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.util.Date;

import org.junit.Test;

public class MovementsTests {

	@Test
	public void testEmpty() {
		final Movements movements = new Movements(1000);
		movements.close();
		assertTrue(movements.data.isEmpty());
	}

	@Test
	public void testOne() {
		final Movements movements = new Movements(1000);
		movements.add(new Date(0), 1d);
		movements.close();
		assertFalse(movements.data.isEmpty());
		assertEquals(1, movements.data.size());
		assertEquals(0, movements.data.get(0).time);
		assertEquals(1, movements.data.get(0).inertia, Double.MIN_VALUE);
	}

	@Test
	public void testQuantisationOne() {
		final Movements movements = new Movements(1000);
		movements.add(new Date(179), 1d);
		movements.close();
		assertFalse(movements.data.isEmpty());
		assertEquals(1, movements.data.size());
		assertEquals(0, movements.data.get(0).time);
		assertEquals(1, movements.data.get(0).inertia, Double.MIN_VALUE);
	}

	@Test
	public void testQuantisationTwo() {
		final Movements movements = new Movements(1000);
		movements.add(new Date(179), 1d);
		movements.add(new Date(793), 2d);
		movements.close();
		assertFalse(movements.data.isEmpty());
		assertEquals(1, movements.data.size());
		assertEquals(0, movements.data.get(0).time);
		assertEquals(2, movements.data.get(0).inertia, Double.MIN_VALUE);
	}

	@Test
	public void testQuantisationThree() {
		final Movements movements = new Movements(1000);
		movements.add(new Date(179), 1d);
		movements.add(new Date(793), 2d);
		movements.add(new Date(1379), 3d);
		movements.close();
		assertFalse(movements.data.isEmpty());
		assertEquals(2, movements.data.size());
		assertEquals(0, movements.data.get(0).time);
		assertEquals(2, movements.data.get(0).inertia, Double.MIN_VALUE);
		assertEquals(1000, movements.data.get(1).time);
		assertEquals(3, movements.data.get(1).inertia, Double.MIN_VALUE);
	}
}
