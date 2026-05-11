if !isdefined(Main, :write_text_report)
    include(joinpath(@__DIR__, "common.jl"))
end

using JSON
using DifferentialEquations

# Load BenchmarkSystems here (top-level) so it is available in the current world
# when run_phase8 later calls load_problem.  Doing the include inside the function
# body triggers Julia 1.12's stricter world-age checks.
let bs_path = normpath(joinpath(@__DIR__, "..", "benchmark", "benchmarkProblems", "BenchmarkSystems.jl"))
    if !isdefined(Main, :BenchmarkSystems)
        include(bs_path)
    end
end

# Custom operators that may appear in discovered equation strings.
# These mirror the definitions in benchmark/benchmark.jl.
if !isdefined(Main, :square)
    square(x::Real) = x * x
end
if !isdefined(Main, :sqrtp)
    sqrtp(x::Real) = x > zero(x) ? sqrt(x) : typeof(x)(NaN)
end
if !isdefined(Main, :powc)
    function powc(x::Real, c::Real)
        xf, cf = Float64(x), Float64(c)
        (!isfinite(xf) || !isfinite(cf)) && return NaN
        (xf < 0.0 || (xf == 0.0 && cf < 0.0)) && return NaN
        y = exp(cf * log(xf))
        return isfinite(y) ? y : NaN
    end
end

# Problems where the GT ODE uses external forcing inputs (x_{n+1}, x_{n+2}, ...),
# making autonomous re-simulation of the discovered equations unreliable.
const _PROBLEMS_WITH_INPUTS = Set([
    "inhosc1", "inhosc2",
    "feedf1", "feedf2",
    "metabol1", "metabol2", "metabol3",
    "ss_feedf1", "ss_feedf2",
    "ss_inhosc1", "ss_inhosc2",
    "gma_feedf1", "gma_feedf2",
    "gma_inhosc1", "gma_inhosc2",
    "simpleLin1", "simpleLin2",
    "threeGenes1", "threeGenes2",
])

# ---------------------------------------------------------------------------
# Data collection
# ---------------------------------------------------------------------------

const R2_THRESHOLD = 0.95

"""
    _frac_good_r2(r2_scores) -> Float64

Fraction of equations whose R² ≥ R2_THRESHOLD (ignoring NaN entries).
"""
function _frac_good_r2(r2_scores::Vector{Float64})
    valid = filter(isfinite, r2_scores)
    isempty(valid) && return 0.0
    return count(r2 -> r2 >= R2_THRESHOLD, valid) / length(valid)
end

"""
    _collect_problem_runs(manifest) -> Dict{String, Vector{NamedTuple}}

Scan all completed JSON result files in manifest and, for each problem name
that does not use external inputs, collect a NamedTuple with:
    (run_key, json_path, integration_loss, discovered_equations, n_states, r2_scores,
     n_points, noise, trajectories, mode)
"""
function _collect_problem_runs(manifest::DataFrame)
    problem_runs = Dict{String, Vector{NamedTuple}}()

    for row in eachrow(manifest)
        (row.has_json && row.completed_run) || continue

        json_data = try
            JSON.parsefile(row.json_path)
        catch
            continue
        end

        for (problem, pdata) in json_data
            problem in _PROBLEMS_WITH_INPUTS && continue

            eqs = String.(get(pdata, "discovered_equations", String[]))
            isempty(eqs) && continue

            scores_raw = get(pdata, "equation_scores", nothing)
            scores_raw === nothing && continue
            r2_scores = Float64[get(s, "r2", NaN) for s in scores_raw]
            all(isnan, r2_scores) && continue

            integration_loss = let v = get(pdata, "integration_loss", nothing)
                (v === nothing || v === missing) ? Inf : Float64(v)
            end

            haskey(problem_runs, problem) || (problem_runs[problem] = NamedTuple[])
            push!(problem_runs[problem], (
                run_key              = row.run_key,
                json_path            = String(row.json_path),
                integration_loss     = integration_loss,
                discovered_equations = eqs,
                n_states             = Int(get(pdata, "n_states", length(eqs))),
                r2_scores            = r2_scores,
                n_points             = Int(get(row, :n_points, 0)),
                noise                = Float64(get(row, :noise, 0.0)),
                trajectories         = Int(get(row, :trajectories, 1)),
                mode                 = String(get(row, :mode, "unknown")),
            ))
        end
    end

    return problem_runs
