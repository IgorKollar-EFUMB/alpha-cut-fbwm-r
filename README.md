# Alpha-cut Fuzzy Best-Worst Method (ACFBWM) in R

This project calculates **criterion importance weights** from fuzzy
Best-to-Others and Others-to-Worst judgments. Each judgment is entered as a
positive triangular fuzzy number with lower, modal and upper values.
Use this implementation when comparisons are expressed as fuzzy judgments
rather than single precise intensities.

The method fits weight ratios to the alpha-cut intervals of the input comparisons.
It returns a representative fuzzy solution, intervals of defuzzified weights,
and a normalized weight vector and ranking derived from interval midpoints.
A normalized weight of 0.30 means 30% of the total importance within this
criterion set. It is not a performance score, probability or confidence level.

For an input triangle $\widetilde a=(L,M,U)$, its alpha-cut endpoints are

```math
a^L(\alpha)=L+\alpha(M-L),\qquad
a^U(\alpha)=U-\alpha(U-M),\qquad 0\leq\alpha\leq1.
```

The calculation uses K alpha levels and minimizes the largest discrepancy
between the input endpoints and the corresponding weight ratios. The basic
model and output formulas are explained after the practical workflow.
**This repository does not calculate input- or output-based CI/CR.**

## Quick start

This is a collection of R scripts, not an installable R package. Download the
complete repository, extract it, set its root as the working directory,
install the single required package, and run the prepared example.

```r
setwd("C:/Users/UserName/Documents/alpha-cut-fbwm-r")
install.packages("highs", repos = "https://cloud.r-project.org")
source(file.path("examples", "run_acfbwm_example.R"))
```

Replace the example path with your actual folder. The following sections
explain every step and then show how to analyse your own data.

## Repository structure

| Path | Purpose |
|---|---|
| `R/validate_acfbwm_input.R` | Checks explicit triangular comparisons and best/worst identifiers. |
| `R/solve_acfbwm.R` | Solves the alpha-cut model and calculates weight intervals and diagnostics. |
| `R/export_acfbwm_result.R` | Prints results and exports tables, the result object and environment. |
| `examples/run_acfbwm_example.R` | Fixed five-criterion installation check; do not edit. |
| `examples/run_own_data.R` | Sole recommended script template for custom data; copy before editing. |
| `examples/article.R` | Computes PSI and the two included Ratandhara examples. |
| `data/example.csv` | Fixed five-criterion example input. |
| `data/my_input_template.csv` | Filled, copyable template with exactly the same values as `example.csv`. |
| `data/PSI.csv` | Explicit triangular inputs for the Pension Sustainability Index scenario. |
| `data/Example1_Ratandhara.csv` | Inputs for original article Example 1. |
| `data/Example2_Ratandhara.csv` | Inputs for original article Example 2. |
| `output/` | Generated results; each analysis should have its own subfolder. |
| `tests/run_tests.R` | Input validation, analytical and numerical regression checks. |
| `CITATION.cff` | Software version and author metadata. |
| `LICENSE` | MIT license. |

## 1. Download and extract the repository

1. On the Alpha-cut FBWM repository page, open **Releases** and download the
   required version. If no release is available, use **Code → Download ZIP**.
   Alternatively, use the complete ZIP supplied with this project.
2. Extract the entire archive into a permanent folder. Do not run scripts
   directly inside the ZIP.
3. Check that the root contains `R`, `data`, `examples`, `tests` and `README.md`.

The extracted folder may have a version or `-main` suffix; its name does not
matter. For example, on Windows:

```text
C:\Users\UserName\Documents\alpha-cut-fbwm-r
```

Extract a new release into a new folder. Keep your input files and earlier
outputs; exports from different model versions must not be mixed.

## 2. Install R, RStudio, and the required package

Install R from <https://cran.r-project.org/>. RStudio Desktop is optional;
its editor is helpful for beginners and is available from
<https://posit.co/download/rstudio-desktop/>. R performs the calculations;
RStudio is the user interface.

Open R or RStudio and install `highs`:

```r
install.packages("highs", repos = "https://cloud.r-project.org")
packageVersion("highs")
```

No other add-on package is required. Install it once for the R installation
used by your session. Internet access is needed for installation, not for
subsequent calculations. If asked to create a personal library, accept the
proposed option. No automatic package installation or `renv` activation is required.

