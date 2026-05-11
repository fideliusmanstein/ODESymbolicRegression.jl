if !isdefined(Main, :write_text_report)
    include(joinpath(@__DIR__, "common.jl"))
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

"""
    _finite_times(df) -> Vector{Float64}

Extract finite, positive discovery_time values from a DataFrame subset.
"""
function _finite_times(df::DataFrame)
    filter(x -> isfinite(x) && x > 0.0, Float64.(df.discovery_time))
end

"""
    _box_stats(v) -> NamedTuple

Compute five-number summary + mean for a vector of floats.
"""
function _box_stats(v::Vector{Float64})
    isempty(v) && return (q0=NaN, q1=NaN, q2=NaN, q3=NaN, q4=NaN, mean=NaN, n=0)
    sv = sort(v)
    n  = length(sv)
    q1 = sv[max(1, round(Int, 0.25 * n))]
    q2 = median(sv)
    q3 = sv[min(n, round(Int, 0.75 * n))]
    (q0=sv[1], q1=q1, q2=q2, q3=q3, q4=sv[end], mean=mean(sv), n=n)
end

"""
    _draw_boxplot!(ax, positions, groups; color, label)

Manual box-and-whisker overlay on a CairoMakie Axis.
`groups` is a Vector{Vector{Float64}}, `positions` a Vector{Real} of x positions.
"""
function _draw_boxplot!(ax, positions, groups;
                        color = :steelblue, label = nothing, width = 0.5)
    for (xpos, vals) in zip(positions, groups)
        isempty(vals) && continue
        s = _box_stats(vals)
        hw = width / 2

        # IQR whiskers (capped at 1.5×IQR or min/max)
        iqr = s.q3 - s.q1
        lo_fence = max(s.q0, s.q1 - 1.5 * iqr)
        hi_fence = min(s.q4, s.q3 + 1.5 * iqr)

        # Box
        poly!(ax,
            [xpos - hw, xpos + hw, xpos + hw, xpos - hw, xpos - hw],
            [s.q1, s.q1, s.q3, s.q3, s.q1];
            color = (color, 0.25), strokecolor = color, strokewidth = 1.5)

        # Median line
        lines!(ax, [xpos - hw, xpos + hw], [s.q2, s.q2];
               color = color, linewidth = 2.5)

        # Whiskers
        lines!(ax, [xpos, xpos], [s.q1, lo_fence]; color = color, linewidth = 1.2)
        lines!(ax, [xpos, xpos], [s.q3, hi_fence]; color = color, linewidth = 1.2)
        lines!(ax, [xpos - hw*0.4, xpos + hw*0.4], [lo_fence, lo_fence];
               color = color, linewidth = 1.2)
        lines!(ax, [xpos - hw*0.4, xpos + hw*0.4], [hi_fence, hi_fence];
               color = color, linewidth = 1.2)

        # Mean dot
        scatter!(ax, [xpos], [s.mean]; color = color, markersize = 7, marker = :diamond)

        # Outliers
        outliers = filter(v -> v < lo_fence || v > hi_fence, vals)
        if !isempty(outliers)
            scatter!(ax, fill(Float64(xpos), length(outliers)), Float64.(outliers);
                     color = (color, 0.5), markersize = 5, marker = :circle)
        end
    end

    # Invisible dummy for legend (only if label provided)
    if label !== nothing
        lines!(ax, Float64[], Float64[]; color = color, linewidth = 2, label = label)
    end
end

# ---------------------------------------------------------------------------
# Plot 1: effect of n_points on discovery time
# ---------------------------------------------------------------------------

function _plot_npoints_effect(df::DataFrame, phase_dir::AbstractString)
    pts_levels = sort(unique(df.n_points))
    isempty(pts_levels) && return

    fig = Figure(size = (800, 480))
    ax  = Axis(fig[1, 1];
        title   = "Effect of n_points on discovery time",
        xlabel  = "Number of observation points",
        ylabel  = "Discovery time (s)",
        xticks  = (1:length(pts_levels), string.(pts_levels)),
    )

    groups = [_finite_times(filter(r -> r.n_points == p, df)) for p in pts_levels]
    _draw_boxplot!(ax, 1:length(pts_levels), groups; color = :steelblue)

    # Overlay per-noise medians as a line plot to show trend
    noise_levels = sort(unique(df.noise))
    palette = [:crimson, :darkorange, :forestgreen, :purple]
    for (ni, noise) in enumerate(noise_levels)
        medians = Float64[]
        for p in pts_levels
            sub = filter(r -> r.n_points == p && r.noise == noise, df)
            t = _finite_times(sub)
            push!(medians, isempty(t) ? NaN : median(t))
        end
        any(isfinite, medians) || continue
        c = palette[mod1(ni, length(palette))]
        lines!(ax, 1:length(pts_levels), medians;
               color = c, linewidth = 1.5, linestyle = :dash,
               label = "noise=$(noise)")
        scatter!(ax, 1:length(pts_levels), medians; color = c, markersize = 6)
    end

    axislegend(ax; position = :lt, labelsize = 10)
    save_plot(fig, joinpath(phase_dir, "npoints_effect.png"))
