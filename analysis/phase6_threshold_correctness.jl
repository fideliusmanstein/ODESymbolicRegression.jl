if !isdefined(Main, :write_text_report)
    include(joinpath(@__DIR__, "common.jl"))
end

using JSON

const CORRECTNESS_R2_THRESHOLDS = [0.95, 0.80, 0.50]

_threshold_tag(t::Real) = replace(string(t), "." => "_")

function _correctness_long_table(df::DataFrame; thresholds = CORRECTNESS_R2_THRESHOLDS)
    rows = NamedTuple[]

    for row in eachrow(df)
        state_bucket = assign_state_bucket(row.n_states)
        for threshold in thresholds
            problem_correct = row.avg_r2 >= threshold
            fully_correct = row.min_r2 >= threshold

            push!(rows, (
                run_key = row.run_key,
                mode = row.mode,
                noise = row.noise,
                n_points = row.n_points,
                trajectories = row.trajectories,
                problem = row.problem,
                n_states = row.n_states,
                state_bucket = state_bucket,
                threshold = threshold,
                avg_r2 = row.avg_r2,
                min_r2 = row.min_r2,
                problem_correct = problem_correct,
                fully_correct = fully_correct,
                fully_correct_state_count = fully_correct ? row.n_states : 0,
            ))
        end
    end

    if isempty(rows)
        return DataFrame()
    end

    return sort!(DataFrame(rows), [:threshold, :mode, :noise, :n_points, :trajectories, :problem])
end

function _summarize_correctness(g::AbstractDataFrame)
    n_items = nrow(g)
    n_states_total = sum(g.n_states)
    n_problem_correct = sum(g.problem_correct)
    n_fully_correct = sum(g.fully_correct)
    n_states_in_fully_correct = sum(g.fully_correct_state_count)

    return (
        n_items = n_items,
        n_states_total = n_states_total,
        n_problem_correct = n_problem_correct,
        problem_correct_rate = n_items == 0 ? NaN : n_problem_correct / n_items,
        n_fully_correct = n_fully_correct,
        fully_correct_rate = n_items == 0 ? NaN : n_fully_correct / n_items,
        n_states_in_fully_correct = n_states_in_fully_correct,
        fully_correct_state_fraction = n_states_total == 0 ? NaN : n_states_in_fully_correct / n_states_total,
    )
end

function _group_correctness(df::DataFrame, keys)
    if nrow(df) == 0
        return DataFrame()
    end

    summary = combine(groupby(df, keys)) do g
        _summarize_correctness(g)
    end

    return sort!(summary, keys)
end

function _plot_combo_correctness(summary::DataFrame, threshold::Real, outpath::AbstractString)
    threshold_rows = filter(r -> r.threshold == threshold, summary)
    isempty(threshold_rows) && return nothing

    ranked = sort(threshold_rows, [:problem_correct_rate, :fully_correct_rate], rev = true)
    n_show = min(12, nrow(ranked))
    shown = ranked[1:n_show, :]

    xs = 1:n_show
    labels = [combo_label(r) for r in eachrow(shown)]

    fig = Figure(size = (1400, 650))
    ax = Axis(fig[1, 1],
        title = "Threshold correctness by combination (R² ≥ $(threshold))",
        xlabel = "Combination",
        ylabel = "Rate")

    barplot!(ax, xs .- 0.18, shown.problem_correct_rate, width = 0.32, label = "avg_r2 threshold")
    barplot!(ax, xs .+ 0.18, shown.fully_correct_rate, width = 0.32, label = "min_r2 threshold")
    ax.xticks = (xs, labels)
    ax.xticklabelrotation = pi / 4
    axislegend(ax)
    save_plot(fig, outpath)
end

