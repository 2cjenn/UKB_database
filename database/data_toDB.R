# Jennifer Collister
# 29/09/2020

library(glue)
library(duckdb)
library(DBI)
library(stringr)
library(dplyr)
library(data.table)

source("path/to/dataset.R")

#---------------------------------------------------------------------------------
# You need to modify the values here:

# download_runID should be the prefix of the .html, .tab and .R files, of the form ukbXXXXX
download_runID <- "ukb12345"

# Provide path to the folder containing the three ukbXXXXX files
file_path<-"path/to/ukbXXXXXfiles"

# Open a terminal window in the directory containing the three ukbXXXXX files
# Run the following command (replacing ukbXXXXX with the filename)
#------------------------------------------------------------------
# split -l 25000 -d --additional-suffix=.tab ukbXXXXX.tab ukbXXXXX_
#------------------------------------------------------------------

# Name of the database to write to (will be created if it doesn't exist)
db_name <- "path/to/ukb_data.db"

# Number of chunks to read (determined by the number of lines per file in the split command)
chunks <- 21

# Renaming sheet - supply this if you want to print a csv listing UKB fields
# you haven't given human-readable names to yet (convenience feature)
# Set to NULL if you don't want to.
mapping <- NULL # "path/to/Renaming_List.csv"

# Should the data be written in Stata-usable format?
# Set this to TRUE if you want to be able to extract data from the database using Stata
# and see documentation 
stata <- FALSE

# Then run this function to load the data into the db
ukb_db(fileset = download_runID,
       path = file_path,
       dbname = db_name,
       chunks = chunks,
       mapping = mapping,
       stata = stata 
       )

# Please keep an eye on the script for a minute or so after launching it
# If you're overwriting an existing table, it will stop with an error.


