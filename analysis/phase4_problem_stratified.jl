if !isdefined(Main, :write_text_report)
    include(joinpath(@__DIR__, "common.jl"))
end

function run_phase4(df_analysis::DataFrame, output_dir::AbstractString)
    phase_dir = joinpath(output_dir, "phase4")
    mkpath(phase_dir)

    df = copy(df_analysis)
    df.state_bucket = assign_state_bucket.(df.n_states)

    stratified = combine(groupby(df, [:run_key, :mode, :noise, :n_points, :trajectories, :state_bucket]),
        :avg_r2 => median => :median_avg_r2,
        :min_r2 => median => :median_min_r2,
        :discovery_time => median => :median_discovery_time,
        nrow => :n_rows)
    CSV.write(joinpath(phase_dir, "stratified_summary.csv"), stratified)

    best_by_bucket = combine(groupby(stratified, :state_bucket)) do g
        i = argmax(g.median_avg_r2)
        return g[i, :]
    end
    CSV.write(joinpath(phase_dir, "stratified_best_by_bucket.csv"), best_by_bucket)

    # Plot: average per mode by bucket
    mode_bucket = combine(groupby(df, [:mode, :state_bucket]),
        :avg_r2 => median => :median_avg_r2)

    buckets = ["2-3", "4-5", "6+"]
    modes = sort(unique(mode_bucket.mode))

    fig = Figure(size = (900, 600))
    ax = Axis(fig[1, 1],
        title = "Problem-stratified performance by mode",
        xlabel = "State bucket",
        ylabel = "Median avg_r2")

    xpos = 1:length(buckets)
    width = 0.35
    offsets = length(modes) == 1 ? [0.0] : collect(range(-width / 2, width / 2, length = length(modes)))

    for (j, mode) in enumerate(modes)
        ys = Float64[]
        for b in buckets
            row = filter(r -> r.mode == mode && r.state_bucket == b, mode_bucket)
            push!(ys, nrow(row) == 0 ? NaN : row.median_avg_r2[1])
        end
        barplot!(ax, xpos .+ offsets[j], ys, width = width / length(modes), label = mode)
    end

    ax.xticks = (xpos, buckets)
    axislegend(ax)
    save_plot(fig, joinpath(phase_dir, "stratified_r2_plot.png"))

    lines = String[]
    push!(lines, "Phase 4 Report - Problem-Stratified Performance")
    push!(lines, "")
    for r in eachrow(best_by_bucket)
        push!(lines, "Best for bucket $(r.state_bucket): $(r.run_key) (median_avg_r2=$(r.median_avg_r2))")
    end

    write_text_report(joinpath(phase_dir, "report.txt"), lines)
    return stratified
end
