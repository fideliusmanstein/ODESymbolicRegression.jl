"""
test_dimensional_data.jl

Verify that every benchmark problem returns data with the correct shape when
called with different n_points and num_trajectories values.

For each (problem, n_points, num_trajectories) combination the test checks:
  1. length(experiments) == num_trajectories         (trajectory count)
  2. length(e[:t])       == n_points  for every e   (time-axis length)
  3. size(e[:X], 1)      == n_points  for every e   (X rows = time points)
  4. size(e[:X], 2)      == n_states  for every e   (X cols = state variables)

Also tests the default behaviour: n_points=nothing should return the
problem's native number of time points.

Skip patterns:
  - ss_15genes* and ss_30genes* are excluded (very slow ODE solves).

Run with:  julia --project=. test/test_dimensional_data.jl
"""

# =============================================================================
# Setup
# =============================================================================

import Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Random
Random.seed!(42)

include("../benchmark/benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems
using Test

# =============================================================================
# Configuration
# =============================================================================

# Problems too large / slow for a unit-test loop
const SKIP_PROBLEMS = [
    "ss_15genes1", "ss_15genes2",
    "ss_30genes1", "ss_30genes2", "ss_30genes3",
]

# n_points values to sweep (small, so tests run fast)
const TEST_N_POINTS = [5, 11, 21]

# num_trajectories values to sweep
#   1  → always below predefined count
#   4  → within predefined count for most problems
#   9  → forces perturbed copies for most problems
const TEST_NUM_TRAJECTORIES = [1, 4, 9]

# =============================================================================
# Helpers
# =============================================================================

"""
    check_experiment_dims(experiments, n_points, n_states, context)

Assert that every experiment in `experiments` has the expected shape.
`context` is a string printed on failure.
"""
function check_experiment_dims(experiments, n_points, n_states, context)
    for (i, e) in enumerate(experiments)
        t = e[:t]
        X = e[:X]
        @test length(t) == n_points   ||
              error("$context  exp[$i]: length(t)=$(length(t)), expected $n_points")
        @test size(X, 1) == n_points  ||
              error("$context  exp[$i]: size(X,1)=$(size(X,1)), expected $n_points")
        @test size(X, 2) == n_states  ||
              error("$context  exp[$i]: size(X,2)=$(size(X,2)), expected $n_states")
    end
end

# =============================================================================
# Tests
# =============================================================================

all_problems = BenchmarkSystems.list_problems()
testable_problems = sort([p for p in keys(all_problems) if !(p in SKIP_PROBLEMS)])

println("Testing $(length(testable_problems)) problems  ×  $(length(TEST_N_POINTS)) n_points  ×  $(length(TEST_NUM_TRAJECTORIES)) num_trajectories")
println("Skipping: $(join(SKIP_PROBLEMS, ", "))")
println()

@testset "Dimensional data integrity" begin

    # ------------------------------------------------------------------
    # 1. Default n_points  (n_points=nothing → problem's native length)
    # ------------------------------------------------------------------
    @testset "Default n_points" begin
        for problem_name in testable_problems
            info     = all_problems[problem_name]
            n_states = info[:states]
            native   = info[:points_per_exp]

            @testset "$problem_name" begin
                experiments = BenchmarkSystems.load_problem(
                    problem_name;
                    num_trajectories = 2,
                    noise_std        = 0.0,
                    n_points         = nothing,
                )
                ctx = "$problem_name  n_points=nothing(→$native)  num_traj=2"
                @test length(experiments) == 2
                check_experiment_dims(experiments, native, n_states, ctx)
            end
        end
    end

    # ------------------------------------------------------------------
    # 2. Explicit n_points sweep  ×  num_trajectories sweep
    # ------------------------------------------------------------------
    @testset "Explicit n_points=$np, num_trajectories=$nt" for
            np in TEST_N_POINTS, nt in TEST_NUM_TRAJECTORIES

        @testset "$problem_name" for problem_name in testable_problems
            info     = all_problems[problem_name]
            n_states = info[:states]
            ctx      = "$problem_name  n_points=$np  num_traj=$nt"

            experiments = BenchmarkSystems.load_problem(
                problem_name;
                num_trajectories = nt,
                noise_std        = 0.0,
                n_points         = np,
            )

            @test length(experiments) == nt
            check_experiment_dims(experiments, np, n_states, ctx)
        end
    end

end  # @testset "Dimensional data integrity"

println("\nAll dimensional tests complete.")