The tested environment was **R 4.6.1, highs 1.14.0-2, Windows 11 x64
(build 26300)**. The user's current editor is **RStudio 2026.10.0 Build 233**.
These describe the reported environment, not mandatory minimum versions.
The scripts export `sessionInfo.txt` for reproducibility; this records R and
loaded packages, but normally not the RStudio version.

## 3. Set and verify the working directory

Use the extracted repository root, not its `R`, `data` or `examples` subfolder.
In RStudio you can use **Session → Set Working Directory → Choose Directory**.
Alternatively, replace the path in this code; use forward slashes on Windows:

```r
setwd("C:/Users/UserName/Documents/alpha-cut-fbwm-r")
# macOS/Linux example:
# setwd("/Users/UserName/Documents/alpha-cut-fbwm-r")

getwd()
list.files()
stopifnot(
  file.exists(file.path("R", "validate_acfbwm_input.R")),
  file.exists(file.path("R", "solve_acfbwm.R")),
  file.exists(file.path("R", "export_acfbwm_result.R")),
  file.exists(file.path("data", "example.csv"))
)
```

No error means that these relative paths are available. Set the directory
again in a new session unless your project or editor restores it.

## 4. Run the prepared Alpha-cut FBWM example

```r
source(file.path("examples", "run_acfbwm_example.R"))
```

The script loads the three function files, reads `data/example.csv`, validates
the input, calculates weights with **C1 best, C5 worst, K = 129**, prints the
results and exports them to `output/example`.

The unchanged example should give the following normalized weights up to
numerical rounding:

| Criterion | Average weight | Rank | Weight in % | Lower bound | Upper bound
|---|---:|---:|---:|---:|---:|
| C1 | 0.38509704 | 1 | 38.51 | 0.348377507 | 0.426261831
| C2 | 0.25277285 | 2 | 25.28 | 0.195874562 | 0.312588951
| C3 | 0.19303104 | 3 | 19.30 | 0.173568372 | 0.214721901
| C4 | 0.10454251 | 4 | 10.45 | 0.074003602 | 0.136288173
| C5 | 0.06455656 | 5 | 6.46 | 0.058282303 | 0.071575999

Their sum is 1. In the tested environment, `epsilon` was approximately
1.040271, `epsilon_tolerance_met` was `TRUE`, `max_input_spread` was 0.4,
`mesh_size` was 0.0078125 and `ea_upper_bound` was 0.003125.
The representative fuzzy solution need not be unique; its components can
vary between solver versions without a material change in the weight intervals.

Keep both this script and `data/example.csv` unchanged. They are the fixed
installation check. For custom data, copy only the templates described next.

## 5. Use Alpha-cut FBWM with your own data

### 5.1 Copy the analysis template and prepare your data

Copy `examples/run_own_data.R` to `examples/run_my_analysis.R` using RStudio
**Save As** or your file manager. Copy `data/my_input_template.csv` to
`data/my_acfbwm.csv`. Keep the supplied files unchanged.

The filled CSV template and the reference CSV contain **identical values**.
You can first run the copy unchanged to verify the workflow. Then replace
its criterion identifiers and comparisons with your own complete dataset;
add or remove rows as needed. There is no deliberately altered single value
between these two files.

Select the most important (best) and least important (worst) criteria. These
labels refer to importance, not an alternative's performance. Use one row per
criterion and these exact seven column names:

| Column | Required content |
|---|---|
| `criterion` | Unique, non-empty criterion identifier. |
| `best_to_others_lower` | Lower endpoint of best compared with the current criterion. |
| `best_to_others_modal` | Modal value of that comparison. |
| `best_to_others_upper` | Upper endpoint of that comparison. |
| `others_to_worst_lower` | Lower endpoint of the current criterion compared with worst. |
| `others_to_worst_modal` | Modal value of that comparison. |
| `others_to_worst_upper` | Upper endpoint of that comparison. |

Comparisons of input data reflect experts’ assessments of relative importance within the specific area of indicator analysis; they are not weights assigned to criteria. Each triangular fuzzy number represents a decision-maker’s assessment within the comparison ‘best versus the others’ or ‘the others to the worst’. The resulting normalised weights are obtained by optimising and subsequently normalising the midpoints of the GMIR intervals. Each normalised weight represents the criterion’s share of the overall importance within a specific set of criteria, and the sum of these weights is equal to 1. For example, a normalised weight of 0.30 assigns this criterion 30% of the overall importance within the evaluation of the given set of criteria.

