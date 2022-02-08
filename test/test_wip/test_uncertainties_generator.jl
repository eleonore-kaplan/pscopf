using PSCOPF

using Test
using Dates

@testset "test_uncertainties_generation" begin
    @testset "empty_test" begin
        uncertainties_distribution = Dict()
        nb_scenarios = 2

        grid = PSCOPF.Networks.Network()
        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_1
        horizon_timepoints = PSCOPF.generate_ech(grid, TS, mode)

        uncertainties = PSCOPF.generate_uncertainties(grid, TS, horizon_timepoints,
                                                    uncertainties_distribution, nb_scenarios)

        @test length(uncertainties) == 0
    end

    @testset "read_uncertain_distributions" begin
        data_path = joinpath(@__DIR__, "..", "..", "2buses")
        network = PSCOPF.Data.pscopfdata2network(data_path)
        uncertainties_distribution = PSCOPF.PSCOPFio.read_uncertainties_distributions(network, data_path)

        #FIXME : for now, the same mean value (mu) is used for all timepoints ts
        @test length(uncertainties_distribution) == 4
        # println("distro :\n\n", uncertainties_distribution)
    end

    @testset "one_mode" begin
        data_path = joinpath(@__DIR__, "..", "..", "2buses")
        network = PSCOPF.Data.pscopfdata2network(data_path)
        uncertainties_distribution = PSCOPF.PSCOPFio.read_uncertainties_distributions(network, data_path)
        nb_scenarios = 5#= FIXME =#

        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_1
        horizon_timepoints = PSCOPF.generate_ech(network, TS, mode)

        uncertainties = PSCOPF.generate_uncertainties(network, TS, horizon_timepoints,
                                                    uncertainties_distribution, nb_scenarios)

        # Tests
        EXPECTED_NODAL_INJECTION_NAMES = ["poste_1_0", "poste_2_0", "wind_1", "wind_2"]
        EXPECTED_SCENARIOS = ["S1", "S2", "S3", "S4", "S5"]
        @test collect(keys(uncertainties)) == horizon_timepoints
        for (ech, _) in uncertainties
            @test collect(keys(uncertainties[ech])) == EXPECTED_NODAL_INJECTION_NAMES
            for (nodal_injection_name, _) in uncertainties[ech]
                @test collect(keys(uncertainties[ech][nodal_injection_name])) == TS
                for (ts, _) in uncertainties[ech][nodal_injection_name]
                    @test length(uncertainties[ech][nodal_injection_name][ts]) == nb_scenarios
                    @test collect(keys(uncertainties[ech][nodal_injection_name][ts])) == EXPECTED_SCENARIOS
                    for (scenario, value_l) in uncertainties[ech][nodal_injection_name][ts]
                        @test value_l >= 0
                    end
                end
            end
        end
    end

    @testset "multiple_modes" begin
        data_path = joinpath(@__DIR__, "..", "..", "2buses")
        network = PSCOPF.Data.pscopfdata2network(data_path)
        uncertainties_distribution = PSCOPF.PSCOPFio.read_uncertainties_distributions(network, data_path)
        nb_scenarios = 5#= FIXME =#

        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        ECHs = []
        for mode in [PSCOPF.PSCOPF_MODE_1, PSCOPF.PSCOPF_MODE_2, PSCOPF.PSCOPF_MODE_3]
            push!(ECHs, PSCOPF.generate_ech(network, TS, mode) )
        end
        horizon_timepoints = sort(unique(Iterators.flatten(ECHs)))

        uncertainties = PSCOPF.generate_uncertainties(network, TS, horizon_timepoints,
                                                    uncertainties_distribution, nb_scenarios)

        # Tests
        EXPECTED_NODAL_INJECTION_NAMES = ["poste_1_0", "poste_2_0", "wind_1", "wind_2"]
        EXPECTED_SCENARIOS = ["S1", "S2", "S3", "S4", "S5"]
        @test collect(keys(uncertainties)) == horizon_timepoints
        for (ech, _) in uncertainties
            @test collect(keys(uncertainties[ech])) == EXPECTED_NODAL_INJECTION_NAMES
            for (nodal_injection_name, _) in uncertainties[ech]
                @test collect(keys(uncertainties[ech][nodal_injection_name])) == TS
                for (ts, _) in uncertainties[ech][nodal_injection_name]
                    @test length(uncertainties[ech][nodal_injection_name][ts]) == nb_scenarios
                    @test collect(keys(uncertainties[ech][nodal_injection_name][ts])) == EXPECTED_SCENARIOS
                    for (scenario, value_l) in uncertainties[ech][nodal_injection_name][ts]
                        @test value_l >= 0
                    end
                end
            end
        end
    end
end
