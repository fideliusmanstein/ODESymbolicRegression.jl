"""
TreeBuilder.jl

Utilities for building expression trees that represent ODE equations.
Provides a convenient API for constructing trees from mathematical expressions.
"""

module TreeBuilderModule

using SymbolicRegression: Node

export build_tree, var, const_val, @tree_expr

"""
    var(index::Int)

Create a variable node in an expression tree.

# Example
```julia
x1 = var(1)  # Represents x₁
```
"""
function var(index::Int)
    return Node(; feature=index)
end

"""
    const_val(value::Float64)

Create a constant node in an expression tree.

# Example
```julia
c = const_val(2.5)  # Represents the constant 2.5
```
"""
function const_val(value::Float64)
    return Node(Float64; val=value)
end

"""
Helper functions to build common binary operations.
"""
function Base.:+(left::Node, right::Node)
    return Node(+, left, right)
end

function Base.:-(left::Node, right::Node)
    return Node(-, left, right)
end

function Base.:*(left::Node, right::Node)
    return Node(*, left, right)
end

function Base.:/(left::Node, right::Node)
    return Node(/, left, right)
end

function Base.:^(left::Node, right::Node)
    return Node(^, left, right)
end

# Allow mixing with numbers
Base.:+(left::Node, right::Real) = left + const_val(Float64(right))
Base.:+(left::Real, right::Node) = const_val(Float64(left)) + right
Base.:-(left::Node, right::Real) = left - const_val(Float64(right))
Base.:-(left::Real, right::Node) = const_val(Float64(left)) - right
Base.:*(left::Node, right::Real) = left * const_val(Float64(right))
Base.:*(left::Real, right::Node) = const_val(Float64(left)) * right
Base.:/(left::Node, right::Real) = left / const_val(Float64(right))
Base.:/(left::Real, right::Node) = const_val(Float64(left)) / right
Base.:^(left::Node, right::Real) = left ^ const_val(Float64(right))
Base.:^(left::Real, right::Node) = const_val(Float64(left)) ^ right

# Unary minus
Base.:-(node::Node) = const_val(0.0) - node

"""
Helper functions to build common unary operations.
"""
function square(node::Node)
    return Node(^, node, const_val(2.0))
end

function cube(node::Node)
    return Node(^, node, const_val(3.0))
end

function sqrt_op(node::Node)
    return Node(sqrt, node)
end

function exp_op(node::Node)
    return Node(exp, node)
end

function log_op(node::Node)
    return Node(log, node)
end

function sin_op(node::Node)
    return Node(sin, node)
end

function cos_op(node::Node)
    return Node(cos, node)
end

"""
    michaelis_menten(substrate::Node, vmax::Real, km::Real)

Build a Michaelis-Menten kinetics expression tree.
Returns: vmax * substrate / (substrate + km)

# Example
```julia
x1 = var(1)
v = michaelis_menten(x1, 1.0, 0.5)  # 1.0 * x1 / (x1 + 0.5)
```
"""
function michaelis_menten(substrate::Node, vmax::Real, km::Real)
    v = const_val(Float64(vmax))
    k = const_val(Float64(km))
    return v * substrate / (substrate + k)
end

"""
    hill_minus(x::Node, k::Real)

Build a Hill inhibition function (h⁻).
Returns: k / (x + k)

# Example
```julia
x3 = var(3)
h = hill_minus(x3, 0.9)  # 0.9 / (x3 + 0.9)
```
"""
function hill_minus(x::Node, k::Real)
    kval = const_val(Float64(k))
    return kval / (x + kval)
end

"""
    hill_plus(x::Node, k::Real)

Build a Hill activation function (h⁺).
Returns: x / (x + k)

# Example
```julia
x1 = var(1)
h = hill_plus(x1, 0.5)  # x1 / (x1 + 0.5)
```
"""
function hill_plus(x::Node, k::Real)
    kval = const_val(Float64(k))
    return x / (x + kval)
end

"""
    hill_power(x::Node, k::Real, n::Real)

Build a cooperative Hill function.
Returns: x^n / (x^n + k^n)

# Example
```julia
x1 = var(1)
h = hill_power(x1, 1.0, 2)  # x1^2 / (x1^2 + 1.0)
```
"""
function hill_power(x::Node, k::Real, n::Real)
    kval = const_val(Float64(k))
    nval = const_val(Float64(n))
    xn = Node(^, x, nval)
    kn = Node(^, kval, nval)
    return xn / (xn + kn)
end

"""
    Example usage and tests
"""
function test_tree_builder()
    println("Testing TreeBuilder...")
    
    # Test 1: Simple linear combination
    # dx1/dt = -k1*x1 + k2*x2
    x1 = var(1)
    x2 = var(2)
    eq1 = -1.0 * x1 + 1.0 * x2
    println("Test 1: ", eq1)
    
    # Test 2: Michaelis-Menten
    # v = 1.0 * x1 / (x1 + 0.5)
    eq2 = michaelis_menten(x1, 1.0, 0.5)
    println("Test 2: ", eq2)
    
    # Test 3: Hill function
    # h = 0.9 / (x3 + 0.9)
    x3 = var(3)
    eq3 = hill_minus(x3, 0.9)
    println("Test 3: ", eq3)
    
    # Test 4: Complex expression
    # dx1/dt = 0.9 * (0.9/(x3+0.9)) - 1.0*x1
    k1 = 0.9
    k2 = 0.9
    k3 = 1.0
    eq4 = k1 * hill_minus(x3, k2) - k3 * x1
    println("Test 4: ", eq4)
    
    println("TreeBuilder tests complete!")
end

end # module
