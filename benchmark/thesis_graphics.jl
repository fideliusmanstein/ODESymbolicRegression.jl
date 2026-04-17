"""
thesis_graphics.jl

Generate thesis-quality figures for ODE symbolic regression results.

Usage:
    julia --project=. benchmark/thesis_graphics.jl \\
        --json  benchmark_results/results_A.json \\
        --json  benchmark_results/results_B.json \\   # optional second run for comparison
        --problem simpleLin2 \\
        --outdir thesis_figures

Figures generated:
  1. trajectories_<problem>.pdf        — Ground-truth trajectories for multiple ICs
  2. discovered_vs_true_<problem>.pdf  — Discovered vs true system trajectories
  3. r2_per_problem_<run>.pdf          — R² for every problem in one benchmark run
  4. r2_distribution_comparison.pdf   — R² distributions across multiple benchmark runs
  5. integration_loss_ranking.pdf      — Problems ranked by integration loss
  6. discovery_time_vs_quality.pdf     — Discovery time vs avg R² scatter
"""

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

include(joinpath(@__DIR__, "benchmarkProblems/BenchmarkSystems.jl"))

using .BenchmarkSystems
using DifferentialEquations
using JSON
using CairoMakie
using Statistics
using Dates

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

function parse_args(args)
    json_files  = String[]
    problem     = nothing
    outdir      = "thesis_figures"
    i = 1
    while i <= length(args)
        if args[i] == "--json" && i < length(args)
            push!(json_files, args[i+1]); i += 2
        elseif args[i] == "--problem" && i < length(args)
            problem = args[i+1]; i += 2
        elseif args[i] == "--outdir" && i < length(args)
            outdir = args[i+1]; i += 2
        else
            i += 1
        end
    end
    return json_files, problem, outdir
end

json_files, PROBLEM, OUTDIR = parse_args(ARGS)
mkpath(OUTDIR)

if isempty(json_files)
    error("Provide at least one --json <path> argument.")
end
if PROBLEM === nothing
    error("Provide --problem <name>.")
end

println("Output directory : $OUTDIR")
println("Problem          : $PROBLEM")
println("JSON files       : $(join(json_files, ", "))")

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

function load_json(path)
    open(path) do f
        JSON.parse(f)
    end
end

"""
Load the full benchmark dataset for a problem, without the truncation behavior of
`BenchmarkSystems.load_problem(problem_name)` that is used for convenience in
benchmark execution.
"""
function load_full_benchmark_dataset(problem_name)
    prefix, module_ref, exp_func, _, _, _ = BenchmarkSystems.find_problem_config(problem_name)

    if prefix == "simpleLin"
        return getfield(module_ref, exp_func)(num_trajectories=1)
    end

    return getfield(module_ref, exp_func)(problem=problem_name)
end

"""Short label for a JSON file path (basename without extension)."""
run_label(path) = splitext(basename(path))[1]

"""
Simulate the ODE defined by `system_func!(dX,X,p,t)` from X0 over tspan,
returning (t_vec, X_matrix) where X_matrix is (n_points × n_states).
Returns nothing if integration fails.
"""
function simulate_system(system_func!, X0, tspan; n_points=200)
    prob = ODEProblem(system_func!, X0, tspan)
    t_eval = range(tspan[1], tspan[2]; length=n_points)
    try
        sol = solve(prob, AutoTsit5(Rosenbrock23());
                    saveat=collect(t_eval), maxiters=10^7,
                    abstol=1e-8, reltol=1e-8)
        if sol.retcode != ReturnCode.Success
            return nothing
        end
        X = reduce(hcat, sol.u)'   # (n_points × n_states)
        return collect(t_eval), X
    catch
        return nothing
    end
end

"""
Build a callable `(dX, X, p, t) -> ...` from a vector of equation strings.
Variable names are x1…x_{n_states} (+ x{n_states+1}… for inputs if any).
Returns nothing if any equation fails to parse.
"""
function build_system_from_strings(eq_strings, n_states, input_interps=Dict())
    n_inputs  = length(input_interps)
    n_features = n_states + n_inputs
    input_keys = sort(collect(keys(input_interps)))

    # compile each equation string to a lambda
    lambdas = []
    for eq in eq_strings
        # strip "x_i' = " prefix if present
        body = replace(eq, r"^[xX]\d+'\s*=\s*" => "")
        body = replace(body, "·" => "*")
        # replace square(…) with (…)^2
        body = replace(body, r"square\(([^)]+)\)" => s"(\1)^2")
        # replace inv_op(…) with 1/(…)
        body = replace(body, r"inv_op\(([^)]+)\)" => s"(1/(\1))")
        arg_list = join(["x$k" for k in 1:n_features], ", ")
        fn_str = "($arg_list) -> $body"
        fn = try
            eval(Meta.parse(fn_str))
        catch e
            @warn "Could not parse equation: $eq  →  $e"
            return nothing
        end
        push!(lambdas, fn)
    end

    function ode!(dX, X, p, t)
        all(isfinite, X) || (fill!(dX, Inf); return)
        args = [X[k] for k in 1:n_states]
        for key in input_keys
            push!(args, input_interps[key](t))
        end
        for (i, fn) in enumerate(lambdas)
            val = try Base.invokelatest(fn, args...) catch; Inf end
            dX[i] = isfinite(val) ? val : Inf
        end
    end
    return ode!
