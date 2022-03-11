# Apache 2.0 licensed
# 
# Copyright (c) 2021 Herald Project Contributors
# 

# Author Adam Fowler <adam@adamfowler.org>

# This file holds the Herald Risk calibration and scoring library for R



library(ggplot2)
library(parsedate)
library(stringr)
library(moments) # For skewness calculation
library(zoo) # rolling mean
library(lubridate) # working with time durations
library(fitdistrplus) # gamma distribution fitting
library(slider) # sliding time window
library(scales) # date format in charts


generateDefaultHeraldLibrarySettings <- function() {
  data.frame(
    filterTimeMin <- NA,
    filterTimeMax <- NA,
    filterWithoutTxPower <- TRUE,
    outputFolder <- ".",
    outputFilePrefix <- "", # E.g. phonedir plus hyphen
    groupText <- "", # differentiating text when running the same output function multiple times
    chartWidth <- 400,
    chartHeight <- 300,
    ignoreHeraldDevices <- TRUE,
    heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%S" # PRE v2.1.0-beta3 - integer seconds
    #heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%OS3%z" # v2.1.0-beta3 onwards - 3 decimal places of seconds with timezone as E.g. -0800
    
  )
}

getmode <- function(v) {
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

initialDataPrepAndFilter <- function(settings, dataFrame) {
  # We only care about measures (and their RSSI and TxPower values)
  # i.e. the didMeasure calls (for ALL nearby devices, prefiltering)
  measures <- dplyr::filter(dataFrame,measure==3)
  #head(measures)
  measures <- dplyr::select(measures,c("time","id","data"))
  ##measures <- dplyr::distinct(measures) # DO NOT DO THIS - reduces RSSI data
  names(measures) <- c("time","macuuid","data")
  #head(measures)
  
  if (settings$ignoreHeraldDevices[1]) {
    # Collect macuuids for devices with Herald payloads
    # We will use our two known contacts to test the final risk score algorithm
    print("   - Filtering out Herald devices from dataset")
    heraldcontacts <- dplyr::filter(dataFrame,read==2)
    measures <- dplyr::filter(measures, !(macuuid %in% heraldcontacts$id) )
  }
  
  # Filter by time
  measures$t <- as.POSIXct(measures$time, format=settings$heraldCsvDateFormat[1])
  measures <- dplyr::filter(measures,t>=settings$filterTimeMin[1])
  measures <- dplyr::filter(measures,t<=settings$filterTimeMax[1])
  #head(measures)
  
  # Now extract RSSI and txPower (if present)
  # Example $data value: RSSI:-97.0[BLETransmitPower:8.0]
  rssiAndTxPowerPattern <- "RSSI:(-[0-9]+\\.0)(.BLETransmitPower:([0-9.]+).)?"
  matches <- stringr::str_match(measures$data,rssiAndTxPowerPattern)
  #head(matches)
  measures$rssi <- stringr::str_match(measures$data,rssiAndTxPowerPattern)[,2]
  measures$txpower <- stringr::str_match(measures$data,rssiAndTxPowerPattern)[,4]
#  if (settings$filterWithoutTxPower[1]) {
#    #head(measures)
#  } else {
#    measures$txpower <- NA
#  }
  
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

chartCEStats <- function(settings,dataFrameCE) {
  print(" - chartCEStats")
  if (settings$generateCharts[1]) {
    
    p <- ggplot(dataFrameCE, aes(x=meanrssi,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
      labs(x="Mean RSSI",
           y="Relative Frequency",
           title="Mean RSSI Chart",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-meanrssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    p <- ggplot(dataFrameCE, aes(x=moderssi,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
      labs(x="Mode RSSI",
           y="Relative Frequency",
           title="Mode RSSI Chart",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-moderssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    p <- ggplot(dataFrameCE, aes(x=sdrssi,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
      labs(x="SD RSSI",
           y="Relative Frequency",
           title="SD RSSI Chart",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-sdrssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    p <- ggplot(dataFrameCE, aes(x=minrssi,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
      labs(x="Minimum RSSI",
           y="Relative Frequency",
           title="Minimum RSSI Chart",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-minrssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    p <- ggplot(dataFrameCE, aes(x=maxrssi,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
      labs(x="Maximum RSSI",
           y="Relative Frequency",
           title="Maximum RSSI Chart",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-maxrssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    
    
    # Show maxrssi by meanrssi and similar scatter plots
    
    p <- ggplot(dataFrameCE, aes(x=meanrssi, y=maxrssi,color=1, fill=1)) +
      geom_point(alpha=0.5, show.legend = F) +
      labs(x="Mean RSSI",
           y="Max RSSI",
           title="Mean vs Max RSSI",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-meanvsmaxrssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    p <- ggplot(dataFrameCE, aes(x=meanrssi, y=minrssi,color=1, fill=1)) +
      geom_point(alpha=0.5, show.legend = F) +
      labs(x="Mean RSSI",
           y="Min RSSI",
           title="Mean vs Min RSSI",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-meanvsminrssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    p <- ggplot(dataFrameCE, aes(x=meanrssi, y=rangerssi,color=1, fill=1)) +
      geom_point(alpha=0.5, show.legend = F) +
      labs(x="Mean RSSI",
           y="Range RSSI",
           title="Mean vs Range RSSI",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-meanvsrangerssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    p <- ggplot(dataFrameCE, aes(x=meanrssi, y=sdrssi,color=1, fill=1)) +
      geom_point(alpha=0.5, show.legend = F) +
      labs(x="Mean RSSI",
           y="SD RSSI",
           title="Mean vs SD RSSI",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-meanvssdrssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    p <- ggplot(dataFrameCE, aes(x=maxrssi, y=minrssi,color=1, fill=1)) +
      geom_point(alpha=0.5, show.legend = F) +
      labs(x="Max RSSI",
           y="Min RSSI",
           title="Max vs Min RSSI",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-maxvsminrssi.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    print("   - Done")
  } else {
    print("   - Skipping")
  }
}


chartCEDuration <- function(settings, dataFrameCE, durationLimitMins) {
  print(" - chartCEDuration")
  if (settings$generateCharts[1]) {
    
    cestatslim <- dataFrameCE
    cestatslim$durmin[cestatslim$durmin > durationLimitMins] <- durationLimitMins
    p <- ggplot(cestatslim, aes(x=durmin,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
      labs(x="Duration (minutes)",
           y="Relative Frequency",
           title="Contact Event Duration Frequency",
           subtitle=paste("Across all interactions (max of ",durationLimitMins," minutes)",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-duration.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    print("   - Done")
  } else {
    print("   - Skipping")
  }
}

chartCEReadingsCount <- function(settings, dataFrameCE, readingCountLimit) {
  print(" - chartCEReadingsCount")
  if (settings$generateCharts[1]) {
    
    # Also show a chart of number of readings for each contact event, in the tens of readings
    cestatscntlim <- dataFrameCE
    cestatscntlim$n[cestatscntlim$n > readingCountLimit] <- readingCountLimit
    p <- ggplot(cestatscntlim, aes(x=n,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=5, show.legend = F, aes( y=..density.. )) +
      labs(x="Readings (count)",
           y="Relative Frequency",
           title="Contact Event Reading Count Frequency",
           subtitle=paste("Across ",settings$groupText[1]," interactions (limited to n=",readingCountLimit,")",sep=""))
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"ce-",settings$groupText[1],"-readingcount.png", sep=""), 
           width = settings$chartWidth[1], height = settings$chartHeight[1], units = "mm")
    
    print("   - Done")
  } else {
    print("   - Skipping")
  }
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

## Smooth each contact event's rssi value over time
#smooth <- function(dataFrame, smoothingWidth) {
#  # Order data by ascending time (should be by default)
#  # For each macuuid (contact event), smooth over up to given number of readings (smoothingWidth)
#  
#}
# TODO a version of the above that is sensitive to time between readings
# TODO function that assigns contact event id so that repeated mac addresses from different devices do not interfere with long lived data


# SECTION - Single data column functions

# No longer used
#justReverse <- function(dataFrame) {
#  mydf <- dataFrame
#  maxValue <- max(mydf$rssiint)
#  mydf$rssicor <- maxValue - mydf$rssiint + 1.0
#  mydf
#}

# Doesn't really use a 'reference tx power' yet, simple hardcoding reverse
# Not currently used, but left for when we allow inclusion of non txpower corrected data
referenceTxAndReverse <- function(dataFrame) {
  mydf <- dataFrame
  mydf$rssicor <- 1.0 - mydf$rssiint
  mydf
}

chartProximity <- function(settings, dataFrame) {
  
  print(paste("chartProximity for ",settings$groupText[1],sep=""))
  print(" - Charting prox values")
  if (settings$generateCharts[1]) {
    
    # Graph 1a&b - Show RSSI frequencies by macuuid across whole time period
    # Note: As devices rotate mac address, some devices will be the same but 
    #       appear as different mac addresses
    p <- ggplot(dataFrame, aes(x=rssicor, color=macuuid, fill=macuuid)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
      labs(x=paste(settings$groupText[1]," proximity",sep=""),
           y="Count of each proximity value",
           title="Proximity histogram for each phone detected",
           subtitle="Some phones may be duplicates")  + 
      theme(legend.position = "bottom")
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],settings$groupText[1],"-proximity-values.png", sep=""), 
           width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
    print("   - Done")
  } else {
    print("   - Skipped")
  }
  
  print(" - Charting prox density")
  if (settings$generateCharts[1]) {
    
    p <- ggplot(dataFrame, aes(x=rssicor, y=..density..  , color=macuuid, fill=macuuid)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
      geom_density(alpha=0.3, fill=NA, show.legend = F) +
      labs(x=paste(settings$groupText[1]," proximity",sep=""),
           y="Relative Density",
           title="Proximity histogram for each phone detected",
           subtitle="Some phones may be duplicates")  + 
      theme(legend.position = "bottom")
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"",settings$groupText[1],"-proximity-density.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  } else {
    print("   - Skipped");
  }
  
  
  
  # Graph 2 - Smoothed line of rssi over time (3 degrees of freedom)
  print(" - Charting prox over time")
  if (settings$generateCharts[1]) {
    
    p <- ggplot(dataFrame, aes(x=t,y=rssicor,color=macuuid)) +
      geom_point(show.legend = F) +
      labs(x="Time",
           y=paste(settings$groupText[1]," proximity",sep=""),
           title="Proximity detected over time",
           subtitle="Some phones may be duplicates") +
      scale_x_datetime(date_breaks = "10 min", date_minor_breaks = "2 min")
    #  scale_x_datetime(date_breaks = "60 min", date_minor_breaks = "10 min")
    #  + geom_smooth(method="lm", formula=y ~ poly(x,3), show.legend = F)
    #  geom_smooth(method="loess")
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"",settings$groupText[1],"-proximity-over-time.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  } else {
    print("   - Skipped");
  }
  
  
  
  
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
  if (settings$generateCharts[1]) {
    
    p <- ggplot(measuresinrangewithmostdata, aes(x=t,y=rssicor,color=macuuid)) +
      geom_point(show.legend = F) +
      labs(x="Time",
           y=paste(settings$groupText[1]," Proximity",sep=""),
           title="Proximity detected over time",
           subtitle="50 Contact Events with most in range data only") +
      geom_line(aes(y=zoo::rollmean(rssicor, 5, na.pad=TRUE))) +
      scale_x_datetime(date_breaks = "5 min", date_minor_breaks = "1 min")  +
      facet_wrap(~macuuid, ncol=5, nrow=10, scales="free") +
      theme(legend.position = "none")
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"",settings$groupText[1],"-proximity-over-time-top50.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  } else {
    print("   - Skipped");
  }
  
  print(" - Charting top20 ce by duration")
  if (settings$generateCharts[1]) {
    
    p <- ggplot(measuresinrangewithlongestduration, aes(x=t,y=rssicor,color=macuuid)) +
      geom_point(show.legend = F) +
      labs(x="Time",
           y=paste(settings$groupText[1]," Proximity",sep=""),
           title="Proximity detected over time",
           subtitle="20 Contact Events withlongest duration") +
      geom_line(aes(y=zoo::rollmean(rssicor, 5, na.pad=TRUE))) +
      scale_x_datetime(date_breaks = "5 min", date_minor_breaks = "1 min")  +
      facet_wrap(~macuuid, ncol=4, nrow=5, scales="free") +
      theme(legend.position = "none")
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"",settings$groupText[1],"-proximity-over-time-longest20.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  } else {
    print("   - Skipped");
  }
  
  # Density of ones with most data, above
  
  print(" - Charting density of top50 ce by duration")
  if (settings$generateCharts[1]) {
    
    p <- ggplot(measuresinrangewithmostdata, aes(x=rssicor, y=..density..  , color=macuuid, fill=macuuid)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend=F) +
      geom_density(alpha=0.3, fill=NA, show.legend = F) +
      labs(x=paste(settings$groupText[1]," Proximity",sep=""),
           y="Relative Density",
           title="Proximity histogram for each phone detected",
           subtitle="Top 50 events with most data")  + 
      facet_wrap(~macuuid, ncol=5, nrow=10, scales="free") +
      theme(legend.position = "bottom")
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"",settings$groupText[1],"-proximity-density-top50.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  } else {
    print("   - Skipped");
  }
  
  
  
  
  
  
}

printSummary <- function(settings,dataFrame) {
  ce <- dataFrame %>%
    dplyr::group_by(macuuid) %>%
    dplyr::summarise(mean=mean(rssicor), sd=sd(rssicor), min=min(rssicor), max=max(rssicor), range=max-min, n=dplyr::n())
  totalces <- NROW(ce)
  meanRange <- mean(ce$range)
  sdRange <- sd(ce$range)
  
  # Print number of readings total
  print(
    paste("Summary of ",settings$groupText[1],
          ": Readings=",NROW(dataFrame$rssicor),
          ", Contact Events=",totalces,
          ", Mean range=",meanRange,
          ", SD range=",sdRange,
          sep=""
    )
  )
}

# DUplicate/no longer used
#filterForCERange <- function(dataFrame, minRange) {
#  ce <- dataFrame %>%
#    dplyr::group_by(macuuid) %>%
#    dplyr::summarise(mean=mean(rssicor), sd=sd(rssicor), min=min(rssicor), max=max(rssicor), range=max-min, n=dplyr::n())
#  ce <- dplyr::filter(ce, range >= minRange)
#  filtered <- dplyr::filter(dataFrame, macuuid %in% ce$macuuid)
#}


filterContactEvents <- function (dataFrame, statsData, configuration) {
  res <- dataFrame  
  
  # count lower and higher than 25 mins
  #celong <- dplyr::filter(statsData, durmin >= 60)
  #cemiddle <- dplyr::filter(statsData, durmin >= 26 & durmin < 60)
  ceshort <- dplyr::filter(statsData, durmin < 26)
  #NROW(celong)
  #NROW(cemiddle)
  NROW(ceshort)
  
  # Filter remaining data by those likely as phones (with BL E Privacy enabled)
  NROW(res)
  res <- dplyr::filter(res, macuuid %in% ceshort$macuuid)
  NROW(res)
  # Filter out contact events with less than 35 readings
  cestatscntenough <- dplyr::filter(statsData, n > 35)
  res <- dplyr::filter(res, macuuid %in% cestatscntenough$macuuid)
  NROW(res)
  # Filter for maxrssi
  cestatsmaxrssi <- statsData
  cestatsmaxrssi <- dplyr::filter(cestatsmaxrssi, maxrssi > -90)
  res <- dplyr::filter(res, macuuid %in% cestatsmaxrssi$macuuid)
  NROW(res)
  # Filter for meanrssi
  cestatsmeanrssi <- statsData
  cestatsmeanrssi <- dplyr::filter(cestatsmeanrssi, meanrssi > -80)
  res <- dplyr::filter(res, macuuid %in% cestatsmeanrssi$macuuid)
  NROW(res)
  # Filter for rangerssi > 5 NOTE SUPERCEDED BY LATER FILTER
  #cestatsrangerssi <- statsData
  #cestatsrangerssi <- dplyr::filter(cestatsrangerssi, rangerssi > 5)
  #res <- dplyr::filter(res, macuuid %in% cestatsrangerssi$macuuid)
  #NROW(res)
  # Filter for cerange > 10
  cerangegte10 <- statsData
  cerangegte10 <- dplyr::filter(cerangegte10, rangerssi >= 10)
  res <- dplyr::filter(res, macuuid %in% cerangegte10$macuuid)
  NROW(res)
  
  
  res 
}


calculateCentralAndUpperPeak <- function(settings, dataFrame) {
  
  
  meanrssitxcor <- mean(dataFrame$rssicor)
  sdrssitxcor <- sd(dataFrame$rssicor)
  countrssitxcor <- NROW(dataFrame)
  minrssitxcor <- min(dataFrame$rssicor)
  maxrssitxcor <- max(dataFrame$rssicor)
  skewrssitxcor <- moments::skewness(dataFrame$rssicor, na.rm = TRUE)
  kurtosisrssitxcor <- moments::kurtosis(dataFrame$rssicor, na.rm = TRUE)
  
  weakmintxcor <- min(meanrssitxcor + (3 * sdrssitxcor), max(dataFrame$rssicor))# -98 is the boundary value for bluetooth chips to receive data, so ignore
  weakmaxtxcor <- (meanrssitxcor + (2 * sdrssitxcor))
  strongmintxcor <- (meanrssitxcor - (2 * sdrssitxcor))
  strongmaxtxcor <- max(meanrssitxcor - (4 * sdrssitxcor), 0)
  
  
  # Filter those so we're left with those between 2 and 3 SD only
  dataExtremeties <- dataFrame %>%
    dplyr::filter(
      (rssicor >= strongmaxtxcor & rssicor < strongmintxcor)
      |
        (rssicor <= weakmintxcor & rssicor > weakmaxtxcor )
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
  
  
  write.csv(rssicountssummarytxcor,paste(settings$outputFolder[1] , "/", settings$outputFilePrefix[1],settings$groupText[1],"rssi-peaks.csv",sep=""))
  
  
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
  
  # Find the central (largest y value) peak
  peakData <- dataFrame
  peakData$rssicorGroup <- round(peakData$rssicor)
  peakGroups <- peakData %>%
    dplyr::group_by(rssicorGroup) %>%
    dplyr::summarise(n=dplyr::n()) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(dplyr::desc(n)) #,dplyr::desc(rssicorGroup))
  centralPeakValue <- peakGroups$rssicorGroup[1]
  centralPeakCount <- peakGroups$n[1]
  print(paste(" - Central value is ",centralPeakValue," with count of ",centralPeakCount,sep=""))
  
  # if lower (farthest) point missing, use +3 * SD
  # if upper (nearest) point missing, use -3 * SD
  #if (lowersdpostxcor == meanrssitxcor) {
  #  lowersdpostxcor <- meanrssitxcor + (3 * sdrssitxcor)
  #}
  #if (uppersdpostxcor == meanrssitxcor) {
  #  uppersdpostxcor <- meanrssitxcor - (3 * sdrssitxcor)
  #}
  
  data.frame(
    farPeakValue = lowersdpostxcor, # 'Farther'
    nearPeakValue = uppersdpostxcor, # 'Nearer'
    centralPeakValue = centralPeakValue,
    centralPeakCount = centralPeakCount,
    meanValue = meanrssitxcor,
    sdValue = sdrssitxcor,
    countValues = countrssitxcor,
    minValue = minrssitxcor,
    maxValue = maxrssitxcor,
    nearAreaMin = strongmaxtxcor,
    nearAreaMax = strongmintxcor,
    farAreaMin = weakmaxtxcor, # original variables were flipped, hence the confusing names within this function
    farAreaMax = weakmintxcor
  )
}


chartAndFit <- function(settings, dataFrame, fitData) {
  print(paste("chartAndFit - ",settings$groupText[1],sep=""))
  
  #meanrssitx <- mean(dataFrame$rssiint)
  #sdrssitx <- sd(dataFrame$rssiint)
  #countrssitx <- NROW(dataFrame)
  #minrssitx <- min(dataFrame$rssiint)
  #maxrssitx <- max(dataFrame$rssiint)
  #skewrssitx <- moments::skewness(dataFrame$rssiint, na.rm = TRUE)
  #kurtosisrssitx <- moments::kurtosis(dataFrame$rssiint, na.rm = TRUE)
  
  
  
  #meanrssitxcor <- mean(dataFrame$rssicor)
  #sdrssitxcor <- sd(dataFrame$rssicor)
  #countrssitxcor <- NROW(dataFrame)
  #minrssitxcor <- min(dataFrame$rssicor)
  #maxrssitxcor <- max(dataFrame$rssicor)
  skewrssitxcor <- moments::skewness(dataFrame$rssicor, na.rm = TRUE)
  kurtosisrssitxcor <- moments::kurtosis(dataFrame$rssicor, na.rm = TRUE)
  
  
  
  
  
  
  #  # NOW CREATE NORMALISED (scaled) DATASET
  #  # Now alter rssi values to the idealised normal distribution
  #  # NOTE: Not actually to a N(0,1) as yet - not got the scale factors right...
  #  # Calculate fitness
  #  scaledtxcor <- dataFrame
  #  # Filter beyond the two peaks
  #  #scaledtxcor <- dplyr::filter(scaledtxcor, rssicor >= lowerpeaktxcor & rssicor <= upperpeaktxcor)
  #  #scaledtxcor$rssicorrected <- 0
  #  #scaledtxcor$rssicorrected[scaledtxcor$rssicor < meanrssitxcor] <- (scaledtxcor$rssicor[scaledtxcor$rssicor < meanrssitxcor] - meanrssitxcor) / abs(lowersdpostxcor)
  #  #scaledtxcor$rssicorrected[scaledtxcor$rssicor > meanrssitxcor] <- (scaledtxcor$rssicor[scaledtxcor$rssicor > meanrssitxcor] - meanrssitxcor) / abs(uppersdpostxcor)
  #  head(scaledtxcor)
  #  meancortxcor <- mean(scaledtxcor$rssicor)
  #  sdcortxcor <- sd(scaledtxcor$rssicor)
  #  skewcortxcor <- moments::skewness(scaledtxcor$rssicor, na.rm = TRUE)
  #  kurtosiscortxcor <- moments::kurtosis(scaledtxcor$rssicor, na.rm = TRUE)
  
  
  print(" - Calculating scaled fit")
  
  myfit <- fitdist(dataFrame$rssicor, distr = "gamma", method = "mle")
  summary(myfit)
  gammashape <- myfit$estimate[1] # shape
  gammarate <- myfit$estimate[2] # rate
  
  myfitnorm <- fitdist(dataFrame$rssicor, distr = "norm", method = "mle")
  summary(myfitnorm)
  
  myfitnorm$sd[2]
  
  
  
  
  
  
  # Now plot the same but after txpower correction of rssi
  print(paste(" - Stats: mean=",fitData$meanValue[1]," sd=",fitData$sdValue[1]," n=",fitData$countValues[1], sep=""))
  #  if (settings$generateCharts[1]) {
  #  p <- ggplot(dataFrame, aes(x=rssicor,color=1, fill=1)) +
  #    geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
  #    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor), color="blue", linetype="dashed", size=1, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=maxrssitxcor), color="black", linetype="solid", size=0.5, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=minrssitxcor), color="black", linetype="solid", size=0.5, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor + sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor - sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor + 2*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor - 2*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor + 3*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=meanrssitxcor - 3*sdrssitxcor), color="grey", linetype="dashed", size=0.5, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=lowersdpostxcor), color="blue", linetype="dashed", size=1, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=uppersdpostxcor), color="blue", linetype="dashed", size=1, show.legend = F) +
  #    geom_vline(data=dataFrame, aes(xintercept=centralPeakValue), color="blue", linetype="dashed", size=1, show.legend = F) +
  #    geom_text(aes(x=lowersdpostxcor, label=paste("Lower peak = ",lowersdpostxcor,sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
  #    geom_text(aes(x=uppersdpostxcor, label=paste("Upper peak = ",uppersdpostxcor,sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
  #    geom_text(aes(x=centralPeakValue, label=paste("Central peak = ",centralPeakValue,sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
  #    geom_text(aes(x=meanrssitxcor, label=paste("N = ",countrssitxcor,"\nMean = ",meanrssitxcor,"\nSD = ",sdrssitxcor,"\nSkewness = ",skewrssitxcor,"\nKurtosis = ",kurtosisrssitxcor,sep=""), y=0.02), colour="blue", vjust = -1, text=element_text(size=11)) +
  #    labs(x="RSSI corrected for TxPower",
  #         y="Relative Frequency",
  #         title="Corrected RSSI Frequency",
  #         subtitle="Across all interactions") + 
  #    stat_function(fun = dnorm, args = list(mean = meanrssitxcor, sd = sdrssitxcor), show.legend = F)
  #  p
  #  ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"",settings$groupText[1],"-fitting-01-input-distribution.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  #  } else {
  #    print("   - Skipped");
  #  }
  
  
  
  
  print(" - Calculating bounds for scaling")
  
  # A2 Try to normalise these values - by using the mean and local maxima peaks based on human behaviour
  # - First, Filter for only those rssiint between -3 (or -97) and -1 SD and 1 and 3 SD (or minrssi if smaller)
  #weakmintxcor <- max(meanrssitxcor - (3 * sdrssitxcor), -120)# -98 is the boundary value for bluetooth chips to receive data, so ignore
  #weakmaxtxcor <- meanrssitxcor - (2 * sdrssitxcor)
  #strongmintxcor <- meanrssitxcor + (2 * sdrssitxcor)
  #strongmaxtxcor <- min(meanrssitxcor + (4 * sdrssitxcor), maxrssitxcor, 0)
  sdmeasurestxcor <- dplyr::filter(dataFrame, 
                                   (rssicor > fitData$farAreaMin[1] & rssicor <= fitData$farAreaMax[1]) | 
                                     (rssicor >= fitData$nearAreaMin[1] & rssicor <= fitData$nearAreaMax[1])
  )
  # Chart these as a debug step
  
  if (settings$generateCharts[1]) {
    p <- ggplot(sdmeasurestxcor, aes(x=rssicor)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend=F, aes( y=..density.. )) +
      labs(x="Proximity values",
           y="Count",
           title="Proximity Values in range of local maxima")  + 
      theme(legend.position = "bottom") + 
      stat_function(fun = dnorm, args = list(mean = fitData$meanValue[1], sd = fitData$sdValue[1]), show.legend = F)
    p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],settings$groupText[1],"-fitting-02-maxima-areas.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  } else {
    print("   - Skipped");
  }
  
  
  
  
  
  
  
  
  print(" - Calculating scaling summaries")
  
  
  
  
  
  
  
  # Now chart it
  
  xlimmin <- fitData$maxValue[1]
  if (xlimmin < 255) {
    xlimmin <- 255
  }
  xlimmax <- fitData$minValue[1]
  if (xlimmax > 0) {
    xlimmax <- 0
  }
  
  print(" - Charting scaled fit")
  if (settings$generateCharts[1]) {
    # Now reversed and fitted to gamma and normal(gaussian) distributions
    p <- ggplot(dataFrame, aes(x=rssicor,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=10, show.legend = F, aes( y=..density.. )) +
      geom_text(aes(x=fitData$meanValue[1] - 2*fitData$sdValue[1], label=paste(
        "Gamma:-\nShape = ",myfit$estimate[1]," (SE = ",myfit$sd[1],")\nRate = ",myfit$estimate[2]," (SE = ",myfit$sd[2],")",
        "\nNorm:-\nMean = ",myfitnorm$estimate[1]," (SE = ",myfitnorm$sd[1],")\nSD = ",myfitnorm$estimate[2]," (SE = ",myfitnorm$sd[2],")",
        sep=""), y=0.02), colour="blue", vjust = -1, text=element_text(size=11)) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$maxValue[1]), color="black", linetype="solid", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$minValue[1]), color="black", linetype="solid", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] + fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] - fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] + 2*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] - 2*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] + 3*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] - 3*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$farPeakValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$nearPeakValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$centralPeakValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_text(aes(x=fitData$maxValue[1], label=paste("Max = ",fitData$maxValue[1],sep=""), y=0.01), colour="black", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$minValue[1], label=paste("Min = ",fitData$minValue[1],sep=""), y=0.01), colour="black", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$farPeakValue[1], label=paste("Lower peak = ",fitData$farPeakValue[1],sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$nearPeakValue[1], label=paste("Upper peak = ",fitData$nearPeakValue[1],sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$centralPeakValue[1], label=paste("Central peak = ",fitData$centralPeakValue[1],sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$meanValue[1] + 2*fitData$sdValue[1], label=paste("N = ",fitData$countValues[1],"\nMean = ",fitData$meanValue[1],"\nSD = ",
                                                                               fitData$sdValue[1],"\nSkewness = ",skewrssitxcor,"\nKurtosis = ",kurtosisrssitxcor,sep=""), y=0.02), colour="blue", vjust = -1, text=element_text(size=11)) +
      labs(x="Calibrated proximity",
           y="Relative Frequency",
           title="Proximity Frequency fitting",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep="")) + 
      stat_function(fun = dgamma, args = list(shape = myfit$estimate[1], rate = myfit$estimate[2]), show.legend = F, colour="orange") +
      stat_function(fun = dnorm, args = list(mean = myfitnorm$estimate[1], sd = myfitnorm$estimate[2]), show.legend = F) +
      xlim(xlimmax,xlimmin) + ylim(0,0.025)
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],settings$groupText[1],"-fitting-03-complete.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
    
    # Now reversed and fitted to gamma and normal(gaussian) distributions
    p <- ggplot(dataFrame, aes(x=rssicor,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=3, show.legend = F, aes( y=..density.. )) +
      geom_text(aes(x=fitData$meanValue[1] - 2*fitData$sdValue[1], label=paste(
        "Gamma:-\nShape = ",myfit$estimate[1]," (SE = ",myfit$sd[1],")\nRate = ",myfit$estimate[2]," (SE = ",myfit$sd[2],")",
        "\nNorm:-\nMean = ",myfitnorm$estimate[1]," (SE = ",myfitnorm$sd[1],")\nSD = ",myfitnorm$estimate[2]," (SE = ",myfitnorm$sd[2],")",
        sep=""), y=0.02), colour="blue", vjust = -1, text=element_text(size=11)) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$maxValue[1]), color="black", linetype="solid", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$minValue[1]), color="black", linetype="solid", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] + fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] - fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] + 2*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] - 2*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] + 3*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] - 3*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$farPeakValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$nearPeakValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$centralPeakValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_text(aes(x=fitData$maxValue[1], label=paste("Max = ",fitData$maxValue[1],sep=""), y=0.01), colour="black", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$minValue[1], label=paste("Min = ",fitData$minValue[1],sep=""), y=0.01), colour="black", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$farPeakValue[1], label=paste("Lower peak = ",fitData$farPeakValue[1],sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$nearPeakValue[1], label=paste("Upper peak = ",fitData$nearPeakValue[1],sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$centralPeakValue[1], label=paste("Central peak = ",fitData$centralPeakValue[1],sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$meanValue[1] + 2*fitData$sdValue[1], label=paste("N = ",fitData$countValues[1],"\nMean = ",fitData$meanValue[1],"\nSD = ",
                                                                               fitData$sdValue[1],"\nSkewness = ",skewrssitxcor,"\nKurtosis = ",kurtosisrssitxcor,sep=""), y=0.02), colour="blue", vjust = -1, text=element_text(size=11)) +
      labs(x="Calibrated proximity",
           y="Relative Frequency",
           title="Proximity Frequency fitting",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep="")) + 
      stat_function(fun = dgamma, args = list(shape = myfit$estimate[1], rate = myfit$estimate[2]), show.legend = F, colour="orange") +
      stat_function(fun = dnorm, args = list(mean = myfitnorm$estimate[1], sd = myfitnorm$estimate[2]), show.legend = F) +
      xlim(xlimmax,xlimmin) + ylim(0,0.025)
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],settings$groupText[1],"-fitting-03-complete-3.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
    
    # Now with binwidth=1
    # Now reversed and fitted to gamma and normal(gaussian) distributions
    p <- ggplot(dataFrame, aes(x=rssicor,color=1, fill=1)) +
      geom_histogram(alpha=0.5, binwidth=1, show.legend = F, aes( y=..density.. )) +
      geom_text(aes(x=fitData$meanValue[1] - 2*fitData$sdValue[1], label=paste(
        "Gamma:-\nShape = ",myfit$estimate[1]," (SE = ",myfit$sd[1],")\nRate = ",myfit$estimate[2]," (SE = ",myfit$sd[2],")",
        "\nNorm:-\nMean = ",myfitnorm$estimate[1]," (SE = ",myfitnorm$sd[1],")\nSD = ",myfitnorm$estimate[2]," (SE = ",myfitnorm$sd[2],")",
        sep=""), y=0.02), colour="blue", vjust = -1, text=element_text(size=11)) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$maxValue[1]), color="black", linetype="solid", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$minValue[1]), color="black", linetype="solid", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] + fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] - fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] + 2*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] - 2*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] + 3*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$meanValue[1] - 3*fitData$sdValue[1]), color="grey", linetype="dashed", size=0.5, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$farPeakValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$nearPeakValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_vline(data=dataFrame, aes(xintercept=fitData$centralPeakValue[1]), color="blue", linetype="dashed", size=1, show.legend = F) +
      geom_text(aes(x=fitData$maxValue[1], label=paste("Max = ",fitData$maxValue[1],sep=""), y=0.01), colour="black", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$minValue[1], label=paste("Min = ",fitData$minValue[1],sep=""), y=0.01), colour="black", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$farPeakValue[1], label=paste("Lower peak = ",fitData$farPeakValue[1],sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$nearPeakValue[1], label=paste("Upper peak = ",fitData$nearPeakValue[1],sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$centralPeakValue[1], label=paste("Central peak = ",fitData$centralPeakValue[1],sep=""), y=0.01), colour="blue", angle=90, vjust = -1, text=element_text(size=11)) +
      geom_text(aes(x=fitData$meanValue[1] + 2*fitData$sdValue[1], label=paste("N = ",fitData$countValues[1],"\nMean = ",fitData$meanValue[1],"\nSD = ",
                                                                               fitData$sdValue[1],"\nSkewness = ",skewrssitxcor,"\nKurtosis = ",kurtosisrssitxcor,sep=""), y=0.02), colour="blue", vjust = -1, text=element_text(size=11)) +
      labs(x="Calibrated proximity",
           y="Relative Frequency",
           title="Proximity Frequency fitting",
           subtitle=paste("Across ",settings$groupText[1]," interactions",sep="")) + 
      stat_function(fun = dgamma, args = list(shape = myfit$estimate[1], rate = myfit$estimate[2]), show.legend = F, colour="orange") +
      stat_function(fun = dnorm, args = list(mean = myfitnorm$estimate[1], sd = myfitnorm$estimate[2]), show.legend = F) +
      xlim(xlimmax,xlimmin) + ylim(0,0.025)
    #p
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],settings$groupText[1],"-fitting-03-complete-thin.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  } else {
    print("   - Skipped");
  }
  print(" - Done")
}

applyStandardisedWindow <- function(dataFrame, stdWindowSeconds, windowSizeSeconds) {
  res <- dataFrame %>%
    dplyr::group_by(macuuid) %>%
    dplyr::summarise( t=seq(from=min(t) + stdWindowSeconds,to=max(t) + stdWindowSeconds,by=paste(stdWindowSeconds,"secs",sep=" ")) ) %>%
    dplyr::ungroup()
  head(res)
  
  res <- res %>%
    dplyr::group_by(macuuid,t) %>%
    dplyr::mutate(
      rssicorrected=mean(dataFrame$rssicor[
        dataFrame$macuuid==macuuid &
          dataFrame$t < t &
          dataFrame$t >= (t - windowSizeSeconds)
      ]),
      txpowerint=head(c(tail(dataFrame$txpowerint[
        dataFrame$macuuid==macuuid &
          dataFrame$t < t &
          dataFrame$t >= (t - windowSizeSeconds)
      ],n=1), NA),n=1)
    ) %>%
    dplyr::ungroup()
  res <- as.data.frame(res)
  res <- dplyr::filter(res,!is.na(rssicorrected) & !is.na(txpowerint) & rssicorrected>=0)
  res
}

calculateScale <- function(fitData, minPeakTargetValue, centralPeakTargetValue) {
  central <- fitData$centralPeakValue[1]
  upperpeakvalue <- fitData$nearPeakValue[1]
  
  minPeakRisk <- minPeakTargetValue
  centralRisk <- centralPeakTargetValue
  scaleFactor <- (centralRisk - minPeakRisk) / (central - upperpeakvalue)
  
  data.frame(
    scaleFactor=scaleFactor,
    srcIndexValue=upperpeakvalue,
    srcCentralValue=central,
    targetIndexValue=minPeakRisk,
    targetCentralValue=centralRisk
  )
}

applyScale <- function(dataFrame, scaleFactorData, applyZeroLimit = TRUE) {
  scaledData <- dataFrame
  
  scaledData$rssicor <- scaledData$rssicor - scaleFactorData$srcIndexValue[1]
  scaledData$rssicor <- scaledData$rssicor * scaleFactorData$scaleFactor[1]
  scaledData$rssicor <- scaledData$rssicor + scaleFactorData$targetIndexValue[1]
  min(scaledData$rssicor)
  max(scaledData$rssicor)
  
  # DROP data below and above limits for the purposes of fitting (it skews the fit)
  if (applyZeroLimit) {
    scaledData <- scaledData %>%
      dplyr::filter(rssicor > 0 ) # & rssicor <= 255
  }
  min(scaledData$rssicor)
  max(scaledData$rssicor)
  scaledData
}

saveFitData <- function(settings,fitData) {
  print(paste(" - Saving fitData for ",settings$groupText[1],sep=""))
  write.csv(fitData,paste(settings$outputFolder[1] , "/", settings$outputFilePrefix[1],settings$groupText[1],"-fitdata.csv",sep=""), row.names = FALSE, quote=FALSE, na = "")
}

loadFitData <- function(fitDataFile) {
  
  csvdata <- tryCatch({
    tp <- read.table(fitDataFile, sep=",",header = TRUE)
    
    tp
  }, error = function(err) {
    #  # error handler picks up where error was generated 
    print(paste("Read.table didn't work for fitData!:  ",err))
  })
  head(csvdata)
  csvdata
}

saveScaleFactorData <- function(settings,scaleFactorData) {
  print(paste(" - Saving scaleFactorData for ",settings$groupText[1],sep=""))
  write.csv(scaleFactorData,paste(settings$outputFolder[1] , "/", settings$outputFilePrefix[1],settings$groupText[1],"-scalefactordata.csv",sep=""), row.names = FALSE, quote=FALSE, na = "")
}

loadScaleFactorData <- function(scaleFactorDataFile) {
  
  csvdata <- tryCatch({
    tp <- read.table(scaleFactorDataFile, sep=",",header = TRUE)
    
    tp
  }, error = function(err) {
    #  # error handler picks up where error was generated 
    print(paste("Read.table didn't work for scaleFactorData!:  ",err))
  })
  head(csvdata)
  csvdata
}

# I'm providing a basic log risk score. The exact function matters less than 
# ensuring the input data is calibrated, and the output of it being applied
# provides reliable, comparable scores across different devices
applyRiskUsingBasicLogScore <- function(dataFrame) {
  computeScore <- function(df) {
    last <- tail(df, n=1)
    # TODO decide if we want an 'ignore distant contacts for risk calculation' threshold to be applied here
    #if (df$rssicor[2] > 200) {
    #  last$risk <- 0
    #} else {
    # Pin most distant quarter of results to max so their risk affect is minimal
    #last$risk[last$risk > 300] <- 400
    last$risk <- exp(log(60) * (400 - df$rssicor[2]) / 400) * (as.numeric(df$t[2])-as.numeric(df$t[1])) / 60
    #}
    last
  }
  
  applySlidingScore = function(df, ...) {
    #print(NROW(df))
    res <- slider::slide_dfr(df, computeScore, .before=1, .complete=TRUE)
    #print(NROW(res))
    res
  }
  #NROW(dataFrame)
  #timeWindow <- slide_dbl(timeWindow, Var="rssicor", TimeVar="t", GroupVar="macuuid", NewVar="rssicorrected", SlideBy=30)
  scored <- dataFrame %>%
    dplyr::group_by(macuuid) %>%
    #  dplyr::arrange(t) %>%
    dplyr::group_modify(applySlidingScore) %>%
    dplyr::ungroup()
  scored <- as.data.frame(scored)
  scored
}



chartRiskOverTime <- function(settings, dataFrame) {
  print(paste("chartRiskOverTime for ",settings$groupText[1],sep=""))
  # First, chart risk per day
  print(" - Preparing daily data")
  data <- dataFrame
  data$day <- as.Date(data$t)
  data <- data %>%
    dplyr::group_by(day) %>%
    dplyr::summarise(risk=sum(risk))
  
  print(" - Plotting daily chart")
  if(settings$generateCharts[1]) {
    p <- ggplot(data, aes(x=day, y=risk)) +
      geom_bar(alpha=0.5, show.legend=F, stat= "identity") +
      theme(axis.text.x = element_text(angle=90)) +
      labs(x="Time",
           y=paste("For ",settings$groupText[1],sep=""),
           title="Risk incurred per day")  + 
      theme(legend.position = "bottom")
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"",settings$groupText[1],"-risk-01-daily.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  } else {
    print("   - Skipped");
  }
  
  print(" - Preparing hourly data")
  data <- dataFrame
  data$t <- as.POSIXct(round(data$t,"hours"))
  data <- data %>%
    dplyr::group_by(t) %>%
    dplyr::summarise(risk=sum(risk))
  
  print(" - Plotting hourly chart")
  if(settings$generateCharts[1]) {
    p <- ggplot(data, aes(x=t, y=risk)) +
      geom_bar(alpha=0.5, show.legend=F, stat= "identity") +
      theme(axis.text.x = element_text(angle=90)) +
      labs(x="Time",
           y="Risk Score",
           subtitle=paste("For ",settings$groupText[1],sep=""),
           title="Risk incurred per hour")  + 
      theme(legend.position = "bottom") +
      scale_x_datetime(labels = scales::date_format("%Y-%m-%d %H:%M"), breaks = scales::date_breaks('1 hours'))
    ggsave(paste(settings$outputFolder[1],"/",settings$outputFilePrefix[1],"",settings$groupText[1],"-risk-02-hourly.png", sep=""), width =settings$chartWidth[1], height =settings$chartHeight[1], units = "mm")
  } else {
    print("   - Skipped");
  }
  
  
}


# Default scoring process configuration
# Filter for TxPower, HeraldDevices can be applied 'on the fly' on-device
# CE Filters can be applied after the devices has been out of range for a target time (normally 20 minutes, although we go up to <26 here)
# 
generateDefaultConfiguration <- function() {
  data.frame(
    # 0. Best practice (blinding of results) filters
    filterIgnoreHeraldDevices = TRUE,
    # 1. Filters applied to valid hasMeasured() data only
    filterOnlyWithTxPower = TRUE,
    filterMinCERange = 10, # value, exclusive
    filterMinCEReadings = 35, # count, exclusive
    filterMaxCEDuration = 26, # minutes, exclusive
    filterMinCEValue = -90, # raw rssi, exclusive
    filterMinMeanValue = -80, # mean of CE raw rssi, exclusive
    
    # 2. Windowing standardisation
    windowSize = 5,
    windowLag = 30,
    
    # 3. Scaling based on human behaviour to a standard wide continuous scale
    scaleCentralTargetValue = 200,
    scaleNearTargetValue = 20,
    
    # 4. Fitting calculations based on scaled data
    fitCentralSrcValue = NA, # NA until calculated per-phone
    fitNearSrcValue = NA, # NA until calculated per-phone
    
    # 3. Risk curve (depends on model) and min/max filters
    riskMethod = "basicLog",
    riskFilterMinValue = 0, # Remove all readings in the FINAL risk scoring below this value
    riskFilterMaxValue = NA, # If implemented, filter all values equal to or greater than this number (inclusive)
    riskPerMinute = 60
  )
}



