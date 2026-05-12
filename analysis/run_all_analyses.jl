include(joinpath(@__DIR__, "common.jl"))
include(joinpath(@__DIR__, "phase0_integrity_and_diagnostics.jl"))
include(joinpath(@__DIR__, "phase1_primary_metrics.jl"))
include(joinpath(@__DIR__, "phase2_main_effects.jl"))
include(joinpath(@__DIR__, "phase3_interactions.jl"))
include(joinpath(@__DIR__, "phase4_problem_stratified.jl"))
include(joinpath(@__DIR__, "phase5_decision_outputs.jl"))
include(joinpath(@__DIR__, "phase6_threshold_correctness.jl"))
include(joinpath(@__DIR__, "phase7_initial_final_equation_changes.jl"))
include(joinpath(@__DIR__, "phase8_trajectory_examples.jl"))
include(joinpath(@__DIR__, "phase9_discovery_time_effects.jl"))

function copy_results_for_overleaf(legacy_output::AbstractString, additional_output::AbstractString)
    # Copy all images to overleaf_images, preserving outputs structure
    overleaf_dir = normpath(joinpath(@__DIR__, "..", "overleaf_images"))
    mkpath(overleaf_dir)
    for base in (legacy_output, additional_output)
        # Only copy if directory exists
        isdir(base) || continue
        for (root, dirs, files) in walkdir(base)
            for f in files
                if endswith(f, ".png") || endswith(f, ".jpg") || endswith(f, ".jpeg") || endswith(f, ".pdf") || endswith(f, ".svg") || endswith(f, ".eps")
                    rel = joinpath(splitpath(root)[end-1:end]...)
                    dest_dir = joinpath(overleaf_dir, rel)
                    mkpath(dest_dir)
                    cp(joinpath(root, f), joinpath(dest_dir, f); force=true)
                end
            end
        end
    end
    println("[analysis] images copied to: $overleaf_dir")
    return nothing
end

function run_all_analyses(; results_dir = normpath(joinpath(@__DIR__, "..", "server_results", "hyperparameter_search")),
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

    println("[analysis] phase 7: knee initial vs final equation changes")
    run_phase7(phase0.manifest, output_dir)

    println("[analysis] phase 8: trajectory comparison examples")
    run_phase8(phase0.manifest, output_dir)

    # Build artifact index
    index_lines = String[]
    push!(index_lines, "Analysis Artifacts Index")
    push!(index_lines, "Generated: $(Dates.now())")
    push!(index_lines, "")

    for phase in ("phase0", "phase1", "phase2", "phase3", "phase4", "phase5", "phase6", "phase7", "phase8")
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

function run_all_analyses_both()
    legacy_results = normpath(joinpath(@__DIR__, "..", "server_results", "hyperparameter_search"))
    legacy_output = joinpath(@__DIR__, "outputs")
    additional_results = normpath(joinpath(@__DIR__, "..", "server_results", "additional_hs_searches"))
    additional_output = joinpath(@__DIR__, "additional_outputs")

    println("[analysis] running legacy sweep analyses")
    run_all_analyses(results_dir = legacy_results, output_dir = legacy_output)

    println("[analysis] running additional sweep analyses")
    run_all_analyses(results_dir = additional_results, output_dir = additional_output)

    println("[analysis] both analysis runs completed")

    copy_results_for_overleaf(legacy_output, additional_output)
    return nothing
end


function run_phase1_only(; results_dir = normpath(joinpath(@__DIR__, "..", "server_results", "hyperparameter_search")),
                           output_dir = joinpath(@__DIR__, "outputs"))
    ensure_output_dirs(output_dir)
    println("[analysis] phase 0: building manifest")
    phase0 = run_phase0(results_dir, output_dir)
    println("[analysis] loading csv results")
    df_all = load_results_table(phase0.manifest)
    println("[analysis] phase 1: primary metrics")
    run_phase1(phase0.manifest, df_all, output_dir)
    println("[analysis] done. outputs at: $output_dir")
    return nothing
end

function run_phase6_only(; results_dir = normpath(joinpath(@__DIR__, "..", "server_results", "hyperparameter_search")),
                           output_dir = joinpath(@__DIR__, "outputs"))
    ensure_output_dirs(output_dir)
    println("[analysis] phase 0: integrity + diagnostics")
    phase0 = run_phase0(results_dir, output_dir)
    println("[analysis] loading csv results")
    df_all = load_results_table(phase0.manifest)
    println("[analysis] phase 1: primary metrics")
    phase1 = run_phase1(phase0.manifest, df_all, output_dir)
    println("[analysis] phase 6: threshold correctness")
    run_phase6(phase1.df_strict, output_dir)
    println("[analysis] done. outputs at: $output_dir")
    return nothing
end

function run_phase9_only(; results_dir = normpath(joinpath(@__DIR__, "..", "server_results", "hyperparameter_search")),
                           output_dir = joinpath(@__DIR__, "outputs"))
    ensure_output_dirs(output_dir)
    println("[analysis] phase 0: building manifest")
    phase0 = run_phase0(results_dir, output_dir)
    println("[analysis] loading csv results")
    df_all = load_results_table(phase0.manifest)
    println("[analysis] phase 1: strict dataset")
    phase1 = run_phase1(phase0.manifest, df_all, output_dir)
    println("[analysis] phase 9: discovery time effects")
    run_phase9(phase1.df_strict, output_dir)
    println("[analysis] done. outputs at: $output_dir")
    return nothing
end

function run_phase3_only(; results_dir = normpath(joinpath(@__DIR__, "..", "server_results", "hyperparameter_search")),
                           output_dir = joinpath(@__DIR__, "outputs"))
    ensure_output_dirs(output_dir)
    println("[analysis] phase 0: building manifest")
    phase0 = run_phase0(results_dir, output_dir)
    println("[analysis] loading csv results")
    df_all = load_results_table(phase0.manifest)
    println("[analysis] phase 1: strict dataset")
    phase1 = run_phase1(phase0.manifest, df_all, output_dir)
    println("[analysis] phase 3: interactions")
    run_phase3(phase1.df_strict, output_dir)
    println("[analysis] done. outputs at: $output_dir")
    return nothing
end

function run_phase7_only(; results_dir = normpath(joinpath(@__DIR__, "..", "server_results", "hyperparameter_search")),
                           output_dir = joinpath(@__DIR__, "outputs"))
    ensure_output_dirs(output_dir)
    println("[analysis] phase 0: building manifest")
    phase0 = run_phase0(results_dir, output_dir)
    println("[analysis] phase 7: initial vs final equation changes")
    run_phase7(phase0.manifest, output_dir)
    println("[analysis] done. outputs at: $output_dir")
    return nothing
end

function run_phase8_only(; results_dir = normpath(joinpath(@__DIR__, "..", "server_results", "hyperparameter_search")),
                           output_dir = joinpath(@__DIR__, "outputs"))
    ensure_output_dirs(output_dir)
    println("[analysis] phase 0: building manifest (needed for phase 8)")
    phase0 = run_phase0(results_dir, output_dir)
    println("[analysis] phase 8: trajectory comparison examples")
    run_phase8(phase0.manifest, output_dir)
    println("[analysis] done. outputs at: $output_dir")
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_phase7_only()
    # run_phase6_only()
    # run_all_analyses()
    # run_all_analyses_both()
    copy_results_for_overleaf(
        joinpath(@__DIR__, "outputs"),
        joinpath(@__DIR__, "additional_outputs")
    )
end
