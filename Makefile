benchmark:
	sbatch run.sh

test:
	julia --project=. test/runtests.jl
	julia test/test_noise_parameter.jl
	julia test/test_trajectory_counts.jl
	julia test/tests/test_multi_trajectory.jl
	julia test/tests/test_iterative_refinement.jl
	julia test/tests/test_multi_ic_robustness.jl

.PHONY: benchmark test
