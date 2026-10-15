# Explicit positive triangular inputs; finite alpha-grid minimax model.
solve_acfbwm <- function(
    input,
    k,
    best,
    worst,
    input_tolerance = 1e-10,
    denominator_lower_bound = 1e-7,
    tolerance = 1e-6,
    epsilon_upper_start = 1,
    epsilon_upper_max = 1e6,
    epsilon_margin = 1e-6
) {
  if (!exists("validate_acfbwm_input", mode = "function")) {
    stop(
      "Function 'validate_acfbwm_input()' is not available. ",
      "Source 'R/validate_acfbwm_input.R' first.",
      call. = FALSE
    )
  }
  if (!requireNamespace("highs", quietly = TRUE)) {
    stop(
      "Package 'highs' is required. Install it with ",
      "install.packages('highs').",
      call. = FALSE
    )
  }

  if (
    length(k) != 1L ||
      !is.numeric(k) ||
      !is.finite(k) ||
      k < 2 ||
      k > .Machine$integer.max ||
      k != as.integer(k)
  ) {
    stop(
      "'k' must be a single integer greater than or equal to 2.",
      call. = FALSE
    )
  }
  k <- as.integer(k)

  numeric_parameters <- list(
    input_tolerance = input_tolerance,
    denominator_lower_bound = denominator_lower_bound,
    tolerance = tolerance,
    epsilon_upper_start = epsilon_upper_start,
    epsilon_upper_max = epsilon_upper_max,
    epsilon_margin = epsilon_margin
  )
  if (!all(vapply(numeric_parameters, function(x) {
    is.numeric(x) && length(x) == 1L && is.finite(x)
  }, logical(1)))) {
    stop("Each numerical parameter must be a single finite number.", call. = FALSE)
  }
  if (
    denominator_lower_bound <= 0 ||
      tolerance <= 0 ||
      epsilon_upper_start <= 0 ||
      epsilon_upper_max < epsilon_upper_start ||
      epsilon_margin < 0
  ) {
    stop(
      "Tolerance and denominator bounds must be positive; epsilon settings ",
      "must define a valid non-negative search range.",
      call. = FALSE
    )
  }

  if (missing(best) || missing(worst)) {
    stop("Supply explicit best and worst criterion names.", call. = FALSE)
  }
  validated <- validate_acfbwm_input(input, best, worst, input_tolerance)
  alpha_levels <- seq(0, 1, length.out = k)
  mesh_size <- max(diff(alpha_levels))

  comparison_data <- .prepare_acfbwm_comparisons(
    validated = validated
  )

  max_input_spread <- max(c(
      comparison_data$best_modal - comparison_data$best_lower,
      comparison_data$best_upper - comparison_data$best_modal,
      comparison_data$worst_modal - comparison_data$worst_lower,
      comparison_data$worst_upper - comparison_data$worst_modal))

  epsilon_result <- .solve_acfbwm_epsilon(
    validated = validated,
    comparison_data = comparison_data,
    alpha_levels = alpha_levels,
    denominator_lower_bound = denominator_lower_bound,
    tolerance = tolerance,
    epsilon_upper_start = epsilon_upper_start,
    epsilon_upper_max = epsilon_upper_max
  )

  bounds_result <- .compute_acfbwm_bounds(
    epsilon = epsilon_result$epsilon,
    validated = validated,
    comparison_data = comparison_data,
    alpha_levels = alpha_levels,
    denominator_lower_bound = denominator_lower_bound,
    epsilon_margin = epsilon_margin
  )

  eta_result <- .compute_acfbwm_eta_diagnostics(
    validated = validated,
    comparison_data = comparison_data,
    representative_weights = epsilon_result$representative_weights
  )

  weights <- merge(
    epsilon_result$representative_weights,
    bounds_result$bounds,
    by = "criterion",
    sort = FALSE
  )
  weights <- weights[
    match(validated$criteria, weights$criterion),
    ,
    drop = FALSE
  ]
  weights$rank <- rank(-weights$normalized_weight, ties.method = "min")

  ranking <- weights[order(weights$rank, weights$criterion), , drop = FALSE]
  row.names(ranking) <- NULL
  row.names(weights) <- NULL

  result <- list(
    method = "Alpha-cut intervals based Fuzzy Best-Worst Method",
    weights = weights,
    ranking = ranking,
    epsilon = epsilon_result$epsilon,
    epsilon_bisection_upper = epsilon_result$epsilon_bisection_upper,
    epsilon_lower_bound = epsilon_result$epsilon_lower_bound,
    epsilon_search_gap = epsilon_result$epsilon_search_gap,
    epsilon_tolerance_met = epsilon_result$epsilon_tolerance_met,
    epsilon_search_status = epsilon_result$epsilon_search_status,
    epsilon_certification_adjustment =
      epsilon_result$epsilon_certification_adjustment,
    indeterminate_epsilon_values =
      epsilon_result$indeterminate_epsilon_values,
    epsilon_used_for_bounds = bounds_result$epsilon_used,
    k = k,
    alpha_levels = alpha_levels,
    mesh_size = mesh_size,
    max_input_spread = max_input_spread,
    ea_upper_bound = mesh_size * max_input_spread,
    eta_star = eta_result$eta_star,
    eta_star_alpha = eta_result$eta_star_alpha,
    eta_star_relation = eta_result$eta_star_relation,
    model_version = "0.3.0-rc.3",
    comparison_data = .acfbwm_comparison_table(validated, comparison_data),
    best_worst_adjustment = validated$best_worst_adjustment,
    best_criterion = validated$best_criterion,
    worst_criterion = validated$worst_criterion,
    diagnostics = epsilon_result$diagnostics,
    parameters = list(
      best = best, worst = worst, input_tolerance = input_tolerance,
      denominator_lower_bound = denominator_lower_bound,
      tolerance = tolerance,
      epsilon_upper_start = epsilon_upper_start,
      epsilon_upper_max = epsilon_upper_max,
      epsilon_margin = epsilon_margin
    ),
    solver = "HiGHS",
    solver_version = as.character(utils::packageVersion("highs")),
    solver_status = epsilon_result$solver_status,
    solver_status_message = epsilon_result$solver_status_message,
    solver_strategy = epsilon_result$solver_strategy,
    solver_diagnostics = list(
      epsilon_search = epsilon_result$solver_trace,
      interval_bounds = bounds_result$solver_trace,
      continuous_alpha_deviations = eta_result$deviations
    ),
    input_original = validated$original_data,
    input = validated$data
  )
  class(result) <- c("acfbwm_result", "list")
  result
}

