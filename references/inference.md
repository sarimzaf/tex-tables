# Statistical collection and inference

## Collection and control means

Capture `e(N)`, `e(cmd)`, `e(cmdline)`, controls, fixed effects, weight type and
expression, sample restrictions, VCE and cluster IDs before later commands
overwrite results. Preserve the exact e(sample) IDs with `pt_sample` before
reloading or modifying the analysis data. Check `_ms_omit_info e(b)`
before collecting a term. Use estimator-supported `lincom`/`test` or its native
inference result: OLS finite-df inference must not silently become normal-theory
inference; IV, survey, nonlinear and other estimators need explicit adapters.
`examples/stata/standard.do` is a tested unweighted OLS pattern, not a universal adapter.

Ordinary covariates are not treatment arms. Equality tests are optional unless
`pt_contrasts` is explicitly `first_vs_rest`; supply them only when their equality
is a scientifically intended hypothesis. All supplied tests use the fitted model's
joint covariance and reference distribution, regardless of whether required.

Control mean defaults to the relevant outcome at endline in the explicitly
declared control group, restricted to each model's e(sample). Record outcome,
time, control expression, restrictions and weights. Never infer the control
group from a variable name. The example uses `arm==0` because the synthetic
assignment is explicitly constructed that way. It supports unweighted means;
adapt weighted means with a valid estimator or report that limitation. Do not
silently drop weights. Regression count and summary weighted count conventions
can differ; document both.

## Sharpened q-values

Use Benjamini, Krieger and Yekutieli (2006) two-stage sharpened FDR, associated
with Anderson (2008), on conventional p-values within a common substantive
outcome domain. Determine that domain from the outcomes' definitions, measurement
instruments, study context and analysis plan. For example, GAD, PHQ and PSS can
form one mental-health outcome family. Record an explicit outcome-to-domain
mapping; do not infer membership solely from variable names, panel/table
placement or observed p-values. Use an existing planned mapping when available;
ask for clarification if the substantive context does not resolve membership.

Distinguish primary composite indices from secondary component outcomes using
the analysis plan and intended claims. Calculate secondary-component q-values
within each substantive domain, excluding the primary composite index from that
component family. For example, a primary mental-health index is separate from
the secondary family containing PHQ, GAD and PSS. Record each outcome's role
alongside its domain; do not infer primary status merely because it is an index.
Ask before adjustment if the roles are unclear or the plan treats indices and
components as coequal outcomes without specifying how to handle them.

Define a separate primary-outcome testing family for the indices from the
analysis plan and the claims they jointly support. That family may span domains;
do not automatically create one singleton family per index or group indices
because they share a table. Ask if its membership is unclear. When q-values are
requested for indices, calculate them within that explicitly defined index
family. If the plan instead specifies FWER or another primary-outcome procedure,
honor it through an appropriate adapter rather than substituting the bundled
FDR method. Report the component and primary-index families separately in the
notes; separate adjustments do not establish error control over their combined
claims. Do not choose roles or family boundaries from observed significance.

By default, adjust each planned outcome group separately for each treatment/effect.
Keep derived effects in their own effect families unless the analysis plan pools
them. A panel can contain multiple domains, and one domain can span panels or
tables. Determine any separation by follow-up time, population or specification
from the intended scientific comparisons and analysis plan, not automatically
from panel IDs. Document those boundaries along with domain membership.

Native `pt_adjust` directly calls the bundled
`scripts/fdr_sharpened_qvalues.ado` (Stata adaptation dated 2026-04-15), using
its identified descending .001 grid. The Mata validator recomputes that algorithm
independently when checking saved results. No Python is involved.

For each q from 1 to .001: stage 1 step-up threshold is q/(1+q) times rank/m;
let R1 be its largest rejected rank. Stage 2 uses denominator m−R1. All hypotheses
are rejected if R1=m; otherwise use the largest stage-2 rejected rank. Store the
smallest grid value rejecting each hypothesis, initialized to 1. Missing source
p-values do not enter m and retain missing q. Smallest nonmissing q is .001;
this is a computational grid, not precision added to the underlying estimates.
Ties use step-up ranks. Q can be less than conventional p. FDR validity still
depends on the procedure's assumptions and scientific family specification.

Use `pt_adjust, family(planned_family)` with an explicit string-valued family ID.
For a single planned time/population/specification scope, assign `domain_id`
and `outcome_role` from the substantive context and plan. Explicitly map each
outcome to `family_group_id`, incorporating its role: for example,
`secondary_components:mental_health` for the components and
`primary_indices:main_outcomes` for indices in a separately justified primary
family. The latter is an example ID, not a rule to pool every index. Then:

