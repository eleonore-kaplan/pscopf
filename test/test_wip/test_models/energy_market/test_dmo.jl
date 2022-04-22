using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_energy_market_dmo" begin

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load
    Pmin=0, Pmax=100    |  S1:55
    Csta=0, Cprop=1     |
      S1: 20            |
                        |
    (imposable) prod_1_1|
    Pmin=10, Pmax=100   |
    Csta=0, Cprop=10    |
    DMO => 8h           |
                        |
    (imposable) prod_1_2|
     Pmin=10, Pmax=100  |
     Csta=0, Cprop=15   |
     DMO => 10h30       |
                        |
    =#
    function create_instance(ech, next_ech, ts,
                            prod_1_state, prod_1_state_definitive, prod_1_level,
                            prod_2_state, prod_2_state_definitive, prod_2_level,
                            )
        ECH = [DateTime("2015-01-01T07:00:00"), DateTime("2015-01-01T09:00:00"), DateTime("2015-01-01T10:35:00")]
        @assert (ech in ECH)
        network = PSCOPF.Networks.Network()
        # Buses
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                10., 100.,
                                                0., 10.,
                                                Dates.Second(3*60*60), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.IMPOSABLE,
                                                10., 100.,
                                                0., 15.,
                                                Dates.Second(30*60), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ECH[1], "wind_1_1", ts, "S1", 20.)
        PSCOPF.add_uncertainty!(uncertainties, ECH[1], "bus_1", ts, "S1", 55.)
        PSCOPF.add_uncertainty!(uncertainties, ECH[2], "wind_1_1", ts, "S1", 20.)
        PSCOPF.add_uncertainty!(uncertainties, ECH[2], "bus_1", ts, "S1", 55.)
        PSCOPF.add_uncertainty!(uncertainties, ECH[3], "wind_1_1", ts, "S1", 20.)
        PSCOPF.add_uncertainty!(uncertainties, ECH[3], "bus_1", ts, "S1", 55.)
        # initial generators state : need to pay starting cost at ts
        generators_init_state = SortedDict(
            "prod_1_1" => PSCOPF.OFF,
            "prod_1_2" => PSCOPF.OFF
        )
        mode = PSCOPF.ManagementMode("mode_5mins", Dates.Minute(5))

        prod_1_state_def = prod_1_state_definitive ? prod_1_state : missing
        prod_2_state_def = prod_2_state_definitive ? prod_2_state : missing
        initial_schedule = PSCOPF.Schedule(PSCOPF.Market(), ech - Second(1), SortedDict(
            "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                # SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                #                                                                          SortedDict("S1"=>PSCOPF.ON))),
                SortedDict(ts => PSCOPF.UncertainValue{Float64}(missing,
                                                                SortedDict("S1"=>20.)))
                ),
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(ts => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(prod_1_state_def,
                                                                SortedDict("S1"=>prod_1_state))),
                SortedDict(ts => PSCOPF.UncertainValue{Float64}(missing,
                                                                SortedDict("S1"=>prod_1_level)))
                ),
            "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                SortedDict(ts => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(prod_2_state_def,
                                                                SortedDict("S1"=>prod_2_state))),
                SortedDict(ts => PSCOPF.UncertainValue{Float64}(missing,
                                                                SortedDict("S1"=>prod_2_level)))
                )
            )
        )

        context = PSCOPF.PSCOPFContext(network, [ts], mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        context.market_schedule = initial_schedule

        market = PSCOPF.EnergyMarket()

        firmness = PSCOPF.compute_firmness(market, ech,
                                            next_ech,
                                            [ts], context)

        return context, market, firmness
    end

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load
    Pmin=0, Pmax=100    |  S1:55
    Csta=0, Cprop=1     |
      S1: 20            |
                        |
    (imposable) prod_1_1|
    Pmin=10, Pmax=100   |
    Csta=0, Cprop=10    |
    DMO => 8h           |
                        |
    (imposable) prod_1_2|
     Pmin=10, Pmax=100  |
     Csta=0, Cprop=15   |
     DMO => 10h30       |
                        |

    We can start an imposable before its DMO.
    ech = 7h
    TS = 11h
    DMO(prod_1_1) = 3h => 8h
    DMO(prod_1_2) = 30mins => 10h30

    We suppose that in the preceding step we decided :
    prod_1_1 : OFF (non definitive)
    prod_1_2 : ON (non definitive)

    but in terms of cost, it is cheaper to use prod_1_1.
    Since we haven't reached the DMO yet, we can start prod_1_1
    => the new decision :
    prod_1_1 : ON (unit started)
    prod_1_2 : OFF (unit shutdown)
    =#
    @testset "energy_market_can_start_unit_when_commitment_firmness_is_FREE" begin
        ech = DateTime("2015-01-01T07:00:00")
        next_ech = DateTime("2015-01-01T08:00:00")
        TS = [DateTime("2015-01-01T11:00:00")]
        context, market, firmness = create_instance(ech, next_ech, TS[1],
                                                    PSCOPF.OFF, false, 0.,
                                                    PSCOPF.ON, false, 35.,
                                                    )

        # firmness
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), ),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )
        @test firmness == expected_firmness

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        # we started prod_1_1
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test 35. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        # we shut down prod_1_2
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1") < 1e-09
    end

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load
    Pmin=0, Pmax=100    |  S1:55
    Csta=0, Cprop=1     |
      S1: 20            |
                        |
    (imposable) prod_1_1|
    Pmin=10, Pmax=100   |
    Csta=0, Cprop=10    |
    DMO => 8h           |
                        |
    (imposable) prod_1_2|
     Pmin=10, Pmax=100  |
     Csta=0, Cprop=15   |
     DMO => 10h30       |
                        |

    We can no longer start an imposable after its DMO.
    ech = 9h
    TS = 11h
    DMO(prod_1_1) = 3h => 8h => We are past DMO!
    DMO(prod_1_2) = 30mins => 10h30

    We suppose that in the preceding step we decided :
    prod_1_1 : OFF (definitive)
    prod_1_2 : ON (non definitive)

    but in terms of cost, it is cheaper to use prod_1_1.
    We would like to start prod_1_1 cause it's cheaper. But we are past DMO => we can no longer start it.
    => we are stuck using prod_1_2 :
    prod_1_1 : OFF
    prod_1_2 : ON
    =#
    @testset "energy_market_cannot_start_unit_after_DMO" begin
        ech = DateTime("2015-01-01T09:00:00")
        next_ech = DateTime("2015-01-01T10:00:00")
        TS = [DateTime("2015-01-01T11:00:00")]
        context, market, firmness = create_instance(ech, next_ech, TS[1],
                                                    PSCOPF.OFF, true, 0.,
                                                    PSCOPF.ON, false, 35.,
                                                    )

        # firmness : prod_1_1 is already decided (DMO > ECH)
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), ),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )
        @test firmness == expected_firmness

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        # we could not start prod_1_1 due to DMO even if it is cheaper
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # we use prod_1_2
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test 35. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1")
    end

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load
    Pmin=0, Pmax=100    |  S1:55
    Csta=0, Cprop=1     |
      S1: 20            |
                        |
    (imposable) prod_1_1|
    Pmin=10, Pmax=100   |
    Csta=0, Cprop=10    |
    DMO => 8h           |
                        |
    (imposable) prod_1_2|
     Pmin=10, Pmax=100  |
     Csta=0, Cprop=15   |
     DMO => 10h30       |
                        |

    We can still shutdown a unit after DMO.
    We can still change a unit's level after DMO (before DP).

    ech = 10h35
    TS = 11h
    DMO(prod_1_1) = 3h => 8h => We are past DMO!
    DMO(prod_1_2) = 30mins => 10h30 => We are past DMO!

    We suppose that in the preceding step we decided :
    prod_1_1 : ON (definitive) at 15MW
    prod_1_2 : ON (definitive) at 20MW

    but in terms of cost, it is cheaper to only use prod_1_1.
    => we can change the levels to :
    prod_1_1 : ON at 35MW (production level changed)
    prod_1_2 : OFF (unit was shutdown)
    =#
    @testset "energy_market_can_shutdown_unit_after_DMO" begin
        ech = DateTime("2015-01-01T10:35:00")
        next_ech = DateTime("2015-01-01T10:45:00")
        TS = [DateTime("2015-01-01T11:00:00")]
        context, market, firmness = create_instance(ech, next_ech, TS[1],
                                                    PSCOPF.ON, true, 15.,
                                                    PSCOPF.ON, true, 20.,
                                                    )
        # firmness : prod_1_1 is already decided (DMO > ECH)
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )
        @test firmness == expected_firmness

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        # we use prod_1_1, it was already started, we can change production before DP
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test 35. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        # we can shutdown prod_1_2 after the DMO
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1") < 1e-09
    end

end