.acfbwm_comparison_table <- function(validated, comparison_data) {
  do.call(rbind, lapply(c("best_to_others", "others_to_worst"), function(vector) {
    is_best <- identical(vector, "best_to_others")
    prefix <- if (is_best) "best" else "worst"
    data.frame(vector = vector, criterion = validated$criteria,
      lower = comparison_data[[paste0(prefix,"_lower")]],
      modal = comparison_data[[paste0(prefix,"_modal")]],
      upper = comparison_data[[paste0(prefix,"_upper")]],
      role = ifelse(seq_len(validated$n_criteria) ==
        (if (is_best) validated$best_index else validated$worst_index), "self",
        ifelse(seq_len(validated$n_criteria) ==
          (if (is_best) validated$worst_index else validated$best_index),
          "direct_best_to_worst", "ordinary")),
      stringsAsFactors = FALSE)
  }))
}

.prepare_acfbwm_comparisons <- function(validated) {
  d <- validated$data
  list(best_lower = d$best_to_others_lower,
       best_modal = d$best_to_others_modal,
       best_upper = d$best_to_others_upper,
       worst_lower = d$others_to_worst_lower,
       worst_modal = d$others_to_worst_modal,
       worst_upper = d$others_to_worst_upper,
       intermediate = setdiff(seq_len(validated$n_criteria),
                              c(validated$best_index, validated$worst_index)))
}

.maximize_acfbwm_ratio_error <- function(
    numerator_intercept,
    numerator_slope,
    denominator_intercept,
    denominator_slope,
    target_intercept,
    target_slope
) {
  if (
    denominator_intercept <= 0 ||
      denominator_intercept + denominator_slope <= 0
  ) {
    stop(
      "Cannot evaluate the continuous-alpha deviation because a denominator is non-positive ",
      "on the alpha interval.",
      call. = FALSE
    )
  }

  candidates <- c(0, 1)
  derivative_constant <-
    numerator_slope * denominator_intercept -
    numerator_intercept * denominator_slope

  if (abs(target_slope) > .Machine$double.eps) {
    squared_denominator <- derivative_constant / target_slope
    if (is.finite(squared_denominator) && squared_denominator >= 0) {
      stationary_denominators <- c(
        sqrt(squared_denominator),
        -sqrt(squared_denominator)
      )
      if (abs(denominator_slope) > .Machine$double.eps) {
        stationary_alpha <-
          (stationary_denominators - denominator_intercept) /
          denominator_slope
        stationary_alpha <- stationary_alpha[
          is.finite(stationary_alpha) &
            stationary_alpha > 0 &
            stationary_alpha < 1
        ]
        candidates <- c(candidates, stationary_alpha)
      }
    }
  }

  candidates <- unique(candidates)
  errors <- abs(
    (numerator_intercept + numerator_slope * candidates) /
      (denominator_intercept + denominator_slope * candidates) -
      (target_intercept + target_slope * candidates)
  )
  maximum_index <- which.max(errors)

  list(
    error = errors[maximum_index],
    alpha = candidates[maximum_index]
  )
}

