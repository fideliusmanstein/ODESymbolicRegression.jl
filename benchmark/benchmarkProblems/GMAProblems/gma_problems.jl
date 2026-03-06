"""
gma_feedf.jl, gma_inhosc.jl, gma_bifeedb.jl

GMA approximations of chemical rate equation systems.
GMA (Generalized Mass Action) uses similar structure to S-systems.
"""

module GmaFeedfModule
include("GMABase.jl")
using .GMABase
include("../SSystemProblems/SSystemBase.jl")
using .SSystemBase
using DifferentialEquations
export gma_feedf_system, generate_gma_feedf_data, generate_gma_feedf_experiments, get_equation_strings

const α = [1.0, 1.0, 1.5, 1.0, 1.0, 1.0]
const β = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
const g_mat = [0.0  0.0  0.0  0.0  1.0  0.0;
               0.0  0.0  0.0  0.0  0.0  1.0;
               0.5  0.5  0.0  0.0  0.0  0.0;
               0.0  0.0  0.5  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0]
const h_mat = [0.5  0.0  0.0  0.0  0.0  0.0;
               0.0  0.5  0.0  0.0  0.0  0.0;
               0.0  0.0  0.5  0.0  0.0  0.0;
               0.0  0.0  0.0  0.5  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0]

function gma_feedf_system(X, inputs, t)
    return GMABase.gma_ode(X[1:4], α[1:4], β[1:4], g_mat[1:4, :], h_mat[1:4, :], inputs, t)
end

function generate_gma_feedf_data(; In1_const=1.0, In2_const=1.0, X0=[0.5, 0.5, 1.5, 0.8],
                                  tspan=(0.0, 5.0), n_points=51, noise_std=0.0)
    inputs = Dict(:X5 => t -> In1_const, :X6 => t -> In2_const)
    t, X, input_values = GMABase.generate_gma_data(
        α[1:4], β[1:4], g_mat[1:4, :], h_mat[1:4, :];
        X0=X0, tspan=tspan, n_points=n_points, noise_std=noise_std, inputs=inputs)
    return t, X, input_values
end

function generate_gma_feedf_experiments(; problem="gma_feedf1", noise_std::Union{Float64,Nothing}=nothing, n_points::Union{Int,Nothing}=nothing)
    noise_std = noise_std !== nothing ? noise_std : 0.0
    _n_points = n_points !== nothing ? n_points : 51
    experiments = []
    # Bug 2 fix: vary both input levels (X5=In1, X6=In2) across experiments (4×4 grid).
    in1_vals = [0.5, 1.0, 1.5, 2.0]
    in2_vals = [0.5, 1.0, 1.5, 2.0]
    exp_num = 1
    for in1 in in1_vals, in2 in in2_vals
        X_ss = [in1^2, in2^2, (1.5 * in1 * in2)^2, (1.5 * in1 * in2)^2]
        X0 = X_ss .* (1.0 .+ 0.5 * (2.0 * rand(4) .- 1.0))
        X0 = max.(X0, 0.01)
        t, X, input_values = generate_gma_feedf_data(In1_const=in1, In2_const=in2, X0=X0,
                                                      tspan=(0.0, 5.0), n_points=_n_points, noise_std=noise_std)
        push!(experiments, Dict(:experiment => exp_num, :t => t, :X => X, :inputs => input_values, :X0 => X0))
        exp_num += 1
    end
    return experiments
end

function get_equation_strings(problem::String)
    if !startswith(problem, "gma_feedf")
        error("Problem $problem is not a gma_feedf problem")
    end
    return SSystemBase.format_ssystem_equations(α[1:4], β[1:4], g_mat[1:4, :], h_mat[1:4, :], 4, Dict(5 => "X5", 6 => "X6"))
end
end

module GmaInhoscModule
include("GMABase.jl")
using .GMABase
include("../SSystemProblems/SSystemBase.jl")
using .SSystemBase
using DifferentialEquations
export gma_inhosc_system, generate_gma_inhosc_data, generate_gma_inhosc_experiments, get_equation_strings, get_equation_strings

const α = [1.0, 1.0, 1.0, 1.0]
const β = [1.0, 1.0, 1.0, 1.0]
const g_mat = [0.0  -0.5  0.0  0.0  1.0  0.0;
               0.5   0.0  0.0  0.0  0.0  0.0;
               0.0   0.5  0.0 -0.5  0.0  0.0;
               0.0   0.0  0.5  0.0  0.0  0.0]
const h_mat = [0.0  0.0  0.0  0.0  0.0  0.0;
               0.0  0.0  0.5  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  0.0;
               0.0  0.0  0.0  0.0  0.0  1.0]

