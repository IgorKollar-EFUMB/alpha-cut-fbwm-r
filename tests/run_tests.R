# Installation/reproducibility check of the documented own-data workflow.
# Run from the repository root: source("tests/run_tests.R")
(function() {
  check <- function(ok, text) {
    if (!isTRUE(ok)) stop(text, call. = FALSE)
  }
  cat("Checking repository files and required package...\n")
  files <- c("R/validate_acfbwm_input.R", "R/solve_acfbwm.R",
    "R/export_acfbwm_result.R", "examples/run_acfbwm_example.R",
    "examples/run_own_data.R", "examples/article.R", "data/example.csv",
    "data/my_input_template.csv", "data/PSI.csv",
    "data/Example1_Ratandhara.csv", "data/Example2_Ratandhara.csv")
  missing <- files[!file.exists(files)]
  check(length(missing)==0L, paste("Missing files; check the repository root:",
                                   paste(missing, collapse=", ")))
  check(requireNamespace("highs", quietly=TRUE),
        "Install the required package with install.packages('highs').")
  for (f in files[1:3]) source(f, local=TRUE)
  for (name in c("validate_acfbwm_input", "solve_acfbwm",
                 "report_acfbwm_result", "export_acfbwm_result"))
    check(exists(name, mode="function"), paste("Missing function:",name))
  cat("R:",R.version.string,"; highs:",as.character(utils::packageVersion("highs")),"\n")

  cat("Reading and validating data/my_input_template.csv...\n")
  input <- read.csv("data/my_input_template.csv", stringsAsFactors=FALSE)
  example <- read.csv("data/example.csv", stringsAsFactors=FALSE)
  check(isTRUE(all.equal(input,example)),
        "The supplied example.csv and my_input_template.csv must contain identical data. Use copies for custom data.")
  expected_input <- data.frame(criterion=paste0("C",1:5),
    best_to_others_lower=c(1,1.6,2.6,3.6,5),
    best_to_others_modal=c(1,2,3,4,5),
    best_to_others_upper=c(1,2.4,3.4,4.4,5),
    others_to_worst_lower=c(5,3.6,3.6,1.6,1),
    others_to_worst_modal=c(5,4,4,2,1),
    others_to_worst_upper=c(5,4.4,4.4,2.4,1))
  check(isTRUE(all.equal(input,expected_input,check.attributes=FALSE)),
        "The supplied template differs from the documented reference input. Restore it; edit a copy for your own analysis.")
  validate_acfbwm_input(input, best="C1", worst="C5")

  cat("Calculating documented example: K=129; tolerance=1e-6...\n")
  # Keep warnings visible. They are separate from the weight comparison.
  result <- solve_acfbwm(input,k=129,best="C1",worst="C5",
    input_tolerance=1e-10,denominator_lower_bound=1e-7,tolerance=1e-6,
    epsilon_upper_start=1,epsilon_upper_max=1e6,epsilon_margin=1e-6)
  report_acfbwm_result(result)
  check(inherits(result,"acfbwm_result"),"Unexpected solver result type.")
  check(identical(result$solver_status_message,"Optimal"),"Representative solve was not optimal.")
  # The solver stops if an interval minimization/maximization cannot be solved.
  w <- result$weights
  check(setequal(w$criterion,expected_input$criterion) && nrow(w)==5L,
        "Unexpected criteria in the result.")
  w <- w[match(expected_input$criterion,w$criterion),]
  check(all(is.finite(as.matrix(w[,c("lower_bound","upper_bound",
     "interval_midpoint","normalized_weight")]))),"Non-finite weights or bounds.")
  check(all(w$lower_bound<=w$upper_bound+1e-9),"Invalid weight intervals.")
  check(all(w$normalized_weight>=0) && abs(sum(w$normalized_weight)-1)<1e-8,
        "Normalized weights must be nonnegative and sum to one.")
  check(all(result$diagnostics$satisfied),"A grid diagnostic failed.")
  check(abs(result$max_input_spread-.4)<1e-12 &&
        abs(result$mesh_size-1/128)<1e-12 &&
        abs(result$ea_upper_bound-.003125)<1e-12,"Unexpected grid or EA diagnostics.")

  # Reference from the user's successful run_own_data.R output, model 0.3.1.
  # Retain nine printed decimals; require agreement at four decimal places.
  # This is an empirical reference, not an exact analytical solution.
  reference <- c(0.385097043,0.252772852,0.193031039,0.104542510,0.064556556)
  comparison <- data.frame(criterion=w$criterion,computed=w$normalized_weight,
    reference=reference,difference=w$normalized_weight-reference,
    matches_4dp=round(w$normalized_weight,4)==round(reference,4))
  cat("\nReference comparison (nine-decimal reference; four-decimal acceptance):\n")
  print(comparison,row.names=FALSE,digits=12)
  check(all(comparison$matches_4dp),"Weight comparison failed; see computed values, reference and differences above.")
  check(all(w$rank==1:5),"Criterion ranks differ from the documented reference.")
  check(identical(as.character(result$ranking$criterion),expected_input$criterion),
        "The reported ranking differs from the documented reference.")

  cat("Checking console reporting and all exports...\n")
  out <- tempfile("acfbwm_installation_")
  on.exit(unlink(out,recursive=TRUE),add=TRUE)
  export_acfbwm_result(result,out)
  csv_files <- c("input_original.csv","input.csv","fuzzy_comparisons.csv",
    "weights.csv","ranking.csv","model_summary.csv","parameters.csv",
    "alpha_levels.csv","grid_diagnostics.csv","continuous_alpha_deviations.csv",
    "epsilon_search.csv","interval_solver_trace.csv")
  paths <- file.path(out,c(csv_files,"result.rds","sessionInfo.txt"))
  check(all(file.exists(paths)),"Some expected export files are missing.")
  check(all(file.info(paths)$size>0),"An export file is empty.")
  for (file in csv_files) {
    tab <- read.csv(file.path(out,file),stringsAsFactors=FALSE)
    check(nrow(tab)>0L && ncol(tab)>0L,paste("CSV cannot be read as a nonempty table:",file))
  }
  saved_weights <- read.csv(file.path(out,"weights.csv"),stringsAsFactors=FALSE)
  check(isTRUE(all.equal(saved_weights$normalized_weight,
                        result$weights$normalized_weight,tolerance=1e-12)),
        "Exported weights differ from calculated weights.")
  restored <- readRDS(file.path(out,"result.rds"))
  check(identical(restored,result),"RDS round-trip did not preserve the result.")
  check(length(readLines(file.path(out,"sessionInfo.txt"),warn=FALSE))>0L,
        "Computational environment was not recorded.")
  cat("\nInstallation and reference-weight checks passed.\n")
  if (isTRUE(result$epsilon_tolerance_met)) {
    cat("Epsilon search tolerance: achieved.\n")
  } else {
    cat("Epsilon search tolerance: NOT achieved. Reference weights match at four decimals,\n",
        "but requested epsilon precision is not established; see diagnostics above.\n",sep="")
  }
  cat("Temporary export/read-back checks passed; analysis folders were not changed.\n")
})()