end

# ─────────────────────────────────────────────────────────────────────────────
# Figure 1 — Ground-truth trajectories with different initial conditions
# ─────────────────────────────────────────────────────────────────────────────

println("\n[1/6] Trajectories with different initial conditions...")

begin
    experiments = load_full_benchmark_dataset(PROBLEM)
    n_states = size(experiments[1][:X], 2)

    state_colors = Makie.wong_colors()

    fig = Figure(size=(900, 400 * ceil(Int, n_states / 2)))
    axes = []
    for s in 1:n_states
        row = div(s-1, 2) + 1
        col = mod(s-1, 2) + 1
        ax = Axis(fig[row, col];
            xlabel="Time",
            ylabel="State value",
            title="State x$s")
        push!(axes, ax)
    end

    for (idx, exp) in enumerate(experiments)
        t  = exp[:t]
        X  = exp[:X]
        parts = String[]

        if haskey(exp, :ic) && exp[:ic] !== nothing
            ic = exp[:ic]
            ic_str = join(["$k=$(round(v; sigdigits=3))" for (k, v) in pairs(ic)], ", ")
            push!(parts, "X₀: $ic_str")
        end

        if haskey(exp, :params) && exp[:params] !== nothing
            params = exp[:params]
            param_str = join(["$k=$(round(v; sigdigits=3))" for (k, v) in pairs(params)], ", ")
            push!(parts, param_str)
        elseif !isempty(get(exp, :inputs, Dict()))
            input_vals = exp[:inputs]
            input_parts = String[]
            for (k, v) in sort(collect(pairs(input_vals)); by=x->string(x[1]))
                val = v isa AbstractVector ? v[1] : v
                push!(input_parts, "$k=$(round(Float64(val); sigdigits=3))")
            end
            !isempty(input_parts) && push!(parts, join(input_parts, ", "))
        end

        lbl = isempty(parts) ? "Exp $idx" : "Exp $idx: " * join(parts, " | ")

        for s in 1:n_states
            lines!(axes[s], t, X[:, s];
                   color=state_colors[mod1(idx, length(state_colors))],
                   label=lbl,
                   linewidth=2)
        end
    end

    for ax in axes
        axislegend(ax; position=:rt, framevisible=false, labelsize=9, nbanks=1)
    end

    Label(fig[0, :], "Benchmark dataset trajectories — $PROBLEM";
          fontsize=16, font=:bold)

    out1 = joinpath(OUTDIR, "1_trajectories_$(PROBLEM).pdf")
    save(out1, fig)
    println("  Saved: $out1")
end

# ─────────────────────────────────────────────────────────────────────────────
# Figure 2 — Discovered vs true system trajectories (first JSON file)
# ─────────────────────────────────────────────────────────────────────────────

println("\n[2/6] Discovered vs. true trajectories...")

