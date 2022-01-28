using PSCOPF

using Test
using Dates

@testset "test_uncertainties_generation" begin
    @testset "one_mode" begin
        uncertainties_distribution = nothing #= FIXME =#
        nb_scenarios = nothing#= FIXME =#

        grid = PSCOPF.Grid()
        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_1
        horizon_timepoints = PSCOPF.generate_ech(grid, TS, mode)

        uncertainties = PSCOPF.generate_uncertainties(grid, TS, horizon_timepoints,
                                                    uncertainties_distribution, nb_scenarios)

        # Tests
        #FIXME : this is just the idea not necessarily in this order
        # EXPECTED_NODAL_INJECTION_NAMES #=FIXME=#
        # EXPECTED_SCENARIOS #=FIXME=#
        # @test keys(uncertainties) == horizon_timepoints
        # for (ech, _) in uncertainties
        #     @test keys(uncertainties[ech]) == EXPECTED_NODAL_INJECTION_NAMES
        #     for (nodal_injection_name, _) in uncertainties[ech]
        #         @test keys(uncertainties[ech][nodal_injection_name]) == TS
        #         for ts in uncertainties[ech][nodal_injection_name]
        #             @test length(uncertainties[ech][nodal_injection_name][ts]) == NB_SCENARIOS
        #             @test keys(uncertainties[ech][nodal_injection_name][ts]) == EXPECTED_SCENARIOS
        #             for (scenario, value_l) in uncertainties[ech][nodal_injection_name][ts]
        #                 @test value_l >= 0
        #             end
        #         end
        #     end
        # end
    end

    @testset "multiple_modes" begin
        uncertainties_distribution = nothing #= FIXME =#
        nb_scenarios = nothing #= FIXME =#

        grid = PSCOPF.Grid()
        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_1
        ECHs = []
        for mode in [PSCOPF.PSCOPF_MODE_1, PSCOPF.PSCOPF_MODE_2, PSCOPF.PSCOPF_MODE_3]
            push!(ECHs, PSCOPF.generate_ech(grid, TS, mode) )
        end
        horizon_timepoints = sort(unique(Iterators.flatten(ECHs)))

        uncertainties = PSCOPF.generate_uncertainties(grid, TS, horizon_timepoints,
                                                    uncertainties_distribution, nb_scenarios)

        # Tests
        #FIXME : this is just the idea not necessarily in this order
        # EXPECTED_NODAL_INJECTION_NAMES #=FIXME=#
        # EXPECTED_SCENARIOS #=FIXME=#
        # @test keys(uncertainties) == horizon_timepoints
        # for (ech, _) in uncertainties
        #     @test keys(uncertainties[ech]) == EXPECTED_NODAL_INJECTION_NAMES
        #     for (nodal_injection_name, _) in uncertainties[ech]
        #         @test keys(uncertainties[ech][nodal_injection_name]) == TS
        #         for ts in uncertainties[ech][nodal_injection_name]
        #             @test length(uncertainties[ech][nodal_injection_name][ts]) == NB_SCENARIOS
        #             @test keys(uncertainties[ech][nodal_injection_name][ts]) == EXPECTED_SCENARIOS
        #             for (scenario, value_l) in uncertainties[ech][nodal_injection_name][ts]
        #                 @test value_l >= 0
        #             end
        #         end
        #     end
        # end
    end
end
