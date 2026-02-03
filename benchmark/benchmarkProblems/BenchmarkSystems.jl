"""
BenchmarkSystems.jl

Unified interface to all benchmark differential equation systems for testing 
symbolic regression algorithms.

Based on: https://www.cse.chalmers.se/~dag/identification/Benchmarks/

Available benchmark systems:
- simpleLin: Simple linear metabolic pathway (3 states, 2 inputs)
- simpleFb: Simple feedback system (3 states)
- osc: Oscillator system (3 states)
- metabol: Metabolic pathway with Michaelis-Menten kinetics (5 states, 2 inputs)
- threeGenes: Gene network system (8 states for N=3)
- feedf: Feed-forward pathway (4 states, 2 inputs)
- inhosc: Inhibitory oscillator (2-4 states, 2 inputs)
- bifeedb: Bi-molecular feedback (4-5 states)

Each system module provides:
- System function: Defines the ODE system
- generate_*_data: Generate single experiment data
- generate_*_experiments: Generate standard benchmark problem datasets

Usage:
```julia
include("benchmarkProblems/BenchmarkSystems.jl")
using .BenchmarkSystems

# Load a specific benchmark problem
experiments = BenchmarkSystems.load_problem("simpleLin2")

# Or use individual modules
using .BenchmarkSystems.SimpleLinModule
t, X, inputs = SimpleLinModule.generate_simplelin_data(X1_const=3.0, X2_const=2.0)
```
"""

module BenchmarkSystems

# Include all benchmark system modules

# Chemical Rate Equations
include("ChemicalRateProblems/simpleLin.jl")
include("ChemicalRateProblems/simpleFb.jl")
include("ChemicalRateProblems/osc.jl")
include("ChemicalRateProblems/metabol.jl")
include("ChemicalRateProblems/threeGenes.jl")
include("ChemicalRateProblems/feedf.jl")
include("ChemicalRateProblems/inhosc.jl")
include("ChemicalRateProblems/bifeedb.jl")

# S-System Problems
include("SSystemProblems/ss_cascade.jl")
include("SSystemProblems/ss_branch.jl")
include("SSystemProblems/ss_5genes.jl")
include("SSystemProblems/ss_15genes.jl")
include("SSystemProblems/ss_30genes.jl")
include("SSystemProblems/ss_feedf.jl")
include("SSystemProblems/ss_inhosc.jl")
include("SSystemProblems/ss_bifeedb.jl")

# GMA Problems
include("GMAProblems/gma_problems.jl")

# Real Biological Problems
include("RealBiologicalProblems/biological_problems.jl")

# Re-export modules for direct access
# Re-export modules for direct access
using .SimpleLinModule
using .SimpleFbModule
using .OscModule
using .MetabolModule
using .ThreeGenesModule
using .FeedfModule
using .InhoscModule
using .BifeedbModule

# S-System modules
using .SsCascadeModule
using .SsBranchModule
using .Ss5genesModule
using .Ss15genesModule
using .Ss30genesModule
using .SsFeedfModule
using .SsInhoscModule
using .SsBifeedbModule

# GMA modules
using .GmaFeedfModule
using .GmaInhoscModule
using .GmaBifeedbModule

# Real biological modules
using .CytokineModule
using .SsEthanolfermModule
using .SsSosrepairModule
using .SsCadBAModule
using .SsClockModule

export SimpleLinModule, SimpleFbModule, OscModule, MetabolModule
export ThreeGenesModule, FeedfModule, InhoscModule, BifeedbModule
export SsCascadeModule, SsBranchModule, Ss5genesModule, Ss15genesModule, Ss30genesModule
export SsFeedfModule, SsInhoscModule, SsBifeedbModule
export GmaFeedfModule, GmaInhoscModule, GmaBifeedbModule
export CytokineModule, SsEthanolfermModule, SsSosrepairModule, SsCadBAModule, SsClockModule
export load_problem, list_problems, problem_info

