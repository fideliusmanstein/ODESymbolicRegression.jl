using CSV
using DataFrames
using Statistics
using CairoMakie
using Dates

CairoMakie.activate!()

function ensure_output_dirs(base_output_dir::AbstractString)
    mkpath(base_output_dir)
    for phase in ("phase0", "phase1", "phase2", "phase3", "phase4", "phase5", "phase6", "phase7", "phase8", "phase9")
        mkpath(joinpath(base_output_dir, phase))
    end
    return nothing
end

function parse_run_meta(filename::AbstractString)
    # Legacy format:
    #   hp_<knee|search>_noiseX_ptsN_trajT_results_YYYYMMDD_HHMMSS.<ext>
    m = match(r"^(hp_(knee|search)_noise([0-9_]+)_pts(\d+)_traj(\d+))_results_(\d{8}_\d{6})\.(txt|csv|json)$", filename)
    if m !== nothing
        run_key = m.captures[1]
        mode = m.captures[2]
        noise = parse(Float64, replace(m.captures[3], "_" => "."))
        n_points = parse(Int, m.captures[4])
        trajectories = parse(Int, m.captures[5])
        timestamp = m.captures[6]
        ext = m.captures[7]

        return (
            run_key = run_key,
            mode = mode,
            noise = noise,
            n_points = n_points,
            trajectories = trajectories,
            timestamp = timestamp,
            ext = ext,
        )
    end

    # Additional structured searches format:
    #   hp_g1_noiseX_ptsN_trajT_results_...      -> mode="knee"
    #   hp_g2_noiseX_cxC_niterI_results_...      -> mode="knee"
    #   hp_g3_noiseX_ops_<ops>_results_...       -> mode="knee"
    m = match(r"^(hp_g(\d)_noise([0-9_]+)_(.*))_results_(\d{8}_\d{6})\.(txt|csv|json)$", filename)
    m === nothing && return nothing

    run_key = m.captures[1]
    group_id = m.captures[2]
    noise = parse(Float64, replace(m.captures[3], "_" => "."))
    tail = m.captures[4]
    timestamp = m.captures[5]
    ext = m.captures[6]

    # Keep existing analysis schema by mapping unavailable dimensions to
    # medium defaults used for fixed settings in the sweep script.
    n_points = 250
    trajectories = 10
    mode = "knee"

    if group_id == "1"
        g1 = match(r"^pts(\d+)_traj(\d+)$", tail)
        g1 === nothing && return nothing
        n_points = parse(Int, g1.captures[1])
        trajectories = parse(Int, g1.captures[2])
    elseif group_id == "2"
        g2 = match(r"^cx(\d+)_niter(\d+)$", tail)
        g2 === nothing && return nothing
    elseif group_id == "3"
        g3 = match(r"^ops_(standard|powc_only|powc_full)$", tail)
        g3 === nothing && return nothing
    else
        return nothing
    end

    return (
        run_key = run_key,
        mode = mode,
        noise = noise,
        n_points = n_points,
        trajectories = trajectories,
        timestamp = timestamp,
        ext = ext,
    )
end

function collect_result_index(results_dir::AbstractString)
    rows = NamedTuple[]
    for fn in readdir(results_dir)
        meta = parse_run_meta(fn)
        meta === nothing && continue
        push!(rows, merge(meta, (filename = fn, path = joinpath(results_dir, fn))))
    end

    if isempty(rows)
        return DataFrame(
            run_key = String[],
            mode = String[],
            noise = Float64[],
            n_points = Int[],
            trajectories = Int[],
            timestamp = String[],
            ext = String[],
            filename = String[],
            path = String[],
        )
    end

    return sort!(DataFrame(rows), [:run_key, :ext, :timestamp])
end

function _pick_latest_path(df::DataFrame, run_key::AbstractString, ext::AbstractString)
    subset = filter(r -> r.run_key == run_key && r.ext == ext, df)
    if nrow(subset) == 0
        return missing
    end
    idx = argmax(subset.timestamp)
    return subset.path[idx]
