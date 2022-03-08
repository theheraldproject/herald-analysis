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
#library(tidyquant) # standardise time period
#library(runner)

# Include herald risk library
source("/home/adam/Documents/git/skunkworks/herald-analysis/heraldrisk.R")

# 1. Set the folder that contains a sub folder per phone in the test
#basedir <- "D:\\git\\skunkworks\\test-data\\2021-12-28-roaming"
#phonedir <- "Pixel3XL"
basedir <- "/home/adam/Documents/git/skunkworks/test-data"
#basedir <- "D:\\git\\skunkworks\\test-data\\2022-01-09-partner-data"
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
filtertimemin <- as.POSIXct(paste("2021-12-13", "08:00:00"), format="%Y-%m-%d %H:%M:%S")
filtertimemax <- as.POSIXct(paste("2021-12-16", "09:30:00"), format="%Y-%m-%d %H:%M:%S")


#filtertimemin <- as.POSIXct(paste("2021-11-16", "12:30:00"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-11-16", "18:45:00"), format="%Y-%m-%d %H:%M:%S")

# Runtime settings
#heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%S" # PRE v2.1.0-beta3 - integer seconds
#heraldCsvDateFormat <- "%Y-%m-%d %H:%M:%OS3%z" # v2.1.0-beta3 onwards - 3 decimal places of seconds with timezone as E.g. -0800
#rssiCharts <- FALSE # Output RSSI chart images
#dotxpower <- FALSE # Provide TXPower analyses



settings <- generateDefaultHeraldLibrarySettings()
head(settings)
settings$outputFolder <- basedir
settings$outputFilePrefix <- paste(phonedir,"-",sep="")
settings$generateCharts <- FALSE # Only enable when we need to (prevents regenerate every chart all the time)
settings$filterTimeMin <- filtertimemin
settings$filterTimeMax <- filtertimemax
head(settings)

#ignoreHeraldDevices <- TRUE

#chartWidth <- 400
#chartHeight <- 300

# DO NOT EDIT BEYOND THIS LINE
thisdir <- paste(basedir,phonedir,sep="/")

















configuration <- generateDefaultConfiguration()





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


measures <- initialDataPrepAndFilter(settings,csvdata);




# PART A
# Analyse RSSI values

# Filter invalid RSSIs (Same as we do in the Herald analysis API)
#measures <- dplyr::filter(measures,rssiint>-99)
#measuresinrange <- measures # So we have all the data still, not just that used for self calibration



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

settings$groupText <- "prefiltered-"
cestats <- calcCEStats(measures)
chartCEStats(settings,cestats)



# Check validity of duration calculations by looking at their distribution
# write chart of frequency of durations in minutes
# Limit max duration in graph to 60 mins


chartCEDuration(settings,cestats,60)
chartCEReadingsCount(settings,cestats,350)

measuresinrange <- filterContactEvents(measures,cestats,configuration)


# To confirm filtering at this point, view the effect on aggregate information
cestatsfiltered <- calcCEStats(measuresinrange)

settings$groupText <- "filtered-"
chartCEStats(settings,cestatsfiltered)
chartCEDuration(settings,cestatsfiltered,60)
chartCEReadingsCount(settings,cestatsfiltered,350)


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




# Filter raw data after CE filtering so as not to skew the results
measures <- filterRawData(measures)


# Not used any more as we have a specialised function for this now
## PART B
## Now analyse txpower
#if (dotxpower) {
#  
#  # Get percentage of contacts with TXPower %>%
#  powercontactevents <- measuresinrange %>%
#    dplyr::group_by(macuuid) %>%
#    dplyr::summarise(hastxpower=any(!is.na(txpower)))
#  totalces <- NROW(powercontactevents)
#  head(powercontactevents)
#  head(measuresinrange)
#  totalces
#  powercecounts <- powercontactevents %>%
#    dplyr::group_by(hastxpower) %>%
#    dplyr::summarise(n=dplyr::n())
#  powercecounts
#  write.csv(powercecounts,paste(basedir , "/", phonedir,"-txpower-ce-prevalence.csv",sep=""))
#  
#  
#  # Stats B1 - Calculate mean & sd of RSSI for each txpowerint value
#  txsummary <- withtxpower %>%
#    dplyr::group_by(txpowerint) %>%
#    dplyr::summarise(mean=mean(rssiint), sd=sd(rssiint), min=min(rssiint), max=max(rssiint), n=dplyr::n())
#  head(txsummary)
#  write.csv(txsummary,paste(basedir , "/", phonedir,"-txpower-distribution-values.csv",sep=""))
#  
#  # Stats B2, do the same but summarise by contact event and not advertisementmeasuresinrange %>%
#  txcewith <- txcewithhastx %>%
#    dplyr::group_by(macuuid,txpower) %>%
#    dplyr::summarise(n=dplyr::n())
#  txcewith
#  txcewithtx <- txcewithhastx %>%
#    dplyr::group_by(txpower) %>%
#    dplyr::summarise(mean=mean(rssiint), sd=sd(rssiint), min=min(rssiint), max=max(rssiint), n=dplyr::n())
#  head(txcewithtx)
#  write.csv(txcewithtx,paste(basedir , "/", phonedir,"-txpower-distribution-by-contactevent.csv",sep=""))
#  txcevaries <- txcewith %>%
#    dplyr::group_by(macuuid,txpower) %>%
#    dplyr::summarise(n=dplyr::n())
#  txcevaries <- dplyr::filter(txcevaries,n > 1)
#  txcevaries
#  
#  # TODO add 'correction' logic for txPower of the remote (partial, ideally need both sides)
#  
#  
#} # end if dotxpower