function _plot_bucket_correctness(summary::DataFrame, threshold::Real, outpath::AbstractString)
    threshold_rows = filter(r -> r.threshold == threshold, summary)
    isempty(threshold_rows) && return nothing

    buckets = ["2-3", "4-5", "6+"]
    rows = combine(groupby(threshold_rows, :state_bucket),
        :problem_correct_rate => mean => :mean_problem_correct_rate,
        :fully_correct_rate => mean => :mean_fully_correct_rate)

    fig = Figure(size = (900, 600))
    ax = Axis(fig[1, 1],
        title = "Threshold correctness by complexity bucket (R² ≥ $(threshold))",
        xlabel = "State bucket",
        ylabel = "Mean rate across combinations")

    xs = 1:length(buckets)
    problem_rates = Float64[]
    fully_rates = Float64[]
    for bucket in buckets
        row = filter(r -> r.state_bucket == bucket, rows)
        push!(problem_rates, nrow(row) == 0 ? NaN : row.mean_problem_correct_rate[1])
        push!(fully_rates, nrow(row) == 0 ? NaN : row.mean_fully_correct_rate[1])
    end

    barplot!(ax, xs .- 0.18, problem_rates, width = 0.32, label = "avg_r2 threshold")
    barplot!(ax, xs .+ 0.18, fully_rates, width = 0.32, label = "min_r2 threshold")
    ax.xticks = (xs, buckets)
    axislegend(ax)
    save_plot(fig, outpath)
end

function _best_run_key_for_threshold(combo_summary::DataFrame, threshold::Real; mode = nothing)
    rows = filter(r -> r.threshold == threshold, combo_summary)
    if mode !== nothing
        rows = filter(r -> r.mode == mode, rows)
    end
    isempty(rows) && return nothing

    ranked = sort(rows, [:n_problem_correct, :n_fully_correct, :problem_correct_rate, :run_key], rev = [true, true, true, false])
    return ranked.run_key[1]
end

function _safe_r2(v)
    try
        return Float64(v)
    catch
        return NaN
    end
end

function _equation_band_rows_from_json(json_path::AbstractString)
    data = JSON.parsefile(json_path)
    rows = NamedTuple[]

    for (problem_name, payload_any) in pairs(data)
        payload = payload_any isa AbstractDict ? payload_any : Dict{String, Any}()

        eq_scores = get(payload, "equation_scores", Any[])
        n_states = Int(get(payload, "n_states", length(eq_scores)))
        n_scores = length(eq_scores)
        n_total = max(n_states, n_scores)
        n_total == 0 && continue

        n95 = 0
        n80 = 0
        n50 = 0
        nbelow = 0

        for s_any in eq_scores
            s = s_any isa AbstractDict ? s_any : Dict{String, Any}()
            r2 = _safe_r2(get(s, "r2", NaN))

            if !isfinite(r2) || r2 < 0.50
                nbelow += 1
            elseif r2 < 0.80
                n50 += 1
            elseif r2 < 0.95
                n80 += 1
            else
                n95 += 1
            end
        end

        # Missing per-equation scores are treated as below-threshold to keep full counts.
        if n_scores < n_total
            nbelow += (n_total - n_scores)
        end

        push!(rows, (
            problem = String(problem_name),
            n_equations = n_total,
            n_r95 = n95,
            n_r80 = n80,
            n_r50 = n50,
            n_below = nbelow,
            r95_frac = n95 / n_total,
            r80_frac = n80 / n_total,
            r50_frac = n50 / n_total,
            below_frac = nbelow / n_total,
        ))
    end

    if isempty(rows)
        return DataFrame()
    end

    return sort!(DataFrame(rows), :problem)
end

function _count_equations_ge_threshold(json_path::AbstractString, threshold::Real)
    data = JSON.parsefile(json_path)
    n = 0

    for (_, payload_any) in pairs(data)
        payload = payload_any isa AbstractDict ? payload_any : Dict{String, Any}()
        eq_scores = get(payload, "equation_scores", Any[])
        for s_any in eq_scores
            s = s_any isa AbstractDict ? s_any : Dict{String, Any}()
            r2 = _safe_r2(get(s, "r2", NaN))
            if isfinite(r2) && r2 >= threshold
                n += 1
            end
        end
    end

    return n
