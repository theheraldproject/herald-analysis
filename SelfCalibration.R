# Apache 2.0 licensed
# 
# Copyright (c) 2021 Herald Project Contributors
# 

# Author Adam Fowler <adam@adamfowler.org>

# This file analyses the raw RSSI data in the contacts.csv file on the demo
# app in order to see how viable self calibration of each phone is over time.

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
library(slider) # sliding time window
library(scales) # date format in charts

# 1. Set the folder that contains a sub folder per phone in the test
#basedir <- "D:\\git\\skunkworks\\test-data\\2021-12-28-roaming"
#phonedir <- "Pixel3XL"
basedir <- "D:\\git\\skunkworks\\test-data\\2022-01-09-partner-data"
#phonedir <- "S10Lite"
phonedir <- "A40"
#basedir <- "d:\\git\\skunkworks/test-data/2021-11-16-garage"
#phonedir <- "A-S10lite"
#basedir <- "./sample-output/2020-08-11-cx-47"
#phonedir <- "Pixel3XL"

# Filter data stored by the dates of interest (if phone is not cleared between tests)
#A40Nov
#filtertimemin <- as.POSIXct(paste("2021-11-13", "00:00:01"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-11-15", "23:59:59"), format="%Y-%m-%d %H:%M:%S")
#A4012-17Dec

#filtertimemin <- as.POSIXct(paste("2021-12-12", "00:00:01"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-12-17", "23:59:59"), format="%Y-%m-%d %H:%M:%S")
#filtertimemin <- as.POSIXct(paste("2020-05-12", "00:00:01"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2020-05-17", "23:59:59"), format="%Y-%m-%d %H:%M:%S")
# Joint overlap
filtertimemin <- as.POSIXct(paste("2021-12-13", "00:09:00"), format="%Y-%m-%d %H:%M:%S")
filtertimemax <- as.POSIXct(paste("2021-12-16", "00:09:30"), format="%Y-%m-%d %H:%M:%S")


#filtertimemin <- as.POSIXct(paste("2021-11-16", "12:30:00"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-11-16", "18:45:00"), format="%Y-%m-%d %H:%M:%S")

# Runtime settings
heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%S" # PRE v2.1.0-beta3 - integer seconds
#heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%OS3%z" # v2.1.0-beta3 onwards - 3 decimal places of seconds with timezone as E.g. -0800
rssiCharts <- FALSE # Output RSSI chart images
dotxpower <- FALSE # Provide TXPower analyses
ignoreHeraldDevices <- TRUE

chartWidth <- 400
chartHeight <- 300

# DO NOT EDIT BEYOND THIS LINE
thisdir <- paste(basedir,phonedir,sep="/")











getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

initialDataPrepAndFilter <- function(dataFrame) {
  # We only care about measures (and their RSSI and TxPower values)
  # i.e. the didMeasure calls (for ALL nearby devices, prefiltering)
  measures <- dplyr::filter(dataFrame,measure==3)
  #head(measures)
  measures <- dplyr::select(measures,c("time","id","data"))
  ##measures <- dplyr::distinct(measures) # DO NOT DO THIS - reduces RSSI data
  names(measures) <- c("time","macuuid","data")
  #head(measures)
  
  if (ignoreHeraldDevices) {
    # Collect macuuids for devices with Herald payloads
    # We will use our two known contacts to test the final risk score algorithm
    heraldcontacts <- dplyr::filter(dataFrame,read==2)
    measures <- dplyr::filter(measures, !(macuuid %in% heraldcontacts$id) )
  }
  
  # Filter by time
  measures$t <- as.POSIXct(measures$time, format=heraldCsvDateFormat)
  measures <- dplyr::filter(measures,t>=filtertimemin)
  measures <- dplyr::filter(measures,t<=filtertimemax)
  #head(measures)
  
  # Now extract RSSI and txPower (if present)
  # Example $data value: RSSI:-97.0[BLETransmitPower:8.0]
  rssiAndTxPowerPattern <- "RSSI:(-[0-9]+\\.0)(.BLETransmitPower:([0-9.]+).)?"
  matches <- str_match(measures$data,rssiAndTxPowerPattern)
  #head(matches)
  measures$rssi <- str_match(measures$data,rssiAndTxPowerPattern)[,2]
  measures$txpower <- str_match(measures$data,rssiAndTxPowerPattern)[,4]
  #head(measures)
  
  # Filter out those without RSSI
  measures <- dplyr::filter(measures,!is.na(rssi))
  measures$rssiint <- as.numeric(measures$rssi)
  #head(measures)
  measures
}



## IMPORTANT filter nonsense RSSI readings before proceeding
# Contrary to popular believe, RSSI is NOT -127->128 on phones
# It's only valid -1 to -98
# -99 Is used by some bluetooth chip manufacturers to indicate "valid packet but extreme range"
# -100 to -106 are used as error flags for some manufacturers
# Removes error values. Does not attempt to remove any data based on situation/calibration
filterRawData <- function(dataFrame) {
  dplyr::filter(dataFrame,rssiint > -99 & rssiint < 0)
}

calcCEStats <- function(dataFrame) {
  #cestats <- dataFrame %>%
  #  dplyr::group_by(macuuid) %>%
  #  dplyr::summarise(n=dplyr::n(), mint=min(t), maxt=max(t), difft=maxt-mint, sdrssi=sd(rssiint), meanrssi=mean(rssiint), moderssi=getmode(rssiint), minrssi=min(rssiint), maxrssi=max(rssiint), rangerssi=max(rssiint)-min(rssiint)) %>%
  #  dplyr::arrange(dplyr::desc(n))
  #cestats$durmin <- as.numeric(as.POSIXct(cestats$difft)$seconds) / 60 #assume seconds conversion
  #head(cestats)
  
  cestats <- dataFrame %>%
    dplyr::group_by(macuuid) %>%
    dplyr::summarise(n=dplyr::n(), mint=min(t), maxt=max(t), difft=as.numeric(maxt)-as.numeric(mint), sdrssi=sd(rssiint), meanrssi=mean(rssiint), moderssi=getmode(rssiint), minrssi=min(rssiint), maxrssi=max(rssiint), rangerssi=max(rssiint)-min(rssiint)) %>%
    dplyr::arrange(dplyr::desc(n))
  cestats$durmin <- cestats$difft / 60 # seconds to minutes
  
  cestats
}

