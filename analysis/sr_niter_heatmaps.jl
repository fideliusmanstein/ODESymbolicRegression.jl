"""
sr_niter_heatmaps.jl

Heatmap figures for the sr_niter sweep (niterations_derivative = 150/300/450/600),
in the same visual style as analysis/phase3_interactions.jl's hp_heatmap_*.png
(problem on the y-axis instead of trajectories, niter on the x-axis instead of
n_points -- this sweep only has one varied dimension).

Reads the merged per-niter csv files produced by merge_sr_niter_per_problem.py.

Usage:
    julia --project=. analysis/sr_niter_heatmaps.jl \
        --csv 150=server_results/sr_niter_merged/sr_niter_niter150_merged.csv \
        --csv 300=server_results/sr_niter_merged/sr_niter_niter300_merged.csv \
        --csv 450=server_results/sr_niter_merged/sr_niter_niter450_merged.csv \
        --csv 600=server_results/sr_niter_merged/sr_niter_niter600_merged.csv \
        --outdir thesis_figures/sr_niter_heatmaps
"""

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using CSV
using DataFrames
using CairoMakie
using Statistics

CairoMakie.activate!()

# ─────────────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────────────

function parse_args(args)
    csv_by_niter = Dict{Int, String}()
    outdir = "thesis_figures/sr_niter_heatmaps"
    i = 1
    while i <= length(args)
        if args[i] == "--csv" && i < length(args)
            niter_str, path = split(args[i+1], "="; limit=2)
            csv_by_niter[parse(Int, niter_str)] = path
            i += 2
        elseif args[i] == "--outdir" && i < length(args)
            outdir = args[i+1]; i += 2
        else
            i += 1
        end
    end
    return csv_by_niter, outdir
end

csv_by_niter, OUTDIR = parse_args(ARGS)
mkpath(OUTDIR)

if isempty(csv_by_niter)
    error("Provide at least one --csv <niter>=<path> argument.")
end

niter_vals = sort(collect(keys(csv_by_niter)))
println("Niter values : ", niter_vals)
println("Output dir   : $OUTDIR")

# ─────────────────────────────────────────────────────────────────────────────
# Load and combine
# ─────────────────────────────────────────────────────────────────────────────

df_all = DataFrame()
for n in niter_vals
    d = CSV.read(csv_by_niter[n], DataFrame)
    d.niter = fill(n, nrow(d))
    global df_all = vcat(df_all, d; cols = :union)
end

problems = sort(unique(df_all.problem))
nx = length(niter_vals)
ny = length(problems)

niter_idx  = Dict(v => i for (i, v) in enumerate(niter_vals))
problem_idx = Dict(p => i for (i, p) in enumerate(problems))

# ─────────────────────────────────────────────────────────────────────────────
# Aggregated (median-across-problems) heatmap: single row, one cell per niter
# value -- same visual style as hp_heatmap_*.png (colored cell + text label),
# but collapsed across all 22 problems instead of showing each one, since
# this sweep only varies one factor (niterations_derivative).
# ─────────────────────────────────────────────────────────────────────────────

