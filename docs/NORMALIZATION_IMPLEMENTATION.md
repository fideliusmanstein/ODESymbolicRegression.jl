# Equation Normalization Implementation

## Summary

Implemented automatic equation normalization for all printed and saved equations in the ODE discovery system.

## Changes Made

### 1. Added Dependencies
- **SymbolicUtils.jl**: For symbolic simplification  
- **Symbolics.jl**: For symbolic variable handling

### 2. Core Functions

#### `normalize_equation()` in benchmark_ode_discovery.jl
Normalizes equations with:
1. **Canonical variable names**: Uses x1, x2, x3, etc. (already handled by `string_tree`)
2. **Symbolic simplification**: Expands and simplifies expressions using SymbolicUtils
3. **Constant rounding**: Rounds all numeric constants to 2 decimal places

#### `normalize_equation_internal()` in SymbolicRegressionODE.jl
Same functionality for internal use within the ODE discovery module.

### 3. Application Points

Normalization is applied whenever equations are converted to strings:

**In benchmark_ode_discovery.jl:**
- Line ~270: Discovered equations (final results)
- Line ~275: Initial equations (before refinement)

**In SymbolicRegressionODE.jl:**
- Line ~571: Initial equations printout (before refinement)
- Line ~665: Final equations printout (best system)

**In benchmark_reporting.jl:**
- Equations are already normalized when passed to reporting functions

## Examples

### Before Normalization:
```
X1' = 1.0042765338065114*x1 + 0.9987654321*x2
X2' = (1.0 / (x3 + 0.1)) - square(x1)
```

### After Normalization:
```
X1' = 1*x1 + 1*x2  
X2' = (1 / (x3 + 0.1)) - square(x1)
```

## Benefits

1. **Cleaner output**: Removes numerical noise from constants
2. **Easier comparison**: Standardized format makes equations more comparable
3. **Better readability**: Canonical variable names and simplified expressions
4. **Automatic**: No manual intervention needed

## Testing

Run `test_normalization.jl` to verify:
```bash
julia --project=.. master_thesis/test_normalization.jl
```

Tests cover:
- Constant rounding (1.0042765... → 1)
- Variable naming (canonical x1, x2, x3...)
- Expression simplification
- Complex fractions and nested operations

## Technical Notes

- **Symbolic simplification**: Uses SymbolicUtils.simplify() → expand() → simplify() pipeline
- **Error handling**: Falls back to original string if symbolic processing fails
- **Custom operators**: The `square()` function is defined for symbolic evaluation
- **Performance**: Minimal overhead, simplification runs only during output formatting

## Configuration

Currently hardcoded to 2 decimal places. To change:

```julia
# In benchmark_ode_discovery.jl, line ~89:
eq_str = round_equation_constants(eq_str, digits=3)  # Change to 3 decimals
```

## Future Improvements

1. Make rounding precision configurable via ODERegressionOptions
2. Add option to disable symbolic simplification
3. Implement full factorization (e.g., x1*2 + x1*3 → 5*x1)
4. Convert square(x) to x^2 notation for consistency with ground truth
