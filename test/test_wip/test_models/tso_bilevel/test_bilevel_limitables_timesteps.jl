using PSCOPF

using .PSCOPFFixtures

using Test
using JuMP
using Dates
using DataStructures
using Printf

@testset verbose=true "test_bilevel_limitables_timesteps" begin

    TS = [DateTime("2015-01-01T11:00:00"), DateTime("2015-01-01T11:15:00")]
    ech = DateTime("2015-01-01T07:00:00")
    next_ech = DateTime("2015-01-01T07:30:00")
    function create_instance(timesteps,
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
        for (ts_index, ts) in enumerate(timesteps)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", ts, "S1", load_1[ts_index])
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", ts, "S1", load_2[ts_index])
            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", ts, "S1", wind_1[ts_index])
        end

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                    SortedDict{String,PSCOPF.GeneratorState}(), #gen_initial_state
                                    uncertainties, nothing, logs)

        return context
    end

    #=
    TS: [11h, 11h15]
    S: S1
      TS1       TS2
                       bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 40    S1: 60  |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10    S1: 25  |                      | S1: 30   S1: 35
    =#
    @testset "no_problem" begin
        println("\n\nno_problem")

        context = create_instance(TS,
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

        @test value(result.upper.limitable_model.p_capping_min[TS[2],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[2],"S1"]) < 1e-09

        #Market EOD constraints are OK
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        @test value(result.lower.limitable_model.p_capping[TS[2],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[2],"S1"]) < 1e-09

        # Limitations are by scenario : p_limit can be different for scenario 1 and 2
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]) > 40. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S1"]) < 1e-09
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[2],"S1"]) > 60. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[2],"S1"]) < 1e-09

    end

    #=
    TS: [11h, 11h15]
    S: [S1]
      TS1       TS2
                       bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 40    S1: 60  |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10    S1: 10  |                      | S1: 30   S1: 30

    In TS2, we have excess production
    => Market should cap the production.
    => limitation of the prod
    Note: the TSO does a limitation even if it's due to EOD constraints
    =#
    @testset "EOD_problem_needs_capping_in_ts2" begin
        println("\n\nEOD_problem_needs_capping_in_ts2")

        context = create_instance(TS,
                                    [10., 10.], #load1
                                    [30., 30.], #load2
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

        #TSO RSO constraints are OK => no minimum capping or cut conso
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        @test value(result.upper.limitable_model.p_capping_min[TS[2],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[2],"S1"]) < 1e-09

        # EOD problem in TS2 : lots of prod
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        @test 20. ≈ value(result.lower.limitable_model.p_capping[TS[2],"S1"])
        @test value(result.lower.slack_model.p_cut_conso[TS[2],"S1"]) < 1e-09

        # need to limit in TS2
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]) > 40. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S1"]) < 1e-09
        @test 40. ≈ value(result.upper.limitable_model.p_limit["wind_1_1",TS[2],"S1"])
        @test 1. ≈ value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[2],"S1"])

    end

    #=
    TS: [11h, 11h15]
    S: [S1]
      TS1       TS2
                       bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 40    S1: 40  |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10    S1: 30  |                      | S1: 30   S1: 30

    In TS2, we have production deficit
    => Market should cut conso.
    =#
    @testset "EOD_problem_needs_cut_conso_in_ts2" begin
        println("\n\nEOD_problem_needs_cut_conso_in_ts2")

        context = create_instance(TS,
                                    [10., 30.], #load1
                                    [30., 30.], #load2
                                    [40., 40.], #wind_1_1
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

        #TSO RSO constraints are OK
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        @test value(result.upper.limitable_model.p_capping_min[TS[2],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[2],"S1"]) < 1e-09

        # EOD problem in TS2 : lot of conso
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        @test value(result.lower.limitable_model.p_capping[TS[2],"S1"]) < 1e-09
        @test 20. ≈ value(result.lower.slack_model.p_cut_conso[TS[2],"S1"])

        # no need to limit
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]) > 40. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S1"]) < 1e-09
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]) > 40. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[2],"S1"]) < 1e-09

        #TSO distributes the cut conso assuring RSO
        @test ( value(result.upper.slack_model.p_cut_conso["bus_1", TS[1],"S1"])
            + value(result.upper.slack_model.p_cut_conso["bus_2", TS[1],"S1"]) ) < 1e-09
        @test 20. ≈ ( value(result.upper.slack_model.p_cut_conso["bus_1", TS[2],"S1"])
                    + value(result.upper.slack_model.p_cut_conso["bus_2", TS[2],"S1"]) )

    end

    #=
    TS: [11h, 11h15]
    S: [S1]
      TS1       TS2
                       bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 40    S1: 50  |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10    S1: 10  |                      | S1: 30   S1: 40
    =#
    @testset "RSO_problem_in_ts2" begin
        println("\n\nRSO_problem_in_ts2")

        context = create_instance(TS,
                                    [10., 10.], #load1
                                    [30., 40.], #load2
                                    [40., 50.], #wind_1_1
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

        #TSO RSO constraints are violated in TS2 => need to limit flow to 35
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        @test 5. ≈ value(result.upper.limitable_model.p_capping_min[TS[2],"S1"])
        @test value(result.upper.slack_model.p_cut_conso_min[TS[2],"S1"]) < 1e-09

        # EOD problem in TS2 due to TSO action
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        @test 5. ≈ value(result.lower.limitable_model.p_capping[TS[2],"S1"])
        @test 5. ≈ value(result.lower.slack_model.p_cut_conso[TS[2],"S1"])

        # need to limit in TS2
        @test value(result.upper.limitable_model.p_limit["wind_1_1",TS[1],"S1"]) > 40. - 1e-09
        @test value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[1],"S1"]) < 1e-09

        @test 45. ≈ value(result.upper.limitable_model.p_limit["wind_1_1",TS[2],"S1"])
        @test 1. ≈ value(result.upper.limitable_model.b_is_limited["wind_1_1",TS[2],"S1"])

        #TSO distributes the cut conso assuring RSO
        @test ( value(result.upper.slack_model.p_cut_conso["bus_1", TS[1],"S1"])
            + value(result.upper.slack_model.p_cut_conso["bus_2", TS[1],"S1"]) ) < 1e-09
        @test 5. ≈ ( value(result.upper.slack_model.p_cut_conso["bus_1", TS[2],"S1"])
                    + value(result.upper.slack_model.p_cut_conso["bus_2", TS[2],"S1"]) )
        @test value(result.upper.slack_model.p_cut_conso["bus_1", TS[2],"S1"]) < 1e-09
        @test 5. ≈ value(result.upper.slack_model.p_cut_conso["bus_2", TS[2],"S1"])

    end

end