end

function _best_run_by_equation_threshold(manifest::DataFrame, threshold::Real; mode = nothing, noise_values = nothing)
    if nrow(manifest) == 0 || !("json_path" in names(manifest))
        return nothing
    end

    rows = NamedTuple[]
    for row in eachrow(manifest)
        if mode !== nothing && row.mode != mode
            continue
        end

        if noise_values !== nothing && !(row.noise in noise_values)
            continue
        end

        json_path = row.json_path
        if ismissing(json_path) || !isfile(json_path)
            continue
        end

        n_ge = _count_equations_ge_threshold(json_path, threshold)
        push!(rows, (
            run_key = String(row.run_key),
            json_path = String(json_path),
            n_equations_ge_threshold = n_ge,
        ))
    end

    isempty(rows) && return nothing

    ranked = sort!(DataFrame(rows), [:n_equations_ge_threshold, :run_key], rev = [true, false])
    return ranked[1, :]
end

# Stacked bars from one selected run; each problem belongs to exactly one threshold band.
function _plot_problem_stacked_correctness(json_path::AbstractString, selected_run_key::AbstractString, outpath::AbstractString)
    rows = _equation_band_rows_from_json(json_path)
    isempty(rows) && return nothing

    order = sortperm(collect(zip(rows.r95_frac, rows.r80_frac, rows.r50_frac, rows.problem)), rev = true)
    shown = rows[order, :]

    xs = 1:nrow(shown)
    r95 = Float64.(shown.r95_frac)
    r80 = Float64.(shown.r80_frac)
    r50 = Float64.(shown.r50_frac)
    below = Float64.(shown.below_frac)

    fig = Figure(size = (max(900, 40 * nrow(shown)), 620))
    ax = Axis(fig[1, 1],
        title = "Per-problem equation-level threshold bands (best run)",
        subtitle = "run_key = $(selected_run_key)",
        xlabel = "Problem",
        ylabel = "Fraction of equations",
        ytickformat = v -> string.(round.(Int, v .* 100)) .* "%",
        limits = (nothing, (0.0, 1.0)))

    c1 = RGBf(0.20, 0.63, 0.17)
    c2 = RGBf(0.65, 0.84, 0.33)
    c3 = RGBf(0.99, 0.85, 0.35)
    c4 = RGBf(0.84, 0.19, 0.15)

    barplot!(ax, collect(xs), r95, color = c1, label = "R² ≥ 0.95")
    barplot!(ax, collect(xs), r80, color = c2, offset = r95, label = "0.80 ≤ R² < 0.95")
    barplot!(ax, collect(xs), r50, color = c3, offset = r95 .+ r80, label = "0.50 ≤ R² < 0.80")
    barplot!(ax, collect(xs), below, color = c4, offset = r95 .+ r80 .+ r50, label = "R² < 0.50")

    ax.xticks = (collect(xs), String.(shown.problem))
    ax.xticklabelrotation = pi / 3
    ax.xticklabelalign = (:right, :center)
    axislegend(ax, position = :rt, framevisible = true)

    save_plot(fig, outpath)
end

