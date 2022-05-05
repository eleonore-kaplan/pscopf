using PSCOPF

using Test
using JuMP
using Dates
using DataStructures
using Printf

@testset "test_capping" begin

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |     load_1
        S1: 60          | S1: 80
                        |
    (limitable) wind_1_2|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=5     |
        S1: 40          |
                        |
    =#
    function create_instance(ech, TS)
        network = PSCOPF.Networks.Network()
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_2", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 5.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 60.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_2", DateTime("2015-01-01T11:00:00"), "S1", 40.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 80.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict{String, SortedDict{Dates.DateTime, PSCOPF.DecisionFirmness} }(),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "wind_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)
                    ),
                    )
        # initial generators state : No need because all pmin=0 => ON by default
        generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)

        return context, firmness
    end

    ech = DateTime("2015-01-01T07:00:00")
    TS = [DateTime("2015-01-01T11:00:00")]


    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |     load_1
        S1: 60          | S1: 80
                        |
    (limitable) wind_1_2|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=5     |
        S1: 40          |
                        |

    When EnergyMarketConfigs::force_limitables is true (Default behaviour),
    The limitables are supposed to produce to their highest possible level
    If needed, a global capping is applied to ensure EOD.
    The capping needs to be dispatched but this is not done by the market model. It is done during schedule update.

    In this testcase, limitable units can provide 60MW + 40MW
    So, available limitable production is 100MW but we only need 80MW
    Each of the units is set to it's available prod i.e.
    P_injected[wind_1_1] = 60
    P_injected[wind_1_2] = 40
    and we need to cap 20MW
    =#
    @testset "energy_market_capping_when_enr_are_imposed_to_uncertainties" begin
        context, firmness = create_instance(ech, TS)

        market = PSCOPF.EnergyMarket()
        @test market.configs.force_limitables

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        @test 60. ≈ value(result.limitable_model.p_injected["wind_1_1", TS[1], "S1"])
        @test 40. ≈ value(result.limitable_model.p_injected["wind_1_2", TS[1], "S1"])
        @test 20. ≈ value(result.limitable_model.p_capping[TS[1], "S1"])

        @testset "schedule_update" begin
            PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

            @test 60. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
            @test 40. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_2", TS[1], "S1")

            @test (60. / 100. * 20. ) ≈ PSCOPF.get_capping(context.market_schedule, "wind_1_1", TS[1], "S1")
            @test (40. / 100. * 20. ) ≈ PSCOPF.get_capping(context.market_schedule, "wind_1_2", TS[1], "S1")

        end

    end

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |     load_1
        S1: 60          | S1: 80
                        |
    (limitable) wind_1_2|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=5     |
        S1: 40          |
                        |

    When EnergyMarketConfigs::force_limitables is false,
    The limitables levels are chosen according to their proportional cost
    If units are set to a level lower than their available level, a global capping is reported.

    The capping per unit is decided by the market in this case.

    In this testcase, limitable units can provide 60MW + 40MW
    So, available limitable production is 100MW but we only need 80MW
    Unit wind_1_1 is supposed to be cheaper
    So it produces all it can : 60MW
    unit wind_1_2 produces the rest : 20MW
    and we need to cap 20MW from wind_1_2
    =#
    @testset "energy_market_capping_when_enr_are_free" begin
        context, firmness = create_instance(ech, TS)

        market = PSCOPF.EnergyMarket(PSCOPF.EnergyMarketConfigs(force_limitables=false))

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        @test 60. ≈ value(result.limitable_model.p_injected["wind_1_1", TS[1], "S1"])
        @test 20. ≈ value(result.limitable_model.p_injected["wind_1_2", TS[1], "S1"])
        @test 20. ≈ value(result.limitable_model.p_capping[TS[1], "S1"])

        @testset "schedule_update" begin
            PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

            @test 60. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
            @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_2", TS[1], "S1")

            @test PSCOPF.get_capping(context.market_schedule, "wind_1_1", TS[1], "S1") < 1e-09
            @test 20. ≈ PSCOPF.get_capping(context.market_schedule, "wind_1_2", TS[1], "S1")

        end

    end

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |     load_1
        S1: 60          | S1: 80
        Limited to 45   |
                        |
    (limitable) wind_1_2|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=5     |
        S1: 40          |
                        |

    when CONSIDER_TSOACTIONS_LIMITATIONS is true (like in the BalanceMarket),
    Market respects limitations.
    Even if force_limitables is true, the forced level will be equal to the limit.
    but capping is global.
    The capping is uniformly distributed => it does not show the capping due to limitation.

    wind_1_1 can produce up to 60 MW
    but, for some reason, we have limited its production to 45 MW
    => wind_1_1 will be set to its max allowable production level : 45 MW

    wind_1_2 is set to its allowable production level : 40 MW

    => limitables produce 85 MW, while demand is 80MW
    => we will need to cap an extra 5 MW

    Solution :
        wind_1_1 injected : 45
        wind_1_2 injected : 40
        capping : 20 (15 due to limit, 5 for EOD)
        lol : 0
    =#
    @testset "energy_market_capping_when_enr_are_imposed_to_uncertainties_and_there_is_a_limit" begin
        context, firmness = create_instance(ech, TS)

        market = PSCOPF.EnergyMarket(PSCOPF.EnergyMarketConfigs(CONSIDER_TSOACTIONS_LIMITATIONS=true))

        PSCOPF.set_limitation_value!(context.tso_actions, "wind_1_1", TS[1], 45.)

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        @test 45. ≈ value(result.limitable_model.p_injected["wind_1_1", TS[1], "S1"])
        @test 40. ≈ value(result.limitable_model.p_injected["wind_1_2", TS[1], "S1"])
        @test 20. ≈ value(result.limitable_model.p_capping[TS[1], "S1"]) #due to limitation

        @test value(result.slack_model.p_cut_conso[TS[1], "S1"]) < 1e-09

        @testset "schedule_update" begin
            PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

            @test 45. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
            @test 40. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_2", TS[1], "S1")

            @test (60. / 100. * 20. ) ≈ PSCOPF.get_capping(context.market_schedule, "wind_1_1", TS[1], "S1")
            @test (40. / 100. * 20. ) ≈ PSCOPF.get_capping(context.market_schedule, "wind_1_2", TS[1], "S1")

        end

    end

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |     load_1
        S1: 60          | S1: 80
        Limited to 30   |
                        |
    (limitable) wind_1_2|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=5     |
        S1: 40          |
                        |

    EnergyMarketConfigs::force_limitables is true,
    when CONSIDER_TSOACTIONS_LIMITATIONS is true (like in the BalanceMarket),
    Market respects limitations but capping is global.
    The capping is uniformly distributed => it does not show the capping due to limitation.
    and check that LoL is possible.

    wind_1_1 can produce up to 60 MW
    but, for some reason, we have limited its production to 30 MW
    => wind_1_1 will be set to its max allowable production level : 30 MW

    wind_1_2 is set to its allowable production level : 40 MW

    => limitables produce 70 MW, while demand is 80MW
    => we will need to lose 10 MW of load

    Solution :
        wind_1_1 injected : 30
        wind_1_2 injected : 40
        capping : 30 (due to limit)
        lol : 10
    =#
    @testset "energy_market_capping_when_enr_are_imposed_to_uncertainties_and_there_is_a_limit" begin
        context, firmness = create_instance(ech, TS)
        println("\n===================")

        market = PSCOPF.EnergyMarket(PSCOPF.EnergyMarketConfigs(CONSIDER_TSOACTIONS_LIMITATIONS=true))

        PSCOPF.set_limitation_value!(context.tso_actions, "wind_1_1", TS[1], 30.)

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        @test 30. ≈ value(result.limitable_model.p_injected["wind_1_1", TS[1], "S1"])
        @test 40. ≈ value(result.limitable_model.p_injected["wind_1_2", TS[1], "S1"])
        @test 30. ≈ value(result.limitable_model.p_capping[TS[1], "S1"]) #due to limitation

        @test 10. ≈ value(result.slack_model.p_cut_conso[TS[1], "S1"])

        @testset "schedule_update" begin
            PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

            @test 30. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
            @test 40. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_2", TS[1], "S1")

            @test (60. / 100. * 30. ) ≈ PSCOPF.get_capping(context.market_schedule, "wind_1_1", TS[1], "S1")
            @test (40. / 100. * 30. ) ≈ PSCOPF.get_capping(context.market_schedule, "wind_1_2", TS[1], "S1")

        end


    end

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |     load_1
        S1: 60          | S1: 80
        Limited to 30   |
                        |
    (limitable) wind_1_2|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=5     |
        S1: 40          |
                        |

    EnergyMarketConfigs::force_limitables is false,
    when CONSIDER_TSOACTIONS_LIMITATIONS is true (like in the BalanceMarket),
    Market respects limitations and capping is localized.
    and check that LoL is possible

    wind_1_1 can produce up to 60 MW
    but, for some reason, we have limited its production to 30 MW
    => wind_1_1 will be set to its max allowable production level : 30 MW

    wind_1_2 is set to its allowable production level : 40 MW

    => limitables produce 70 MW, while demand is 80MW
    => we will need to lose 10 MW of load

    Solution :
        wind_1_1 injected : 30
        wind_1_2 injected : 40
        capping : 30 (due to limit)
        lol : 10
    =#
    @testset "energy_market_capping_when_enr_are_free_and_there_is_a_limit" begin
        context, firmness = create_instance(ech, TS)

        market = PSCOPF.EnergyMarket(PSCOPF.EnergyMarketConfigs(force_limitables=false, CONSIDER_TSOACTIONS_LIMITATIONS=true))

        PSCOPF.set_limitation_value!(context.tso_actions, "wind_1_1", TS[1], 30.)

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        @test 30. ≈ value(result.limitable_model.p_injected["wind_1_1", TS[1], "S1"])
        @test 40. ≈ value(result.limitable_model.p_injected["wind_1_2", TS[1], "S1"])
        @test 30. ≈ value(result.limitable_model.p_capping[TS[1], "S1"])

        @testset "schedule_update" begin
            PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

            @test 30. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
            @test 40. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_2", TS[1], "S1")

            @test 30. ≈ PSCOPF.get_capping(context.market_schedule, "wind_1_1", TS[1], "S1")
            @test PSCOPF.get_capping(context.market_schedule, "wind_1_2", TS[1], "S1") < 1e-09

        end


    end

end
