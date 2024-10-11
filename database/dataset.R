# Adapted from https://github.com/kenhanscombe/ukbtools, with many thanks!

library(stringr)
library(DBI)
library(duckdb)
library(data.table)
library(dplyr)

globalVariables(
  c(".", "i", "j", "eid", "pair", "ibs0", "kinship", "category_related",
    "ped_related", "code", "heterozygosity_0_0", "field.tab", "field.showcase",
    "field.html", "col.type", "variable", "HetHet", "IBS0", "ID", "ID1", "ID2",
    "Kinship", "categorized_var", "dx", "freq", "tile_range", "lower", "upper",
    "mid", "frequency", "disease"))

#' Reads a UK Biobank phenotype fileset and returns a single dataset.
#'
#' A UK Biobank \emph{fileset} includes a \emph{.tab} file containing the raw data with field codes instead of variable names, an \emph{.r} (\emph{sic}) file containing code to read raw data (inserts categorical variable levels and labels), and an \emph{.html} file containing tables mapping field code to variable name, and labels and levels for categorical variables.
#'
#' @param fileset The prefix for a UKB fileset, e.g., ukbxxxx (for ukbxxxx.tab, ukbxxxx.r, ukbxxxx.html)
#' @param path The path to the directory containing your UKB fileset. The default value is the current directory.
#' @param dbname The name of the database to connect to. The default is ukb_data.db.
#' @param chunks The number of chunks that you split the .tab file into. The default value is 21.
#' @param mapping A mapping file containing human-readable names for the fields. Use if you wish to print a list of fields that aren't yet contained in the mapping. Default NULL.
#' @param stata Set to TRUE if you want to save the data in Stata-usable format as well as R. Default FALSE.
#' @param n_threads Either "max" (uses the number of cores, `parallel::detectCores()`), "dt" (default - uses the data.table default, `data.table::getDTthreads()`), or a numerical value (in which case n_threads is set to the supplied value, or `parallel::detectCores()` if it is smaller).
#' @param data.pos Locates the data in your .html file. The .html file is read into a list; the default value data.pos = 2 indicates the second item in the list. (The first item in the list is the title of the table). You will probably not need to change this value, but if the need arises you can open the .html file in a browser and identify where in the file the data is.
#'
#' @details The \strong{index} and \strong{array} from the UKB field code are preserved in the variable name, as two numbers separated by underscores at the end of the name e.g. \emph{variable_index_array}. \strong{index} refers the assessment instance (or visit). \strong{array} captures multiple answers to the same "question". See UKB documentation for detailed descriptions of \href{http://biobank.ctsu.ox.ac.uk/crystal/instance.cgi?id=2}{index} and \href{http://biobank.ctsu.ox.ac.uk/crystal/help.cgi?cd=array}{array}.
#'
#' @return A dataframe with variable names in snake_case (lowercase and separated by an underscore).
#'
#' @seealso \code{\link{ukb_df_field}} \code{\link{ukb_df_full_join}}
#'
#' @import stringr
#' @import duckdb
#' @import DBI
#' @importFrom data.table fread
#'
ukb_db <- function(fileset, path = ".", dbname = "ukb_data.db", chunks = 21, 
                   mapping = NULL, stata = FALSE,
                   n_threads = "dt", data.pos = 2) {
  tblname=fileset
  tblname_stata = paste0(tblname, "_stata")
  # Check files exist
  html_file <- stringr::str_interp("${fileset}.html")
  r_file <- stringr::str_interp("${fileset}.r")
  tab_file <- stringr::str_interp("${fileset}.tab")

  # Create paths to the r and tab files
  tab_location <- file.path(path, tab_file)
  r_location <- file.path(path, r_file)

  # Comment out .r read of .tab
  edit_ukb_r(r_location)

  # Column types as described by UKB
  # http://biobank.ctsu.ox.ac.uk/crystal/help.cgi?cd=value_type
  col_type <- c(
    "Sequence" = "integer",
    "Integer" = "integer",
    "Categorical (single)" = "character",
    "Categorical (multiple)" = "character",
    "Continuous" = "double",
    "Text" = "character",
    "Date" = "character",
    "Time" = "character",
    "Compound" = "character",
    "Binary object" = "character",
    "Records" = "character",
    "Curve" = "character"
  )

  ukb_key <- ukb_df_field(fileset, path = path) %>%
    mutate(fread_column_type = col_type[col.type])

  # Write a csv containing any columns that don't yet exist in renaming sheet
  if(!is.null(mapping)) {
    renamed_cols <- read.csv(mapping)
    new_cols <- ukb_key %>%
      group_by(field.showcase, col.name) %>%
      summarise(
        max_instance = max(instance),
        max_measure = max(measure),
        .groups="drop"
      ) %>%
      filter(!field.showcase %in% renamed_cols$Field_ID)
    write.csv(new_cols, file.path(path, "Nameless_columns.csv"))
  }

  bad_col_type <- is.na(ukb_key$fread_column_type)

  if (any(bad_col_type)) {
    bad_types <- sort(unique(ukb_key$col.type[bad_col_type])) %>%
      stringr::str_c(bad_types, collapse = ", ")
    warning(
      stringr::str_c(
        "Unknown column types ",
        bad_types,
        " encountered, setting them to type character."
      )
    )
    ukb_key$fread_column_type[bad_col_type] <- "character"
  }

  # Read .tab file from user named path with data.table::fread
  # Include UKB-generated categorical variable labels
  # Write it to a duckDB database
  if(!file.exists(dbname)) {
    dir.create(dirname(dbname))
  }
  con <- DBI::dbConnect(duckdb::duckdb(), dbname)
  on.exit(DBI::dbDisconnect(con, shutdown=TRUE))

  existing_tables <- dbListTables(con)

  for(chunk in seq(1, chunks, by=1)){
    print(paste0("chunk ", chunk))
    # Handle the case where a table with this name already exists
    overwrite <- chunk==1
    stopifnot(overwrite == FALSE | (!tblname %in% existing_tables))
    append <- chunk!=1

    if(chunk==1){
      bd <- read_ukb_tab(str_replace(tab_location, pattern=".tab", replacement="_00.tab"),
                         column_type = ukb_key$fread_column_type,
                          header=TRUE, n_threads = n_threads)
      col.names <- colnames(bd)
    } else if (chunk>1){
      bd <- read_ukb_tab(str_replace(tab_location, pattern=".tab", replacement=paste0("_", sprintf("%02d", chunk-1), ".tab")),
                         column_type = ukb_key$fread_column_type,
                         col.names=col.names, n_threads = n_threads)
    }
    print("read")
    if(stata) {
        duckdb::dbWriteTable(con, name=tblname_stata, value=bd, overwrite=overwrite, append=append, temporary=FALSE)
        print("written for Stata")
    }
    source(r_location, local = TRUE)
    print("formatted for R")
    duckdb::dbWriteTable(con, name=tblname, value=bd, overwrite=overwrite, append=append, temporary=FALSE)
    print("written for R")
  }
}




