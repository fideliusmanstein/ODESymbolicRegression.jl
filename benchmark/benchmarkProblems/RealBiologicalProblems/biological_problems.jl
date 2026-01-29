"""
RealBiologicalProblems.jl

Collection of real biological data-based benchmark problems.
These use data from actual biological experiments with realistic noise patterns.

Note: These implementations use synthetic S-system models to approximate
the real biological systems. In practice, you would load the actual experimental data.
"""

module CytokineModule
include("../SSystemProblems/SSystemBase.jl")
using .SSystemBase
using DifferentialEquations
export cytokine_system, generate_cytokine_data, generate_cytokine_experiments, get_equation_strings

const α = [5.0, 10.0, 8.0, 6.0]
const β = [10.0, 10.0, 10.0, 10.0]
const g = [0.0  1.0  -0.5  0.0;
           0.5  0.0   0.0  -0.5;
           0.0  0.5   0.0   0.5;
           0.5  0.0   0.5   0.0]
const h = [1.0  0.0  0.0  0.0;
           0.0  1.0  0.0  0.0;
           0.0  0.0  1.0  0.0;
           0.0  0.0  0.0  1.0]

function cytokine_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_cytokine_data(; X0=ones(4), tspan=(0.0, 6.0), n_points=7, noise_std=0.10)
    t, X, input_values = SSystemBase.generate_ssystem_data(
        α, β, g, h; X0=X0, tspan=tspan, n_points=n_points, noise_std=noise_std)
    return t, X, input_values
end

function generate_cytokine_experiments(; problem="cytokine1")
    noise_std = 0.10
    X0_list = problem == "cytokine1" ? [ones(4)] : [1.2 .* ones(4)]
    experiments = []
    for (exp, X0) in enumerate(X0_list)
        t, X, input_values = generate_cytokine_data(X0=X0, tspan=(0.0, 6.0), n_points=7, noise_std=noise_std)
        push!(experiments, Dict(:experiment => exp, :t => t, :X => X, :inputs => Dict(), :X0 => X0))
    end
    return experiments
end

function get_equation_strings(problem::String)
    if !startswith(problem, "cytokine")
        error("Problem $problem is not a cytokine problem")
    end
    return SSystemBase.format_ssystem_equations(α, β, g, h, 4, nothing)
end
end

module SsEthanolfermModule
include("../SSystemProblems/SSystemBase.jl")
using .SSystemBase
using DifferentialEquations
export ss_ethanolferm_system, generate_ss_ethanolferm_data, generate_ss_ethanolferm_experiments, get_equation_strings

const α = [8.0, 6.0, 5.0, 4.0]
const β = [10.0, 10.0, 10.0, 10.0]
const g = [0.0  -0.5  0.8  0.0;
           1.0   0.0  0.0 -0.3;
           0.5   0.5  0.0  0.0;
           0.0   0.8  0.5  0.0]
const h = [0.8  0.0  0.0  0.0;
           0.0  0.9  0.0  0.0;
           0.0  0.0  1.0  0.0;
           0.0  0.0  0.0  1.2]

function ss_ethanolferm_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_ss_ethanolferm_data(; X0=ones(4), tspan=(0.0, 10.0), n_points=15, noise_std=0.30)
    t, X, input_values = SSystemBase.generate_ssystem_data(
        α, β, g, h; X0=X0, tspan=tspan, n_points=n_points, noise_std=noise_std)
    return t, X, input_values
end

function generate_ss_ethanolferm_experiments(; problem="ss_ethanolferm1")
    n_exp = problem == "ss_ethanolferm1" ? 3 : 2
    n_points = problem == "ss_ethanolferm1" ? 15 : 13
    experiments = []
    for exp in 1:n_exp
        X0 = 1.0 .+ 0.3 * randn(4)
        X0 = max.(X0, 0.1)
        t, X, _ = generate_ss_ethanolferm_data(X0=X0, tspan=(0.0, 10.0), n_points=n_points, noise_std=0.30)
        push!(experiments, Dict(:experiment => exp, :t => t, :X => X, :inputs => Dict(), :X0 => X0))
    end
    return experiments
end

function get_equation_strings(problem::String)
    if !startswith(problem, "ss_ethanolferm")
        error("Problem $problem is not a ss_ethanolferm problem")
    end
    return SSystemBase.format_ssystem_equations(α, β, g, h, 4, nothing)
end
end

module SsSosrepairModule
include("../SSystemProblems/SSystemBase.jl")
using .SSystemBase
using DifferentialEquations
export ss_sosrepair_system, generate_ss_sosrepair_data, generate_ss_sosrepair_experiments, get_equation_strings

const α = [7.0, 8.0, 6.0, 5.0, 9.0, 4.0]
const β = fill(10.0, 6)
const g = zeros(6, 6)
const h = zeros(6, 6)
# Set up interaction pattern
for i in 1:6
    g[i, mod1(i+1, 6)] = 0.5
    g[i, mod1(i+2, 6)] = -0.3
    h[i, i] = 1.0