The input template is:

```csv
criterion,best_to_others_lower,best_to_others_modal,best_to_others_upper,others_to_worst_lower,others_to_worst_modal,others_to_worst_upper
C1,1,1,1,5,5,5
C2,1.6,2,2.4,3.6,4,4.4
C3,2.6,3,3.4,3.6,4,4.4
C4,3.6,4,4.4,1.6,2,2.4
C5,5,5,5,1,1,1
```

For C2, `(1.6,2,2.4)` expresses the preference of C1 over C2, and
`(3.6,4,4.4)` expresses C2 over C5. The two direct C1-to-C5 triples both equal
`(5,5,5)`: Best-to-Others (BO) in the C5 row and Others-to-Worst (OW) in the C1 row.
These triples could instead be fuzzy, provided both copies agree.

Lower (L) and Upper (U) delimit the support and M is the modal value of the fuzzy judgment;
they are not statistical confidence limits. These are comparison intensities,
not ranks or weights. The two vectors need not add to a fixed number and Others-to-Worst
must not be generated simply by reversing Best-to-Others. Elicit both from the decision maker.
The solver does not generate a scale or add a width automatically.

The input must satisfy these rules:

1. At least two criteria, with unique non-empty identifiers and unique columns.
2. All six comparison columns numeric, finite and strictly positive, with
   **0 < L <= M <= U** for each triple.
3. Explicit, distinct best and worst identifiers present in the CSV.
4. BO for best-to-itself and OW for worst-to-itself exactly `(1,1,1)`.
5. The complete direct best-to-worst triple agrees in both vectors.

Asymmetric triangles, different widths, `L=M`, `M=U`, fully crisp triples,
and overlapping supports are allowed. Other comparisons can also be
`(1,1,1)`; this is why best/worst must be specified explicitly rather than
inferred from a unique 1. The maximum value need not be crisp. Decimal inputs
are allowed; the interface does not restrict modes to integers or the range
1–9. A scale outside the example scale requires an application-specific justification.
Additional metadata columns are ignored by the optimization.

The direct-duplicate check uses `input_tolerance = 1e-10`:

```math
|a-b|\leq\text{input\_tolerance}\max(1,|a|,|b|)
```

for each component. Roundoff differences within this limit are canonicalized
to the BO triple; the original and effective inputs are both exported.
`best_worst_adjustment` records the largest change. Set `input_tolerance=0`
for exact agreement; permitted values are 0 to 1e-6. This is not judgment
aggregation. Self-comparisons and triangle order have no such relaxation.

In a spreadsheet, use the first row for the column names and subsequent rows
for criteria. Avoid title rows, blank rows, merged cells, units, percent signs
or formulas saved as text. Save as **CSV UTF-8** and inspect the result in a
text editor. Do not rename an XLSX file to CSV.

The example uses comma separators and decimal points. European spreadsheet
settings may use semicolons and decimal commas: in that case replace
`read.csv()` with `read.csv2()` in the copied script. For semicolons but decimal
points use `read.csv(input_path, sep=";", dec=".", stringsAsFactors=FALSE)`.

### 5.2 Edit the input, output and analysis settings

At the beginning of your copied script, set:

```r
input_path <- file.path("data", "my_acfbwm.csv")
output_dir <- file.path("output", "my_acfbwm_analysis")
best <- "C1"
worst <- "C5"
k <- 129L
```

Use the exact, case-sensitive identifiers from your CSV. Change best/worst if
you change the criteria. K is the number of alpha levels, not the number of
criteria. The `L` suffix in `129L` denotes an R integer.

Both paths are relative to the repository root even though the script is in
`examples`. The CSV must exist; the script creates the output directory.
Use a separate output directory for each scenario. Named exports are overwritten
on rerunning the same model version; previous-version results are protected.
The numerical search tolerance remains `1e-6`; no change is needed for ordinary use.

### 5.3 Save and run the copy

```r
source(file.path("examples", "run_my_analysis.R"))
```