```stata
assert domain_id!="" & effect_id!="" if row_type=="coef"
assert outcome_role!="" & family_group_id!="" if row_type=="coef"
generate str244 planned_family = family_group_id+":"+effect_id if row_type=="coef"
pt_adjust, family(planned_family)
char _dta[pt_q_family_definition] "Components by domain, primary indices separately; each planned group x effect; membership and scope documented in notes"
```

Use stable unambiguous IDs and add an explicit scope ID when the analysis plan
requires separate time/population/specification families. Describe actual domain
members, outcome roles and the separate primary-index family in the notes
(for example, secondary mental-health components: GAD, PHQ, PSS). Set the scientific
definition in `char _dta[pt_q_family_definition]` after `pt_adjust`, which writes
generic method metadata. The bare `pt_adjust` command retains a legacy
panel-by-effect fallback for compatibility; do not use that fallback to choose
families in new analyses. Bundled examples retain their demonstration-specific
families and are not a prescription for empirical domain membership.

When a family spans tables, collect and adjust its complete hypothesis universe
together. Retain those complete family records in each staged export and use
`display=0` for members not shown in that table; do not adjust each table fragment
separately. Source p-values are preserved in
`q_source`; the native helper uses conventional p-values. Another requested
source needs an explicit reviewed adapter with matching validator/provenance.
Recompute if hypotheses, source p-values, or family membership change. Prepare
the complete universe first; set `display=0` to hide results without removing
them from the family. The exporter detects deleted members/changed p-values
through saved family counts, source comparisons and recomputation. Do not substitute BH, Bonferroni,
Holm or another procedure silently. Alternative requested methods need a reviewed
adapter and different provenance; the bundled validator intentionally rejects
unrecognized q implementations.

Primary sources: [Anderson's software and research page](https://anderson.are.berkeley.edu/Research.html),
[Anderson (2008)](https://anderson.are.berkeley.edu/pdf/Anderson%202008a.pdf),
Benjamini, Krieger and Yekutieli (2006), “Adaptive linear step-up procedures that
control the false discovery rate,” Biometrika 93(3), 491–507.
The bundled Stata adaptation and its SHA-256 are identified in the validation
report; retain that provenance if redistributing it.

## Randomization inference

Prefer [Simon Hess's ritest](https://github.com/simonheb/ritest) when assignment
was randomized and its mechanism is documented. Cite Heß (2017), “Randomization
inference with Stata: A guide and software,” Stata Journal 17(3), 630–651.
Record `which ritest`, source URL, ado version/header and SHA-256. Do not rely
only on a returned version macro: source headers and internal macros may differ.

Before running require: assignment variable; assignment unit; strata/blocks and
all restrictions; tested null (sharp vs weak, joint vs arm-specific); statistic;
tail; repetitions; seed. Distinguish assignment unit from SE clustering. Jointly
reassign the single categorical arm variable for multi-arm experiments; never
shuffle separate treatment dummies independently. Constrained/rerandomized or
unequal-probability designs may need `samplingprogram()` or an external assignment
file that represents the actual support. Define the randomization frame and
sample selection explicitly; e(sample) is not automatically the full assignment
frame. Any assignment-dependent processing must be rerun as required.

Illustration only, AFTER design verification (not a universal runnable template):
```stata
ritest arm (_b[1.arm]/_se[1.arm]), reps(9999) seed(20261018) ///
    cluster(assignment_unit) strata(randomization_stratum): ///
    regress endline_y i.arm baseline_y i.randomization_stratum, vce(cluster se_cluster)
matrix ri_p = r(p)
```
Inspect `return list`, save draws and the observed statistic, and attach the
correct returned statistic by panel/column/row key. Record actual repetitions
and failed draws; do not quietly discard failed fits. Verify the sample/frame
behavior of the installed version, including any `nodrop` setting in its help.

The source inspected on 2026-10-18 has header 1.21 (March 2024). Its default
two-sided comparison uses absolute statistics, non-strict ties and absolute
tolerance `eps(1e-7)`; strict comparisons require `eps(0)`. It reports the extreme
fraction `c/n` over nonmissing replications. Verify these conventions in the
actual installed source/draws; do not relabel this as a plus-one estimator.
Do not describe another RI implementation as Hess's ritest. Notes must identify
the method actually used. If the design is missing or RI is inapplicable, state why, obtain essential
information when needed, and retain `p_ri=.` with `{--}` if that line is retained.
Never fabricate RI values or resampling details to fill a table.

For nonmissing RI, use the required `pt_ri_*` dataset characteristics listed in
[native schema](native-stata.md). If procedures vary across models/effects, add
cell-specific provenance and adapt validation. Add draw/source hashes and actual
successful counts as supporting provenance. Notes must describe those actual procedures.
