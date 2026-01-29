# Equation Comparison Guide

## Overview

This guide explains strategies for comparing discovered ODE equations against ground truth equations. Since symbolic equations can be mathematically equivalent while having different representations, we need multiple comparison approaches.

## The Challenge

Consider these equivalent equations:
- Ground truth: `X1' = 1.0/(X3+0.1) - 1.0*X1^2`
- Discovered: `X1' = (1.0 / (x3 + 0.1)) - square(x1)`

These are **mathematically identical** but differ in:
- Notation: `X1^2` vs `square(x1)` 
- Variable names: `X3` vs `x3`
- Formatting: spacing and parentheses

Even worse, consider:
- Ground truth: `X2' = 1.0*X1^2 - 1.0*X2/(X2+0.1)`
- Discovered: `X2' = square(x1) - (0.99 / (x2 + 0.1))`

The constant `1.0` is approximated as `0.99` - still very good, but not exact.

---

## Comparison Strategies

### 1. String Matching (Simplest, Least Robust)

**What it does:** Direct string comparison after normalization.

**Steps:**
1. Convert both equations to lowercase
2. Remove whitespace
3. Standardize operators (`^2` → `square()`)
4. Compare strings

**Limitations:**
- Fails on mathematically equivalent forms: `x*2` vs `2*x`
- Fails on rounded constants: `1.0` vs `0.999`
- Fails on reordered terms: `a + b` vs `b + a`

**Use case:** Quick initial check only.

```julia
function string_comparison(eq1::String, eq2::String)
    # Normalize
    norm1 = lowercase(replace(eq1, r"\s" => ""))
    norm2 = lowercase(replace(eq2, r"\s" => ""))
    
    return norm1 == norm2
end
```

---

### 2. Numerical Equivalence (Most Practical)

**What it does:** Evaluates both equations on test data and compares outputs.

**Steps:**
1. Generate test data: random points across the state space
2. Evaluate ground truth equation at test points → `y_true`
3. Evaluate discovered equation at test points → `y_pred`
4. Compute similarity metrics:
   - **R² score**: Measures correlation (1.0 = perfect)
   - **Mean Squared Error (MSE)**: Average squared difference
   - **Relative error**: Percentage deviation

**Advantages:**
- Works regardless of symbolic form
- Handles approximations (0.999 ≈ 1.0)
- Fast and reliable

**Limitations:**
- Requires evaluation capability
- May miss symbolic differences that cancel numerically

**Implementation:**

```julia
using Statistics

function numerical_equivalence(expr1, expr2, X_test::Matrix; threshold=1e-6)
    """
    Compare two expressions numerically.
    
    Args:
        expr1, expr2: Expression trees or functions
        X_test: Test data matrix (n_samples × n_features)
        threshold: MSE threshold for equivalence
    
    Returns:
        Dict with metrics and verdict
    """
    # Evaluate on test data
    y_true = [expr1(X_test[i, :]) for i in 1:size(X_test, 1)]
    y_pred = [expr2(X_test[i, :]) for i in 1:size(X_test, 1)]
    
    # Compute metrics
    r2 = cor(y_true, y_pred)^2
    mse = mean((y_true .- y_pred).^2)
    rel_error = mean(abs.((y_true .- y_pred) ./ (abs.(y_true) .+ 1e-10)))
    
    # Verdict
    equivalent = mse < threshold
    
    return Dict(
        "r2" => r2,
        "mse" => mse,
        "relative_error" => rel_error,
        "equivalent" => equivalent,
        "verdict" => equivalent ? "NUMERICALLY_EQUIVALENT" : 
                     r2 > 0.99 ? "VERY_SIMILAR" :
                     r2 > 0.95 ? "SIMILAR" : "DIFFERENT"
    )
end

# Example usage:
X_test = randn(1000, 4)  # 1000 test points, 4 state variables
result = numerical_equivalence(ground_truth_tree, discovered_tree, X_test)
println("R² = $(result["r2"]), MSE = $(result["mse"])")
```

---

### 3. Symbolic Simplification (Most Rigorous)

**What it does:** Converts equations to canonical form using computer algebra.