Run the complete script after each change. It checks the working directory and
package, prints the imported data, calls the solver (including validation),
prints the results, and exports them. If a run fails, do not interpret an object
left from an earlier successful run as its result.

If an import looks wrong, inspect it before calculating:

```r
my_input <- read.csv(input_path, stringsAsFactors = FALSE)
names(my_input)
str(my_input)
print(my_input)
colSums(is.na(my_input))
```

With the unchanged template, the weights are the same as in section 4.
The current implementation does not calculate the consistency index (CI) or the consistency ratio (CR) for the  $\alpha$ cut – BWM. The methodological aim of our future research is to develop a theoretically grounded framework for assessing consistency, including the formal derivation and validation of appropriate measures of CI and CR, and the investigation of appropriate acceptance thresholds.

For users who prefer calling the functions directly, the same workflow is:

```r
source(file.path("R", "validate_acfbwm_input.R"))
source(file.path("R", "solve_acfbwm.R"))
source(file.path("R", "export_acfbwm_result.R"))
my_input <- read.csv(file.path("data", "my_acfbwm.csv"), stringsAsFactors = FALSE)
result <- solve_acfbwm(my_input, k = 129, best = "C1", worst = "C5")
report_acfbwm_result(result)
export_acfbwm_result(result, file.path("output", "my_acfbwm_analysis"))
```

### 5.4 Alpha-cut FBWM results and interpretation

The output distinguishes between a representative triangular fuzzy weight, an interval of defuzzified weights, and a final normalised weight for each criterion. The interval bounds are obtained by separately minimising and maximising the GMIR value under the model constraints at the common permitted deviation. The final normalised weights are calculated from the interval midpoints, rather than from the defuzzified values of the representative fuzzy solution.

| `Column in weights.csv` | Meaning |
|---|---|
| criterion | Input identifier |
| `fuzzy_lower, fuzzy_modal, fuzzy_upper` | One representative triangular weight returned by the epsilon search |
| `representative_defuzzified` | GMIR of that representative: (lower + 4*modal + upper)/6 |
| `lower_bound` | Minimum GMIR weight for this criterion over the bounds model |
| `upper_bound` | Maximum GMIR weight for this criterion over the bounds model |
| `interval_midpoint` | (lower_bound + upper_bound)/2 |
| `normalized_weight` | interval_midpoint divided by the sum of all interval midpoints |
| `weight_percent` | Final normalized weights expressed in percent with two decimals; largest-remainder allocation preserves a total of 100.00% |
| rank | Descending normalized_weight; ties share the minimum rank |

The representative fuzzy solution may be nonunique and can vary with solver
strategies without changing the optimal intervals materially.
The fuzzy endpoints are not the minimum and maximum GMIR values.
Each criterion's interval endpoints are optimized separately; their endpoint
vectors need not form one jointly feasible weight vector.
Interval midpoints need not sum to 1. Their normalized vector is a reporting
choice and is not asserted to be an optimal triangular solution.

### Percentage weights for practical use

`result$weights$weight_percent` and `result$ranking$weight_percent` contain numeric
percentages with two decimal places, summing to **100.00%**. Divide these values
by 100 if you need rounded proportions summing to one. The original
`normalized_weight` remains available at full precision; `rank` is still based
on that original weight, even when displayed percentages tie.

The largest remainder method allocates 10,000 integer units, each worth 0.01
percentage point. It multiplies the normalized weights by 10,000, takes the
floor of each quota, and assigns the remaining units to the largest fractional
remainders. Equal remainders are resolved by the original input CSV row order.
A temporary normalization absorbs floating-point drift without changing the
stored normalized weights. The integer allocation totals exactly 10,000;
checks of floating-point percentage sums use a small numerical tolerance.
This is presentation rounding, not a change to the ACFBWM optimization,
interval bounds, epsilon search or criterion ranks.

The column is included in console reports, `weights.csv`, `ranking.csv`,
`result.rds`, and the article tables and combined weight export. Console and
manuscript-ready tables show two decimal places; numeric CSV readers may omit
trailing zeros. 

Use normalized_weight for a final normalized weighting vector. Use
interval_midpoint when comparing with the original article's "Average".
Do not interpret normalized_weight as necessarily lying within its unnormalized
GMIR interval. Interval widths are not confidence intervals or probabilities.