begin
    data = load_json(json_files[1])
    if !haskey(data, PROBLEM)
        @warn "Problem $PROBLEM not found in $(json_files[1]) — skipping Figure 2"
    else
        entry = data[PROBLEM]
        disc_eqs  = entry["discovered_equations"]
        n_states  = entry["n_states"]

        # Use first experiment for reference trajectory + ICs
        exp       = BenchmarkSystems.load_problem(PROBLEM; num_trajectories=1)[1]
        t_ref     = exp[:t]
        X_ref     = exp[:X]
        X0        = X_ref[1, :]
        tspan     = (t_ref[1], t_ref[end])

        # Build input interpolations from the experiment
        input_interps = Dict()
        for (key, vals) in exp[:inputs]
            if length(vals) == length(t_ref)
                input_interps[key] = t -> begin
                    # linear interp manually
                    i = clamp(searchsortedfirst(t_ref, t) - 1, 1, length(t_ref)-1)
                    α = (t - t_ref[i]) / (t_ref[i+1] - t_ref[i])
                    vals[i] * (1 - α) + vals[i+1] * α
                end
            end
        end

        disc_system = build_system_from_strings(disc_eqs, n_states, input_interps)

        fig = Figure(size=(900, 400 * ceil(Int, n_states / 2)))
        axes = []
        for s in 1:n_states
            row = div(s-1, 2) + 1
            col = mod(s-1, 2) + 1
            ax = Axis(fig[row, col];
                xlabel="Time",
                ylabel="State value",
                title="State x$s")
            push!(axes, ax)
        end

        # Ground truth
        for s in 1:n_states
            lines!(axes[s], t_ref, X_ref[:, s];
                   color=:steelblue, linewidth=2.5, label="Ground truth",
                   linestyle=:solid)
        end

        # Discovered
        if disc_system !== nothing
            res = simulate_system(disc_system, Float64.(X0), tspan)
            if res !== nothing
                t_sim, X_sim = res
                for s in 1:n_states
                    lines!(axes[s], t_sim, X_sim[:, s];
                           color=:orangered, linewidth=2, label="Discovered",
                           linestyle=:dash)
                end
            else
                @warn "Discovered system simulation diverged for $PROBLEM"
            end
        else
            @warn "Could not parse discovered equations for $PROBLEM"
        end

        for ax in axes
            axislegend(ax; position=:rt, framevisible=false, labelsize=11)
        end

        r2_vals = [s["r2"] for s in entry["equation_scores"] if haskey(s, "r2") && s["r2"] isa Number]
        avg_r2 = isempty(r2_vals) ? NaN : mean(r2_vals)
        Label(fig[0, :],
            "Discovered vs. true trajectories — $PROBLEM  (avg R²=$(round(avg_r2; digits=4)))";
            fontsize=15, font=:bold)

        out2 = joinpath(OUTDIR, "2_discovered_vs_true_$(PROBLEM).pdf")
        save(out2, fig)
        println("  Saved: $out2")
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Figure 3 — R² per problem for one benchmark run
# ─────────────────────────────────────────────────────────────────────────────

println("\n[3/6] R² per problem (first run)...")

begin
    data  = load_json(json_files[1])
    label = run_label(json_files[1])

    problems = sort(collect(keys(data)))
    avg_r2s  = Float64[]
    min_r2s  = Float64[]

    for p in problems
        local entry = data[p]
        r2s = [s["r2"] for s in get(entry, "equation_scores", [])
               if haskey(s, "r2") && s["r2"] isa Number && isfinite(s["r2"])]
        push!(avg_r2s, isempty(r2s) ? NaN : mean(r2s))
        push!(min_r2s, isempty(r2s) ? NaN : minimum(r2s))
    end

    valid = .!isnan.(avg_r2s)
    problems_v = problems[valid]
    avg_v      = avg_r2s[valid]
    min_v      = min_r2s[valid]

    # Sort by avg R²
    order = sortperm(avg_v)
    problems_sorted = problems_v[order]
    avg_sorted      = avg_v[order]
    min_sorted      = min_v[order]

    n = length(problems_sorted)
    ys = 1:n

    fig = Figure(size=(800, max(400, 22 * n)))
    ax  = Axis(fig[1, 1];
        xlabel="R²",
        ylabel="Problem",
        title="R² per problem — $label",
        yticks=(collect(ys), problems_sorted),
        yticklabelsize=11)

    # Shade "good" region
    vspan!(ax, 0.9, 1.0; color=(:green, 0.08))
    vlines!(ax, [0.0, 0.9]; color=:gray, linestyle=:dash, linewidth=1)

    # Min R² (worst state)
    scatter!(ax, min_sorted, collect(ys);
             color=:firebrick, marker=:diamond, markersize=9, label="min R² (worst state)")
    # Avg R²
    scatter!(ax, avg_sorted, collect(ys);
             color=:steelblue, marker=:circle, markersize=10, label="avg R²")

    # Error bar between min and avg
    for i in 1:n
        lines!(ax, [min_sorted[i], avg_sorted[i]], [ys[i], ys[i]];
               color=:gray, linewidth=1)
    end

    xlims!(ax, min(-1.5, minimum(min_sorted) - 0.2), 1.05)
    axislegend(ax; position=:rb, framevisible=false)

    out3 = joinpath(OUTDIR, "3_r2_per_problem_$(label).pdf")
    save(out3, fig)
    println("  Saved: $out3")
end

# ─────────────────────────────────────────────────────────────────────────────
# Figure 4 — R² distribution comparison across runs
# ─────────────────────────────────────────────────────────────────────────────

println("\n[4/6] R² distribution comparison...")