.compute_acfbwm_eta_diagnostics <- function(
    validated,
    comparison_data,
    representative_weights
) {
  best_index <- validated$best_index
  worst_index <- validated$worst_index
  intermediate <- comparison_data$intermediate

  fuzzy_lower <- representative_weights$fuzzy_lower
  fuzzy_modal <- representative_weights$fuzzy_modal
  fuzzy_upper <- representative_weights$fuzzy_upper

  lower_line <- function(j) {
    c(
      intercept = fuzzy_lower[j],
      slope = fuzzy_modal[j] - fuzzy_lower[j]
    )
  }
  upper_line <- function(j) {
    c(
      intercept = fuzzy_upper[j],
      slope = fuzzy_modal[j] - fuzzy_upper[j]
    )
  }
  target_lower_line <- function(lower, modal) {
    c(intercept = lower, slope = modal - lower)
  }
  target_upper_line <- function(modal, upper) {
    c(intercept = upper, slope = modal - upper)
  }

  deviations <- list()
  add_deviation <- function(relation, numerator, denominator, target) {
    maximum <- .maximize_acfbwm_ratio_error(
      numerator_intercept = numerator[["intercept"]],
      numerator_slope = numerator[["slope"]],
      denominator_intercept = denominator[["intercept"]],
      denominator_slope = denominator[["slope"]],
      target_intercept = target[["intercept"]],
      target_slope = target[["slope"]]
    )
    deviations[[length(deviations) + 1L]] <<- data.frame(
      relation = relation,
      alpha = maximum$alpha,
      absolute_error = maximum$error,
      stringsAsFactors = FALSE
    )
  }

  for (j in intermediate) {
    add_deviation(
      sprintf(
        "w_%s_l / w_%s_u",
        validated$criteria[best_index],
        validated$criteria[j]
      ),
      lower_line(best_index),
      upper_line(j),
      target_lower_line(
        comparison_data$best_lower[j],
        comparison_data$best_modal[j]
      )
    )
    add_deviation(
      sprintf(
        "w_%s_u / w_%s_l",
        validated$criteria[best_index],
        validated$criteria[j]
      ),
      upper_line(best_index),
      lower_line(j),
      target_upper_line(
        comparison_data$best_modal[j],
        comparison_data$best_upper[j]
      )
    )
    add_deviation(
      sprintf(
        "w_%s_l / w_%s_u",
        validated$criteria[j],
        validated$criteria[worst_index]
      ),
      lower_line(j),
      upper_line(worst_index),
      target_lower_line(
        comparison_data$worst_lower[j],
        comparison_data$worst_modal[j]
      )
    )
    add_deviation(
      sprintf(
        "w_%s_u / w_%s_l",
        validated$criteria[j],
        validated$criteria[worst_index]
      ),
      upper_line(j),
      lower_line(worst_index),
      target_upper_line(
        comparison_data$worst_modal[j],
        comparison_data$worst_upper[j]
      )
    )
  }

  add_deviation(
    sprintf(
      "w_%s_l / w_%s_u",
      validated$criteria[best_index],
      validated$criteria[worst_index]
    ),
    lower_line(best_index),
    upper_line(worst_index),
    target_lower_line(
      comparison_data$best_lower[worst_index],
      comparison_data$best_modal[worst_index]
    )
  )
  add_deviation(
    sprintf(
      "w_%s_u / w_%s_l",
      validated$criteria[best_index],
      validated$criteria[worst_index]
    ),
    upper_line(best_index),
    lower_line(worst_index),
    target_upper_line(
      comparison_data$best_modal[worst_index],
      comparison_data$best_upper[worst_index]
    )
  )

  deviations <- do.call(rbind, deviations)
  maximum_index <- which.max(deviations$absolute_error)
  eta_star <- deviations$absolute_error[maximum_index]
  eta_star_alpha <- deviations$alpha[maximum_index]
  eta_star_relation <- deviations$relation[maximum_index]

  list(
    eta_star = eta_star,
    eta_star_alpha = eta_star_alpha,
    eta_star_relation = eta_star_relation,
    deviations = deviations
  )
}

