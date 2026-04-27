if !isdefined(Main, :write_text_report)
    include(joinpath(@__DIR__, "common.jl"))
end

function _paired_deltas(df::DataFrame, factor::Symbol, levels, metrics::Vector{Symbol})
    fixed = setdiff([:mode, :noise, :n_points, :trajectories], [factor])

    rows = NamedTuple[]
    for (lo, hi) in zip(levels[1:end-1], levels[2:end])
        dfl = filter(r -> getproperty(r, factor) == lo, df)
        dfh = filter(r -> getproperty(r, factor) == hi, df)

        left_cols = vcat(fixed, [:problem], metrics)
        right_cols = vcat(fixed, [:problem], metrics)

        lsub = dfl[:, left_cols]
        rsub = dfh[:, right_cols]

        rename!(lsub, Dict(m => Symbol(string(m, "_lo")) for m in metrics))
        rename!(rsub, Dict(m => Symbol(string(m, "_hi")) for m in metrics))

        joined = innerjoin(lsub, rsub, on = vcat(fixed, [:problem]))

        for row in eachrow(joined)
            for m in metrics
                lo_col = Symbol(string(m, "_lo"))
                hi_col = Symbol(string(m, "_hi"))
                delta = row[hi_col] - row[lo_col]
                push!(rows, (
                    factor = String(factor),
                    transition = string(lo, "->", hi),
                    metric = String(m),
                    problem = row.problem,
                    mode = hasproperty(row, :mode) ? row.mode : missing,
                    noise = hasproperty(row, :noise) ? row.noise : missing,
                    n_points = hasproperty(row, :n_points) ? row.n_points : missing,
                    trajectories = hasproperty(row, :trajectories) ? row.trajectories : missing,
                    delta = delta,
                ))
            end
        end
    end

    return DataFrame(rows)
end

function _effect_summary(deltas::DataFrame)
    if nrow(deltas) == 0
        return DataFrame()
    end
    return combine(groupby(deltas, [:factor, :transition, :metric]),
        :delta => median => :median_delta,
        :delta => mean => :mean_delta,
        nrow => :n_rows)
end

function _plot_effect_summary(summary::DataFrame, factor_name::String, outpath::AbstractString)
    sub = filter(r -> r.factor == factor_name, summary)
    if nrow(sub) == 0
        return
    end

    metrics = unique(sub.metric)
    transitions = unique(sub.transition)

    fig = Figure(size = (1000, 600))
    ax = Axis(fig[1, 1],
        title = "Main effect: $(factor_name) (median deltas)",
        xlabel = "metric / transition",
        ylabel = "median delta")

    xpos = Int[]
    yvals = Float64[]
    labels = String[]
    i = 1
    for t in transitions
        for m in metrics
            row = filter(r -> r.transition == t && r.metric == m, sub)
            if nrow(row) > 0
                push!(xpos, i)
                push!(yvals, row.median_delta[1])
                push!(labels, "$(m)\n$(t)")
                i += 1
            end
        end
    end

    barplot!(ax, xpos, yvals)
    hlines!(ax, [0.0], color = :black, linestyle = :dash)
    ax.xticks = (xpos, labels)
    ax.xticklabelrotation = pi / 5

    save_plot(fig, outpath)
end

function run_phase2(df_analysis::DataFrame, output_dir::AbstractString)
    phase_dir = joinpath(output_dir, "phase2")
    mkpath(phase_dir)

    metrics = [:avg_r2, :min_r2, :avg_rmse, :discovery_time, :integration_loss]

    mode_deltas = _paired_deltas(df_analysis, :mode, ["knee", "search"], metrics)
    noise_deltas = _paired_deltas(df_analysis, :noise, [0.0, 0.01, 0.05], metrics)
    npoints_deltas = _paired_deltas(df_analysis, :n_points, [100, 250, 500], metrics)
    traj_deltas = _paired_deltas(df_analysis, :trajectories, [1, 5], metrics)

    CSV.write(joinpath(phase_dir, "mode_effect_deltas.csv"), mode_deltas)
    CSV.write(joinpath(phase_dir, "noise_effect_deltas.csv"), noise_deltas)
    CSV.write(joinpath(phase_dir, "npoints_effect_deltas.csv"), npoints_deltas)
    CSV.write(joinpath(phase_dir, "trajectory_effect_deltas.csv"), traj_deltas)

    all_deltas = vcat(mode_deltas, noise_deltas, npoints_deltas, traj_deltas)
    summary = _effect_summary(all_deltas)
    CSV.write(joinpath(phase_dir, "effect_summary.csv"), summary)

    _plot_effect_summary(summary, "mode", joinpath(phase_dir, "mode_effect_plot.png"))
    _plot_effect_summary(summary, "noise", joinpath(phase_dir, "noise_effect_plot.png"))
    _plot_effect_summary(summary, "n_points", joinpath(phase_dir, "npoints_effect_plot.png"))
    _plot_effect_summary(summary, "trajectories", joinpath(phase_dir, "trajectory_effect_plot.png"))

    lines = String[]
    push!(lines, "Phase 2 Report - Main Effects")
    push!(lines, "")
    push!(lines, "Rows analyzed: $(nrow(df_analysis))")
    push!(lines, "Delta rows (mode): $(nrow(mode_deltas))")
    push!(lines, "Delta rows (noise): $(nrow(noise_deltas))")
    push!(lines, "Delta rows (n_points): $(nrow(npoints_deltas))")
    push!(lines, "Delta rows (trajectories): $(nrow(traj_deltas))")
    push!(lines, "")

    if nrow(summary) > 0
        for r in eachrow(sort(summary, [:factor, :transition, :metric]))
            push!(lines, "- $(r.factor) $(r.transition) $(r.metric): median_delta=$(r.median_delta)")
        end
    end

    write_text_report(joinpath(phase_dir, "report.txt"), lines)

    return (summary = summary, deltas = all_deltas)
end
