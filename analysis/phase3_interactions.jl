if !isdefined(Main, :write_text_report)
    include(joinpath(@__DIR__, "common.jl"))
end

function _interaction_summary(df::DataFrame, x::Symbol, g::Symbol)
    combine(groupby(df, [x, g]),
        :avg_r2 => median => :median_avg_r2,
        :discovery_time => median => :median_discovery_time,
        nrow => :n_rows)
end

function _plot_interaction_avg_r2(summary::DataFrame, x::Symbol, g::Symbol, outpath::AbstractString)
    fig = Figure(size = (900, 600))

    all_xvals  = sort(unique(summary[!, x]))
    all_groups = sort(unique(summary[!, g]))
    n_x = length(all_xvals)
    xval_to_pos = Dict(v => i for (i, v) in enumerate(all_xvals))

    xs_full = collect(1:n_x)

    ax = Axis(fig[1, 1],
        title  = "Interaction: $(g) × $(x) (median avg_r2)",
        xlabel = String(x),
        ylabel = "median avg_r2",
        xticks = (xs_full, string.(all_xvals)))

    for grp in all_groups
        sub = filter(r -> getproperty(r, g) == grp, summary)
        # Build a full-length y vector; NaN where this group has no data.
        # Makie treats NaN as a break in the line, so missing combos show as gaps.
        ys = fill(NaN, n_x)
        for row in eachrow(sub)
            pos = xval_to_pos[getproperty(row, x)]
            ys[pos] = row.median_avg_r2
        end
        lines!(ax, xs_full, ys, label = string(grp))
        valid = .!isnan.(ys)
        scatter!(ax, xs_full[valid], ys[valid])
    end

    axislegend(ax)
    save_plot(fig, outpath)
end

function run_phase3(df_analysis::DataFrame, output_dir::AbstractString)
    phase_dir = joinpath(output_dir, "phase3")
    mkpath(phase_dir)

    interactions = [
        (:noise, :mode, "mode_x_noise"),
        (:n_points, :mode, "mode_x_npoints"),
        (:trajectories, :mode, "mode_x_trajectories"),
        (:noise, :n_points, "npoints_x_noise"),
        (:noise, :trajectories, "trajectories_x_noise"),
    ]

    lines = String[]
    push!(lines, "Phase 3 Report - Interaction Analysis")
    push!(lines, "")

    for (x, g, name) in interactions
        summary = _interaction_summary(df_analysis, x, g)
        CSV.write(joinpath(phase_dir, "interaction_$(name).csv"), summary)
        _plot_interaction_avg_r2(summary, x, g, joinpath(phase_dir, "interaction_$(name).png"))

        push!(lines, "Interaction $(name): $(nrow(summary)) grouped rows")
    end

    write_text_report(joinpath(phase_dir, "report.txt"), lines)
    return nothing
end
