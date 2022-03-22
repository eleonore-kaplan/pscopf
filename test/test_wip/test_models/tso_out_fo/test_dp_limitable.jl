using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_tso_out_fo_dp" begin

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load
    Pmin=0, Pmax=100    | S1: 55
    Csta=0, Cprop=1     | S2: 60
    DP => 10h40         |
      S1: 55            |
      S2: 60            |
    =#

    TS = [DateTime("2015-01-01T11:00:00")]
    network = PSCOPF.Networks.Network()
    # Buses
    PSCOPF.Networks.add_new_bus!(network, "bus_1")
    # Limitables
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                            0., 100.,
                                            0., 1.,
                                            Dates.Second(20*60), Dates.Second(20*60))
    # Uncertainties
    uncertainties = PSCOPF.Uncertainties()
    # initial generators state : need to pay starting cost at TS[1]
    generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()
    #ManagementMode
    mode = PSCOPF.ManagementMode("test_mode", Dates.Minute(5))

    #=
    ECH1*                    ECH2              ECH3         <---FO--->TS
    |                        |
    10h                      10h40             10h45                 11h
                             <--------------------DP(wind1)----------->
    =#
    @testset "tso_out_fo_can_change_the_limit_before_dp" begin
        ech = DateTime("2015-01-01T10:00:00")
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict(),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        #This limit should be ignored because firmness is FREE
        OLD_LIMIT = 55.
        PSCOPF.set_limitation_value!(context.tso_actions, "wind_1_1", TS[1], OLD_LIMIT)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
                                            "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                                SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                        SortedDict("S1"=>55.,"S2"=>55.)))
                                                ),
                                            )
                                    )

        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T10:00:00"), SortedDict(
                                        "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                            SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>57.,"S2"=>62.)))
                                            ),
                                        )
                                )

        tso = PSCOPF.TSOOutFO()

        @test firmness == PSCOPF.compute_firmness(tso,
                                                ech, DateTime("2015-01-01T10:40:00"),
                                                TS, context)

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # Limit was changed since we are before DP
        @test value(result.limitable_model.p_limit["wind_1_1",TS[1]]) > 55. == OLD_LIMIT
        @test 60. - 1e-09 <= value(result.limitable_model.p_limit["wind_1_1",TS[1]]) <= 100. + 1e-09
        #But this is not an active limit
        @test value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S1"]) < 1e-09
        @test value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S1"]) < 1e-09
        @test value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S2"]) < 1e-09
        @test value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S2"]) < 1e-09
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"]) < 1e-09
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S2"]) < 1e-09
    end

    #=
    ECH1                    ECH2              ECH3*         <---FO--->TS
    |                        |
    10h                      10h40             10h45                 11h
                             <--------------------DP(wind1)----------->
    =#
    @testset "tso_out_fo_can_increase_the_limit_after_dp" begin
        ech = DateTime("2015-01-01T10:45:00")
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 65.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict(),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        OLD_LIMIT = 55.
        PSCOPF.set_limitation_value!(context.tso_actions, "wind_1_1", TS[1], OLD_LIMIT)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T10:40:00"), SortedDict(
                                            "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                                SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                        SortedDict("S1"=>55.,"S2"=>55.)))
                                                ),
                                            )
                                    )

        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T10:45:00"), SortedDict(
                                        "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                            SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>57.,"S2"=>62.)))
                                            ),
                                        )
                                )

        tso = PSCOPF.TSOOutFO()

        @test firmness == PSCOPF.compute_firmness(tso,
                                                ech, DateTime("2015-01-01T10:50:00"),
                                                TS, context)

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution has slacks
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # Limit can be changed after DP :
        @test 55. == OLD_LIMIT < value(result.limitable_model.p_limit["wind_1_1",TS[1]]) ≈ 60

        @test value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S1"]) < 1e-09
        @test value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S1"]) < 1e-09
        @test 55. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1], "S1"])
        @test 1. ≈ value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S2"])
        @test 60. ≈ value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S2"])
        @test 60. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1], "S2"])
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"]) < 1e-09
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S2"]) < 1e-09
    end

    #=
    ECH1                    ECH2              ECH3*         <---FO--->TS
    |                        |
    10h                      10h40             10h45                 11h
                             <--------------------DP(wind1)----------->
    =#
    @testset "tso_out_fo_can_decrease_the_limit_after_dp" begin
        ech = DateTime("2015-01-01T10:45:00")
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 65.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict(),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        OLD_LIMIT = 70.
        PSCOPF.set_limitation_value!(context.tso_actions, "wind_1_1", TS[1], OLD_LIMIT)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T10:40:00"), SortedDict(
                                            "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                                SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                        SortedDict("S1"=>70.,"S2"=>70.)))
                                                ),
                                            )
                                    )

        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T10:45:00"), SortedDict(
                                        "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                            SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>57.,"S2"=>62.)))
                                            ),
                                        )
                                )

        tso = PSCOPF.TSOOutFO()

        @test firmness == PSCOPF.compute_firmness(tso,
                                                ech, DateTime("2015-01-01T10:50:00"),
                                                TS, context)

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution has slacks
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # Limit cannot be changed after DP : Ideally we would have 60. to use all available limitable power
        @test 70. == OLD_LIMIT > value(result.limitable_model.p_limit["wind_1_1",TS[1]]) ≈ 60

        @test value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S1"]) < 1e-09
        @test value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S1"]) < 1e-09
        @test 55. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1], "S1"])
        @test 1. ≈ value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S2"])
        @test 60. ≈ value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S2"])
        @test 60. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1], "S2"])
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"]) < 1e-09
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S2"]) < 1e-09
    end

end