function plot_heatmap(df, col::Symbol, label::AbstractString, cmap, outpath;
                       digits=2, higher_is_better=true, clip_range=nothing, agg=median)
    vals = fill(NaN, nx)
    for (xi, n) in enumerate(niter_vals)
        sub = filter(r -> r.niter == n, df)
        finite = filter(isfinite, skipmissing(sub[!, col]))
        isempty(finite) && continue
        vals[xi] = Float64(agg(collect(finite)))
    end

    finite_vals = filter(isfinite, vals)
    if clip_range === nothing
        clo = isempty(finite_vals) ? 0.0 : minimum(finite_vals)
        chi = isempty(finite_vals) ? 1.0 : maximum(finite_vals)
    else
        clo, chi = clip_range
    end

    mat = reshape(vals, 1, nx)  # 1 row x nx columns

    fig = Figure(size = (160 * nx + 260, 220))
    Label(fig[0, 1], label; fontsize = 14, tellwidth = false)
    ax = Axis(fig[1, 1];
        xlabel = "niterations_derivative",
        ylabel = "",
        xticks = (1:nx, string.(niter_vals)),
        yticks = (1:1, ["median (22 problems)"]),
    )
    hm = if clip_range === nothing
        heatmap!(ax, 1:nx, 1:1, mat';
            colormap = higher_is_better ? cmap : Reverse(cmap),
            colorrange = (clo, chi),
        )
    else
        heatmap!(ax, 1:nx, 1:1, mat';
            colormap = higher_is_better ? cmap : Reverse(cmap),
            colorrange = (clo, chi),
            lowclip = :black,
            highclip = :white,
        )
    end
    for xi in 1:nx
        v = vals[xi]
        isfinite(v) || continue
        txt = digits == 0 ? string(round(Int, v)) : string(round(v; digits=digits))
        clamped = clamp(v, clo, chi)
        text!(ax, xi, 1; text = txt,
            align = (:center, :center),
            fontsize = 13,
            color = (clamped - clo) / max(chi - clo, 1e-9) > 0.6 ? :black : :white)
    end
    Colorbar(fig[1, 2], hm)
    save(outpath, fig)
    println("  Saved: $outpath")
end

println("\n[1/5] avg_r2 heatmap...")
plot_heatmap(df_all, :avg_r2, "Median avg R² by niterations_derivative", :viridis,
    joinpath(OUTDIR, "heatmap_avg_r2.png"); digits=2, higher_is_better=true, clip_range=(-1.0, 1.0))

println("[2/5] discovery_time heatmap...")
plot_heatmap(df_all, :discovery_time, "Median discovery time (s) by niterations_derivative", :plasma,
    joinpath(OUTDIR, "heatmap_discovery_time.png"); digits=0, higher_is_better=false)

println("[3/5] min_r2 heatmap...")
plot_heatmap(df_all, :min_r2, "Median min R² (worst equation) by niterations_derivative", :viridis,
    joinpath(OUTDIR, "heatmap_min_r2.png"); digits=2, higher_is_better=true, clip_range=(-1.0, 1.0))

println("[4/5] integration_loss heatmap (log10)...")
df_all.log_integration_loss = log10.(max.(df_all.integration_loss, 1e-12))
plot_heatmap(df_all, :log_integration_loss, "Median log10(integration loss) by niterations_derivative", :plasma,
    joinpath(OUTDIR, "heatmap_integration_loss.png"); digits=2, higher_is_better=false)

# ─────────────────────────────────────────────────────────────────────────────
# [5/5] Summary trend: median avg_r2 and median discovery_time vs niter
# ─────────────────────────────────────────────────────────────────────────────

println("[5/5] summary trend (median avg_r2 / discovery_time vs niter)...")

grp = combine(groupby(df_all, :niter),
    :avg_r2 => median => :median_avg_r2,
    :avg_r2 => (x -> quantile(x, 0.25)) => :q25_avg_r2,
    :avg_r2 => (x -> quantile(x, 0.75)) => :q75_avg_r2,
    :discovery_time => median => :median_discovery_time,
)
sort!(grp, :niter)

fig = Figure(size = (900, 400))
ax1 = Axis(fig[1, 1]; xlabel = "niterations_derivative", ylabel = "median avg R²",
    title = "Quality vs. niterations_derivative", xticks = niter_vals)
lines!(ax1, grp.niter, grp.median_avg_r2; color = :steelblue, linewidth = 2)
scatter!(ax1, grp.niter, grp.median_avg_r2; color = :steelblue)

ax2 = Axis(fig[1, 2]; xlabel = "niterations_derivative", ylabel = "median discovery time (s)",
    title = "Runtime vs. niterations_derivative", xticks = niter_vals)
lines!(ax2, grp.niter, grp.median_discovery_time; color = :darkorange, linewidth = 2)
scatter!(ax2, grp.niter, grp.median_discovery_time; color = :darkorange)

outpath = joinpath(OUTDIR, "summary_trend_vs_niter.png")
save(outpath, fig)
println("  Saved: $outpath")

println("\n✓ All heatmaps saved to: $OUTDIR")
