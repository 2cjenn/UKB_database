---
title: Extracting data in R
filename: r.md
---

# Setup

You will need the files in the [r](https://github.com/2cjenn/UKB_database/tree/main/r) folder of this repository.

**The script**

[`extract_data.R`](https://github.com/2cjenn/UKB_database/blob/main/r/extract_data.R) contains the functions to extract data from the database.

**The config**

The [config.yml](https://github.com/2cjenn/UKB_database/blob/main/r/config.yml) file is our suggested way of passing filepaths in to the R functions, so that if you want to modify these filepaths you need only do so in this one central configuration file, instead of having to trawl through all your scripts doing find-and-replace. It is written in [yaml](https://yaml.org/) format (similar to [json](https://www.json.org/json-en.html)).

In R, we use the [yaml](https://cran.r-project.org/web/packages/yaml/index.html) package to parse yaml files, storing them as named lists (dictionaries) so you can access the configuration values by name.

**The mapping**

We suggest that you have a mapping by which you convert the UK Biobank field IDs into human-readable names for ease of use. The database contains the data in raw form, with the original UKB Field IDs, which means you can apply any mapping of your choice. 

These scripts expect this mapping to be in the form of [Renaming_List.csv](https://github.com/2cjenn/UKB_database/blob/main/r/Renaming_List.csv).

Our suggested format for a mapping file is as follows (the row in italics is here for documentation only!):

| Field_ID | Field_Description | NewVarName | Coded | Notes |
|-------------|-------------|-------------|-------------|--------------|
| *UKB Field ID* | *Text description of the field* | *Human-readable name* | *Initials of person who named the field* | *Any notes* |
| eid | Pseudonymised participant ID | ID | JC | Please note this "eid" is necessary for the automated renaming process |
| [53](https://biobank.ndph.ox.ac.uk/showcase/field.cgi?id=53) | Date when a participant attended a UK Biobank assessment centre | Rec_DateAssess | JC |  |
| [6150](https://biobank.ndph.ox.ac.uk/showcase/field.cgi?id=6150) | Vascular/heart problems diagnosed by doctor | HMH_HeartProbs | JC | |
| ... | etc | | | |

Required:
* UKB Field IDs must be in a column titled "Field ID" 
* human-readable names must be in a column titled "NewVarName"

But we encourage the other columns as sensible bits of info to keep there!

# Extracting the data

First you will need to source [`extract_data.R`](https://github.com/2cjenn/UKB_database/blob/main/r/extract_data.R) so the functions are loaded for use.

`source("/path/to/extract_data.R")`

## Usage

You need to use the `DB_extract()` function which takes the following form:

```
DB_extract(
    extract_cols,
    db = config$data$database,
    name_map = config$cleaning$renaming,
    withdrawals = config$cleaning$withdrawals
)
```
## Arguments

* `extract_cols`
    * A character vector specifying the columns you want to extract from the database.
    * Note that each column must be fully specified using field name, instance and array (eg Rec_DateAssess.0.0)
* `db`
    * A string giving the filepath to the database you want to extract data from
* `name_map`
    * A string giving the filepath to a mapping file (.csv, formatted as described above) to convert UKB Field IDs to human-readable names
* `withdrawals`
    * A string giving the filepath to the .csv file containing the list of withdrawn UKB participants (you should receive this by email from UKB periodically)


The arguments `db`, `name_map` and `withdrawals` take default values from your [config.yml](https://github.com/2cjenn/UKB_database/blob/main/r/config.yml) if you haven't explicitly supplied alternatives.

Note that you will need to manually specify the instances and arrays for each field you want to extract. We recommend that you always look at the [Data Showcase](https://biobank.ndph.ox.ac.uk/showcase/browse.cgi?) page for your fields of interest, and understand the columns available (described by the instance and array)

## Example

```
data <- DB_extract(
    extract_cols = c(
        "ID", 
        "Rec_DateAssess.0.0",
        paste0("HMH_HeartProbs.0.", seq(0, 3, by=1))
    )
) 
```

In this example, we are extracting
* [Field 53: Date of baseline assessment](https://biobank.ndph.ox.ac.uk/showcase/field.cgi?id=53)
    * We are extracting only the date of the first assessment visit (instance 0)
* [Field 6150: Vascular/heart problems](https://biobank.ndph.ox.ac.uk/showcase/field.cgi?id=6150)
    * We are extracting this field for the first assessment visit only (instance 0)
    * We are extracting four columns of this field, corresponding to the four possible conditions that could be reported in this question (array 0-3)

# Alternatives

You can of course extract the data in any way you prefer, `DB_extract()` is just a wrapper around functions provided in the [`duckDB`](https://duckdb.org/docs/api/r) and [`DBI`](https://dbi.r-dbi.org/) packages.

If you are familiar with SQL, you may wish to submit queries directly using [`dbGetQuery`](https://dbi.r-dbi.org/reference/dbgetquery) from [`DBI`](https://dbi.r-dbi.org/).

Another useful R package for interfacing with databases is [`dbplyr`](https://dbplyr.tidyverse.org/) which allows you to write `dplyr` style code that is converted into SQL queries for you.