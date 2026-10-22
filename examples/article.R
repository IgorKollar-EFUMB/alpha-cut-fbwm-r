# Reproduce computations for the three included article datasets.
# Run from the repository root. Published tables must use these same inputs/K.
# Values are computed at full precision; rounding below is for presentation only.
source("R/validate_acfbwm_input.R")
source("R/solve_acfbwm.R")
source("R/export_acfbwm_result.R")

# Article settings: K is the number of alpha levels including 0 and 1.
jobs <- list(
  list(name="PSI",file="data/PSI.csv",best="I1",worst="I9",
       k=c(2L,17L,129L),digits=5L),
  list(name="Example1_Ratandhara",file="data/Example1_Ratandhara.csv",
       best="c2",worst="c5",k=c(2L,17L,129L),digits=4L),
  list(name="Example2_Ratandhara",file="data/Example2_Ratandhara.csv",
       best="c2",worst="c5",k=c(2L,17L,129L),digits=4L)
)
output_dir <- "output/article"
rows <- list()
diagnostics <- list()
settings <- list()
for (job in jobs) {
  input <- read.csv(job$file,stringsAsFactors=FALSE)
  for (kk in job$k) {
    cat("\n",job$name,": K =",kk,"\n")
    result <- solve_acfbwm(input,k=kk,best=job$best,worst=job$worst)
    export_acfbwm_result(result,
      file.path(output_dir,job$name,paste0("k",kk)))
    # Retain source row order; ranking.csv in each run provides ranked order.
    w <- result$weights
    rows[[length(rows)+1L]] <- data.frame(dataset=job$name,k=kk,
      criterion=w$criterion,lower_bound=w$lower_bound,upper_bound=w$upper_bound,
      interval_midpoint=w$interval_midpoint,normalized_weight=w$normalized_weight,
      weight_percent=w$weight_percent, rank=w$rank)
    # Decimal strings preserve trailing zeros in manuscript-ready tables.
    table <- data.frame(criterion=w$criterion,
      lower_bound=formatC(w$lower_bound,format="f",digits=job$digits),
      upper_bound=formatC(w$upper_bound,format="f",digits=job$digits),
      interval_midpoint=formatC(w$interval_midpoint,format="f",digits=job$digits),
      normalized_weight=formatC(w$normalized_weight,format="f",digits=job$digits),
      weight_percent=formatC(w$weight_percent,format="f",digits=2L), rank=w$rank)
    write.csv(table,file.path(output_dir,job$name,paste0("k",kk),"table_rounded.csv"),
              row.names=FALSE)
    print(table,row.names=FALSE)
    diagnostics[[length(diagnostics)+1L]] <- data.frame(
      dataset=job$name,k=kk,max_input_spread=result$max_input_spread,
      mesh_size=result$mesh_size,ea_upper_bound=result$ea_upper_bound,
      epsilon=result$epsilon,epsilon_used_for_bounds=result$epsilon_used_for_bounds,
      epsilon_lower_bound=result$epsilon_lower_bound,
      epsilon_search_gap=result$epsilon_search_gap,
      epsilon_tolerance_met=result$epsilon_tolerance_met,
      epsilon_search_status=result$epsilon_search_status,
      eta_star=result$eta_star,eta_star_alpha=result$eta_star_alpha,
      eta_star_relation=result$eta_star_relation)
    settings[[length(settings)+1L]] <- data.frame(dataset=job$name,
      input_file=job$file,best=job$best,worst=job$worst,k=kk,
      presentation_digits=job$digits)
  }
}
write.csv(do.call(rbind,rows),file.path(output_dir,"weights_all.csv"),row.names=FALSE)
write.csv(do.call(rbind,diagnostics),file.path(output_dir,"diagnostics_all.csv"),row.names=FALSE)
write.csv(do.call(rbind,settings),file.path(output_dir,"run_settings.csv"),row.names=FALSE)
cat("\nArticle calculations completed: ",output_dir,"\n",
    "Original article Average corresponds to interval_midpoint.\n",
    "normalized_weight is the rescaled vector used for final normalized weights.\n",
    "No rounded published epsilon is substituted for the computed epsilon.\n")
