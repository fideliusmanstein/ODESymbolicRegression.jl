"""
create_all_unified_problems.jl

Script to systematically create all unified problem implementations.
Run this to generate all remaining problem files.
"""

using Pkg
Pkg.activate(".")

# This script will read the legacy problem definitions and create unified versions
# For now, we'll create them manually in batches

println("Creating unified problem architecture for all benchmark problems...")
println("="^80)
println()

# List of problems to create (organized by type)
chemical_rate_problems = [
    ("metabol", 3, 5, 2),  # (name, variants, states, inputs)
    ("feedf", 2, 4, 2),
    ("inhosc", 2, 2, 2),  # variable: 2-4 states
    ("bifeedb", 2, 4, 0),  # variable: 4-5 states  
    ("threeGenes", 2, 8, 2)
]

s_system_problems = [
    ("ss_cascade", 3, 3, 2),
    ("ss_branch", 6, 5, 2),
    ("ss_5genes", 8, 5, 2),
    ("ss_15genes", 2, 15, 2),
    ("ss_30genes", 3, 30, 2),
    ("ss_feedf", 2, 4, 2),
    ("ss_inhosc", 2, 2, 2),
    ("ss_bifeedb", 2, 4, 0)
]

gma_problems = [
    ("gma_feedf", 2, 4, 2),
    ("gma_inhosc", 2, 2, 2),
    ("gma_bifeedb", 2, 4, 0)
]

biological_problems = [
    ("cytokine", 2, 4, 0),
    ("ss_ethanolferm", 2, 4, 0),
    ("ss_sosrepair", 2, 7, 0),
    ("ss_cadBA", 2, 4, 0),
    ("ss_clock", 2, 7, 0)
]

println("Chemical Rate Problems (", sum(p[2] for p in chemical_rate_problems), " variants):")
for (name, variants, states, inputs) in chemical_rate_problems
    println("  $name: $variants variants, $states states, $inputs inputs")
end
println()

println("S-System Problems (", sum(p[2] for p in s_system_problems), " variants):")
for (name, variants, states, inputs) in s_system_problems
    println("  $name: $variants variants, $states states, $inputs inputs")
end
println()

println("GMA Problems (", sum(p[2] for p in gma_problems), " variants):")
for (name, variants, states, inputs) in gma_problems
    println("  $name: $variants variants, $states states, $inputs inputs")
end
println()

println("Biological Problems (", sum(p[2] for p in biological_problems), " variants):")
for (name, variants, states, inputs) in biological_problems
    println("  $name: $variants variants, $states states, $inputs inputs")
end
println()

total_variants = (
    sum(p[2] for p in chemical_rate_problems) +
    sum(p[2] for p in s_system_problems) +
    sum(p[2] for p in gma_problems) +
    sum(p[2] for p in biological_problems)
)

println("="^80)
println("Total variants to create: $total_variants")
println("Already created: 8 (simpleLin1/2, simpleFb1-4, osc1/2)")
println("Remaining: $(total_variants - 8)")
println("="^80)
println()

println("NOTE: Due to the large scope, we recommend:")
println("1. Create problem files in batches by category")
println("2. Test each batch before proceeding")
println("3. Update UnifiedBenchmarkSystems.jl incrementally")
println("4. Run test_all_unified_problems.jl after each batch")