For criterion $j$, the representative triangle is defuzzified by the graded
mean integration representation (GMIR):

```math
R(\widetilde w_j)=\frac{w_j^L+4w_j^M+w_j^U}{6}.
```

The interval bounds are optimized separately at the common deviation allowed
by the interval model. If they are $\underline r_j$ and $\overline r_j$, then

```math
m_j=\frac{\underline r_j+\overline r_j}{2},\qquad
p_j=\frac{m_j}{\sum_i m_i}.
```

Here $m_j$ is `interval_midpoint` and $p_j$ is `normalized_weight`.
Normalization is applied to the midpoints, not to the representative GMIR values.
Interpreting the intervals after normalisation: the bounds lower_bound and upper_bound refer to GMIR weights before midpoint normalisation. Dividing each interval midpoint by the sum of all midpoints produces the final normalized_weight vector, whose components sum to one. This rescaling does not preserve membership in the original intervals, so a normalised weight should not be assumed to lie within its corresponding GMIR interval. The intervals are optimisation ranges, not statistical confidence intervals.

## Understanding the alpha-cut model, K and numerical precision

### Basic optimization model

Let B and W denote the selected best and worst criteria. The pair set contains
(B,j) and (j,W) for each intermediate criterion j, plus the direct pair (B,W)
once. Self-comparisons are validated but are not fitted as ordinary comparisons.
For each pair (p,q) and each alpha in the uniform grid $F_K$, the model requires

```math
\left|\frac{w_p^L(\alpha)}{w_q^U(\alpha)}-a_{pq}^L(\alpha)\right|\leq\epsilon,
\qquad
\left|\frac{w_p^U(\alpha)}{w_q^L(\alpha)}-a_{pq}^U(\alpha)\right|\leq\epsilon.
```

It minimizes $\epsilon\geq0$, subject to ordered nonnegative triangular weight
components, positive denominators and GMIR normalization:

```math
0\leq w_j^L\leq w_j^M\leq w_j^U,\qquad
\sum_j\frac{w_j^L+4w_j^M+w_j^U}{6}=1.
```

The implementation imposes a positive denominator floor, documented below.
For fixed epsilon the ratio constraints can be written as linear constraints
by multiplication by their positive denominators. The implementation searches
for epsilon by bisection with fallback probes and solves the resulting LPs
using HiGHS. It then minimizes and maximizes each GMIR weight with the common
allowed deviation `epsilon + epsilon_margin`.

The article defines the mathematical optimization model. The bisection stopping
tolerance and solver fallback strategy are implementation choices, not a fuzzy
consistency rule or a threshold prescribed by that article.

### K and the discretization bound

K is the number of alpha levels, including both 0 and 1. It must be an integer
at least 2. The solver uses a uniform grid alpha = 0, 1/(K-1), ..., 1.
A larger K introduces more constraints and generally takes longer.
For nested comparisons, use K = 2, 3, 5, 9, 17, 33, 65, 129, 257.
This sequence is convenient, not mandatory: other integers such as 10, 50
or 100 are also valid.

For every input triple calculate M-L and U-M. Let S be the largest of these
values over both vectors. The outputs are:

- max_input_spread = S
- mesh_size = 1/(K-1)
- ea_upper_bound = S * mesh_size

For S = 0.4 and K = 129 the bound is 0.003125. For the original article scale,
S = 1, and at K = 129 the bound is 0.0078125. If all comparisons are crisp, S = 0 and
there is no alpha-discretization error; epsilon can still be positive.

EA bounds the difference between the exact finite-grid and continuous-alpha
optimal objective values on the same feasible weight domain. It is **not**
a bound on the error of each weight and not a consistency ratio. Numerical
search/solver errors are separate. A proof for general positive triangular
inputs is given in the appendix below; this is an explicit generalization of
the original scale-specific result.

A desired theoretical bound delta > 0 can be met with
K >= max(2, ceiling(S/delta)+1). This can be expensive for wide inputs.
The public API currently accepts uniform grids only.

In formula form:

```math
F_K=\left\{\frac{r}{K-1}:r=0,\ldots,K-1\right\},\qquad
S=\max_{(L,M,U)\text{ in both input vectors}}\{M-L,U-M\},
\qquad \mathrm{EA}_{\mathrm{upper\_bound}}=\frac{S}{K-1}.
```