end

function ss_sosrepair_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_ss_sosrepair_data(; X0=ones(6), tspan=(0.0, 50.0), n_points=50, noise_std=0.10)
    t, X, input_values = SSystemBase.generate_ssystem_data(
        α, β, g, h; X0=X0, tspan=tspan, n_points=n_points, noise_std=noise_std)
    return t, X, input_values
end

function generate_ss_sosrepair_experiments(; problem="ss_sosrepair1")
    experiments = []
    X0 = 1.0 .+ 0.3 * randn(6)
    X0 = max.(X0, 0.1)
    t, X, _ = generate_ss_sosrepair_data(X0=X0, tspan=(0.0, 50.0), n_points=50, noise_std=0.10)
    push!(experiments, Dict(:experiment => 1, :t => t, :X => X, :inputs => Dict(), :X0 => X0))
    return experiments
end

function get_equation_strings(problem::String)
    if !startswith(problem, "ss_sosrepair")
        error("Problem $problem is not a ss_sosrepair problem")
    end
    return SSystemBase.format_ssystem_equations(α, β, g, h, 6, nothing)
end
end

module SsCadBAModule
include("../SSystemProblems/SSystemBase.jl")
using .SSystemBase
using DifferentialEquations
export ss_cadBA_system, generate_ss_cadBA_data, generate_ss_cadBA_experiments, get_equation_strings

const α = [6.0, 7.0, 5.0, 8.0]
const β = fill(10.0, 4)
const g = [0.0   0.8  -0.4  0.0;
           0.6   0.0   0.0  -0.3;
           0.0   0.5   0.0   0.4;
           0.7   0.0   0.6   0.0]
const h = [1.0  0.0  0.0  0.0;
           0.0  1.0  0.0  0.0;
           0.0  0.0  1.0  0.0;
           0.0  0.0  0.0  1.0]

function ss_cadBA_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_ss_cadBA_data(; X0=ones(4), tspan=(0.0, 25.0), n_points=25, noise_std=0.15)
    t, X, input_values = SSystemBase.generate_ssystem_data(
        α, β, g, h; X0=X0, tspan=tspan, n_points=n_points, noise_std=noise_std)
    return t, X, input_values
end

function generate_ss_cadBA_experiments(; problem="ss_cadBA1")
    experiments = []
    X0 = 1.0 .+ 0.3 * randn(4)
    X0 = max.(X0, 0.1)
    t, X, _ = generate_ss_cadBA_data(X0=X0, tspan=(0.0, 25.0), n_points=25, noise_std=0.15)
    push!(experiments, Dict(:experiment => 1, :t => t, :X => X, :inputs => Dict(), :X0 => X0))
    return experiments
end

function get_equation_strings(problem::String)
    if !startswith(problem, "ss_cadBA")
        error("Problem $problem is not a ss_cadBA problem")
    end
    return SSystemBase.format_ssystem_equations(α, β, g, h, 4, nothing)
end
end

module SsClockModule
include("../SSystemProblems/SSystemBase.jl")
using .SSystemBase
using DifferentialEquations
export ss_clock_system, generate_ss_clock_data, generate_ss_clock_experiments, get_equation_strings

const α = [5.0, 6.0, 7.0, 6.0, 5.0, 7.0, 6.0]
const β = fill(10.0, 7)
const g = zeros(7, 7)
const h = zeros(7, 7)
for i in 1:7
    g[i, mod1(i+1, 7)] = 0.7
    g[i, mod1(i+3, 7)] = -0.4
    h[i, i] = 1.0
end

function ss_clock_system(X, inputs, t)
    return SSystemBase.ssystem_ode(X, α, β, g, h, inputs, t)
end

function generate_ss_clock_data(; X0=ones(7), tspan=(0.0, 12.0), n_points=12, noise_std=0.10)
    t, X, input_values = SSystemBase.generate_ssystem_data(
        α, β, g, h; X0=X0, tspan=tspan, n_points=n_points, noise_std=noise_std)
    return t, X, input_values
end

function generate_ss_clock_experiments(; problem="ss_clock1")
    experiments = []
    X0 = 1.0 .+ 0.3 * randn(7)
    X0 = max.(X0, 0.1)
    t, X, _ = generate_ss_clock_data(X0=X0, tspan=(0.0, 12.0), n_points=12, noise_std=0.10)
    push!(experiments, Dict(:experiment => 1, :t => t, :X => X, :inputs => Dict(), :X0 => X0))
    return experiments
end

function get_equation_strings(problem::String)
    if !startswith(problem, "ss_clock")
        error("Problem $problem is not a ss_clock problem")
    end
    return SSystemBase.format_ssystem_equations(α, β, g, h, 7, nothing)
end
end

