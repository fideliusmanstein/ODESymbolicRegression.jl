# Trajectory Count Test Results

## Summary
- **Total Tests**: 505 (63 problems × 8 tests each + 1 overall)
- **Passed**: 424  
- **Failed**: 81
- **Success Rate**: 83.96%

## Problem Categories

### ✅ Fully Passing (44 problems)
Problems that correctly generate all requested trajectory counts (1, 2, 3, 5):
- osc1, osc2
- simpleLin1, simpleLin2, simpleFb1, simpleFb2, simpleFb3, simpleFb4
- metabol1, metabol2, metabol3
- threeGenes1, threeGenes2
- bifeedb1, bifeedb2
- feedf1, feedf2
- ss_cascade1, ss_cascade3
- ss_5genes1, ss_5genes2, ss_5genes3, ss_5genes4, ss_5genes5, ss_5genes7, ss_5genes8
- ss_15genes1, ss_15genes2
- ss_30genes1, ss_30genes2, ss_30genes3
- ss_feedf1, ss_feedf2
- ss_bifeedb1, ss_bifeedb2
- ss_branch2, ss_branch3, ss_branch6
- gma_bifeedb1, gma_bifeedb2
- gma_feedf1, gma_feedf2

### ⚠️ Partially Failing (19 problems)

#### High Severity - Only 1 trajectory generated regardless of request:
- **ss_clock1** - generates 1 instead of [2,3,5] (6 failures)
- **ss_clock2** - generates 1 instead of [2,3,5] (6 failures)  
- **ss_5genes6** - generates 1 instead of [2,3,5] (6 failures)
- **ss_cadBA1** - generates 1 instead of [2,3,5] (6 failures)
- **ss_cadBA2** - generates 1 instead of [2,3,5] (6 failures)
- **ss_sosrepair1** - generates 1 instead of [2,3,5] (6 failures)
- **ss_sosrepair2** - generates 1 instead of [2,3,5] (6 failures)
- **cytokine1** - generates 1 instead of [2,3,5] (6 failures)
- **cytokine2** - generates 1 instead of [2,3,5] (6 failures)

#### Medium Severity - Caps at max available experimental trajectories:
- **ss_cascade2** - generates 4 instead of 5 (2 failures)
- **ss_branch4** - generates 4 instead of 5 (2 failures)
- **ss_branch5** - generates 4 instead of 5 (2 failures)
- **gma_inhosc1** - generates 4 instead of 5 (2 failures)
- **gma_inhosc2** - generates 4 instead of 5 (2 failures)
- **inhosc1** - generates 4 instead of 5 (2 failures)
- **inhosc2** - generates 4 instead of 5 (2 failures)
- **ss_inhosc1** - generates 4 instead of 5 (2 failures)
- **ss_inhosc2** - generates 4 instead of 5 (2 failures)

#### Medium Severity - Caps at 2 trajectories:
- **ss_ethanolferm1** - generates 2 instead of [3,5] (2 failures)
- **ss_ethanolferm2** - generates 2 instead of [3,5] (4 failures)

#### Low Severity - Minor cap:
- **ss_branch1** - generates 3 instead of 5 (2 failures)

## Root Cause Analysis

### Issue 1: No generation function available
Problems like **ss_clock1**, **ss_cadBA1**, **cytokine1**, etc. likely don't have synthetic data generation functions defined in the benchmark system modules. The fix attempts to call functions like `generate_ss_clock_data()` or `generate_cytokine_data()`, but these don't exist.

### Issue 2: Limited experimental data  
Problems ending in "inhosc" have exactly 4 experimental trajectories available and cannot expand to 5 without generation functions.

### Issue 3: Missing data generation
Problems like **ss_ethanolferm2** may have limited experimental data (2 trajectories) without a corresponding generation function.

## Recommendations

1. **For problems with only 1 trajectory**: Check if these are real biological data without synthetic generation capability. May need to document as "experimental data only, no synthetic generation".

2. **For problems capping at 4**: These have 4 experimental trajectories. Either:
   - Add generation functions for these specific systems
   - Document maximum available as 4

3. **For ss_ethanolferm problems**: Similar to above - add generation or document limits.

4. **Update load_problem() logic**: Add fallback behavior when generation function doesn't exist:
   - Return available experimental data
   - Issue warning about trajectory count mismatch
   - Don't error silently

## Next Steps

1. Audit which problems have generation functions vs. experimental-only data
2. For experimental-only: document maximum available trajectories  
3. For missing generation functions: either implement them or mark as unsupported
4. Update `load_problem()` to handle missing generation functions gracefully
