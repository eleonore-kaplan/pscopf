using Test
using Dates: Date, DateTime;
using DataStructures
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

#TODO : redirect logs
@testset verbose=true "PSCOPF_TESTS" begin
    include("test_wip/test_modes.jl")
    include("test_wip/test_target_ts.jl")
    include("test_wip/test_network.jl")
    include("test_wip/test_ech_generator.jl")
    include("test_wip/test_uncertainties_generator.jl")
    include("test_wip/test_schedule.jl")
    include("test_wip/test_tso_actions.jl")

    include("test_wip/test_coherence_checks/test_check_ptdf.jl")
    include("test_wip/test_coherence_checks/test_check_generator.jl")
    include("test_wip/test_coherence_checks/test_check_branch.jl")
    include("test_wip/test_coherence_checks/test_check_uncertainties.jl")
    include("test_wip/test_coherence_checks/test_check_initial_state.jl")
    include("test_wip/test_coherence_checks/test_check_timesteps.jl")

    include("test_wip/test_verify_firmness.jl")
    include("test_wip/test_verify_firmness_on_schedule.jl")
    include("test_wip/test_compute_firmness.jl")
    include("test_wip/test_init_firmness.jl")
    include("test_wip/test_custom_sequence.jl")
    include("test_wip/test_firmness_in_sequence.jl")
    include("test_wip/test_seq_generator.jl")

    include("test_wip/test_models/energy_market/test_constraints.jl")
    include("test_wip/test_models/energy_market/test_unit_priority.jl")
    include("test_wip/test_models/energy_market/test_start_cost.jl")
    include("test_wip/test_models/energy_market/test_dmo.jl")
    include("test_wip/test_models/energy_market/test_dp.jl")
    include("test_wip/test_models/energy_market/test_energy_market_at_fo.jl")

    # include("test_wip/test_seq_launch.jl")
    include("test_wip/example_usecase.jl")
    include("test_wip/example_usecase_from_folder.jl")

end
