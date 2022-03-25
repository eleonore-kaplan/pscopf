using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_tso_out_fo_dp_imposable" begin

    #=
    TS: [11h]
    S: [S1]
                      bus 1
                        |
    (imposable) prod_1_1|load
     Pmin=10, Pmax=100  | S1: 55
     Csta=0, Cprop=10   |
     DP => 10h30        |
                        |
    (imposable) prod_1_2|
     Pmin=10, Pmax=100  |
     Csta=0, Cprop=15   |
     DP => 10h45        |
                        |

    =#

    TS = [DateTime("2015-01-01T11:00:00")]
    network = PSCOPF.Networks.Network()
    # Buses
    PSCOPF.Networks.add_new_bus!(network, "bus_1")
    # Imposables
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                            10., 100.,
                                            0., 10.,
                                            Dates.Second(3*60*60), Dates.Second(30*60))
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.IMPOSABLE,
                                            10., 100.,
                                            0., 15.,
                                            Dates.Second(3*60*60), Dates.Second(15*60))
    # Uncertainties
    uncertainties = PSCOPF.Uncertainties()
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T10:00:00"), "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T10:50:00"), "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
    # initial generators state : need to pay starting cost at TS[1]
    generators_init_state = SortedDict(
        "prod_1_1" => PSCOPF.OFF,
        "prod_1_2" => PSCOPF.OFF
    )
    #ManagementMode
    mode = PSCOPF.ManagementMode("test_mode", Dates.Minute(5))

    #=
    ECH1*         ECH2            ECH3                                 <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "tso_can_change_the_production_level_before_dp_if_ON" begin
        ech = DateTime("2015-01-01T10:00:00")

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                                                    SortedDict("S1"=>PSCOPF.OFF))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>0.)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>50.)))
                                            )
                                        )
                                    )

        # Market schedule does not respect EOD for ech=10h, ts=11h, S1
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T10:00:00"), SortedDict(
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                                                    SortedDict("S1"=>PSCOPF.OFF))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>0.)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>60.)))
                                            )
                                        )
                                )

        tso = PSCOPF.TSOOutFO()

        @test firmness == PSCOPF.compute_firmness(tso,
                                                ech, DateTime("2015-01-01T10:30:00"),
                                                TS, context)

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # prod_1_1 is OFF cause it already was OFF:
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # prod_1_2 was ON, it can change it's production : 50 => 55.
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
        @test 55. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
    end


    #=
    ECH1          ECH2            ECH3           ECH4        ECH5*    <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "tso_cannot_change_the_production_level_after_dp" begin
        ech = DateTime("2015-01-01T10:50:00")

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T10:45:00"), SortedDict(
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                                                    SortedDict("S1"=>PSCOPF.OFF))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(0.,
                                                                                                                    SortedDict("S1"=>0.)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(50.,
                                                                                                                    SortedDict("S1"=>50.)))
                                            )
                                        )
                                    )

        # Market schedule can not be adopted, cause it will imply changing an already decided production (prod_1_2) after DP
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T10:50:00"), SortedDict(
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                                                    SortedDict("S1"=>PSCOPF.OFF))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(0.,
                                                                                                                    SortedDict("S1"=>0.)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(55.,
                                                                                                                    SortedDict("S1"=>55.)))
                                            )
                                        )
                                )

        tso = PSCOPF.TSOOutFO()

        @test firmness == PSCOPF.compute_firmness(tso,
                                                ech, DateTime("2015-01-01T10:55:00"),
                                                TS, context)

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal but has slack due to infeasibility
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK
        # prod_1_1 is OFF cause it already was OFF:
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # prod_1_2 cannot be changed after DP
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
        @test 50. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
        # slack for feasibility
        @test 5. ≈ value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"])
    end

    #=
    ECH1*         ECH2            ECH3           ECH4                  <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "tso_cannot_change_the_production_level_before_dp_if_unit_is_off_and_past_DMO" begin
        ech = DateTime("2015-01-01T10:00:00")

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                                                    SortedDict("S1"=>PSCOPF.OFF))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>0.)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                                                    SortedDict("S1"=>PSCOPF.OFF))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>0.)))
                                            )
                                        )
                                    )

        # Market schedule can not be adopted, cause it will imply changing an already decided production (prod_1_2) after DP
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T10:00:00"), SortedDict(
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                                                    SortedDict("S1"=>PSCOPF.OFF))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>55.)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>0.)))
                                            )
                                        )
                                )

        tso = PSCOPF.TSOOutFO()

        @test firmness == PSCOPF.compute_firmness(tso,
                                                ech, DateTime("2015-01-01T10:30:00"),
                                                TS, context)

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal but has slack due to infeasibility
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK
        # prod_1_1 is OFF cause it already was OFF:
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # prod_1_2 cannot be changed after DP
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_2", TS[1], "S1") < 1e-09
        # slack for feasibility
        @test 55. ≈ value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"])
    end

end