### Choosing K for your data

The example and own-data scripts use **K = 129** and leave the numerical
search `tolerance` at **1e-6**. The function still requires K explicitly.
Start with these settings; ordinary use does not require changing the advanced
numerical parameters. The article script keeps its separate K = 2, 17, 129 runs.

These defaults were selected after 60 tolerance runs and 52 K runs on the four
included datasets, using R 4.6.1 / highs 1.14.0-2 on Windows 11. With tolerance
1e-6, K=129 and K=257 gave the same normalized weights rounded to four decimal
places in all four datasets, and all four K=129 runs achieved the requested
epsilon tolerance. The four K=129 calculations took about 25 seconds in total,
compared with 183 seconds at K=257. Timings depend on hardware and solver version.
Some interval endpoints still differed after rounding, so this observation
applies to normalized weights and is not a universal precision guarantee.

For a sensitivity check on new data, run your copied script again with K=257
and a different output directory, for example `output/my_analysis_k257`.
Compare `normalized_weight`, `rank`, and the interval endpoints in `weights.csv`.
Retain full precision during calculation; four decimals of a weight correspond
to two decimals when expressed as a percentage. A small change near a rounding
boundary can change the last printed digit without a meaningful practical change.
Increasing K does not guarantee monotonic changes in individual weights.

Keep tolerance at 1e-6 for this comparison so that only K changes. Tighter
requested tolerances (1e-7 or 1e-8) substantially increased time in the evaluation
without changing the normalized weights at four decimals relative to 1e-6.
None of the twelve 1e-8 runs achieved its requested epsilon tolerance; therefore
those runs are comparison points, not exact solutions. No automatic additional
sensitivity calculations are performed by the user scripts.

### Model diagnostics and numerical settings

| Output | Interpretation |
|---|---|
| epsilon | Grid-fit deviation for the representative solution, certified by evaluating its original ratios; a numerical estimate, not CI/CR |
| `epsilon_bisection_upper` | Feasible upper endpoint found by the epsilon search |
| `epsilon_certification_adjustment` | Upward adjustment after checking actual ratios |
| `epsilon_used_for_bounds` | epsilon + epsilon_margin; all GMIR bounds use this common value |
| `eta_star` | Maximum absolute ratio deviation of the representative fuzzy weights over continuous alpha in [0,1] |
| `eta_star_alpha` | An alpha where that maximum occurs |
| `eta_star_relation` | The corresponding weight ratio |
| `max_input_spread, mesh_size, ea_upper_bound` | Input spread, grid spacing and theoretical discretization bound |
| `best_worst_adjustment` | Roundoff-level canonicalization of the duplicated direct input |
| `indeterminate_epsilon_values` | Search trials whose feasibility was not certified |
| `solver_status, solver_status_message, solver_strategy` | Status/strategy of the representative epsilon solution |
| `solver, solver_version, model_version` | Reproducibility identifiers |

eta_star and epsilon describe model fit and approximation; neither provides a
methodologically established acceptance threshold for the judgments.
The continuous-alpha deviation is evaluated at endpoints and applicable
stationary points of each ratio-error function.
There is no input- or output-based CI/CR in this repository.

Default numerical settings:

| Parameter | Default | Purpose |
|---|---:|---|
| `input_tolerance` | 1e-10 | Agreement of duplicated direct input, not a solver tolerance |
| `denominator_lower_bound` | 1e-7 | Positive floor on lower weight components used as denominators |
| tolerance | 1e-6 | Epsilon bisection stopping width |
| `epsilon_upper_start` | 1 | Initial search upper endpoint |
| `epsilon_upper_max` | 1e6 | Maximum permitted search endpoint |
| `epsilon_margin` | 1e-6 | Explicit relaxation for interval optimization |

Changing the denominator floor changes the numerical feasible domain.
Changing epsilon_margin can change intervals, particularly close to an optimum.
The implementation uses an equivalent-formulation fallback: if needed, solve an equivalent
LP with singleton constraints represented as variable bounds, duplicate rows
removed and positive row/objective scaling. Epsilon and margins are not
automatically enlarged. Accepted primal solutions are checked against the
original linear constraints at absolute residual tolerance 1e-8.
Indeterminate trials never move the bracket. Check `epsilon_tolerance_met`
and `epsilon_search_gap`; numerical solver classifications are not exact-arithmetic
certificates. See the numerical stopping explanation below for the stopping rules.

