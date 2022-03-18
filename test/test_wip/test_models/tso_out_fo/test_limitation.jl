using PSCOPF

using Test
using JuMP
using Dates
using DataStructures

@testset verbose=true "test_tso_out_fo_dp" begin

    #=
    TS: [11h]
    S: [S1]
                        bus 1
                        |
    (limitable) wind_1_1|load
    Pmin=0, Pmax=100    | S1: 30
    Csta=0, Cprop=1     | S2: 35
      S1: 55            |
      S2: 60            |
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
                                                Dates.Second(0), Dates.Second(0))
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
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
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
        @test 35. ≈ value(result.limitable_model.p_injected["wind_1_1",TS[1],"S2"])

        @test 35. ≈ value(result.limitable_model.p_limit["wind_1_1",TS[1]]) # should be 35 ? 30 ? 60 ? 100 ?

        # active limits ?
        @test PSCOPF.is_limited("wind_1_1",TS[1], "S1", result.limitable_model, uncertainties[ech])
        @test PSCOPF.is_limited("wind_1_1",TS[1], "S2", result.limitable_model, uncertainties[ech])
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"]) < 1e-09
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S2"]) < 1e-09
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
    @testset "tso_chooses_injection_level" begin
        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T10:00:00")
        network = PSCOPF.Networks.Network()
        # Buses
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
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
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
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

        @test 60. ≈ value(result.limitable_model.p_limit["wind_1_1",TS[1]])

        # active limits ?
        @test PSCOPF.is_limited("wind_1_1",TS[1], "S1", result.limitable_model, uncertainties[ech])
        @test ! PSCOPF.is_limited("wind_1_1",TS[1], "S2", result.limitable_model, uncertainties[ech])
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"]) < 1e-09
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S2"]) < 1e-09
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
    @testset "tso_chooses_injection_level" begin
        TS = [DateTime("2015-01-01T11:00:00")]
        ech = DateTime("2015-01-01T10:00:00")
        network = PSCOPF.Networks.Network()
        # Buses
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        # Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_1", PSCOPF.Networks.LIMITABLE,
                                                0., 100.,
                                                0., 1.,
                                                Dates.Second(0), Dates.Second(0))
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
                SortedDict("wind_1_1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE), )
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

        @test 60. ≈ value(result.limitable_model.p_limit["wind_1_1",TS[1]]) # should be 60 ? 70 ? 100 ?

        # active limits ?
        @test PSCOPF.is_limited("wind_1_1",TS[1], "S1", result.limitable_model, uncertainties[ech])
        @test ! PSCOPF.is_limited("wind_1_1",TS[1], "S2", result.limitable_model, uncertainties[ech])
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S1"]) < 1e-09
        @test value(result.slack_model.p_cut_conso["bus_1", TS[1], "S2"]) < 1e-09
    end


end