"""
    list_problems()

List all available benchmark problems with their characteristics.

Returns a dictionary with problem names as keys and metadata as values.
"""
function list_problems()
    problems = Dict(
        # simpleLin problems
        "simpleLin1" => Dict(
            :module => "SimpleLinModule",
            :states => 3,
            :inputs => 2,
            :experiments => 3,
            :points_per_exp => 13,
            :noise => "0%",
            :description => "Simple linear metabolic pathway, perfect data"
        ),
        "simpleLin2" => Dict(
            :module => "SimpleLinModule",
            :states => 3,
            :inputs => 2,
            :experiments => 8,
            :points_per_exp => 13,
            :noise => "10%",
            :description => "Simple linear metabolic pathway, noisy data"
        ),
        
        # simpleFb problems
        "simpleFb1" => Dict(
            :module => "SimpleFbModule",
            :states => 3,
            :inputs => 0,
            :experiments => 4,
            :points_per_exp => 7,
            :noise => "0%",
            :description => "Feedback system, 4 experiments, perfect data"
        ),
        "simpleFb2" => Dict(
            :module => "SimpleFbModule",
            :states => 3,
            :inputs => 0,
            :experiments => 4,
            :points_per_exp => 7,
            :noise => "5%",
            :description => "Feedback system, 4 experiments, noisy data"
        ),
        "simpleFb3" => Dict(
            :module => "SimpleFbModule",
            :states => 3,
            :inputs => 0,
            :experiments => 1,
            :points_per_exp => 7,
            :noise => "0%",
            :description => "Feedback system, sparse data, perfect"
        ),
        "simpleFb4" => Dict(
            :module => "SimpleFbModule",
            :states => 3,
            :inputs => 0,
            :experiments => 1,
            :points_per_exp => 7,
            :noise => "~5%",
            :description => "Feedback system, sparse data, noisy"
        ),
        
        # osc problems
        "osc1" => Dict(
            :module => "OscModule",
            :states => 3,
            :inputs => 0,
            :experiments => 1,
            :points_per_exp => 41,
            :noise => "0%",
            :description => "Oscillator system, perfect data"
        ),
        "osc2" => Dict(
            :module => "OscModule",
            :states => 3,
            :inputs => 0,
            :experiments => 1,
            :points_per_exp => 41,
            :noise => "3%",
            :description => "Oscillator system, noisy data"
        ),
        
        # metabol problems
        "metabol1" => Dict(
            :module => "MetabolModule",
            :states => 5,
            :inputs => 2,
            :experiments => 12,
            :points_per_exp => 7,
            :noise => "0%",
            :description => "Metabolic pathway, perfect data"
        ),
        "metabol2" => Dict(
            :module => "MetabolModule",
            :states => 5,
            :inputs => 2,
            :experiments => 12,
            :points_per_exp => 21,
            :noise => "10%",
            :description => "Metabolic pathway, 10% noise"
        ),
        "metabol3" => Dict(
            :module => "MetabolModule",
            :states => 5,
            :inputs => 2,
            :experiments => 12,
            :points_per_exp => 21,
            :noise => "20%",
            :description => "Metabolic pathway, 20% noise"
        ),
        
        # threeGenes problems
        "threeGenes1" => Dict(
            :module => "ThreeGenesModule",
            :states => 8,
            :inputs => 0,
            :experiments => 16,
            :points_per_exp => 21,
            :noise => "0%",
            :description => "Gene network with N=3, perfect data"
        ),
        "threeGenes2" => Dict(
            :module => "ThreeGenesModule",
            :states => 8,
            :inputs => 0,
            :experiments => 16,
            :points_per_exp => 21,
            :noise => "5%",
            :description => "Gene network with N=3, noisy data"
        ),
        
        # feedf problems
        "feedf1" => Dict(
            :module => "FeedfModule",
            :states => 4,
            :inputs => 2,
            :experiments => 16,
            :points_per_exp => 51,
            :noise => "0%",
            :description => "Feed-forward pathway, perfect data"
        ),
        "feedf2" => Dict(
            :module => "FeedfModule",
            :states => 4,
            :inputs => 2,
            :experiments => 16,
            :points_per_exp => 51,
            :noise => "5%",
            :description => "Feed-forward pathway, noisy data"
        ),
        
        # inhosc problems
        "inhosc1" => Dict(
            :module => "InhoscModule",
            :states => 2,
            :inputs => 2,
            :experiments => 4,
            :points_per_exp => 51,
            :noise => "0%",
            :description => "Inhibitory oscillator, 2-state, perfect data"
        ),
        "inhosc2" => Dict(
            :module => "InhoscModule",
            :states => 4,
            :inputs => 2,
            :experiments => 4,
            :points_per_exp => 51,
            :noise => "3%",
            :description => "Inhibitory oscillator, 4-state, noisy data"
        ),
        
        # bifeedb problems
        "bifeedb1" => Dict(
            :module => "BifeedbModule",
            :states => 4,
            :inputs => 0,
            :experiments => 16,
            :points_per_exp => 51,
            :noise => "0%",
            :description => "Bi-molecular feedback, 4-state, perfect data"
        ),
        "bifeedb2" => Dict(
            :module => "BifeedbModule",
            :states => 5,
            :inputs => 0,
            :experiments => 16,
            :points_per_exp => 51,
            :noise => "5%",
            :description => "Bi-molecular feedback, 5-state, noisy data"
        ),
    )
    
    # Add S-system problems
    merge!(problems, Dict(
        "ss_cascade1" => Dict(:module => "SsCascadeModule", :states => 3, :inputs => 1, :experiments => 8, :points_per_exp => 41, :noise => "0%", :description => "S-system cascade, 8 exp"),
        "ss_cascade2" => Dict(:module => "SsCascadeModule", :states => 3, :inputs => 1, :experiments => 4, :points_per_exp => 41, :noise => "0%", :description => "S-system cascade, 4 exp"),
        "ss_cascade3" => Dict(:module => "SsCascadeModule", :states => 3, :inputs => 1, :experiments => 8, :points_per_exp => 41, :noise => "5%", :description => "S-system cascade, noisy"),
        "ss_branch1" => Dict(:module => "SsBranchModule", :states => 4, :inputs => 0, :experiments => 3, :points_per_exp => 21, :noise => "0%", :description => "S-system branch, 3 exp"),
        "ss_branch2" => Dict(:module => "SsBranchModule", :states => 4, :inputs => 0, :experiments => 6, :points_per_exp => 51, :noise => "0%", :description => "S-system branch, 6 exp"),
        "ss_branch3" => Dict(:module => "SsBranchModule", :states => 4, :inputs => 0, :experiments => 5, :points_per_exp => 20, :noise => "0%", :description => "S-system branch, 5 exp"),
        "ss_branch4" => Dict(:module => "SsBranchModule", :states => 4, :inputs => 0, :experiments => 4, :points_per_exp => 20, :noise => "0%", :description => "S-system branch, 4 exp"),
        "ss_branch5" => Dict(:module => "SsBranchModule", :states => 4, :inputs => 0, :experiments => 4, :points_per_exp => 20, :noise => "2.5%", :description => "S-system branch, 2.5% noise"),
        "ss_branch6" => Dict(:module => "SsBranchModule", :states => 4, :inputs => 0, :experiments => 5, :points_per_exp => 31, :noise => "0%", :description => "S-system branch, 31 pts"),
        "ss_5genes1" => Dict(:module => "Ss5genesModule", :states => 5, :inputs => 0, :experiments => 10, :points_per_exp => 11, :noise => "0%", :description => "5-gene network, 10 exp"),
        "ss_5genes2" => Dict(:module => "Ss5genesModule", :states => 5, :inputs => 0, :experiments => 10, :points_per_exp => 9, :noise => "20%", :description => "5-gene network, 20% noise"),
        "ss_5genes3" => Dict(:module => "Ss5genesModule", :states => 5, :inputs => 0, :experiments => 10, :points_per_exp => 3, :noise => "0%", :description => "5-gene network, sparse"),
        "ss_5genes4" => Dict(:module => "Ss5genesModule", :states => 5, :inputs => 0, :experiments => 15, :points_per_exp => 11, :noise => "0%", :description => "5-gene network, 15 exp"),
        "ss_5genes5" => Dict(:module => "Ss5genesModule", :states => 5, :inputs => 0, :experiments => 10, :points_per_exp => 11, :noise => "0%", :description => "5-gene network, variant 5"),
        "ss_5genes6" => Dict(:module => "Ss5genesModule", :states => 5, :inputs => 0, :experiments => 1, :points_per_exp => 16, :noise => "0%", :description => "5-gene network, 1 exp"),
        "ss_5genes7" => Dict(:module => "Ss5genesModule", :states => 5, :inputs => 0, :experiments => 10, :points_per_exp => 20, :noise => "0%", :description => "5-gene network, 20 pts"),
        "ss_5genes8" => Dict(:module => "Ss5genesModule", :states => 5, :inputs => 0, :experiments => 8, :points_per_exp => 41, :noise => "0%", :description => "5-gene network, 41 pts"),
        "ss_15genes1" => Dict(:module => "Ss15genesModule", :states => 15, :inputs => 0, :experiments => 10, :points_per_exp => 11, :noise => "0%", :description => "15-gene network, clean"),
        "ss_15genes2" => Dict(:module => "Ss15genesModule", :states => 15, :inputs => 0, :experiments => 20, :points_per_exp => 11, :noise => "10%", :description => "15-gene network, 10% noise"),
        "ss_30genes1" => Dict(:module => "Ss30genesModule", :states => 30, :inputs => 0, :experiments => 15, :points_per_exp => 11, :noise => "0%", :description => "30-gene network, clean"),
        "ss_30genes2" => Dict(:module => "Ss30genesModule", :states => 30, :inputs => 0, :experiments => 20, :points_per_exp => 11, :noise => "10%", :description => "30-gene network, 10% noise"),
        "ss_30genes3" => Dict(:module => "Ss30genesModule", :states => 30, :inputs => 0, :experiments => 8, :points_per_exp => 41, :noise => "0%", :description => "30-gene network, 41 pts"),
        "ss_feedf1" => Dict(:module => "SsFeedfModule", :states => 4, :inputs => 2, :experiments => 16, :points_per_exp => 51, :noise => "0%", :description => "S-system feedf, clean"),
        "ss_feedf2" => Dict(:module => "SsFeedfModule", :states => 4, :inputs => 2, :experiments => 16, :points_per_exp => 51, :noise => "5%", :description => "S-system feedf, 5% noise"),
        "ss_inhosc1" => Dict(:module => "SsInhoscModule", :states => 4, :inputs => 2, :experiments => 4, :points_per_exp => 51, :noise => "0%", :description => "S-system inhosc, clean"),
        "ss_inhosc2" => Dict(:module => "SsInhoscModule", :states => 4, :inputs => 2, :experiments => 4, :points_per_exp => 51, :noise => "5%", :description => "S-system inhosc, 5% noise"),
        "ss_bifeedb1" => Dict(:module => "SsBifeedbModule", :states => 5, :inputs => 0, :experiments => 16, :points_per_exp => 51, :noise => "0%", :description => "S-system bifeedb, clean"),
        "ss_bifeedb2" => Dict(:module => "SsBifeedbModule", :states => 5, :inputs => 0, :experiments => 16, :points_per_exp => 51, :noise => "5%", :description => "S-system bifeedb, 5% noise"),
    ))
    
    # Add GMA problems
    merge!(problems, Dict(
        "gma_feedf1" => Dict(:module => "GmaFeedfModule", :states => 4, :inputs => 2, :experiments => 16, :points_per_exp => 51, :noise => "0%", :description => "GMA feedf, clean"),
        "gma_feedf2" => Dict(:module => "GmaFeedfModule", :states => 4, :inputs => 2, :experiments => 16, :points_per_exp => 51, :noise => "5%", :description => "GMA feedf, 5% noise"),
        "gma_inhosc1" => Dict(:module => "GmaInhoscModule", :states => 4, :inputs => 2, :experiments => 4, :points_per_exp => 51, :noise => "0%", :description => "GMA inhosc, clean"),
        "gma_inhosc2" => Dict(:module => "GmaInhoscModule", :states => 4, :inputs => 2, :experiments => 4, :points_per_exp => 51, :noise => "5%", :description => "GMA inhosc, 5% noise"),
        "gma_bifeedb1" => Dict(:module => "GmaBifeedbModule", :states => 5, :inputs => 0, :experiments => 16, :points_per_exp => 51, :noise => "0%", :description => "GMA bifeedb, clean"),
        "gma_bifeedb2" => Dict(:module => "GmaBifeedbModule", :states => 5, :inputs => 0, :experiments => 16, :points_per_exp => 51, :noise => "5%", :description => "GMA bifeedb, 5% noise"),
    ))
    
    # Add real biological problems
    merge!(problems, Dict(
        "cytokine1" => Dict(:module => "CytokineModule", :states => 4, :inputs => 0, :experiments => 1, :points_per_exp => 7, :noise => "10%", :description => "Cytokine network, exp 1"),
        "cytokine2" => Dict(:module => "CytokineModule", :states => 4, :inputs => 0, :experiments => 1, :points_per_exp => 7, :noise => "10%", :description => "Cytokine network, exp 2"),
        "ss_ethanolferm1" => Dict(:module => "SsEthanolfermModule", :states => 4, :inputs => 0, :experiments => 3, :points_per_exp => 15, :noise => "30%", :description => "Ethanol fermentation, 3 exp"),
        "ss_ethanolferm2" => Dict(:module => "SsEthanolfermModule", :states => 4, :inputs => 0, :experiments => 2, :points_per_exp => 13, :noise => "30%", :description => "Ethanol fermentation, 2 exp"),
        "ss_sosrepair1" => Dict(:module => "SsSosrepairModule", :states => 6, :inputs => 0, :experiments => 1, :points_per_exp => 50, :noise => "10%", :description => "SOS DNA repair, exp 1"),
        "ss_sosrepair2" => Dict(:module => "SsSosrepairModule", :states => 6, :inputs => 0, :experiments => 1, :points_per_exp => 50, :noise => "10%", :description => "SOS DNA repair, exp 2"),
        "ss_cadBA1" => Dict(:module => "SsCadBAModule", :states => 4, :inputs => 0, :experiments => 1, :points_per_exp => 25, :noise => "<20%", :description => "CadBA system, exp 1"),
        "ss_cadBA2" => Dict(:module => "SsCadBAModule", :states => 4, :inputs => 0, :experiments => 1, :points_per_exp => 25, :noise => "<20%", :description => "CadBA system, exp 2"),
        "ss_clock1" => Dict(:module => "SsClockModule", :states => 7, :inputs => 0, :experiments => 1, :points_per_exp => 12, :noise => "~10%", :description => "Circadian clock, exp 1"),
        "ss_clock2" => Dict(:module => "SsClockModule", :states => 7, :inputs => 0, :experiments => 1, :points_per_exp => 12, :noise => "~10%", :description => "Circadian clock, exp 2"),
    ))
    
    return problems