.build_acfbwm_constraints <- function(
    epsilon,
    validated,
    comparison_data,
    alpha_levels,
    denominator_lower_bound
) {
  n <- validated$n_criteria
  best_index <- validated$best_index
  worst_index <- validated$worst_index
  intermediate <- comparison_data$intermediate
  n_variables <- 3L * n

  lower_index <- function(j) j
  modal_index <- function(j) n + j
  upper_index <- function(j) 2L * n + j
  zero_row <- function() numeric(n_variables)

  lower_alpha_coefficients <- function(j, alpha) {
    coefficients <- zero_row()
    coefficients[lower_index(j)] <- 1 - alpha
    coefficients[modal_index(j)] <- alpha
    coefficients
  }
  upper_alpha_coefficients <- function(j, alpha) {
    coefficients <- zero_row()
    coefficients[modal_index(j)] <- alpha
    coefficients[upper_index(j)] <- 1 - alpha
    coefficients
  }

  rows <- list()
  directions <- character(0)
  rhs <- numeric(0)

  add_constraint <- function(coefficients, direction, value) {
    rows[[length(rows) + 1L]] <<- coefficients
    directions <<- c(directions, direction)
    rhs <<- c(rhs, value)
  }
  add_ratio_constraints <- function(
      numerator,
      denominator,
      target,
      epsilon
  ) {
    add_constraint(numerator - (target + epsilon) * denominator, "<=", 0)
    add_constraint(-numerator + (target - epsilon) * denominator, "<=", 0)
  }

  # Triangular fuzzy weights: 0 <= w_l <= w_m <= w_u.
  for (j in seq_len(n)) {
    coefficients <- zero_row()
    coefficients[lower_index(j)] <- 1
    coefficients[modal_index(j)] <- -1
    add_constraint(coefficients, "<=", 0)

    coefficients <- zero_row()
    coefficients[modal_index(j)] <- 1
    coefficients[upper_index(j)] <- -1
    add_constraint(coefficients, "<=", 0)
  }

  # Denominators must be strictly positive.
  denominator_indices <- unique(c(intermediate, worst_index))
  for (j in denominator_indices) {
    coefficients <- zero_row()
    coefficients[lower_index(j)] <- 1
    add_constraint(coefficients, ">=", denominator_lower_bound)
  }

  # Bounds implied by the GMIR normalization are included explicitly for
  # numerical stability: w_l <= 6, w_m <= 1.5, and w_u <= 6.
  for (j in seq_len(n)) {
    coefficients <- zero_row()
    coefficients[lower_index(j)] <- 1
    add_constraint(coefficients, "<=", 6)

    coefficients <- zero_row()
    coefficients[modal_index(j)] <- 1
    add_constraint(coefficients, "<=", 1.5)

    coefficients <- zero_row()
    coefficients[upper_index(j)] <- 1
    add_constraint(coefficients, "<=", 6)
  }

  # GMIR normalization: sum_j (w_l + 4*w_m + w_u) / 6 = 1.
  coefficients <- zero_row()
  for (j in seq_len(n)) {
    coefficients[lower_index(j)] <- 1 / 6
    coefficients[modal_index(j)] <- 4 / 6
    coefficients[upper_index(j)] <- 1 / 6
  }
  add_constraint(coefficients, "=", 1)

  lower_target <- function(lower, modal, alpha) {
    lower + alpha * (modal - lower)
  }
  upper_target <- function(modal, upper, alpha) {
    upper - alpha * (upper - modal)
  }

  for (alpha in alpha_levels) {
    for (j in intermediate) {
      add_ratio_constraints(
        lower_alpha_coefficients(best_index, alpha),
        upper_alpha_coefficients(j, alpha),
        lower_target(
          comparison_data$best_lower[j],
          comparison_data$best_modal[j],
          alpha
        ),
        epsilon
      )
      add_ratio_constraints(
        upper_alpha_coefficients(best_index, alpha),
        lower_alpha_coefficients(j, alpha),
        upper_target(
          comparison_data$best_modal[j],
          comparison_data$best_upper[j],
          alpha
        ),
        epsilon
      )
      add_ratio_constraints(
        lower_alpha_coefficients(j, alpha),
        upper_alpha_coefficients(worst_index, alpha),
        lower_target(
          comparison_data$worst_lower[j],
          comparison_data$worst_modal[j],
          alpha
        ),
        epsilon
      )
      add_ratio_constraints(
        upper_alpha_coefficients(j, alpha),
        lower_alpha_coefficients(worst_index, alpha),
        upper_target(
          comparison_data$worst_modal[j],
          comparison_data$worst_upper[j],
          alpha
        ),
        epsilon
      )
    }

    add_ratio_constraints(
      lower_alpha_coefficients(best_index, alpha),
      upper_alpha_coefficients(worst_index, alpha),
      lower_target(
        comparison_data$best_lower[worst_index],
        comparison_data$best_modal[worst_index],
        alpha
      ),
      epsilon
    )
    add_ratio_constraints(
      upper_alpha_coefficients(best_index, alpha),
      lower_alpha_coefficients(worst_index, alpha),
      upper_target(
        comparison_data$best_modal[worst_index],
        comparison_data$best_upper[worst_index],
        alpha
      ),
      epsilon
    )
  }

  list(
    matrix = do.call(rbind, rows),
    direction = directions,
    rhs = rhs,
    n_variables = n_variables,
    lower_index = lower_index,
    modal_index = modal_index,
    upper_index = upper_index
  )
}

# Equivalent LP representation for a numerical retry. Move singleton rows to
# variable bounds, remove exact duplicate rows, and scale each remaining row
# by a positive factor. No epsilon, margin, or solver tolerance is enlarged.
.compact_acfbwm_lp <- function(lp_data) {
  compact <- lp_data
  A <- lp_data$matrix
  lo <- rep(0, lp_data$n_variables)
  up <- rep(Inf, lp_data$n_variables)
  singleton <- rowSums(A != 0) == 1L
  for (i in which(singleton)) {
    j <- which(A[i, ] != 0)
    a <- A[i, j]
    value <- lp_data$rhs[i] / a
    direction <- lp_data$direction[i]
    if (direction == "=") {
      lo[j] <- max(lo[j], value)
      up[j] <- min(up[j], value)
    } else if ((direction == "<=" && a > 0) ||
               (direction == ">=" && a < 0)) {
      up[j] <- min(up[j], value)
    } else {
      lo[j] <- max(lo[j], value)
    }
  }
  keep <- which(!singleton)
  compact$matrix <- A[keep, , drop = FALSE]
  compact$direction <- lp_data$direction[keep]
  compact$rhs <- lp_data$rhs[keep]
  unique_rows <- !duplicated(data.frame(compact$matrix,
    direction = compact$direction, rhs = compact$rhs, check.names = FALSE))
  compact$matrix <- compact$matrix[unique_rows, , drop = FALSE]
  compact$direction <- compact$direction[unique_rows]
  compact$rhs <- compact$rhs[unique_rows]
  scale <- apply(abs(compact$matrix), 1L, max)
  scale[scale == 0] <- 1
  compact$matrix <- compact$matrix / scale
  compact$rhs <- compact$rhs / scale
  compact$variable_lower <- lo
  compact$variable_upper <- up
  compact
}

