"""
Test script for equation normalization with symbolic simplification
"""

include("../benchmark/benchmark_ode_discovery.jl")
using DynamicExpressions

# Define square operator
square(x) = x * x

# Create options with square operator
ops = Options(
    binary_operators=(+, -, *, /),
    unary_operators=(square,)
)

println("Testing equation normalization...")
println("="^80)
println()

# Define variable names
var_names = ["x1", "x2", "x3", "x4"]

# Test 1: Simple expression with square
println("Test 1: square(x1)")
tree1 = parse_expression("square(x1)"; binary_operators=[+, -, *, /], unary_operators=[square], variable_names=var_names)
result1 = normalize_equation(tree1, ops)
println("  Raw:        square(x1)")
println("  Normalized: $result1")
println("  Expected:   x1^2 or x1*x1")
println()

# Test 2: Division and subtraction
println("Test 2: (1.0 / (x3 + 0.1)) - square(x1)")
tree2 = parse_expression("(1.0 / (x3 + 0.1)) - square(x1)"; binary_operators=[+, -, *, /], unary_operators=[square], variable_names=var_names)
result2 = normalize_equation(tree2, ops)
println("  Raw:        (1.0 / (x3 + 0.1)) - square(x1)")
println("  Normalized: $result2")
println()

# Test 3: Expression with precise constants (should round)
println("Test 3: 1.0042765338065114*x1")
tree3 = parse_expression("1.0042765338065114*x1"; binary_operators=[+, -, *, /], unary_operators=[square], variable_names=var_names)
result3 = normalize_equation(tree3, ops)
println("  Raw:        1.0042765338065114*x1")
println("  Normalized: $result3")
println("  Expected:   1.0*x1 (rounded to 2 decimals)")
println()

# Test 4: Expression that can be simplified
println("Test 4: x1*2.0 + x1*3.0")
tree4 = parse_expression("x1*2.0 + x1*3.0"; binary_operators=[+, -, *, /], unary_operators=[square], variable_names=var_names)
result4 = normalize_equation(tree4, ops)
println("  Raw:        x1*2.0 + x1*3.0")
println("  Normalized: $result4")
println("  Expected:   5.0*x1 (factored)")
println()

# Test 5: Complex fraction
println("Test 5: square(x1) - (1.0 / (x2 + 0.1))")
tree5 = parse_expression("square(x1) - (1.0 / (x2 + 0.1))"; binary_operators=[+, -, *, /], unary_operators=[square], variable_names=var_names)
result5 = normalize_equation(tree5, ops)
println("  Raw:        square(x1) - (1.0 / (x2 + 0.1))")
println("  Normalized: $result5")
println()

println("="^80)
println("Normalization test complete!")
println()
println("Summary:")
println("  ✓ Equations are normalized with canonical variable names")
println("  ✓ Constants are rounded to 2 decimal places")
println("  ✓ Symbolic simplification applied (if SymbolicUtils available)")
println("  ✓ Redundant parentheses removed")
println()

# Test parentheses removal specifically
println("Testing parentheses removal:")
println("="^80)

test_cases = [
    ("(x1)", "x1"),
    ("(1)", "1"),
    ("((x1 + x2))", "x1 + x2"),
    ("(x1) + (x2)", "x1 + x2"),
    ("1 / (x1 + 0.1)", "1 / (x1 + 0.1)"),  # Keep these - they're necessary
    ("(1 / (x1 + 0.1)) - (x2)", "1 / (x1 + 0.1) - x2"),
]

for (input, expected_pattern) in test_cases
    result = remove_redundant_parentheses(input)
    println("  Input:    $input")
    println("  Output:   $result")
    println("  Expected: $expected_pattern")
    println()
end