end

# ---------------------------------------------------------------------------
# Plot 2: effect of num_trajectories on discovery time
# ---------------------------------------------------------------------------

function _plot_trajectories_effect(df::DataFrame, phase_dir::AbstractString)
    traj_levels = sort(unique(df.trajectories))
    isempty(traj_levels) && return

    fig = Figure(size = (700, 480))
    ax  = Axis(fig[1, 1];
        title   = "Effect of number of trajectories on discovery time",
        xlabel  = "Number of trajectories",
        ylabel  = "Discovery time (s)",
        xticks  = (1:length(traj_levels), string.(traj_levels)),
    )

    groups = [_finite_times(filter(r -> r.trajectories == t, df)) for t in traj_levels]
    _draw_boxplot!(ax, 1:length(traj_levels), groups; color = :teal)

    # Per-n_points trend lines
    pts_levels = sort(unique(df.n_points))
    palette    = [:steelblue, :darkorange, :crimson]
    for (pi, pts) in enumerate(pts_levels)
        medians = Float64[]
        for t in traj_levels
            sub = filter(r -> r.trajectories == t && r.n_points == pts, df)
            tv  = _finite_times(sub)
            push!(medians, isempty(tv) ? NaN : median(tv))
        end
        any(isfinite, medians) || continue
        c = palette[mod1(pi, length(palette))]
        lines!(ax, 1:length(traj_levels), medians;
               color = c, linewidth = 1.5, linestyle = :dash, label = "n_pts=$(pts)")
        scatter!(ax, 1:length(traj_levels), medians; color = c, markersize = 6)
    end

    axislegend(ax; position = :lt, labelsize = 10)
    save_plot(fig, joinpath(phase_dir, "trajectories_effect.png"))
end

# ---------------------------------------------------------------------------
# Plot 3: effect of selection method on discovery time
# ---------------------------------------------------------------------------
#
# "knee"   = knee_point combination + stage 2 SR (niterations_integration=100)
# "search" = combination_search      + no stage 2 (niterations_integration=0)
#
# To make the stage-1 component comparable, we note that `search` times are
# stage-1-only by construction (niterations_integration=0).
# For each matched pair (same noise, n_points, trajectories, problem), we
# decompose knee_time into:
#   stage1_est = search_time            (same niter_derivative=150)
#   stage2_est = knee_time - search_time (everything added by stage 2 + knee overhead)
# This is an approximation; the combination step is also different between modes.

function _plot_selection_method_effect(df::DataFrame, phase_dir::AbstractString)
    modes = sort(unique(df.mode))
    length(modes) < 2 && begin
        @warn "phase9: fewer than 2 modes available; skipping selection method plot"
        return
    end

    # --- per-problem matched pairs ---
    knee_df   = filter(r -> r.mode == "knee",   df)
    search_df = filter(r -> r.mode == "search", df)

    match_cols = [:noise, :n_points, :trajectories, :problem]
    joined = innerjoin(
        rename(select(knee_df,   vcat(match_cols, [:discovery_time])),
               :discovery_time => :time_knee),
        rename(select(search_df, vcat(match_cols, [:discovery_time])),
               :discovery_time => :time_search),
        on = match_cols,
    )

    filter!(r -> isfinite(r.time_knee) && isfinite(r.time_search), joined)

    if nrow(joined) == 0
        @warn "phase9: no matched knee/search pairs found; skipping selection method plot"
        return
    end

    joined.stage2_est = max.(joined.time_knee .- joined.time_search, 0.0)

    # --- Figure with 2 subplots ---
    fig = Figure(size = (1000, 500))

    # Left: total discovery time side-by-side
    ax1 = Axis(fig[1, 1];
        title   = "Total discovery time by selection method",
        xlabel  = "Mode",
        ylabel  = "Discovery time (s)",
        xticks  = ([1, 2], ["knee\n(+stage 2 SR)", "search\n(stage 1 only)"]),
    )
    g_knee   = _finite_times(filter(r -> r.mode == "knee",   df))
    g_search = _finite_times(filter(r -> r.mode == "search", df))
    _draw_boxplot!(ax1, [1, 2], [g_knee, g_search];
                   color = :steelblue, label = nothing, width = 0.55)
    # per-group median labels
    for (xp, vals) in [(1, g_knee), (2, g_search)]
        isempty(vals) && continue
        m = median(vals)
        text!(ax1, xp + 0.3, m; text = string(round(m; digits=1)) * "s",
              fontsize = 10, align = (:left, :center))
    end

    # Right: stacked bar showing estimated stage-1 vs stage-2 contribution
    ax2 = Axis(fig[1, 2];
        title   = "Estimated stage-1 vs stage-2 time\n(matched problem pairs)",
        xlabel  = "Mode",
        ylabel  = "Discovery time (s)",
        xticks  = ([1, 2], ["knee", "search"]),
    )

    med_search     = median(joined.time_search)
    med_stage2_est = median(joined.stage2_est)
    med_knee_stage1_est = med_search   # stage 1 same across modes (same niter_deriv)

    # search bar: all stage 1
    barplot!(ax2, [2], [med_search];
             color = :steelblue, label = "Stage 1 (est.)")
    # knee bar: stage 1 + stage 2
    barplot!(ax2, [1], [med_knee_stage1_est];
             color = :steelblue)
    barplot!(ax2, [1], [med_stage2_est];
             color = :crimson, offset = [med_knee_stage1_est], label = "Stage 2 overhead (est.)")

    axislegend(ax2; position = :lt, labelsize = 10)

    Label(fig[2, 1:2],
        "Note: stage-2 overhead is estimated as (knee_time − search_time) per matched problem pair.\n" *
        "Both modes use niterations_derivative=150. Combination step overhead is included in the estimate.",
        fontsize = 9, tellwidth = false)

    save_plot(fig, joinpath(phase_dir, "selection_method_effect.png"))

    return joined
