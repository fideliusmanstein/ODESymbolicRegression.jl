#!/usr/bin/env julia

"""
Test the automatic analysis generation in benchmark.jl

This script tests the new analysis features by running a minimal benchmark.
"""

# Override the test configuration to run only 1 problem
ENV["MAX_PROBLEMS_TO_TEST"] = "1"

# Run the benchmark
include("../benchmark/benchmark.jl")
