include(joinpath(@__DIR__, "common.jl"))
include(joinpath(@__DIR__, "phase0_integrity_and_diagnostics.jl"))
include(joinpath(@__DIR__, "phase1_primary_metrics.jl"))
include(joinpath(@__DIR__, "phase2_main_effects.jl"))
include(joinpath(@__DIR__, "phase3_interactions.jl"))
include(joinpath(@__DIR__, "phase4_problem_stratified.jl"))
include(joinpath(@__DIR__, "phase5_decision_outputs.jl"))
include(joinpath(@__DIR__, "phase6_threshold_correctness.jl"))

function run_all_analyses(; results_dir = normpath(joinpath(@__DIR__, "..", "hyperparameter_search")),
                            output_dir = joinpath(@__DIR__, "outputs"))
    ensure_output_dirs(output_dir)

    println("[analysis] phase 0: integrity + diagnostics")
    phase0 = run_phase0(results_dir, output_dir)

    println("[analysis] loading csv results")
    df_all = load_results_table(phase0.manifest)

    println("[analysis] phase 1: primary metrics")
    phase1 = run_phase1(phase0.manifest, df_all, output_dir)

    # Use strict dataset for all deeper comparisons to avoid partial-run bias.
    df_analysis = phase1.df_strict

    println("[analysis] phase 2: main effects")
    run_phase2(df_analysis, output_dir)

    println("[analysis] phase 3: interactions")
    run_phase3(df_analysis, output_dir)

    println("[analysis] phase 4: problem-stratified")
    run_phase4(df_analysis, output_dir)

    println("[analysis] phase 5: decision outputs")
    run_phase5(phase1.summary_strict, output_dir)

    println("[analysis] phase 6: threshold correctness")
    run_phase6(df_analysis, output_dir)

    # Build artifact index
    index_lines = String[]
    push!(index_lines, "Analysis Artifacts Index")
    push!(index_lines, "Generated: $(Dates.now())")
    push!(index_lines, "")

    for phase in ("phase0", "phase1", "phase2", "phase3", "phase4", "phase5", "phase6")
        phase_path = joinpath(output_dir, phase)
        push!(index_lines, "[$phase]")
        for f in sort(readdir(phase_path))
            push!(index_lines, "- $phase/$f")
        end
        push!(index_lines, "")
    end

    write_text_report(joinpath(output_dir, "analysis_index.txt"), index_lines)

    println("[analysis] done. outputs at: $output_dir")
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_all_analyses()
end
