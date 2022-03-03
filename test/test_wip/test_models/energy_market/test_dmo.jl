using PSCOPF

using Test
using Dates

@testset verbose=true "test_energy_market_dmo" begin

    #=
    TS: [11h]
    S: [S1]
                        bus 1                   bus 2
                        |                      |
    (limitable) wind_1_1|       "1_2"          |
    Pmin=0, Pmax=100    |                      |
    Csta=0, Cprop=1     |                      |
      S1: 20            |----------------------|
                        |         35           |
                        |                      |
                        |                      |
    (imposable) prod_1_1|                      |(imposable) prod_2_1
    Pmin=10, Pmax=100   |                      | Pmin=10, Pmax=100
    Csta=0, Cprop=10    |                      | Csta=0, Cprop=15
    DMO => 8h           |                      | DMO => 10h30
                        |                      |
                load_1  |                      |load_2
                 S1: 15 |                      | S1: 40
                        |                      |
    =#

    TS = [DateTime("2015-01-01T11:00:00")]
    network = PSCOPF.Networks.Network()
    # Buses
    PSCOPF.Networks.add_new_bus!(network, "bus_1")
    PSCOPF.Networks.add_new_bus!(network, "bus_2")
    # Branches
    PSCOPF.Networks.add_new_branch!(network, "branch_1_2", 35.);
    # PTDF
    PSCOPF.Networks.add_ptdf_elt!(network, "branch_1_2", "bus_1", 0.5)
    PSCOPF.Networks.add_ptdf_elt!(network, "branch_1_2", "bus_2", -0.5)
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
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "prod_2_1", PSCOPF.Networks.IMPOSABLE,
                                            10., 100.,
                                            0., 15.,
                                            Dates.Second(30*60), Dates.Second(0))
    # Uncertainties
    uncertainties = PSCOPF.Uncertainties()
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T07:00:00"), "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T07:00:00"), "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 15.)
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T07:00:00"), "bus_2", DateTime("2015-01-01T11:00:00"), "S1", 40.)
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T09:00:00"), "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T09:00:00"), "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 15.)
    PSCOPF.add_uncertainty!(uncertainties, DateTime("2015-01-01T09:00:00"), "bus_2", DateTime("2015-01-01T11:00:00"), "S1", 40.)
    # initial generators state : need to pay starting cost at TS[1]
    generators_init_state = SortedDict(
        "prod_1_1" => PSCOPF.OFF,
        "prod_2_1" => PSCOPF.OFF
    )

    # before DMO + still have an ech to decide on => commitment firmness is FRE
    @testset "energy_market_can_start_unit_when_commitment_firmness_is_FREE" begin
        ech = DateTime("2015-01-01T07:00:00")

        #For some reason, Initial schedule starts prod_2_1 (prod_1_1 is off) : decisions are not definitive
        initial_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
            "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                # SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                #                                                                          SortedDict("S1"=>PSCOPF.ON))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>20.)))
                ),
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                                                        SortedDict("S1"=>PSCOPF.OFF))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>0.)))
                ),
            "prod_2_1" => PSCOPF.GeneratorSchedule("prod_2_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                                                        SortedDict("S1"=>PSCOPF.ON))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>35.)))
                )
            )
        )

        # firmness
        # firmness = PSCOPF.Firmness(
        #         SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
        #                     "prod_2_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), ),
        #         SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
        #                     "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
        #                     "prod_2_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
        #         )
        firmness = PSCOPF.compute_firmness(ech, #7h
                                        DateTime("2015-01-01T08:00:00"), # corresponds to ECH-DMO
                                        TS, collect(PSCOPF.Networks.get_generators(network)))

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)

        # prod_1_1 is OFF (but value is not definitive)
        context.market_schedule = initial_schedule

        market = PSCOPF.EnergyMarket()
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
        # we shut down prod_2_1
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_2_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_2_1", TS[1], "S1") < 1e-09
    end

    # after DMO => commitment firmness is DECIDED
    @testset "energy_market_cannot_start_unit_when_commitment_firmness_is_DECIDED" begin
        ech = DateTime("2015-01-01T09:00:00")

        #For some reason, Initial schedule starts prod_2_1 (prod_1_1 is off) : decisions are not definitive
        initial_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
            "wind_1_1" => PSCOPF.GeneratorSchedule("wind_1_1",
                SortedDict{Dates.DateTime, PSCOPF.UncertainValue{PSCOPF.GeneratorState}}(),
                # SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                #                                                                         SortedDict("S1"=>PSCOPF.ON))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>20.)))
                ),
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                        SortedDict("S1"=>PSCOPF.OFF))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>0.)))
                ),
            "prod_2_1" => PSCOPF.GeneratorSchedule("prod_2_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                                                        SortedDict("S1"=>PSCOPF.ON))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>35.)))
                )
            )
        )

        # firmness : prod_1_1 is already decided (DMO > ECH)
        # firmness = PSCOPF.Firmness(
        #         SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
        #                     "prod_2_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), ),
        #         SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
        #                     "prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE),
        #                     "prod_2_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
        #         )
        firmness = PSCOPF.compute_firmness(ech, #9h
                                        DateTime("2015-01-01T10:30:00"), # corresponds to ECH-DMO
                                        TS, collect(PSCOPF.Networks.get_generators(network)))

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                        generators_init_state,
                                        uncertainties, nothing)

        # prod_1_1 is OFF (but value is not definitive)
        context.market_schedule = initial_schedule

        market = PSCOPF.EnergyMarket()
        result = PSCOPF.run(market, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_market_schedule!(context, ech, result, firmness, market)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        @test 20. ≈ PSCOPF.get_prod_value(context.market_schedule, "wind_1_1", TS[1], "S1")
        # we could not start prod_1_1 due to DMO
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.market_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.market_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # we use prod_2_1
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.market_schedule, "prod_2_1", TS[1], "S1")
        @test 35. ≈ PSCOPF.get_prod_value(context.market_schedule, "prod_2_1", TS[1], "S1")
    end

end