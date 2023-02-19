//  Copyright 2022-2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

package io.heraldprox.analysis.anomalies;

import java.util.List;
import java.util.ArrayList;
import java.io.File;

public class TestFolder {
    File folder;
    List<DeviceFolder> folders = new ArrayList<DeviceFolder>();

    public TestFolder(File folder) {
        this.folder = folder;

        initFolders();
    }

    public boolean exists() {
        return folder.exists() && folder.isDirectory();
    }

    protected void initFolders() {
        File[] files = folder.listFiles();
        if (null == files) {
            return;
        }
        for (int i = 0;i < files.length;++i) {
            if (files[i].isDirectory()) {
                folders.add(new DeviceFolder(files[i]));
            }
        }
    }

    public List<DeviceFolder> getDeviceFolders() {
        return folders;
    }

    public DeviceFolder deviceFolderByFolderName(String folderName) {
        for (DeviceFolder df : folders) {
            if (df.getFolder().getName().equals(folderName)) {
                return df;
            }
        }
        return null;
    }
}