# Hypothesis 1, Null point 1 - Each contact event RSSI is normally distributed
# Method: Find 12 contact events with highest number of rssi readings, and chart their RSSI over time, and rssi distribution




# We're not doing this any more - we're using the txPower method instead.
# This is left here for when we incorporate non-TxPower data using a calculated or fixed reference TxPower value
## Chart and match the raw data now
#revOnly <- referenceTxAndReverse(measures) # TODO DOUBLE CHECK THIS IS DEFO RAW DATA WITHOUT TX CORRECTION
#printSummary(revOnly,"01-reversed")
#fitData <- calculateCentralAndUpperPeak(revOnly)
#chartAndFit(revOnly,"01-reversed",fitData)
#chartProximity(revOnly,"01-reversed")

settings$groupText <- "02-txcorrected-"
head(settings)

# Now try the fit to the 'raw' TxPower corrected data
corrected <- txAndReverse(measures) # 214 events
printSummary(settings,corrected)
fitData <- calculateCentralAndUpperPeak(settings,corrected)
chartAndFit(settings, corrected, fitData)
chartProximity(settings, corrected)

head(corrected)



stdWindow <- applyStandardisedWindow(corrected, 5, 30)
# WARNING: USE RSSICOR COLUMN BEYOND THIS POINT! (as chartAndFit uses)

NROW(corrected)
NROW(stdWindow)

settings$groupText <- "02b-stdwindow"

head(stdWindow)
stdWindow$rssicor <- stdWindow$rssicorrected
#dplyr::filter(stdWindow, rssicor < 0)
#dplyr::filter(stdWindow, is.na(rssicor))
printSummary(settings, stdWindow)
fitData <- calculateCentralAndUpperPeak(settings, stdWindow)
head(fitData)
chartAndFit(settings, stdWindow,fitData)
chartProximity(settings, stdWindow)


# Ensure the contact event data in use has a good distribution across the whole range (reduces local noise)
#wideRange <- filterForCERange(stdWindow,10) # 187 events
#wideRangeSelected <- wideRange
wideRangeSelected <- stdWindow
#printSummary(wideRange,"03-cerangegt10")
#fitData <- calculateCentralAndUpperPeak(wideRange,"03-cerangegt10")
#chartAndFit(wideRange,"03-cerangegt10",fitData)
#chartProximity(wideRange,"03-cerangegt10")

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
# NOTE RUNNING MEAN IGNORED FOR NOW AS WERE DOING THIS IN STANDARDISE WINDOW
#runningMean <- wideRangeSelected
#runningMean <- runningMean %>%
#  dplyr::group_by(macuuid) %>%
#  dplyr::mutate(rollrssicor = lag(zoo::rollapplyr(rssicor, 10, mean, partial = TRUE), k = 10)) %>%
#  dplyr::ungroup()
#head(runningMean, n=20)
#runningMean$rssicor <- runningMean$rollrssicor
#printSummary(runningMean,"04-runningmean")
#chartAndFit(runningMean,"04-runningmean")
#chartProximity(runningMean,"04-runningmean")


# Now try last 30 seconds worth of data rather than fixed values
# - As per https://github.com/theheraldproject/herald-analysis/tree/develop/reference-data/rssi-raw-edison#solution

#computeSummary <- function(dataFrame) {
#  last <- tail(dataFrame, n=1)
#  last$rssicorrected <- mean(dataFrame$rssicor)
##      dplyr::summarise(dataFrame, 
##                          t=t,rssiint=rssiint,txpower=txpower,txpowerint=txpowerint,rssicor=rssicor,
##                   rssicorrected = mean(rssicor))
##    ,n=1)
#  last
#}
#head(wideRangeSelected)
#timeWindow <- wideRangeSelected

