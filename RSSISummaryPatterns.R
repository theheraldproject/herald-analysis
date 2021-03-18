# Apache 2.0 licensed
# 
# Copyright (c) 2021 Herald Project Contributors
# 

# Author Adam Fowler adamf@vmware.com adam@adamfowler.org

library(plyr)
library(dplyr)
library(readr)
library(ggplot2)
library(ggpubr)
library(chron)
library(parsedate)
library(scales)
library(caTools)

# EDITABLE SETTINGS BEING
folder <- "/Volumes/TB3-1/git/skunkworks/herald-analysis/reference-data/rssi-raw-edison/output"
recordName <- "26-phoneb-summary-filtered"
summaryFile <- paste(folder,"/",recordName,".csv",sep="")
intercept <- -50
coefficient <- -11
# EDITABLE SETTINGS END

# Load summary CSV file
summary <- read.table(summaryFile,sep=",",header=TRUE, stringsAsFactors=FALSE)

# LATER Create one series with mean RSSI - projected regression formula
# Create another with modal RSSI - projected regression formula
summary$modediff <- summary$grp.mode - (intercept + (coefficient * summary$distlog10))
summary$distsquared <- summary$distnumeric * summary$distnumeric

# Plot on a chart of log distance
rplot <- ggplot(summary, aes(x=distsquared, y=modediff, color=3)) +
  geom_point() +
  geom_errorbar(aes(ymin=modediff-sqrt(grp.var), ymax=modediff+sqrt(grp.var)), 
                width=.05, position=position_dodge(.9)) +
  stat_cor(label.x = -0.4, label.y = 14) + 
  stat_regline_equation(label.x = -0.4, label.y = 12) +
  geom_smooth(method=lm) +
  labs(x="Distance squared (meters)", y="Difference from mode to log distance regression line", 
       title="Regression for difference from expected values at distance squared (m)",
       subtitle="Errors bars show 1 standard deviation from mode") + 
  theme(legend.position = "none")
#rplot
ggsave(paste(folder,"/",recordName,"-modediff.png", sep=""))
