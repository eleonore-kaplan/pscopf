using PSCOPF

using Test
using Dates

@testset verbose=true "test_energy_market_dp" begin

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load
    Pmin=0, Pmax=100    | S1: 55
    Csta=0, Cprop=1     |
    DP => 10h40         |
      S1: 20            |
                        |
    (imposable) prod_1_1|
    Pmin=10, Pmax=100   |
    Csta=0, Cprop=10    |
    DP => 10h30         |
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
    # Limitables
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                            0., 100.,
                                            0., 1.,
                                            Dates.Second(20*60), Dates.Second(20*60))
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
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T10:00:00"), "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T10:00:00"), "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T10:40:00"), "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T10:40:00"), "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
    # initial generators state : need to pay starting cost at TS[1]
    generators_init_state = SortedDict(
        "prod_1_1" => PSCOPF.OFF,
        "prod_1_2" => PSCOPF.OFF
    )
    #ManagementMode
    mode = PSCOPF.ManagementMode("test_mode", Dates.Minute(5))

    #=
            ECH   TS
    |        |    |
            10h   11h
             <---->
               FO
    =#
    @testset "energy_market_cannot_be_launched_after_or_at_FO" begin
        ech = DateTime("2015-01-01T10:00:00")
        mode1 = PSCOPF.PSCOPF_MODE_1 # FO == 10h

        # firmness : wrong firmness % ech/DMO/DP but doesn't matter
        firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), ),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode1,
                                        generators_init_state,
                                        uncertainties, nothing)

        market = PSCOPF.EnergyMarket()
        @test_throws ErrorException PSCOPF.run(market, ech, firmness,
                                                PSCOPF.get_target_timepoints(context),
                                                context)
    end


    #=
    ECH1*         ECH2            ECH3                                 <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                  <--------------------------DP(wind1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "energy_market_can_change_the_production_level_before_dp_if_ON" begin
        ech = DateTime("2015-01-01T10:00:00")

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        # prod_1_1 and prod_1_2 are both ON (e.g. due to RSO constraint though here we have 1 bus)
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
                                        "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                            SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                            # SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                            #                                                                         SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>18.)))
                                            ),
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
                                                                                                                    SortedDict("S1"=>37.)))
                                            )
                                        )
                                )

        market = PSCOPF.EnergyMarket()

        @test firmness == PSCOPF.compute_firmness(market,
                                                ech, DateTime("2015-01-01T10:30:00"),
                                                TS, context)

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        # prod_1_1 is OFF cause it already was OFF:
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # prod_1_2 was ON, it can change it's production : 37 => 35.
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test 35. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1")
    end


    #=
    ECH1          ECH2            ECH3*          ECH4                  <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                  <--------------------------DP(wind1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "energy_market_cannot_change_the_production_level_after_dp" begin
        # We are past DP[prod_1_1]
        ech = DateTime("2015-01-01T10:40:00")

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE),
                            "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        # prod_1_1 and prod_1_2 are both ON (e.g. due to RSO constraint)
        # prod_1_1 has a definitive value since we are past the DP
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
                                        "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                            SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                            # SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                            #                                                                         SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>18.)))
                                            ),
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(17.,
                                                                                                                    SortedDict("S1"=>17.)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>20.)))
                                            )
                                        )
                                )

        market = PSCOPF.EnergyMarket()

        @test firmness == PSCOPF.compute_firmness(market,
                                                ech, DateTime("2015-01-01T10:45:00"),
                                                TS, context)

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        # we are past DP[prod_1_] => we can't change the level of prod_1_1
        # prod_1_1 : 17.
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test 17. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        # prod_1_2 : 20 => 18.
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test 18. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1")
    end

    #=
    at ECH2, we are at wind_1_1's DP,
    but the decision made will still be by scenario cause it depends on the uncertainties
    limitables's DP only applies to limitation decisions (=> applied in TSO)
    ECH1          ECH2            ECH3*          ECH4                  <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                  <--------------------------DP(wind1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "energy_market_wind_is_always_uncertain" begin
        # We are past DP[prod_1_1]
        ech = DateTime("2015-01-01T10:40:00")

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE),
                            "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        # prod_1_1 and prod_1_2 are both ON (e.g. due to RSO constraint)
        # prod_1_1 has a definitive value since we are past the DP
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
                                        "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                            SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                            # SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                            #                                                                         SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>18.)))
                                            ),
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(17.,
                                                                                                                    SortedDict("S1"=>17.)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>20.)))
                                            )
                                        )
                                )

        market = PSCOPF.EnergyMarket()

        @test firmness == PSCOPF.compute_firmness(market,
                                                ech, DateTime("2015-01-01T10:45:00"),
                                                TS, context)

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        @test !PSCOPF.is_definitive(PSCOPF.get_prod_uncertain_value(context.market_schedule, "wind_1_1", TS[1]))
    end

    #=
    ECH1*         ECH2            ECH3           ECH4                  <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                  <--------------------------DP(wind1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "energy_market_cannot_change_the_production_level_before_dp_if_unit_is_off_and_past_DMO" begin
        ech = DateTime("2015-01-01T10:00:00")

        # firmness
        firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        # prod_1_1 is OFF and we are past the DMO (e.g. sue to RSO constraint)
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
                                        "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                            SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                            # SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                            #                                                                         SortedDict("S1"=>PSCOPF.ON))),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                                    SortedDict("S1"=>35.)))
                                            ),
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
                                                                                                                    SortedDict("S1"=>25.)))
                                            )
                                        )
                                )

        market = PSCOPF.EnergyMarket()

        @test firmness == PSCOPF.compute_firmness(market,
                                                ech, DateTime("2015-01-01T10:30:00"),
                                                TS, context)

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        # We are past DMO => unit state was already fixed
        # prod_1_1 : OFF
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # prod_1_2 : 25 => 35.
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test 35. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1")
    end

end