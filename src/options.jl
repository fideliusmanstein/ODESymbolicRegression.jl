"""
options.jl

Configuration structures for ODE discovery.
"""

"""
    ODERegressionOptions

Configuration for ODE discovery through symbolic regression.

# Fields
- `binary_operators`: Binary operators for symbolic expressions (default: +, *, -, /)
- `unary_operators`: Unary operators for symbolic expressions (default: cos, sin, exp)
- `maxsize`: Maximum complexity of expressions (default: 20)
- `niterations_derivative`: Iterations for derivative search (default: 10)
- `niterations_integration`: Iterations for integration refinement (default: 5)
- `complexity_derivative`: Max complexity for derivative search (default: 15)
- `complexity_integration`: Max complexity for integration search (default: 10)
- `parallelism`: Parallelism mode (:serial, :multithreading, :multiprocessing)
- `differentiation_method`: Method for numerical derivatives (:finite_difference, :savitzky_golay, :tikhonov, :tikhonov_regularizationtools, or :tikhonov_datainterpolations)
- `savitzky_golay_window`: Window size for Savitzky-Golay filter (default: 11)
- `savitzky_golay_order`: Polynomial order for Savitzky-Golay filter (default: 2)
- `tikhonov_lambda`: Regularization strength for Tikhonov smoothing (default: 1e-2)
- `seed`: Random seed for reproducibility
- `verbose`: Enable verbose output
- `combination_method`: Strategy for selecting initial equation combination in Stage 2 (`:combination_search` or `:knee_point`)
- `sr_populations`: Number of independent SR populations in stage 2 (default: 31)
- `sr_population_size`: Candidates per population per generation in stage 2 (default: 27)
- `sr_ncycles_per_iteration`: Evolutionary cycles per SR iteration in stage 2 (default: 380)
- `sr_tournament_selection_n`: Tournament size; must be < sr_population_size (default: 12)
- `complexity_threshold`: Max expression complexity evaluated by ODE integration in stage 2 (default: 10). Candidates above this are rejected immediately (Inf loss).
- `stage2_short_window_fraction`: Fraction of trajectory used in phase 1 short solve (default: 0.2). Must be tuned to the problem.
- `stage2_short_loss_threshold`: Phase 1 MSE above which candidate is rejected without full solve (default: 1.0). Must be tuned to problem scale.
"""
struct ODERegressionOptions
    binary_operators::Tuple
    unary_operators::Tuple
    maxsize::Int
    niterations_derivative::Int
    niterations_integration::Int
    complexity_derivative::Int
    complexity_integration::Int
    parallelism::Symbol
    differentiation_method::Symbol
    savitzky_golay_window::Int
    savitzky_golay_order::Int
    tikhonov_lambda::Float64
    seed::Int
    verbose::Bool
    combination_method::Symbol
    # Stage 2 SR population control
    sr_populations::Int
    sr_population_size::Int
    sr_ncycles_per_iteration::Int
    sr_tournament_selection_n::Int
    # Stage 2 integration-loss gating
    complexity_threshold::Int
    stage2_short_window_fraction::Float64
    stage2_short_loss_threshold::Float64
    
    function ODERegressionOptions(;
        binary_operators=(+, *, -, /),
        unary_operators=(cos, sin, exp),
        maxsize=20,
        niterations_derivative=10,
        niterations_integration=5,
        complexity_derivative=15,
        complexity_integration=10,
        parallelism=:multithreading,
        differentiation_method=:finite_difference,
        savitzky_golay_window=11,
        savitzky_golay_order=2,
        tikhonov_lambda=1e-2,
        seed=42,
        verbose=true,
        combination_method=:combination_search,
        sr_populations=31,
        sr_population_size=27,
        sr_ncycles_per_iteration=380,
        sr_tournament_selection_n=12,
        complexity_threshold=10,
        stage2_short_window_fraction=0.2,
        stage2_short_loss_threshold=1.0
    )
        @assert differentiation_method in [:finite_difference, :savitzky_golay, :tikhonov, :tikhonov_regularizationtools, :tikhonov_datainterpolations] "differentiation_method must be :finite_difference, :savitzky_golay, :tikhonov, :tikhonov_regularizationtools, or :tikhonov_datainterpolations"
        @assert isodd(savitzky_golay_window) && savitzky_golay_window >= 3 "savitzky_golay_window must be odd and >= 3"
        @assert savitzky_golay_order >= 1 "savitzky_golay_order must be >= 1"
        @assert tikhonov_lambda >= 0 "tikhonov_lambda must be >= 0"
        @assert combination_method in [:combination_search, :knee_point] "combination_method must be :combination_search or :knee_point"
        @assert sr_populations >= 1 "sr_populations must be >= 1"
        @assert sr_population_size >= 2 "sr_population_size must be >= 2"
        @assert sr_ncycles_per_iteration >= 1 "sr_ncycles_per_iteration must be >= 1"
        @assert sr_tournament_selection_n >= 2 "sr_tournament_selection_n must be >= 2"
        @assert sr_tournament_selection_n < sr_population_size "sr_tournament_selection_n must be < sr_population_size"
        @assert complexity_threshold >= 1 "complexity_threshold must be >= 1"
        @assert 0.0 < stage2_short_window_fraction <= 1.0 "stage2_short_window_fraction must be in (0, 1]"
        @assert stage2_short_loss_threshold > 0.0 "stage2_short_loss_threshold must be > 0"
        new(binary_operators, unary_operators, maxsize, 
            niterations_derivative, niterations_integration,
            complexity_derivative, complexity_integration,
            parallelism, differentiation_method, savitzky_golay_window, 
            savitzky_golay_order, Float64(tikhonov_lambda), seed, verbose,
            combination_method,
            sr_populations, sr_population_size, sr_ncycles_per_iteration,
            sr_tournament_selection_n,
            complexity_threshold, stage2_short_window_fraction,
            Float64(stage2_short_loss_threshold))
    end
end
