using ODESymbolicRegression
using Test

@testset "ODESymbolicRegression.jl" begin
    # Basic functionality tests
    @testset "Module Loading" begin
        @test isdefined(ODESymbolicRegression, :discover_ode_system)
        @test isdefined(ODESymbolicRegression, :ODERegressionOptions)
    end
    
    # Add more tests from the tests/ directory as needed
    # include("tests/test_multi_trajectory.jl")
end
