source("r/extract_data.R")

data <- bulk_extraction(fieldlist = "r/fields.txt",
                            db = config$data$database,
                            name_map = config$cleaning$renaming,
                            withdrawals = config$cleaning$withdrawals,
                            hierarchy_file = config$cleaning$hierarchy,
                            fields_file = config$cleaning$ukb_fields)
saveRDS(data, "Metabolic_RepeatMeasures_20230512.rds")
