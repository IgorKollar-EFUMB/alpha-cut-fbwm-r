# Copy this script and data/my_input_template.csv; edit only the copies.
input_path <- "data/my_input_template.csv"
output_dir <- "output/my_analysis"
best <- "C1"
worst <- "C5"
k <- 17L
files <- file.path("R",c("validate_acfbwm_input.R","solve_acfbwm.R","export_acfbwm_result.R"))
if (!all(file.exists(files))) stop("Set the working directory to the repository root.")
if (!requireNamespace("highs",quietly=TRUE)) stop("Install highs: install.packages('highs')")
for (f in files) source(f)
# For semicolons and decimal commas use read.csv2 instead.
input <- read.csv(input_path, stringsAsFactors=FALSE)
cat("Working directory:",getwd(),"\n")
print(input,row.names=FALSE)
result <- solve_acfbwm(input, k=k, best=best, worst=worst)
report_acfbwm_result(result)
export_acfbwm_result(result,output_dir)
cat("Saved to:",normalizePath(output_dir,winslash="/"),"\n")
