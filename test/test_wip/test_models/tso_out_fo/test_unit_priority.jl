using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_tso_unit_priority" begin

    #=
    TSOOutFO tries to deviate the least from the reference market schedule.
    Then, while respecting this deviation, chooses the cheapest units.

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
    (pilotable) prod_1_1|
    Pmin=0, Pmax=100    |
    Csta=0, Cprop=10    |
                        |
    (pilotable) prod_1_2|
     Pmin=0, Pmax=100   |
     Csta=0, Cprop=15   |
                        |
    =#
    @testset "tso_deviates_the_least_from_market" begin
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
                                                0., 10.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.PILOTABLE,
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


        @testset "tso_follows_market_even_if_its_expensive" begin
            #=
            Market uses the more expensive unit prod_1_2
            =#
            context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                            generators_init_state,
                                            uncertainties, nothing)
            context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T10:45:00"), SortedDict(
                    "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                        SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                        SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                SortedDict("S1"=>20.)))
                        ),
                    "wind_1_2" => PSCOPF.GeneratorSchedule("wind_1_2",
                        SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                        SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                SortedDict("S1"=>25.)))
                    ),
                    "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                        SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                        SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                SortedDict("S1"=>0.)))
                    ),
                    "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                        SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                        SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                SortedDict("S1"=>10.)))
                    ),
                    )
            )

            tso = PSCOPF.TSOOutFO()
            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)
            PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

            @test value(result.objective_model.deltas) < 1e-09 # followed the market
            @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09

            @test 20. ≈ PSCOPF.get_prod_value(context.tso_schedule, "wind_1_1", TS[1], "S1")
            @test 25. ≈ PSCOPF.get_prod_value(context.tso_schedule, "wind_1_2", TS[1], "S1")
            @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
            @test 10. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_2", TS[1], "S1")

            # pmin = 0 for prod_1_1 & prod_2_1
            @test ismissing( PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1") )
            @test ismissing( PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_2", TS[1], "S1") )
        end

        @testset "tso_follows_market_while_choosing_the_cheapest" begin
            #=
            Market uses the more expensive unit prod_1_2
            5MW are missing => To respect EOD, TSO will increase prod by 5
            => deviation from market
            TSO will use prod_1_1 & prod_1_2 cause that is cheaper
            =#
            context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                            generators_init_state,
                                            uncertainties, nothing)
            context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T10:45:00"), SortedDict(
                    "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                        SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                        SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                SortedDict("S1"=>20.)))
                        ),
                    "wind_1_2" => PSCOPF.GeneratorSchedule("wind_1_2",
                        SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                        SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                SortedDict("S1"=>25.)))
                    ),
                    "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                        SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                        SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                SortedDict("S1"=>0.)))
                    ),
                    "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                        SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                        SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                                SortedDict("S1"=>5.)))
                    ),
                    )
            )

            tso = PSCOPF.TSOOutFO()
            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)
            PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

            @test 5. ≈ value(result.objective_model.deltas)
            @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09

            @test 20. ≈ PSCOPF.get_prod_value(context.tso_schedule, "wind_1_1", TS[1], "S1")
            @test 25. ≈ PSCOPF.get_prod_value(context.tso_schedule, "wind_1_2", TS[1], "S1")
            @test 5. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
            @test 5. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_2", TS[1], "S1")

            # pmin = 0 for prod_1_1 & prod_2_1
            @test ismissing( PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1") )
            @test ismissing( PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_2", TS[1], "S1") )
        end

        @testset "tso_empty_market_schedule" begin
            #=
            If market_schedule is empty
            consider that reference is 0.
            Deviate the least from market (not important in this case since cutting conso is highly penalized)
            Choose cheapest alternative
            NOTE : unlike market, limitables with high Cprop will be chosen first (cause we pay the non-usage ie capping)
            =#
            context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                            generators_init_state,
                                            uncertainties, nothing)

            tso = PSCOPF.TSOOutFO()
            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)
            PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

            @test 55. ≈ value(result.objective_model.deltas)
            @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09

            @test 20. ≈ PSCOPF.get_prod_value(context.tso_schedule, "wind_1_1", TS[1], "S1") #Cprop=150 : Highlu penalized if not used
            @test 25. ≈ PSCOPF.get_prod_value(context.tso_schedule, "wind_1_2", TS[1], "S1") #Cprop=1
            @test 10. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") #Cprop=10
            @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_2", TS[1], "S1") < 1e-09 #Cprop=15

            # pmin = 0 for prod_1_1 & prod_2_1
            @test ismissing( PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1") )
            @test ismissing( PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_2", TS[1], "S1") )
        end

    end


    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load_2
    Pmin=0, Pmax=100    | S1: 55
    Csta=0, Cprop=1     |
      S1: 45            |
                        |
    (pilotable) prod_1_1|
    Pmin=20, Pmax=100   |
    Csta=0, Cprop=10    |
                        |
    =#
    @testset "tso_respects_pmin" begin
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

        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 45.)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
        # firmness
        firmness = PSCOPF.Firmness(
                    SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                            ),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
                                "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                    )
        # initial generators state
        generators_init_state = SortedDict(
            "prod_1_1" => PSCOPF.OFF,
        )

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), ech, SortedDict(
            "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                SortedDict(),
                SortedDict( TS[1] => PSCOPF.UncertainValue{Float64}(missing,
                                                                    SortedDict("S1"=>45.)))
            ),
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(TS[1] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                SortedDict("S1"=>PSCOPF.ON))),
                SortedDict(TS[1] => PSCOPF.UncertainValue{Float64}(missing,
                                                                    SortedDict("S1"=>10.))) # does not respect Pmin=20
                ),
            )
        )
        tso = PSCOPF.TSOOutFO()
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

        @test 20. ≈ value(result.objective_model.deltas)
        @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09

        @test 35. ≈ PSCOPF.get_prod_value(context.tso_schedule, "wind_1_1", TS[1], "S1")
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test 20. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1")

        @test value(result.objective_model.start_cost) < 1e-09 # prod_1_1 started by the market
        @test value(result.objective_model.prop_cost) ≈ (
              ((45. - 35.) * 1 + 20. * 10.)
        )
    end

end