end

# ---------------------------------------------------------------------------
# ODE construction from equation strings
# ---------------------------------------------------------------------------

"""
    _build_discovered_ode(eqs, n_states) -> Function

Return an in-place ODE function `(du, u, p, t)` built by parsing the equation
strings at runtime.  Variable names x1 … xN are bound to u[1] … u[N].
`square`, `sqrtp`, `powc` and `inv` are assumed to be defined in Main scope.
"""
function _build_discovered_ode(eqs::Vector{String}, n_states::Int)
    var_lines = join(["x$i = u[$i]" for i in 1:n_states], "\n        ")
    du_lines  = join(["du[$i] = $(eqs[i])" for i in 1:n_states], "\n        ")
    fn_str = """
    (du, u, p, t) -> begin
        $var_lines
        $du_lines
        return nothing
    end
    """
    return eval(Meta.parse(fn_str))
end

"""
    _simulate_discovered(eqs, u0, tspan) -> (ts, Xs) or nothing

Solve the discovered ODE system from `u0` over `tspan`.
Returns a `(time_vector, state_matrix)` tuple (state_matrix: n_pts × n_states)
or `nothing` if the solve fails or diverges immediately.
"""
function _simulate_discovered(
    eqs::Vector{String},
    u0::Vector{Float64},
    tspan::Tuple{Float64, Float64},
)
    ode_fn! = try
        _build_discovered_ode(eqs, length(eqs))
    catch e
        @warn "phase8: could not build discovered ODE: $e"
        return nothing
    end

    prob = ODEProblem(ode_fn!, u0, tspan)
    sol = try
        solve(
            prob,
            Tsit5();
            reltol      = 1e-6,
            abstol      = 1e-9,
            isoutofdomain = (u, p, t) -> any(!isfinite, u),
            maxiters    = 100_000,
        )
    catch e
        @warn "phase8: ODE solve failed: $e"
        return nothing
    end

    # Dense evaluation on a fine grid matching the GT density
    n_pts = 300
    ts = collect(range(tspan[1], tspan[2]; length = n_pts))
    Xs = try
        hcat([sol(t) for t in ts]...)'  # (n_pts × n_states)
    catch e
        @warn "phase8: dense eval failed: $e"
        return nothing
    end

    return ts, Matrix{Float64}(Xs)
end

# ---------------------------------------------------------------------------
# Plotting
# ---------------------------------------------------------------------------

