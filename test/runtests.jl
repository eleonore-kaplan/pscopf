using Test

using PSCOPF

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

    include("test_wip/test_starts.jl")
    include("test_wip/test_flows.jl")
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
    include("test_wip/test_models/energy_market/test_slacks.jl")
    include("test_wip/test_models/energy_market/test_energy_market_at_fo.jl")

    include("test_wip/test_models/tso_out_fo/test_dp_imposable.jl")
    include("test_wip/test_models/tso_out_fo/test_dp_limitable.jl")
    include("test_wip/test_models/tso_out_fo/test_dmo.jl")
    include("test_wip/test_models/tso_out_fo/test_constraints.jl")
    include("test_wip/test_models/tso_out_fo/test_slacks.jl")
    include("test_wip/test_models/tso_out_fo/test_start_cost.jl")
    include("test_wip/test_models/tso_out_fo/test_unit_priority.jl")
    include("test_wip/test_models/tso_out_fo/test_limitation.jl")

    # include("test_wip/test_seq_launch.jl")
    include("test_wip/example_usecase.jl")
    include("test_wip/example_usecase_from_folder.jl")

end