**Tools:**
- **SymbolicUtils.jl**: Low-level symbolic manipulation
- **Symbolics.jl**: High-level symbolic math
- **ModelingToolkit.jl**: Specialized for ODEs

**Canonicalization Steps:**

1. **Parse to symbolic form**
   ```julia
   using Symbolics
   @variables x1, x2, x3, x4
   
   # Parse string to symbolic expression
   expr = Meta.parse("1.0/(x3 + 0.1) - x1^2")
   ```

2. **Simplify**
   ```julia
   using SymbolicUtils
   simplified = simplify(expr)
   ```

3. **Expand products**
   ```julia
   expanded = expand(simplified)
   # (a+b)*(c+d) → ac + ad + bc + bd
   ```

4. **Combine like terms**
   ```julia
   combined = simplify(expanded)
   # 2x + 3x → 5x
   # x^2 - 2x^2 → -x^2
   ```

5. **Sort terms** (lexicographic order)
   ```julia
   # -x^2 + 3x + 1  (standard polynomial form)
   ```

6. **Normalize coefficients**
   ```julia
   # Factor out GCD: 2x + 4y → 2(x + 2y)
   # Normalize leading coefficient: -x^2 + ... → -(x^2 - ...)
   ```

**Implementation:**

```julia
using SymbolicUtils
using Symbolics

function canonicalize_equation(eq_str::String, variables::Vector{Symbol})
    """
    Convert equation string to canonical symbolic form.
    
    Args:
        eq_str: Equation as string (e.g., "1.0/(x3 + 0.1) - x1^2")
        variables: List of variable symbols (e.g., [:x1, :x2, :x3, :x4])
    
    Returns:
        Canonical symbolic expression
    """
    # Create symbolic variables
    @variables $(variables...)
    
    # Parse string to expression
    expr = eval(Meta.parse(eq_str))
    
    # Simplification pipeline
    expr = simplify(expr)           # Basic simplification
    expr = expand(expr)             # Expand products
    expr = simplify(expr)           # Combine like terms
    
    return expr
end

function symbolic_comparison(eq1_str::String, eq2_str::String, vars::Vector{Symbol})
    """
    Compare two equations symbolically.
    
    Returns:
        "EXACT_MATCH", "EQUIVALENT", or "DIFFERENT"
    """
    # Canonicalize both
    canon1 = canonicalize_equation(eq1_str, vars)
    canon2 = canonicalize_equation(eq2_str, vars)
    
    # Direct equality check
    if isequal(canon1, canon2)
        return "EXACT_MATCH"
    end
    
    # Check if difference simplifies to zero
    diff = simplify(canon1 - canon2)
    if iszero(diff)
        return "EQUIVALENT"
    end
    
    return "DIFFERENT"
end

# Example:
vars = [:x1, :x2, :x3, :x4]
eq1 = "1.0/(x3 + 0.1) - x1^2"
eq2 = "x1^2 - 1.0/(0.1 + x3)"  # Reordered
result = symbolic_comparison(eq1, eq2, vars)  # "EQUIVALENT"
```

**Advantages:**
- Mathematically rigorous
- Handles reordering, regrouping, factorization
- Identifies exact symbolic equivalence

**Limitations:**
- Complex to implement
- Requires symbolic manipulation library
- May struggle with transcendental functions
- Sensitive to numerical precision in coefficients

---

### 4. Structural Similarity (For Partial Credit)

**What it does:** Measures how "similar" two equations are structurally.

**Metrics:**

1. **Operator overlap** (Jaccard similarity)
   ```julia
   ops1 = [+, -, /, ^]  # Operators in equation 1
   ops2 = [+, -, /]     # Operators in equation 2
   similarity = |ops1 ∩ ops2| / |ops1 ∪ ops2|
              = 3 / 4 = 0.75
   ```

2. **Variable overlap**
   ```julia
   vars1 = [:x1, :x3]
   vars2 = [:x1, :x2, :x3]
   similarity = 2 / 3 = 0.67
   ```

3. **Tree depth ratio**
   ```julia
   depth1 = tree_depth(expr1)  # Maximum nesting level
   depth2 = tree_depth(expr2)
   ratio = min(depth1, depth2) / max(depth1, depth2)
   ```

