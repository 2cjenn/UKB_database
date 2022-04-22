# Jennifer Collister
# 29/09/2020
# XL edit: 07/10/2020 (Amended download_runID, file_path for 9th data download)
library(glue)
library(duckdb)
library(DBI)
library(stringr)
library(tidyverse)
library(data.table)

source("K:/TEU/UKB33952_Data/Data_Downloads/database_scripts/dataset.R")

#---------------------------------------------------------------------------------
# You need to modify the values here:

# download_runID should be the prefix of the .html, .tab and .R files, of the form ukbXXXXX
download_runID <- "ukb48850"

# file_path should be the path to the folder containing the three ukbXXXXX files
#file_path <- "K:/TEU/UKB33952_Data/Data_Downloads/V5.0_B2015010_R48850/Data_20211015"
file_path<-"C:/Users/xiaonanl/UKB"

# Open a Git bash in the directory containing the three ukbXXXXX files
# Run the following command
#------------------------------------------------------------------
# split -l 25000 -d --additional-suffix=.tab ukbXXXXX.tab ukbXXXXX_
#------------------------------------------------------------------

# db_version should be the UKB data refresh version
db_version <- 5
# From this we generate the filepath and the name of the database
# format: ukb_vX.db where X is the UKB refresh version of the data as per our download naming convention
#db_name <- glue("K:/TEU/UKB33952_Data/Data_Downloads/V{db_version}_database_duckdb0.2.7/ukb_v{db_version}.db")
db_name <- glue("C:/Users/xiaonanl/UKB/V{db_version}_database_duckdb0.3.0/ukb_v{db_version}.db")

# Latest version of the renaming sheet - supply this if you want to print a csv of "nameless" columns
mapping <- "K:/TEU/UKB33952_Data/Data_Dictionary/Renaming_List_UPDATE_Sep2021_TEU.csv"

# Then run this function to load the data into the db
ukb_db(fileset = download_runID,
       path = file_path,
       dbname = db_name,
       mapping = NULL,
       stata=TRUE)

# Please keep an eye on the script for a minute or so after launching it
# If you're writing to a new database, or overwriting an existing table, it will query this before continuing


