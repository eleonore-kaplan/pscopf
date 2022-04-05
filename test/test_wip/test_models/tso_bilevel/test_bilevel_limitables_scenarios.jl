using PSCOPF

using .PSCOPFFixtures

using Test
using JuMP
using Dates
using DataStructures
using Printf

@testset verbose=true "test_bilevel_limitables_scenarios" begin

    TS = [DateTime("2015-01-01T11:00:00")]
    ech = DateTime("2015-01-01T07:00:00")
    next_ech = DateTime("2015-01-01T07:30:00")
    scenarios = ["S1", "S2"]
    function create_instance(scenarios,
                            load_1::Vector{Float64}, load_2::Vector{Float64}, wind_1::Vector{Float64},
                            limit::Float64=35.,
                            logs=nothing)
        network = PSCOPFFixtures.network_2buses(limit=limit)
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))

        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        for (s_index, s) in enumerate(scenarios)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", TS[1], s, load_1[s_index])
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", TS[1], s, load_2[s_index])
            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", TS[1], s, wind_1[s_index])
        end

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
      S2: 60            |         35           |
                        |                      |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10            |                      | S1: 30
      S2: 25            |                      | S2: 35
    =#
    @testset "no_problem" begin

        context = create_instance(["S1", "S2"], #scenarios
                                    [10., 25.], #load1
                                    [30., 35.], #load2
                                    [40., 60.], #wind_1_1
                                35.)

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
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S2"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S2"]) < 1e-09

        #Market EOD constraints are OK
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        @test value(result.lower.limitable_model.p_capping[TS[1],"S2"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S2"]) < 1e-09

        # Limitations are by scenario : p_limit can be different for scenario 1 and 2
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]) > 40. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S1"]) < 1e-09
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S2"]) > 60. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S2"]) < 1e-09

    end

    #=
    previous + link limits
    =#
    @testset "no_problem_link_scenarios_limit" begin

        context = create_instance(["S1", "S2"], #scenarios
                                    [10., 25.], #load1
                                    [30., 35.], #load2
                                    [40., 60.], #wind_1_1
                                35.)

        tso = PSCOPF.TSOBilevel()
        tso.configs.LINK_SCENARIOS_LIMIT = true

        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

        #TSO RSO constraints are OK
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S2"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S2"]) < 1e-09

        #Market EOD constraints are OK
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        @test value(result.lower.limitable_model.p_capping[TS[1],"S2"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S2"]) < 1e-09

        # Limitations are by scenario
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]) > 40. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S1"]) < 1e-09
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S2"]) > 60. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S2"]) < 1e-09
        @test !PSCOPF.is_different( value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]),
                                value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S2"]) )

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
      S2: 60            |         35           |
                        |                      |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10            |                      | S1: 30
      S2: 10            |                      | S2: 50
    =#
    @testset "EOD_problem_needs_capping_in_s2" begin

        context = create_instance(["S1", "S2"], #scenarios
                                    [10., 10.], #load1
                                    [30., 50.], #load2
                                    [40., 60.], #wind_1_1
                                35.)

        tso = PSCOPF.TSOBilevel()
        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK

        #TSO RSO constraints are OK in S1, but not in S2
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        @test 15. ≈ value(result.upper.limitable_model.p_capping_min[TS[1],"S2"])
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S2"]) < 1e-09

        #Market EOD constraints are OK, but there would be a disbalance in S2 due to RSO action
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        @test 15. ≈ value(result.lower.limitable_model.p_capping[TS[1],"S2"])
        @test 15. ≈ value(result.lower.slack_model.p_cut_conso[TS[1],"S2"])

        # need to limit in S2
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]) > 40. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S1"]) < 1e-09
        @test 45. ≈ value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S2"])
        @test 1. ≈ value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S2"])

    end

    #=
    previous + link limits
    =#
    @testset "EOD_problem_needs_capping_in_s2_link_scenarios" begin

        context = create_instance(["S1", "S2"], #scenarios
                                    [10., 10.], #load1
                                    [30., 50.], #load2
                                    [40., 60.], #wind_1_1
                                35.)

        tso = PSCOPF.TSOBilevel()
        tso.configs.LINK_SCENARIOS_LIMIT = true

        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK

        #TSO needs to cap prod at S2 due to RSO constraints
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        @test 15. ≈ value(result.upper.limitable_model.p_capping_min[TS[1],"S2"])
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S2"]) < 1e-09

        #Market EOD constraints are disbalanced due to TSO limiting
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        @test 15. ≈ value(result.lower.limitable_model.p_capping[TS[1],"S2"])
        @test 15. ≈ value(result.lower.slack_model.p_cut_conso[TS[1],"S2"])

        # Limitations are by scenario
        @test 45. ≈ value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"])
        @test 45. ≈ value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S2"])
        @test !PSCOPF.is_different( value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]),
                                value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S2"]) )

    end

    #=
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 60            |----------------------|
      S2: 60            |         35           |
                        |                      |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 50            |                      | S1: 10
      S2: 10            |                      | S2: 50

      No problem in S1
      In S2, RSO constraint is violated, need to limit flow 1->2 to 35
            => limit wind1 to 45=10+35
            or cut conso on bus2 to 35
    =#
    @testset "limiting_a_scenario_does_not_affect_the_other" begin

        context = create_instance(["S1", "S2"], #scenarios
                                    [50., 10.], #load1
                                    [10., 50.], #load2
                                    [60., 60.], #wind_1_1
                                35.)

        tso = PSCOPF.TSOBilevel()
        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK

        #TSO RSO constraints are OK in S1, but not in S2
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        @test 15. ≈ value(result.upper.limitable_model.p_capping_min[TS[1],"S2"])
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S2"]) < 1e-09

        #Market EOD constraints are OK, but there would be a disbalance in S2 due to RSO action
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        @test 15. ≈ value(result.lower.limitable_model.p_capping[TS[1],"S2"])
        @test 15. ≈ value(result.lower.slack_model.p_cut_conso[TS[1],"S2"])

        # need to limit in S2
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]) > 40. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S1"]) < 1e-09
        @test 45. ≈ value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S2"])
        @test 1. ≈ value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S2"])

    end

    #=
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 60            |----------------------|
      S2: 60            |         35           |
                        |                      |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 50            |                      | S1: 10
      S2: 10            |                      | S2: 50

      Initially, No problem in S1
      In S2, RSO constraint is violated, need to limit flow 1->2 to 35
            => limit wind1 to 45=10+35 (option 1)
            or cut conso on bus2 to 35 (option 2)

      Option 1 : limiting wind1 to 45 in S2,
          will oblige to limit wind1 to 45 in S1 as well
          => for tso : 15MW capped in S1, 15MW capped in S2
                       no need to impose cutting consumption (lol) cause capping + EOD will oblige the market to do it
                        => cost : 30
             for market : 15MW capped in S1, 15MW capped in S2
                        cut 15MW consumption in S1 and 15 MW consumption in S2
                        => cost 30 + 30*1e7

      Option 2 : cutting conso on bus 2 in scenario S2
          EOD + the fact that limitables produce at available uncertainty oblige TSO to limit S2 at 45
          => limit S1 at 45
          => cost of option 1 + cost of cutting conso by the TSO
          => for TSO, option 1 is preferable.

      Ideally, we would have cut conso for S2 without limiting (not possible in the current model)
      and then the market would only cut 15MW in S2 instead of cutting in both scenarios.

    previous + link limits
    =#
    @testset "limiting_a_scenario_affects_the_other_link_scenarios" begin

        context = create_instance(["S1", "S2"], #scenarios
                                    [50., 10.], #load1
                                    [10., 50.], #load2
                                    [60., 60.], #wind_1_1
                                35.)

        tso = PSCOPF.TSOBilevel()
        tso.configs.LINK_SCENARIOS_LIMIT = true

        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK

        # TSO needs to cap prod at S2 due to RSO constraints,
        #but limiting is the same across scenarios => capping will be needed to solve S1's limiting as well
        @test 15. ≈ value(result.upper.limitable_model.p_capping_min[TS[1],"S1"])
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        @test 15. ≈ value(result.upper.limitable_model.p_capping_min[TS[1],"S2"])
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S2"]) < 1e-09

        #Market EOD constraints are disbalanced due to TSO limiting
        @test 15. ≈ value(result.lower.limitable_model.p_capping[TS[1],"S1"])
        @test 15. ≈ value(result.lower.slack_model.p_cut_conso[TS[1],"S1"])

        @test 15. ≈ value(result.lower.limitable_model.p_capping[TS[1],"S2"])
        @test 15. ≈ value(result.lower.slack_model.p_cut_conso[TS[1],"S2"])

        # Limitations are by scenario
        @test 45. ≈ value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"])
        @test 45. ≈ value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S2"])
        @test !PSCOPF.is_different( value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]),
                                value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S2"]) )

    end

end
