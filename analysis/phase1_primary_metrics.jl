if !isdefined(Main, :summarize_combo_metrics)
    include(joinpath(@__DIR__, "common.jl"))
end

using JSON

# ---------------------------------------------------------------------------
# Helper: count functions with R² ≥ 0.95 per run
# ---------------------------------------------------------------------------

"""
    _count_high_r2_functions(manifest) -> DataFrame

Count how many equations across all problems in each run have R² ≥ 0.95.
Returns DataFrame with columns: run_key, count_r2_95
"""
function _count_high_r2_functions(manifest::DataFrame)
    run_counts = Dict{String, Int}()

    for row in eachrow(manifest)
        (row.has_json && row.completed_run) || continue

        json_data = try
            JSON.parsefile(row.json_path)
        catch
            continue
        end

        run_key_str = String(row.run_key)
        for (problem, pdata) in json_data
            scores_raw = get(pdata, "equation_scores", nothing)
            scores_raw === nothing && continue
            
            r2_scores = Float64[get(s, "r2", NaN) for s in scores_raw]
            count_95 = count(r2 -> isfinite(r2) && r2 >= 0.95, r2_scores)
            
            if !haskey(run_counts, run_key_str)
                run_counts[run_key_str] = 0
            end
            run_counts[run_key_str] += count_95
        end
    end

    sort_order = sortperm(collect(values(run_counts)); rev=true)
    run_keys = collect(keys(run_counts))[sort_order]
    counts = collect(values(run_counts))[sort_order]
    
    return DataFrame(run_key = run_keys, count_r2_95 = counts)
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

    # Plot: top 12 median integration loss by combo (lower = better)
    top_loss = sort(
        filter(r -> isfinite(r.median_integration_loss), summary_strict),
        :median_integration_loss,
    )
    n_show_loss = min(12, nrow(top_loss))
    if n_show_loss > 0
        shown_loss = top_loss[1:n_show_loss, :]
        xs_l = 1:n_show_loss
        ys_l = shown_loss.median_integration_loss
        labels_l = [combo_label(r) for r in eachrow(shown_loss)]

        fig3 = Figure(size = (1300, 600))
        ax3 = Axis(fig3[1, 1],
            title = "Best Combinations by Median Integration Loss (strict, lower = better)",
            xlabel = "Combination",
            ylabel = "Median integration loss",
            yscale = log10)
        barplot!(ax3, xs_l, ys_l)
        ax3.xticks = (xs_l, labels_l)
        ax3.xticklabelrotation = pi / 4
        save_plot(fig3, joinpath(phase_dir, "median_integration_loss_by_combo.png"))
    end

    # Plot: count of functions with R² ≥ 0.95 per run
    df_r2_counts = _count_high_r2_functions(manifest)
    if nrow(df_r2_counts) > 0
        n_show_r2 = min(20, nrow(df_r2_counts))
        shown_r2 = df_r2_counts[1:n_show_r2, :]
        xs_r2 = 1:n_show_r2
        ys_r2 = shown_r2.count_r2_95
        labels_r2 = shown_r2.run_key

        fig4 = Figure(size = (1400, 600))
        ax4 = Axis(fig4[1, 1],
            title = "Number of Functions with R² ≥ 0.95 per Run (all problems)",
            xlabel = "Run",
            ylabel = "Count of functions with R² ≥ 0.95")
        barplot!(ax4, xs_r2, ys_r2)
        ax4.xticks = (xs_r2, labels_r2)
        ax4.xticklabelrotation = pi / 4
        save_plot(fig4, joinpath(phase_dir, "count_r2_095_by_run.png"))
    end

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
