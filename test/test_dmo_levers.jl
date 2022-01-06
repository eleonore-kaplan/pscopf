using Test
using Dates
using JuMP

@testset verbose=true "dmo_levers" begin
    data_path = joinpath(@__DIR__, "tests_data", "dmo_levers")
    ts = Dates.DateTime("2015-01-01T11:00:00")
    ech = Dates.DateTime("2015-01-01T10:00:00")
    res_min = 0.
    res_max = 15.


    #=
    ECH: 10h, TS:11h,
    S: [S1,S2]
    RESERVE: [0,15]
                        bus 1                   bus 2
                        |                      |
      (imposable) prod_1|       "1_2"          |load_2
                prev:18 |----------------------|
                S1: 20  |        100           | S1: 20
                S2: 30  |                      | S2: 30
    =#
    @testset verbose=true "2bus_imposable" begin
        dir_path = joinpath(data_path, "2bus_imposable")

        #=
        DMO
        ECH            TS
        |-------------|

        when DMO=ECH, production level needs to be fixed across all scenarios with the same decided value
        =#
        @info "dmo_equal_to_ech"
        @testset "dmo_equal_to_ech" begin
            launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_dmo_equal_to_ech"));

            dmo_l = Dates.value(Second(Hour(1)))
            launcher.units["prod_1"][5] = dmo_l

            result = Workflow.sc_opf(launcher, ech, res_min, res_max)

            @test result.status == Workflow.pscopf_OPTIMAL

            @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) ≈ value(result.imposable_modeler.p_imposable["prod_1", ts, "S2"]) ≈ 20.

            Workflow.clear_output_files(launcher);
        end

        #=
        DMO           ECH            TS
        |-------------|-------------|

        since DMO>ECH, production level was already fixed by horizon ECH
        the production level is set to the value read from launcher.previsions
        =#
        @info "dmo_greater_than_ech"
        @testset "dmo_greater_than_ech" begin
            launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_dmo_greater_than_ech"));

            dmo_l = Dates.value(Second(Hour(2)))
            launcher.units["prod_1"][5] = dmo_l

            result = Workflow.sc_opf(launcher, ech, res_min, res_max)

            @test result.status == Workflow.pscopf_OPTIMAL

            @test ( value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"])
                    ≈ value(result.imposable_modeler.p_imposable["prod_1", ts, "S2"])
                    ≈ launcher.previsions["prod_1", ts, ech]
                    ≈ 18.)

            Workflow.clear_output_files(launcher);
        end

        #=
        ECH    DMO     TS
        |------|------|
        since ECH>DMO, production level is flexible and governed by SCENARIOS_FLEXIBILITY
        Here 0, => no flexibility : values are the same across the scenarios
        =#
        @info "dmo_less_than_ech_0"
        @testset "dmo_less_than_ech_0" begin
            launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_dmo_less_than_ech_0"));

            launcher.SCENARIOS_FLEXIBILITY = 0.
            dmo_l = Dates.value(Second(Minute(30)))
            launcher.units["prod_1"][5] = dmo_l

            result = Workflow.sc_opf(launcher, ech, res_min, res_max)

            @test result.status == Workflow.pscopf_OPTIMAL

            @test TestHelpers.safe_leq( abs( value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) - value(result.imposable_modeler.p_imposable["prod_1", ts, "S2"]) ),
                                        launcher.SCENARIOS_FLEXIBILITY)
            @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) ≈ 20.
            @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S2"]) ≈ 20.
            @test value(result.reserve_modeler.p_res_pos[ts, "S1"]) ≈ 0.
            @test value(result.reserve_modeler.p_res_pos[ts, "S2"]) ≈ 10.

            Workflow.clear_output_files(launcher);
        end

        #=
        ECH    DMO     TS
        |------|------|

        since ECH>DMO, production level is flexible and governed by SCENARIOS_FLEXIBILITY
        Here 5, => a delta of 5 is allowed between the different scenarios production levels
        =#
        @info "dmo_less_than_ech_5"
        @testset "dmo_less_than_ech_5" begin
            launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_dmo_less_than_ech_5"));

            launcher.SCENARIOS_FLEXIBILITY = 5.
            dmo_l = Dates.value(Second(Minute(30)))
            launcher.units["prod_1"][5] = dmo_l

            result = Workflow.sc_opf(launcher, ech, res_min, res_max)

            @test result.status == Workflow.pscopf_OPTIMAL

            @test TestHelpers.safe_leq( abs( value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) - value(result.imposable_modeler.p_imposable["prod_1", ts, "S2"]) ),
                                        launcher.SCENARIOS_FLEXIBILITY)
            @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) ≈ 20.
            @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S2"]) ≈ 25.
            @test value(result.reserve_modeler.p_res_pos[ts, "S1"]) ≈ 0.
            @test value(result.reserve_modeler.p_res_pos[ts, "S2"]) ≈ 5.

            Workflow.clear_output_files(launcher);
        end

        #=
        ECH    DMO     TS
        |------|------|

        since ECH>DMO, production level is flexible and governed by SCENARIOS_FLEXIBILITY
        Here 200, => production levels per scenario are free
        =#
        @info "dmo_less_than_ech_200"
        @testset "dmo_less_than_ech_200" begin
            launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_dmo_less_than_ech_200"));

            dmo_l = Dates.value(Second(Minute(30)))
            launcher.units["prod_1"][5] = dmo_l

            result = Workflow.sc_opf(launcher, ech, res_min, res_max)
            @test launcher.SCENARIOS_FLEXIBILITY ≈ 200.

            @test result.status == Workflow.pscopf_OPTIMAL

            @test TestHelpers.safe_leq( abs( value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) - value(result.imposable_modeler.p_imposable["prod_1", ts, "S2"]) ),
                                        launcher.SCENARIOS_FLEXIBILITY)
            @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) ≈ 20.
            @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S2"]) ≈ 30.
            @test value(result.reserve_modeler.p_res_pos[ts, "S1"]) ≈ 0.
            @test value(result.reserve_modeler.p_res_pos[ts, "S2"]) ≈ 0.

            Workflow.clear_output_files(launcher);
        end

    end #testset "2bus_imposable"

    #=
    ECH: 10h, TS:11h,
    S: [S1,S2]
    RESERVE: [0,15]
                        bus 1                   bus 2
                        |                      |
     (limitable) wind_1 |       "1_2"          |load_2
                prev:18 |----------------------|
                S1: 20  |        100           | S1: 20
                S2: 32  |                      | S2: 30

    =#
    @testset verbose=true "2bus_limitable" begin
        dir_path = joinpath(data_path, "2bus_limitable")

        #=
        limitable units don't consider the dmo
        They always have the same limit across scenarios (here, 30)
        But, not necessarily the same injected power (here, 20 in S1 and 30 in S2)
        =#
        @info "limitable"
        @testset "limitable" begin
            launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_limitable"));

            result = Workflow.sc_opf(launcher, ech, res_min, res_max)

            @test result.status == Workflow.pscopf_OPTIMAL

            @test ( value(result.limitable_modeler.p_lim["wind_1", ts]) ≈ 30.)
            @test ( value(result.limitable_modeler.p_enr["wind_1", ts, "S1"]) ≈ 20.)
            @test ( value(result.limitable_modeler.p_enr["wind_1", ts, "S2"]) ≈ 30.)

            Workflow.clear_output_files(launcher);
        end

    end  #testset "2bus_limitable"

end #testset "dmo_levers"