#applySlider = function(dataFrame, ...) {
#  #print(NROW(dataFrame))
#  res <- slider::slide_period_dfr(dataFrame, dataFrame$t, "second", computeSummary, .before=29, .complete=FALSE) # Drops first 29s of data
#  #print(NROW(res))
#  res
#}
#timeWindow <- slide_dbl(timeWindow, Var="rssicor", TimeVar="t", GroupVar="macuuid", NewVar="rssicorrected", SlideBy=30)
#timeWindowR <- timeWindow %>%
#  dplyr::group_by(macuuid) %>%
#  dplyr::group_modify(applySlider) %>%
#  dplyr::ungroup()
#timeWindowR <- as.data.frame(timeWindowR)
#head(timeWindowR, n=200)
#NROW(timeWindow)
#NROW(timeWindowR)
#head(timeWindowR)
#head(timeWindow)
#timeWindowR$rssicor <- timeWindowR$rssicorrected



# Now perform 30 seconds scaling instead
#selectedForScaling <- timeWindowR


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




# NO LONGER USING SEPARATE SLIDING WINDOW FUNCTIONS
scaledData <- wideRangeSelected
head(scaledData)

# Note: Below taken from non-scaled chart. Will calculate this on the fly in future
# S10Lite
#central <- 82 # or 67 depending on which source data you calibrate from
#upperpeakvalue <- 29
# A40
#central <- 83
#upperpeakvalue <- 38

settings$groupText <- "05-scaled"

fitData <- calculateCentralAndUpperPeak(settings,scaledData)
head(fitData)

generateCharts <- TRUE

saveFitData(settings, fitData)
scaleFactorData <- calculateScale(fitData,20,200)
saveScaleFactorData(settings, scaleFactorData)
scaledData <- applyScale(scaledData,scaleFactorData)
printSummary(settings, scaledData)

# FitData has not yet been scaled - need to recalculate before charting
fitData <- calculateCentralAndUpperPeak(settings,scaledData)
head(fitData)

chartAndFit(settings, scaledData,fitData)

#head(scaledData,n=200)

# RISK SCORING
# - Generate risk score function (over corrected data for now) and print out risk incurred per hour, and sanity check it
# - Apply risk scoring function by macuuid, and show top 50 most risky contacts' data over time, descending by riskiness (sanity check)

# Risk function - simple for now, favouring nearer (lower prox value) contact
# Limit prox to 400
# Risk = e ^ (ln(60) * (400 - prox)/400) * minutesPassed (implies a windowing function to calculate risk)
# Note the above gives a score of 60 if at nearest distance for one minute (3600 per close person hour)
# This means the risk will drop off very quickly with distance

#scored <- scaledData

# before we start, shift rssicor left by 10%, and turn any negative scores into 0s (max risk)
# - This simulates the nearest contacts all being high risk (E.g. all under 1m incurring the same high score)

# TODO decide if we want to have a 'max risk below x metres' style threshold for nearby risks
#scored$rssicor <- scored$rssicor - 40
#scored$rssicor[scaled$rssicor < 0] <- 0

# Use a basic log risk scoring technique, giving much larger scores for nearer or longer interactions
scored <- applyRiskUsingBasicLogScore(scaledData)
head(scored)
NROW(scored)


settings$generateCharts <- TRUE
settings$groupText <- "06-simplerisk"
chartRiskOverTime(settings, scored)
#head(scored, n=200)

# Now plot scored risk as signal so we can see it over time
scoredOverTime <- scored
head(scoredOverTime)
scoredOverTime$rssicor <- scoredOverTime$risk
#head(scoredOverTime)
chartProximity(settings, scoredOverTime)


# Now write out the final self-calibration results - enough to reproduce on a phone
configuration$fitCentralSrcValue <- fitData$centralPeakValue[1]
configuration$fitNearSrcValue <- fitData$nearPeakValue[1]
head(configuration)
# TODO save final configuration

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
#   4b. DONE Apply standardised time window at 5 seconds with 30 seconds of history to remove skew
#   4c. DONE Find maximum y value in buckets and scale to 250, find min and scale to 50, now fit and check distributions are the same
#   4d. DONE Separate statistics and charting steps, and produce calibration summary format
#   4e. DONE Create R functions for all re-usable functionality
#   4f. WIP Externalise R functions for re-use and refactor
#   4x. All raw data with calibration algorithm applied (requires dynamic calculation and application of risk variables)
# - DONE Review RSSI to calibrated RSSI for TxPower
# - DONE Apply running mean of each contact's RSSI as per current demo app to raw data before processing
# - Compare mutual risk scores for both test phones' users

















