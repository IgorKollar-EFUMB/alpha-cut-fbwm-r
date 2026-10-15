# Reporting and exports for model 0.3 (no consistency assessment).
export_acfbwm_result <- function(result, output_dir) {
  stopifnot(inherits(result, "acfbwm_result"))
  legacy_files <- file.path(output_dir, c("local_consistency.csv", "consistency_summary.csv"))
  if (any(file.exists(legacy_files))) {
    stop("This directory contains legacy consistency exports. Choose a new output_dir for model 0.3.", call. = FALSE)
  }
  previous_rds <- file.path(output_dir, "result.rds")
  if (file.exists(previous_rds)) {
    previous <- tryCatch(readRDS(previous_rds), error = function(e) NULL)
    if (!is.list(previous) || !identical(previous$model_version, result$model_version)) {
      stop("The existing result.rds belongs to a different or unknown model. Choose a new output_dir.", call. = FALSE)
    }
  }
  if (dir.exists(output_dir) && length(list.files(output_dir)) > 0L) {
    message("Existing named exports will be overwritten in: ", output_dir)
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(output_dir)) stop("Cannot create output directory: ", output_dir)
  write_table <- function(x, name) {
    write.csv(x, file.path(output_dir, name), row.names = FALSE)
  }
  write_table(result$weights, "weights.csv")
  write_table(result$ranking, "ranking.csv")
  write_table(result$input, "input.csv")
  write_table(result$input_original, "input_original.csv")
  write_table(result$comparison_data, "fuzzy_comparisons.csv")
  write_table(data.frame(
    model_version = result$model_version,
    max_input_spread = result$max_input_spread,
    best_criterion = result$best_criterion, worst_criterion = result$worst_criterion,
    best_worst_adjustment = result$best_worst_adjustment,
    k = result$k, mesh_size = result$mesh_size,
    ea_upper_bound = result$ea_upper_bound, epsilon = result$epsilon,
    epsilon_bisection_upper = result$epsilon_bisection_upper,
    epsilon_lower_bound = result$epsilon_lower_bound,
    epsilon_search_gap = result$epsilon_search_gap,
    epsilon_tolerance_met = result$epsilon_tolerance_met,
    epsilon_search_status = result$epsilon_search_status,
    epsilon_certification_adjustment = result$epsilon_certification_adjustment,
    epsilon_used_for_bounds = result$epsilon_used_for_bounds,
    eta_star = result$eta_star, eta_star_alpha = result$eta_star_alpha,
    eta_star_relation = result$eta_star_relation,
    indeterminate_epsilon_values = paste(result$indeterminate_epsilon_values, collapse = "; "),
    solver = result$solver, solver_version = result$solver_version,
    solver_status = result$solver_status,
    solver_status_message = result$solver_status_message,
    solver_strategy = result$solver_strategy
  ), "model_summary.csv")
  write_table(as.data.frame(result$parameters), "parameters.csv")
  write_table(data.frame(alpha = result$alpha_levels), "alpha_levels.csv")
  write_table(result$diagnostics, "grid_diagnostics.csv")
  write_table(result$solver_diagnostics$epsilon_search, "epsilon_search.csv")
  write_table(result$solver_diagnostics$interval_bounds, "interval_solver_trace.csv")
  write_table(result$solver_diagnostics$continuous_alpha_deviations,
              "continuous_alpha_deviations.csv")
  saveRDS(result, file.path(output_dir, "result.rds"))
  writeLines(capture.output(sessionInfo()), file.path(output_dir, "sessionInfo.txt"))
  invisible(result)
}

report_acfbwm_result <- function(result) {
  cat("\nALPHA-CUT FBWM\n")
  print(result[c("model_version", "parameters", "max_input_spread", "k", "mesh_size", "ea_upper_bound", "epsilon", "epsilon_lower_bound", "epsilon_search_gap",
                 "epsilon_tolerance_met", "epsilon_search_status", "eta_star",
                 "eta_star_alpha", "eta_star_relation", "solver_status_message")])
  print(result$ranking, digits = 8, row.names = FALSE)
  cat("Sum of normalized midpoint weights: ", sum(result$weights$normalized_weight), "\n")
  cat("Discretization and model fit do not establish judgment consistency.\n")
  cat("No input- or output-based CI/CR is calculated. See README.md.\n")
  if (length(result$indeterminate_epsilon_values)) {
    message("Some epsilon trials were unresolved and did not move the bracket. See epsilon_search.csv and epsilon_tolerance_met.")
  }
  invisible(result)
}
