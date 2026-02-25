"""
test_similarity_scoring.jl

Regression test for the "0 valid samples" bug in the equation similarity scoring
inside benchmark_ode_discovery.jl.

Root cause: Julia world-age problem.
  eval() inside a compiled function creates methods in a newer "world age" than
  the calling function was compiled in.  Calling the eval()-created function
  directly fails with:
    MethodError ... (method too new to be called from this world context.)
  Fix: Base.invokelatest(gt_func, args...)

Run with: julia --project=. test/test_similarity_scoring.jl
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Test
using Statistics
using SymbolicRegression
using SymbolicRegression: eval_tree_array, calculate_pareto_frontier, equation_search

println("="^80)
println("Regression test: equation similarity scoring (world-age + GT lambda)")
println("="^80)

# ── Helper ────────────────────────────────────────────────────────────────────

function build_gt_lambda(gt_eq_str_raw::String, n_features::Int)
    gt_eq_str  = replace(gt_eq_str_raw, r"^[xX]\d+'\s*=\s*" => "")
    gt_eq_str  = replace(gt_eq_str, "·" => "*")
    gt_eq_safe = replace(gt_eq_str, r"square\(([^)]+)\)" => s"((\1)^2)")
    arg_list   = join(["x$k" for k in 1:n_features], ", ")
    alias_block = join(["X$k = x$k" for k in 1:n_features], "; ")
    return "($arg_list) -> begin; $alias_block; $gt_eq_safe; end"
end

# ── T1: World-age demonstration ───────────────────────────────────────────────

@testset "T1: eval() lambda direct call fails; invokelatest fixes it" begin
    function call_direct(lambda_str, x_vals)
        f = eval(Meta.parse(lambda_str))
        try; return f(x_vals...); catch e; return e; end
    end

    function call_invokelatest(lambda_str, x_vals)
        f = eval(Meta.parse(lambda_str))
        return Base.invokelatest(f, x_vals...)
    end

    lambda_str = "(x1, x2) -> x1^2 - x2"
    x_vals     = [2.0, 1.0]

    err = call_direct(lambda_str, x_vals)
    @test err isa MethodError
    @test contains(sprint(showerror, err), "world")

    result = call_invokelatest(lambda_str, x_vals)
    @test result ≈ 3.0
    println("  confirmed: direct call → MethodError(world age); invokelatest → $result")
end

# ── T2: Bifeedb1 GT lambdas ───────────────────────────────────────────────────

gt_raw_bifeedb1 = [
    "X1' = 1.0/(X3+0.1) - 1.0*X1^2",
    "X2' = 1.0*X1^2 - 1.0*X2/(X2+0.1)",
    "X3' = 1.0*X2/(X2+0.1) - 1.0*X3/(X3+0.1)",
    "X4' = 1.0*X3/(X3+0.1) - 1.0*X4/(X4+0.1)",
]

@testset "T2: bifeedb1 GT lambdas via invokelatest" begin
    n_features = 4
    sample_vals = [0.5, 1.0, 1.5, 2.0]
    for (i, raw) in enumerate(gt_raw_bifeedb1)
        lambda_str = build_gt_lambda(raw, n_features)
        gt_func    = eval(Meta.parse(lambda_str))
        v          = Base.invokelatest(gt_func, sample_vals...)
        @test isfinite(v)
    end
end

# ── T3: Feedf1 GT lambdas (has input variables x5/x6) ────────────────────────

gt_raw_feedf1 = [
    "X1' = X5 - 1.0*X1/(X1+0.5)",
    "X2' = X6 - 1.0*X2/(X2+0.4)",
    "X3' = 1.0*X1/(X1+0.5) + 1.0*X2/(X2+0.4) - 1.0*X3/(X3+0.3)",
    "X4' = 1.0*X3/(X3+0.3) - 1.0*X4/(X4+0.3)",
]

@testset "T3: feedf1 GT lambdas (6 features) via invokelatest" begin
    n_features  = 6
    sample_vals = [0.2, 0.3, 0.4, 0.5, 0.3, 0.2]
    for (i, raw) in enumerate(gt_raw_feedf1)
        lambda_str = build_gt_lambda(raw, n_features)
        gt_func    = eval(Meta.parse(lambda_str))
        v          = Base.invokelatest(gt_func, sample_vals...)
        @test isfinite(v)
    end
end

# ── T4: Cytokine GT lambdas (fractional powers x^-0.5) ───────────────────────

gt_raw_cytokine = [
    "x1' = 5*x2*x3^-0.5 - 10*x1",
    "x2' = 10*x1^0.5*x4^-0.5 - 10*x2",
    "x3' = 8*x2^0.5*x4^0.5 - 10*x3",
    "x4' = 6*x1^0.5*x3^0.5 - 10*x4",
]

@testset "T4: cytokine GT lambdas (fractional powers) via invokelatest" begin
    n_features  = 4
    sample_vals = [0.5, 0.6, 0.7, 0.8]
    for (i, raw) in enumerate(gt_raw_cytokine)
        lambda_str = build_gt_lambda(raw, n_features)
        gt_func    = eval(Meta.parse(lambda_str))
        v          = Base.invokelatest(gt_func, sample_vals...)
        @test isfinite(v)
    end
end

# ── T5: Full similarity loop integration test ─────────────────────────────────
# Simulates the inner loop from benchmark_ode_discovery.jl with the fix applied.
# Must produce >0 valid samples per equation.

@testset "T5: similarity loop yields >0 valid samples when using invokelatest" begin
    sq(x) = x * x  # named function required by SymbolicRegression
    sr_opts = SymbolicRegression.Options(
        binary_operators = (+, *, -, /),
        unary_operators  = (sq,),
        maxsize = 6,
        seed = 42
    )
    n_features = 4
    X_dummy    = rand(n_features, 30)
    y_dummy    = rand(30)
    hof        = equation_search(X_dummy, y_dummy; options=sr_opts, niterations=2, parallelism=:serial)
    pareto     = calculate_pareto_frontier(hof)
    disc_tree  = pareto[end].tree.tree  # Node

    for (i, raw) in enumerate(gt_raw_bifeedb1)
        lambda_str = build_gt_lambda(raw, n_features)
        gt_func    = eval(Meta.parse(lambda_str))

        feat_lo    = fill(0.1, n_features)
        feat_hi    = fill(5.0, n_features)
        n_samples  = 200
        test_pts   = feat_lo' .+ (feat_hi .- feat_lo)' .* rand(n_samples, n_features)

        valid = 0
        for j in 1:n_samples
            x_vals = test_pts[j, :]
            try
                gt_val  = Base.invokelatest(gt_func, x_vals...)
                disc_r  = eval_tree_array(disc_tree, reshape(x_vals, n_features, 1), sr_opts.operators)
                disc_v  = disc_r[1][1]
                if isfinite(gt_val) && isfinite(disc_v)
                    valid += 1
                end
            catch
                continue
            end
        end
        println("  eq $i: $valid / $n_samples valid samples")
        @test valid >= 10
    end
end

println("\n" * "="^80)
println("All tests complete.")
println("="^80)
