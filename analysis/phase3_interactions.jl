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

"""
    _plot_noise_npoints_heatmap(df, phase_dir)

Heatmap of median avg_r² (and discovery time) with noise on y-axis and
n_points on x-axis.  One panel per combination method.  Contour lines at
R²=0.8 and R²=0.95 mark the compensation boundary.
"""
function _plot_noise_npoints_heatmap(df::DataFrame, phase_dir::AbstractString)
    traj_panels  = sort(unique(df.trajectories))
    npoints_vals = sort(unique(df.n_points))
    noise_vals   = sort(unique(df.noise))

    n_panels = length(traj_panels)
    nx = length(npoints_vals)
    ny = length(noise_vals)

    npoints_idx = Dict(v => i for (i, v) in enumerate(npoints_vals))
    noise_idx   = Dict(v => i for (i, v) in enumerate(noise_vals))

    for (metric, col, fig_label, cmap) in [
            (:avg_r2,         :avg_r2,         "Median avg R²: noise vs n\\_points",          :viridis),
            (:discovery_time, :discovery_time,  "Median discovery time (s)", :plasma),
        ]

        fig = Figure(size = (420 * n_panels + 100, 400))
        Label(fig[0, 1:n_panels], fig_label; fontsize = 14, tellwidth = false)

        all_vals   = Float64[]
        cell_data  = Dict{Any, Matrix{Float64}}()

        for t in traj_panels
            sub = filter(r -> r.trajectories == t, df)
            mat = fill(NaN, ny, nx)
            grp = combine(groupby(sub, [:n_points, :noise]),
                col => median => :val)
            for row in eachrow(grp)
                xi = get(npoints_idx, row.n_points, nothing)
                yi = get(noise_idx,   row.noise,    nothing)
                (xi === nothing || yi === nothing) && continue
                v = Float64(row.val)
                isfinite(v) && push!(all_vals, v)
                mat[yi, xi] = v
            end
            cell_data[t] = mat
        end

        clo = isempty(all_vals) ? 0.0 : minimum(all_vals)
        chi = isempty(all_vals) ? 1.0 : maximum(all_vals)

        for (mi, t) in enumerate(traj_panels)
            mat = cell_data[t]
            ax = Axis(fig[1, mi];
                title   = "trajectories = $t",
                xlabel  = "n_points",
                ylabel  = mi == 1 ? "noise" : "",
                xticks  = (1:nx, string.(npoints_vals)),
                yticks  = (1:ny, string.(noise_vals)),
            )
            hm = heatmap!(ax, 1:nx, 1:ny, mat';
                colormap   = cmap,
                colorrange = (clo, chi),
            )

            # Annotate each cell with its value
            for xi in 1:nx, yi in 1:ny
                v = mat[yi, xi]
                isfinite(v) || continue
                txt = metric == :discovery_time ? string(round(Int, v)) :
                                                  string(round(v; digits = 2))
                brightness = (v - clo) / max(chi - clo, 1e-9)
                text!(ax, xi, yi; text = txt,
                    align    = (:center, :center),
                    fontsize = 10,
                    color    = brightness > 0.6 ? :black : :white)
            end

            # Contour lines at R²=0.8 and R²=0.95 for avg_r2 only
            if metric == :avg_r2
                xs_c = Float64.(1:nx)
                ys_c = Float64.(1:ny)
                for threshold in [0.8, 0.95]
                    if clo < threshold < chi
                        contour!(ax, xs_c, ys_c, mat';
                            levels    = [threshold],
                            color     = :white,
                            linewidth = 2,
                            linestyle = :dash,
                        )
                    end
                end
            end

            if mi == n_panels
                Colorbar(fig[1, n_panels + 1], hm)
            end
        end

        outpath = joinpath(phase_dir, "noise_npoints_heatmap_$(metric).png")
        save_plot(fig, outpath)
    end
end

"""
    _plot_hp_heatmaps(df, phase_dir)

Two figures (avg_r2 and discovery_time), each with one heatmap panel per
combination method.  Axes: n_points (x) × trajectories (y).
"""
function _plot_hp_heatmaps(df::DataFrame, phase_dir::AbstractString)
    methods   = sort(unique(df.mode))
    npoints_vals = sort(unique(df.n_points))
    traj_vals    = sort(unique(df.trajectories))

    n_methods = length(methods)
    nx = length(npoints_vals)
    ny = length(traj_vals)

    npoints_idx = Dict(v => i for (i, v) in enumerate(npoints_vals))
    traj_idx    = Dict(v => i for (i, v) in enumerate(traj_vals))

    for (metric, col, label, cmap) in [
            (:avg_r2,        :avg_r2,        "Median avg R²",         :viridis),
            (:discovery_time, :discovery_time, "Median discovery time (s)", :plasma),
        ]

        fig = Figure(size = (420 * n_methods + 80, 400))
        Label(fig[0, 1:n_methods], label; fontsize = 14, tellwidth = false)

        # Compute global colour range across all methods for consistent scale
        all_vals = Float64[]
        cell_data = Dict{String, Matrix{Float64}}()
        for m in methods
            sub = filter(r -> r.mode == m, df)
            mat = fill(NaN, ny, nx)
            grp = combine(groupby(sub, [:n_points, :trajectories]),
                col => median => :val)
            for row in eachrow(grp)
                xi = get(npoints_idx, row.n_points, nothing)
                yi = get(traj_idx,    row.trajectories, nothing)
                (xi === nothing || yi === nothing) && continue
                v = Float64(row.val)
                isfinite(v) && push!(all_vals, v)
                mat[yi, xi] = v
            end
            cell_data[m] = mat
        end

        clo = isempty(all_vals) ? 0.0 : minimum(all_vals)
        chi = isempty(all_vals) ? 1.0 : maximum(all_vals)

        for (mi, m) in enumerate(methods)
            mat = cell_data[m]
            ax = Axis(fig[1, mi];
                title   = string(m),
                xlabel  = "n_points",
                ylabel  = mi == 1 ? "trajectories" : "",
                xticks  = (1:nx, string.(npoints_vals)),
                yticks  = (1:ny, string.(traj_vals)),
            )
            hm = heatmap!(ax, 1:nx, 1:ny, mat';
                colormap = cmap,
                colorrange = (clo, chi),
            )
            # Annotate cells with the numeric value
            for xi in 1:nx, yi in 1:ny
                v = mat[yi, xi]
                isfinite(v) || continue
                txt = metric == :discovery_time ? string(round(Int, v)) : string(round(v; digits=2))
                text!(ax, xi, yi; text = txt,
                    align = (:center, :center),
                    fontsize = 10,
                    color = (v - clo) / max(chi - clo, 1e-9) > 0.6 ? :black : :white)
            end
            if mi == n_methods
                Colorbar(fig[1, n_methods + 1], hm)
            end
        end

        outpath = joinpath(phase_dir, "hp_heatmap_$(metric).png")
        save_plot(fig, outpath)
    end
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

    _plot_hp_heatmaps(df_analysis, phase_dir)
    push!(lines, "")
    push!(lines, "Heatmaps: hp_heatmap_avg_r2.png, hp_heatmap_discovery_time.png")

    _plot_noise_npoints_heatmap(df_analysis, phase_dir)
    push!(lines, "Noise×n_points heatmaps: noise_npoints_heatmap_avg_r2.png, noise_npoints_heatmap_discovery_time.png")

    write_text_report(joinpath(phase_dir, "report.txt"), lines)
    return nothing
end
