//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

package com.vmware.herald.calibration.cablecar.util;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.logging.Level;
import java.util.logging.Logger;

public class TextFile implements AutoCloseable {
	private final static Logger logger = Logger.getLogger(TextFile.class.getName());
	public final File file;
	private final OutputStream echoStream;
	private FileOutputStream fileOutputStream = null;

	public TextFile(final File folder, final String filename) {
		this(folder, filename, null);
	}

	public TextFile(final File folder, final String filename, final OutputStream echoStream) {
		if (!folder.exists()) {
			if (!folder.mkdirs()) {
				logger.log(Level.SEVERE, "Make folder failed (folder=" + folder + ")");
			}
		}
		this.file = new File(folder, filename);
		this.echoStream = echoStream;
		try {
			this.fileOutputStream = new FileOutputStream(file);
		} catch (Throwable e) {
			logger.log(Level.SEVERE, "Failed to create file " + file, e);
		}
	}

	/// Append line to new or existing file
	public synchronized void write(final String line) {
		final byte[] bytes = (line + "\n").getBytes();
		if (echoStream != null) {
			try {
				echoStream.write(bytes);
				echoStream.flush();
			} catch (IOException e) {
			}
		}
		if (fileOutputStream == null) {
			return;
		}
		try {
			fileOutputStream.write(bytes);
		} catch (Throwable e) {
			logger.log(Level.WARNING, "Write failed (file=" + file + ")", e);
		}
	}

	@Override
	public void close() {
		if (fileOutputStream == null) {
			return;
		}
		try {
			fileOutputStream.flush();
			fileOutputStream.close();
		} catch (Throwable e) {
			logger.log(Level.WARNING, "Close failed (file=" + file + ")", e);
		}
	}

}
