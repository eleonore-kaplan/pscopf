using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_energy_market_unit_priority" begin

    function create_instance_with_expensive_wind()
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
        # Pilotables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.PILOTABLE,
                                                0., 100.,
                                                0., 15.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.PILOTABLE,
                                                0., 100.,
                                                0., 10.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", TS[1], "S1", 20.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_2", TS[1], "S1", 25.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", TS[1], "S1", 55.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict{String, SortedDict{Dates.DateTime, PSCOPF.DecisionFirmness} }(),
                    SortedDict("wind_1_1" => SortedDict(TS[1] => PSCOPF.FREE),
                                "wind_1_2" => SortedDict(TS[1] => PSCOPF.FREE),
                                "prod_1_1" => SortedDict(TS[1] => PSCOPF.FREE),
                                "prod_1_2" => SortedDict(TS[1] => PSCOPF.FREE), )
                    )
        # initial generators state : No need because all pmin=0 => ON by default
        generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)

        return TS, ech, firmness, context
    end


    #=
    By default, Energy markets picks Limitable units first. Then, the cheapest units.

    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load
    Pmin=0, Pmax=100    | S1: 55
    Csta=0, Cprop=150   |
      S1: 20            |
                        |
    (limitable) wind_1_2|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |
      S1: 25            |
                        |
    (pilotable) prod_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=15    |
                        |
    (pilotable) prod_1_2|
     Pmin=0, Pmax=100   |
     Csta=0, Cprop=10   |
                        |

    Demand : 55
    Available limitable power : 45

    The units prod_1_1 and prod_1_2 are cheaper than wind_1_2.

    The market selects the limitable units first.
    So, it uses wind_1_2 before prod_1_1 and prod_1_2 even if their proportional cost is lower.

    => wind_1_1 = 20 and wind_1_2 = 25
    remaining demand : 10MW
    => prod_1_1 = 10 (because prod_1_1 is cheaper than prod_1_2)
    =#
    @testset "energy_market_picks_renewables_first" begin
        TS, ech, firmness, context = create_instance_with_expensive_wind()

        market = PSCOPF.EnergyMarket()

        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        @test 25. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_2", TS[1], "S1")
        @test 10. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # pmin = 0 for prod_1_1 & prod_1_2
        @test ismissing( PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1") )
        @test ismissing( PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S1") )
    end

    #=
    In S1:
      load = 55, wind=45 => missing 10
      prod_1_1 has a pmin=20 => we produce 20 costing 200 (20MW*10)
                                + we cap 10MW of wind
      prod_1_2 has a pmin=5 => we produce 10 costing 150 (10MW*15)
    => use prod_1_2
    In S2:
      load = 60, wind=45 => missing 15
      prod_1_1 has a pmin=20 => we produce 20 costing 200 (20MW*10)
                                + we cap 5MW of wind
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
    (pilotable) prod_1_1|
    Pmin=20, Pmax=100   |
    Csta=0, Cprop=10    |
                        |
    (pilotable) prod_1_2|
     Pmin=5, Pmax=100   |
     Csta=0, Cprop=15   |
                        |
    =#
    @testset "energy_market_may_cap_due_to_pilotables_pmin" begin
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
        # Pilotables : have a Pmin but no start cost
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.PILOTABLE,
                                                20., 100.,
                                                0., 10.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.PILOTABLE,
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
        @test 40. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S2")
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S2")
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S2")
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_2", TS[1], "S2")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_2", TS[1], "S2") < 1e-09
        @test 5. ≈ value(result.limitable_model.p_capping[TS[1], "S2"])

        @test value(result.objective_model.start_cost) < 1e-09
        @test value(result.objective_model.prop_cost) ≈ (
              (0. * 10. + 10. * 15) #S1
            + (20. * 10. + 0. * 15) #S2
        )
    end

end
