using Test
using Dates: Date, DateTime;
import Logging

root_path = dirname(@__DIR__);
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "test", "TestHelpers.jl"));
include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "Workflow.jl"));

Logging.with_logger(Logging.NullLogger()) do
    @testset verbose=true "PSCOPF_TESTS" begin
        include("test_dmo_levers.jl")
        include("test_feasibility_slacks.jl")
    end
end
