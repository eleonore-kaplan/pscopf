using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_tso_limitation" begin

    @testset verbose=true "test_tso_limitation_after_dp" begin

        #=
        TS: [11h]
        S: [S1]
                            bus 1
                            |
        (limitable) wind_1_1|load
        Pmin=0, Pmax=100    | S1: 30
        Csta=0, Cprop=1     | S2: 35
        DP => 9h30          |
        S1: 55              |
        S2: 60              |
        =#
        @testset "tso_limits_limitables" begin
            TS = [DateTime("2015-01-01T11:00:00")]
            ech = DateTime("2015-01-01T10:00:00")
            network = PSCOPF.Networks.Network()
            # Buses
            PSCOPF.Networks.add_new_bus!(network, "bus_1")
            # Limitables
            PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                    0., 100.,
                                                    0., 1.,
                                                    Dates.Second(90*60), Dates.Second(90*60))
            # Uncertainties
            uncertainties = PSCOPF.Uncertainties()
            # initial generators state : need to pay starting cost at TS[1]
            generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()
            #ManagementMode
            mode = PSCOPF.ManagementMode("test_mode", Dates.Minute(5))


            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 30.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 35.)

            # firmness
            firmness = PSCOPF.Firmness(
                    SortedDict(),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), )
                    )

            context = PSCOPF.PSCOPFContext(network, TS, mode,
                                            generators_init_state,
                                            uncertainties, nothing)
            tso = PSCOPF.TSOOutFO()

            @test firmness == PSCOPF.compute_firmness(tso,
                                                    ech, DateTime("2015-01-01T10:40:00"),
                                                    TS, context)

            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)
            PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK
            # Limit
            @test 30. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1],"S1"])
            @test 30. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1],"S2"])

            @test 30. ≈ value(result.limitable_model.p_limit["wind_1_1",TS[1], "S1"])
            @test 30. ≈ value(result.limitable_model.p_limit["wind_1_1",TS[1], "S2"])

            # active limits ?
            @test 1 ≈ value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S1"]) # now 0, should be 1 ?
            @test 30. ≈ value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S1"]) # now 0, should be 35 ?
            @test 1 ≈ value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S2"]) # now 0, should be 1 ?
            @test 30. ≈ value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S2"]) # now 0, should be 35 ?
            @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09
            @test 5. ≈ value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S2"])
        end

        #=
        TS: [11h]
        S: [S1]
                            bus 1
                            |
        (limitable) wind_1_1|load
        Pmin=0, Pmax=100    | S1: 30
        Csta=0, Cprop=1     | S2: 60
        S1: 55            |
        S2: 60            |
        =#
        @testset "tso_cannot_choose_injection_level_1" begin
            TS = [DateTime("2015-01-01T11:00:00")]
            ech = DateTime("2015-01-01T10:00:00")
            network = PSCOPF.Networks.Network()
            # Buses
            PSCOPF.Networks.add_new_bus!(network, "bus_1")
            # Limitables
            PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                    0., 100.,
                                                    0., 1.,
                                                    Dates.Second(90*60), Dates.Second(90*60))
            # Uncertainties
            uncertainties = PSCOPF.Uncertainties()
            # initial generators state : need to pay starting cost at TS[1]
            generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()
            #ManagementMode
            mode = PSCOPF.ManagementMode("test_mode", Dates.Minute(5))


            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 55.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 30.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)

            # firmness
            firmness = PSCOPF.Firmness(
                    SortedDict(),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), )
                    )

            context = PSCOPF.PSCOPFContext(network, TS, mode,
                                            generators_init_state,
                                            uncertainties, nothing)
            tso = PSCOPF.TSOOutFO()

            @test firmness == PSCOPF.compute_firmness(tso,
                                                    ech, DateTime("2015-01-01T10:40:00"),
                                                    TS, context)

            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)
            PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK
            # Limit
            @test 30. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1],"S1"])
            @test 30. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1],"S2"])

            @test 30. ≈ value(result.limitable_model.p_limit["wind_1_1",TS[1], "S1"])
            @test 30. ≈ value(result.limitable_model.p_limit["wind_1_1",TS[1], "S2"])

            # active limits ?
            @test 1 ≈ value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S1"])
            @test 30. ≈ value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S1"])
            @test 1 ≈ value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S2"])
            @test 30. ≈ value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S2"])
            @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09
            @test 30. ≈ value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S2"])
        end

        #=
        TS: [11h]
        S: [S1]
                            bus 1
                            |
        (limitable) wind_1_1|load
        Pmin=0, Pmax=100    | S1: 30
        Csta=0, Cprop=1     | S2: 60
        S1: 70            |
        S2: 60            |
        uncertainty(S1) > limit
        =#
        @testset "tso_cannot_choose_injection_level_2" begin
            TS = [DateTime("2015-01-01T11:00:00")]
            ech = DateTime("2015-01-01T10:00:00")
            network = PSCOPF.Networks.Network()
            # Buses
            PSCOPF.Networks.add_new_bus!(network, "bus_1")
            # Limitables
            PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                    0., 100.,
                                                    0., 1.,
                                                    Dates.Second(90*60), Dates.Second(90*60))
            # Uncertainties
            uncertainties = PSCOPF.Uncertainties()
            # initial generators state : need to pay starting cost at TS[1]
            generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()
            #ManagementMode
            mode = PSCOPF.ManagementMode("test_mode", Dates.Minute(5))


            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 70.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 30.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)

            # firmness
            firmness = PSCOPF.Firmness(
                    SortedDict(),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), )
                    )

            context = PSCOPF.PSCOPFContext(network, TS, mode,
                                            generators_init_state,
                                            uncertainties, nothing)
            tso = PSCOPF.TSOOutFO()

            @test firmness == PSCOPF.compute_firmness(tso,
                                                    ech, DateTime("2015-01-01T10:40:00"),
                                                    TS, context)

            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)
            PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_HAS_SLACK
            # Limit
            @test 30. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1],"S1"])
            @test 30. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1],"S2"])

            @test 30. ≈ value(result.limitable_model.p_limit["wind_1_1",TS[1], "S1"])
            @test 30. ≈ value(result.limitable_model.p_limit["wind_1_1",TS[1], "S2"])

            # active limits ?
            @test 1 ≈ value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S1"])
            @test 30. ≈ value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S1"])
            @test 1 ≈ value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S2"])
            @test 30. ≈ value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S2"])
            @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09
            @test 30. ≈ value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S2"])
        end

        #=
        TS: [11h]
        S: [S1]
                            bus 1
                            |
        (limitable) wind_1_1|load
        Pmin=0, Pmax=100    | S1: 30
        Csta=0, Cprop=1     | S2: 60
        S1: 30            |
        S2: 60            |
        =#
        @testset "tso_no_need_for_limit" begin
            TS = [DateTime("2015-01-01T11:00:00")]
            ech = DateTime("2015-01-01T10:00:00")
            network = PSCOPF.Networks.Network()
            # Buses
            PSCOPF.Networks.add_new_bus!(network, "bus_1")
            # Limitables
            PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                    0., 100.,
                                                    0., 1.,
                                                    Dates.Second(90*60), Dates.Second(90*60))
            # Uncertainties
            uncertainties = PSCOPF.Uncertainties()
            # initial generators state : need to pay starting cost at TS[1]
            generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()
            #ManagementMode
            mode = PSCOPF.ManagementMode("test_mode", Dates.Minute(5))


            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S1", 30.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S1", 30.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "wind_1_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)
            PSCOPF.add_uncertainty!(uncertainties, ech, "bus_1", DateTime("2015-01-01T11:00:00"), "S2", 60.)

            # firmness
            firmness = PSCOPF.Firmness(
                    SortedDict(),
                    SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED), )
                    )

            context = PSCOPF.PSCOPFContext(network, TS, mode,
                                            generators_init_state,
                                            uncertainties, nothing)
            tso = PSCOPF.TSOOutFO()

            @test firmness == PSCOPF.compute_firmness(tso,
                                                    ech, DateTime("2015-01-01T10:40:00"),
                                                    TS, context)

            result = PSCOPF.run(tso, ech, firmness,
                        PSCOPF.get_target_timepoints(context),
                        context)
            PSCOPF.update_tso_schedule!(context, ech, result, firmness, tso)

            # Solution is optimal
            @test PSCOPF.get_status(result) == PSCOPF.pscopf_OPTIMAL
            # Limit
            @test 30. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1],"S1"])
            @test 60. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1],"S2"])

            @test ( 60. -1e-09 < value(result.limitable_model.p_limit["wind_1_1",TS[1], "S1"]) < 100 +1e-09 ) # betwen 60 and 100
            @test ( 60. -1e-09 < value(result.limitable_model.p_limit["wind_1_1",TS[1], "S2"]) < 100 +1e-09 ) # betwen 60 and 100

            # active limits ?
            @test value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S1"]) < 1e-09
            @test value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S1"]) < 1e-09
            @test value(result.limitable_model.b_is_limited["wind_1_1",TS[1], "S2"]) < 1e-09
            @test value(result.limitable_model.p_limit_x_is_limited["wind_1_1",TS[1], "S2"]) < 1e-09
            @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S1"]) < 1e-09
            @test value(result.lol_model.p_loss_of_load["bus_1", TS[1], "S2"]) < 1e-09
        end

    end

end