"""
    _plot_trajectory_comparison(problem, gt_t, gt_X, eqs, loss, label, phase_dir)

One figure per example.  Each subplot is one state variable; GT (solid blue)
and discovered (dashed red) are overlaid.
"""
function _plot_trajectory_comparison(
    problem_name::String,
    gt_t::Vector{Float64},
    gt_X::Matrix{Float64},    # (n_timepoints × n_states)
    eqs::Vector{String},
    integration_loss::Float64,
    label::String,
    phase_dir::AbstractString,
)
    n_states = size(gt_X, 2)

    u0    = Float64.(gt_X[1, :])
    tspan = (gt_t[1], gt_t[end])

    disc_result = _simulate_discovered(eqs, u0, tspan)

    # Layout
    n_cols = min(3, n_states)
    n_rows = cld(n_states, n_cols)
    fig_w  = 350 * n_cols
    fig_h  = 280 * n_rows + 80

    fig = Figure(size = (fig_w, fig_h))

    loss_str  = isfinite(integration_loss) ? string(round(integration_loss; sigdigits = 3)) : "Inf"
    title_str = "$problem_name — $(uppercasefirst(label)) example  (integ. loss = $loss_str)"
    Label(fig[0, 1:n_cols], title_str; fontsize = 14, tellwidth = false)

    for i in 1:n_states
        row = cld(i, n_cols)
        col = mod1(i, n_cols)

        ax = Axis(fig[row, col];
            title   = "State x$i",
            xlabel  = "t",
            ylabel  = "x$i(t)",
        )

        # Ground-truth trajectory (solid blue, with dots on data points)
        lines!(ax, gt_t, gt_X[:, i];
            color = :steelblue, linewidth = 2, label = "Ground truth")
        scatter!(ax, gt_t, gt_X[:, i];
            color = :steelblue, markersize = 5)

        # Discovered trajectory (dashed red)
        if disc_result !== nothing
            disc_t, disc_X = disc_result
            col_vals = disc_X[:, i]
            finite_mask = isfinite.(col_vals)
            if any(finite_mask)
                lines!(ax, disc_t[finite_mask], col_vals[finite_mask];
                    color = :crimson, linewidth = 2,
                    linestyle = :dash, label = "Discovered")
            else
                text!(ax, 0.5, 0.5;
                    text  = "(diverged)",
                    space = :relative,
                    align = (:center, :center),
                    color = :crimson, fontsize = 11)
            end
        else
            text!(ax, 0.5, 0.5;
                text  = "(solve failed)",
                space = :relative,
                align = (:center, :center),
                color = :crimson, fontsize = 11)
        end

        # Legend on first subplot only
        if i == 1
            axislegend(ax; position = :rt, labelsize = 10)
        end
    end

    save_plot(fig, joinpath(phase_dir, "trajectory_$(label).png"))
    return nothing
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