end

"""
    problem_info(problem_name::String)

Get detailed information about a specific benchmark problem.
"""
function problem_info(problem_name::String)
    problems = list_problems()
    if haskey(problems, problem_name)
        info = problems[problem_name]
        println("Problem: $problem_name")
        println("  Module: $(info[:module])")
        println("  States: $(info[:states])")
        println("  Inputs: $(info[:inputs])")
        println("  Experiments: $(info[:experiments])")
        println("  Points per experiment: $(info[:points_per_exp])")
        println("  Noise level: $(info[:noise])")
        println("  Description: $(info[:description])")
        return info
    else
        available = join(sort(collect(keys(problems))), ", ")
        error("Unknown problem: $problem_name\nAvailable problems: $available")
    end
end

"""
    load_problem(problem_name::String; num_trajectories::Union{Int,Nothing}=nothing)

Load a specific benchmark problem dataset by name.

Arguments:
- problem_name: Name of the problem (e.g., "simpleLin1", "simpleLin2")
- num_trajectories: Number of trajectories to use (default: nothing = use all)
                    If specified, selects the first N trajectories from the problem

Returns:
- Vector of experiment dictionaries with keys :t, :X, :inputs, :params

Available problems:
- simpleLin1, simpleLin2
- simpleFb1, simpleFb2, simpleFb3, simpleFb4
- osc1, osc2
- metabol1, metabol2, metabol3
- threeGenes1, threeGenes2
- feedf1, feedf2
- inhosc1, inhosc2
- bifeedb1, bifeedb2

Examples:
```julia
# Load standard benchmark (all trajectories)
experiments = load_problem("simpleLin1")

# Load with limited trajectories
experiments = load_problem("bifeedb1", num_trajectories=3)
```
"""
function load_problem(problem_name::String; num_trajectories::Union{Int,Nothing}=nothing)
    # Load the full problem dataset
    experiments = if startswith(problem_name, "simpleLin")
        # simpleLin supports num_trajectories natively
        SimpleLinModule.generate_simplelin_experiments(
            noise_std = problem_name == "simpleLin1" ? 0.0 : 0.1,
            num_trajectories = num_trajectories === nothing ? 1 : num_trajectories)
    elseif startswith(problem_name, "simpleFb")
        SimpleFbModule.generate_simplefb_experiments(problem=problem_name)
    elseif startswith(problem_name, "osc")
        OscModule.generate_osc_experiments(problem=problem_name)
    elseif startswith(problem_name, "metabol")
        MetabolModule.generate_metabol_experiments(problem=problem_name)
    elseif startswith(problem_name, "threeGenes")
        ThreeGenesModule.generate_threegenes_experiments(problem=problem_name)
    elseif problem_name in ["feedf1", "feedf2"]
        FeedfModule.generate_feedf_experiments(problem=problem_name)
    elseif problem_name in ["inhosc1", "inhosc2"]
        InhoscModule.generate_inhosc_experiments(problem=problem_name)
    elseif problem_name in ["bifeedb1", "bifeedb2"]
        BifeedbModule.generate_bifeedb_experiments(problem=problem_name)
    
    # S-System Problems
    elseif startswith(problem_name, "ss_cascade")
        SsCascadeModule.generate_ss_cascade_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_branch")
        SsBranchModule.generate_ss_branch_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_5genes")
        Ss5genesModule.generate_ss_5genes_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_15genes")
        Ss15genesModule.generate_ss_15genes_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_30genes")
        Ss30genesModule.generate_ss_30genes_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_feedf")
        SsFeedfModule.generate_ss_feedf_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_inhosc")
        SsInhoscModule.generate_ss_inhosc_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_bifeedb")
        SsBifeedbModule.generate_ss_bifeedb_experiments(problem=problem_name)
    
    # GMA Problems
    elseif startswith(problem_name, "gma_feedf")
        GmaFeedfModule.generate_gma_feedf_experiments(problem=problem_name)
    elseif startswith(problem_name, "gma_inhosc")
        GmaInhoscModule.generate_gma_inhosc_experiments(problem=problem_name)
    elseif startswith(problem_name, "gma_bifeedb")
        GmaBifeedbModule.generate_gma_bifeedb_experiments(problem=problem_name)
    
    # Real Biological Problems
    elseif startswith(problem_name, "cytokine")
        CytokineModule.generate_cytokine_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_ethanolferm")
        SsEthanolfermModule.generate_ss_ethanolferm_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_sosrepair")
        SsSosrepairModule.generate_ss_sosrepair_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_cadBA")
        SsCadBAModule.generate_ss_cadBA_experiments(problem=problem_name)
    elseif startswith(problem_name, "ss_clock")
        SsClockModule.generate_ss_clock_experiments(problem=problem_name)
    
    else
        available = join(sort(collect(keys(list_problems()))), ", ")
        error("Unknown problem: $problem_name\nAvailable problems: $available")
    end
    
    # Handle num_trajectories parameter
    if num_trajectories !== nothing
        n_available = length(experiments)
        
        if num_trajectories <= n_available
            # Just take the first num_trajectories experiments
            return experiments[1:num_trajectories]
        else
            # Need more trajectories than available - generate additional ones
            # by perturbing initial conditions of existing experiments
            additional_needed = num_trajectories - n_available
            extended_experiments = copy(experiments)
            
            for i in 1:additional_needed
                # Use existing experiment as template (cycle through if needed)
                base_idx = ((i - 1) % n_available) + 1
                base_exp = experiments[base_idx]
                
                # Create perturbed initial condition
                # Use small random perturbations (5-10% of initial values)
                X0_base = base_exp[:X][1, :]
                perturbation_scale = 0.05 + 0.05 * rand()  # 5-10%
                X0_new = X0_base .* (1.0 .+ perturbation_scale .* randn(length(X0_base)))
                
                # Make sure new initial conditions are positive (for biological systems)
                X0_new = max.(X0_new, 1e-6)
                
                # Generate new trajectory with perturbed IC
                # Try to call the appropriate generation function
                try
                    local t, X
                    has_inputs = haskey(base_exp, :inputs) && !isempty(base_exp[:inputs])
                    tspan = (base_exp[:t][1], base_exp[:t][end])
                    n_points = length(base_exp[:t])
                    
                    # Determine which module to use based on problem name
                    if startswith(problem_name, "simpleFb")
                        t, X = SimpleFbModule.generate_simplefb_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "simpleLin")
                        t, X = SimpleLinModule.generate_simplelin_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "osc")
                        t, X = OscModule.generate_osc_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "metabol")
                        t, X = MetabolModule.generate_metabol_data(X0=X0_new, tspan=tspan, n_points=n_points, 
                                                                     inputs=get(base_exp, :inputs, Dict()), noise_std=0.0)
                    elseif startswith(problem_name, "threeGenes")
                        t, X = ThreeGenesModule.generate_threegenes_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "bifeedb")
                        t, X = BifeebdModule.generate_bifeedb_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "feedf")
                        t, X = FeedfModule.generate_feedf_data(X0=X0_new, tspan=tspan, n_points=n_points,
                                                                inputs=get(base_exp, :inputs, Dict()), noise_std=0.0)
                    elseif startswith(problem_name, "inhosc")
                        t, X, _ = InhoscModule.generate_inhosc_data(X0=X0_new, tspan=tspan, n_points=n_points,
                                                                      inputs=get(base_exp, :inputs, Dict()), noise_std=0.0)
                    elseif startswith(problem_name, "cytokine")
                        t, X, _ = CytokineModule.generate_cytokine_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_ethanolferm")
                        t, X, _ = SsEthanolfermModule.generate_ss_ethanolferm_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_sosrepair")
                        t, X, _ = SsSosrepairModule.generate_ss_sosrepair_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_cadBA")
                        t, X, _ = SsCadBAModule.generate_ss_cadBA_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_clock")
                        t, X, _ = SsClockModule.generate_ss_clock_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_cascade")
                        t, X, _ = SsCascadeModule.generate_ss_cascade_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_branch")
                        t, X, _ = SsBranchModule.generate_ss_branch_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_bifeedb")
                        t, X, _ = SsBifeebdModule.generate_ss_bifeedb_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_feedf")
                        t, X, _ = SsFeedfModule.generate_ss_feedf_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_inhosc")
                        t, X, _ = SsInhoscModule.generate_ss_inhosc_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_5genes")
                        t, X, _ = Ss5GenesModule.generate_ss_5genes_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_15genes")
                        t, X, _ = Ss15GenesModule.generate_ss_15genes_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "ss_30genes")
                        t, X, _ = Ss30GenesModule.generate_ss_30genes_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "gma_bifeedb")
                        t, X, _ = GmaBifeebdModule.generate_gma_bifeedb_data(X0=X0_new, tspan=tspan, n_points=n_points, noise_std=0.0)
                    elseif startswith(problem_name, "gma_feedf")
                        t, X, _ = GmaFeedfModule.generate_gma_feedf_data(X0=X0_new, tspan=tspan, n_points=n_points,
                                                                          In1_const=1.0, In2_const=1.0, noise_std=0.0)
                    elseif startswith(problem_name, "gma_inhosc")
                        t, X, _ = GmaInhoscModule.generate_gma_inhosc_data(X0=X0_new, tspan=tspan, n_points=n_points,
                                                                            In1_const=1.0, In2_const=1.0, noise_std=0.0)
                    else
                        # Unknown problem type - skip generation
                        @warn "No generation function available for problem type: $problem_name"
                        continue
                    end
                    
                    # Create new experiment dict
                    new_exp = Dict(
                        :experiment => n_available + i,
                        :t => t,
                        :X => X,
                        :X0 => X0_new
                    )
                    
                    # Preserve inputs if present
                    if haskey(base_exp, :inputs)
                        new_exp[:inputs] = base_exp[:inputs]
                    end
                    
                    push!(extended_experiments, new_exp)
                catch e
                    # If generation fails, just duplicate the base experiment with warning
                    @warn "Could not generate new trajectory for $problem_name, duplicating experiment $base_idx"
                    push!(extended_experiments, base_exp)
                end
            end
            
            return extended_experiments
        end
    else
        return experiments
    end
end

end # module
