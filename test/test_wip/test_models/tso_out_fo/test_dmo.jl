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
    (pilotable) prod_1_1|load
    Pmin=10, Pmax=100   |    ?
    Csta=0, Cprop=10    |
    DMO => 8h           |
    INIT : OFF          |
    PREV MARKET :       |
        ON?     ?(?)    |
        PROD    ?(?)    |
    PREV TSO :          |
        ON?     ?(?)    |
        PROD    ?(?)    |
                        |
    =#
    function create_context(TS, ech,
                            load_1,
                            market_on_s1, market_isdefinitive_on::Bool,
                            tso_on_s1, tso_isdefinitive_on::Bool,
                            )
        network = PSCOPF.Networks.Network()
        # Buses
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Pilotables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.PILOTABLE,
                                                10., 100.,
                                                0., 10.,
                                                Dates.Second(3*60*60), Dates.Second(0))
        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", TS[1], "S1", load_1)
        # initial generators state : need to pay starting cost
        generators_init_state = SortedDict(
            "prod_1_1" => PSCOPF.OFF,
        )
        mode = PSCOPF.ManagementMode("mode_5mins", Dates.Minute(5))

        context = PSCOPF.PSCOPFContext(network, TS, mode,
                                        generators_init_state,
                                        uncertainties, nothing)

        definitive_on =  market_isdefinitive_on ? market_on_s1 : missing
        prod = (market_on_s1 == PSCOPF.ON) ? load_1 : 0.
        context.market_schedule = PSCOPF.Schedule(PSCOPF.Market(), ech-Minute(1), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(definitive_on,
                                                                                        SortedDict("S1"=>market_on_s1))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>prod)))
                ),
            )
        )

        definitive_on =  tso_isdefinitive_on ? tso_on_s1 : missing
        prod = (tso_on_s1 == PSCOPF.ON) ? load_1 : 0.
        context.tso_schedule = PSCOPF.Schedule(PSCOPF.TSO(), ech-Minute(1), SortedDict(
            "prod_1_1" => PSCOPF.GeneratorSchedule("prod_1_1",
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(definitive_on,
                                                                                        SortedDict("S1"=>tso_on_s1))),
                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.UncertainValue{Float64}(missing,
                                                                                        SortedDict("S1"=>prod)))
                ),
            )
        )

        return context
    end


    TS = [DateTime("2015-01-01T11:00:00")]


    #=
    ech=7h : before DMO
    next_ech = 8h : coincide with DMO
    before DMO + still have an ech to decide on => commitment firmness is FREE
    We can start the unit no matter what the previous decision was

    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (pilotable) prod_1_1|load
    Pmin=10, Pmax=100   |    20.
    Csta=0, Cprop=10    |
    DMO => 8h           |
    INIT : OFF          |
    PREV MARKET :       |
        ON?     OFF
        PROD    0.
    PREV TSO :
        ON?     OFF
        PROD    0.

    The previous decision was to turn off the unit
    But now we need to satisfy 20MW of demand => we need to start the unit
    since we are before the DMO, we can do so!
    =#
    @testset "tso_can_start_unit_before_DMO" begin
        ech = DateTime("2015-01-01T07:00:00")
        next_ech = DateTime("2015-01-01T08:00:00") # corresponds to ECH-DMO

        context = create_context(TS, ech, 20.,
                                PSCOPF.OFF, false, #previous market
                                PSCOPF.OFF, false, #previous tso
                                )

        tso = PSCOPF.TSOOutFO()
        result, firmness = PSCOPF.run_step!(context, tso, ech, next_ech)

        # firmness
        expected_firmness = PSCOPF.Firmness(
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), ),
                SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
                )
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
        @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09
    end

    #=
    ech=10h : after DMO
    after DMO, We can no longer start the unit

    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (pilotable) prod_1_1|load
    Pmin=10, Pmax=100   |    20.
    Csta=0, Cprop=10    |
    DMO => 8h           |
    INIT : OFF          |
    PREV MARKET :       |
        ON?     OFF(definitive)
        PROD    0.
    PREV TSO :
        ON?     OFF(definitive)
        PROD    0.

    The previous decisions were to turn off the unit
    But now we need to satisfy 20MW of demand => we need to start the unit
    now we are past DMO, so we can no longer start the unit
    =#
    @testset "tso_cannot_start_unit_after_DMO" begin
        ech = DateTime("2015-01-01T10:00:00")

        context = create_context(TS, ech, 20.,
                                PSCOPF.OFF, true, #previous market
                                PSCOPF.OFF, true, #previous tso
                                )

        tso = PSCOPF.TSOOutFO()
        next_ech = DateTime("2015-01-01T10:30:00")
        result, firmness = PSCOPF.run_step!(context, tso, ech, next_ech)

        expected_firmness = PSCOPF.Firmness(
            SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
            SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
            )
        @test firmness == expected_firmness

        # Solution uses slack
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK
        # we could not start prod_1_1
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        @test 20. ≈ value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"])
    end

    #=
    ech=10h : after DMO
    after DMO, We can no longer start the unit

    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (pilotable) prod_1_1|load
    Pmin=10, Pmax=100   |    20.
    Csta=0, Cprop=10    |
    DMO => 8h           |
    INIT : OFF          |
    PREV MARKET :       |
        ON?     ON(definitive)
        PROD    0.
    PREV TSO :
        ON?     OFF(definitive)
        PROD    0.

    The previous TSO decision was to turn off the unit
    The previous Market decision was to turn on the unit
    (The two decisions are not coherent, this is hypothetical and should not happen)
    Currently, we need to satisfy 20MW of demand => we need to start the unit
    now we are past DMO, so we can no longer start the unit if it's OFF
    our reference is the TSO
    => the unit appear shutdown for us
    => we cannot use it (even if market is using it)
    =#
    @testset "tso_cannot_start_unit_after_DMO_even_if_market_does" begin
        ech = DateTime("2015-01-01T10:00:00")
        context = create_context(TS, ech, 20.,
                                PSCOPF.ON, true, #previous market
                                PSCOPF.OFF, true, #previous tso : this is our reference
                                )

        tso = PSCOPF.TSOOutFO()
        @test PSCOPF.is_tso(tso.configs.REF_SCHEDULE_TYPE) #The reference for decided values is the preceding TSO schedule
        next_ech = DateTime("2015-01-01T10:30:00")
        result, firmness = PSCOPF.run_step!(context, tso, ech, next_ech)

        expected_firmness = PSCOPF.Firmness(
            SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
            SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
            )
        @test firmness == expected_firmness

        # Solution uses slack
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK
        # we could not start prod_1_1
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        @test 20. ≈ value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"])
    end

    #=
    ech=10h : after DMO
    after DMO, We can no longer start the unit

    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (pilotable) prod_1_1|load
    Pmin=10, Pmax=100   |    20.
    Csta=0, Cprop=10    |
    DMO => 8h           |
    INIT : OFF          |
    PREV MARKET :       |
        ON?     ON(definitive)
        PROD    0.
    PREV TSO :
        ON?     OFF(definitive)
        PROD    0.

    The previous TSO decision was to turn off the unit
    The previous Market decision was to turn on the unit
    (The two decisions are not coherent, this is hypothetical and should not happen)
    Currently, we need to satisfy 20MW of demand => we need to start the unit
    now we are past DMO, so we can no longer start the unit if it's OFF
    our reference is the MARKET (not the default behaviour)
    => the unit appears started and we can use it
    =#
    @testset "dmo_constraint_is_linked_to_reference_schedule" begin
        ech = DateTime("2015-01-01T10:00:00")
        context = create_context(TS, ech, 20.,
                                PSCOPF.ON, true, #previous market : this will be set to be our reference (non default)
                                PSCOPF.OFF, true, #previous tso
                                )

        tso = PSCOPF.TSOOutFO(PSCOPF.TSOConfigs(REF_SCHEDULE_TYPE=PSCOPF.Market()))
        @test PSCOPF.is_market(tso.configs.REF_SCHEDULE_TYPE) #The reference for decided values is the preceding TSO schedule
        next_ech = DateTime("2015-01-01T10:30:00")
        result, firmness = PSCOPF.run_step!(context, tso, ech, next_ech)

        expected_firmness = PSCOPF.Firmness(
            SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
            SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
            )
        @test firmness == expected_firmness

        # Solution uses slack
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # we could not start prod_1_1
        @test PSCOPF.ON == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test 20. ≈ PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09
    end

    #=
    ech=10h : after DMO
    after DMO, We can still shutdown a unit

    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (pilotable) prod_1_1|load
    Pmin=10, Pmax=100   |    20.
    Csta=0, Cprop=10    |
    DMO => 8h           |
    INIT : OFF          |
    PREV MARKET :       |
        ON?     ON(definitive)
        PROD    20.
    PREV TSO :
        ON?     ON(definitive)
        PROD    20.

    The previous decisions were to turn ON the unit
    Currently, we no longer need the unit
    => we can shut it down even if we are past DMO
    =#
    @testset "tso_can_shutdown_unit_after_DMO" begin
        ech = DateTime("2015-01-01T10:00:00")
        context = create_context(TS, ech,
                                0., #No demand
                                PSCOPF.ON, true, #previous market
                                PSCOPF.ON, true, #previous tso
                                )

        tso = PSCOPF.TSOOutFO()
        next_ech = DateTime("2015-01-01T10:30:00")
        result, firmness = PSCOPF.run_step!(context, tso, ech, next_ech)

        expected_firmness = PSCOPF.Firmness(
            SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), ),
            SortedDict("prod_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
            )
        @test firmness == expected_firmness

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
        # 0 demand => we shutdown the unit
        @test PSCOPF.OFF == PSCOPF.get_commitment_value(context.tso_schedule, "prod_1_1", TS[1], "S1")
        @test PSCOPF.get_prod_value(context.tso_schedule, "prod_1_1", TS[1], "S1") < 1e-09
        @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09
    end

end