end

function _analyze_txt(txt_path)
    if txt_path === missing
        return (
            has_final_summary = false,
            has_end_timestamp = false,
            completed_run = false,
            problems_started = 0,
            problems_finished = 0,
            last_problem_started = missing,
            last_problem_finished = missing,
            has_exception_trace = false,
        )
    end

    text = read(txt_path, String)

    started_matches = collect(eachmatch(r"(?m)^STARTED:\s+([^\s]+)", text))
    finished_matches = collect(eachmatch(r"(?m)^Problem:\s+([^\s]+)", text))

    has_final_summary = occursin("SUMMARY", text)
    has_end_timestamp = occursin(r"(?m)^End:\s", text)
    completed_run = has_final_summary || has_end_timestamp

    has_exception_trace = (
        occursin("ERROR:", text) ||
        occursin("Exception", text) ||
        occursin("FAILED TO WRITE FULL RESULT", text) ||
        occursin("Test Failed", text)
    )

    last_problem_started = isempty(started_matches) ? missing : started_matches[end].captures[1]
    last_problem_finished = isempty(finished_matches) ? missing : finished_matches[end].captures[1]

    return (
        has_final_summary = has_final_summary,
        has_end_timestamp = has_end_timestamp,
        completed_run = completed_run,
        problems_started = length(started_matches),
        problems_finished = length(finished_matches),
        last_problem_started = last_problem_started,
        last_problem_finished = last_problem_finished,
        has_exception_trace = has_exception_trace,
    )
end

function classify_failure(; completed_run::Bool, has_csv::Bool, has_json::Bool, has_exception_trace::Bool, has_txt::Bool)
    if !has_txt
        return "no_txt"
    elseif completed_run && has_csv && has_json
        return "completed"
    elseif completed_run && (!has_csv || !has_json)
        return "completed_export_failed"
    elseif has_exception_trace
        return "runtime_failure"
    else
        return "interrupted"
    end
end

function build_manifest(results_dir::AbstractString)
    idx = collect_result_index(results_dir)
    run_keys = sort(unique(idx.run_key))

    rows = NamedTuple[]
    for run_key in run_keys
        subset = filter(r -> r.run_key == run_key, idx)
        mode = subset.mode[1]
        noise = subset.noise[1]
        n_points = subset.n_points[1]
        trajectories = subset.trajectories[1]

        txt_path = _pick_latest_path(idx, run_key, "txt")
        csv_path = _pick_latest_path(idx, run_key, "csv")
        json_path = _pick_latest_path(idx, run_key, "json")

        txt_meta = _analyze_txt(txt_path)

        has_txt = txt_path !== missing
        has_csv = csv_path !== missing
        has_json = json_path !== missing

        failure_class = classify_failure(
            completed_run = txt_meta.completed_run,
            has_csv = has_csv,
            has_json = has_json,
            has_exception_trace = txt_meta.has_exception_trace,
            has_txt = has_txt,
        )

        push!(rows, (
            run_key = run_key,
            mode = mode,
            noise = noise,
            n_points = n_points,
            trajectories = trajectories,
            txt_path = txt_path,
            csv_path = csv_path,
            json_path = json_path,
            has_txt = has_txt,
            has_csv = has_csv,
            has_json = has_json,
            has_final_summary = txt_meta.has_final_summary,
            has_end_timestamp = txt_meta.has_end_timestamp,
            completed_run = txt_meta.completed_run,
            problems_started = txt_meta.problems_started,
            problems_finished = txt_meta.problems_finished,
            last_problem_started = txt_meta.last_problem_started,
            last_problem_finished = txt_meta.last_problem_finished,
            has_exception_trace = txt_meta.has_exception_trace,
            failure_class = failure_class,
        ))
    end

    if isempty(rows)
        return DataFrame(
            run_key = String[],
            mode = String[],
            noise = Float64[],
            n_points = Int[],
            trajectories = Int[],
            txt_path = Union{Missing,String}[],
            csv_path = Union{Missing,String}[],
            json_path = Union{Missing,String}[],
            has_txt = Bool[],
            has_csv = Bool[],
            has_json = Bool[],
            has_final_summary = Bool[],
            has_end_timestamp = Bool[],
            completed_run = Bool[],
            problems_started = Int[],
            problems_finished = Int[],
            last_problem_started = Union{Missing,String}[],
            last_problem_finished = Union{Missing,String}[],
            has_exception_trace = Bool[],
            failure_class = String[],
        )
    end

    return sort!(DataFrame(rows), [:mode, :noise, :n_points, :trajectories])
