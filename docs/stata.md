---
title: Extracting data in Stata
filename: stata.md
---

# First time setup

Stata 17 has Python integration, and we will use this to extract the data from the database. 

If you have not yet made a database containing your UK Biobank dataset, you will need to do so before you can extract data from it! See the instructions on [creating the database](database.md).

To use Python and Stata to extract data from the database, you need the files in the [pythonStata](https://github.com/2cjenn/UKB_database/tree/main/pythonStata) folder of this [UKB_database repository](https://github.com/2cjenn/UKB_database).

## Setting up Python on your computer

* Create a folder for the project and put the [environment.yml](https://github.com/2cjenn/UKB_database/blob/main/pythonStata/environment.yml) file and the [main.py](https://github.com/2cjenn/UKB_database/blob/main/pythonStata/main.py) script file in it
* Install [miniconda](https://docs.conda.io/en/latest/miniconda.html)
  * Installation options: “Just me”, leave add to PATH unticked
  * If you don’t have admin access to your computer, you won’t be allowed to install in Program Files. Recommend C:\Users\<username>\Miniconda3
* Open an Anaconda prompt (start menu, “Anaconda”) and navigate to the project directory
  * Run `conda env create -f environment.yml`
  * Wait
  * Run `conda activate pythonStata` (it should prompt you to do this)
  * To check it worked, run `conda list` to verify that expected packages have installed


## Setting up the Python integration in Stata

Open Stata version 17 or higher.

Specify the environment you want to use:

`python set exec C:\Users\<username>\Miniconda3\envs\pythonStata\python.exe, permanently`

Make sure the packages you need are installed within that environment, check their install location and add that to the path in Stata:

`python set userpath C:\Users\<username>\Miniconda3\envs\pythonStata\lib\site-packages, permanently`

Remember to put your username in place of `<username>`!

# Specifying fields to extract

Fields are specified in a .txt file. See [fields.txt](https://github.com/2cjenn/UKB_database/blob/main/pythonStata/fields.txt) for an example.

Currently there are three ways to specify fields, described below. You can use a mixture of these within one specification file. [If you think of any more convenient ways you would prefer to specify fields, let me know!]

Fields can be specified by:
* prefix
* maximum wanted instance/measure
* category

Fields can be specified in R style (f.1234.0.0) or Stata style (n_1234_0_0).

##	By prefix

When specifying fields by prefix, you can request multiple data columns

For example: ts_40000_ will return any ts_40000_X_Y, in this case ts_40000_0_0 and ts_40000_1_0.

To request eg all baseline SBP measurements, n_4080\_0\_ will return all n_4080_0_Y, in this case n_4080_0_0 and n_4080_0_1. This can save space by not loading the repeat visit columns if they’re not of interest.

It’s important to start with a letter and end with an underscore.

##	By maximum required instance/measure

For example: ts_40000_A_B will return any ts_40000_X_Y where X ≤ A and Y ≤ B.

If you were instead interested in the first recorded SBP measurement at each assessment visit, n_4080_3_0 will return n_4080_0_0, n_4080_1_0, n_4080_2_0, n_4080_3_0.

##	By category

Specify a category to return all columns for all fields in that category.

For example: 110 will return all fields in [Category 110](https://biobank.ndph.ox.ac.uk/showcase/label.cgi?id=110): the T1 structural brain MRI category.

Specify just the category number, no letters or other characters.

# Running the script

To call Python scripts from within Stata 17, the following general syntax is used:

`python script [scriptname], args([arg1] [arg2] [arg3] ...)`

The specific code to use to extract fields from the UKB database (argument order matters) is:

``python script "`python_script'", args("`field_list'" "`out_file'" "`out_do'" `max_cols' "`db_name'" "`tblname'" "`do_file'" "`dct_file'")``

Where python_script is the full path to the python script file ([`main.py`](https://github.com/2cjenn/UKB_database/blob/main/pythonStata/main.py))

And the arguments are:

* field_list = .txt file containing list of field specs required, one on each line
* out_file = desired output .dta file (give full file path)
* out_do = .do helper file to format the data, see Section 3.2
* max_cols = maximum number of columns per output file, to avoid memory issues
* db_name = full path to database from which to extract the data
* tblname = name of table in database
* do_file = .do file created by ukbconv
* dct_file = .dct file created by ukbconv

We recommend you use the provided [`Run_Script.do`](https://github.com/2cjenn/UKB_database/blob/main/pythonStata/Run_Script.do) and substitute in your own values for the arguments.

# Notes

This expects Stata version 17 to be installed in `C:/Program Files/Stata17/StataMP-64.exe`.

If this is not the case, you will need to modify this path in the Python script.

##	Max columns

As ever, memory restrictions can be a problem. In particular, converting the data from Python to Stata requires more memory than just having the data open. 

For this reason, if there are a lot of columns in your data it will be automatically split into multiple files. The maximum number of columns per data file can be specified as a parameter to the script.

When the data is split into multiple files, the data fields are grouped by category so related fields can be found in the same file. This does mean each file won’t necessarily have the maximum permitted number of columns.

##	The do files

In order to properly format the data to have beautiful Stata variable names and labelled numerics and fancy dates:

* The data is saved in the database without the R formatting applied
* The script extracts the relevant commands from the .do and .dct files created by ukbconv when converting the data download
  * This means we will need to keep running the ukbconv command for stata, but I think it creates those files first, then we can just kill it instead of waiting for it to create the data file
* The script assembles the relevant commands from the ukbconv .do and .dct files, assembles them into a helper .do file tailored for the data fields extracted, and automatically runs that .do file to format the data.
