using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_energy_market_tso_actions" begin

    @testset "energy_market_respects_tso_actions_commitment" begin

        #=
        TS: [11h]
        S: [S1]
                            bus 1
                            |
        (imposable) prod_1_1|load
        Pmin=10, Pmax=100   |  S1:55
        Csta=0, Cprop=10    |
        DMO => 8h           |
                            |
        (imposable) prod_1_2|
        Pmin=10, Pmax=100   |
        Csta=0, Cprop=50    |
        DMO => 8h           |
        =#
        function create_instance(ech, next_ech, ts,
                                market_state_1, market_state_definitive_1::Bool, market_level_1,
                                tso_action_state_1,
                                market_state_2, market_state_definitive_2::Bool, market_level_2,
                                tso_action_state_2,
                                )
            ECH = [DateTime("2015-01-01T07:00:00"), DateTime("2015-01-01T09:00:00"), DateTime("2015-01-01T10:35:00")]
            @assert (ech in ECH)
            network = PSCOPF.Networks.Network()
            # Buses
            PSCOPF.Networks.add_new_bus!(network, "bus_1")
            # Imposables
            PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                    10., 100.,
                                                    0., 10.,
                                                    Dates.Second(3*60*60), Dates.Second(0))
            PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.IMPOSABLE,
                                                    10., 100.,
                                                    0., 50.,
                                                    Dates.Second(3*60*60), Dates.Second(0))
            # Uncertainties
            uncertainties = PSCOPF.Uncertainties()
            PSCOPF.add_uncertainty!(uncertainties, ECH[1], "bus_1", ts, "S1", 55.)
            PSCOPF.add_uncertainty!(uncertainties, ECH[2], "bus_1", ts, "S1", 55.)
            # initial generators state : need to pay starting cost at ts
            generators_init_state = SortedDict(
                "prod_1_1" => PSCOPF.OFF,
                "prod_1_2" => PSCOPF.OFF,
            )
            mode = PSCOPF.ManagementMode("mode_5mins", Dates.Minute(5))

            context = PSCOPF.PSCOPFContext(network, [ts], mode,
                                            generators_init_state,
                                            uncertainties, nothing)

            market_state_def_1 = market_state_definitive_1 ? market_state_1 : missing
            market_state_def_2 = market_state_definitive_2 ? market_state_2 : missing
            initial_schedule = PSCOPF.Schedule(PSCOPF.Market(), ech - Second(1), SortedDict(
                "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                    SortedDict(ts => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(market_state_def_1,
                                                                    SortedDict("S1"=>market_state_1))),
                    SortedDict(ts => PSCOPF.UncertainValue{Float64}(missing,
                                                                    SortedDict("S1"=>market_level_1)))
                    ),
                "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                    SortedDict(ts => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(market_state_def_2,
                                                                    SortedDict("S1"=>market_state_2))),
                    SortedDict(ts => PSCOPF.UncertainValue{Float64}(missing,
                                                                    SortedDict("S1"=>market_level_2)))
                    ),
                ),
            )
            context.market_schedule = initial_schedule

            if !ismissing(tso_action_state_1)
                PSCOPF.set_commitment_value!(context.tso_actions, "prod_1_1", ts, tso_action_state_1)
            end
            if !ismissing(tso_action_state_2)
                PSCOPF.set_commitment_value!(context.tso_actions, "prod_1_2", ts, tso_action_state_2)
            end

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
        (imposable) prod_1_1|load
        Pmin=10, Pmax=100   |  S1:55
        Csta=0, Cprop=10    |
        DMO => 8h           |
                            |
        (imposable) prod_1_2|
        Pmin=10, Pmax=100   |
        Csta=0, Cprop=50    |
        DMO => 8h           |

        If TSO Actions indicate a shutdown unit, the market respects the decision and cannot start the unit even before DMO.

        ech : 7h
        previous market decision :
            prod_1_1: ON at 55MW
            prod_1_2: OFF
        TSO Action : OFF
            prod_1_1: OFF
            prod_1_2: X

        The market prefers prod_1_1 cause cheaper but prod_1_1 was shutdown by TSO.
        => solution :
        prod_1_1 : OFF (due to TSO Actions)
        prod_1_2 : 55 MW
        =#
        @testset "energy_market_cannot_start_units_shutdown_in_tso_actions" begin
            ech = DateTime("2015-01-01T07:00:00")
            next_ech = DateTime("2015-01-01T08:00:00")
            TS = [DateTime("2015-01-01T11:00:00")]
            context, market, firmness = create_instance(ech, next_ech, TS[1],
                                                        #prod_1_1
                                                        PSCOPF.ON, false, 55., #previous market
                                                        PSCOPF.OFF, #tso actions
                                                        #prod_1_2
                                                        PSCOPF.OFF, false, 0., #previous market
                                                        missing, #tso actions
                                                        )

            # firmness
            expected_firmness = PSCOPF.Firmness(
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), ),
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                    )
            @test firmness == expected_firmness

            result = PSCOPF.run(market, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)
            PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

            # we could not start prod_1_1 since TSO indicated to shut it down
            @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
            @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09
            # we started prod_1_2 to respect EOD
            @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1")
            @test 55. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        end

        #=
        TS: [11h]
        S: [S1]
                            bus 1
                            |
        (imposable) prod_1_1|load
        Pmin=10, Pmax=100   |  S1:55
        Csta=0, Cprop=10    |
        DMO => 8h           |
                            |
        (imposable) prod_1_2|
        Pmin=10, Pmax=100   |
        Csta=0, Cprop=50    |
        DMO => 8h           |

        If TSO started a unit in TSO ACtions, the market can choose to use it or not

        at DMO,
            Market says prod_1_1 is OFF
            TSO says prod_1_1 is ON
        Then, at the next step
            market can use prod_1_1

        ech : 9h
        previous market decision :
            prod_1_1: OFF
            prod_1_2: OFF
        TSO Action :
            prod_1_1: ON
            prod_1_2: ON

        The market prefers prod_1_1 cause cheaper but prod_1_1 was shutdown by TSO.
        => solution :
        prod_1_1 : 55 MW (used since the TSOActions allow us to)
        prod_1_2 : OFF (not used even if the TSOActions allow us to)
        =#
        @testset "energy_market_can_use_units_started_in_tso_actions" begin
            ech = DateTime("2015-01-01T09:00:00")
            next_ech = DateTime("2015-01-01T10:00:00")
            TS = [DateTime("2015-01-01T11:00:00")]
            context, market, firmness = create_instance(ech, next_ech, TS[1],
                                                        #prod_1_1
                                                        PSCOPF.OFF, true, 0., #previous market
                                                        PSCOPF.ON, #tso actions
                                                        #prod_1_2
                                                        PSCOPF.OFF, true, 0., #previous market
                                                        PSCOPF.ON, #tso actions
                                                        )

            # firmness
            expected_firmness = PSCOPF.Firmness(
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                                "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                    )
            @test firmness == expected_firmness

            result = PSCOPF.run(market, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)
            PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

            # The TSO started prod_1_1 so we can use it
            @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
            @test 55. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1")
            # we can use prod_1_2 but we prefer prod_1_1
            @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1")
            @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1") < 1e-09
        end


        #=
        TSOActions::commitments are supposed to only be indicated when we reach a unit's DMO.
           DMO
            |                  no tso launched here   market    market
        unit 1 : ON                                   ON        ON
        unit 2 : ON                                   OFF       ON       => market_2 restarted unit 2 after DMO!

        #TODO : possible Solution : markets should reset TSOActions::commitments
        if upcoming step is a bilevelTSO, it will know wether to use market or tso schedule as reference and it does not need TSOActions
        if upcoming step is a TSO, it won't use TSOActions
        if upcoming step is a market, it will need the limitations/impositions (may imply commitments)
        =#
        @testset "issue_with_tso_actions_allowing_to_restart_units_after_dmo" begin
            #TODO
        end

    end

end
