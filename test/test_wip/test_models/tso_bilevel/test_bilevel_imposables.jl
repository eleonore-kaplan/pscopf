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
                            limit::Float64=35.,
                            logs=nothing)
        network = PSCOPFFixtures.network_2buses(limit=limit)
        # Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "prod_1_1", PSCOPF.Networks.IMPOSABLE,
                                                0., 200.,
                                                0., 10.,
                                                Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "prod_2_1", PSCOPF.Networks.IMPOSABLE,
                                                0., 200.,
                                                0., 50.,
                                                Dates.Second(0), Dates.Second(0))

        # Uncertainties
        uncertainties = PSCOPF.Uncertainties()
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", TS[1], "S1", load_1)
        PSCOPF.add_uncertainty!(uncertainties, ech, "bus_2", TS[1], "S1", load_2)

        context = PSCOPF.PSCOPFContext(network, TS, PSCOPF.PSCOPF_MODE_1,
                                    SortedDict{String,PSCOPF.GeneratorState}(), #gen_initial_state
                                    uncertainties, nothing, logs)

        return context
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
      S1: 30            |                      | S1: 30

    
    FIXME!
    =#
    @testset "no_risk_of_breaking_rso_constraint" begin

        context = create_instance(30., 30.,
                                35.)

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
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
        #prod_2_1 is not bound
        @test value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"]) < 1e-09
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"])

        #Market chooses the levels respecting the bounds for imposable production
        @test 60. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
        @test value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"]) < 1e-09

        @test objective_value(result.upper.model) < 1e-09

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
      S1: 10            |                      | S1: 100   

    prod_1_1 is cheaper than prod_2_1
     but using only prod_1_1, like a market would, will cause RSO problems
    => The TSO needs to oblige
            bus1 to produce at most 10+35=45 => P_1_1 in [0,45] => cost : 200-45=155
            bus2 to produce at least 100-35=65 => P_2_1 in [65,200] => cost : 65
        Imposing one of the preceding conditions guarantees RSO constraint
        => TSO will impose one of the two preceding conditions, the cheaper one

    =#
    @testset "rso_constraint_requires_setting_imposables_bounds" begin

        context = create_instance(10., 100.,
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
        @test value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"]) < 1e-09
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
        #prod_2_1 bounding + EOD, guarantees RSO constraints
        @test 65. ≈ value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"])
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"])

        #Market chooses the levels sets the bounds for imposable production
        @test 45. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
        @test 65. ≈ value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"])

        @test objective_value(result.upper.model) ≈ ( 65 )

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
        @test value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"]) < 1e-09
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
        #prod_2_1 bounding + EOD, guarantees RSO constraints
        @test value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"]) < 1e-09
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"])

        #Market chooses the levels sets the bounds for imposable production
        @test 200. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
        @test 200. ≈ value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"])

        @test objective_value(result.upper.model) < 1e-09

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
                        |         180          |
                        |                      |
                        |                      |
           load(bus_1)  |                      |load(bus_2)
      S1: 400           |                      | S1: 20

    =#
    @testset "eod_and_rso_problems_require_cutting_conso_and_locating_it" begin

        context = create_instance(400., 20.,
                                180.)

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

        # RSO locates cut conso : due to flow limit, conso must be cut on bus_1
        @test 20. ≈ value(result.upper.slack_model.p_cut_conso["bus_1", TS[1],"S1"])
        @test value(result.upper.slack_model.p_cut_conso["bus_2", TS[1],"S1"]) < 1e-09

        #TSO sets the bounds for imposable production respecting units' pmin and pmax
        #prod_1_1 is not bound
        @test value(result.upper.imposable_model.p_tso_min["prod_1_1",TS[1],"S1"]) < 1e-09
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_1_1",TS[1],"S1"])
        #prod_2_1 bounding + EOD, guarantees RSO constraints
        @test value(result.upper.imposable_model.p_tso_min["prod_2_1",TS[1],"S1"]) < 1e-09
        @test 200. ≈ value(result.upper.imposable_model.p_tso_max["prod_2_1",TS[1],"S1"])

        #Market chooses the levels sets the bounds for imposable production
        @test 200. ≈ value(result.lower.imposable_model.p_injected["prod_1_1",TS[1],"S1"])
        @test 200. ≈ value(result.lower.imposable_model.p_injected["prod_2_1",TS[1],"S1"])

        @test objective_value(result.upper.model) < 1e-09

        for var in all_variables(result.model)
            println(name(var), " = ", value(var))
        end

    end

    

end
