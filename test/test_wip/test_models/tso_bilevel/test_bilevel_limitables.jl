using PSCOPF

using .PSCOPFFixtures

using Test
using JuMP
using BilevelJuMP
using Dates
using DataStructures
using Printf

@testset verbose=true "test" begin

    TS = [DateTime("2015-01-01T11:00:00")]
    ech = DateTime("2015-01-01T07:00:00")
    next_ech = DateTime("2015-01-01T07:30:00")
    function create_instance(load_1, load_2,
                            wind_1,
                            limit::Float64=35.,
                            logs=nothing)
        network = PSCOPFFixtures.network_2buses(limit=limit)
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "wind_2_1", PSCOPF.Networks.LIMITABLE,
        #                                         0., 100.,
        #                                         0., 1.,
        #                                         Dates.Second(0), Dates.Second(0))

        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", TS[1], "S1", wind_1)
        # PSCOPF.add_uncertainty!(uncertainties, ech, "wind_2_1", TS[1], "S1", wind_2)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", TS[1], "S1", load_1)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", TS[1], "S1", load_2)

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                    SortedDict{String,PSCOPF.GeneratorState}(), #gen_initial_state
                                    uncertainties, nothing, logs)

        return context
    end

    #=
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 40            |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10            |                      | S1: 30
    =#
    @testset "no_problem" begin
        println("\n\nno_problem")

        context = create_instance(10., 30.,
                                40.,
                                35.,
                                "no_problem")

        tso = PSCOPF.TSOBilevel()
        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

        #TSO RSO constraints are OK
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) <= 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) <= 1e-09

        #Market EOD constraints are OK
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) <= 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) <= 1e-09

        for var in all_variables(result.model)
            println(name(var), " = ", value(var))
        end
    end

    #=
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 100           |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10            |                      | S1: 30
    =#
    @testset "EOD_problem_needs_capping" begin
        println("\n\nEOD_problem_needs_capping")
        context = create_instance(10., 30.,
                                100.,
                                35.,
                                "EOD_problem_needs_capping")

        tso = PSCOPF.TSOBilevel()
        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

        #TSO RSO constraints are OK
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) <= 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) <= 1e-09

        #Market caps ENR for EOD reasons
        @test 60. ≈ value(result.lower.limitable_model.p_capping[TS[1],"S1"])
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) <= 1e-09

        for var in all_variables(result.model)
            println(name(var), " = ", value(var))
        end
    end

    #=
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 40            |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 100           |                      | S1: 30
    =#
    @testset "EOD_problem_needs_cut_conso" begin
        println("\n\nEOD_problem_needs_cut_conso")
        context = create_instance(100., 30.,
                                40.,
                                35.,
                                "EOD_problem_needs_cut_conso")

        tso = PSCOPF.TSOBilevel()
        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Market needed to cut conso
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK

        #TSO RSO constraints are OK
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) <= 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) <= 1e-09

        #Market cuts conso for EOD reasons
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) <= 1e-09
        @test 90. ≈ value(result.lower.slack_model.p_cut_conso[TS[1],"S1"])

        for var in all_variables(result.model)
            println(name(var), " = ", value(var))
        end
    end

    #=
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 50            |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10            |                      | S1: 40
    =#
    @testset "RSO_problem" begin
        println("\n\nRSO_problem")
        context = create_instance(10., 40.,
                                50.,
                                35.,
                                "RSO_problem")

        tso = PSCOPF.TSOBilevel()
        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Market needed to cut conso
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK

        #TSO obliges cuts for RSO reasons
        #FIXME? normally both capping and lol are due to RSO constraints
        #however the TSO simply tells the market to cap some MW which only costs 5€
        #in this example, the market will be obliged to cut_conso for EOD reasons since there are no other productions
        # => cost of 5 + 5e7 in the market
        #this should not happen IRL cause the TSO will cap/bound prod on bus1 but allow producing with units at bus2
        @test 5. ≈ value(result.upper.limitable_model.p_capping_min[TS[1],"S1"])
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) <= 1e-09

        #Market only cuts as required since EOD is OK
        @test 5. ≈ value(result.lower.limitable_model.p_capping[TS[1],"S1"])
        @test 5. ≈ value(result.lower.slack_model.p_cut_conso[TS[1],"S1"])

        for var in all_variables(result.model)
            println(name(var), " = ", value(var))
        end

        println(result.lower.objective_model.full_obj)
        @printf("%.8f", value(result.lower.objective_model.full_obj))
    end


end