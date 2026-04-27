if !isdefined(Main, :write_text_report)
    include(joinpath(@__DIR__, "common.jl"))
end

function _zscore(v::Vector{Float64})
    μ = mean(v)
    σ = std(v)
    if σ == 0.0 || isnan(σ)
        return zeros(length(v))
    end
    return (v .- μ) ./ σ
end

function compute_scores(combo_summary::DataFrame)
    df = copy(combo_summary)

    r2z = _zscore(Float64.(df.median_avg_r2))
    minr2z = _zscore(Float64.(df.median_min_r2))
    rmsez = _zscore(Float64.(df.median_avg_rmse))
    timez = _zscore(Float64.(df.median_discovery_time))

    df.quality_score = r2z .+ minr2z .- rmsez
    df.speed_score = -timez
    df.balanced_score = 0.65 .* df.quality_score .+ 0.35 .* df.speed_score

    return df
end

function pareto_front(df::DataFrame)
    # maximize quality (median_avg_r2), minimize runtime (median_discovery_time)
    idx = Int[]
    for i in 1:nrow(df)
        dominated = false
        for j in 1:nrow(df)
            i == j && continue
            better_or_equal_quality = df.median_avg_r2[j] >= df.median_avg_r2[i]
            better_or_equal_time = df.median_discovery_time[j] <= df.median_discovery_time[i]
            strictly_better = (df.median_avg_r2[j] > df.median_avg_r2[i]) || (df.median_discovery_time[j] < df.median_discovery_time[i])
            if better_or_equal_quality && better_or_equal_time && strictly_better
                dominated = true
                break
            end
        end
        if !dominated
            push!(idx, i)
        end
    end
    return sort(df[idx, :], :median_discovery_time)
end

function run_phase5(combo_summary::DataFrame, output_dir::AbstractString)
    phase_dir = joinpath(output_dir, "phase5")
    mkpath(phase_dir)

    scores = compute_scores(combo_summary)

    quality_rank = sort(scores, :quality_score, rev = true)
    speed_rank = sort(scores, :speed_score, rev = true)
    balanced_rank = sort(scores, :balanced_score, rev = true)

    CSV.write(joinpath(phase_dir, "ranking_quality_first.csv"), quality_rank)
    CSV.write(joinpath(phase_dir, "ranking_speed_first.csv"), speed_rank)
    CSV.write(joinpath(phase_dir, "ranking_balanced.csv"), balanced_rank)

    front = pareto_front(scores)
    CSV.write(joinpath(phase_dir, "pareto_front.csv"), front)

    fig = Figure(size = (900, 600))
    ax = Axis(fig[1, 1],
        title = "Pareto Front: Quality vs Runtime",
        xlabel = "Median discovery time (s)",
        ylabel = "Median avg_r2")

    scatter!(ax, scores.median_discovery_time, scores.median_avg_r2, color = :gray70)
    scatter!(ax, front.median_discovery_time, front.median_avg_r2, color = :red, markersize = 12)
    lines!(ax, front.median_discovery_time, front.median_avg_r2, color = :red)
    save_plot(fig, joinpath(phase_dir, "pareto_plot.png"))

    lines = String[]
    push!(lines, "Phase 5 Report - Decision Outputs")
    push!(lines, "")

    if nrow(quality_rank) > 0
        q = quality_rank[1, :]
        push!(lines, "Top quality-first: $(q.run_key)")
    end
    if nrow(speed_rank) > 0
        s = speed_rank[1, :]
        push!(lines, "Top speed-first: $(s.run_key)")
    end
    if nrow(balanced_rank) > 0
        b = balanced_rank[1, :]
        push!(lines, "Top balanced: $(b.run_key)")
        push!(lines, "")
        push!(lines, "Default recommendation: $(b.run_key)")
        push!(lines, "Fallback quality-heavy: $(quality_rank.run_key[1])")
        push!(lines, "Fallback speed-heavy: $(speed_rank.run_key[1])")
    end

    write_text_report(joinpath(phase_dir, "recommendation.txt"), lines)

    return (scores = scores, pareto = front)
end
