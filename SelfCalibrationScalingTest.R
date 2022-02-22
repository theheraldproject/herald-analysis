# Apache 2.0 licensed
# 
# Copyright (c) 2021 Herald Project Contributors
# 

# Author Adam Fowler <adam@adamfowler.org>

# This is purely a test file with calibration primitives

library(ggplot2)
library(parsedate)
library(stringr)
library(moments) # For skewness calculation
library(zoo) # rolling mean
library(lubridate) # working with time durations
library(fitdistrplus) # gamma distribution fitting


data <- c(10,20,25,30,40,50,60,70,80,90)
#logdata = 10^data
#logdata

# Map 25 to 20, 50 to 127
diff = (127 - 20) / (50 - 25)
translated <- data - 25
scaled <- translated * diff
online <- scaled + 20
online

# TODO move anything < 0 to 0, and > 255 to 255