"""
    _load_gt(problem) -> (gt_t, gt_X) or nothing
"""
function _load_gt(problem::String)
    exps = try
        Main.BenchmarkSystems.load_problem(problem; noise_std = 0.0)
    catch
        return nothing
    end
    isempty(exps) && return nothing
    exp   = exps[1]
    gt_t  = Float64.(exp[:t])
    X_raw = exp[:X]
    gt_X  = if X_raw isa Matrix
        size(X_raw, 1) >= size(X_raw, 2) ? Float64.(X_raw) : Float64.(X_raw')
    else
        Float64.(Matrix(X_raw))
    end
    return gt_t, gt_X
end

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

function run_phase8(manifest::DataFrame, output_dir::AbstractString)
    phase_dir = joinpath(output_dir, "phase8")
    mkpath(phase_dir)

    # Collect per-problem records (including R² scores) from all completed runs
    problem_runs = _collect_problem_runs(manifest)

    if isempty(problem_runs)
        @warn "phase8: no usable problem data found; skipping trajectory plots"
        return nothing
    end

    selected_row = _best_run_by_equation_threshold(manifest, R2_THRESHOLD, noise_values = Set([0.01, 0.05]))
    if selected_row === nothing
        @warn "phase8: no noisy best run found; skipping trajectory plots"
        return nothing
    end

    selected_run_key = selected_row.run_key
    selected_json_path = selected_row.json_path

    # Restrict phase 8 to the same run used by the noisy stacked-correctness plot.
    selected_problem_runs = Dict{String, Vector{NamedTuple}}()
    for (prob, runs) in problem_runs
        chosen_runs = filter(r -> r.run_key == selected_run_key, runs)
        isempty(chosen_runs) && continue
        selected_problem_runs[prob] = chosen_runs
    end

    # ------------------------------------------------------------------
    # For each problem in the selected run, keep the single available record.
    # This keeps the example selection aligned with the noisy best-run plot.
    # ------------------------------------------------------------------
    best_run_per_problem = Dict{String, NamedTuple}()
    for (prob, runs) in selected_problem_runs
        best_run_per_problem[prob] = sort(
            runs;
            by = r -> (-_frac_good_r2(r.r2_scores), r.integration_loss)
        )[1]
    end

    if isempty(best_run_per_problem)
        @warn "phase8: selected noisy run has no usable problems; skipping trajectory plots"
        return nothing
    end

    # Fraction of equations with R² ≥ threshold for each problem's best run
    frac_good = Dict(
        p => _frac_good_r2(r.r2_scores)
        for (p, r) in best_run_per_problem
    )

    all_problems = collect(keys(best_run_per_problem))

    # ------------------------------------------------------------------
    # Select the three showcase problems
    # ------------------------------------------------------------------
    # Good  : all equations R² ≥ threshold  (frac = 1.0)
    good_candidates  = filter(p -> frac_good[p] >= 1.0, all_problems)
    # Bad   : no  equation  R² ≥ threshold  (frac = 0.0)
    bad_candidates   = filter(p -> frac_good[p] == 0.0, all_problems)
    # Medium: everything in between, pick the one closest to 0.5
    medium_candidates = filter(p -> 0.0 < frac_good[p] < 1.0, all_problems)

    # If exact buckets are empty, fall back to closest available
    if isempty(good_candidates)
        good_candidates = [argmax(p -> frac_good[p], all_problems)]
    end
    if isempty(bad_candidates)
        bad_candidates = [argmin(p -> frac_good[p], all_problems)]
    end
    if isempty(medium_candidates)
        remaining = filter(p -> p ∉ good_candidates && p ∉ bad_candidates, all_problems)
        medium_candidates = isempty(remaining) ? good_candidates : remaining
    end

    # Among good candidates, prefer the one with the highest n_states (more interesting)
    good_problem  = argmax(p -> best_run_per_problem[p].n_states, good_candidates)
    # Among bad candidates, prefer the one with the most states as well
    bad_problem   = argmax(p -> best_run_per_problem[p].n_states, bad_candidates)
    # Among medium candidates, pick the one whose frac_good is nearest 0.5
    medium_problem = argmin(p -> abs(frac_good[p] - 0.5), medium_candidates)

    report_lines = String[
        "Phase 8 Report - Trajectory Example Plots",
        "Selection criterion: fraction of equations with R² ≥ $R2_THRESHOLD",
        "Selected run (shared with phase 6 noisy stacked plot): $selected_run_key",
        "Source JSON: $selected_json_path",
        "",
        "good   → $good_problem   ($(round(100*frac_good[good_problem]; digits=0))% of eqs R²≥$R2_THRESHOLD)",
        "medium → $medium_problem  ($(round(100*frac_good[medium_problem]; digits=0))% of eqs R²≥$R2_THRESHOLD)",
        "bad    → $bad_problem    ($(round(100*frac_good[bad_problem]; digits=0))% of eqs R²≥$R2_THRESHOLD)",
        "",
    ]

    # ------------------------------------------------------------------
    # Plot each example
    # ------------------------------------------------------------------
    for (problem, role) in [
        (good_problem,   "good"),
        (medium_problem, "medium"),
        (bad_problem,    "bad"),
    ]
        problem === nothing && continue
        chosen = best_run_per_problem[problem]

        gt = _load_gt(problem)
        if gt === nothing
            @warn "phase8: could not load GT for $role example $problem"
            continue
        end
        gt_t, gt_X = gt

        r2_str = join(
            [isfinite(r2) ? string(round(r2; digits=2)) : "NaN" for r2 in chosen.r2_scores],
            ", "
        )
        push!(report_lines,
            "$(uppercasefirst(role)) example: $problem  frac_good=$(round(frac_good[problem]; digits=2))  R²=[$(r2_str)]  loss=$(round(chosen.integration_loss; sigdigits=4))")
        push!(report_lines,
            "  run_key=$(chosen.run_key)  n_points=$(chosen.n_points)  noise=$(chosen.noise)  trajectories=$(chosen.trajectories)  mode=$(chosen.mode)")
        push!(report_lines, "  equations: $(join(chosen.discovered_equations, " | "))")
        push!(report_lines, "")

        _plot_trajectory_comparison(
            problem, gt_t, gt_X,
            chosen.discovered_equations,
            chosen.integration_loss,
            role, phase_dir,
        )

        @info "phase8: plotted $role example — $problem  R²=[$(r2_str)]"
    end

    write_text_report(joinpath(phase_dir, "report.txt"), report_lines)
    return nothing
end
