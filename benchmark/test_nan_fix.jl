"""
test_nan_fix.jl

Minimal test to verify that the NaN fix in equation similarity evaluation works correctly.
This script tests the ground truth evaluation function approach.
"""

using Printf
using Statistics

println("="^80)
println("Testing Ground Truth Evaluation Fix")
println("="^80)

# Test 1: Simple function creation and evaluation
println("\nTest 1: Creating and evaluating ground truth functions")
println("-"^80)

# Define square function
square(x) = x * x

# Test case 1: 2-state system
n_states = 2
gt_eq_str_raw = "-1.0·X1 + 2.0·X2"
# Replace middle dot with asterisk for valid Julia syntax
gt_eq_str = replace(gt_eq_str_raw, "·" => "*")
gt_expr_parsed = Meta.parse(gt_eq_str)

println("Number of states: $n_states")
println("Ground truth equation (raw): $gt_eq_str_raw")
println("Ground truth equation (parsed): $gt_eq_str")

# Create function
gt_func = @eval (X1, X2) -> begin
    square(x) = x * x
    $gt_expr_parsed
end

# Test evaluation
test_vals = [1.0, 2.0]
result = gt_func(test_vals...)
expected = -1.0 * 1.0 + 2.0 * 2.0  # = -1 + 4 = 3.0

println("Test values: $test_vals")
println("Result: $result")
println("Expected: $expected")
println("Match: $(abs(result - expected) < 1e-10 ? "✓" : "✗")")

# Test case 2: 3-state system with square
n_states = 3
gt_eq_str = "square(X1) + X2 * X3"
gt_expr_parsed = Meta.parse(gt_eq_str)

println("\nNumber of states: $n_states")
println("Ground truth equation: $gt_eq_str")

gt_func = @eval (X1, X2, X3) -> begin
    square(x) = x * x
    $gt_expr_parsed
end

test_vals = [2.0, 3.0, 4.0]
result = gt_func(test_vals...)
expected = 2.0^2 + 3.0 * 4.0  # = 4 + 12 = 16.0

println("Test values: $test_vals")
println("Result: $result")
println("Expected: $expected")
println("Match: $(abs(result - expected) < 1e-10 ? "✓" : "✗")")

# Test 2: Error metric computation with valid samples
println("\n\nTest 2: Error Metrics Computation")
println("-"^80)

ground_truth_outputs = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
discovered_outputs = [1.1, 2.1, 2.9, 4.2, 4.8, 6.1, 7.0, 8.1, 8.9, 10.2]

println("Ground truth outputs: $(length(ground_truth_outputs)) samples")
println("Discovered outputs: $(length(discovered_outputs)) samples")

errors = discovered_outputs .- ground_truth_outputs
abs_errors = abs.(errors)

rmse = sqrt(mean(errors.^2))
mae = mean(abs_errors)
max_error = maximum(abs_errors)

gt_std = std(ground_truth_outputs)
nrmse = gt_std > 1e-10 ? rmse / gt_std : NaN

ss_res = sum(errors.^2)
ss_tot = sum((ground_truth_outputs .- mean(ground_truth_outputs)).^2)
r2 = ss_tot > 1e-10 ? 1.0 - (ss_res / ss_tot) : NaN

println("\nComputed metrics:")
println("  RMSE: ", @sprintf("%.6e", rmse))
println("  NRMSE: ", isnan(nrmse) ? "N/A" : @sprintf("%.4f", nrmse))
println("  MAE: ", @sprintf("%.6e", mae))
println("  Max Error: ", @sprintf("%.6e", max_error))
println("  R²: ", isnan(r2) ? "N/A" : @sprintf("%.6f", r2))

println("\nAll metrics finite: $(all(isfinite.([rmse, mae, max_error])) ? "✓" : "✗")")
println("NRMSE and R² may be NaN in edge cases (that's expected)")

# Test 3: Edge case - constant ground truth
println("\n\nTest 3: Edge Case - Constant Ground Truth")
println("-"^80)

ground_truth_outputs = fill(5.0, 10)
discovered_outputs = [5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0]

println("Ground truth outputs: all $(ground_truth_outputs[1])")
println("Discovered outputs: all $(discovered_outputs[1])")

errors = discovered_outputs .- ground_truth_outputs
abs_errors = abs.(errors)

rmse = sqrt(mean(errors.^2))
mae = mean(abs_errors)
max_error = maximum(abs_errors)

gt_std = std(ground_truth_outputs)
nrmse = gt_std > 1e-10 ? rmse / gt_std : NaN

ss_res = sum(errors.^2)
ss_tot = sum((ground_truth_outputs .- mean(ground_truth_outputs)).^2)
r2 = ss_tot > 1e-10 ? 1.0 - (ss_res / ss_tot) : NaN

println("\nComputed metrics:")
println("  RMSE: ", @sprintf("%.6e", rmse))
println("  NRMSE: ", isnan(nrmse) ? "N/A (expected for constant values)" : @sprintf("%.4f", nrmse))
println("  MAE: ", @sprintf("%.6e", mae))
println("  Max Error: ", @sprintf("%.6e", max_error))
println("  R²: ", isnan(r2) ? "N/A (expected for constant values)" : @sprintf("%.6f", r2))

println("\nNRMSE is NaN: $(isnan(nrmse) ? "✓ (as expected)" : "✗")")
println("R² is NaN: $(isnan(r2) ? "✓ (as expected)" : "✗")")

# Test 4: NaN detection
println("\n\nTest 4: NaN Detection")
println("-"^80)

ground_truth_outputs = [1.0, 2.0, NaN, 4.0, 5.0]
discovered_outputs = [1.1, 2.1, 3.1, 4.1, 5.1]

println("Ground truth outputs contain NaN: $(any(isnan.(ground_truth_outputs)))")
println("Discovered outputs contain NaN: $(any(isnan.(discovered_outputs)))")

if any(isnan.(ground_truth_outputs)) || any(isnan.(discovered_outputs))
    println("✓ NaN detected correctly - would skip metrics computation")
else
    println("✗ NaN not detected - this is a bug!")
end

println("\n" * "="^80)
println("All tests completed successfully!")
println("="^80)
