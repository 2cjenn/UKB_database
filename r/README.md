The files in this folder are:

* `README.md`: You're reading this!
* `Renaming_List.csv`: This is a sample renaming file, mapping UK Biobank Field IDs to human readable names
* `UKB_fields.csv`: [UK Biobank Schema 1](https://biobank.ndph.ox.ac.uk/showcase/schema.cgi?id=1) - this file has been downloaded, converted to a csv, and renamed to have a slightly more descriptive name.
* `catbrowse.csv`: [UK Biobank Schema 13](https://biobank.ndph.ox.ac.uk/showcase/schema.cgi?id=13)
* `config.yml`: A configuration file specifying important filepaths. We recommend keeping this in the root directory of your R project.
* `extract_data.R`: This R script file contains the functions to extract data from your database of UK Biobank data
* `fields.txt`: This file is where you should list the fields you want to extract from your database of UKB data

For documentation on how to use these scripts to extract data from a database of UK Biobank data using R, see [docs](https://2cjenn.github.io/UKB_database/r.html).

To use these scripts, you should have already set up a database containing your UK Biobank data, following the instructions [here](https://2cjenn.github.io/UKB_database/database.html).