.acfbwm_lp_residual <- function(lp_data, solution) {
  if (length(solution) != lp_data$n_variables || any(!is.finite(solution))) {
    return(Inf)
  }
  delta <- as.vector(lp_data$matrix %*% solution) - lp_data$rhs
  violation <- ifelse(lp_data$direction == "=", abs(delta),
    ifelse(lp_data$direction == "<=", pmax(delta, 0), pmax(-delta, 0)))
  max(0, violation, -solution)
}

.solve_acfbwm_highs_lp <- function(lp_data, objective, direction = "min") {
  first <- .solve_acfbwm_highs_raw(lp_data, objective, direction)
  if (first$optimal &&
      .acfbwm_lp_residual(lp_data, first$solution) <= 1e-8) return(first)

  compact <- .compact_acfbwm_lp(lp_data)
  # Positive objective scaling preserves minimizers and maximizers.
  objective_scale <- max(abs(objective))
  if (objective_scale == 0) objective_scale <- 1
  retry <- .solve_acfbwm_highs_raw(compact, objective / objective_scale, direction)
  retry$strategy <- paste0("compact_", retry$strategy)
  retry$attempts$strategy <- paste0("compact_", retry$attempts$strategy)
  retry$attempts <- rbind(first$attempts, retry$attempts)
  if (retry$optimal) {
    residual <- .acfbwm_lp_residual(lp_data, retry$solution)
    if (residual > 1e-8) {
      retry$optimal <- FALSE
      retry$infeasible <- FALSE
      retry$status_message <- paste("Original LP residual exceeds 1e-8:", residual)
      retry$attempts$status_message[nrow(retry$attempts)] <- retry$status_message
    } else {
      retry$objective_value <- sum(objective * retry$solution)
    }
  }
  retry
}

.solve_acfbwm_highs_raw <- function(lp_data, objective, direction = "min") {
  direction <- match.arg(direction, c("min", "max"))
  if (length(objective) != lp_data$n_variables) {
    stop(
      "The HiGHS objective length does not match the ACFBWM model.",
      call. = FALSE
    )
  }

  permitted_directions <- c("<=", ">=", "=")
  if (any(!lp_data$direction %in% permitted_directions)) {
    stop(
      "The ACFBWM model contains an unsupported constraint direction.",
      call. = FALSE
    )
  }

  lhs <- rep(-Inf, length(lp_data$rhs))
  rhs <- rep(Inf, length(lp_data$rhs))
  less_equal <- lp_data$direction == "<="
  greater_equal <- lp_data$direction == ">="
  equal <- lp_data$direction == "="

  rhs[less_equal] <- lp_data$rhs[less_equal]
  lhs[greater_equal] <- lp_data$rhs[greater_equal]
  lhs[equal] <- lp_data$rhs[equal]
  rhs[equal] <- lp_data$rhs[equal]

  strategies <- list(
    list(
      name = "default",
      control = highs::highs_control(
        threads = 1L,
        log_to_console = FALSE,
        primal_feasibility_tolerance = 1e-9,
        dual_feasibility_tolerance = 1e-9
      )
    ),
    list(
      name = "simplex_presolve_on",
      control = highs::highs_control(
        threads = 1L,
        log_to_console = FALSE,
        solver = "simplex",
        presolve = "on",
        primal_feasibility_tolerance = 1e-9,
        dual_feasibility_tolerance = 1e-9
      )
    ),
    list(
      name = "simplex_presolve_off",
      control = highs::highs_control(
        threads = 1L,
        log_to_console = FALSE,
        solver = "simplex",
        presolve = "off",
        primal_feasibility_tolerance = 1e-9,
        dual_feasibility_tolerance = 1e-9
      )
    ),
    list(
      name = "ipm_presolve_on",
      control = highs::highs_control(
        threads = 1L,
        log_to_console = FALSE,
        solver = "ipm",
        presolve = "on",
        primal_feasibility_tolerance = 1e-9,
        dual_feasibility_tolerance = 1e-9
      )
    )
  )

  attempts <- list()
  last_result <- NULL

  for (strategy in strategies) {
    model <- tryCatch(
      highs::highs_solve(
        L = objective,
        lower = if (is.null(lp_data$variable_lower)) rep(0, lp_data$n_variables) else lp_data$variable_lower,
        upper = if (is.null(lp_data$variable_upper)) rep(Inf, lp_data$n_variables) else lp_data$variable_upper,
        A = lp_data$matrix,
        lhs = lhs,
        rhs = rhs,
        types = rep("C", lp_data$n_variables),
        maximum = identical(direction, "max"),
        control = strategy$control
      ),
      error = function(error) error
    )

    if (inherits(model, "error")) {
      attempts[[length(attempts) + 1L]] <- data.frame(
        strategy = strategy$name,
        status = NA_integer_,
        status_message = conditionMessage(model),
        stringsAsFactors = FALSE
      )
      next
    }

    status_message <- paste(
      as.character(model$status_message),
      collapse = " "
    )
    if (!nzchar(status_message)) {
      status_message <- paste("HiGHS status code", as.integer(model$status))
    }
    normalized_status <- tolower(trimws(status_message))
    optimal <- identical(normalized_status, "optimal")
    infeasible <- identical(normalized_status, "infeasible")

    attempts[[length(attempts) + 1L]] <- data.frame(
      strategy = strategy$name,
      status = as.integer(model$status),
      status_message = status_message,
      stringsAsFactors = FALSE
    )
    last_result <- list(
      optimal = optimal,
      infeasible = infeasible,
      status = as.integer(model$status),
      status_message = status_message,
      strategy = strategy$name,
      objective_value = if (optimal) model$objective_value else NA_real_,
      solution = if (optimal) model$primal_solution else NULL
    )

    # Optimal and infeasible are decisive states. Retry only indeterminate
    # states such as Unknown, solver errors, or ambiguous status messages.
    if (optimal || infeasible) {
      last_result$attempts <- do.call(rbind, attempts)
      row.names(last_result$attempts) <- NULL
      return(last_result)
    }
  }

  if (is.null(last_result)) {
    last_result <- list(
      optimal = FALSE,
      infeasible = FALSE,
      status = NA_integer_,
      status_message = "All HiGHS attempts ended with R errors.",
      strategy = NA_character_,
      objective_value = NA_real_,
      solution = NULL
    )
  }
  last_result$attempts <- do.call(rbind, attempts)
  row.names(last_result$attempts) <- NULL
  last_result
}

