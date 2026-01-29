# Parameter Estimation Problems

Parameter estimation problems (`pe_*`) use the same system structures as their corresponding base problems but focus on parameter fitting rather than structure discovery.

## Structure

Parameter estimation problems are defined by:
1. **Known structure**: The ODE structure (which variables interact) is given
2. **Unknown parameters**: Only parameter values need to be estimated
3. **Same data**: Uses the same data generation as base problems

## Available Problems

### From Chemical Rate Equations
- `pe_feedf1`, `pe_feedf2` - Uses feedf structure
- `pe_inhosc1`, `pe_inhosc2` - Uses inhosc structure  
- `pe_bifeedb1`, `pe_bifeedb2` - Uses bifeedb structure

### From Gene Networks
- `pe_3genes1`, `pe_3genes2`, `pe_3genes2f`, `pe_3genes3`, `pe_3genes3f` - Uses 3genes structure
- `pe_4genes1` - 4-gene network
- `pe_5genes1` - 5-gene network
- `pe_6genes1` - 6-gene network

### From S-Systems
- `pe_ss_cascade1` - Uses ss_cascade structure
- `pe_ss_branch4` - Uses ss_branch structure
- `pe_ss_30genes2`, `pe_ss_30genes2f` - Uses ss_30genes structure
- `pe_ss_feedf1`, `pe_ss_feedf2` - Uses ss_feedf structure
- `pe_ss_inhosc1`, `pe_ss_inhosc2` - Uses ss_inhosc structure
- `pe_ss_bifeedb1`, `pe_ss_bifeedb2` - Uses ss_bifeedb structure

### From GMA Models
- `pe_gma_feedf1`, `pe_gma_feedf2` - Uses gma_feedf structure
- `pe_gma_inhosc1`, `pe_gma_inhosc2` - Uses gma_inhosc structure
- `pe_gma_bifeedb1`, `pe_gma_bifeedb2` - Uses gma_bifeedb structure

### Other
- `pe_pinene` - Alpha-pinene pyrolysis model

## Implementation Note

Since parameter estimation problems share structures with their base problems, they can be generated using the same system functions. The key difference is in how they are used:

**Structure Discovery (base problems)**:
```julia
# Unknown: Which variables interact, parameter values
# Given: Time-series data
# Task: Discover both structure and parameters
```

**Parameter Estimation (pe_ problems)**:
```julia
# Unknown: Only parameter values
# Given: Time-series data + ODE structure
# Task: Fit parameters to known structure
```

For implementation, use the corresponding base problem's data generation function. For example:
- `pe_feedf1` → use `generate_feedf_data()` from `feedf.jl`
- `pe_ss_cascade1` → use `generate_ss_cascade_data()` from `ss_cascade.jl`

The structure information (which terms appear in which equations) would typically be provided separately in a parameter estimation framework.