4. **Tree edit distance** (Advanced)
   - Number of insertions/deletions/substitutions needed to transform one tree into another
   - Computationally expensive but very accurate

**Implementation:**

```julia
function structural_similarity(tree1, tree2)
    """
    Compute structural similarity metrics.
    """
    # Extract operators
    ops1 = extract_operators(tree1)
    ops2 = extract_operators(tree2)
    op_jaccard = length(intersect(ops1, ops2)) / length(union(ops1, ops2))
    
    # Extract variables
    vars1 = extract_variables(tree1)
    vars2 = extract_variables(tree2)
    var_jaccard = length(intersect(vars1, vars2)) / length(union(vars1, vars2))
    
    # Tree depth
    depth1 = compute_tree_depth(tree1)
    depth2 = compute_tree_depth(tree2)
    depth_ratio = min(depth1, depth2) / max(depth1, depth2)
    
    # Combined score (weighted average)
    overall = 0.4 * op_jaccard + 0.4 * var_jaccard + 0.2 * depth_ratio
    
    return Dict(
        "operator_similarity" => op_jaccard,
        "variable_similarity" => var_jaccard,
        "depth_similarity" => depth_ratio,
        "overall_similarity" => overall
    )
end

function extract_operators(tree)
    # Recursively collect all operator nodes
    operators = Set()
    traverse_tree(tree) do node
        if is_operator(node)
            push!(operators, node.op)
        end
    end
    return operators
end

function extract_variables(tree)
    # Recursively collect all variable nodes
    variables = Set()
    traverse_tree(tree) do node
        if is_variable(node)
            push!(variables, node.name)
        end
    end
    return variables
end
```

---

## Recommended Multi-Tier Approach

For robust comparison, use **all methods in sequence**:

```julia
function comprehensive_comparison(
    ground_truth_str::String,
    discovered_str::String,
    ground_truth_tree,
    discovered_tree,
    test_data::Matrix
)
    """
    Complete comparison pipeline.
    
    Returns scoring dict with verdict.
    """
    results = Dict()
    
    # Tier 1: Exact string match (quick check)
    results["string_match"] = string_comparison(ground_truth_str, discovered_str)
    if results["string_match"]
        return Dict("score" => 1.0, "verdict" => "EXACT_STRING_MATCH")
    end
    
    # Tier 2: Symbolic comparison (if available)
    try
        vars = [:x1, :x2, :x3, :x4]
        results["symbolic"] = symbolic_comparison(
            ground_truth_str, discovered_str, vars
        )
        if results["symbolic"] ∈ ["EXACT_MATCH", "EQUIVALENT"]
            return Dict("score" => 1.0, "verdict" => "SYMBOLICALLY_EQUIVALENT")
        end
    catch e
        @warn "Symbolic comparison failed: $e"
        results["symbolic"] = "UNAVAILABLE"
    end
    
    # Tier 3: Numerical equivalence
    results["numerical"] = numerical_equivalence(
        ground_truth_tree, discovered_tree, test_data
    )
    
    if results["numerical"]["r2"] > 0.999
        score = 0.95
        verdict = "NUMERICALLY_EQUIVALENT"
    elseif results["numerical"]["r2"] > 0.95
        score = 0.85
        verdict = "HIGHLY_SIMILAR"
    else
        # Tier 4: Structural similarity (partial credit)
        results["structural"] = structural_similarity(
            ground_truth_tree, discovered_tree
        )
        score = results["structural"]["overall_similarity"] * 0.5
        verdict = "PARTIALLY_SIMILAR"
    end
    
    return Dict(
        "score" => score,
        "verdict" => verdict,
        "details" => results
    )
end
```

---

## Special Considerations for ODE Systems

### Handling Operator Differences

Your system uses:
- Ground truth: `X1^2` (power operator)
- Discovered: `square(x1)` (unary operator)

