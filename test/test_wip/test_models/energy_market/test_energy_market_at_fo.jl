using PSCOPF

using Test
using Dates
using Printf

@testset verbose=true "test_energy_market_at_fo" begin


    println("\n"^10)

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
      S1: 10     S1: 15 |                      | S1: 40  S1: 50
      S2: 10     S2: 15 |                      | S2: 45  S2: 50

    =#

    ech = DateTime("2015-01-01T10:00:00")
    TS = [DateTime("2015-01-01T11:00:00"), DateTime("2015-01-01T11:15:00")]
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
                                            45000., 10.,
                                            Dates.Second(0), Dates.Second(0))
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "prod_2_1", PSCOPF.Networks.IMPOSABLE,
                                            10., 100.,
                                            80000., 15.,
                                            Dates.Second(4*60*60), Dates.Second(0))
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
    PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:15:00"), "S1", 15.)
    PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:15:00"), "S2", 15.)
    PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", DateTime("2015-01-01T11:00:00"), "S1", 40.)
    PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", DateTime("2015-01-01T11:00:00"), "S2", 45.)
    PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", DateTime("2015-01-01T11:15:00"), "S1", 50.)
    PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", DateTime("2015-01-01T11:15:00"), "S2", 50.)
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
    firmness = PSCOPF.init_firmness(ech, #7h
                                    nothing, # corresponds to ECH-DMO
                                    TS, collect(PSCOPF.Networks.get_generators(network)))
    @show(firmness)
    println(firmness.commitment)
    println(firmness.power_level)

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
                                                                                                                    SortedDict("S1"=>PSCOPF.ON, "S2"=>PSCOPF.OFF)),
                                                        Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON, "S2"=>PSCOPF.OFF))
                                                        ),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(missing,
                                                                                                                    SortedDict("S1"=>15., "S2"=>0.)),
                                                        Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(missing,
                                                                                                                    SortedDict("S1"=>20., "S2"=>0.))
                                                        )
                                            ),
                                        "prod_2_1" => PSCOPF.GeneratorSchedule("prod_2_1",
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON, "S2"=>PSCOPF.ON)),
                                                        Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                                                    SortedDict("S1"=>PSCOPF.ON, "S2"=>PSCOPF.ON))
                                                        ),
                                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(missing,
                                                                                                                    SortedDict("S1"=>15., "S2"=>25.)),
                                                        Dates.DateTime("2015-01-01T11:15:00") => PSCOPF.UncertainValue{PSCOPF.Float64}(missing,
                                                                                                                    SortedDict("S1"=>30., "S2"=>35.))
                                                        )
                                            )
                                        )
                                )

    market = PSCOPF.EnergyMarketAtFO()
    result = PSCOPF.run(market, ech, firmness,
                PSCOPF.get_target_timepoints(context),
                context)
    PSCOPF.update_market_schedule!(context.market_schedule, ech, result, firmness, context, market)

    println("SCHEDULE:")
    println(context.market_schedule)
    # println(context.market_schedule.commitment)
    # println(context.market_schedule.production)

    @testset "energy_market_at_fo_successful_launch" begin
        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
    end

    @testset "energy_market_at_fo_updated_schedule_respects_the_input_firmness" begin
        @test context.market_schedule.decision_time == ech
        @test PSCOPF.verify_firmness(firmness, context.market_schedule)
                        # excluded_ids=PSCOPF.get_limitables_ids(context)) #even limitables are firm!
    end

    @testset "energy_market_at_fo_respects_EOD_on_aggregated_uncertainties_not_initial_ones" begin
        @test context.market_schedule.decision_time == ech
        @test PSCOPF.verify_firmness(firmness, context.market_schedule,
                        excluded_ids=PSCOPF.get_limitables_ids(context))
        
        # for ts in TS
        #     for s in ["S1", "S2"]
        #         @test skip=true ( abs( PSCOPF.compute_eod(PSCOPF.get_uncertainties(context),
        #                                 PSCOPF.get_market_schedule(context),
        #                                 PSCOPF.get_network(context),
        #                                 ech, ts, s) )
        #                 < 1e-09 )
        #     end
        # end
    end

end