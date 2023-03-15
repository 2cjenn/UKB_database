The files in this folder are:

* `README.md`: You're reading this!
*  `Run_Script.do`: This is the Stata script you should run to launch the data extraction
* `UKB_fields.csv`: [UK Biobank Schema 1](https://biobank.ndph.ox.ac.uk/showcase/schema.cgi?id=1) - this file has been downloaded, converted to a csv, and renamed to have a slightly more descriptive name.
* `catbrowse.csv`: [UK Biobank Schema 13](https://biobank.ndph.ox.ac.uk/showcase/schema.cgi?id=13)
* `environment.yml`: This file contains the Python environment info needed for the one-time setup
* `fields.txt`: This file is where you should list the fields you want to extract from your database of UKB data
* `helper.do`: This is an example of the "helper" file that will be auto-generated when extracting the data, which will apply nice Stata formatting, as provided by UKB
* `main.py`: This is the Python script where everything happens!

For documentation on how to use these scripts to extract data from a database of UK Biobank data using Stata, see [docs](https://2cjenn.github.io/UKB_database/stata.html).

To use these scripts, you should have already set up a database containing your UK Biobank data, following the instructions [here](https://2cjenn.github.io/UKB_database/database.html).