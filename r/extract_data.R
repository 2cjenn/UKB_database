library(DBI)
library(duckdb)
library(yaml)
library(tidyverse)


# Load the project config file for filepaths etc
if (!exists("config")) {
  library(yaml)
  config = yaml.load_file("config.yml")
}


#' Reads a database of UKB data and returns a dataset containing the requested columns
#'
#' The database contains the data with field codes instead of variable names. It has been pre-processed by the UKB-generated R file to apply categorical variable levels and labels. This loads selecteed variables from the database, applies the chosing naming convention and derives requested variables.
#'
#' @param extract_cols A vector of human readable variable names to extract from the database
#' @param db The path to the database you want to extract the variables from.
#' @param name_map The path to the .csv mapping file containing human-readable names for the raw UKB data fields.
#' @param withdrawals The path to the latest withdrawals csv from UKB, so these participant can be removed
#'
#' @return Returns a data.frame containing the variables requested.
#'
#' @import DBI
#' @import duckdb
#' @export
#' @examples
#' \dontrun{
#' # Extract variables for HTN project from V2 data
#'
#' DB_extract(HTNcols, db="ukb_data.db")
#' }
#'
DB_extract <- function(extract_cols,
                       db = config$data$database,
                       name_map = config$cleaning$renaming,
                       withdrawals = config$cleaning$withdrawals){

  mapping <- read.csv(name_map, stringsAsFactors = FALSE)
  withdrawals <- read.csv(withdrawals, header=FALSE)
  withdrawn_ids <- withdrawals$V1

  # Connect to the database
  con <- dbConnect(duckdb::duckdb(), db, read_only=TRUE)
  on.exit(dbDisconnect(con, shutdown=TRUE))

  # List all tables available in the database
  # Each should correspond to one data download
  tables <- dbListTables(con)
  tables <- tables[!endsWith(tables, "_stata")] # Ignore stata tables

  # Join all download tables to get all data and extract requested columns
  view <- lapply(tables, function(x) tbl(con, from=x)) %>%
    reduce(inner_join, by = "f.eid", suffix = c("", ".delete")) %>%
    select(any_of(name_to_fdot(extract_cols, mapping)), -ends_with(".delete")) %>% # Remove duplicate cols
    filter(!(f.eid %in% withdrawn_ids)) %>% # Exclude participants who have withdrawn
    collect %>%
    rename_with(fdot_to_name, mapping=mapping)

  return(view)
}



