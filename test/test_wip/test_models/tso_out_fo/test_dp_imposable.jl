using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_tso_out_fo_dp_imposable" begin

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (imposable) prod_1_1|load
    Pmin=10, Pmax=100   |    ?
    Csta=0, Cprop=10    |
    DP => 10h30         |
    INIT : OFF          |
    PREV MARKET :       |
        ON?     ?(?)    |
        PROD    ?(?)    |
    PREV TSO :          |
        ON?     ?(?)    |
        PROD    ?(?)    |
                        |
    (imposable) prod_1_2|
    Pmin=10, Pmax=100   |
    Csta=0, Cprop=15    |
    DP => 10h45         |
    INIT : OFF          |
    PREV MARKET :       |
        ON?     ?(?)    |
        PROD    ?(?)    |
    PREV TSO :          |
        ON?     ?(?)    |
        PROD    ?(?)    |
                        |
    =#
    function create_context(TS, ech, next_ech,
                            market_prod_1_1, market_isdefinitive_prod_1_1::Bool,
                            market_prod_1_2, market_isdefinitive_prod_1_2::Bool,
                            tso_prod_1_1, tso_isdefinitive_prod_1_1::Bool,
                            tso_prod_1_2, tso_isdefinitive_prod_1_2::Bool,
                            )
        network = PSCOPF.Networks.Network()
        # Buses
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                10., 100.,
                                                0., 10.,
                                                Dates.Second(3*60*60), Dates.Second(30*60))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_2", PSCOPF.Networks.IMPOSABLE,
                                                10., 100.,
                                                0., 15.,
                                                Dates.Second(3*60*60), Dates.Second(15*60))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", TS[1], "S1", 55.)
        # initial generators state : need to pay starting cost
        generators_init_state = SortedDict(
            "prod_1_1" => PSCOPF.OFF,
            "prod_1_2" => PSCOPF.OFF,
        )
        mode = PSCOPF.ManagementMode("mode_5mins", Dates.Minute(5))

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        definitive_prod_1 = market_isdefinitive_prod_1_1 ? market_prod_1_1 : missing
        definitive_prod_2 = market_isdefinitive_prod_1_2 ? market_prod_1_2 : missing
        on_1 = (market_prod_1_1 > 1e-09) ? PSCOPF.ON : PSCOPF.OFF
        on_2 = (market_prod_1_2 > 1e-09) ? PSCOPF.ON : PSCOPF.OFF
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), ech-Minute(1), SortedDict(
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(TS[1] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(on_1,
                                                                                                                    SortedDict("S1"=>on_1))),
                                            SortedDict(TS[1] => PSCOPF.UncertainValue{Float64}(definitive_prod_1,
                                                                                                                    SortedDict("S1"=>market_prod_1_1)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(TS[1] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(on_2,
                                                                                                                    SortedDict("S1"=>on_2))),
                                            SortedDict(TS[1] => PSCOPF.UncertainValue{Float64}(definitive_prod_2,
                                                                                                                    SortedDict("S1"=>market_prod_1_2)))
                                            )
                                        )
                                    )

        definitive_prod_1 = tso_isdefinitive_prod_1_1 ? tso_prod_1_1 : missing
        definitive_prod_2 = tso_isdefinitive_prod_1_2 ? tso_prod_1_2 : missing
        on_1 = (tso_prod_1_1 > 1e-09) ? PSCOPF.ON : PSCOPF.OFF
        on_2 = (tso_prod_1_2 > 1e-09) ? PSCOPF.ON : PSCOPF.OFF
        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), ech-Minute(1), SortedDict(
                                        "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                                            SortedDict(TS[1] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(on_1,
                                                                                                                    SortedDict("S1"=>on_1))),
                                            SortedDict(TS[1] => PSCOPF.UncertainValue{Float64}(definitive_prod_1,
                                                                                                                    SortedDict("S1"=>tso_prod_1_1)))
                                            ),
                                        "prod_1_2" => PSCOPF.GeneratorSchedule("prod_1_2",
                                            SortedDict(TS[1] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(on_2,
                                                                                                                    SortedDict("S1"=>on_2))),
                                            SortedDict(TS[1] => PSCOPF.UncertainValue{Float64}(definitive_prod_2,
                                                                                                                    SortedDict("S1"=>tso_prod_1_2)))
                                            )
                                        )
                                )

        tso = PSCOPF.TSOOutFO()

        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)

        return context, tso, firmness
    end

    TS = [DateTime("2015-01-01T11:00:00")]

    #=
    ECH1*         ECH2            ECH3                                 <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "tso_can_change_the_production_level_before_dp_if_ON" begin
        ech = DateTime("2015-01-01T10:00:00")

        # firmness
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(TS[1] => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(TS[1] => PSCOPF.DECIDED), ),
                SortedDict("prod_1_1" => SortedDict(TS[1] => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(TS[1] => PSCOPF.FREE), )
                )

        context, tso, firmness = create_context(TS, ech, ech+Minute(5),
                                0., false, 60., false, #previous market
                                0., false, 50., false, #previous tso
                                )

        @test firmness == expected_firmness

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # prod_1_1 is OFF cause it already was OFF:
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # prod_1_2 was ON, it can change it's production : 50 => 55.
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
        @test 55. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
    end


    #=
    ECH1          ECH2            ECH3           ECH4        ECH5*    <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "tso_cannot_change_the_production_level_after_dp" begin
        ech = DateTime("2015-01-01T10:50:00")

        # firmness
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(TS[1] => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(TS[1] => PSCOPF.DECIDED), ),
                SortedDict("prod_1_1" => SortedDict(TS[1] => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(TS[1] => PSCOPF.DECIDED), )
                )

        context, tso, firmness = create_context(TS, ech, ech+Minute(5),
                                0., false, 55., false, #previous market
                                0., true, 50., true, #previous tso
                                )

        @test firmness == expected_firmness

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal but has slack due to infeasibility
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK
        # prod_1_1 is OFF cause it already was OFF:
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # prod_1_2 cannot be changed after DP
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
        @test 50. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
        # slack for feasibility
        @test 5. ≈ value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"])
    end

    #=
    ECH1*         ECH2            ECH3           ECH4                  <---FO--->TS
    |             |               |
    10h           10h30           10h40          10h45                          11h
                  <------------------------------------------DP(prod1)----------->
                                                   <---------DP(prod2)----------->
    =#
    @testset "tso_cannot_change_the_production_level_before_dp_if_unit_is_off_and_past_DMO" begin
        ech = DateTime("2015-01-01T10:00:00")

        # firmness
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(TS[1] => PSCOPF.DECIDED),
                            "prod_1_2" => SortedDict(TS[1] => PSCOPF.DECIDED), ),
                SortedDict("prod_1_1" => SortedDict(TS[1] => PSCOPF.FREE),
                            "prod_1_2" => SortedDict(TS[1] => PSCOPF.FREE), )
                )

        context, tso, firmness = create_context(TS, ech, ech+Minute(5),
                55., false, 0., false, #previous market
                0., false, 0., false, #previous tso
                )

        @test firmness == expected_firmness

        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)
        PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

        # Solution is optimal but has slack due to infeasibility
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK
        # prod_1_1 is OFF cause it already was OFF:
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        # prod_1_2 cannot be changed after DP
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_2", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_2", TS[1], "S1") < 1e-09
        # slack for feasibility
        @test 55. ≈ value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"])
    end

end