function run_phase6(df_analysis::DataFrame, output_dir::AbstractString; thresholds = CORRECTNESS_R2_THRESHOLDS)
    phase_dir = joinpath(output_dir, "phase6")
    mkpath(phase_dir)

    long_df = _correctness_long_table(df_analysis, thresholds = thresholds)
    CSV.write(joinpath(phase_dir, "correctness_threshold_long.csv"), long_df)

    combo_summary = _group_correctness(long_df, [:run_key, :mode, :noise, :n_points, :trajectories, :threshold])
    problem_summary = _group_correctness(long_df, [:problem, :n_states, :state_bucket, :threshold])
    bucket_summary = _group_correctness(long_df, [:run_key, :mode, :noise, :n_points, :trajectories, :state_bucket, :threshold])
    mode_summary = _group_correctness(long_df, [:mode, :threshold])
    noise_summary = _group_correctness(long_df, [:noise, :threshold])
    points_summary = _group_correctness(long_df, [:n_points, :threshold])
    trajectory_summary = _group_correctness(long_df, [:trajectories, :threshold])

    CSV.write(joinpath(phase_dir, "combo_correctness_summary.csv"), combo_summary)
    CSV.write(joinpath(phase_dir, "problem_correctness_summary.csv"), problem_summary)
    CSV.write(joinpath(phase_dir, "bucket_correctness_summary.csv"), bucket_summary)
    CSV.write(joinpath(phase_dir, "mode_correctness_summary.csv"), mode_summary)
    CSV.write(joinpath(phase_dir, "noise_correctness_summary.csv"), noise_summary)
    CSV.write(joinpath(phase_dir, "npoints_correctness_summary.csv"), points_summary)
    CSV.write(joinpath(phase_dir, "trajectories_correctness_summary.csv"), trajectory_summary)

    best_by_threshold = combine(groupby(combo_summary, :threshold)) do g
        i = argmax(g.problem_correct_rate)
        g[i, :]
    end
    CSV.write(joinpath(phase_dir, "best_combo_by_threshold.csv"), best_by_threshold)

    for threshold in thresholds
        tag = _threshold_tag(threshold)
        _plot_combo_correctness(combo_summary, threshold, joinpath(phase_dir, "combo_correctness_t$(tag).png"))
        _plot_bucket_correctness(bucket_summary, threshold, joinpath(phase_dir, "bucket_correctness_t$(tag).png"))
    end

    best_run_key_095 = nothing
    best_equation_count_095 = missing
    best_json_path_095 = nothing
    best_knee_run_key_095 = nothing
    best_knee_equation_count_095 = missing
    best_knee_json_path_095 = nothing
    best_noisy_run_key_095 = nothing
    best_noisy_equation_count_095 = missing
    best_noisy_json_path_095 = nothing

    manifest_path = joinpath(output_dir, "phase0", "manifest.csv")
    if isfile(manifest_path)
        manifest = CSV.read(manifest_path, DataFrame)
        best_row = _best_run_by_equation_threshold(manifest, 0.95)
        if best_row !== nothing
            best_run_key_095 = best_row.run_key
            best_equation_count_095 = best_row.n_equations_ge_threshold
            best_json_path_095 = best_row.json_path
        end

        best_knee_row = _best_run_by_equation_threshold(manifest, 0.95, mode = "knee")
        if best_knee_row !== nothing
            best_knee_run_key_095 = best_knee_row.run_key
            best_knee_equation_count_095 = best_knee_row.n_equations_ge_threshold
            best_knee_json_path_095 = best_knee_row.json_path
        end

        best_noisy_row = _best_run_by_equation_threshold(manifest, 0.95, noise_values = Set([0.01, 0.05]))
        if best_noisy_row !== nothing
            best_noisy_run_key_095 = best_noisy_row.run_key
            best_noisy_equation_count_095 = best_noisy_row.n_equations_ge_threshold
            best_noisy_json_path_095 = best_noisy_row.json_path
        end
    end

    # Fallback to problem-level selection if manifest/json is unavailable.
    if best_run_key_095 === nothing
        best_run_key_095 = _best_run_key_for_threshold(combo_summary, 0.95)
    end

    if best_knee_run_key_095 === nothing
        best_knee_run_key_095 = _best_run_key_for_threshold(combo_summary, 0.95, mode = "knee")
    end

    if best_run_key_095 !== nothing && best_json_path_095 !== nothing
        _plot_problem_stacked_correctness(best_json_path_095, best_run_key_095, joinpath(phase_dir, "problem_stacked_correctness.png"))
    end

    if best_knee_run_key_095 !== nothing && best_knee_json_path_095 !== nothing
        _plot_problem_stacked_correctness(best_knee_json_path_095, best_knee_run_key_095, joinpath(phase_dir, "problem_stacked_correctness_knee.png"))
    end

    if best_noisy_run_key_095 !== nothing && best_noisy_json_path_095 !== nothing
        _plot_problem_stacked_correctness(best_noisy_json_path_095, best_noisy_run_key_095, joinpath(phase_dir, "problem_stacked_correctness_noisy.png"))
    end

    lines = String[]
    push!(lines, "Phase 6 Report - Threshold-Based Correctness")
    push!(lines, "")
    push!(lines, "Definitions:")
    push!(lines, "- problem_correct: avg_r2 >= threshold")
    push!(lines, "- fully_correct: min_r2 >= threshold (conservative all-equations-above-threshold proxy)")
    push!(lines, "- fully_correct_state_fraction sums n_states only for fully-correct problems")
    push!(lines, "")

    for threshold in thresholds
        subset = filter(r -> r.threshold == threshold, best_by_threshold)
        if nrow(subset) == 0
            continue
        end
        best = subset[1, :]
        push!(lines, "Best combination at R² >= $(threshold): $(best.run_key)")
        push!(lines, "- problem_correct_rate=$(best.problem_correct_rate)")
        push!(lines, "- fully_correct_rate=$(best.fully_correct_rate)")
        push!(lines, "- fully_correct_state_fraction=$(best.fully_correct_state_fraction)")
        push!(lines, "")
    end

    hard_threshold = thresholds[1]
    hard_rows = filter(r -> r.threshold == hard_threshold, problem_summary)
    hard_rank = sort(hard_rows, :problem_correct_rate)
    if nrow(hard_rank) > 0
        n_show = min(5, nrow(hard_rank))
        push!(lines, "Hardest problems at R² >= $(hard_threshold):")
        for row in eachrow(hard_rank[1:n_show, :])
            push!(lines, "- $(row.problem) [$(row.state_bucket)] rate=$(row.problem_correct_rate), fully_correct_rate=$(row.fully_correct_rate)")
        end
    end

    if best_run_key_095 !== nothing
        push!(lines, "")
        push!(lines, "Stacked problem plot run selection (R² >= 0.95 count criterion):")
        push!(lines, "- selected run_key=$(best_run_key_095)")
        if !ismissing(best_equation_count_095)
            push!(lines, "- n_equations_with_r2_ge_0_95=$(best_equation_count_095)")
        end
        if best_json_path_095 !== nothing
            push!(lines, "- source_json=$(best_json_path_095)")
        end
    end

    if best_knee_run_key_095 !== nothing
        push!(lines, "")
        push!(lines, "Stacked problem plot run selection for knee mode (R² >= 0.95 count criterion):")
        push!(lines, "- selected run_key=$(best_knee_run_key_095)")
        if !ismissing(best_knee_equation_count_095)
            push!(lines, "- n_equations_with_r2_ge_0_95=$(best_knee_equation_count_095)")
        end
        if best_knee_json_path_095 !== nothing
            push!(lines, "- source_json=$(best_knee_json_path_095)")
        end
    end

    if best_noisy_run_key_095 !== nothing
        push!(lines, "")
        push!(lines, "Stacked problem plot run selection for noise 0.01 or 0.05 (R² >= 0.95 count criterion):")
        push!(lines, "- selected run_key=$(best_noisy_run_key_095)")
        if !ismissing(best_noisy_equation_count_095)
            push!(lines, "- n_equations_with_r2_ge_0_95=$(best_noisy_equation_count_095)")
        end
        if best_noisy_json_path_095 !== nothing
            push!(lines, "- source_json=$(best_noisy_json_path_095)")
        end
    end

    write_text_report(joinpath(phase_dir, "report.txt"), lines)

    return (
        long = long_df,
        combo_summary = combo_summary,
        problem_summary = problem_summary,
        bucket_summary = bucket_summary,
        best_by_threshold = best_by_threshold,
    )
end
