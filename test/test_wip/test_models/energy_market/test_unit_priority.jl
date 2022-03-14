using PSCOPF

using Test
using Dates
using JuMP

@testset verbose=true "test_energy_market_unit_priority" begin


    #=
    By default, Energy markets picks Limitable units first. Then, the cheapest units.

    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load_2
    Pmin=0, Pmax=100    | S1: 55
    Csta=0, Cprop=150   |
      S1: 20            |
                        |
    (limitable) wind_1_2|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |
      S1: 25            |
                        |
    (imposable) prod_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=10    |
                        |
    (imposable) prod_1_2|
     Pmin=0, Pmax=100   |
     Csta=0, Cprop=15   |
                        |
    =#
    @testset "energy_market_picks_renewables_first" begin
        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T07:00:00")
        network = PSCOPF.Networks.Network()
        # Buses
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 150.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_2", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                0., 100.,
                                                0., 10.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.IMPOSABLE,
                                                0., 100.,
                                                0., 15.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_2", DateTime("2015-01-01T11:00:00"), "S1", 25.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict{String, SortedDict{Dates.DateTime, PSCOPF.DecisionFirmness} }(),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "wind_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                    )
        # initial generators state : No need because all pmin=0 => ON by default
        generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)
        market = PSCOPF.EnergyMarket()
        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        @test 25. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_2", TS[1], "S1")
        @test 10. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1") < 1e-09
        # pmin = 0 for prod_1_1 & prod_2_1
        @test ismissing( PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1") )
        @test ismissing( PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1") )
    end

    #=
    If force_limitables_to_uncertainty is False,
      limitables are no longer chosen first but
      units are entirely chosen economically

    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load_2
    Pmin=0, Pmax=100    | S1: 55
    Csta=0, Cprop=150   |
      S1: 20            |
                        |
    (limitable) wind_1_2|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |
      S1: 25            |
                        |
    (imposable) prod_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=15    |
                        |
    (imposable) prod_1_2|
     Pmin=0, Pmax=100   |
     Csta=0, Cprop=10   |
                        |
    =#
    @testset "energy_market_picks_units_by_cheapest" begin
        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T07:00:00")
        network = PSCOPF.Networks.Network()
        # Buses
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 150.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_2", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                0., 100.,
                                                0., 15.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.IMPOSABLE,
                                                0., 100.,
                                                0., 10.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_2", DateTime("2015-01-01T11:00:00"), "S1", 25.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict{String, SortedDict{Dates.DateTime, PSCOPF.DecisionFirmness} }(),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "wind_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                    )
        # initial generators state : No need because all pmin=0 => ON by default
        generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)

        market = PSCOPF.EnergyMarket()
        # Change default configs
        market.configs.force_limitables_to_uncertainty = false

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 25. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_2", TS[1], "S1")
        @test 30. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1") < 1e-09
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09

        # pmin = 0 for prod_1_1 & prod_2_1
        @test ismissing( PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1") )
        @test ismissing( PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1") )
    end

    #=
    TS: [11h]
    S: [S1]
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |(limitable) wind_2_1
    Pmin=0, Pmax=100    |                      |Pmin=0, Pmax=100
    Csta=0, Cprop=150   |                      |Csta=0, Cprop=1
      S1: 20            |----------------------|  S1: 25
                        |         500          |
                        |                      |
                        |                      |
    (imposable) prod_1_1|                      |(imposable) prod_2_1
    Pmin=20, Pmax=100   |                      | Pmin=5, Pmax=100
    Csta=10k, Cprop=10  |                      | Csta=10k, Cprop=15
                        |                      |
                        |                      |
                load_1  |                      |load_2
                 S1: 15 |                      | S1: 40

    =#
    #=
    In S1:
      load = 55, wind=45 => missing 10
      prod_1_1 has a pmin=20 => we produce 20 costing 200 (20MW*10)
                                + we cap 10MW of wind (which here we paid for cause Cprop(wind)=1)
      prod_1_2 has a pmin=5 => we produce 10 costing 150 (10MW*15)
    => use prod_1_2
    In S2:
      load = 60, wind=45 => missing 15
      prod_1_1 has a pmin=20 => we produce 20 costing 200 (20MW*10)
                                + we cap 5MW of wind (which here we paid for cause Cprop(wind)=1)
      prod_1_2 has a pmin=5 => we produce 15 costing 225 (15MW*15)
    => use prod_1_1
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load_2
    Pmin=0, Pmax=100    | S1: 55
    Csta=0, Cprop=1     | S2: 60
      S1: 45            |
      S2: 45            |
                        |
    (imposable) prod_1_1|
    Pmin=20, Pmax=100   |
    Csta=0, Cprop=10    |
                        |
    (imposable) prod_1_2|
     Pmin=5, Pmax=100   |
     Csta=0, Cprop=15   |
                        |
    =#
    @testset "energy_market_picks_cheapest_respecting_pmin_and_capping" begin
        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T07:00:00")
        network = PSCOPF.Networks.Network()
        # Buses
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Imposables : have a Pmin but no start cost
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                20., 100.,
                                                0., 10.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.IMPOSABLE,
                                                5., 100.,
                                                0., 15.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 45.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 45.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            ),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                    )
        # initial generators state
        generators_init_state = SortedDict(
            "prod_1_1" => PSCOPF.ON,
            "prod_1_2" => PSCOPF.ON
        )

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)
        market = PSCOPF.EnergyMarket()
        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

        #S1
        @test 45. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09 #cheapest but pmin=20
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test 10. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test value(result.limitable_model.p_capping[TS[1], "S1"]) < 1e-09

        #S2
        @test 45. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S2")
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S2")
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S2")
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S2")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S2") < 1e-09
        @test 5. ≈ value(result.limitable_model.p_capping[TS[1], "S2"])

        @test value(result.objective_model.start_cost) < 1e-09
        @test value(result.objective_model.prop_cost) ≈ (
              (45. * 1 + 0. * 10. + 10. * 15) #S1
            + (45. * 1 + 20. * 10. + 0. * 15) #S2
        )
    end

end
