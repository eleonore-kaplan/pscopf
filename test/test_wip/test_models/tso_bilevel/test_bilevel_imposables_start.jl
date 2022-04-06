using PSCOPF

using .PSCOPFFixtures

using Test
using JuMP
using Dates
using DataStructures
using Printf

@testset verbose=true "test_bilevel_imposables" begin

    TS = [DateTime("2015-01-01T11:00:00")]
    ech = DateTime("2015-01-01T07:00:00")
    next_ech = DateTime("2015-01-01T07:30:00")
    function create_instance(load_1, load_2,
                            market_decision_prod1, market_decision_prod2,
                            limit::Float64=35.,
                            logs=nothing)
        network = PSCOPFFixtures.network_2buses(limit=limit)
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                20., 200.,
                                                1000., 10.,
                                                Dates.Second(10), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "prod_2_1", PSCOPF.Networks.IMPOSABLE,
                                                20., 200.,
                                                5000., 50.,
                                                Dates.Second(10), Dates.Second(0))

        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", TS[1], "S1", load_1)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", TS[1], "S1", load_2)

        gen_initial_state = SortedDict{String,PSCOPF.GeneratorState}(
                                "prod_1_1" => PSCOPF.ON,
                                "prod_2_1" => PSCOPF.ON,
                            )

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                    gen_initial_state,
                                    uncertainties, nothing, logs)
        if !ismissing(market_decision_prod1)
            PSCOPF.set_commitment_value!(context.market_schedule, "prod_1_1", TS[1], "S1", market_decision_prod1)
        end
        if !ismissing(market_decision_prod2)
            PSCOPF.set_commitment_value!(context.market_schedule, "prod_2_1", TS[1], "S1", market_decision_prod2)
        end

        return context
    end

    @testset "no_risk_of_breaking_rso_constraint" begin
        #=
        TS: [11h, 11h15]
        S: [S1,S2]
                            bus 1                   bus 2
                            |                      |
        (limitable) prod_1_1|       "1_2"          |prod_2_1
        Pmin=20, Pmax=200   |                      |Pmin=20, Pmax=200
        Csta=1k, Cprop=10   |                      |Csta=5k, Cprop=50
                            |----------------------|
                            |         35           |
                            |                      |
                            |                      |
               load(bus_1)  |                      |load(bus_2)
        S1: 30              |                      | S1: 30

        Suppose market starts prod_1_1 and prod_2_1
        There are no RSO constraints
        => TSO does not have to undertake an action
        => he keeps the started units at their bounds
        => prod_1_1 : 20 -> 200
           prod_2_1 : 20 -> 200
        =#
        @testset "no_risk_of_breaking_rso_constraint_on_on" begin

            context = create_instance(30., 30.,
                                    PSCOPF.ON, PSCOPF.ON,
                                    35.,"start_imp_test")

            tso = PSCOPF.TSOBilevel()
            firmness = PSCOPF.compute_firmness(tso,
                                                ech, next_ech,
                                                TS, context)
            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

            #TSO RSO constraints are OK
            @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
            @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

            #Market EOD constraints are OK
            @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
            @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

            #TSO does not need to bound imposables because there is no risk of breaking RSO constraints
            #prod_1_1 is not bound
            @test 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"])
            @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
            #prod_2_1 is not bound
            @test 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"])
            @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"])

            #Market chooses the levels respecting the bounds for imposable production
            @test 40. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
            @test 20. ≈ value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"])

            @test - 1e-09 < objective_value(result.upper.model) < 1e-09

            for var in all_variables(result.model)
                println(name(var), " = ", value(var))
            end

        end

        #=
        TS: [11h, 11h15]
        S: [S1,S2]
                            bus 1                   bus 2
                            |                      |
        (limitable) prod_1_1|       "1_2"          |prod_2_1
        Pmin=20, Pmax=200   |                      |Pmin=20, Pmax=200
        Csta=1k, Cprop=10   |                      |Csta=5k, Cprop=50
                            |----------------------|
                            |         35           |
                            |                      |
                            |                      |
               load(bus_1)  |                      |load(bus_2)
        S1: 30              |                      | S1: 30

        Suppose market did not start any of prod_1_1 and prod_2_1
        The EOD constraint would be violated
        but there are no RSO constraints
        => TSO does not have to undertake an action cause EOD is not his responsibility
        => he keeps the units shut down
        PROBLEM : the following market will not be able to start the units due to the impositions
        => prod_1_1 : 0
           prod_2_1 : 0
           These cost 0.
           But the market will need to cut all the conso

        If the TSO had started any of the units he would have fixed its minimum production,
        Thus, he would have paid for it.
        =#
        @testset "no_risk_of_breaking_rso_constraint_off_off" begin

            context = create_instance(30., 30.,
                                    PSCOPF.OFF, PSCOPF.OFF,
                                    35.,"start_imp_test")

            tso = PSCOPF.TSOBilevel()
            firmness = PSCOPF.compute_firmness(tso,
                                                ech, next_ech,
                                                TS, context)
            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)

            # Solution is optimal
            @test_broken PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

            #TSO RSO constraints are OK
            @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
            @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

            #Market EOD constraints are OK
            @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
            @test_broken value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

            #TSO does not need to bound imposables
            #prod_1_1 is not bound
            @test_broken 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"])
            @test_broken 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
            #prod_2_1 is not bound
            @test value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"]) < 1e-09
            @test value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"]) < 1e-09

            #Market chooses the levels respecting the bounds for imposable production
            @test_broken 60. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
            @test value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"]) < 1e-09

            @test_broken - 1e-09 < objective_value(result.upper.model) ≈ 20.

            for var in all_variables(result.model)
                println(name(var), " = ", value(var))
            end

        end

        #=
        TS: [11h, 11h15]
        S: [S1,S2]
                            bus 1                   bus 2
                            |                      |
        (limitable) prod_1_1|       "1_2"          |prod_2_1
        Pmin=20, Pmax=200   |                      |Pmin=20, Pmax=200
        Csta=1k, Cprop=10   |                      |Csta=5k, Cprop=50
                            |----------------------|
                            |         35           |
                            |                      |
                            |                      |
               load(bus_1)  |                      |load(bus_2)
        S1: 30              |                      | S1: 30

        Suppose market did not start any of prod_1_1 and prod_2_1
        The EOD constraint would be violated
        but there are no RSO constraints
        => TSO does not have to undertake an action cause EOD is not his responsibility
        => he keeps the units shut down
        PROBLEM : the following market will not be able to start the units due to the impositions
        => prod_1_1 : 0
           prod_2_1 : 0
           These cost 0.
           But the market will need to cut all the conso

        If the TSO had started any of the units he would have fixed its minimum production,
        Thus, he would have paid for it.
        =#
        @testset "no_risk_of_breaking_rso_constraint_missing_missing" begin

            context = create_instance(30., 30.,
                                    missing, missing,
                                    35.,"start_imp_test")

            tso = PSCOPF.TSOBilevel()
            firmness = PSCOPF.compute_firmness(tso,
                                                ech, next_ech,
                                                TS, context)
            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)

            # Solution is optimal
            @test_broken PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

            #TSO RSO constraints are OK
            @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
            @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

            #Market EOD constraints are OK
            @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
            @test_broken value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

            #TSO does not need to bound imposables
            #prod_1_1 is not bound
            @test_broken 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"])
            @test_broken 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
            #prod_2_1 is not bound
            @test value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"]) < 1e-09
            @test value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"]) < 1e-09

            #Market chooses the levels respecting the bounds for imposable production
            @test_broken 60. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
            @test value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"]) < 1e-09

            @test_broken - 1e-09 < objective_value(result.upper.model) ≈ 20.

            for var in all_variables(result.model)
                println(name(var), " = ", value(var))
            end

        end

        #=
        TS: [11h, 11h15]
        S: [S1,S2]
                            bus 1                   bus 2
                            |                      |
        (limitable) prod_1_1|       "1_2"          |prod_2_1
        Pmin=20, Pmax=200   |                      |Pmin=20, Pmax=200
        Csta=1k, Cprop=10   |                      |Csta=5k, Cprop=50
                            |----------------------|
                            |         35           |
                            |                      |
                            |                      |
            load(bus_1)     |                      |load(bus_2)
        S1: 30              |                      | S1: 30

        Suppose market only started prod_1_1
        There are no RSO constraints
        => TSO does not have to undertake an action
        => he keeps the unit prod_2_1 shut
        => prod_1_1 : 20 -> 200 : cost 0.
           prod_2_1 : 0 : cost 0.
           These cost 0.
        =#
        @testset "no_risk_of_breaking_rso_constraint_on_off" begin

            context = create_instance(30., 30.,
                                    PSCOPF.ON, PSCOPF.OFF,
                                    35.,"start_imp_test")

            tso = PSCOPF.TSOBilevel()
            firmness = PSCOPF.compute_firmness(tso,
                                                ech, next_ech,
                                                TS, context)
            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

            #TSO RSO constraints are OK
            @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
            @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

            #Market EOD constraints are OK
            @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
            @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

            #TSO does not need to bound imposables
            #prod_1_1 is not bound
            @test 20. ≈value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"])
            @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
            #prod_2_1 is not bound
            @test value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"]) < 1e-09
            @test value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"]) < 1e-09

            #Market chooses the levels respecting the bounds for imposable production
            @test 60. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
            @test value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"]) < 1e-09

            @test - 1e-09 < objective_value(result.upper.model) < 1e-09

            for var in all_variables(result.model)
                println(name(var), " = ", value(var))
            end

        end

        #=
        TS: [11h, 11h15]
        S: [S1,S2]
                            bus 1                   bus 2
                            |                      |
        (limitable) prod_1_1|       "1_2"          |prod_2_1
        Pmin=20, Pmax=200   |                      |Pmin=20, Pmax=200
        Csta=1k, Cprop=10   |                      |Csta=5k, Cprop=50
                            |----------------------|
                            |         35           |
                            |                      |
                            |                      |
            load(bus_1)     |                      |load(bus_2)
        S1: 30              |                      | S1: 30

        Suppose market only started prod_2_1
        There are no RSO constraints
        => TSO does not have to undertake an action
        => he keeps the unit prod_1_1 shut
        => prod_1_1 : 0 : cost 0.
           prod_2_1 : 20 -> 200 : cost 0.
           These cost 0.

        If he had imposed prod_1_1's starting, he would have paid for that : 20
        =#
        @testset "no_risk_of_breaking_rso_constraint_off_on" begin

            context = create_instance(30., 30.,
                                    PSCOPF.OFF, PSCOPF.ON,
                                    35.,"start_imp_test")

            tso = PSCOPF.TSOBilevel()
            firmness = PSCOPF.compute_firmness(tso,
                                                ech, next_ech,
                                                TS, context)
            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

            #TSO RSO constraints are OK
            @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
            @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

            #Market EOD constraints are OK
            @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
            @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

            #TSO does not need to bound imposables
            #prod_1_1 is not bound
            @test value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"]) < 1e-09
            @test value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"]) < 1e-09
            #prod_2_1 is not bound
            @test 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"])
            @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"])

            #Market chooses the levels respecting the bounds for imposable production
            @test value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"]) < 1e-09
            @test 60. ≈ value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"])

            @test objective_value(result.upper.model)  < 1e-09

            for var in all_variables(result.model)
                println(name(var), " = ", value(var))
            end

        end

    end

    #=
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) prod_1_1|       "1_2"          |prod_2_1
    Pmin=0, Pmax=200    |                      |Pmin=0, Pmax=200
    Csta=0, Cprop=10    |                      |Csta=0, Cprop=50
                        |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10            |                      | S1: 100

    Market chooses prod_1_1 cause cheaper than prod_2_1
    => a flow of 100. => RSO problem

    TSO needs to impose using prod_2_1. two options:

    option 1 : impose prod_1_1 to produce at most 10+35=45 => P_1_1 in [0,45]
        If the TSO chooses to shut down prod_1_1 entirely i.e. [O, O] it will pay :
            => cost (unit was ON): (0-20) + (200-0) = -20 + 200 = 180
        If the TSO chooses to allow using prod_1_1 i.e. [20, 45] it will pay :
            => cost (unit was ON): (20-20) + (200-45) = 155
    (*) If the TSO chooses to allow using prod_1_1 freely i.e. [20, 200] and use option 2 it will pay :
            => cost (unit was ON): (20-20) + (200-200) = 0.    + cost(option 2)

    option 2 : impose prod_2_1 to produce at least 100-35=65 => P_2_1 in [65,200] => cost (unit was OFF): 65

    Imposing one of the preceding conditions guarantees RSO constraint
        => TSO will impose the cheaper one => option 1

    FIXME Note: this might not be what we want, the TSO could have shut bus1 completely and only used bus2
    =#
    @testset "rso_constraint_requires_setting_imposables_bounds_min" begin

        context = create_instance(10., 100.,
                                PSCOPF.ON, PSCOPF.OFF,
                                35.,"imposable_test")

        tso = PSCOPF.TSOBilevel()
        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL

        #TSO RSO constraints are OK
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        #Market EOD constraints are OK
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test value(result.lower.slack_model.p_cut_conso[TS[1],"S1"]) < 1e-09

        #TSO sets the bounds for imposable production respecting units' pmin and pmax
        #prod_1_1 is not bound
        @test 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"])
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
        #prod_2_1 bounding + EOD, guarantees RSO constraints
        @test 65. ≈ value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"])
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"])

        #Market chooses the levels sets the bounds for imposable production
        @test 45. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
        @test 65. ≈ value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"])

        @test 65. ≈ objective_value(result.upper.model)

        for var in all_variables(result.model)
            println(name(var), " = ", value(var))
        end

    end

    #=
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) prod_1_1|       "1_2"          |prod_2_1
    Pmin=0, Pmax=200    |                      |Pmin=0, Pmax=200
    Csta=0, Cprop=10    |                      |Csta=0, Cprop=50
                        |----------------------|
                        |         35           |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 10            |                      | S1: 300

    Suppose market starts prod_1_1 and prod_2_1
        because prod_1_1 is cheaper, it will be used at max capa i.e. 200.
        This will cause an RSO constraint on branch 1_2

    TSO needs to solve the RSO constraint by limiting prod_1_1 at [20, 45]
        => limit using prod_1_1 to 10+35=45
        prod_1_1 : 20 -> 45 : cost : 200-45 = 155
        prod_2_1 : 20 -> 200
        => costs 155

    This however will cause a EOD disbalance in market => cut_conso = 65
    =#
    @testset "rso_constraint_requires_setting_imposables_bounds_max" begin

        context = create_instance(10., 300.,
                                PSCOPF.ON, PSCOPF.ON,
                                35.,"imposable_test")

        tso = PSCOPF.TSOBilevel()
        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK

        #TSO RSO constraints are OK
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        #Market EOD constraints are OK
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test 65. ≈ value(result.lower.slack_model.p_cut_conso[TS[1],"S1"])

        # RSO locates cut conso on bus 2 to assure flow limit
        @test value(result.upper.slack_model.p_cut_conso["bus_1", TS[1],"S1"]) < 1e-09
        @test 65. ≈ value(result.upper.slack_model.p_cut_conso["bus_2", TS[1],"S1"])

        #TSO sets the bounds for imposable production respecting units' pmin and pmax
        #prod_1_1 is not bound
        @test 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"])
        @test 45. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
        #prod_2_1 bounding + EOD, guarantees RSO constraints
        @test 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"])
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"])

        #Market chooses the levels sets the bounds for imposable production
        @test 45. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
        @test 200. ≈ value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"])

        @test 155. ≈ objective_value(result.upper.model)

        for var in all_variables(result.model)
            println(name(var), " = ", value(var))
        end

    end

    #TODO : use prop cost instead of the bounding_cost (1.)

    #=
    TS: [11h, 11h15]
    S: [S1,S2]
                        bus 1                   bus 2
                        |                      |
    (limitable) prod_1_1|       "1_2"          |prod_2_1
    Pmin=0, Pmax=200    |                      |Pmin=0, Pmax=200
    Csta=0, Cprop=10    |                      |Csta=0, Cprop=50
                        |----------------------|
                        |         500          |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 400           |                      | S1: 20

    No risk of RSO constraint breaking, but EOD cannot be satisfied
        => the market needs to cut conso
        => the TSO will locate the bus where we cut
    =#
    @testset "eod_problem_requires_cutting_conso" begin

        context = create_instance(400., 20.,
                                PSCOPF.ON, PSCOPF.ON,
                                500.)

        tso = PSCOPF.TSOBilevel()
        firmness = PSCOPF.compute_firmness(tso,
                                            ech, next_ech,
                                            TS, context)
        result = PSCOPF.run(tso, ech, firmness,
                    PSCOPF.get_target_timepoints(context),
                    context)

        # Solution is optimal
        @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK

        #TSO RSO constraints can be respected without capping or losing load OK
        @test value(result.upper.limitable_model.p_capping_min[TS[1],"S1"]) < 1e-09
        @test value(result.upper.slack_model.p_cut_conso_min[TS[1],"S1"]) < 1e-09

        #Market needs to cut conso to assure EOD constraint
        @test value(result.lower.limitable_model.p_capping[TS[1],"S1"]) < 1e-09
        @test 20. ≈ value(result.lower.slack_model.p_cut_conso[TS[1],"S1"])

        # RSO locates cut conso : here any combination will do
        @test 20. ≈ ( value(result.upper.slack_model.p_cut_conso["bus_1", TS[1],"S1"])
                    + value(result.upper.slack_model.p_cut_conso["bus_2", TS[1],"S1"]) )

        #TSO sets the bounds for imposable production respecting units' pmin and pmax
        #prod_1_1 is not bound
        @test 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"])
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
        #prod_2_1 bounding + EOD, guarantees RSO constraints
        @test 20. ≈ value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"])
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"])

        #Market chooses the levels sets the bounds for imposable production
        @test 200. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
        @test 200. ≈ value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"])

        for var in all_variables(result.model)
            println(name(var), " = ", value(var))
        end

    end


end