#' Makes a UKB data-field to variable name table for reference or lookup.
#'
#' Makes either a table of Data-Field and description, or a named vector handy for looking up descriptive name by column names in the UKB fileset tab file.
#'
#' @param fileset The prefix for a UKB fileset, e.g., ukbxxxx (for ukbxxxx.tab, ukbxxxx.r, ukbxxxx.html)
#' @param path The path to the directory containing your UKB fileset. The default value is the current directory.
#' @param data.pos Locates the data in your .html file. The .html file is read into a list; the default value data.pos = 2 indicates the second item in the list. (The first item in the list is the title of the table). You will probably not need to change this value, but if the need arises you can open the .html file in a browser and identify where in the file the data is.
#' @param as.lookup If set to TRUE, returns a named \code{vector}. The default \code{as.look = FALSE} returns a dataframe with columns: field.showcase (as used in the UKB online showcase), field.data (as used in the tab file), name (descriptive name created by \code{\link{ukb_db}})
#'
#' @return Returns a data.frame with columns \code{field.showcase}, \code{field.html}, \code{field.tab}, \code{names}. \code{field.showcase} is how the field appears in the online \href{http://biobank.ctsu.ox.ac.uk/crystal/}{UKB showcase}; \code{field.html} is how the field appears in the html file in your UKB fileset; \code{field.tab} is how the field appears in the tab file in your fileset; and \code{names} is the descriptive name that \code{\link{ukb_db}} assigns to the variable. If \code{as.lookup = TRUE}, the function returns a named character vector of the descriptive names.
#'
#' @seealso \code{\link{ukb_db}}
#'
#' @importFrom stringr str_interp str_c str_replace_all
#' @importFrom xml2 read_html xml_find_all
#' @importFrom rvest html_table
#' @importFrom tibble tibble
#' @export
#' @examples
#' \dontrun{
#' # UKB field-to-description for ukb1234.tab, ukb1234.r, ukb1234.html
#'
#' ukb_df_field("ukb1234")
#' }
#'
ukb_df_field <- function(fileset, path = ".", data.pos = 2, as.lookup = FALSE) {
  html_file <- stringr::str_interp("${fileset}.html")
  html_internal_doc <- xml2::read_html(file.path(path, html_file))
  html_table_nodes <- xml2::xml_find_all(html_internal_doc, "//table")
  html_table <- rvest::html_table(html_table_nodes[[data.pos]])

  df <- fill_missing_description(html_table)
  lookup <- description_to_name(df)
  old_var_names <- paste("f.", gsub("-", ".", df$UDI), sep = "")

  if (as.lookup) {
    names(lookup) <- old_var_names
    return(lookup)
  } else {
    lookup.reference <- tibble::tibble(
      field.showcase = gsub("-.*$", "", df$UDI),
      field.html = df$UDI,
      field.tab = old_var_names,
      col.type = df$Type,
      col.name = ifelse(
        field.showcase == "eid",
        "eid", lookup
        # stringr::str_c(
        #   lookup, "_f",
        #   stringr::str_replace_all(field.html, c("-" = "_", "\\." = "_"))
        # )
      ),
      instance = as.numeric(str_split(old_var_names, pattern="\\.", simplify=TRUE)[,3]),
      measure = as.numeric(str_split(old_var_names, pattern="\\.", simplify=TRUE)[,4])
    )

    return(lookup.reference)
  }
}




