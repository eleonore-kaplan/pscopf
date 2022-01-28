using Test
using Dates: Date, DateTime;
import Logging

using PSCOPF

# root_path = dirname(@__DIR__);
# push!(LOAD_PATH, root_path);
# cd(root_path);
# include(joinpath(root_path, "test", "TestHelpers.jl"));
# include(joinpath(root_path, "AmplTxt.jl"));
# include(joinpath(root_path, "Workflow.jl"));

# Logging.with_logger(Logging.NullLogger()) do
#     @testset verbose=true "PSCOPF_TESTS" begin
#         include("test_dmo_levers.jl")
#         include("test_feasibility_slacks.jl")
#         include("test_multiple_ts.jl")
#     end
# end

@testset verbose=true "PSCOPF_TESTS" begin
    include("test_wip/test_network.jl")
    include("test_wip/test_modes.jl")
    include("test_wip/test_target_ts.jl")
    include("test_wip/test_ech_generator.jl")
    include("test_wip/test_seq_generator.jl")
    include("test_wip/test_seq_launch.jl")
    # include("test_wip/test_steps.jl")
    # include("test_wip/test_uncertainties_generator.jl")
end