.solve_acfbwm_epsilon <- function(
    validated,
    comparison_data,
    alpha_levels,
    denominator_lower_bound,
    tolerance,
    epsilon_upper_start,
    epsilon_upper_max
) {
  solver_trace <- list()

  solve_for_epsilon <- function(epsilon) {
    lp_data <- .build_acfbwm_constraints(
      epsilon = epsilon,
      validated = validated,
      comparison_data = comparison_data,
      alpha_levels = alpha_levels,
      denominator_lower_bound = denominator_lower_bound
    )
    model <- .solve_acfbwm_highs_lp(
      lp_data = lp_data,
      objective = numeric(lp_data$n_variables),
      direction = "min"
    )
    attempt_trace <- model$attempts
    attempt_trace$epsilon <- epsilon
    classification <- if (model$optimal) {
      "feasible"
    } else if (model$infeasible) {
      "infeasible"
    } else {
      "not_certified"
    }
    attempt_trace$classification <- classification
    solver_trace[[length(solver_trace) + 1L]] <<- attempt_trace[
      , c(
        "epsilon", "classification", "strategy", "status",
        "status_message"
      )
    ]
    list(
      feasible = model$optimal,
      classification = classification,
      status = model$status,
      status_message = model$status_message,
      strategy = model$strategy,
      solution = model$solution
    )
  }

  lower <- 0
  upper <- epsilon_upper_start
  upper_solution <- solve_for_epsilon(upper)

  while (!upper_solution$feasible && upper < epsilon_upper_max) {
    upper <- min(2 * upper, epsilon_upper_max)
    upper_solution <- solve_for_epsilon(upper)
  }
  if (!upper_solution$feasible) {
    stop(
      "No feasible ACFBWM solution was found up to epsilon = ",
      epsilon_upper_max,
      ". Check the input and numerical parameters.",
      call. = FALSE
    )
  }

  search <- .acfbwm_search_bracket(solve_for_epsilon, lower, upper,
                                    upper_solution, tolerance)
  lower <- search$lower
  upper <- search$upper
  best_solution <- search$solution

  n <- validated$n_criteria
  solution <- best_solution$solution
  fuzzy_lower <- solution[seq_len(n)]
  fuzzy_modal <- solution[n + seq_len(n)]
  fuzzy_upper <- solution[2L * n + seq_len(n)]
  defuzzified <- (fuzzy_lower + 4 * fuzzy_modal + fuzzy_upper) / 6

  representative_weights <- data.frame(
    criterion = validated$criteria,
    fuzzy_lower = fuzzy_lower,
    fuzzy_modal = fuzzy_modal,
    fuzzy_upper = fuzzy_upper,
    representative_defuzzified = defuzzified,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  diagnostics <- .acfbwm_diagnostics(
    validated = validated,
    comparison_data = comparison_data,
    alpha_levels = alpha_levels,
    fuzzy_lower = fuzzy_lower,
    fuzzy_modal = fuzzy_modal,
    fuzzy_upper = fuzzy_upper,
    epsilon = upper,
    tolerance = tolerance
  )

  # A solver may accept a solution with a small linear feasibility residual.
  # Division by a small fuzzy-weight component can magnify that residual in
  # the original ratio scale. Certify a feasible epsilon directly from the
  # ratios of the returned representative solution before computing bounds.
  bisection_upper <- upper
  certified_epsilon <- max(
    bisection_upper,
    diagnostics$absolute_error,
    na.rm = TRUE
  )
  certification_adjustment <- certified_epsilon - bisection_upper
  search_gap <- certified_epsilon - lower
  tolerance_met <- search_gap <= tolerance
  search_status <- if (tolerance_met) "tolerance_met" else if (
    upper - lower <= tolerance) "ratio_certification_adjustment" else search$status
  if (!tolerance_met) {
    warning(sprintf(paste0("Epsilon tolerance not achieved: lower = %.15g, ",
      "feasible upper = %.15g, gap = %.6g (requested %.6g). ",
      "Weights use the feasible upper bound; inspect epsilon_search.csv."),
      lower, certified_epsilon, search_gap, tolerance), call. = FALSE)
  }

  diagnostics$epsilon <- certified_epsilon
  diagnostics$satisfied <-
    diagnostics$absolute_error <= certified_epsilon + 10 * tolerance

  solver_trace <- do.call(rbind, solver_trace)
  indeterminate_epsilon_values <- unique(
    solver_trace$epsilon[solver_trace$classification == "not_certified"]
  )

  list(
    epsilon = certified_epsilon,
    epsilon_bisection_upper = bisection_upper,
    epsilon_lower_bound = lower,
    epsilon_search_gap = search_gap,
    epsilon_tolerance_met = tolerance_met,
    epsilon_search_status = search_status,
    epsilon_certification_adjustment = certification_adjustment,
    representative_weights = representative_weights,
    diagnostics = diagnostics,
    solver_status = best_solution$status,
    solver_status_message = best_solution$status_message,
    solver_strategy = best_solution$strategy,
    indeterminate_epsilon_values = indeterminate_epsilon_values,
    solver_trace = solver_trace
  )
}

.acfbwm_diagnostics <- function(
    validated,
    comparison_data,
    alpha_levels,
    fuzzy_lower,
    fuzzy_modal,
    fuzzy_upper,
    epsilon,
    tolerance
) {
  best_index <- validated$best_index
  worst_index <- validated$worst_index
  intermediate <- comparison_data$intermediate

  lower_weight <- function(j, alpha) {
    (1 - alpha) * fuzzy_lower[j] + alpha * fuzzy_modal[j]
  }
  upper_weight <- function(j, alpha) {
    alpha * fuzzy_modal[j] + (1 - alpha) * fuzzy_upper[j]
  }
  lower_target <- function(lower, modal, alpha) {
    lower + alpha * (modal - lower)
  }
  upper_target <- function(modal, upper, alpha) {
    upper - alpha * (upper - modal)
  }

  diagnostics <- list()
  add_diagnostic <- function(alpha, relation, ratio, target) {
    diagnostics[[length(diagnostics) + 1L]] <<- data.frame(
      alpha = alpha,
      relation = relation,
      ratio = ratio,
      target = target,
      absolute_error = abs(ratio - target),
      stringsAsFactors = FALSE
    )
  }

  for (alpha in alpha_levels) {
    for (j in intermediate) {
      add_diagnostic(
        alpha,
        sprintf("w_%s_l / w_%s_u", validated$criteria[best_index], validated$criteria[j]),
        lower_weight(best_index, alpha) / upper_weight(j, alpha),
        lower_target(
          comparison_data$best_lower[j],
          comparison_data$best_modal[j],
          alpha
        )
      )
      add_diagnostic(
        alpha,
        sprintf("w_%s_u / w_%s_l", validated$criteria[best_index], validated$criteria[j]),
        upper_weight(best_index, alpha) / lower_weight(j, alpha),
        upper_target(
          comparison_data$best_modal[j],
          comparison_data$best_upper[j],
          alpha
        )
      )
      add_diagnostic(
        alpha,
        sprintf("w_%s_l / w_%s_u", validated$criteria[j], validated$criteria[worst_index]),
        lower_weight(j, alpha) / upper_weight(worst_index, alpha),
        lower_target(
          comparison_data$worst_lower[j],
          comparison_data$worst_modal[j],
          alpha
        )
      )
      add_diagnostic(
        alpha,
        sprintf("w_%s_u / w_%s_l", validated$criteria[j], validated$criteria[worst_index]),
        upper_weight(j, alpha) / lower_weight(worst_index, alpha),
        upper_target(
          comparison_data$worst_modal[j],
          comparison_data$worst_upper[j],
          alpha
        )
      )
    }

    add_diagnostic(
      alpha,
      sprintf(
        "w_%s_l / w_%s_u",
        validated$criteria[best_index],
        validated$criteria[worst_index]
      ),
      lower_weight(best_index, alpha) / upper_weight(worst_index, alpha),
      lower_target(
        comparison_data$best_lower[worst_index],
        comparison_data$best_modal[worst_index],
        alpha
      )
    )
    add_diagnostic(
      alpha,
      sprintf(
        "w_%s_u / w_%s_l",
        validated$criteria[best_index],
        validated$criteria[worst_index]
      ),
      upper_weight(best_index, alpha) / lower_weight(worst_index, alpha),
      upper_target(
        comparison_data$best_modal[worst_index],
        comparison_data$best_upper[worst_index],
        alpha
      )
    )
  }

  diagnostics <- do.call(rbind, diagnostics)
  diagnostics$epsilon <- epsilon
  diagnostics$satisfied <-
    diagnostics$absolute_error <= epsilon + 10 * tolerance
  row.names(diagnostics) <- NULL
  diagnostics
}

.compute_acfbwm_bounds <- function(
    epsilon,
    validated,
    comparison_data,
    alpha_levels,
    denominator_lower_bound,
    epsilon_margin
) {
  epsilon_used <- epsilon + epsilon_margin
  lp_data <- .build_acfbwm_constraints(
    epsilon = epsilon_used,
    validated = validated,
    comparison_data = comparison_data,
    alpha_levels = alpha_levels,
    denominator_lower_bound = denominator_lower_bound
  )

  n <- validated$n_criteria
  lower_bound <- numeric(n)
  upper_bound <- numeric(n)
  solver_trace <- list()

  solve_bound <- function(j, direction) {
    objective <- numeric(lp_data$n_variables)
    objective[lp_data$lower_index(j)] <- 1 / 6
    objective[lp_data$modal_index(j)] <- 4 / 6
    objective[lp_data$upper_index(j)] <- 1 / 6

    model <- .solve_acfbwm_highs_lp(
      lp_data = lp_data,
      objective = objective,
      direction = direction
    )
    attempt_trace <- model$attempts
    attempt_trace$criterion <- validated$criteria[j]
    attempt_trace$bound <- direction
    solver_trace[[length(solver_trace) + 1L]] <<- attempt_trace[
      , c("criterion", "bound", "strategy", "status", "status_message")
    ]
    if (!model$optimal) {
      attempt_summary <- paste(
        paste0(
          model$attempts$strategy,
          "=",
          ifelse(
            is.na(model$attempts$status),
            "R error",
            paste0(
              model$attempts$status,
              " (", model$attempts$status_message, ")"
            )
          )
        ),
        collapse = "; "
      )
      stop(
        "The ", direction, "imization problem for criterion '",
        validated$criteria[j], "' was not solved optimally. ",
        "K = ", length(alpha_levels), "; epsilon_used = ",
        format(epsilon_used, digits = 16), ". HiGHS attempts: ", attempt_summary, ".",
        call. = FALSE
      )
    }
    model$objective_value
  }

  for (j in seq_len(n)) {
    lower_bound[j] <- solve_bound(j, "min")
    upper_bound[j] <- solve_bound(j, "max")
  }

  interval_midpoint <- (lower_bound + upper_bound) / 2
  normalized_weight <- interval_midpoint / sum(interval_midpoint)

  bounds <- data.frame(
    criterion = validated$criteria,
    lower_bound = lower_bound,
    upper_bound = upper_bound,
    interval_midpoint = interval_midpoint,
    normalized_weight = normalized_weight,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  list(
    epsilon_used = epsilon_used,
    bounds = bounds,
    solver_trace = do.call(rbind, solver_trace)
  )
}

# Maintain a bracket supported by solver classifications. Unknown trials never
# move either endpoint. Each trial already invokes the solver fallback chain.
.acfbwm_search_bracket <- function(evaluate, lower, upper, solution,
                                   tolerance, max_iterations = 256L) {
  status <- "iteration_limit"
  for (iteration in seq_len(max_iterations)) {
    if (upper - lower <= tolerance) { status <- "tolerance_met"; break }
    old_lower <- lower
    old_upper <- upper
    midpoint <- lower + (upper - lower) / 2
    # Try the midpoint first; if unresolved, probe on both sides, without
    # treating the unresolved midpoint as a bound.
    candidates <- c(midpoint, lower + (upper-lower)/4,
                     lower + 3*(upper-lower)/4)
    for (i in seq_along(candidates)) {
      point <- candidates[i]
      if (point <= lower || point >= upper) next
      trial <- evaluate(point)
      if (identical(trial$classification, "feasible")) {
        upper <- point
        solution <- trial
      } else if (identical(trial$classification, "infeasible")) {
        lower <- point
      } else if (!identical(trial$classification, "not_certified")) {
        stop("Unexpected epsilon trial classification.", call. = FALSE)
      }
      if (upper - lower <= tolerance ||
          (i == 1L && trial$classification != "not_certified")) break
    }
    if (lower == old_lower && upper == old_upper) {
      status <- "unresolved_trials"; break
    }
  }
  if (upper - lower <= tolerance) status <- "tolerance_met"
  list(lower=lower, upper=upper, solution=solution, status=status)
}
