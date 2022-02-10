using PSCOPF

using Test
using Dates

@testset verbose=true "test_ech_generator" begin

    @testset "mode_1" begin
        network = PSCOPF.Networks.Network()
        ts1 = DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_1

        list_ech = PSCOPF.generate_ech(network, TS, mode)

        EXPECTED_ECH = [ts1 - Dates.Hour(4),
                        ts1 - Dates.Hour(1),
                        ts1 - Dates.Minute(30),
                        ts1 - Dates.Minute(15),
                        ts1]
        @test length(list_ech) == length(EXPECTED_ECH)
        @test list_ech == EXPECTED_ECH
    end

    #=
        generate_ech sorts the received TS, and looks at the first target timepoint
    =#
    @testset "mode_1_unsorted_TS" begin
        network = PSCOPF.Networks.Network()
        #unsorted TS
        TS = [DateTime("2015-01-01T11:30:00"), DateTime("2015-01-01T11:45:00"), DateTime("2015-01-01T11:00:00"), DateTime("2015-01-01T11:15:00")]
        mode = PSCOPF.PSCOPF_MODE_1

        list_ech = PSCOPF.generate_ech(network, TS, mode)

        ts1 = DateTime("2015-01-01T11:00:00")
        EXPECTED_ECH = [ts1 - Dates.Hour(4),
                        ts1 - Dates.Hour(1),
                        ts1 - Dates.Minute(30),
                        ts1 - Dates.Minute(15),
                        ts1]
        @test length(list_ech) == length(EXPECTED_ECH)
        @test list_ech == EXPECTED_ECH
    end

    @testset "mode_2" begin
        network = PSCOPF.Networks.Network()
        ts1 = DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_2

        list_ech = PSCOPF.generate_ech(network, TS, mode)

        EXPECTED_ECH = [ts1 - Dates.Hour(4),
                        ts1 - Dates.Hour(1),
                        ts1 - Dates.Minute(30),
                        ts1 - Dates.Minute(15),
                        ts1]
        @test length(list_ech) == length(EXPECTED_ECH)
        @test list_ech == EXPECTED_ECH
    end

    @testset "mode_3" begin
        network = PSCOPF.Networks.Network()
        ts1 = DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_3

        list_ech = PSCOPF.generate_ech(network, TS, mode)

        EXPECTED_ECH = [ts1 - Dates.Hour(4),
                        ts1 - Dates.Hour(1),
                        ts1 - Dates.Minute(30),
                        ts1 - Dates.Minute(15),
                        ts1]
        @test length(list_ech) == length(EXPECTED_ECH)
        @test list_ech == EXPECTED_ECH
    end

end

#=

#TEst
    planningTSO = planningRefTSO
    planningMarket = planningRefMarket

    data = (Grid, ECH, TS, ...)
    planning = (planningTSO, planningMarket)
    OptimResult = run(MarketMode1, planning, data)

    tester les résutlats

#TEst update (démarrage des unités)

    planningTSO = planningRefTSO
    planningMarket = planningRefMarket

    data = (Grid, ECH, TS, ...)
    planning = (planningTSO, planningMarket)

    update_imposition(planning, OptimResult)
    update_limitation(planning, OptimResult)
    update_units(planning, OptimResult)
    update_reserve(planning, OptimResult)

    test sur planning
    #Decision ferme/
    niveau["unit1"][] = 15
    niveau["unit1"] = 15

=#
