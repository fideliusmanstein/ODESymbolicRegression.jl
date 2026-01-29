# ODE Discovery Test Suite

This directory contains tests for the ODE discovery system.

## Files

- `test_benchmark.jl` - Test all 63 benchmark systems with minimal configuration

## Running Tests

From the `master_thesis` directory:

```bash
julia --project=.. tests/test_benchmark.jl
```

Or using include:

```bash
cd master_thesis
julia --project=.. -e 'include("tests/test_benchmark.jl")'
```

**Note:** Must run from `master_thesis` directory with `--project=..` to access the parent project environment.

## Test Configuration

All benchmark tests use minimal settings:
- 3 derivative iterations
- 3 integration iterations  
- Operators: +, -, *, / only (no transcendental functions)
- 3-minute timeout per system
- Complexity limits: 10 (derivative), 10 (integration)

## Expected Output

Each test will show:
- ✓ PASS - System successfully discovered with low integration loss
- ✗ FAIL - Either timeout or discovery failed
- Test summary at the end with pass/fail counts
