using PSCOPF

using Test
using Dates
using JuMP

@testset verbose=true "test_energy_market_slacks" begin

    #=
    If available power for a limitable exceeds consumption,
      the limitable says it produces the available power level
      but a variable indicates that we needed to cap some of the
      available power.
    The capping variable is global (delocalised in space but has
      a per timestep and per scenario value)

    TS: [11h]
    S: [S1]
                      bus 1
                        |
    (limitable) wind_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |     load_1
      S1: 20            | S1: 15
      S2: 25            | S2: 25
                        |
    =#
    @testset "energy_market_capping_limitable_power" begin
        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T07:00:00")
        network = PSCOPF.Networks.Network()
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 25.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 15.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 25.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict{String, SortedDict{Dates.DateTime, PSCOPF.DecisionFirmness} }(),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
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
        # Limitable produces to the available level
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        @test 25. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S2")
        # Limitable was capped when prod > load (ie. S1):
        @test 5. ≈ value(result.limitable_model.p_capping[TS[1], "S1"])
        # Limitable was not capped when prod <= load (ie. S2):
        @test value(result.limitable_model.p_capping[TS[1], "S2"]) < 1e-09
        # No penalty but we do pay for capped power
        #(otherwise we need a per unit variable for capping to localise and reduce the unpaid costs)
        @test value(result.objective_model.penalty) < 1e-09
        @test value(result.objective_model.start_cost) < 1e-09
        @test (20. + 25. ) ≈ value(result.objective_model.prop_cost)
    end

    #=
    A paramter allows not obliging limitables to produce at their available capacities.
    In this case, cheapest limitable will be used, and extra available power will automatically
      get capped simply by setting the injection level of each unit freely.
    So, the capping variable should have no effect in this case.

    TS: [11h]
    S: [S1]
                      bus 1
                        |
    (limitable) wind_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=1     |     load_1
      S1: 20            | S1: 15
      S2: 25            | S2: 25
                        |
    =#
    @testset "energy_market_does_not_need_capping_if_not_forced_limitables" begin
        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T07:00:00")
        network = PSCOPF.Networks.Network()
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 25.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 15.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 25.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict{String, SortedDict{Dates.DateTime, PSCOPF.DecisionFirmness} }(),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                    )
        # initial generators state : No need because all pmin=0 => ON by default
        generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)
        market = PSCOPF.EnergyMarket()
        market.configs.force_limitables = false
        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # Limitable can produce less than the available level
        @test 15. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1") < 20.
        @test 25. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S2")
        # Limitable didn't need capping
        @test value(result.limitable_model.p_capping[TS[1], "S1"]) < 1e-09
        @test value(result.limitable_model.p_capping[TS[1], "S2"]) < 1e-09
        # No penalty and we only pay for what we used
        @test value(result.objective_model.penalty) < 1e-09
        @test value(result.objective_model.start_cost) < 1e-09
        @test (15. + 25. ) ≈ value(result.objective_model.prop_cost) < (20. + 25.)
    end

    #=
    It is possible to cut consumption.
    This variable should can be used in two cases :
    1- due to EOD constraints : we don't have enough production capacity (illustrated in S1)
    2- due to Pmin constraints : we don't have enough demand to start a unit (illustrated in S2)

    TS: [11h]
    S: [S1]
                        bus 1
                         |
    (imposable) prod_1_1 |    load_1
    Pmin=20, Pmax=100    |  S1: 150
    Csta=100k, Cprop=1   |  S2: 15
                         |  S3: 25
    =#
    @testset "energy_market_cuts_consumption_due_to_pmin" begin
        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T07:00:00")
        network = PSCOPF.Networks.Network()
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                20., 100.,
                                                100000., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 150.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 15.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S3", 25.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),),
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                    )
        # initial generators state :
        generators_init_state = SortedDict("prod_1_1" => PSCOPF.OFF)

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)
        market = PSCOPF.EnergyMarket()
        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # TODO a status to indicate using slacks for feasibility
        @test_broken PSCOPF.get_status(result) != PSCOPF.pscopf_OPTIMAL
        # S1 : prod_capacity < load => cannot satisfy demand
        @test 100. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test 50. ≈ value(result.slack_model.p_cut_conso[TS[1], "S1"])
        # S2 : load < pmin => cannot start the unit for such load
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S2") < 1e-09
        @test 15. ≈ value(result.slack_model.p_cut_conso[TS[1], "S2"])
        # S3 : works fine
        @test 25. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S3")
        @test value(result.slack_model.p_cut_conso[TS[1], "S3"]) < 1e-09
        # penalize cutting consumption
        @test 1e7 ≈ market.configs.cut_conso_penalty
        @test (50. * 1e7 + 15. * 1e7 + 0. ) ≈ value(result.objective_model.penalty)
        @test (1e5 + 0. + 1e5) ≈ value(result.objective_model.start_cost)
        @test (100. + 0. + 25. ) ≈ value(result.objective_model.prop_cost)
    end

    #=
    Cutting consumption is done through penalization.
    Careful for the chosen penalty cost with respect to production costs
    Here, the unit starting cost is higher than the penalty

    TS: [11h]
    S: [S1]
                        bus 1
                         |
    (imposable) prod_1_1 |    load_1
    Pmin=20, Pmax=100    |  S1: 25
    Csta=100k, Cprop=1   |
    =#
    @testset "energy_market_careful_for_cuts_consumption_penalty" begin
        penalty = 1e3

        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T07:00:00")
        network = PSCOPF.Networks.Network()
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                20., 100.,
                                                100000., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 25.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),),
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                    )
        # initial generators state :
        generators_init_state = SortedDict("prod_1_1" => PSCOPF.OFF)

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)
        market = PSCOPF.EnergyMarket()
        market.configs.cut_conso_penalty = penalty
        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)
        
        # Desired Solution
        @test_broken PSCOPF.get_status(result) != PSCOPF.pscopf_OPTIMAL
        @test_broken 25. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test_broken value(result.slack_model.p_cut_conso[TS[1], "S1"]) < 1e-09
        @test_broken value(result.objective_model.penalty) < 1e-09

        # retrieved solution
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        @test 25. ≈ value(result.slack_model.p_cut_conso[TS[1], "S1"])
        @test (25. * 1e3) ≈ value(result.objective_model.penalty)

    end


    #=
    TS: [11h]
    S: [S1]
                        bus 1
                         |
    (limitable) wind_1_1 |    load_1
    Pmin=0, Pmax=100     |  S1: 15
    Csta=0, Cprop=0.     |  S2: 25
         S1 : 10         |
         S1 : 10         |
                         |
    (imposable) prod_1_1 |
    Pmin=20, Pmax=100    |
    Csta=100k, Cprop=100 |
    =#
    @testset "energy_market_capping_limitables_due_to_imposable_pmin" begin
        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T07:00:00")
        network = PSCOPF.Networks.Network()
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                20., 100.,
                                                100000., 100.,
                                                Dates.Second(0), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 10.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 10.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 15.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 25.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                               "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                    )
        # initial generators state :
        generators_init_state = SortedDict("prod_1_1" => PSCOPF.OFF)

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)
        market = PSCOPF.EnergyMarket()
        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # TODO a status to indicate using slacks for feasibility because of scenario S1
        @test_broken PSCOPF.get_status(result) != PSCOPF.pscopf_OPTIMAL

        # In S1 : Load=15, wind provides 10 => still missing 5 but pmin=20
        # => reduce consumption by 5
        @test 10. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        @test value(result.limitable_model.p_capping[TS[1], "S1"]) < 1e-09
        @test 5. ≈ value(result.slack_model.p_cut_conso[TS[1], "S1"])

        # In S2 : Load=25, wind provides 10 => still missing 15 but pmin=20
        # imposable produces 20 => 5 extra prod (20+10 - 25) => reduce wind by 5.
        @test 10. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S2")
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S2")
        @test 5. ≈ value(result.limitable_model.p_capping[TS[1], "S2"])
        @test value(result.slack_model.p_cut_conso[TS[1], "S2"]) < 1e-09
    end


    #TODO : illustrate slack effect

end
