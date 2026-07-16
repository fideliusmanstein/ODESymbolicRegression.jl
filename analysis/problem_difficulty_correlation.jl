"""
problem_difficulty_correlation.jl

Investigates what predicts per-problem symbolic-regression recovery quality:
number of coupled states (system size) vs. functional complexity of the
ground-truth equations (operator/function count).

Uses the exact same source run as
overleaf_images/outputs/phase6/problem_stacked_correctness_noisy.png
(run_key = hp_search_noise0_01_pts250_traj5), so the "quality" numbers here
are directly comparable to that existing figure.

Usage:
    julia --project=. analysis/problem_difficulty_correlation.jl \
        --json server_results/hyperparameter_search/hp_search_noise0_01_pts250_traj5_results_20260506_211953.json \
        --outdir thesis_figures/problem_difficulty
"""

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JSON
using CairoMakie
using Statistics

CairoMakie.activate!()

function parse_args(args)
    json_path = nothing
    outdir = "thesis_figures/problem_difficulty"
    i = 1
    while i <= length(args)
        if args[i] == "--json" && i < length(args)
            json_path = args[i+1]; i += 2
        elseif args[i] == "--outdir" && i < length(args)
            outdir = args[i+1]; i += 2
        else
            i += 1
        end
    end
    return json_path, outdir
end

json_path, OUTDIR = parse_args(ARGS)
json_path === nothing && error("Provide --json <path>.")
mkpath(OUTDIR)

data = JSON.parsefile(json_path)

# ─────────────────────────────────────────────────────────────────────────────
# Equation functional-complexity proxy: count of binary operators (+-*/^) and
# named function calls (square(, inv(, sqrtp(, powc(, ...) on the RHS of each
# ground-truth equation.
# ─────────────────────────────────────────────────────────────────────────────

function op_count(eq::AbstractString)
    parts = split(eq, "="; limit=2)
    rhs = length(parts) == 2 ? parts[2] : eq
    ops = length(collect(eachmatch(r"[\+\-\*/\^]", rhs)))
    funcs = length(collect(eachmatch(r"[a-zA-Z_]+\(", rhs)))
    return ops + funcs
end

problems = String[]
n_states_v = Int[]
avg_complexity_v = Float64[]
avg_r2_v = Float64[]
frac95_v = Float64[]

for (name, info) in data
    gt_eqs = info["ground_truth_equations"]
    complexities = op_count.(gt_eqs)
    scores = info["equation_scores"]
    r2s = [s["r2"] for s in scores]

    push!(problems, name)
    push!(n_states_v, info["n_states"])
    push!(avg_complexity_v, mean(complexities))
    push!(avg_r2_v, mean(r2s))
    push!(frac95_v, count(>=(0.95), r2s) / length(r2s))
end

function pearson(x, y)
    mx, my = mean(x), mean(y)
    cov = sum((x .- mx) .* (y .- my))
    sx = sqrt(sum((x .- mx).^2))
    sy = sqrt(sum((y .- my).^2))
    return cov / (sx * sy)
end

r_states = pearson(Float64.(n_states_v), frac95_v)
r_complexity = pearson(avg_complexity_v, frac95_v)

println("Pearson r(n_states, frac_R2>=0.95)        = $(round(r_states, digits=3))")
println("Pearson r(avg_complexity, frac_R2>=0.95)  = $(round(r_complexity, digits=3))")

# ─────────────────────────────────────────────────────────────────────────────
# Greedy label placement: points with near-identical (x,y) -- common here,
# since fractions are coarse k/n_equations -- get their labels fanned out
# vertically instead of stacking illegibly on top of each other.
# ─────────────────────────────────────────────────────────────────────────────

function place_labels!(ax, xs, ys, labels; base_dx, ystep, xtol, ytol)
    placed = Tuple{Float64,Float64}[]
    for i in eachindex(xs)
        x, y = xs[i], ys[i]
        dx, dy = base_dx, 0.0
        for _ in 1:30
            collision = any(abs((x + dx) - px) < xtol && abs((y + dy) - py) < ytol for (px, py) in placed)
            collision || break
            dy += ystep
        end
        text!(ax, x + dx, y + dy; text = labels[i], fontsize = 8, align = (:left, :center))
        push!(placed, (x + dx, y + dy))
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Figure: two scatter panels side by side, both against frac(R² >= 0.95),
# points sized/colored by the OTHER factor to show they aren't just proxies.
# ─────────────────────────────────────────────────────────────────────────────

fig = Figure(size = (1300, 560))

ax1 = Axis(fig[1, 1];
    xlabel = "number of coupled states",
    ylabel = "fraction of equations with R² ≥ 0.95",
    title = "Quality vs. system size  (r = $(round(r_states, digits=2)))",
    limits = (1.5, 9.5, -0.05, 1.15),
)
sc1 = scatter!(ax1, Float64.(n_states_v), frac95_v;
    color = avg_complexity_v, colormap = :viridis, markersize = 16)
place_labels!(ax1, Float64.(n_states_v), frac95_v, problems;
    base_dx = 0.1, ystep = 0.045, xtol = 0.9, ytol = 0.02)
Colorbar(fig[1, 2], sc1; label = "avg. equation complexity")

ax2 = Axis(fig[1, 3];
    xlabel = "avg. ground-truth equation complexity (ops + funcs)",
    ylabel = "fraction of equations with R² ≥ 0.95",
    title = "Quality vs. equation complexity  (r = $(round(r_complexity, digits=2)))",
    limits = (2, 15, -0.05, 1.15),
)
sc2 = scatter!(ax2, avg_complexity_v, frac95_v;
    color = n_states_v, colormap = :plasma, markersize = 16)
place_labels!(ax2, avg_complexity_v, frac95_v, problems;
    base_dx = 0.15, ystep = 0.045, xtol = 1.2, ytol = 0.02)
Colorbar(fig[1, 4], sc2; label = "n_states")

outpath = joinpath(OUTDIR, "quality_vs_states_and_complexity.png")
save(outpath, fig)
println("Saved: $outpath")
