# Setup to extract variables in Stata format

Stata 17 has Python integration, and we will use this to extract the data from the database.

## Setting up Python on your computer

* Create a folder for the project and put the [environment.yml]() file and the [main.py]() script file in it
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

## Running the script from within Stata

To run the script, use the syntax

`python script [scriptname], args([arg1] [arg2] [arg3] [arg4])`

The arguments here are:
* The path to the database file (“path/to/ukb_vX.db”)
* The name of the table in the database, typically ukbXXXXX
*	The path to the .txt file containing the fields required (one on each row) (“path/to/file.txt”)
*	The desired path to the output file (“path/to/file.dta”)

See [`Run_Script.do`]()

# Notes

This expects Stata version 17 to be installed in `C:/Program Files/Stata17/StataMP-64.exe`.

If this is not the case, you will need to modify this path in the Python script.
