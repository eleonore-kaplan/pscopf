using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_tso_out_fo_dmo" begin

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (imposable) prod_1_1|load
    Pmin=10, Pmax=100   |
    Csta=0, Cprop=10    |
    DMO => 8h           |
                        |
    =#

    TS = [DateTime("2015-01-01T11:00:00")]
    network = PSCOPF.Networks.Network()
    # Buses
    PSCOPF.Networks.add_new_bus!(network, "bus_1")
    # Imposables
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                            10., 100.,
                                            0., 10.,
                                            Dates.Second(3*60*60), Dates.Second(0))
    # Uncertainties
    uncertainties = PSCOPF.Uncertainties()
    # initial generators state : need to pay starting cost at TS[1]
    generators_init_state = SortedDict(
        "prod_1_1" => PSCOPF.OFF,
    )
    mode = PSCOPF.ManagementMode("mode_5mins", Dates.Minute(5))

    # before DMO + still have an ech to decide on => commitment firmness is FREE
    @testset "tso_can_start_unit_before_DMO" begin
        ech = DateTime("2015-01-01T07:00:00")
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)

        # firmness
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), ),
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                                                        SortedDict("S1"=>PSCOPF.OFF))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>0.)))
                ),
            )
        )

        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T07:00:00"), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                                                        SortedDict("S1"=>PSCOPF.OFF))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>0.)))
                ),
            )
        )

        tso = PSCOPF.TSOOutFO()

        firmness = PSCOPF.compute_firmness(tso, ech, #7h
                                            DateTime("2015-01-01T08:00:00"), # corresponds to ECH-DMO
                                            TS, context)
        @test firmness == expected_firmness

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # we started prod_1_1
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test 20. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"]) < 1e-09
    end

    @testset "tso_cannot_start_unit_after_DMO" begin
        ech = DateTime("2015-01-01T10:00:00")
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)

        # firmness
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                        SortedDict("S1"=>PSCOPF.OFF))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>0.)))
                ),
            )
        )

        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T07:00:00"), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                        SortedDict("S1"=>PSCOPF.OFF))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>0.)))
                ),
            )
        )

        tso = PSCOPF.TSOOutFO()

        firmness = PSCOPF.compute_firmness(tso, ech, #10h
                                            DateTime("2015-01-01T10:30:00"), # corresponds to ECH-DMO
                                            TS, context)
        @test firmness == expected_firmness

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution uses slack
        @test_broken PSCOPF.get_status(result) != PSCOPF.pscopf_OPTIMAL
        # we could not start prod_1_1
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        @test 20. ≈ value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"])
    end

    @testset "tso_cannot_start_unit_after_DMO_even_if_market_does" begin
        ech = DateTime("2015-01-01T10:00:00")
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 20.)

        # firmness
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                                                        SortedDict("S1"=>PSCOPF.OFF))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>0.)))
                ),
            )
        )

        # market uses prod_1_1 but tso didn't (This should not happen as TSO dictates commitment)
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T07:00:00"), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                        SortedDict("S1"=>PSCOPF.ON))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>20.)))
                ),
            )
        )

        tso = PSCOPF.TSOOutFO()

        firmness = PSCOPF.compute_firmness(tso, ech, #10h
                                            DateTime("2015-01-01T10:30:00"), # corresponds to ECH-DMO
                                            TS, context)
        @test firmness == expected_firmness

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution uses slack
        @test_broken PSCOPF.get_status(result) != PSCOPF.pscopf_OPTIMAL
        # we could not start prod_1_1
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        @test 20. ≈ value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"])
    end

    @testset "tso_can_shutdown_unit_after_DMO" begin
        ech = DateTime("2015-01-01T10:00:00")
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 0.)

        # firmness
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T06:00:00"), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                        SortedDict("S1"=>PSCOPF.ON))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>20.)))
                ),
            )
        )

        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), Dates.DateTime("2015-01-01T07:00:00"), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON,
                                                                                        SortedDict("S1"=>PSCOPF.ON))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>20.)))
                ),
            )
        )

        tso = PSCOPF.TSOOutFO()

        firmness = PSCOPF.compute_firmness(tso, ech, #10h
                                            DateTime("2015-01-01T10:30:00"), # corresponds to ECH-DMO
                                            TS, context)
        @test firmness == expected_firmness

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # 0 demand => we shutdown the unit
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"]) < 1e-09
    end

end