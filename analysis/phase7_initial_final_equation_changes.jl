if !isdefined(Main, :write_text_report)
    include(joinpath(@__DIR__, "common.jl"))
end

_normalize_equation_line(line::AbstractString) = replace(strip(line), r"\s+" => " ")

function _extract_equation_block(detail::AbstractString, heading::AbstractString)
    pattern = Regex("(?ms)^  $(heading):\\n(?:    Initial integration loss:[^\\n]*\\n)?(.*?)(?=^  [A-Z]|\\z)")
    m = match(pattern, detail)
    m === nothing && return String[]

    block = chomp(m.captures[1])
    return [_normalize_equation_line(line) for line in split(block, '\n') if startswith(strip(line), "X")]
end

function _extract_problem_sections(txt_path::AbstractString)
    text = read(txt_path, String)
    matches = eachmatch(r"(?ms)^Problem:\s+([^\n]+)\n(.*?)(?=^================================================================================\n(?:STARTED:|SUMMARY)|\z)", text)

    rows = NamedTuple[]
    for m in matches
        problem = strip(m.captures[1])
        detail = m.captures[2]
        initial_eqs = _extract_equation_block(detail, raw"Initial Equations \(Best combination from Stage 1\)")
        final_eqs = _extract_equation_block(detail, raw"Final Discovered Equations \(After Integration Refinement\)")

        push!(rows, (
            problem = problem,
            initial_equations = join(initial_eqs, " || "),
            final_equations = join(final_eqs, " || "),
            n_initial_equations = length(initial_eqs),
            n_final_equations = length(final_eqs),
            equations_changed = !isempty(initial_eqs) && !isempty(final_eqs) && initial_eqs != final_eqs,
            equations_missing = isempty(initial_eqs) || isempty(final_eqs),
        ))
    end

    return rows
end

function _build_equation_change_table(manifest::DataFrame)
    rows = NamedTuple[]

    knee_manifest = filter(r -> r.mode == "knee" && r.completed_run && r.has_txt, manifest)
    for run in eachrow(knee_manifest)
        problem_rows = _extract_problem_sections(run.txt_path)
        for problem_row in problem_rows
            push!(rows, merge((
                run_key = run.run_key,
                mode = run.mode,
                noise = run.noise,
                n_points = run.n_points,
                trajectories = run.trajectories,
                txt_path = String(run.txt_path),
            ), problem_row))
        end
    end

    if isempty(rows)
        return DataFrame()
    end

    return sort!(DataFrame(rows), [:noise, :n_points, :trajectories, :problem])
end

function run_phase7(manifest::DataFrame, output_dir::AbstractString)
    phase_dir = joinpath(output_dir, "phase7")
    mkpath(phase_dir)

    changes = _build_equation_change_table(manifest)
    CSV.write(joinpath(phase_dir, "knee_initial_final_equation_changes.csv"), changes)

    if nrow(changes) == 0
        lines = [
            "Phase 7 Report - Knee Initial vs Final Equation Changes",
            "",
            "No completed knee runs with parsable txt reports were found.",
        ]
        write_text_report(joinpath(phase_dir, "report.txt"), lines)
        return (changes = changes, by_run = DataFrame(), by_problem = DataFrame())
    end

    by_run = combine(groupby(changes, [:run_key, :mode, :noise, :n_points, :trajectories]),
        :equations_changed => sum => :n_changed,
        :equations_missing => sum => :n_missing,
        nrow => :n_problems)
    by_run.changed_fraction = by_run.n_changed ./ by_run.n_problems
    CSV.write(joinpath(phase_dir, "knee_equation_change_summary_by_run.csv"), sort!(by_run, [:noise, :n_points, :trajectories]))

    by_problem = combine(groupby(changes, :problem),
        :equations_changed => sum => :n_changed,
        :equations_missing => sum => :n_missing,
        nrow => :n_runs)
    by_problem.changed_fraction = by_problem.n_changed ./ by_problem.n_runs
    CSV.write(joinpath(phase_dir, "knee_equation_change_summary_by_problem.csv"), sort!(by_problem, [:n_changed, :problem], rev = [true, false]))

    ranked = sort(by_run, :changed_fraction, rev = true)
    fig = Figure(size = (max(1000, 35 * nrow(ranked)), 550))
    ax = Axis(fig[1, 1],
        title = "Knee runs with changed final equations",
        xlabel = "Run",
        ylabel = "Fraction of problems with changed equations",
        ytickformat = v -> string.(round.(Int, v .* 100)) .* "%",
        limits = (nothing, (0.0, 1.0)))

    xs = 1:nrow(ranked)
    barplot!(ax, xs, ranked.changed_fraction)
    ax.xticks = (xs, [combo_label(r) for r in eachrow(ranked)])
    ax.xticklabelrotation = pi / 4
    save_plot(fig, joinpath(phase_dir, "knee_equation_change_rate_by_run.png"))

    total_changed = sum(changes.equations_changed)
    total_missing = sum(changes.equations_missing)
    total_problems = nrow(changes)

    lines = String[]
    push!(lines, "Phase 7 Report - Knee Initial vs Final Equation Changes")
    push!(lines, "")
    push!(lines, "Scope: completed knee_point runs with txt reports only")
    push!(lines, "Total parsed knee problem instances: $(total_problems)")
    push!(lines, "Problems with different initial/final equations: $(total_changed)")
    push!(lines, "Problems with missing equation blocks: $(total_missing)")
    push!(lines, "Changed fraction: $(total_problems == 0 ? NaN : total_changed / total_problems)")
    push!(lines, "")
    push!(lines, "Runs with the most changed problems:")
    for row in eachrow(ranked[1:min(5, nrow(ranked)), :])
        push!(lines, "- $(row.run_key): changed=$(row.n_changed)/$(row.n_problems), missing=$(row.n_missing)")
    end

    hottest = sort(by_problem, :n_changed, rev = true)
    push!(lines, "")
    push!(lines, "Problems most often changed by integration refinement:")
    for row in eachrow(hottest[1:min(10, nrow(hottest)), :])
        push!(lines, "- $(row.problem): changed=$(row.n_changed)/$(row.n_runs), missing=$(row.n_missing)")
    end

    write_text_report(joinpath(phase_dir, "report.txt"), lines)

    return (changes = changes, by_run = by_run, by_problem = by_problem)
end