begin
    fig = Figure(size=(700, 480))
    ax  = Axis(fig[1, 1];
        xlabel="R²",
        ylabel="Density",
        title="R² distribution across benchmark runs")

    colors = Makie.wong_colors()
    all_labels = run_label.(json_files)

    for (k, path) in enumerate(json_files)
        local data = load_json(path)
        r2s  = Float64[]
        for (_, entry) in data
            for s in get(entry, "equation_scores", [])
                if haskey(s, "r2") && s["r2"] isa Number && isfinite(s["r2"])
                    push!(r2s, s["r2"])
                end
            end
        end

        isempty(r2s) && continue

        # Clip extreme outliers for display
        r2s_clipped = clamp.(r2s, -5.0, 1.0)

        density!(ax, r2s_clipped;
                 color=(colors[mod1(k, length(colors))], 0.4),
                 strokecolor=colors[mod1(k, length(colors))],
                 strokewidth=2,
                 label="$(all_labels[k])  (n=$(length(r2s)))")
    end

    vlines!(ax, [0.9]; color=:green, linestyle=:dash, linewidth=1.5,
            label="R²=0.9 threshold")
    axislegend(ax; position=:lt, framevisible=false, labelsize=11)

    out4 = joinpath(OUTDIR, "4_r2_distribution_comparison.pdf")
    save(out4, fig)
    println("  Saved: $out4")
end

# ─────────────────────────────────────────────────────────────────────────────
# Figure 5 — Problems ranked by integration loss (log scale)
# ─────────────────────────────────────────────────────────────────────────────

println("\n[5/6] Integration loss ranking...")

begin
    fig = Figure(size=(800, 500))
    ax  = Axis(fig[1, 1];
        xlabel="Problem",
        ylabel="Integration loss (log₁₀)",
        title="Integration loss per problem")

    colors = Makie.wong_colors()

    all_problems_union = String[]
    for path in json_files
        d = load_json(path)
        union!(all_problems_union, collect(keys(d)))
    end
    sort!(all_problems_union)

    n_problems = length(all_problems_union)
    xs = 1:n_problems
    offsets = range(-0.2, 0.2; length=length(json_files))

    for (k, path) in enumerate(json_files)
        d   = load_json(path)
        lbl = run_label(path)
        losses = [begin
            e = get(d, p, nothing)
            e === nothing ? NaN : begin
                v = get(e, "integration_loss", NaN)
                (v isa Number && isfinite(v) && v > 0) ? log10(v) : NaN
            end
        end for p in all_problems_union]

        local valid = .!isnan.(losses)
        scatter!(ax, collect(xs[valid]) .+ offsets[k], losses[valid];
                 color=colors[mod1(k, length(colors))],
                 markersize=9, label=lbl)
    end

    ax.xticks = (collect(xs), all_problems_union)
    ax.xticklabelrotation = π/3
    ax.xticklabelsize = 9
    axislegend(ax; position=:rt, framevisible=false)

    out5 = joinpath(OUTDIR, "5_integration_loss_ranking.pdf")
    save(out5, fig)
    println("  Saved: $out5")
end

# ─────────────────────────────────────────────────────────────────────────────
# Figure 6 — Discovery time vs. quality scatter
# ─────────────────────────────────────────────────────────────────────────────

println("\n[6/6] Discovery time vs. quality...")

begin
    fig = Figure(size=(700, 500))
    ax  = Axis(fig[1, 1];
        xlabel="Discovery time (s)",
        ylabel="Avg R²",
        title="Discovery time vs. equation quality")

    colors = Makie.wong_colors()

    for (k, path) in enumerate(json_files)
        d   = load_json(path)
        lbl = run_label(path)
        times = Float64[]
        r2s   = Float64[]
        pnames = String[]

        for (p, entry) in d
            t_disc = get(entry, "discovery_time", NaN)
            r2_list = [s["r2"] for s in get(entry, "equation_scores", [])
                       if haskey(s, "r2") && s["r2"] isa Number && isfinite(s["r2"])]
            isempty(r2_list) && continue
            push!(times,  t_disc isa Number ? Float64(t_disc) : NaN)
            push!(r2s,    mean(r2_list))
            push!(pnames, p)
        end

        local valid = .!isnan.(times) .& .!isnan.(r2s)
        sc = scatter!(ax, times[valid], r2s[valid];
                      color=colors[mod1(k, length(colors))],
                      markersize=10, label=lbl)

        # Label each point
        for i in findall(valid)
            text!(ax, times[i] + 2, r2s[i];
                  text=pnames[i], fontsize=7, color=:gray40,
                  align=(:left, :center))
        end
    end

    hlines!(ax, [0.9]; color=:green, linestyle=:dash, linewidth=1.5,
            label="R²=0.9 threshold")
    axislegend(ax; position=:rb, framevisible=false)

    out6 = joinpath(OUTDIR, "6_time_vs_quality.pdf")
    save(out6, fig)
    println("  Saved: $out6")
end

println("\n✓ All figures saved to: $OUTDIR/")
