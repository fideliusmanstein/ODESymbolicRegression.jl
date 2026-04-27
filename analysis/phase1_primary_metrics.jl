if !isdefined(Main, :summarize_combo_metrics)
    include(joinpath(@__DIR__, "common.jl"))
end

function run_phase1(manifest::DataFrame, df_all::DataFrame, output_dir::AbstractString)
    phase_dir = joinpath(output_dir, "phase1")
    mkpath(phase_dir)

    df_strict = strict_dataset(manifest, df_all)
    df_common = common_subset_dataset(df_strict)

    summary_strict = summarize_combo_metrics(df_strict)
    summary_common = summarize_combo_metrics(df_common)

    CSV.write(joinpath(phase_dir, "combo_summary_strict.csv"), summary_strict)
    CSV.write(joinpath(phase_dir, "combo_summary_common_subset.csv"), summary_common)

    top_quality = sort(summary_strict, [:median_avg_r2, :median_min_r2], rev = true)
    top_speed = sort(summary_strict, :median_discovery_time)

    CSV.write(joinpath(phase_dir, "top_quality_table.csv"), top_quality)
    CSV.write(joinpath(phase_dir, "top_speed_table.csv"), top_speed)

    # Plot: quality vs runtime scatter
    fig1 = Figure(size = (900, 600))
    ax1 = Axis(fig1[1, 1],
        title = "Strict Dataset: Quality vs Runtime",
        xlabel = "Median discovery time (s)",
        ylabel = "Median avg_r2")
    scatter!(ax1, summary_strict.median_discovery_time, summary_strict.median_avg_r2)
    save_plot(fig1, joinpath(phase_dir, "quality_vs_runtime_scatter.png"))

    # Plot: top 12 median R2 by combo
    n_show = min(12, nrow(top_quality))
    shown = top_quality[1:n_show, :]
    xs = 1:n_show
    ys = shown.median_avg_r2
    labels = [combo_label(r) for r in eachrow(shown)]

    fig2 = Figure(size = (1300, 600))
    ax2 = Axis(fig2[1, 1],
        title = "Top Combinations by Median avg_r2 (strict)",
        xlabel = "Combination",
        ylabel = "Median avg_r2")
    barplot!(ax2, xs, ys)
    ax2.xticks = (xs, labels)
    ax2.xticklabelrotation = pi / 4
    save_plot(fig2, joinpath(phase_dir, "median_r2_by_combo.png"))

    lines = String[]
    push!(lines, "Phase 1 Report - Primary Outcome Metrics")
    push!(lines, "")
    push!(lines, "Strict dataset runs: $(length(unique(df_strict.run_key)))")
    push!(lines, "Strict dataset rows: $(nrow(df_strict))")
    push!(lines, "Common-subset rows: $(nrow(df_common))")
    push!(lines, "Common-subset problems: $(length(unique(df_common.problem)))")
    push!(lines, "")

    if nrow(top_quality) > 0
        best = top_quality[1, :]
        push!(lines, "Best quality run (strict): $(best.run_key)")
        push!(lines, "- median_avg_r2=$(best.median_avg_r2)")
        push!(lines, "- median_min_r2=$(best.median_min_r2)")
        push!(lines, "- median_discovery_time=$(best.median_discovery_time)")
    end

    if nrow(top_speed) > 0
        fastest = top_speed[1, :]
        push!(lines, "")
        push!(lines, "Fastest run (strict): $(fastest.run_key)")
        push!(lines, "- median_discovery_time=$(fastest.median_discovery_time)")
        push!(lines, "- median_avg_r2=$(fastest.median_avg_r2)")
    end

    write_text_report(joinpath(phase_dir, "report.txt"), lines)

    return (
        df_strict = df_strict,
        df_common = df_common,
        summary_strict = summary_strict,
        summary_common = summary_common,
    )
end