end

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

function run_phase9(df_analysis::DataFrame, output_dir::AbstractString)
    phase_dir = joinpath(output_dir, "phase9")
    mkpath(phase_dir)

    if nrow(df_analysis) == 0
        @warn "phase9: empty dataframe; skipping"
        return nothing
    end

    # Work with finite discovery times only
    df = filter(r -> isfinite(r.discovery_time) && r.discovery_time > 0, df_analysis)

    report_lines = String[
        "Phase 9 Report - Discovery Time Effects",
        "",
        "Rows used: $(nrow(df))  (from $(nrow(df_analysis)) total, $(nrow(df_analysis)-nrow(df)) dropped as non-finite/zero)",
        "",
        "Unique n_points values    : $(sort(unique(df.n_points)))",
        "Unique trajectories values: $(sort(unique(df.trajectories)))",
        "Unique modes              : $(sort(unique(df.mode)))",
        "",
    ]

    # --- Plot 1: n_points ---
    println("[phase9] plotting n_points effect")
    _plot_npoints_effect(df, phase_dir)
    push!(report_lines, "Plot 1: npoints_effect.png")

    # Median by n_points
    for pts in sort(unique(df.n_points))
        sub = filter(r -> r.n_points == pts, df)
        t   = _finite_times(sub)
        push!(report_lines, "  n_points=$(pts): n=$(length(t))  median=$(round(isempty(t) ? NaN : median(t); digits=1))s  mean=$(round(isempty(t) ? NaN : mean(t); digits=1))s")
    end
    push!(report_lines, "")

    # --- Plot 2: trajectories ---
    println("[phase9] plotting trajectories effect")
    _plot_trajectories_effect(df, phase_dir)
    push!(report_lines, "Plot 2: trajectories_effect.png")

    for traj in sort(unique(df.trajectories))
        sub = filter(r -> r.trajectories == traj, df)
        t   = _finite_times(sub)
        push!(report_lines, "  trajectories=$(traj): n=$(length(t))  median=$(round(isempty(t) ? NaN : median(t); digits=1))s  mean=$(round(isempty(t) ? NaN : mean(t); digits=1))s")
    end
    push!(report_lines, "")

    # --- Plot 3: selection method ---
    println("[phase9] plotting selection method effect")
    matched = _plot_selection_method_effect(df, phase_dir)
    push!(report_lines, "Plot 3: selection_method_effect.png")

    for mode in sort(unique(df.mode))
        sub = filter(r -> r.mode == mode, df)
        t   = _finite_times(sub)
        push!(report_lines, "  mode=$(mode): n=$(length(t))  median=$(round(isempty(t) ? NaN : median(t); digits=1))s  mean=$(round(isempty(t) ? NaN : mean(t); digits=1))s")
    end

    if matched !== nothing && nrow(matched) > 0
        push!(report_lines, "")
        push!(report_lines, "  Matched pairs: $(nrow(matched))")
        push!(report_lines, "  Median search time (stage 1):       $(round(median(matched.time_search); digits=1))s")
        push!(report_lines, "  Median knee time (stage 1+2):       $(round(median(matched.time_knee); digits=1))s")
        push!(report_lines, "  Median estimated stage-2 overhead:  $(round(median(matched.stage2_est); digits=1))s")
        push!(report_lines, "  Stage-2 fraction of knee time:      $(round(100*median(matched.stage2_est)/median(matched.time_knee); digits=1))%")
    end
    push!(report_lines, "")
    push!(report_lines, "Note: per-stage timing (time_stage1, time_stage2_sr) is available only in")
    push!(report_lines, "runs produced after the timing instrumentation was added to discovery.jl.")
    push!(report_lines, "The current estimate uses (knee_time - search_time) as a proxy for stage-2 overhead.")

    write_text_report(joinpath(phase_dir, "report.txt"), report_lines)
    return nothing
end
