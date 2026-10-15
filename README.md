# Alpha-cut Fuzzy Best-Worst Method in R

**Release 0.3.0-rc.3 — 13 October 2026.**

Calculate criterion weights from your own positive triangular fuzzy comparisons.
Each comparison is entered as lower (L), modal (M) and upper (U).
Asymmetric, overlapping, shoulder and crisp comparisons are supported.
There is no automatic sharpening and no input/output CI/CR.

## 1. Repository structure

~~~text
R/
  validate_acfbwm_input.R
  solve_acfbwm.R
  export_acfbwm_result.R
scripts/
  example.R
  run_own_data.R
  article.R
data/
  example.csv
  my_input_template.csv
  PSI.csv
  Example1_Ratandhara.csv
  Example2_Ratandhara.csv
tests/
  run_tests.R
output/
  README.md
README.md
LICENSE
CITATION.cff
~~~

- **example.R**: fixed five-criterion installation check using example.csv.
- **run_own_data.R**: the one script to copy for your own analysis.
- **article.R**: PSI and two Ratandhara examples.
- **R/**: implementation; no edits needed for ordinary use.
- **tests/**: regression checks of validation, weights, EA and numerical behavior.
- **output/**: generated results; use separate folders for separate analyses.

example.csv and my_input_template.csv initially contain exactly the same values.
Keep example.csv unchanged. Copy the filled template before editing judgments.

## 2. Install and set the working directory

Install R and, optionally, RStudio. Extract the entire ZIP into a **new folder**.
The working directory must be the folder containing README.md, R/, data/ and
scripts/. Do not use the scripts/ subfolder as the working directory.

In RStudio, use Session > Set Working Directory > Choose Directory, or run:

```r
setwd("I:/your/path/alpha-cut-fbwm-r")
getwd()
file.exists("R/solve_acfbwm.R")
```

Replace the path with your actual folder. Use forward slashes on Windows.
The last command should return TRUE. For example scripts below, relative
paths are interpreted from this root folder.

Install the required solver package once:

```r
install.packages("highs")
packageVersion("highs")
```

No other add-on R package is required. Internet access is needed for installation,
not for an analysis with the package already installed.

## 3. Check the installation

~~~r
source("scripts/example.R")
~~~

The fixed example uses five criteria, C1 best, C5 worst and K = 17.
Expected: optimal status, normalized weights summing to 1,
max_input_spread = 0.4 and ea_upper_bound = 0.025.
Results go to output/example. This tests installation and normal use.

For additional regression checks:

~~~r
source("tests/run_tests.R")
~~~

Successful completion prints "All tests passed for release 0.3.0-rc.3."

## 4. Use your own data: complete workflow

1. Copy data/my_input_template.csv to data/my_input.csv.
2. Copy scripts/run_own_data.R to scripts/run_my_analysis.R.
3. Run the filled example first if desired, then edit your copied CSV.
4. In your copied script, set:

```r
input_path <- "data/my_input.csv"
output_dir <- "output/my_analysis"
best <- "C1"
worst <- "C5"
k <- 17L
```

5. Set best and worst to the exact criterion identifiers in your CSV.
6. Save both files, confirm the working directory, and run:

```r
source("scripts/run_my_analysis.R")
```

The script prints the imported data, validates them, solves the model and
exports results. The supplied CSV is a filled example, not an empty form.
Its modal judgments match the five-criterion Classical BWM teaching example;
Alpha-cut does not apply Classical BWM's input consistency assessment.

### Required CSV columns

```csv
criterion,best_to_others_lower,best_to_others_modal,best_to_others_upper,others_to_worst_lower,others_to_worst_modal,others_to_worst_upper
```

Each row is one criterion. Best-to-Others expresses preference of the best
criterion over the row's criterion. Others-to-Worst expresses preference of
the row's criterion over the worst criterion. Larger values express stronger
preference in that direction.

For example, with C1 best and C3 worst:

```csv
criterion,best_to_others_lower,best_to_others_modal,best_to_others_upper,others_to_worst_lower,others_to_worst_modal,others_to_worst_upper
C1,1,1,1,5.5,6,6.8
C2,1.8,2,2.5,2.6,3,3.7
C3,5.5,6,6.8,1,1,1
```

This example illustrates asymmetric inputs. The direct best-to-worst triple
appears twice and must represent the same comparison.

Use commas as separators and decimal points. For a file saved with semicolons
and decimal commas, change read.csv to read.csv2 in your copied script.
Inspect the printed data; do not solve if columns were imported as text.

### What validation checks

- At least two rows, unique non-empty criterion identifiers and unique columns.
- Six numeric, finite, strictly positive comparison columns, with L <= M <= U.
- Distinct explicitly named best and worst criteria that exist in the data.
- Exactly (1,1,1) for best-to-itself in BO and worst-to-itself in OW.
- Agreement of all three direct best-to-worst components in both vectors.

Decimal values, L = M, M = U and L = M = U are allowed. Other rows may also
contain (1,1,1); this is why best and worst are explicit arguments. Input
values are not restricted to integer modes or the range 1–9. You must justify
the scale and the interpretation of your comparisons for your application.
The code does not establish ordinal or multiplicative consistency.

Direct duplicate agreement uses input_tolerance = 1e-10:
absolute difference <= input_tolerance * max(1, absolute value of either component).
A difference within that tolerance is canonicalized to the BO triple. Both
original and effective inputs are exported, and best_worst_adjustment records
the maximum changed component. Set input_tolerance = 0 for exact agreement.
input_tolerance must lie between 0 and 1e-6; it is not a mechanism for aggregating different judgments.
Self-comparisons and L <= M <= U are checked without this relaxation.

No symmetry or common-width condition is applied. Overlap is not an input
error. A maximum or a best-to-worst comparison is crisp only if its CSV triple
is crisp. Input validation does not assess consistency or acceptability.

### Direct function call

```r
source("R/validate_acfbwm_input.R")
source("R/solve_acfbwm.R")
source("R/export_acfbwm_result.R")
input <- read.csv("data/my_input.csv", stringsAsFactors = FALSE)
result <- solve_acfbwm(input, k = 17, best = "C1", worst = "C5")
report_acfbwm_result(result)
export_acfbwm_result(result, "output/my_analysis")
```

## 5. K, S and the discretization bound

K is the number of alpha levels, including both 0 and 1. It must be an integer
at least 2. The solver uses a uniform grid alpha = 0, 1/(K-1), ..., 1.
A larger K introduces more constraints and generally takes longer.
For nested comparisons, use K = 2, 3, 5, 9, 17, 33, 65, 129.

For every input triple calculate M-L and U-M. Let S be the largest of these
values over both vectors. The outputs are:

- max_input_spread = S
- mesh_size = 1/(K-1)
- ea_upper_bound = S * mesh_size

For S = 0.4 and K = 17 the bound is 0.025. For the original article scale,
S = 1, and the bound is 0.0625. If all comparisons are crisp, S = 0 and
there is no alpha-discretization error; epsilon can still be positive.

EA bounds the difference between the exact finite-grid and continuous-alpha
optimal objective values on the same feasible weight domain. It is **not**
a bound on the error of each weight and not a consistency ratio. Numerical
search/solver errors are separate. A proof for general positive triangular
inputs is given in section 11 below; this is an explicit generalization of
the original scale-specific result.

A desired theoretical bound delta > 0 can be met with
K >= max(2, ceiling(S/delta)+1). This can be expensive for wide inputs.
The public API currently accepts uniform grids only.

## 6. Interpreting all result columns

| Column in weights.csv | Meaning |
|---|---|
| criterion | Input identifier |
| fuzzy_lower, fuzzy_modal, fuzzy_upper | One representative triangular weight returned by the epsilon search |
| representative_defuzzified | GMIR of that representative: (lower + 4*modal + upper)/6 |
| lower_bound | Minimum GMIR weight for this criterion over the bounds model |
| upper_bound | Maximum GMIR weight for this criterion over the bounds model |
| interval_midpoint | (lower_bound + upper_bound)/2 |
| normalized_weight | interval_midpoint divided by the sum of all interval midpoints |
| rank | Descending normalized_weight; ties share the minimum rank |

The representative fuzzy solution may be nonunique and can vary with solver
strategies without changing the optimal intervals materially.
The fuzzy endpoints are not the minimum and maximum GMIR values.
Each criterion's interval endpoints are optimized separately; their endpoint
vectors need not form one jointly feasible weight vector.
Interval midpoints need not sum to 1. Their normalized vector is a reporting
choice and is not asserted to be an optimal triangular solution.
Use normalized_weight for a final normalized weighting vector. Use
interval_midpoint when comparing with the original article's "Average".
Do not interpret normalized_weight as necessarily lying within its unnormalized
GMIR interval. Interval widths are not confidence intervals or probabilities.

## 7. Model diagnostics and numerical settings

| Output | Interpretation |
|---|---|
| epsilon | Grid-fit deviation for the representative solution, certified by evaluating its original ratios; a numerical estimate, not CI/CR |
| epsilon_bisection_upper | Feasible upper endpoint found by the epsilon search |
| epsilon_certification_adjustment | Upward adjustment after checking actual ratios |
| epsilon_used_for_bounds | epsilon + epsilon_margin; all GMIR bounds use this common value |
| eta_star | Maximum absolute ratio deviation of the representative fuzzy weights over continuous alpha in [0,1] |
| eta_star_alpha | An alpha where that maximum occurs |
| eta_star_relation | The corresponding weight ratio |
| max_input_spread, mesh_size, ea_upper_bound | Input spread, grid spacing and theoretical discretization bound |
| best_worst_adjustment | Roundoff-level canonicalization of the duplicated direct input |
| indeterminate_epsilon_values | Search trials whose feasibility was not certified |
| solver_status, solver_status_message, solver_strategy | Status/strategy of the representative epsilon solution |
| solver, solver_version, model_version | Reproducibility identifiers |

eta_star and epsilon describe model fit and approximation; neither provides a
methodologically established acceptance threshold for the judgments.
The continuous-alpha deviation is evaluated at endpoints and applicable
stationary points of each ratio-error function.
There is no input- or output-based CI/CR in this repository.

Default numerical settings:

| Parameter | Default | Purpose |
|---|---:|---|
| input_tolerance | 1e-10 | Agreement of duplicated direct input, not a solver tolerance |
| denominator_lower_bound | 1e-7 | Positive floor on lower weight components used as denominators |
| tolerance | 1e-6 | Epsilon bisection stopping width |
| epsilon_upper_start | 1 | Initial search upper endpoint |
| epsilon_upper_max | 1e6 | Maximum permitted search endpoint |
| epsilon_margin | 1e-6 | Explicit relaxation for interval optimization |

Changing the denominator floor changes the numerical feasible domain.
Changing epsilon_margin can change intervals, particularly close to an optimum.
The implementation retains the rc.3 fallback: if needed, solve an equivalent
LP with singleton constraints represented as variable bounds, duplicate rows
removed and positive row/objective scaling. Epsilon and margins are not
automatically enlarged. Accepted primal solutions are checked against the
original linear constraints at absolute residual tolerance 1e-8.
Indeterminate trials never move the bracket. Check `epsilon_tolerance_met`
and `epsilon_search_gap`; numerical solver classifications are not exact-arithmetic
certificates. See the numerical search update below for the stopping rules.

## 8. Exported files

export_acfbwm_result writes these files to the selected output directory:

| File | Contents |
|---|---|
| input_original.csv | Validated original seven-column input before roundoff canonicalization |
| input.csv | Effective input used for calculation |
| fuzzy_comparisons.csv | Both vectors in long format: criterion, L/M/U, role (self/direct_best_to_worst/ordinary) |
| weights.csv | All weight quantities in input row order |
| ranking.csv | Same quantities sorted by rank |
| model_summary.csv | Version, best/worst, S, K, mesh, EA, deviations, solver information |
| parameters.csv | Explicit best/worst identifiers and all numerical settings |
| alpha_levels.csv | Alpha grid |
| grid_diagnostics.csv | alpha, ratio relation, actual ratio, target, absolute error, epsilon and satisfied flag |
| continuous_alpha_deviations.csv | Maximum continuous deviation and alpha for each ratio relation |
| epsilon_search.csv | Attempted epsilon values, solver strategies/statuses and feasibility classifications |
| interval_solver_trace.csv | Solver attempts for every criterion's minimum and maximum |
| result.rds | Complete R result object |
| sessionInfo.txt | R, platform and package information |

The grid satisfied flag includes a numerical tolerance; it is not an input
consistency assessment. Successful interval calculations require optimal solver
statuses for every bound.

Rerunning overwrites named files within the same model version. Use a fresh
output folder for a different scenario. Directories containing legacy
consistency exports or a result.rds from another model version are rejected;
no old files are automatically deleted.
To reopen a result: saved <- readRDS("output/my_analysis/result.rds").

## 9. Article calculations

~~~r
source("scripts/article.R")
~~~

The settings are at the top of the script:

| Dataset | CSV | Best | Worst | K values | Display decimals |
|---|---|---|---|---|---|
| PSI | PSI.csv | I1 | I9 | 2, 17, 129 | 5 |
| Ratandhara Example 1 | Example1_Ratandhara.csv | c2 | c5 | 2, 17, 129 | 4 |
| Ratandhara Example 2 | Example2_Ratandhara.csv | c2 | c5 | 2, 17, 129 | 4 |

Criterion names are case-sensitive. These settings specify exactly what the
script reproduces. The manuscript must use the same inputs and K settings.
This workflow computes the retained article datasets; it does not claim to
reproduce every table in the earlier AMSE_2026_10_09_v5 draft, which used
different examples/input choices. Historical draft comparisons and development
audits are outside this user repository.

Each dataset/K has a full export folder under output/article. Additional files:

- weights_all.csv: all runs together at full exported precision.
- diagnostics_all.csv: S, K, mesh, EA, epsilon and continuous-alpha diagnostics.
- run_settings.csv: input paths, best/worst, K and presentation precision.
- table_rounded.csv in each run folder: formatted values with trailing zeros,
  including both interval_midpoint and normalized_weight.

Rounding is for presentation only. Do not use rounded tables for subsequent
calculations or replace computed epsilon with a rounded published value.
The original article's Average corresponds to interval_midpoint, not
normalized_weight. Matching every printed Average is not asserted; source
discrepancies were investigated separately.

### Input provenance

**PSI:** modal BO=(1,2,6,5,7,4,8,3,9) and OW=(9,8,4,5,3,6,2,7,1), in I1..I9
order. Ordinary triangles have width +/-0.4, self inputs are (1,1,1), and direct
9 is (9,9,9). These preserve the tested PSI scenario; they are data choices,
not solver rules. display_order is presentation metadata, not an optimization
input. This script calculates indicator weights, not country-level PSI scores.

**Ratandhara examples:** H. M. Ratandhara and M. Kumar (2024), *An alpha-cut
intervals based Fuzzy Best-Worst Method for Multi-Criteria Decision-Making*,
Applied Soft Computing 159, 111625. DOI: 10.1016/j.asoc.2024.111625.
Examples 1 and 2 are in section 5.3 (p.14), with the scale from Table 4 (p.5):
1=(1,1,1), 9=(9,9,9), otherwise m=(m-1,m,m+1).
Example 1 BO=(2,1,4,2,8), OW=(3,8,5,4,1).
Example 2 BO=(3,1,3,2,6), OW=(2,6,6,3,1).
Their direct best-worst comparisons and maxima remain fuzzy.

**Teaching example:** the modal comparisons match the Classical BWM teaching
data: BO=(1,2,3,4,5), OW=(5,4,4,2,1). The explicit triangles are in example.csv.
Classical BWM's consistency assessment is not transferred to Alpha-cut.

## 10. Troubleshooting

- File not found: check getwd(), extraction and relative paths.
- Old three-column input: migrate to six explicit comparison columns; it is not automatically expanded.
- Non-numeric columns: check separators/decimal notation; use read.csv2 when appropriate.
- Invalid triangle: correct positivity or order; the code never sorts your entries.
- Best/worst error: use exact identifiers and distinct criteria.
- Direct mismatch: review both copies of the same comparison; none is silently discarded beyond roundoff tolerance.
- Solver failure: preserve the full error, K, epsilon, inputs and sessionInfo(). Do not increase margins solely to match a publication.
- Different representative fuzzy weights: check interval bounds and parameters before concluding the optimization differs.
- Different article weights: compare the same triangles, K, epsilon policy and output quantity.

This software does not alter or depend on the Classical BWM repository.

## 11. Why the bound is S times the grid spacing

Let every input comparison be (L,M,U), with 0<L<=M<=U. Set
S=max{M-L,U-M} over all input comparisons, and let h be the largest alpha-grid
gap, with both endpoints 0 and 1 included. Uniform K-point grids have h=1/(K-1).

For fixed ordered nonnegative triangular weights, with positive denominators,
each lower-ratio function w_i^L(alpha)/w_j^U(alpha) is nondecreasing,
and each upper-ratio function w_i^U(alpha)/w_j^L(alpha) is nonincreasing.
The corresponding target functions L+alpha(M-L) and U-alpha(U-M) have the
same respective monotonicity and Lipschitz constants at most S.

On a grid interval [a,b], write q for a ratio and t for its target, and let E
be a bound on their absolute errors at both endpoints.
If both are nondecreasing, q(a)<=q(alpha)<=q(b) gives
q(alpha)-t(alpha)<=q(b)-t(b)+t(b)-t(alpha)<=E+S(b-a),
and t(alpha)-q(alpha)<=t(alpha)-t(a)+t(a)-q(a)<=E+S(b-a).
For nonincreasing functions the endpoint roles reverse, giving the same bound.
Thus the continuous maximum error for any such weight vector is at most its
grid maximum error plus S*h. No disjointness, symmetry or common width is used.

Let epsilon_F* and epsilon_C* be the exact grid and continuous minimax values
over the SAME weight domain. Grid constraints are a subset of continuous
constraints, so epsilon_F*<=epsilon_C*. Applying the preceding estimate to a
grid minimizer gives epsilon_C*<=epsilon_F*+S*h. If only an infimum is attained,
apply the estimate to arbitrarily near-minimizers and take the limit.
Therefore 0<=epsilon_C*-epsilon_F*<=S*h.

For a computed representative, the pointwise argument also gives
eta_star<=grid_max_error+S*h, up to numerical evaluation error.
This does not make the computed epsilon an exact optimum. Solver errors,
uncertified feasibility trials, positive denominator floors and the explicit
epsilon_margin used for interval calculations must be reported separately.

The bounds do not quantify errors of individual weights, uncertainty
probabilities, confidence intervals or judgment consistency.
For S=0 the grid and continuous objectives agree for a fixed weight vector;
they need not equal zero.

This is a derivation extending the scale-specific Theorem 1 in
Ratandhara & Kumar (2024), Applied Soft Computing 159, 111625.
It is not quoted as a theorem already stated in that article for arbitrary TFNs.

The computational core is unchanged from the explicit-input release tested by the user in R on 13 October 2026. This release reorganizes scripts, data and documentation; it does not change the optimization model.

## Numerical search update in 0.3.0-rc.3

Unresolved solver trials (`not_certified`) never change either epsilon bracket
endpoint. The search first tries the midpoint, then the quarter points if the
midpoint is unresolved. Existing solver fallback strategies still apply to each
trial. If no point resolves the bracket, or the iteration limit is reached,
the calculation retains the feasible upper bound and warns if the requested
precision was not achieved. No tolerance or epsilon margin is silently increased.

The result, console report, `model_summary.csv`, and article
`diagnostics_all.csv` include:

- `epsilon_lower_bound`: lower bound supported by infeasibility classifications
  (initially zero, since the objective is nonnegative).
- `epsilon_search_gap`: returned feasible epsilon minus that lower bound;
  includes any upward correction from checking the original ratios.
- `epsilon_tolerance_met`: whether this gap is at most the requested `tolerance`.
- `epsilon_search_status`: `tolerance_met`, `unresolved_trials`,
  `iteration_limit`, or `ratio_certification_adjustment`.

These are numerical diagnostics based on solver decisions and tolerances, not
exact-arithmetic certificates. `Optimal` describes a fixed-epsilon LP solve;
it does not by itself certify the outer epsilon search. If
`epsilon_tolerance_met` is FALSE, weights and intervals are still exported at
the feasible epsilon (plus the explicit `epsilon_margin` for interval bounds),
but the requested optimum precision is not established. Inspect the solver
trace before using such results as final manuscript values. The epsilon gap
is not an error bound on weights. This numerical gap is separate from EA.
Historical unresolved trials may remain in the trace even when later trials
achieve the requested precision; their presence alone no longer triggers a warning.

Extract this release into a new directory. Old output/result.rds files are
intentionally not overwritten across release versions. Run
`source("tests/run_tests.R")`, `source("scripts/example.R")`, then
`source("scripts/article.R")` from the new repository root.