# Fills Description and Type columns where missing at follow-up assessments.
#
# @param data Field-to-description table from html file
#
fill_missing_description <-  function(data) {
  udi <- gsub(pattern = "-.*$", "", data$UDI)
  for (i in 2:nrow(data)) {
    if (udi[i] == udi[i-1] & is.na(data$Description[i])) {
      data[i, "Type"] <- data[i-1, "Type"]
      data[i, "Description"] <- data[i-1, "Description"]
    }
  }
  return(data)
}



# Creates a variable name from the field description.
#
# @param data Field-to-description table from html file
#
description_to_name <-  function(data) {

  name <- tolower(data$Description) %>%
    gsub(" - ", "_", x = .) %>%
    gsub(" ", "_", x = .) %>%
    gsub("uses.*data.*coding.*simple_list.$", "", x = .) %>%
    gsub("uses.*data.*coding.*hierarchical_tree.", "", x = .) %>%
    gsub("uses.*data.*coding_[0-9]*", "", x = .) %>%
    gsub("[^[:alnum:][:space:]_]", "", x = .) %>%
    gsub("__*", "_", x = .)

  return(name)
}



# Corrects path to tab file in R source
#
# In particular, if you have moved the fileset from the directory containing the foo.enc file on which you called gconv. NB. gconv writes absolute path to directory containing foo.enc, into foo.r read.table() call
#
# @param fileset prefix for UKB fileset
# @param path The path to the directory containing your UKB fileset. The default value is the current directory.
#
edit_ukb_r <- function(r_location) {

  edit_date <- Sys.time()

  f <- stringr::str_replace(
    readLines(r_location),
    pattern = "bd *<-" ,
    replacement = stringr::str_interp(
      "# Read function edited to write into database: ${edit_date}\n# bd <-")
  )

  cat(f, file = r_location, sep = "\n")
}



# Reads in the data from .tab files
#
# Has a bunch of settings for speed, setting data types of columns, etc
#
# @param tab_location
# @param column_type
# @param header Does the first data line contain column names?
# @param col.names A vector of optional names for the columns. The default is to use the header column.
#
read_ukb_tab <- function(tab_location,
                         column_type,
                         header=FALSE,
                         col.names=NULL,
                         n_threads) {

  # Read the data - these chunks aren't quite identical, I promise!
  if(is.null(col.names)){
    bd <- data.table::fread(
      input = tab_location,
      sep = "\t",
      header = header,
      colClasses = stringr::str_c(column_type),
      data.table = FALSE,
      showProgress = TRUE,
      nThread = if(n_threads == "max") {
        parallel::detectCores()
      } else if (n_threads == "dt") {
        data.table::getDTthreads()
      } else if (is.numeric(n_threads)) {
        min(n_threads, parallel::detectCores())
      }
    )
  } else{
    bd <- data.table::fread(
      input = tab_location,
      sep = "\t",
      header = header,
      col.names=col.names, # This line is different!
      colClasses = stringr::str_c(column_type),
      data.table = FALSE,
      showProgress = TRUE,
      nThread = if(n_threads == "max") {
        parallel::detectCores()
      } else if (n_threads == "dt") {
        data.table::getDTthreads()
      } else if (is.numeric(n_threads)) {
        min(n_threads, parallel::detectCores())
      }
    )
  }

  return(bd)
}