#### Numerical stopping and diagnostics

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
but the requested optimum precision is not established. This does not automatically invalidate the weights or assess input consistency.
Review the trace and compare the resulting weights under nearby numerical
settings when the warning occurs; precision of weights is not established by
the epsilon tolerance alone. The epsilon gap
is not an error bound on weights. This numerical gap is separate from EA.
Historical unresolved trials may remain in the trace even when later trials
achieve the requested precision; their presence alone no longer triggers a warning.

## Assess whether the weights are usable

Interpret the calculation in this order:

1. **Review the judgments.** Check comparison directions, criterion definitions,
   triangle endpoints and best/worst choices with the decision maker. Structural
   validity is not evidence of judgment consistency.
2. **Check numerical completion.** Inspect the solver status and
   `epsilon_tolerance_met`. An unresolved epsilon search retains a feasible
   solution but does not establish the requested optimum precision.
3. **Read normalized weights and ranking.** Their sum should be 1 within rounding.
   A weight of 0.30 is a 30% share of importance within this criterion set.
4. **Inspect intervals and near ties.** The GMIR intervals describe ranges under
   the optimization constraints, not statistical confidence or probability.
5. **Check sensitivity when needed.** Compare the same data at a larger K using
   the same numerical settings. Separately, test plausible changes to judgments
   with the decision maker; preserve both copies of the direct comparison.

There is **no input- or output-based CI/CR** in this implementation. Do not apply
Classical BWM's modal input ratio, its acceptance thresholds, or a supposed
universal threshold for epsilon or eta_star. These fit diagnostics do not
establish consistency, accuracy of individual weights or substantive validity.
A small EA bounds objective discretization, not errors in each weight.

A practical result should combine defensible judgments, successful numerical
calculation, interpretable weights and adequate sensitivity for the intended
application. When using weights in an aggregate score, separately define
performance normalization and benefit/cost directions. This repository does
not make raw performance measures comparable or calculate country-level PSI scores.

## Preserve and reopen the analysis

The example and own-data workflows export the following files automatically.

`export_acfbwm_result()` writes these files to the selected output directory:

| File | Contents |
|---|---|
| `input_original.csv` | Validated original seven-column input before roundoff canonicalization |
| `input.csv` | Effective input used for calculation |
| `fuzzy_comparisons.csv` | Both vectors in long format: criterion, L/M/U, role (self/direct_best_to_worst/ordinary) |
| `weights.csv` | All weight quantities in input row order |
| `ranking.csv` | Same quantities sorted by rank |
| `model_summary.csv` | Version, best/worst, S, K, mesh, EA, deviations, solver information |
| `parameters.csv` | Explicit best/worst identifiers and all numerical settings |
| `alpha_levels.csv` | Alpha grid |
| `grid_diagnostics.csv` | alpha, ratio relation, actual ratio, target, absolute error, epsilon and satisfied flag |
| `continuous_alpha_deviations.csv` | Maximum continuous deviation and alpha for each ratio relation |
| `epsilon_search.csv` | Attempted epsilon values, solver strategies/statuses and feasibility classifications |
| `interval_solver_trace.csv` | Solver attempts for every criterion's minimum and maximum |
| `result.rds` | Complete R result object |
| `sessionInfo.txt` | R, platform and package information |

The grid satisfied flag includes a numerical tolerance; it is not an input
consistency assessment. Successful interval calculations require optimal solver
statuses for every bound.

Rerunning overwrites named files within the same model version. Use a fresh
output folder for a different scenario. Directories containing legacy
consistency exports or a result.rds from another model version are rejected;
no old files are automatically deleted.
To reopen a result: saved <- readRDS("output/my_analysis/result.rds").

Keep the original CSV, copied script, outputs and exact repository version
or commit together. Use a different output directory for each scenario.
To reopen a result without running the optimizer:

```r
saved_result <- readRDS(file.path("output", "my_acfbwm_analysis", "result.rds"))
print(saved_result$ranking)
print(saved_result$epsilon_tolerance_met)
```

Report criterion definitions, the decision maker and elicitation scale,
explicit triangular inputs, best/worst, K, numerical settings, interval and
normalized weights, and relevant diagnostics. Round only displayed results.

