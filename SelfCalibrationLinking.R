# Apache 2.0 licensed
# 
# Copyright (c) 2021 Herald Project Contributors
# 

# Author Adam Fowler <adam@adamfowler.org>

# This file links two datasets together based on two known Herald contacts
# This was created due to one of a pair of test phones resetting their date.
# This may be generally useful to align data from two known pairs of phones
# whose internal clocks are not synced

# Note: Only the Android demo app shows all nearby phones, not just Herald
#       enabled phones, and so please use Android phones for self calibration
#       analysis.

library(ggplot2)
library(parsedate)
library(stringr)
library(moments) # For skewness calculation
library(zoo) # rolling mean
library(lubridate) # working with time durations
library(fitdistrplus) # gamma distribution fitting

# 1. Set the folder that contains a sub folder per phone in the test
#basedir <- "D:\\git\\skunkworks\\test-data\\2021-12-28-roaming"
#phonedir <- "Pixel3XL"
basedir <- "D:\\git\\skunkworks\\test-data\\2022-01-09-partner-data"
phonedirA <- "S10Lite"
phonedirB <- "A40"
#basedir <- "d:\\git\\skunkworks/test-data/2021-11-16-garage"
#phonedir <- "A-S10lite"
#basedir <- "./sample-output/2020-08-11-cx-47"
#phonedir <- "Pixel3XL"

heraldIdA <- "Co2S+A"
heraldIdB <- "c5Y1zQ"

# Filter data stored by the dates of interest (if phone is not cleared between tests)
#A40Nov
#filtertimemin <- as.POSIXct(paste("2021-11-13", "00:00:01"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-11-15", "23:59:59"), format="%Y-%m-%d %H:%M:%S")
#A4012-17Dec

filtertimeminA <- as.POSIXct(paste("2021-12-12", "00:00:01"), format="%Y-%m-%d %H:%M:%S")
filtertimemaxA <- as.POSIXct(paste("2021-12-17", "23:59:59"), format="%Y-%m-%d %H:%M:%S")
filtertimeminB <- as.POSIXct(paste("2020-05-12", "00:00:01"), format="%Y-%m-%d %H:%M:%S")
filtertimemaxB <- as.POSIXct(paste("2020-06-01", "23:59:59"), format="%Y-%m-%d %H:%M:%S")

#filtertimemin <- as.POSIXct(paste("2021-11-16", "12:30:00"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-11-16", "18:45:00"), format="%Y-%m-%d %H:%M:%S")

# Runtime settings
heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%S" # PRE v2.1.0-beta3 - integer seconds
#heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%OS3%z" # v2.1.0-beta3 onwards - 3 decimal places of seconds with timezone as E.g. -0800
rssiCharts <- TRUE # Output RSSI chart images
dotxpower <- TRUE # Provide TXPower analyses
# DO NOT EDIT BEYOND THIS LINE

thisdirA <- paste(basedir,phonedirA,sep="/")
## load csv file
csvdataA <- tryCatch({
  tp <- read.table(paste(thisdirA , "/contacts.csv",sep=""), sep=",",header = TRUE)
  # names: time,sensor,id,detect,read,measure,share,visit,data
  
  tp
}, error = function(err) {
  #  # error handler picks up where error was generated 
  print(paste("Read.table didn't work for contacts!:  ",err))
})

thisdirB <- paste(basedir,phonedirB,sep="/")
## load csv file
csvdataB <- tryCatch({
  tp <- read.table(paste(thisdirB , "/contacts.csv",sep=""), sep=",",header = TRUE)
  # names: time,sensor,id,detect,read,measure,share,visit,data
  
  tp
}, error = function(err) {
  #  # error handler picks up where error was generated 
  print(paste("Read.table didn't work for contacts!:  ",err))
})

# Join data
csvdataA$phone <- phonedirA
head(csvdataA)
csvdataA <- dplyr::filter(csvdataA,data == heraldIdB)
csvdataA$t <- as.POSIXct(csvdataA$time, format=heraldCsvDateFormat)
csvdataA <- dplyr::filter(csvdataA,t>=filtertimeminA)
csvdataA <- dplyr::filter(csvdataA,t<=filtertimemaxA)
head(csvdataA)

csvdataB$t <- as.POSIXct(csvdataB$time, format=heraldCsvDateFormat)
csvdataB <- dplyr::filter(csvdataB,t>=filtertimeminB)
csvdataB <- dplyr::filter(csvdataB,t<=filtertimemaxB)
csvdataBOrig <- csvdataB
csvdataB$phone <- phonedirB
head(csvdataB)
csvdataB <- dplyr::filter(csvdataB,data == heraldIdA)
head(csvdataB)

# Align - assume first reading is mutual
firstTimeA <- min(csvdataA$t)
firstTimeB <- min(csvdataB$t)
# get difference
timeDiff <- firstTimeA - firstTimeB
timeDiff
csvdataB$t <- csvdataB$t + timeDiff
unclass(timeDiff)

# Join
csvdata <- rbind(csvdataA,csvdataB)
head(csvdata)

# We only care about measures (and their RSSI and TxPower values)
# i.e. the didMeasure calls (for ALL nearby devices, prefiltering)
#measures <- dplyr::filter(csvdata,measure==3)
#head(measures)
measures <- dplyr::select(csvdata,c("t","phone","id","data"))
#measures <- dplyr::distinct(measures) # DO NOT DO THIS - reduces RSSI data
names(measures) <- c("t","phone","macuuid","data")
head(measures)

# Collect macuuids for devices with Herald payloads
#heraldcontacts <- dplyr::filter(csvdata,read==2)
#measures <- dplyr::filter(measures, macuuid %in% heraldcontacts$id)

# Now we have only herald contacts, plot number of readings over time by hour n a histogram for each phone
measures$min <- cut(measures$t,breaks = "1 hour")
summary <- measures  %>%
  dplyr::group_by(min,phone) %>%
  dplyr::summarise(cnt=dplyr::n())
head(measures)
head(summary)

p <- ggplot(summary, aes(x=min, y=cnt,color=phone, fill=phone)) +
  geom_point(alpha=0.5, show.legend = T) +
  labs(x="Time",
       y="Reading count",
       title="Phone mutual proximity over time")  + 
  theme(legend.position = "bottom")
ggsave(paste(basedir,"/phone-association.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")

# Now output corrected times for phoneB (A40)
csvdataBCorrected <- csvdataBOrig
csvdataBCorrected$t <- csvdataBCorrected$t + timeDiff
csvdataBCorrected$time <- format(csvdataBCorrected$t, format = heraldCsvDateFormat)
csvdataBCorrected <- dplyr::select(csvdataBCorrected, c("time","sensor","id","detect","read","measure","share","visit","data"))
head(csvdataBCorrected)
write.csv(csvdataBCorrected,paste(basedir , "/", phonedirB,"/contacts_corrected.csv",sep=""), row.names = FALSE, quote=FALSE, na = "")
