# Run from the repository root. No additional test framework is required.
local({
  source("R/validate_acfbwm_input.R",local=TRUE)
  source("R/solve_acfbwm.R",local=TRUE)
  source("R/export_acfbwm_result.R",local=TRUE)
stopifnot(identical(readLines("data/example.csv"),readLines("data/my_input_template.csv")))
expect_error <- function(expr) {
  caught <- tryCatch({force(expr); FALSE},error=function(e) TRUE)
  stopifnot(caught)
}
x <- read.csv("data/my_input_template.csv",stringsAsFactors=FALSE)
v <- validate_acfbwm_input(x,"C1","C5")
cols <- names(x)[-1]
for (col in cols) {
  for (bad in c(NA_real_,Inf,0,-1)) {
    y <- x; y[[col]][2] <- bad
    expect_error(validate_acfbwm_input(y,"C1","C5"))
  }
  y <- x; y[[col]] <- as.character(y[[col]])
  expect_error(validate_acfbwm_input(y,"C1","C5"))
}
y <- x; y$criterion[2] <- y$criterion[1]
expect_error(validate_acfbwm_input(y,"C1","C5"))
expect_error(validate_acfbwm_input(x,"C1","missing"))
expect_error(validate_acfbwm_input(x,"C1","C1"))
expect_error(validate_acfbwm_input(x[,-2],"C1","C5"))
y <- x; y$best_to_others_lower[2] <- y$best_to_others_modal[2]+.1
expect_error(validate_acfbwm_input(y,"C1","C5"))
y <- x; y$others_to_worst_upper[2] <- y$others_to_worst_modal[2]-.1
expect_error(validate_acfbwm_input(y,"C1","C5"))
y <- x; y$best_to_others_upper[1] <- 1.1
expect_error(validate_acfbwm_input(y,"C1","C5"))
# Test mismatch in every direct component without violating triangle order.
for (col in c("lower","modal","upper")) {
  y <- read.csv("data/Example1_Ratandhara.csv")
  y[[paste0("others_to_worst_",col)]][2] <-
    y[[paste0("others_to_worst_",col)]][2]+.1
  expect_error(validate_acfbwm_input(y,"c2","c5"))
}
a <- data.frame(criterion=c("B","M","W"),
  best_to_others_lower=c(1,1.5,4.5),best_to_others_modal=c(1,2,6),
  best_to_others_upper=c(1,2,7),others_to_worst_lower=c(4.5,2.2,1),
  others_to_worst_modal=c(6,3,1),others_to_worst_upper=c(7,4.7,1))
va <- validate_acfbwm_input(a,"B","W")
f <- .prepare_acfbwm_comparisons(va)
stopifnot(identical(f$best_lower,a$best_to_others_lower),
          f$best_lower[3]==4.5, f$best_modal[3]==6, f$best_upper[3]==7,
          f$best_modal[2]==f$best_upper[2])
# Repeated self-like comparisons are allowed; best/worst are explicit.
y <- x; y[2,2:4] <- 1
validate_acfbwm_input(y,"C1","C5")
# Near-equal duplicate BW values are canonicalized, original retained.
y <- a; y$others_to_worst_modal[1] <- 6+1e-11
vy <- validate_acfbwm_input(y,"B","W")
stopifnot(vy$best_worst_adjustment>0,vy$data$others_to_worst_modal[1]==6,
          vy$original_data$others_to_worst_modal[1]!=6)
expect_error(validate_acfbwm_input(y,"B","W",input_tolerance=0))

check_result <- function(r) {
  stopifnot(inherits(r,"acfbwm_result"),r$model_version=="0.3.1",
    !"input_consistency" %in% names(r),!"scale_supports_disjoint" %in% names(r),
    abs(sum(r$weights$normalized_weight)-1)<1e-8,
    all(is.finite(r$weights$normalized_weight)),
    all(r$weights$lower_bound<=r$weights$upper_bound+1e-9),
    all(r$diagnostics$satisfied),
    abs(r$ea_upper_bound-r$max_input_spread/(r$k-1))<1e-12,
    r$eta_star <= r$epsilon+r$ea_upper_bound+1e-7)
}
crisp <- data.frame(criterion=c("B","M","W"))
for (q in c("lower","modal","upper")) {
  crisp[[paste0("best_to_others_",q)]] <- c(1,2,4)
  crisp[[paste0("others_to_worst_",q)]] <- c(4,2,1)
}
cat("Testing crisp analytic case\n")
r <- solve_acfbwm(crisp,k=2,best="B",worst="W")
check_result(r)
stopifnot(r$epsilon<1e-5,r$ea_upper_bound==0,
          max(abs(r$weights$normalized_weight-c(4,2,1)/7))<1e-5)
cat("Testing explicit five-criterion input and asymmetric input\n")
default_result <- solve_acfbwm(x,k=2,best="C1",worst="C5")
check_result(default_result)
r <- solve_acfbwm(a,k=17,best="B",worst="W")
check_result(r)
stopifnot(abs(r$max_input_spread-1.7)<1e-12,
          abs(r$ea_upper_bound-1.7/16)<1e-12)
# Positive inconsistent crisp input: zero discretization error, nonzero fit.
y <- x
for (prefix in c("best_to_others_","others_to_worst_")) {
  y[[paste0(prefix,"lower")]] <- y[[paste0(prefix,"modal")]]
  y[[paste0(prefix,"upper")]] <- y[[paste0(prefix,"modal")]]
}
r <- solve_acfbwm(y,k=2,best="C1",worst="C5")
check_result(r);stopifnot(r$ea_upper_bound==0,r$epsilon>.1)
for (bad in list(1,2.5,NA_real_,Inf,NULL,"17")) {
  expect_error(solve_acfbwm(x,k=bad,best="C1",worst="C5"))
}
expect_error(solve_acfbwm(x,k=2,best="C1",worst="C5",comparison_width=.4))
# User-confirmed rc.3 reference weights remain invariant after explicit conversion.
input <- read.csv("data/PSI.csv")
r <- solve_acfbwm(input,k=17,best="I1",worst="I9")
check_result(r)
target <- c(.270331153,.200280678,.060541987,.082563717,.042967511,
            .113775004,.036031992,.168299708,.025208250)
stopifnot(max(abs(r$weights$normalized_weight-target))<1e-5)
# Literal article inputs preserve fuzzy maxima, repeated maxima and direct BW.
input <- read.csv("data/Example2_Ratandhara.csv")
v <- validate_acfbwm_input(input,"c2","c5")
f <- .prepare_acfbwm_comparisons(v)
stopifnot(f$best_lower[5]==5,f$best_upper[5]==7,
          f$worst_lower[3]==5,f$worst_upper[3]==7)
for (kk in c(2L,17L)) {
  cat("Testing original article Example 2, K =",kk,"\n")
  r <- solve_acfbwm(input,k=kk,best="c2",worst="c5")
  check_result(r);stopifnot(r$max_input_spread==1)
}
# Exercise compact LP retry formulation on the previously failing C1 problem.
v <- validate_acfbwm_input(x,"C1","C5")
lp <- .build_acfbwm_constraints(default_result$epsilon_used_for_bounds,v,
                               .prepare_acfbwm_comparisons(v),c(0,1),1e-7)
obj <- numeric(lp$n_variables); obj[c(1,6,11)] <- c(1,4,1)/6
fit <- .solve_acfbwm_highs_raw(.compact_acfbwm_lp(lp),obj,"min")
stopifnot(fit$optimal,.acfbwm_lp_residual(lp,fit$solution)<=1e-8,
          abs(fit$objective_value-default_result$weights$lower_bound[1])<1e-7)
out <- tempfile("lmu_export_")
export_acfbwm_result(default_result,out)
stopifnot(file.exists(file.path(out,"input_original.csv")),
          file.exists(file.path(out,"fuzzy_comparisons.csv")),
          !any(grepl("consistency",list.files(out))),
          "max_input_spread" %in% names(read.csv(file.path(out,"model_summary.csv"))))
unlink(out,recursive=TRUE)

  # Deterministic regression: an unresolved midpoint must not become a bound.
  cat("Testing unresolved epsilon trials and bracket accuracy\n")
  trial <- function(x, threshold=0.4) list(
    classification=if (x < threshold) "infeasible" else "feasible",
    feasible=x >= threshold, solution=x)
  evaluate <- function(x) {
    if (x == 0.5) return(list(classification="not_certified",feasible=FALSE))
    trial(x)
  }
  bracket <- .acfbwm_search_bracket(evaluate,0,1,trial(1),1e-6)
  stopifnot(bracket$lower < 0.4, bracket$upper >= 0.4,
            bracket$upper-bracket$lower <= 1e-6,
            bracket$status == "tolerance_met")
  unknown <- function(x) list(classification="not_certified",feasible=FALSE)
  bracket <- .acfbwm_search_bracket(unknown,0,1,trial(1),1e-6)
  stopifnot(bracket$lower == 0, bracket$upper == 1,
            bracket$status == "unresolved_trials")
  # User's recorded narrow unresolved zone must remain inside the bracket.
  zone <- function(x) {
    if (x > 1.04026794433594 && x < 1.04027080535889) return(unknown(x))
    trial(x,1.040269)
  }
  bracket <- .acfbwm_search_bracket(zone,1.04026794433594,
    1.04027080535889,trial(1.04027080535889),1e-6)
  stopifnot(bracket$lower == 1.04026794433594,
            bracket$upper == 1.04027080535889,
            bracket$status == "unresolved_trials")
  stopifnot(all(c("epsilon_lower_bound", "epsilon_search_gap",
    "epsilon_tolerance_met", "epsilon_search_status") %in% names(default_result)))

  cat("All tests passed for release 0.3.1.\n")
})
