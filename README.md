# DuckDB Database system for storing and extracting UKB data

#### Jennifer Collister, Xiaonan Liu
#### Translational Epidemiology Unit, NDPH

Data downloads from UK Biobank can be too large to hold in memory in R or Stata on desktop computers.

Rather than splitting the data into multiple smaller files, and then having to remember which variables are stored in each file, we store the entire dataset in one table of a duckDB database.

The scripts in this repository and the documentation in the [accompanying website](https://2cjenn.github.io/UKB_database/):
* Create a duckDB database from the UK Biobank data ([scripts](https://github.com/2cjenn/UKB_database/tree/main/database)/[docs](https://2cjenn.github.io/UKB_database/database.html))
* Extract variables from this database in
  * R ([scripts](https://github.com/2cjenn/UKB_database/tree/main/r)/[docs](https://2cjenn.github.io/UKB_database/r.html))
  * Stata v17 (using Python) ([scripts](https://github.com/2cjenn/UKB_database/tree/main/pythonStata)/[docs](https://2cjenn.github.io/UKB_database/stata.html))

# Cautionary Note

The database [`duckdb`](https://duckdb.org/) is still under development, which means that unfortunately new versions of the package are often not backwards compatible. This means a database written under one version of duckdb cannot be read by a later version.

Please consider using some form of package management, for example [`renv`](https://rstudio.github.io/renv/articles/renv.html) to facilitate control over package versions.

