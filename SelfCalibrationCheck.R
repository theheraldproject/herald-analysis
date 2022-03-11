# Apache 2.0 licensed
# 
# Copyright (c) 2021 Herald Project Contributors
# 

# Author Adam Fowler <adam@adamfowler.org>

# This file generates a risk score for a known remote Herald target
# from Herald demo app CSV data


library(ggplot2)
library(parsedate)
library(stringr)
library(moments) # For skewness calculation
library(zoo) # rolling mean
library(lubridate) # working with time durations
library(fitdistrplus) # gamma distribution fitting
library(slider) # sliding time window
library(scales) # date format in charts

# Include herald risk library
#source("/home/adam/Documents/git/skunkworks/herald-analysis/heraldrisk.R")
source("D:/git/skunkworks/herald-analysis/heraldrisk.R")




#basedir <- "/home/adam/Documents/git/skunkworks/test-data"
basedir <- "D:/git/skunkworks/test-data/2022-01-09-partner-data"

# For A40 data processing
#fitDataFile <- paste(basedir,"17.\ A40-12-16Dec2021-scored-refactored/A40-05-scaled-fitdata.csv",sep="/")
#scaleFactorDataFile <- paste(basedir,"17.\ A40-12-16Dec2021-scored-refactored/A40-05-scaled-scalefactordata.csv",sep="/")
#phonedir <- "A40"
#blid <- "Co2S+A" # For S10Lite, use with A40 data
#bleDefaultTxPower <- 20 # TODO find this for our two test phones S10Lite (use with A40 data)

# For S10Lite data processing
fitDataFile <- paste(basedir,"16.\ S10Lite-12-16Dec2021-scored-refactored/S10Lite-05-scaled-fitdata.csv",sep="/")
scaleFactorDataFile <- paste(basedir,"16.\ S10Lite-12-16Dec2021-scored-refactored/S10Lite-05-scaled-scalefactordata.csv",sep="/")
phonedir <- "S10Lite"
blid <- "c5Y1zQ" # Fpr A40, use with S10Lite data
bleDefaultTxPower <- 12 # TODO find this for our two test phones A40 (usewith S10Lite data)

# A40 result (may be wrong TxPower of 7): Total mutual contact risk score: 5574.81757309342 (ex dropout: 5140.02621124087)
# A40 result (may be wrong TxPower of 20): Total mutual contact risk score: 3384.68671450543 (ex dropout: 3229.97394798798) <-- use this (7.37% less than other side)
# S10Lite result (may be wrong TxPower of 7): Total mutual contact risk score: 5979.51870465455 (ex dropout: 4207.34979939865)
# S10Lite result (may be wrong TxPower of 12): Total mutual contact risk score: 4954.68930704596 (ex dropout: 3486.25233764308) <-- use this

filtertimemin <- as.POSIXct(paste("2021-12-13", "08:00:00"), format="%Y-%m-%d %H:%M:%S")
#filtertimemax <- as.POSIXct(paste("2021-12-16", "09:30:00"), format="%Y-%m-%d %H:%M:%S")
filtertimemax <- as.POSIXct(paste("2021-12-14", "11:00:00"), format="%Y-%m-%d %H:%M:%S") # Dropout at 14th 11:00 (approx) <-- use this

settings <- generateDefaultHeraldLibrarySettings()
head(settings)
settings$outputFolder <- basedir
settings$outputFilePrefix <- paste(phonedir,"-",sep="")
settings$generateCharts <- TRUE # Only enable when we need to (prevents regenerate every chart all the time)
settings$filterTimeMin <- filtertimemin
settings$filterTimeMax <- filtertimemax
settings$ignoreHeraldDevices <- FALSE
# DO NOT filterwithout TxPower (Herald phones may not have it...)
settings$filterWithoutTxPower <- FALSE

head(settings)

# DO NOT EDIT BEYOND THIS LINE
thisdir <- paste(basedir,phonedir,sep="/")

# Load data





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

# Prepare data

measures <- initialDataPrepAndFilter(settings,csvdata)
head(measures)

# Now do our own filter for just the other contact
taggedRemoteData <- dplyr::filter(csvdata,data == blid) # TODO run grep manually on this
head(taggedRemoteData)
measures <- dplyr::filter(measures,macuuid %in% taggedRemoteData$id)
head(measures)
head(taggedRemoteData$id)
head(measures$macuuid)

cestats <- calcCEStats(measures)
settings$groupText <- "prefiltered"
chartCEStats(settings,cestats)

# Do NOT apply CE filters - as we're not generating a calibration, just applying it

# Limit columns to only those of interest (performance tweak)
measures <- dplyr::select(measures,c("t","macuuid","rssiint","txpower"))
names(measures) <- c("t","macuuid","rssiint","txpower")
head(measures)

# Correct TxPower for the other side's phone (may hardcode or average this on an app)
measures$txpower[is.na(measures$txpower)] <- bleDefaultTxPower
head(measures)

# Do apply tx power correction (WARNING assumes Herald remote has TxPower)
corrected <- txAndReverse(measures) # 214 events
settings$groupText <- "02-txcorrected"
printSummary(settings,corrected)


stdWindow <- applyStandardisedWindow(corrected, 5, 30)
# WARNING: USE RSSICOR COLUMN BEYOND THIS POINT! (as chartAndFit uses)

NROW(corrected)
NROW(stdWindow)

head(stdWindow)
stdWindow$rssicor <- stdWindow$rssicorrected
#dplyr::filter(stdWindow, rssicor < 0)
#dplyr::filter(stdWindow, is.na(rssicor))
settings$groupText <- "02b-stdwindow"
printSummary(settings,stdWindow)

# NEW LOAD FIT DATA AND SCALE DATA FROM CALIBRATION
fitData <- loadFitData(fitDataFile)
scaleFactorData <- loadScaleFactorData(scaleFactorDataFile)

# END LOAD FIT DATA AND SCALE DATA FROM CALIBRATION


scaledData <- applyScale(stdWindow,scaleFactorData)
settings$groupText <- "05-scaled"
printSummary(settings,scaledData)


scored <- applyRiskUsingBasicLogScore(scaledData)
head(scored)
NROW(scored)


generateCharts <- TRUE
settings$groupText <- "06-simplerisk"
chartRiskOverTime(settings,scored)
#head(scored, n=200)

# Now plot scored risk as signal so we can see it over time
scoredOverTime <- scored
head(scoredOverTime)
scoredOverTime$rssicor <- scoredOverTime$risk

# NEW NOW SHOW TOTAL RISK SCORE FOR THESE CONTACTS

totalScore <- sum(scoredOverTime$risk)
print(paste("Total mutual contact risk score: ",totalScore,sep=""))

result <- data.frame(
  phone <- phonedir,
  otherblid <- blid,
  riskscore <- totalScore
)
write.csv(result,paste(basedir , "/", phonedir,"-risk-summary.csv",sep=""), row.names = FALSE, quote=FALSE, na = "")

print("DONE")
