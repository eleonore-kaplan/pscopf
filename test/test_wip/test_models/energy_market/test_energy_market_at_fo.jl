using PSCOPF

using .PSCOPFFixtures

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_energy_market_at_fo" begin

    #=
    ECH = 10h
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 20    S1: 15  |----------------------|
      S2: 30    S2: 30  |         35           |
                        |                      |
                        |                      |
    (imposable) prod_1_1|                      |(imposable) prod_2_1
    Pmin=10, Pmax=100   |                      | Pmin=10, Pmax=100
    Csta=45k, Cprop=10  |                      | Csta=80k, Cprop=15
    ON    ON       ON   |                      | ON  ON      ON
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10     S1: 17 |                      | S1: 40  S1: 48
      S2: 10     S2: 13 |                      | S2: 45  S2: 52


    prod_2_1 is started at 10MW in TS1 and 15MW in TS2

    =#
    function create_instance(ech,TS)
        network = PSCOPFFixtures.network_2buses()
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                10., 100.,
                                                45000., 10.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "prod_2_1", PSCOPF.Networks.IMPOSABLE,
                                                10., 100.,
                                                80000., 15.,
                                                Dates.Second(4*60*60), Dates.Second(4*60*60))
        # initial generators state
        generators_init_state = SortedDict(
                        "prod_1_1" => PSCOPF.ON,
                        "prod_2_1" => PSCOPF.ON
                    )
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 30.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:15:00"), "S1", 15.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:15:00"), "S2", 30.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 10.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 10.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:15:00"), "S1", 17.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:15:00"), "S2", 13.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", DateTime("2015-01-01T11:00:00"), "S1", 40.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", DateTime("2015-01-01T11:00:00"), "S2", 45.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", DateTime("2015-01-01T11:15:00"), "S1", 48.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", DateTime("2015-01-01T11:15:00"), "S2", 52.)
        # firmness
        # firmness = PSCOPF.Firmness(
        #             SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE,
        #                                                 Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.TO_DECIDE,),
        #                         "prod_2_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED,
        #                                                 Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.DECIDED,), ),
        #             SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE,
        #                                                 Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.TO_DECIDE,),
        #                         "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE,
        #                                                 Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.TO_DECIDE,),
        #                         "prod_2_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE,
        #                                                 Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.TO_DECIDE,), )
        #             )
        firmness = PSCOPF.compute_firmness(ech, #7h
                                        nothing, # corresponds to ECH-DMO
                                        TS, collect(PSCOPF.Networks.get_generators(network)))

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)

        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T07:00:00"), SortedDict(
                                            "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                                                SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(missing,
                                                                                                                        SortedDict("S1"=>20., "S2"=>30.)),
                                                            Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(missing,
                                                                                                                        SortedDict("S1"=>15., "S2"=>30.))),
                                                ),
                                            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                                                                                        SortedDict("S1"=>PSCOPF.OFF, "S2"=>PSCOPF.OFF)),
                                                            Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                                                                                        SortedDict("S1"=>PSCOPF.OFF, "S2"=>PSCOPF.OFF))
                                                            ),
                                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(missing,
                                                                                                                        SortedDict("S1"=>20., "S2"=>15.)),
                                                            Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(missing,
                                                                                                                        SortedDict("S1"=>35., "S2"=>20.))
                                                            )
                                                ),
                                            "prod_2_1" => PSCOPF.GeneratorSchedule("prod_2_1",
                                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                        SortedDict("S1"=>PSCOPF.ON, "S2"=>PSCOPF.ON)),
                                                            Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                        SortedDict("S1"=>PSCOPF.ON, "S2"=>PSCOPF.ON))
                                                            ),
                                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(10.,
                                                                                                                        SortedDict("S1"=>10., "S2"=>10.)),
                                                            Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(15.,
                                                                                                                        SortedDict("S1"=>15., "S2"=>15.))
                                                            )
                                                )
                                            )
                                    )

        market = PSCOPF.EnergyMarketAtFO()
        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        return context, result
    end

    ech = DateTime("2015-01-01T10:00:00")
    TS = [DateTime("2015-01-01T11:00:00"), DateTime("2015-01-01T11:15:00")]
    context, result = create_instance(ech, TS)

    @testset "energy_market_at_fo_successful_launch" begin
        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
    end

    #=
    EnergyMarketAtFO returns firm decisions
    =#
    @testset "energy_market_at_fo_all_decisions_are_firm" begin
        @test context.market_schedule.decision_time == ech
        for (gen_id,gen_schedule) in context.market_schedule.generator_schedules
            for (ts, uncertain) in gen_schedule.production
                @test PSCOPF.is_definitive(uncertain)
            end
        end
        for (gen_id,gen_schedule) in context.market_schedule.generator_schedules
            for (ts, uncertain) in gen_schedule.commitment
                @test PSCOPF.is_definitive(uncertain)
            end
        end
    end

    #=
    EnergyMarketAtFO operates on an aggregated scenario
    =#
    @testset "energy_market_at_fo_aggregated_scenario" begin
        @test PSCOPF.SCENARIOS_DELIMITER == "_+_"

        expected_s_agg = "S1_+_S2"
        s_agg = PSCOPF.aggregate_scenario_name(context, ech)
        @test s_agg == expected_s_agg
    end

    #=
    EnergyMarketAtFO operates on an aggregated scenario and respects preceding decisions
    preceding decision : prod_2_1 started at 10MW for TS[1]

    The aggregate scenario :
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
        25      22.5    |----------------------|
                        |         35           |
                        |                      |
                        |                      |
    (imposable) prod_1_1|                      |(imposable) prod_2_1
    Pmin=10, Pmax=100   |                      | Pmin=10, Pmax=100
    Csta=45k, Cprop=10  |                      | Csta=80k, Cprop=15
    ON    ON       ON   |                      | ON  ON      ON
                        |                      |
           load(bus_1)  |                      |load(bus_2)
        10      15      |                      |    42.5  50

    =#
    @testset "energy_market_at_fo_production_levels" begin
        s_agg = PSCOPF.aggregate_scenario_name(context, ech)

        @test 25. ≈ value(result.limitable_model.p_injected["wind_1_1", TS[1], s_agg])
        @test 17.5 ≈ value(result.imposable_model.p_injected["prod_1_1", TS[1], s_agg])
        @test 10. ≈ value(result.imposable_model.p_injected["prod_2_1", TS[1], s_agg])
        @test value(result.limitable_model.p_capping[TS[1], s_agg]) < 1e-09
        @test value(result.slack_model.p_cut_conso[TS[1], s_agg]) < 1e-09

        @test 22.5 ≈ value(result.limitable_model.p_injected["wind_1_1", TS[2], s_agg])
        @test 27.5 ≈ value(result.imposable_model.p_injected["prod_1_1", TS[2], s_agg])
        @test 15. ≈ value(result.imposable_model.p_injected["prod_2_1", TS[2], s_agg])
        @test value(result.limitable_model.p_capping[TS[2], s_agg]) < 1e-09
        @test value(result.slack_model.p_cut_conso[TS[2], s_agg]) < 1e-09

        @testset "energy_market_at_fo_respect_preceding_decisions" begin
            #prod_2_1 was already set to 10 for TS1
            @test PSCOPF.ON == PSCOPF.safeget_commitment_value(context.market_schedule, "prod_2_1", TS[1])
            @test 10. ≈ PSCOPF.safeget_prod_value(context.market_schedule, "prod_2_1", TS[1])
            #prod_2_1 was already set to 15 for TS2
            @test PSCOPF.ON == PSCOPF.safeget_commitment_value(context.market_schedule, "prod_2_1", TS[2])
            @test 15. ≈ PSCOPF.safeget_prod_value(context.market_schedule, "prod_2_1", TS[2])
        end
    end

    #=
    EnergyMarketAtFO considers aggregated scenario uncertainties,
    => It does not necessarily respect the EOD of the initial individual scenarios
    If we look at the initial scenarios we can have : overloads, overproductions or balanced scenarios
    =#
    @testset "energy_market_at_fo_does_not_necessarily_respect_EOD_on_initial_scenarios" begin
        s_agg = PSCOPF.aggregate_scenario_name(context, ech)

        #TS[1], "S1" : aggregated scenarios induces an over prodction
        @test 2.5 ≈ PSCOPF.compute_eod(PSCOPF.get_uncertainties(context),
                                        PSCOPF.get_market_schedule(context),
                                        PSCOPF.get_network(context),
                                        ech, TS[1], "S1")
        #TS[1], "S2" : aggregated scenarios induces an over load
        @test -2.5 ≈ PSCOPF.compute_eod(PSCOPF.get_uncertainties(context),
                                        PSCOPF.get_market_schedule(context),
                                        PSCOPF.get_network(context),
                                        ech, TS[1], "S2")
        #TS[2] : initial scenarios are balanced
        @test 1e-09 > PSCOPF.compute_eod(PSCOPF.get_uncertainties(context),
                                        PSCOPF.get_market_schedule(context),
                                        PSCOPF.get_network(context),
                                        ech, TS[2], "S1")
        @test 1e-09 > PSCOPF.compute_eod(PSCOPF.get_uncertainties(context),
                                        PSCOPF.get_market_schedule(context),
                                        PSCOPF.get_network(context),
                                        ech, TS[2], "S2")

        # capping and LoL are defined for the aggregated scenario
        @test value( result.slack_model.p_cut_conso[TS[1], s_agg] ) < 1e-09
        @test value( result.limitable_model.p_capping[TS[1], s_agg] ) < 1e-09
        @test value( result.slack_model.p_cut_conso[TS[2], s_agg] ) < 1e-09
        @test value( result.limitable_model.p_capping[TS[2], s_agg] ) < 1e-09
    end

    #=
    EnergyMarketAtFO satisfies the EOD of the aggregated scenario
    NOTE: If the EOD could not be satisfied, the market might use capping and LoL for the aggregated scenario
    =#
    @testset "energy_market_at_fo_respects_EOD_on_aggregated_uncertainties" begin
        s_agg, agg_uncertainties = PSCOPF.aggregate_scenarios(context, ech)
        agg_uncertainties = PSCOPF.Uncertainties(ech => agg_uncertainties)
        for ts in TS
            @test 1e-09 > abs( PSCOPF.compute_eod(agg_uncertainties,
                                                PSCOPF.get_market_schedule(context),
                                                PSCOPF.get_network(context),
                                                ech, ts, s_agg) )
            @test value( result.slack_model.p_cut_conso[ts, s_agg] ) < 1e-09
            @test value( result.limitable_model.p_capping[ts, s_agg] ) < 1e-09
        end
    end

end