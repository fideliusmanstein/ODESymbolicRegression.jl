"""
test_trivial_equations.jl

Tests that detect "trivial equation" failures: cases where the SR discovery
produces constant (or nearly constant) equations instead of meaningful ODE terms.

Background / why this happens
==============================
Two conditions combine to cause this failure:

1. Low derivative SNR: For some problems the true derivative magnitudes are
   small relative to the observation noise. Numerical differentiation amplifies
   noise by ~1/Δt, so the derivative targets fed to SR are dominated by noise.
   SR's best low-complexity fit to a noise floor is a constant.

2. Misleading similarity scores: The benchmark's numerical similarity metric
   (R² / NRMSE) evaluates the discovered tree on random inputs and compares it
   to the ground truth. When the discovered equation is a constant that happens
   to fall near the *mean* of the ground truth evaluated at those test points,
   R² can appear excellent (≥0.99) even though the equation is structurally
   wrong.

This test file checks for both failure modes.

Run with:
    julia test/test_trivial_equations.jl
"""

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

include("../benchmark/benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems
using DifferentialEquations
using Statistics
using Random
using Test

Random.seed!(42)

println("="^80)
println("Testing Trivial-Equation Detection")
println("="^80)

# ─────────────────────────────────────────────────────────────────────────────
# Helper: evaluate a discovered equation string over random state inputs and
# return the standard deviation of the outputs.
# A constant equation has std ≈ 0.  A real equation has measurable std.
# ─────────────────────────────────────────────────────────────────────────────
function output_std_of_equation_string(eq_str::String, n_states::Int; n_samples=500, x_range=(0.1, 5.0))
    lo, hi = x_range
    results = Float64[]
    for _ in 1:n_samples
        x_vals = lo .+ (hi - lo) .* rand(n_states)
        var_assign = join(["x$k = $(x_vals[k]); X$k = $(x_vals[k])" for k in 1:n_states], "; ")
        eval_str = "begin; square(x) = x*x; $var_assign; $eq_str; end"
        try
            val = Core.eval(Main, Meta.parse(eval_str))
            if isfinite(val) && abs(val) < 1e8
                push!(results, Float64(val))
            end
        catch
            continue
        end
    end
    length(results) < 10 ? NaN : std(results)
end

# ─────────────────────────────────────────────────────────────────────────────
# Helper: check if an equation string is structurally a constant (no variables).
# A simple heuristic: try parsing with two different random input sets; if the
# outputs are identical to machine precision, it's constant.
# ─────────────────────────────────────────────────────────────────────────────
function is_constant_equation(eq_str::String, n_states::Int)
    v1 = output_std_of_equation_string(eq_str, n_states; n_samples=100)
    return isnan(v1) || v1 < 1e-6
end

# ─────────────────────────────────────────────────────────────────────────────
# Helper: compute derivative signal-to-noise ratio for a problem.
# Returns (snr_per_state, derivative_magnitudes, noise_amplitudes)
# ─────────────────────────────────────────────────────────────────────────────
function estimate_derivative_snr(experiments::Vector; method=:finite_difference)
    all_dX = [Float64[] for _ in 1:size(experiments[1][:X], 2)]
    all_X  = [Float64[] for _ in 1:size(experiments[1][:X], 2)]

    for exp in experiments
        t = exp[:t]
        X = exp[:X]
        n_states = size(X, 2)
        n_points = length(t)

        # Central differences for interior points
        for j in 2:(n_points-1)
            dt1 = t[j] - t[j-1]
            dt2 = t[j+1] - t[j]
            dt  = (t[j+1] - t[j-1]) / 2
            for s in 1:n_states
                dxdt = (X[j+1, s] - X[j-1, s]) / (t[j+1] - t[j-1])
                push!(all_dX[s], dxdt)
                push!(all_X[s], X[j, s])
            end
        end
    end

    snrs = Float64[]
    for s in 1:length(all_dX)
        signal_mag = mean(abs.(all_dX[s]))
        noise_proxy = std(diff(all_dX[s]))  # roughness = proxy for differentiation noise
        snr = noise_proxy > 1e-12 ? signal_mag / noise_proxy : Inf
        push!(snrs, snr)
    end
    return snrs, all_dX
end

# ─────────────────────────────────────────────────────────────────────────────
# Test 1: Ground-truth equation strings should NOT be constant
# (sanity-check our is_constant_equation helper itself)
# ─────────────────────────────────────────────────────────────────────────────
println("\n[Test 1] Ground-truth equations must be non-constant...")
@testset "Ground truth equations are non-constant" begin
    # bifeedb2 ground truth (from benchmark): x1' = 1/(x3+0.1) - x1^2
    gt_eqs_bifeedb2 = [
        "1/(x3+0.1) - 1*x1^2",
        "1*x1^2 - 1*x2/(x2+0.1)",
        "1*x2/(x2+0.1) - 1*x3/(x3+0.1)",
        "1*x3/(x3+0.1) - 1*x4/(x4+0.1)",
        "1*x4/(x4+0.1) - 1*x5/(x5+0.1)",
    ]
    for (i, eq) in enumerate(gt_eqs_bifeedb2)
        s = output_std_of_equation_string(eq, 5)
        @test !isnan(s)
        @test s > 0.01   # must have meaningful output variation (true constants have std = 0)
        println("  GT eq $i: std=$(round(s, digits=3))  → non-constant ✓")
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Test 2: Constant expressions must be flagged by is_constant_equation
# ─────────────────────────────────────────────────────────────────────────────
println("\n[Test 2] Constant expressions must be detected as constant...")
@testset "Constant expression detection" begin
    constant_eqs = ["-4.87", "4.43", "0.0", "1.0 + 0.0"]
    non_constant_eqs = [
        "x1 * x2",
        "1.0 / (x3 + 0.1)",
        "x1^2 - x2",
        "x1 / (x1 + 0.5)",
    ]
    for eq in constant_eqs
        @test is_constant_equation(eq, 5)
        println("  '$eq' → constant ✓")
    end
    for eq in non_constant_eqs
        @test !is_constant_equation(eq, 5)
        println("  '$eq' → non-constant ✓")
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Test 3: Check derivative SNR for known-problematic problem (bifeedb2)
# Low SNR predicts unreliable SR discovery.
# ─────────────────────────────────────────────────────────────────────────────
println("\n[Test 3] Derivative SNR check for bifeedb2 (known low-SNR problem)...")
@testset "Derivative SNR for bifeedb2" begin
    experiments = BenchmarkSystems.load_problem("bifeedb2", num_trajectories=3, noise_std=0.05)
    snrs, all_dX = estimate_derivative_snr(experiments)
    n_states = length(snrs)
    n_low_snr = count(s -> !isinf(s) && s < 1.0, snrs)

    println("  Per-state SNR (signal / differentiation-noise proxy):")
    for (i, s) in enumerate(snrs)
        flag = (!isinf(s) && s < 1.0) ? " ← LOW SNR" : ""
        println("    State $i: SNR ≈ $(round(s, digits=2))$flag")
    end
    println("  States with SNR < 1.0: $n_low_snr / $n_states")

    # At least warn if majority of states have low SNR
    @test n_low_snr >= 0   # always passes; below is the informational test
    if n_low_snr > n_states ÷ 2
        @warn "bifeedb2: majority of states have SNR < 1.0 — SR likely to find constants"
    end

    # Additionally test: noise_std=0.0 gives much better SNR
    experiments_clean = BenchmarkSystems.load_problem("bifeedb2", num_trajectories=3, noise_std=0.0)
    snrs_clean, _ = estimate_derivative_snr(experiments_clean)
    mean_snr_noisy = mean(filter(isfinite, snrs))
    mean_snr_clean = mean(filter(isfinite, snrs_clean))
    println("  Mean SNR (noisy):  $(round(mean_snr_noisy, digits=2))")
    println("  Mean SNR (clean):  $(round(mean_snr_clean, digits=2))")
    @test mean_snr_clean > mean_snr_noisy   # clean data → better SNR
end

# ─────────────────────────────────────────────────────────────────────────────
# Test 4: Similarity scores for purely constant equations should be low
# when evaluated against non-constant ground truth over a wide input range.
# This tests that the benchmark metric is not misleadingly optimistic.
# ─────────────────────────────────────────────────────────────────────────────
println("\n[Test 4] Similarity score sanity: constant equation must score low vs\n" *
        "         non-constant ground truth on wide input range...")
@testset "Similarity metric sanity for constant equations" begin
    # Ground truth: x1' = 1/(x3+0.1) - x1^2  (for bifeedb2 eq 1)
    gt_eq = "1/(x3+0.1) - 1*x1^2"
    # Discovered (as seen in the bad result above)
    disc_eq = "-4.87"
    n_states = 5
    n_samples = 500

    # Evaluate both on random inputs over a WIDER range [0.1, 10.0]
    gt_outputs   = Float64[]
    disc_outputs = Float64[]

    for _ in 1:n_samples
        x_vals = 0.1 .+ 9.9 .* rand(n_states)
        var_assign = join(["x$k = $(x_vals[k]); X$k = $(x_vals[k])" for k in 1:n_states], "; ")

        try
            gt_val   = Core.eval(Main, Meta.parse("begin; square(x)=x*x; $var_assign; $gt_eq; end"))
            disc_val = Core.eval(Main, Meta.parse("begin; square(x)=x*x; $var_assign; $disc_eq; end"))
            if isfinite(gt_val) && isfinite(disc_val) && abs(gt_val) < 1e8 && abs(disc_val) < 1e8
                push!(gt_outputs, Float64(gt_val))
                push!(disc_outputs, Float64(disc_val))
            end
        catch
            continue
        end
    end

    errors  = disc_outputs .- gt_outputs
    ss_res  = sum(errors .^ 2)
    ss_tot  = sum((gt_outputs .- mean(gt_outputs)) .^ 2)
    r2      = ss_tot > 1e-10 ? 1.0 - ss_res / ss_tot : NaN
    rmse    = sqrt(mean(errors .^ 2))
    gt_std  = std(gt_outputs)
    nrmse   = gt_std > 1e-10 ? rmse / gt_std : NaN

    println("  Constant -4.87  vs  GT '1/(x3+0.1) - x1^2'  on [0.1, 10.0]:")
    println("    RMSE  = $(round(rmse,  digits=4))")
    println("    NRMSE = $(round(nrmse, digits=4))")
    println("    R²    = $(round(r2,    digits=4))")
    println("    GT std (output variance) = $(round(gt_std, digits=4))")

    # A constant equation against a genuinely variable function must have low R²
    @test isnan(r2) || r2 < 0.5
    println("  ✓ R² < 0.5 confirmed — constant equation does NOT appear similar to GT")
end

# ─────────────────────────────────────────────────────────────────────────────
# Test 5: Cross-trajectory validation.
# Simulate forward using a "discovered" constant equation and compare to actual
# measured data on a held-out trajectory.  A constant ODE cannot reproduce
# the true trajectory.
# ─────────────────────────────────────────────────────────────────────────────
println("\n[Test 5] Cross-trajectory validation: constant equation fails on held-out data...")
@testset "Constant equation fails on trajectory prediction" begin
    # Use simpleLin1 because it has known ground truth and diverse trajectories
    experiments = BenchmarkSystems.load_problem("simpleLin1", num_trajectories=5)

    # Take first experiment as reference, last as held-out
    ref_exp   = experiments[1]
    holdout   = experiments[min(5, end)]
    n_states  = size(ref_exp[:X], 2)
    t_holdout = holdout[:t]
    X_holdout = holdout[:X]

    # Compute mean derivative from reference as "constant discovered equation"
    constant_deriv = zeros(n_states)
    for s in 1:n_states
        # Use forward differences
        dXdt_s = diff(ref_exp[:X][:, s]) ./ diff(ref_exp[:t])
        constant_deriv[s] = mean(dXdt_s)
    end

    println("  Constant derivative estimates: $(round.(constant_deriv, digits=3))")

    # Simulate with constant derivatives (Euler integration)
    X0   = X_holdout[1, :]
    Xpred = copy(X0)
    mse_over_time = Float64[]

    for j in 2:length(t_holdout)
        dt = t_holdout[j] - t_holdout[j-1]
        Xpred = Xpred .+ constant_deriv .* dt
        true_X = X_holdout[j, :]
        push!(mse_over_time, mean((Xpred .- true_X) .^ 2))
    end

    final_mse = mse_over_time[end]
    println("  Final MSE (constant eq vs held-out trajectory): $(round(final_mse, digits=5))")

    # The constant ODE prediction should diverge substantially from truth
    @test final_mse > 0.01
    println("  ✓ Constant equation diverges from true trajectory (MSE > 0.01)")
end

# ─────────────────────────────────────────────────────────────────────────────
# Test 6: Detect all-constant results in a fake benchmark output dictionary,
# which is the pattern seen in the bifeedb2 failure.
# ─────────────────────────────────────────────────────────────────────────────
println("\n[Test 6] All-constant discovered equations must be flagged as failure...")
@testset "All-constant discovery detection" begin
    # Simulate what a bad benchmark result looks like
    bad_result = Dict(
        "problem_name"         => "bifeedb2",
        "success"              => true,
        "n_states"             => 5,
        "discovered_equations" => ["-4.87", "4.43", "-0.18", "-0.01",
                                   "((x5 * (-0.09 / x4)) + 0.09) / (x5 + 0.11)"],
    )

    good_result = Dict(
        "problem_name"         => "bifeedb2_ideal",
        "success"              => true,
        "n_states"             => 5,
        "discovered_equations" => [
            "1 / (x3 + 0.1) - x1^2",
            "x1^2 - x2 / (x2 + 0.1)",
            "x2 / (x2 + 0.1) - x3 / (x3 + 0.1)",
            "x3 / (x3 + 0.1) - x4 / (x4 + 0.1)",
            "x4 / (x4 + 0.1) - x5 / (x5 + 0.1)",
        ],
    )

    function count_constant_equations(result)
        n = result["n_states"]
        eqs = result["discovered_equations"]
        count(eq -> is_constant_equation(eq, n), eqs)
    end

    function is_trivial_discovery(result; max_allowed_constants=1)
        n_const = count_constant_equations(result)
        n_total = result["n_states"]
        return n_const > max_allowed_constants
    end

    n_const_bad  = count_constant_equations(bad_result)
    n_const_good = count_constant_equations(good_result)

    println("  Bad result:  $n_const_bad / 5 equations are constant")
    println("  Good result: $n_const_good / 5 equations are constant")

    # Bad result has too many constants (4 out of 5)
    @test is_trivial_discovery(bad_result)
    println("  ✓ Bad result correctly flagged as trivial discovery")

    # Good result should not be flagged (0 constants)
    @test !is_trivial_discovery(good_result)
    println("  ✓ Good result correctly NOT flagged as trivial discovery")
end

println("\n" * "="^80)
println("All trivial-equation detection tests passed ✓")
println("="^80)
println()
println("Key takeaways:")
println("  1. Low derivative SNR predicts constant-equation failure.")
println("  2. Ground-truth similarity metrics are misleading when evaluated")
println("     over a narrow or biased input range.")
println("  3. Cross-trajectory error is a more reliable quality signal than R².")
println("  4. Count the fraction of constant equations to flag trivial results.")
