if !isdefined(Main, :build_manifest)
    include(joinpath(@__DIR__, "common.jl"))
end

function run_phase0(results_dir::AbstractString, output_dir::AbstractString)
    phase_dir = joinpath(output_dir, "phase0")
    mkpath(phase_dir)

    manifest = build_manifest(results_dir)
    CSV.write(joinpath(phase_dir, "manifest.csv"), manifest)

    missing_exports = filter(r -> !r.has_csv || !r.has_json, manifest)
    CSV.write(joinpath(phase_dir, "missing_exports.csv"), missing_exports)

    failure_counts = combine(groupby(manifest, :failure_class), nrow => :count)
    CSV.write(joinpath(phase_dir, "failure_class_counts.csv"), failure_counts)

    completed_problem_counts = manifest[:, [:run_key, :problems_started, :problems_finished, :completed_run, :failure_class]]
    CSV.write(joinpath(phase_dir, "completed_problem_counts.csv"), completed_problem_counts)

    # Plot: failure class counts
    sorted_counts = sort(failure_counts, :count, rev = true)
    xs = 1:nrow(sorted_counts)
    ys = sorted_counts.count
    labels = String.(sorted_counts.failure_class)

    fig = Figure(size = (1000, 500))
    ax = Axis(fig[1, 1],
        title = "Run Diagnostics: Failure Class Counts",
        xlabel = "Failure class",
        ylabel = "Count")
    barplot!(ax, xs, ys)
    ax.xticks = (xs, labels)
    ax.xticklabelrotation = pi / 6
    save_plot(fig, joinpath(phase_dir, "failure_class_bar.png"))

    lines = String[]
    push!(lines, "Phase 0 Report - Integrity and Diagnostics")
    push!(lines, "")
    push!(lines, "Total run keys discovered: $(nrow(manifest))")
    push!(lines, "Runs with txt: $(count(manifest.has_txt))")
    push!(lines, "Runs with csv: $(count(manifest.has_csv))")
    push!(lines, "Runs with json: $(count(manifest.has_json))")
    push!(lines, "")
    push!(lines, "Failure class counts:")
    for r in eachrow(sorted_counts)
        push!(lines, "- $(r.failure_class): $(r.count)")
    end
    push!(lines, "")
    push!(lines, "Missing export run keys:")
    if nrow(missing_exports) == 0
        push!(lines, "- none")
    else
        for r in eachrow(sort(missing_exports, [:mode, :noise, :n_points, :trajectories]))
            push!(lines, "- $(r.run_key) [class=$(r.failure_class), started=$(r.problems_started), finished=$(r.problems_finished)]")
        end
    end

    write_text_report(joinpath(phase_dir, "report.txt"), lines)

    strict_keys = manifest.run_key[findall(r -> r.completed_run && r.has_csv && r.has_json, eachrow(manifest))]

    return (manifest = manifest, strict_keys = strict_keys)
end
