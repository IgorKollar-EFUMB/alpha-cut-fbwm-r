# Fixed five-criterion installation example. Do not edit this input or script.
source("R/validate_acfbwm_input.R")
source("R/solve_acfbwm.R")
source("R/export_acfbwm_result.R")
input <- read.csv("data/example.csv",stringsAsFactors=FALSE)
result <- solve_acfbwm(input,k=17,best="C1",worst="C5")
stopifnot(abs(sum(result$weights$normalized_weight)-1)<1e-8,
          abs(result$max_input_spread-.4)<1e-12,
          abs(result$ea_upper_bound-.025)<1e-12,
          all(result$diagnostics$satisfied))
report_acfbwm_result(result)
export_acfbwm_result(result,"output/example")
cat("Example completed: output/example\n")
