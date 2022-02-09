using PSCOPF

using Test
using Dates

@testset verbose=true "test_ech_generator" begin

    @testset "mode_1" begin
        grid = PSCOPF.Networks.Network()
        ts1 = DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_1

        list_ech = PSCOPF.generate_ech(grid, TS, mode)

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
        grid = PSCOPF.Networks.Network()
        #unsorted TS
        TS = [DateTime("2015-01-01T11:30:00"), DateTime("2015-01-01T11:45:00"), DateTime("2015-01-01T11:00:00"), DateTime("2015-01-01T11:15:00")]
        mode = PSCOPF.PSCOPF_MODE_1

        list_ech = PSCOPF.generate_ech(grid, TS, mode)

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
        grid = PSCOPF.Networks.Network()
        ts1 = DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_2

        list_ech = PSCOPF.generate_ech(grid, TS, mode)

        EXPECTED_ECH = [ts1 - Dates.Hour(4),
                        ts1 - Dates.Hour(1),
                        ts1 - Dates.Minute(30),
                        ts1 - Dates.Minute(15),
                        ts1]
        @test length(list_ech) == length(EXPECTED_ECH)
        @test list_ech == EXPECTED_ECH
    end

    @testset "mode_3" begin
        grid = PSCOPF.Networks.Network()
        ts1 = DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_3

        list_ech = PSCOPF.generate_ech(grid, TS, mode)

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

# GENERATION
@testset "mode_1" begin
    #generateur de réseau
    grid = create_grid(#=FIXME initial input or mocks=#)

    #lecture TS
    ts1 #=FIXME initial input or mocks=#
    TS = create_TS(Dates.DateTime(ts1)) #ts1 .+ [Dates.Minute(0), Dates.Minute(15), Dates.Minute(30), Dates.Minute(45)]
    mode = PSCOPF_MODE_1

    #generateur d"ech
    ECH = generate_ech(grid, TS, mode)


    EXPECTED_SEQUENCES = Dict(
        "h-4" => [MarketMode1OutFO, TSOMode1],
        "h-2" => [MarketMode1OutFO, TSOMode1],
        "echFO_h-1" => [MarketMode1OutFO, EnterFO, TSOMode1InFO],
        "m-30" => [MarketMode1InFO, TSOMode1InFO],
        "m-15" => [MarketMode1InFO, TSOMode1InFO],
        "m-0" => [Assessment]
    )

    @test length(SEQUENCES) == length(EXPECTED_SEQUENCES) == length(ECH)
    for ech in ECH
        @test length(SEQUENCES[ech]) == length(EXPECTED_SEQUENCES[ech])
        for (operation, expected_operation) in zip(SEQUENCES[ech], EXPECTED_SEQUENCES[ech])
            @test isa(operation, expected_operation)
            # to check, for example, that we have the following [instance of Mode1MarketClass, instance of Mode1TSOClass]
        end
    end
end


# LANCEMENT
@testset "mode_1" begin
    grid = create_grid(#=FIXME initial input or mocks=#)
    ts1 #=FIXME initial input or mocks=#
    TS = create_TS(Dates.DateTime(ts1)) #ts1 .+ [Dates.Minute(0), Dates.Minute(15), Dates.Minute(30), Dates.Minute(45)]
    mode = PSCOPF_MODE_1
    ECH = generate_ech(grid, TS, mode)

    # FIXME : MAYBE it is better if the sequencer (i.e. generate_sequences) works with a Session that contains the grid, TS, ECH,...
    #and the launcher creates a context to
    #   - maintains the current ech, current schedule, ..
    #   - saves the schedule history,...
    sequence #FIXME generate_sequences(grid, TS, ECH, mode)
    session  #FIXME Session(grid,TS,ECH)
    initial_situation #FIXME
    uncertainties #FIXME generate_uncertainties(grid, TS, ECH, uncertainties_distribution, NB_SCENARIOSN)
    assessment_uncertainties

    launch(sequence, session, initial_situation, uncertainties, assessment_uncertainties)

    #FIXME : TESTS
end





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