function gma_inhosc_system(X, inputs, t)
    return GMABase.gma_ode(X, α, β, g_mat, h_mat, inputs, t)
end

function generate_gma_inhosc_data(; In_const=1.0, Out_const=1.0, X0=ones(4),
                                   tspan=(0.0, 10.0), n_points=51, noise_std=0.0)
    inputs = Dict(:In => t -> In_const, :Out => t -> Out_const)
    t, X, input_values = GMABase.generate_gma_data(
        α, β, g_mat, h_mat; X0=X0, tspan=tspan, n_points=n_points, noise_std=noise_std, inputs=inputs)
    return t, X, input_values
end

function generate_gma_inhosc_experiments(; problem="gma_inhosc1", noise_std::Union{Float64,Nothing}=nothing, n_points::Union{Int,Nothing}=nothing)
    noise_std = noise_std !== nothing ? noise_std : 0.0
    _n_points = n_points !== nothing ? n_points : 51
    experiments = []
    input_combinations = [(In=0.8, Out=0.8), (In=1.0, Out=1.0), (In=1.2, Out=1.0), (In=1.0, Out=1.2)]
    for (exp, combo) in enumerate(input_combinations)
        t, X, input_values = generate_gma_inhosc_data(In_const=combo.In, Out_const=combo.Out,
                                                      X0=ones(4), tspan=(0.0, 10.0), n_points=_n_points, noise_std=noise_std)
        push!(experiments, Dict(:experiment => exp, :t => t, :X => X, :inputs => input_values, :X0 => ones(4)))
    end
    return experiments
end

function get_equation_strings(problem::String)
    if !startswith(problem, "gma_inhosc")
        error("Problem $problem is not a gma_inhosc problem")
    end
    return SSystemBase.format_ssystem_equations(α, β, g_mat, h_mat, 4, Dict(5 => "In", 6 => "Out"))
end
end

module GmaBifeedbModule
include("GMABase.jl")
using .GMABase
include("../SSystemProblems/SSystemBase.jl")
using .SSystemBase
using DifferentialEquations
export gma_bifeedb_system, generate_gma_bifeedb_data, generate_gma_bifeedb_experiments, get_equation_strings, get_equation_strings

const α = [1.0, 1.0, 1.0, 1.0, 1.0]
const β = [1.0, 1.0, 1.0, 1.0, 1.0]
const g_mat = [0.0  0.0  -0.5  0.0  0.0;
               2.0  0.0   0.0  0.0  0.0;
               0.0  0.5   0.0  0.0  0.0;
               0.0  0.0   0.5  0.0  0.0;
               0.0  0.0   0.0  0.5  0.0]
const h_mat = [2.0  0.0  0.0  0.0  0.0;
               0.0  0.5  0.0  0.0  0.0;
               0.0  0.0  0.5  0.0  0.0;
               0.0  0.0  0.0  0.5  0.0;
               0.0  0.0  0.0  0.0  0.5]

function gma_bifeedb_system(X, inputs, t)
    return GMABase.gma_ode(X, α, β, g_mat, h_mat, inputs, t)
end

function generate_gma_bifeedb_data(; X0=ones(5), tspan=(0.0, 5.0), n_points=51, noise_std=0.0)
    inputs = Dict{Symbol, Function}()
    t, X, input_values = GMABase.generate_gma_data(
        α, β, g_mat, h_mat; X0=X0, tspan=tspan, n_points=n_points, noise_std=noise_std, inputs=inputs)
    return t, X, input_values
end

function generate_gma_bifeedb_experiments(; problem="gma_bifeedb1", noise_std::Union{Float64,Nothing}=nothing, n_points::Union{Int,Nothing}=nothing)
    noise_std = noise_std !== nothing ? noise_std : 0.0
    _n_points = n_points !== nothing ? n_points : 51
    experiments = []
    X_ss = [0.5, 1.0, 1.5, 2.0, 2.5]
    for exp in 1:16
        X0 = X_ss .* (1.0 .+ 0.75 * (2.0 * rand(5) .- 1.0))
        X0 = max.(X0, 0.01)
        t, X, _ = generate_gma_bifeedb_data(X0=X0, tspan=(0.0, 5.0), n_points=_n_points, noise_std=noise_std)
        push!(experiments, Dict(:experiment => exp, :t => t, :X => X, :inputs => Dict(), :X0 => X0))
    end
    return experiments
end

function get_equation_strings(problem::String)
    if !startswith(problem, "gma_bifeedb")
        error("Problem $problem is not a gma_bifeedb problem")
    end
    return SSystemBase.format_ssystem_equations(α, β, g_mat, h_mat, 5, nothing)
end
end