**Solution:** Map operators before comparison:
```julia
function normalize_operators(eq_str)
    replacements = [
        "square(x)" => "x^2",
        "x^2" => "x*x",  # Expand for canonical form
        "1.0*" => "",    # Remove identity multiplication
        "*1.0" => ""
    ]
    
    for (pattern, replacement) in replacements
        eq_str = replace(eq_str, pattern => replacement)
    end
    
    return eq_str
end
```

### Handling Rational Functions

Ground truth equations contain terms like `1/(X+0.1)`:

**Canonicalization:**
1. Factor denominators: `2/(4x+2)` → `1/(2x+1)`
2. Combine fractions: `a/x + b/x` → `(a+b)/x`
3. Standard form: `(numerator)/(denominator)` where denominator is monic

```julia
function canonicalize_rational(expr)
    # Extract numerator and denominator
    num, den = numerator(expr), denominator(expr)
    
    # Simplify both
    num = simplify(num)
    den = simplify(den)
    
    # Make denominator monic (leading coefficient = 1)
    if den isa Polynomial
        lead_coef = leading_coefficient(den)
        num = num / lead_coef
        den = den / lead_coef
    end
    
    return num / den
end
```

### Variable Name Normalization

Ground truth uses `X1, X2, X3` while discovered uses `x1, x2, x3`.

**Solution:**
```julia
function normalize_variable_names(eq_str)
    # Convert all to lowercase
    eq_str = lowercase(eq_str)
    
    # Standardize to x1, x2, etc.
    for i in 1:10
        eq_str = replace(eq_str, "X$i" => "x$i")
        eq_str = replace(eq_str, "state$i" => "x$i")
    end
    
    return eq_str
end
```

---

## Practical Example

```julia
# Ground truth
gt = "1.0/(X3+0.1) - 1.0*X1^2"

# Discovered (with noise)
disc = "(1.0 / (x3 + 0.1)) - square(x1)"

# Step 1: Normalize
gt_norm = normalize_variable_names(gt)      # "1.0/(x3+0.1) - 1.0*x1^2"
disc_norm = normalize_operators(disc)       # "(1.0 / (x3 + 0.1)) - x1*x1"

# Step 2: Symbolic comparison
vars = [:x1, :x2, :x3, :x4]
result = symbolic_comparison(gt_norm, disc_norm, vars)
# Result: "EQUIVALENT"

# Step 3: If symbolic fails, try numerical
if result == "DIFFERENT"
    X_test = randn(1000, 4)
    num_result = numerical_equivalence(gt_tree, disc_tree, X_test)
    println("R² = $(num_result["r2"])")  # Should be ≈ 1.0
end
```

---

## Integration with Benchmark System

Add comparison to `benchmark_ode_discovery.jl`:

```julia
function benchmark_single_problem_with_comparison(problem_name; ode_options=nothing, num_trajectories=1)
    # ... existing discovery code ...
    
    # After discovery, compare each equation
    equation_scores = []
    for i in 1:n_states
        gt_eq = ground_truth_equations[i]
        disc_eq = discovered_equations[i]
        
        comparison = comprehensive_comparison(
            gt_eq, disc_eq,
            ground_truth_trees[i], result.best_trees[i],
            test_data
        )
        
        push!(equation_scores, comparison["score"])
    end
    
    # Overall score = average of equation scores
    overall_score = mean(equation_scores)
    
    return Dict(
        # ... existing fields ...
        "equation_scores" => equation_scores,
        "overall_score" => overall_score,
        "comparison_details" => comparison_results
    )
end
```

---

## Summary & Recommendations

**For your ODE benchmark system, use this hierarchy:**

1. **First**: Normalize operators and variable names
2. **Then**: Try numerical equivalence (fastest, most robust)
   - R² > 0.999 → Accept as equivalent
   - R² > 0.95 → Flag for manual review
3. **If needed**: Apply symbolic comparison for exact verification
4. **Finally**: Compute structural similarity for partial credit

**Success Criteria:**
- **Perfect (1.0)**: R² > 0.999 and MSE < 1e-6
- **Excellent (0.95)**: R² > 0.99 and MSE < 1e-4
- **Good (0.85)**: R² > 0.95
- **Partial (0.5-0.8)**: Based on structural similarity

This gives you both rigor (symbolic/numerical) and robustness (handles approximations).
