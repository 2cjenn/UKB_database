---
title: Extracting data in R
filename: r.md
---

# Setup

You will need the files in the [r](https://github.com/2cjenn/UKB_database/tree/main/r) folder of this repository.

**The script**

[`extract_data.R`]() is the script containing the functions to extract data from the database.

**The config**

The [config.yml]() file is our suggested way of passing filepaths in to the R functions, so that if you want to modify these filepaths you need only do so in this one central configuration file, instead of having to trawl through the script doing find-and-replace. It is written in [yaml](https://yaml.org/) format (similar to [json](https://www.json.org/json-en.html)).

**The mapping**

We assume that you have a mapping by which you convert the UK Biobank field IDs into human-readable names (if not you're either super-human or crazy!) These scripts expect this mapping to be in the form of [Renaming_List.csv]().

<details>

<summary>

Click to view required mapping format:

</summary>

| Field_ID       | Field_Description                                | NewVarName            | Coded                                    | Notes                                                                  |
|-------------|-------------|-------------|-------------|--------------------|
| *UKB Field ID* | *Text description of the field*                  | *Human-readable name* | *Initials of person who named the field* | *Any notes*                                                            |
| eid            | Pseudonymised participant ID                     | ID                    | JC                                       | Please note this "eid" is necessary for the automated renaming process |
| 31             | Gender of participant, self-reported at baseline | BaC_Sex               | JC                                       |                                                                        |
| ...            | etc                                              |                       |                                          |                                                                        |

To be perfectly honest, the only important thing is that the UKB Field IDs are in a column titled "Field ID" and the human-readable names are in a column titled "NewVarName", but we encourage the other columns as sensible bits of info to keep there!

</details>

You will also need a list of the fields you want to extract.

# Running it