## Troubleshooting

| Symptom | What to check |
|---|---|
| File cannot be opened | Check `getwd()`, extraction, exact filename and extension; start from the repository root. |
| Required columns missing | Use the seven exact names and the correct separator; the old three-column input is not automatically converted. |
| Non-numeric values or NA | Inspect `str(my_input)` and missing counts. Check decimals, separators and text formatting. |
| Triangle rejected | Require finite values with `0 < L <= M <= U`; the validator does not sort or repair judgments. |
| Best/worst identifier rejected | Use distinct, existing, case-sensitive names; set them explicitly in the copied script. |
| Self-comparison rejected | BO for best and OW for worst must each be exactly `(1,1,1)`. |
| Direct comparisons do not match | Compare all three BO components in the worst row with OW in the best row; they represent the same judgment. |
| A maximum or other comparison is fuzzy | This is allowed. Only the two specified self-comparisons must be crisp 1. |
| Package is missing | Install `highs` in the R installation used by this session. |
| Epsilon tolerance not achieved | Inspect `epsilon_search_gap`, `epsilon_search_status` and `epsilon_search.csv`. This is a numerical precision warning, not a consistency classification. |
| Very slow calculation | Check K and `tolerance`. Start at K=129 and tolerance=1e-6; stricter tolerances can be much slower without improving displayed weights. |
| Optimization stops with an error | Keep inputs, settings, full error and `sessionInfo()`; do not treat previous output as the failed run. |
| Existing output version rejected | Use a new output folder or a newly extracted release; do not mix versions. |
| Representative triangles differ between runs | Nonunique solutions are possible; compare interval bounds, normalized weights and settings. |
| Original article values differ | Compare the same explicit inputs, K and output quantity; article Average means `interval_midpoint`. Do not substitute rounded published epsilon to force agreement. |
| Rounded weights do not sum exactly to 1 | Check full-precision `normalized_weight`; rounding individual displayed values can alter their sum. |
| Normalized weight falls outside the raw interval | Intervals concern unnormalized GMIR weights; midpoint normalization changes the scale. |

## Tests and maintenance

From the repository root:

```r
source(file.path("tests", "run_tests.R"))
```

Tests cover input validation, crisp analytical cases, asymmetric inputs,
reference weights, EA, exports and unresolved epsilon trials. Successful
completion prints `All tests passed for release 0.3.1.` Tests include difficult
numerical cases that can emit precision warnings while all assertions pass.
This does not mean each test run attained its requested epsilon tolerance.

The release's three user workflows were successfully run by the user in the
reported R environment. The numerical engine is unchanged by this README update.
This repository neither modifies nor depends on the Classical BWM repository.

## Associated manuscript

**Best-Worst Method and α-cut intervals based Fuzzy Best-Worst Method in R: A Pension Sustainability Index Case Study**

Authors:

- Michaela Bruteničová
  ([ORCID 0000-0003-0208-6816](https://orcid.org/0000-0003-0208-6816))
- Miroslav Hužvár
  ([ORCID 0000-0001-9797-5602](https://orcid.org/0000-0001-9797-5602))
- Igor Kollár
  ([ORCID 0000-0003-4734-812X](https://orcid.org/0000-0003-4734-812X))
- Jana Špirková
  ([ORCID 0000-0001-5864-9353](https://orcid.org/0000-0001-5864-9353))

Affiliation: Matej Bel University in Banská Bystrica, Slovakia.

The manuscript is in preparation. Journal, publication year, and DOI metadata
will be added when they become available.

### Reproduce the included article calculations

```r
source(file.path("examples", "article.R"))
```

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

#### Input provenance

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

## References and citation

- Ratandhara, H. M., & Kumar, M. (2024). An α-cut intervals based Fuzzy
  Best–Worst Method for Multi-Criteria Decision-Making.
  *Applied Soft Computing, 159*, 111625.
  https://doi.org/10.1016/j.asoc.2024.111625

Software author metadata and version are in `CITATION.cff`. Cite the exact
software release used together with the methodological article. No software
DOI is assigned in this distribution; add archive metadata only when available.

## License

MIT; see `LICENSE`.

## Appendix: why the generalized EA bound is S times the grid spacing

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