#' Reads a database of UKB data and returns a dataset containing the requested columns
#' Similar to DB_extract but allows easier extraction of eg entire categories of data
#'
#' The database contains the data with field codes instead of variable names. It has been pre-processed by the UKB-generated R file to apply categorical variable levels and labels. This loads selecteed variables from the database, applies the chosing naming convention and derives requested variables.
#'
#' @param fieldlist Path to a .txt file containing the list of fields you want. Accepted formats for requesting fields are: category, prefix and maximum. See docs for details.
#' @param db The path to the database you want to extract the variables from.
#' @param name_map The path to the .csv mapping file containing human-readable names for the raw UKB data fields.
#' @param withdrawals The path to the latest withdrawals csv from UKB, so these participant can be removed
#' @param hierarchy_file The path to the .csv file describing the hierarchy of fields on UKB Showcase. Downloadable from UKB (https://biobank.ndph.ox.ac.uk/showcase/schema.cgi?id=13)
#' @param fields_file The path to the .csv file listing all UKB fields. Downloadable from UKB (https://biobank.ndph.ox.ac.uk/showcase/schema.cgi?id=1) but needs to be converted to a .csv.
#'
#' @return Returns a data.frame containing the variables requested.
#'
#' @import DBI
#' @import duckdb
#' @export
#' @examples
#' \dontrun{
#' # Extract variables for HTN project from V2 data
#'
#' bulk_extraction("r/fields.txt")
#' }
#'
bulk_extraction <- function(fieldlist = "r/fields.txt",
                                db = config$data$database,
                                name_map = config$cleaning$renaming,
                                withdrawals = config$cleaning$withdrawals,
                                hierarchy_file = config$cleaning$hierarchy,
                                fields_file = config$cleaning$ukb_fields) {

  mapping <- read.csv(name_map, stringsAsFactors = FALSE)
  withdrawals <- read.csv(withdrawals, header=FALSE)
  withdrawn_ids <- withdrawals$V1

  # Get names of all columns in database
  con <- dbConnect(duckdb::duckdb(), db, read_only=TRUE)
  on.exit(dbDisconnect(con, shutdown=TRUE))
  tables <- dbListTables(con)
  tables <- tables[!endsWith(tables, "_stata")] # Ignore stata tables
  all_cols <- unlist(lapply(tables, FUN=function(x){ duckdb::dbListFields(conn=con, name=x) }))

  # Prepare a list to collect requested fields
  all_fields <- c("f.eid")
  # Read in the file containing requested fields
  request_list <- read.delim(fieldlist, header=FALSE)[,1]
  request_list <- gsub(" ", "", request_list, fixed = TRUE)
  request_list <- request_list[!request_list == "f.eid" & !request_list == ""]

  categories <- request_list[!startsWith(request_list, "f.")]
  if(length(categories)>0) {

    hierarchy <- read.csv(hierarchy_file)
    fields <- read.csv(fields_file)

    children <- categories

    while(any(children %in% hierarchy$parent_id)){
      children <- hierarchy$child_id[hierarchy$parent_id %in% children]
      categories = c(categories, children)
    }

    id_list <- paste0("f.", fields$field_id[fields$main_category %in% categories])
    cat_fields <- unlist(lapply(id_list, FUN=function(id){all_cols[startsWith(all_cols, id)]}))
    all_fields <- c(all_fields, cat_fields)
  }


  field_prefixes <- request_list[startsWith(request_list, "f.") & endsWith(request_list, ".")]
  if(length(field_prefixes)>0) {
    for(prefix in field_prefixes){
      pre_fields <- all_cols[startsWith(all_cols, prefix)]
      all_fields <- c(all_fields, pre_fields)
    }
  }

  field_max <- request_list[startsWith(request_list, "f.") & !endsWith(request_list, ".")]
  if(length(field_max)>0) {
    split <- strsplit(field_max, split="[.]")

    min_fields <- function(field, instance, array){
      combos <- expand.grid(seq(0, instance, by=1), seq(0, array, by=1))
      combos$Var3 <- paste0(combos$Var1, ".", combos$Var2)
      return(paste0(field, combos$Var3))
    }

    max_fields <- unlist(lapply(split, FUN=function(x){
      min_fields(field=paste0(x[1], ".", x[2], "."),
                 instance=as.numeric(x[3]),
                 array=as.numeric(x[4]))
      }))
    # Validate that these fields exist
    max_fields <- max_fields[max_fields %in% all_cols]

    all_fields <- c(all_fields, max_fields)
  }

  unique_fields = unique(all_fields)

  # Join all download tables to get all data and extract requested columns
  view <- lapply(tables, function(x) tbl(con, from=x)) %>%
    reduce(inner_join, by = "f.eid", suffix = c("", ".delete")) %>%
    select(any_of(unique_fields), -ends_with(".delete")) %>% # Remove duplicate cols
    filter(!(f.eid %in% withdrawn_ids)) %>% # Exclude participants who have withdrawn
    collect %>%
    rename_with(fdot_to_name, mapping=mapping)

  return(view)
}


# Maps UKB variable names to human readable names according to the given mapping
#
# UKB variable names of the form f.XXXXX.0.0 are converted to VarName.0.0
#
# @param ukb_col A vector of UKB variable names
# @param mapping A dataframe with the mapping between UKB field IDs and human readable variable names
#
fdot_to_name <- function(ukb_col, mapping) {
  ukb_col <- strsplit(ukb_col, split = ".", fixed = TRUE)
  ukb_col <- sapply(ukb_col, function(x) {
    if (as.character(x[2]) %in% mapping$Field_ID) {
      # Swap the field ID for a human-readable variable name
      x[2] <- mapping$NewVarName[mapping$Field_ID == as.character(x[2])]
    } else {
      print(x[2])
    }
    # Remove the 'f'
    x <- x[-1]
    # Stick it back together with the instances and measurements
    x <- paste(x, collapse = ".")
    return(x)
  })
  return(ukb_col)
}


# Maps human readable names to UKB variable names according to the given mapping
#
# Human readable names of the form VarName.0.0 are converted to UKB variable names f.XXXXX.0.0
#
# @param col_list A vector of human-readable names
# @param mapping A dataframe with the mapping between UKB field IDs and human readable variable names
#
name_to_fdot <- function(col_names,
                         mapping = read.csv(config$cleaning$renaming, stringsAsFactors = FALSE),
                         link = FALSE) {
  col_names <- strsplit(col_names, split = ".", fixed = TRUE)
  col_names <- sapply(col_names, function(x){
    if(x[1] %in% mapping$NewVarName) {
      code <- mapping$Field_ID[mapping$NewVarName == x[1]]
      x[1] <- code
      x <- c("f", x)
      x <- paste(x, collapse=".")

      if(link==TRUE) {
        x <- text_spec(x, link = paste0("http://biobank.ndph.ox.ac.uk/showcase/field.cgi?id=", code))
      }
    } else {
      x <- paste(x, collapse=".")
    }
    return(x)
  })
  return(col_names)
}