chartCEStats <- function(dataFrameCE, groupText) {
  p <- ggplot(dataFrameCE, aes(x=meanrssi,color=1, fill=1)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
    labs(x="Mean RSSI",
         y="Relative Frequency",
         title="Mean RSSI Chart",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-meanrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  p <- ggplot(dataFrameCE, aes(x=moderssi,color=1, fill=1)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
    labs(x="Mode RSSI",
         y="Relative Frequency",
         title="Mode RSSI Chart",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-moderssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  p <- ggplot(dataFrameCE, aes(x=sdrssi,color=1, fill=1)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
    labs(x="SD RSSI",
         y="Relative Frequency",
         title="SD RSSI Chart",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-sdrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  p <- ggplot(dataFrameCE, aes(x=minrssi,color=1, fill=1)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
    labs(x="Minimum RSSI",
         y="Relative Frequency",
         title="Minimum RSSI Chart",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-minrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  p <- ggplot(dataFrameCE, aes(x=maxrssi,color=1, fill=1)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
    labs(x="Maximum RSSI",
         y="Relative Frequency",
         title="Maximum RSSI Chart",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-maxrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  
  
  # Show maxrssi by meanrssi and similar scatter plots
  
  p <- ggplot(dataFrameCE, aes(x=meanrssi, y=maxrssi,color=1, fill=1)) +
    geom_point(alpha=0.5, show.legend = F) +
    labs(x="Mean RSSI",
         y="Max RSSI",
         title="Mean vs Max RSSI",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-meanvsmaxrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  p <- ggplot(dataFrameCE, aes(x=meanrssi, y=minrssi,color=1, fill=1)) +
    geom_point(alpha=0.5, show.legend = F) +
    labs(x="Mean RSSI",
         y="Min RSSI",
         title="Mean vs Min RSSI",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-meanvsminrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  p <- ggplot(dataFrameCE, aes(x=meanrssi, y=rangerssi,color=1, fill=1)) +
    geom_point(alpha=0.5, show.legend = F) +
    labs(x="Mean RSSI",
         y="Range RSSI",
         title="Mean vs Range RSSI",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-meanvsrangerssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  p <- ggplot(dataFrameCE, aes(x=meanrssi, y=sdrssi,color=1, fill=1)) +
    geom_point(alpha=0.5, show.legend = F) +
    labs(x="Mean RSSI",
         y="SD RSSI",
         title="Mean vs SD RSSI",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-meanvssdrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  p <- ggplot(dataFrameCE, aes(x=maxrssi, y=minrssi,color=1, fill=1)) +
    geom_point(alpha=0.5, show.legend = F) +
    labs(x="Max RSSI",
         y="Min RSSI",
         title="Max vs Min RSSI",
         subtitle=paste("Across ",groupText," interactions",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-maxvsminrssi.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  
}


chartCEDuration <- function(dataFrameCE, groupText, durationLimitMins) {
  cestatslim <- dataFrameCE
  cestatslim$durmin[cestatslim$durmin > durationLimitMins] <- durationLimitMins
  p <- ggplot(cestatslim, aes(x=durmin,color=1, fill=1)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
    labs(x="Duration (minutes)",
         y="Relative Frequency",
         title="Contact Event Duration Frequency",
         subtitle=paste("Across all interactions (max of ",durationLimitMins," minutes)",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-duration.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
}

chartCEReadingsCount <- function(dataFrameCE, groupText, readingCountLimit) {
  # Also show a chart of number of readings for each contact event, in the tens of readings
  cestatscntlim <- dataFrameCE
  cestatscntlim$n[cestatscntlim$n > readingCountLimit] <- readingCountLimit
  p <- ggplot(cestatscntlim, aes(x=n,color=1, fill=1)) +
    geom_histogram(alpha=0.5, binwidth=5, show.legend = F, aes( y=..density.. )) +
    labs(x="Readings (count)",
         y="Relative Frequency",
         title="Contact Event Reading Count Frequency",
         subtitle=paste("Across ",groupText," interactions (limited to n=",readingCountLimit,")",sep=""))
  #p
  ggsave(paste(basedir,"/",phonedir,"-ce-",groupText,"-readingcount.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
}


# Corrects for TxPower, which implies filtering raw data for TxPower
#filterAndCorrectForTxPower <- function(dataFrame) {
#  # Filter data for those with TxPower
#  withTx <- dplyr::filter(dataFrame,!is.na(txpower))
#  # Create txpowerint
#  withTx$txpowerint <- as.numeric(withTx$txpower)
#  # Correct data
#  withTx$rssicor <- withTx$rssiint - withTx$txpowerint
#  withTx
#}

# This function corrects for TxPower too, and reverses the order. Centred around txPower per phone (0dBm) rather than overall
txAndReverse <- function(dataFrame) {
  # Filter data for those with TxPower
  withTx <- dplyr::filter(dataFrame,!is.na(txpower))
  # Create txpowerint
  withTx$txpowerint <- as.numeric(withTx$txpower)
  # Correct data
  withTx$rssicor <- withTx$txpowerint - withTx$rssiint
  withTx
}

# TODO function to infer TxPower from each contact event's individual distribution

# Smooth each contact event's rssi value over time
smooth <- function(dataFrame, smoothingWidth) {
  # Order data by ascending time (should be by default)
  # For each macuuid (contact event), smooth over up to given number of readings (smoothingWidth)
  
}
# TODO a version of the above that is sensitive to time between readings
# TODO function that assigns contact event id so that repeated mac addresses from different devices do not interfere with long lived data


# SECTION - Single data column functions


justReverse <- function(dataFrame) {
  mydf <- dataFrame
  maxValue <- max(mydf$rssiint)
  mydf$rssicor <- maxValue - mydf$rssiint + 1.0
  mydf
}

referenceTxAndReverse <- function(dataFrame) {
  mydf <- dataFrame
  mydf$rssicor <- 1.0 - mydf$rssiint
  mydf
}


calibrateGamma <- function(dataFrame,saveChart,saveSummary,parentFolder,filenamePostfix) {
  # Fit to gamma distribution
  # Create calibration summary
  # Save chart (png)
  # save summary (calibration parameters csv)
  # Return calibration summary
}


chartProximity <- function(dataFrame, groupText) {
  
  print(paste("chartProximity for ",groupText,sep=""))
  print(" - Charting prox values")
  # Graph 1a&b - Show RSSI frequencies by macuuid across whole time period
  # Note: As devices rotate mac address, some devices will be the same but 
  #       appear as different mac addresses
  p <- ggplot(dataFrame, aes(x=rssicor, color=macuuid, fill=macuuid)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
    labs(x=paste(groupText," proximity",sep=""),
         y="Count of each proximity value",
         title="Proximity histogram for each phone detected",
         subtitle="Some phones may be duplicates")  + 
    theme(legend.position = "bottom")
  #p
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-proximity-values.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  print(" - Charting prox density")
  p <- ggplot(dataFrame, aes(x=rssicor, y=..density..  , color=macuuid, fill=macuuid)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
    geom_density(alpha=0.3, fill=NA, show.legend = F) +
    labs(x=paste(groupText," proximity",sep=""),
         y="Relative Density",
         title="Proximity histogram for each phone detected",
         subtitle="Some phones may be duplicates")  + 
    theme(legend.position = "bottom")
  #p
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-proximity-density.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  
  
  # Graph 2 - Smoothed line of rssi over time (3 degrees of freedom)
  print(" - Charting prox over time")
  p <- ggplot(dataFrame, aes(x=t,y=rssicor,color=macuuid)) +
    geom_point(show.legend = F) +
    labs(x="Time",
         y=paste(groupText," proximity",sep=""),
         title="Proximity detected over time",
         subtitle="Some phones may be duplicates") +
    scale_x_datetime(date_breaks = "10 min", date_minor_breaks = "2 min")
  #  scale_x_datetime(date_breaks = "60 min", date_minor_breaks = "10 min")
  #  + geom_smooth(method="lm", formula=y ~ poly(x,3), show.legend = F)
  #  geom_smooth(method="loess")
  #p
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-proximity-over-time.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  
  
  
  print(" - Calculating most CE and longest CE")
  
  mostdatacontactevents <- dataFrame %>%
    dplyr::group_by(macuuid) %>%
    dplyr::summarise(n=dplyr::n(), mint=min(t), maxt=max(t), difft=maxt-mint) %>%
    dplyr::arrange(dplyr::desc(n))
  mostdatacontactevents <- dplyr::slice_head(mostdatacontactevents, n=50)
  head(mostdatacontactevents)
  NROW(mostdatacontactevents)
  measuresinrangewithmostdata <- dplyr::filter(dataFrame, macuuid %in% mostdatacontactevents$macuuid)
  head(measuresinrangewithmostdata)
  measuresinrangewithmostdatanomean <- measuresinrangewithmostdata
  
  ## Note: Pre-v2.1.0-beta3 workaround for multiple readings at same integer second point in time (as it skews running mean line otherwise)
  measuresinrangewithmostdata <- measuresinrangewithmostdata %>%
    dplyr::group_by(macuuid,t) %>%
    dplyr::summarise(rssicor=mean(rssicor))
  head(measuresinrangewithmostdata)
  
  
  longestcontactevents <- mostdatacontactevents %>%
    dplyr::arrange(dplyr::desc(difft))
  longestcontactevents <- dplyr::slice_head(longestcontactevents, n=20)
  head(longestcontactevents)
  NROW(longestcontactevents)
  
  measuresinrangewithlongestduration <- dplyr::filter(dataFrame, macuuid %in% longestcontactevents$macuuid)
  head(measuresinrangewithlongestduration)
  
  ## Note: Pre-v2.1.0-beta3 workaround for multiple readings at same integer second point in time (as it skews running mean line otherwise)
  measuresinrangewithlongestduration <- measuresinrangewithlongestduration %>%
    dplyr::group_by(macuuid,t) %>%
    dplyr::summarise(rssicor=mean(rssicor))
  head(measuresinrangewithlongestduration)
  
  
  
  print(" - Charting top50 ce by data quantity")
  p <- ggplot(measuresinrangewithmostdata, aes(x=t,y=rssicor,color=macuuid)) +
    geom_point(show.legend = F) +
    labs(x="Time",
         y=paste(groupText," Proximity",sep=""),
         title="Proximity detected over time",
         subtitle="50 Contact Events with most in range data only") +
    geom_line(aes(y=zoo::rollmean(rssicor, 5, na.pad=TRUE))) +
    scale_x_datetime(date_breaks = "5 min", date_minor_breaks = "1 min")  +
    facet_wrap(~macuuid, ncol=5, nrow=10, scales="free") +
    theme(legend.position = "none")
  #p
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-proximity-over-time-top50.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  print(" - Charting top20 ce by duration")
  p <- ggplot(measuresinrangewithlongestduration, aes(x=t,y=rssicor,color=macuuid)) +
    geom_point(show.legend = F) +
    labs(x="Time",
         y=paste(groupText," Proximity",sep=""),
         title="Proximity detected over time",
         subtitle="20 Contact Events withlongest duration") +
    geom_line(aes(y=zoo::rollmean(rssicor, 5, na.pad=TRUE))) +
    scale_x_datetime(date_breaks = "5 min", date_minor_breaks = "1 min")  +
    facet_wrap(~macuuid, ncol=4, nrow=5, scales="free") +
    theme(legend.position = "none")
  #p
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-proximity-over-time-longest20.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  # Density of ones with most data, above
  
  print(" - Charting density of top50 ce by duration")
  p <- ggplot(measuresinrangewithmostdata, aes(x=rssicor, y=..density..  , color=macuuid, fill=macuuid)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
    geom_density(alpha=0.3, fill=NA, show.legend = F) +
    labs(x=paste(groupText," Proximity",sep=""),
         y="Relative Density",
         title="Proximity histogram for each phone detected",
         subtitle="Top 50 events with most data")  + 
    facet_wrap(~macuuid, ncol=5, nrow=10, scales="free") +
    theme(legend.position = "bottom")
  #p
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-proximity-density-top50.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  
  
  
  
  
}



















## load csv file
csvdatafull <- FALSE
csvdata <- tryCatch({
  tp <- read.table(paste(thisdir , "/contacts.csv",sep=""), sep=",",header = TRUE)
  # names: time,sensor,id,detect,read,measure,share,visit,data
  
  cvsdatafull <- TRUE
  tp
}, error = function(err) {
  #  # error handler picks up where error was generated 
  print(paste("Read.table didn't work for contacts!:  ",err))
})
head(csvdata)


measures <- initialDataPrepAndFilter(csvdata);




# PART A
# Analyse RSSI values

# Filter invalid RSSIs (Same as we do in the Herald analysis API)
#measures <- dplyr::filter(measures,rssiint>-99)
measuresinrange <- measures # So we have all the data still, not just that used for self calibration



# CALIBRATION FILTERING
# Now filter by mean rssi < cut off
#validmacs <- measures %>%
#  dplyr::group_by(macuuid) %>%
#  dplyr::summarise(mean=mean(rssiint), sd=sd(rssiint), min=min(rssiint), max=max(rssiint), n=dplyr::n())
#cepre <- NROW(validmacs)

# Save summary for introspection
#prefilterrssisummary <- validmacs %>%
#  dplyr::group_by(mean) %>%
#  dplyr::summarise(cnt=dplyr::n())
#p <- ggplot(prefilterrssisummary, aes(x=mean, color=cnt, fill=cnt)) +
#  geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
#  labs(x="Mean RSSI",
#       y="Number of encounters with this mean",
#       title="Mean RSSI histogram by frequency")  + 
#  theme(legend.position = "bottom")
#p
#ggsave(paste(basedir,"/",phonedir,"-rssi-mean-freq-prefilter.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")



# Then filter by min number
#validmacs <-  dplyr::filter(validmacs,mean > -85) # & n > 15)
#head(validmacs)

#cepost <- NROW(validmacs)

#postfilterrssisummary <- validmacs %>%
#  dplyr::group_by(mean) %>%
#  dplyr::summarise(cnt=dplyr::n())
#p <- ggplot(postfilterrssisummary, aes(x=mean, color=cnt, fill=cnt)) +
#  geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
#  labs(x="Mean RSSI",
#       y="Number of encounters with this mean",
#       title="Mean RSSI histogram by frequency")  + 
#  theme(legend.position = "bottom")
#p
#ggsave(paste(basedir,"/",phonedir,"-rssi-mean-freq-postfilter.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")





#measures <- dplyr::filter(measures,macuuid %in% validmacs$macuuid)





# TODO SHOW ONLY THOSE WHERE THE CONTACT EVENTS ARE LESS THAN 20 MINUTES (I.e. devices with Bluetooth Privacy enabled) - FILTER ALL FOR THIS


cestats <- calcCEStats(measuresinrange)
chartCEStats(cestats,"prefiltered")



# Check validity of duration calculations by looking at their distribution
# write chart of frequency of durations in minutes
# Limit max duration in graph to 60 mins


chartCEDuration(cestats,"prefiltered",60)
chartCEReadingsCount(cestats,"prefiltered",350)

cestatscntenough <- dplyr::filter(cestats, n > 35)

# count lower and higher than 25 mins
celong <- dplyr::filter(cestats, durmin >= 60)
cemiddle <- dplyr::filter(cestats, durmin >= 26 & durmin < 60)
ceshort <- dplyr::filter(cestats, durmin < 26)
NROW(celong)
NROW(cemiddle)
NROW(ceshort)

# Filter remaining data by those likely as phones (with BL E Privacy enabled)
NROW(measuresinrange)
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% ceshort$macuuid)
NROW(measuresinrange)
# Filter out contact events with less than 35 readings
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% cestatscntenough$macuuid)
NROW(measuresinrange)
# Filter for maxrssi
cestatsmaxrssi <- cestats
cestatsmaxrssi <- dplyr::filter(cestatsmaxrssi, maxrssi > -90)
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% cestatsmaxrssi$macuuid)
NROW(measuresinrange)
# Filter for meanrssi
cestatsmeanrssi <- cestats
cestatsmeanrssi <- dplyr::filter(cestatsmeanrssi, meanrssi > -80)
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% cestatsmeanrssi$macuuid)
NROW(measuresinrange)
# Filter for rangerssi > 5
cestatsrangerssi <- cestats
cestatsrangerssi <- dplyr::filter(cestatsrangerssi, rangerssi > 5)
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% cestatsrangerssi$macuuid)
NROW(measuresinrange)
# filter out long contact events (as they're likely to be non-rotating BLE devices)
measuresinrange <- dplyr::filter(measuresinrange, macuuid %in% ceshort$macuuid)
NROW(measuresinrange)


# To confirm filtering at this point, view the effect on aggregate information
cestatsfiltered <- calcCEStats(measuresinrange)

chartCEStats(cestatsfiltered,"filtered")

chartCEDuration(cestatsfiltered,"filtered",60)
chartCEReadingsCount(cestatsfiltered,"filtered",350)


# TODO also check distributions of 0700-1900 and 1900-0700 (i.e. remove overnight data)
# TODO also check affects of filtering that may skew result - E.g. look at duration pre and post filtering around 13-15 minutes, also look at txpower is na vs not





# Copy back (so I don't have to search and replace...)
measures <- measuresinrange

# TEMPORARILY restrict self calibration to txpower=="7.0" to see its effect
#measures <- dplyr::filter(measures,txpower=="7.0")



# Limit columns to only those of interest (performance tweak)
measures <- dplyr::select(measures,c("t","macuuid","rssiint","txpower"))
names(measures) <- c("t","macuuid","rssiint","txpower")
head(measures)





measures <- filterRawData(measures)



# PART B
# Now analyse txpower
if (dotxpower) {
  
  # Get percentage of contacts with TXPower %>%
  powercontactevents <- measuresinrange %>%
    dplyr::group_by(macuuid) %>%
    dplyr::summarise(hastxpower=any(!is.na(txpower)))
  totalces <- NROW(powercontactevents)
  head(powercontactevents)
  head(measuresinrange)
  totalces
  powercecounts <- powercontactevents %>%
    dplyr::group_by(hastxpower) %>%
    dplyr::summarise(n=dplyr::n())
  powercecounts
  write.csv(powercecounts,paste(basedir , "/", phonedir,"-txpower-ce-prevalence.csv",sep=""))
  
  
  # Stats B1 - Calculate mean & sd of RSSI for each txpowerint value
  txsummary <- withtxpower %>%
    dplyr::group_by(txpowerint) %>%
    dplyr::summarise(mean=mean(rssiint), sd=sd(rssiint), min=min(rssiint), max=max(rssiint), n=dplyr::n())
  head(txsummary)
  write.csv(txsummary,paste(basedir , "/", phonedir,"-txpower-distribution-values.csv",sep=""))
  
  # Stats B2, do the same but summarise by contact event and not advertisementmeasuresinrange %>%
  txcewith <- txcewithhastx %>%
    dplyr::group_by(macuuid,txpower) %>%
    dplyr::summarise(n=dplyr::n())
  txcewith
  txcewithtx <- txcewithhastx %>%
    dplyr::group_by(txpower) %>%
    dplyr::summarise(mean=mean(rssiint), sd=sd(rssiint), min=min(rssiint), max=max(rssiint), n=dplyr::n())
  head(txcewithtx)
  write.csv(txcewithtx,paste(basedir , "/", phonedir,"-txpower-distribution-by-contactevent.csv",sep=""))
  txcevaries <- txcewith %>%
    dplyr::group_by(macuuid,txpower) %>%
    dplyr::summarise(n=dplyr::n())
  txcevaries <- dplyr::filter(txcevaries,n > 1)
  txcevaries
  
  # TODO add 'correction' logic for txPower of the remote (partial, ideally need both sides)
  
  
} # end if dotxpower







#head(withtxpower)
#withtxpower$txpowerint <- as.numeric(withtxpower$txpower)
## Limit columns to only those of interest (performance tweak)
#withtxpower <- dplyr::select(withtxpower,c("t","macuuid","rssiint","txpowerint"))
#names(withtxpower) <- c("t","macuuid","rssiint","txpowerint")
#head(withtxpower)


# Hypothesis 1, Null point 1 - Each contact event RSSI is normally distributed
# Method: Find 12 contact events with highest number of rssi readings, and chart their RSSI over time, and rssi distribution

printSummary <- function(dataFrame, groupText) {
  ce <- dataFrame %>%
    dplyr::group_by(macuuid) %>%
    dplyr::summarise(mean=mean(rssicor), sd=sd(rssicor), min=min(rssicor), max=max(rssicor), range=max-min, n=dplyr::n())
  totalces <- NROW(ce)
  meanRange <- mean(ce$range)
  sdRange <- sd(ce$range)
    
  # Print number of readings total
  print(
    paste("Summary of ",groupText,
          ": Readings=",NROW(dataFrame$rssicor),
          ", Contact Events=",totalces,
          ", Mean range=",meanRange,
          ", SD range=",sdRange,
    sep=""
    )
  )
}

filterForCERange <- function(dataFrame, minRange) {
  ce <- dataFrame %>%
    dplyr::group_by(macuuid) %>%
    dplyr::summarise(mean=mean(rssicor), sd=sd(rssicor), min=min(rssicor), max=max(rssicor), range=max-min, n=dplyr::n())
  ce <- dplyr::filter(ce, range >= minRange)
  filtered <- dplyr::filter(dataFrame, macuuid %in% ce$macuuid)
}




chartAndFit <- function(dataFrame, groupText) {
  print(paste("chartAndFit - ",groupText,sep=""))
  
  #meanrssitx <- mean(dataFrame$rssiint)
  #sdrssitx <- sd(dataFrame$rssiint)
  #countrssitx <- NROW(dataFrame)
  #minrssitx <- min(dataFrame$rssiint)
  #maxrssitx <- max(dataFrame$rssiint)
  #skewrssitx <- moments::skewness(dataFrame$rssiint, na.rm = TRUE)
  #kurtosisrssitx <- moments::kurtosis(dataFrame$rssiint, na.rm = TRUE)
  
  
  
  meanrssitxcor <- mean(dataFrame$rssicor)
  sdrssitxcor <- sd(dataFrame$rssicor)
  countrssitxcor <- NROW(dataFrame)
  minrssitxcor <- min(dataFrame$rssicor)
  maxrssitxcor <- max(dataFrame$rssicor)
  skewrssitxcor <- moments::skewness(dataFrame$rssicor, na.rm = TRUE)
  kurtosisrssitxcor <- moments::kurtosis(dataFrame$rssicor, na.rm = TRUE)
  
  
  
  
  
  
  # NOW CREATE NORMALISED (scaled) DATASET
  # Now alter rssi values to the idealised normal distribution
  # NOTE: Not actually to a N(0,1) as yet - not got the scale factors right...
  # Calculate fitness
  scaledtxcor <- dataFrame
  # Filter beyond the two peaks
  #scaledtxcor <- dplyr::filter(scaledtxcor, rssicor >= lowerpeaktxcor & rssicor <= upperpeaktxcor)
  #scaledtxcor$rssicorrected <- 0
  #scaledtxcor$rssicorrected[scaledtxcor$rssicor < meanrssitxcor] <- (scaledtxcor$rssicor[scaledtxcor$rssicor < meanrssitxcor] - meanrssitxcor) / abs(lowersdpostxcor)
  #scaledtxcor$rssicorrected[scaledtxcor$rssicor > meanrssitxcor] <- (scaledtxcor$rssicor[scaledtxcor$rssicor > meanrssitxcor] - meanrssitxcor) / abs(uppersdpostxcor)
  head(scaledtxcor)
  meancortxcor <- mean(scaledtxcor$rssicor)
  sdcortxcor <- sd(scaledtxcor$rssicor)
  skewcortxcor <- moments::skewness(scaledtxcor$rssicor, na.rm = TRUE)
  kurtosiscortxcor <- moments::kurtosis(scaledtxcor$rssicor, na.rm = TRUE)
  
  
  print(" - Calculating scaled fit")
  
  myfit <- fitdist(scaledtxcor$rssicor, distr = "gamma", method = "mle")
  summary(myfit)
  gammashape <- myfit$estimate[1] # shape
  gammarate <- myfit$estimate[2] # rate
  
  myfitnorm <- fitdist(scaledtxcor$rssicor, distr = "norm", method = "mle")
  summary(myfitnorm)
  
  myfitnorm$sd[2]
  
  
  
  # Filter those so we're left with those between 2 and 3 SD only
  dataExtremeties <- dataFrame %>%
    dplyr::filter(
      (rssicor >= (meanrssitxcor - (3 * sdrssitxcor)) & rssicor < (meanrssitxcor - (2 * sdrssitxcor)) )
      |
        (rssicor <= (meanrssitxcor + (3 * sdrssitxcor)) & rssicor > (meanrssitxcor + (2 * sdrssitxcor)) )
    )
  
  
  # - Second, for each RSSI, find local proportion above the curve (local maxima) beyond 1 SD
  rssicountstxcor <- dataExtremeties %>%
    dplyr::group_by(rssicor) %>%
    dplyr::summarise(cnt=dplyr::n())
  rssicountstxcor$probrssi <- countrssitxcor * 
    (pnorm(rssicountstxcor$rssicor - 0.5, mean = meanrssitxcor, sd = sdrssitxcor, lower.tail=FALSE) - 
       pnorm(rssicountstxcor$rssicor + 0.5, mean = meanrssitxcor, sd = sdrssitxcor, lower.tail=FALSE) 
    )
  #  rssicountstxcor$probrssi <- countrssitxcor * 
  #    (pgamma(rssicountstxcor$rssicor - 0.5, shape = gammashape, rate = gammarate, lower.tail=FALSE) - 
  #       pgamma(rssicountstxcor$rssicor + 0.5, shape = gammashape, rate = gammarate, lower.tail=FALSE) 
  #    )
  rssicountstxcor$abovecurve <- rssicountstxcor$cnt - rssicountstxcor$probrssi
  head(rssicountstxcor)
  #rssicountstxcor <- dplyr::filter(rssicountstxcor, abovecurve > 0) # ignore so we still get the nearest to norm/gamma curve too
  rssicountstxcor$abovefrac <- rssicountstxcor$abovecurve / rssicountstxcor$cnt # Larger is better (more above the curve)
  rssicountstxcor$lowerarea <- rssicountstxcor$rssicor > meanrssitxcor
  head(rssicountstxcor)
  
  rssicountssummarytxcor <- rssicountstxcor %>%
    dplyr::group_by(lowerarea) %>%
    dplyr::slice(which.max(abovefrac))
  head(rssicountssummarytxcor)
  rssicountssummarytxcor$sdpos <- (rssicountssummarytxcor$rssicor - meanrssitxcor) / sdrssitxcor
  write.csv(rssicountssummarytxcor,paste(basedir , "/", phonedir,"-",groupText,"-rssi-peaks.csv",sep=""))
  lowerpeaktxcor <- as.integer(rssicountssummarytxcor[2:2,"sdpos"]) # WARNING ASSUMES A SINGLE PEAK
  lowerpeaktxcor
  upperpeaktxcor <- as.integer(rssicountssummarytxcor[1:1,"sdpos"]) # WARNING ASSUMES A SINGLE PEAK
  upperpeaktxcor
  #print(paste("Lower peak RSSI:",lowerpeak,"Upper Peak RSSI:", upperpeak)," ")
  # Calculate peak positions relative to mean by number of RSSI SD positions
  #lowersdpostxcor <- (lowerpeaktxcor - meanrssitxcor) / sdrssitxcor
  #uppersdpostxcor <- (upperpeaktxcor - meanrssitxcor) / sdrssitxcor
  #lowersdpostxcor <- meanrssitxcor + (lowerpeaktxcor * sdrssitxcor)
  #uppersdpostxcor <- meanrssitxcor + (upperpeaktxcor * sdrssitxcor)
  lowersdpostxcor <- as.integer(rssicountssummarytxcor[2:2,"rssicor"])
  uppersdpostxcor <- as.integer(rssicountssummarytxcor[1:1,"rssicor"])
  lowersdpostxcor
  uppersdpostxcor
  
  
  # if lower (farthest) point missing, use +3 * SD
  # if upper (nearest) point missing, use -3 * SD
  #if (lowersdpostxcor == meanrssitxcor) {
  #  lowersdpostxcor <- meanrssitxcor + (3 * sdrssitxcor)
  #}
  #if (uppersdpostxcor == meanrssitxcor) {
  #  uppersdpostxcor <- meanrssitxcor - (3 * sdrssitxcor)
  #}
  
  
  
  
  
  # Now plot the same but after txpower correction of rssi
  print(paste(" - Stats: mean=",meanrssitxcor," sd=",sdrssitxcor," n=",countrssitxcor, sep=""))
  p <- ggplot(dataFrame, aes(x=rssicor,color=1, fill=1)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor), color="blue", linetype="dashed", size=1, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=maxrssitxcor), color="black", linetype="solid", size=0.5, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=minrssitxcor), color="black", linetype="solid", size=0.5, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor + sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor - sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor + 2*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor - 2*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor + 3*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor - 3*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=lowersdpostxcor), color="blue", linetype="dashed", size=1, show.legend = F) +
    geom_vline(data=dataFrame, aes(xintercept=uppersdpostxcor), color="blue", linetype="dashed", size=1, show.legend = F) +
    geom_text(aes(x=lowersdpostxcor, label=paste("Lower peak = ",lowersdpostxcor,sep=""), y=0.04), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
    geom_text(aes(x=uppersdpostxcor, label=paste("Upper peak = ",uppersdpostxcor,sep=""), y=0.04), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
    geom_text(aes(x=meanrssitxcor, label=paste("N = ",countrssitxcor,"\nMean = ",meanrssitxcor,"\nSD = ",sdrssitxcor,"\nSkewness = ",skewrssitxcor,"\nKurtosis = ",kurtosisrssitxcor,sep=""), y=0.04), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
    labs(x="RSSI corrected for TxPower",
         y="Relative Frequency",
         title="Corrected RSSI Frequency",
         subtitle="Across all interactions") + 
    stat_function(fun = dnorm, args = list(mean = meanrssitxcor, sd = sdrssitxcor), show.legend = F)
  p
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-fitting-01-input-distribution.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  
  
  
  print(" - Calculating bounds for scaling")
  
  # A2 Try to normalise these values - by using the mean and local maxima peaks based on human behaviour
  # - First, Filter for only those rssiint between -3 (or -97) and -1 SD and 1 and 3 SD (or minrssi if smaller)
  weakmintxcor <- max(meanrssitxcor - (3 * sdrssitxcor), -120)# -98 is the boundary value for bluetooth chips to receive data, so ignore
  weakmaxtxcor <- meanrssitxcor - (2 * sdrssitxcor)
  strongmintxcor <- meanrssitxcor + (2 * sdrssitxcor)
  strongmaxtxcor <- min(meanrssitxcor + (3 * sdrssitxcor), maxrssitxcor, 0)
  sdmeasurestxcor <- dplyr::filter(dataFrame, (rssicor > weakmintxcor & rssicor <= weakmaxtxcor) | (rssicor >= strongmintxcor & rssicor <= strongmaxtxcor))
  # Chart these as a debug step
  
  p <- ggplot(sdmeasurestxcor, aes(x=rssicor)) +
    geom_histogram(alpha=0.5, binwidth=1, show.legend=F, aes( y=..density.. )) +
    labs(x="RSSI In Range",
         y="Number of values",
         title="RSSIs in range of local maxima")  + 
    theme(legend.position = "bottom") + 
    stat_function(fun = dnorm, args = list(mean = meanrssitxcor, sd = sdrssitxcor), show.legend = F)
  p
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-fitting-02-maxima-areas.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  
  
  
  
  
  
  
  print(" - Calculating scaling summaries")
  
  
  
  
  
  
  
  # Now chart it
  
  xlimmin <- maxrssitxcor
  if (xlimmin < 255) {
    xlimmin <- 255
  }
  xlimmax <- minrssitxcor
  if (xlimmax > 0) {
    xlimmax <- 0
  }
  
  print(" - Charting scaled fit")
  # Now reversed and fitted to gamma and normal(gaussian) distributions
  p <- ggplot(scaledtxcor, aes(x=rssicor,color=1, fill=1)) +
    geom_histogram(alpha=0.5, binwidth=10, show.legend = F, aes( y=..density.. )) +
    geom_text(aes(x=meanrssitxcor - 2*sdrssitxcor, label=paste(
      "Gamma:-\nShape = ",myfit$estimate[1]," (SE = ",myfit$sd[1],")\nRate = ",myfit$estimate[2]," (SE = ",myfit$sd[2],")",
      "\nNorm:-\nMean = ",myfitnorm$estimate[1]," (SE = ",myfitnorm$sd[1],")\nSD = ",myfitnorm$estimate[2]," (SE = ",myfitnorm$sd[2],")",
      sep=""), y=0.02), colour="blue", vjust = -1, text=element_text(size=11)) +
    geom_vline(data=scaledtxcor, aes(xintercept=meanrssitxcor), color="blue", linetype="dashed", size=1, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=maxrssitxcor), color="black", linetype="solid", size=0.5, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=minrssitxcor), color="black", linetype="solid", size=0.5, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=meanrssitxcor + sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=meanrssitxcor - sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=meanrssitxcor + 2*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=meanrssitxcor - 2*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=meanrssitxcor + 3*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=meanrssitxcor - 3*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=lowersdpostxcor), color="blue", linetype="dashed", size=1, show.legend = F) +
    geom_vline(data=scaledtxcor, aes(xintercept=uppersdpostxcor), color="blue", linetype="dashed", size=1, show.legend = F) +
    geom_text(aes(x=maxrssitxcor, label=paste("Max = ",maxrssitxcor,sep=""), y=0.01), colour="black", angle=90, vjust = -1, text=element_text(size=11)) +
    geom_text(aes(x=minrssitxcor, label=paste("Min = ",minrssitxcor,sep=""), y=0.01), colour="black", angle=90, vjust = -1, text=element_text(size=11)) +
    geom_text(aes(x=lowersdpostxcor, label=paste("Lower peak = ",lowersdpostxcor,sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
    geom_text(aes(x=uppersdpostxcor, label=paste("Upper peak = ",uppersdpostxcor,sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
    geom_text(aes(x=meanrssitxcor + 2*sdrssitxcor, label=paste("N = ",countrssitxcor,"\nMean = ",meanrssitxcor,"\nSD = ",sdrssitxcor,"\nSkewness = ",skewrssitxcor,"\nKurtosis = ",kurtosisrssitxcor,sep=""), y=0.02), colour="blue", vjust = -1, text=element_text(size=11)) +
    labs(x="Calibrated proximity",
         y="Relative Frequency",
         title="Proximity Frequency fitting",
         subtitle=paste("Across ",groupText," interactions",sep="")) + 
    stat_function(fun = dgamma, args = list(shape = myfit$estimate[1], rate = myfit$estimate[2]), show.legend = F, colour="orange") +
    stat_function(fun = dnorm, args = list(mean = myfitnorm$estimate[1], sd = myfitnorm$estimate[2]), show.legend = F) +
    xlim(xlimmax,xlimmin) + ylim(0,0.025)
  #p
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-fitting-03-complete.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  # TODO change these charts so that calculating fit values, printing those on a pre-fit chart, applying the scale criteria, and charting post-scaled data are separate tasks
  
  print(" - Done")
  # TODO output scaled data frame
}





# Chart and match the raw data now
revOnly <- referenceTxAndReverse(measures) # TODO DOUBLE CHECK THIS IS DEFO RAW DATA WITHOUT TX CORRECTION
printSummary(revOnly,"01-reversed")
chartAndFit(revOnly,"01-reversed")
chartProximity(revOnly,"01-reversed")

# Now try the fit to the 'raw' TxPower corrected data
corrected <- txAndReverse(measures) # 214 events
printSummary(corrected,"02-txcorrected")
chartAndFit(corrected,"02-txcorrected")
chartProximity(corrected,"02-txcorrected")

# WARNING: USE RSSICOR COLUMN BEYOND THIS POINT! (as chartAndFit uses)

# Ensure the contact event data in use has a good distribution across the whole range (reduces local noise)
wideRange <- filterForCERange(corrected,10) # 187 events
wideRangeSelected <- wideRange
printSummary(wideRange,"03-cerangegt10")
chartAndFit(wideRange,"03-cerangegt10")
chartProximity(wideRange,"03-cerangegt10")

#wideRange <- filterForCERange(wideRange,25) # 115 events
#printSummary(wideRange,"03-cerangegt25")
#chartAndFit(wideRange,"03-cerangegt25")
#chartProximity(wideRange,"03-cerangegt25")

#wideRange <- filterForCERange(wideRange,35) # 75 events
#printSummary(wideRange,"03-cerangegt35")
#chartAndFit(wideRange,"03-cerangegt35")
#chartProximity(wideRange,"03-cerangegt35")

#wideRange <- filterForCERange(wideRange,45) # 35 events only
#printSummary(wideRange,"03-cerangegt45")
#chartAndFit(wideRange,"03-cerangegt45")
#chartProximity(wideRange,"03-cerangegt45")


# Next try a running mean on rssicor using the last 10 values, then fitting
runningMean <- wideRangeSelected
runningMean <- runningMean %>%
  dplyr::group_by(macuuid) %>%
  dplyr::mutate(rollrssicor = lag(zoo::rollapplyr(rssicor, 10, mean, partial = TRUE), k = 10)) %>%
  dplyr::ungroup()
head(runningMean, n=20)
runningMean$rssicor <- runningMean$rollrssicor
printSummary(runningMean,"04-runningmean")
chartAndFit(runningMean,"04-runningmean")
chartProximity(runningMean,"04-runningmean")


# Now try last 30 seconds worth of data rather than fixed values
# - As per https://github.com/theheraldproject/herald-analysis/tree/develop/reference-data/rssi-raw-edison#solution

computeSummary <- function(dataFrame) {
  last <- tail(dataFrame, n=1)
  last$rssicorrected <- mean(dataFrame$rssicor)
#      dplyr::summarise(dataFrame, 
#                          t=t,rssiint=rssiint,txpower=txpower,txpowerint=txpowerint,rssicor=rssicor,
#                   rssicorrected = mean(rssicor))
#    ,n=1)
  last
}
head(wideRangeSelected)
timeWindow <- wideRangeSelected

applySlider = function(dataFrame, ...) {
  #print(NROW(dataFrame))
  res <- slider::slide_period_dfr(dataFrame, dataFrame$t, "second", computeSummary, .before=29, .complete=FALSE) # Drops first 29s of data
  #print(NROW(res))
  res
}
#timeWindow <- slide_dbl(timeWindow, Var="rssicor", TimeVar="t", GroupVar="macuuid", NewVar="rssicorrected", SlideBy=30)
timeWindowR <- timeWindow %>%
  dplyr::group_by(macuuid) %>%
  dplyr::group_modify(applySlider) %>%
  dplyr::ungroup()
timeWindowR <- as.data.frame(timeWindowR)
head(timeWindowR, n=200)
NROW(timeWindow)
NROW(timeWindowR)
head(timeWindowR)
head(timeWindow)
timeWindowR$rssicor <- timeWindowR$rssicorrected



# Now perform 30 seconds scaling instead
selectedForScaling <- timeWindowR


# ERROR - WE'RE NOT SCALING RSSI BY TIME FOR THE CALIBRATION - JUST TOTAL QUANTITY SEEN!!! THIS WILL SKEW IT FOR REGULAR ADVERTISERS
# - We need a windowing function generating data every 5 seconds based on (up to) the last 30 seconds
# ERROR - COMPLETE CHART IS ONLY DRAWING MINIMA AND MAXIMA NOT THE WHOLE OF THE DATA, AND ITS TOO IRREGULAR (20 instead of 2)

# Implement scaling and fitting properly:-

# - Map lower peak onto 0 (20 in final result)
# - Map pgamma central peak to 171 (3/4 of 256, minus 1, minus 20 (aka Nearby Risk Position))
# - Scale all values according to that ratio
# - Translate back to 20
# - Limit any above 255 to 255, and below 0 to 0 (giving 0 to 255 - an 8 bit unsigned int)
# - Note: May want to log10/loge values first, to represent long tail transmission drop off

# Note: Below taken from non-scaled chart. Will calculate this on the fly in future
# S10Lite
#central <- 67
#upperpeakvalue <- 29
# A40
central <- 72
upperpeakvalue <- 38

minPeakRisk <- 20
centralRisk <- 191
scaleFactor <- (centralRisk - minPeakRisk) / (central - upperpeakvalue)

scaledData <- selectedForScaling
head(scaledData)

scaledData$rssicor <- scaledData$rssicor - upperpeakvalue
scaledData$rssicor <- scaledData$rssicor * scaleFactor
scaledData$rssicor <- scaledData$rssicor + minPeakRisk
min(scaledData$rssicor)
max(scaledData$rssicor)

# DROP data below and above limits for the purposes of fitting (it skews the fit)
scaledData <- scaledData %>%
  dplyr::filter(rssicor > 0 ) # & rssicor <= 255
min(scaledData$rssicor)
max(scaledData$rssicor)
printSummary(scaledData,"05-scaled")
chartAndFit(scaledData,"05-scaled")

head(scaledData,n=200)

# RISK SCORING
# - Generate risk score function (over corrected data for now) and print out risk incurred per hour, and sanity check it
# - Apply risk scoring function by macuuid, and show top 50 most risky contacts' data over time, descending by riskiness (sanity check)

# Risk function - simple for now, favouring nearer (lower prox value) contact
# Limit prox to 400
# Risk = e ^ (ln(60) * (400 - prox)/400) * minutesPassed (implies a windowing function to calculate risk)
# Note the above gives a score of 60 if at nearest distance for one minute (3600 per close person hour)
# This means the risk will drop off very quickly with distance

scored <- scaledData

# before we start, shift rssicor left by 10%, and turn any negative scores into 0s (max risk)
# - This simulates the nearest contacts all being high risk (E.g. all under 1m incurring the same high score)

# TODO decide if we want to have a 'max risk below x metres' style threshold for nearby risks
#scored$rssicor <- scored$rssicor - 40
#scored$rssicor[scaled$rssicor < 0] <- 0


computeScore <- function(dataFrame) {
  last <- tail(dataFrame, n=1)
  # TODO decide if we want an 'ignore distant contacts for risk calculation' threshold to be applied here
  #if (dataFrame$rssicor[2] > 200) {
  #  last$risk <- 0
  #} else {
  # Pin most distant quarter of results to max so their risk affect is minimal
  #last$risk[last$risk > 300] <- 400
    last$risk <- exp(log(60) * (400 - dataFrame$rssicor[2]) / 400) * (as.numeric(dataFrame$t[2])-as.numeric(dataFrame$t[1])) / 60
  #}
  last
}

applySlidingScore = function(dataFrame, ...) {
  #print(NROW(dataFrame))
  res <- slider::slide_dfr(dataFrame, computeScore, .before=1, .complete=TRUE)
  #print(NROW(res))
  res
}
NROW(scored)
#timeWindow <- slide_dbl(timeWindow, Var="rssicor", TimeVar="t", GroupVar="macuuid", NewVar="rssicorrected", SlideBy=30)
scored <- scored %>%
  dplyr::group_by(macuuid) %>%
#  dplyr::arrange(t) %>%
  dplyr::group_modify(applySlidingScore) %>%
  dplyr::ungroup()
scored <- as.data.frame(scored)
head(scored)
NROW(scored)


chartRiskOverTime <- function(dataFrame, groupText) {
  print(paste("chartRiskOverTime for ",groupText,sep=""))
  # First, chart risk per day
  print(" - Preparing daily data")
  data <- dataFrame
  data$day <- as.Date(data$t)
  data <- data %>%
    dplyr::group_by(day) %>%
    dplyr::summarise(risk=sum(risk))
  
  print(" - Plotting daily chart")
  p <- ggplot(data, aes(x=day, y=risk)) +
    geom_bar(alpha=0.5, show.legend=F, stat= "identity") +
    theme(axis.text.x = element_text(angle=90)) +
    labs(x="Time",
         y=paste("For ",groupText,sep=""),
         title="Risk incurred per day")  + 
    theme(legend.position = "bottom")
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-risk-01-daily.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  print(" - Preparing hourly data")
  data <- dataFrame
  data$t <- as.POSIXct(round(data$t,"hours"))
  data <- data %>%
    dplyr::group_by(t) %>%
    dplyr::summarise(risk=sum(risk))
  
  print(" - Plotting hourly chart")
  p <- ggplot(data, aes(x=t, y=risk)) +
    geom_bar(alpha=0.5, show.legend=F, stat= "identity") +
    theme(axis.text.x = element_text(angle=90)) +
    labs(x="Time",
         y="Risk Score",
         subtitle=paste("For ",groupText,sep=""),
         title="Risk incurred per hour")  + 
    theme(legend.position = "bottom") +
    scale_x_datetime(labels = scales::date_format("%Y-%m-%d %H:%M"), breaks = scales::date_breaks('1 hours'))
  ggsave(paste(basedir,"/",phonedir,"-",groupText,"-risk-02-hourly.png", sep=""), width = chartWidth, height = chartHeight, units = "mm")
  
  
}

chartRiskOverTime(scored, "06-simplerisk")
#head(scored, n=200)

# Now plot scored risk as signal so we can see it over time
scoredOverTime <- scored
head(scoredOverTime)
scoredOverTime$rssicor <- scoredOverTime$risk
#head(scoredOverTime)
chartProximity(scoredOverTime,"06-simplerisk")

# TODO
# - DONE refactor the above methods and below graphs into their own functions
# - DONE neaten up the code so we're not duplicating
# - Put different data through these paths :-
#   1. N/A All raw RSSI data reversed
#   2. DONE Filtered RSSI data reversed
#   3. DONE Calibration results
#   3a. DONE Iterate on calibration routine until we can output our calibration formulae variable values
#   4. WIP Apply risk formula across data
#   4a. DONE Apply to those with txpower and calibration results first (easiest) - WORKING AND VALIDATED
#   4b. All raw data with calibration algorithm applied (requires dynamic calculation and application of risk variables)
# - DONE Review RSSI to calibrated RSSI for TxPower
# - DONE Apply running mean of each contact's RSSI as per current demo app to raw data before processing
# - WIP Externalise R functions for re-use and refactor


