end

function load_results_table(manifest::DataFrame)
    dfs = DataFrame[]

    for row in eachrow(manifest)
        row.has_csv || continue
        df = CSV.read(row.csv_path, DataFrame)

        df.run_key .= row.run_key
        df.mode .= row.mode
        df.noise .= row.noise
        df.n_points .= row.n_points
        df.trajectories .= row.trajectories

        # Enforce expected numeric types where possible.
        for c in (:avg_r2, :min_r2, :avg_rmse, :discovery_time, :integration_loss)
            if c in names(df)
                df[!, c] = Float64.(df[!, c])
            end
        end

        push!(dfs, df)
    end

    if isempty(dfs)
        return DataFrame()
    end

    return vcat(dfs...)
end

function strict_dataset(manifest::DataFrame, df::DataFrame)
    strict_keys = manifest.run_key[findall(r -> r.completed_run && r.has_csv && r.has_json, eachrow(manifest))]
    return filter(r -> r.run_key in strict_keys, df)
end

function common_subset_dataset(df::DataFrame)
    if nrow(df) == 0
        return df
    end

    n_runs = length(unique(df.run_key))
    per_problem = combine(groupby(df, :problem), :run_key => (x -> length(unique(x))) => :n_runs)
    common_problems = Set(per_problem.problem[per_problem.n_runs .== n_runs])

    return filter(r -> r.problem in common_problems, df)
end

_safe_median(v) = isempty(v) ? NaN : median(v)
_safe_mean(v) = isempty(v) ? NaN : mean(v)

function summarize_combo_metrics(df::DataFrame)
    if nrow(df) == 0
        return DataFrame()
    end

    rows = NamedTuple[]
    for g in groupby(df, [:run_key, :mode, :noise, :n_points, :trajectories])
        finite_loss = [x for x in g.integration_loss if isfinite(x)]
        push!(rows, (
            run_key = g.run_key[1],
            mode = g.mode[1],
            noise = g.noise[1],
            n_points = g.n_points[1],
            trajectories = g.trajectories[1],
            n_problems = nrow(g),
            success_rate = _safe_mean(Float64.(g.success)),
            timeout_rate = _safe_mean(Float64.(g.timeout)),
            median_avg_r2 = _safe_median(collect(skipmissing(g.avg_r2))),
            median_min_r2 = _safe_median(collect(skipmissing(g.min_r2))),
            median_avg_rmse = _safe_median(collect(skipmissing(g.avg_rmse))),
            median_discovery_time = _safe_median(collect(skipmissing(g.discovery_time))),
            median_integration_loss = _safe_median(finite_loss),
        ))
    end

    return sort!(DataFrame(rows), [:mode, :noise, :n_points, :trajectories])
end

function write_text_report(path::AbstractString, lines::Vector{String})
    open(path, "w") do io
        for line in lines
            println(io, line)
        end
    end
end

function save_plot(fig, path::AbstractString)
    save(path, fig)
    return nothing
end

function combo_label(row)
    return string(row.mode, " | n=", row.noise, " | pts=", row.n_points, " | traj=", row.trajectories)
end

function assign_state_bucket(n_states)
    if n_states <= 3
        return "2-3"
    elseif n_states <= 5
        return "4-5"
    else
        return "6+"
    end
end
