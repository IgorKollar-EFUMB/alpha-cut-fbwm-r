# Structural validation only. No CI/CR or acceptability assessment.
validate_acfbwm_input <- function(input, best, worst, input_tolerance = 1e-10) {
  columns <- c("criterion", paste0("best_to_others_", c("lower","modal","upper")),
               paste0("others_to_worst_", c("lower","modal","upper")))
  if (!is.data.frame(input)) stop("'input' must be a data frame.", call. = FALSE)
  missing_columns <- setdiff(columns, names(input))
  if (length(missing_columns)) stop(
    "Explicit L-M-U input required. Missing columns: ",
    paste(missing_columns, collapse = ", "), call. = FALSE)
  if (nrow(input) < 2L) stop("At least two criteria are required.", call. = FALSE)
  if (anyDuplicated(names(input))) stop("Duplicate column names.", call. = FALSE)
  input <- input[, columns, drop = FALSE]
  criteria <- as.character(input$criterion)
  if (anyNA(criteria) || any(trimws(criteria) == "") || anyDuplicated(criteria)) {
    stop("Criterion names must be non-empty and unique.", call. = FALSE)
  }
  valid_name <- function(x) is.character(x) && length(x) == 1L &&
    !is.na(x) && x %in% criteria
  if (!valid_name(best) || !valid_name(worst) || identical(best, worst)) {
    stop("'best' and 'worst' must be distinct criterion names in the input.", call. = FALSE)
  }
  if (!is.numeric(input_tolerance) || length(input_tolerance) != 1L ||
      !is.finite(input_tolerance) || input_tolerance < 0 || input_tolerance > 1e-6) {
    stop("'input_tolerance' must be a finite number from 0 to 1e-6.", call. = FALSE)
  }
  for (column in columns[-1]) {
    x <- input[[column]]
    if (!is.numeric(x) || anyNA(x) || any(!is.finite(x)) || any(x <= 0)) {
      stop("Column '", column, "' must contain finite, strictly positive numbers.", call. = FALSE)
    }
  }
  for (prefix in c("best_to_others_", "others_to_worst_")) {
    l <- input[[paste0(prefix,"lower")]]
    m <- input[[paste0(prefix,"modal")]]
    u <- input[[paste0(prefix,"upper")]]
    if (any(l > m | m > u)) {
      stop("Each input triple must satisfy lower <= modal <= upper: ", prefix, call. = FALSE)
    }
  }
  input$criterion <- criteria
  original <- input
  b <- match(best, criteria); w <- match(worst, criteria)
  bo <- as.matrix(input[, columns[2:4]])
  ow <- as.matrix(input[, columns[5:7]])
  if (any(bo[b, ] != 1) || any(ow[w, ] != 1)) {
    stop("Self-comparisons must be exactly (1,1,1): best in BO and worst in OW.", call. = FALSE)
  }
  delta <- abs(bo[w, ] - ow[b, ])
  allowed <- input_tolerance * pmax(1, abs(bo[w, ]), abs(ow[b, ]))
  if (any(delta > allowed)) {
    stop("The complete best-to-worst L-M-U triple must agree in both vectors.", call. = FALSE)
  }
  # Canonicalize only roundoff-level differences, keeping the BO triple.
  # Both original and effective data are returned and exported.
  for (j in 1:3) input[b, columns[4+j]] <- bo[w, j]
  list(data = input, original_data = original, criteria = criteria,
       best_index = b, worst_index = w, best_criterion = best, worst_criterion = worst,
       n_criteria = length(criteria), input_tolerance = input_tolerance,
       best_worst_adjustment = max(delta))
}
