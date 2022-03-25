using Test
using Dates
using JuMP

@testset verbose=true "multiple_ts" begin
    data_path = joinpath(@__DIR__, "tests_data", "multiple_ts")
    TS = [Dates.DateTime("2015-01-01T11:00:00"), Dates.DateTime("2015-01-01T11:15:00")]
    ech = Dates.DateTime("2015-01-01T10:00:00")
    res_min = 0.
    res_max = 15.


    #=
    ECH: 10h,
    TS:11h, 11h15
    S: [S1,S2]
    RESERVE: [0,15]
                        bus 1                   bus 2
                        |                      |
      (imposable) prod_1|       "1_2"          |load_2
                TS1     |----------------------|TS1
                S1:   20|        100           |S1: 20
                S2:   30|                      |S2: 30
                prev: 18|                      |
                TS2     |                      |TS2
                S1  : 22|                      |S1: 22
                S2  : 33|                      |S2: 33
                prev: 21|                      |
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

            @test ( value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S1"])
                    ≈ value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S2"])
                    ≈ 20. )
            @test ( value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S1"])
                    ≈ value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S2"])
                    ≈ 22. )

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

            @test ( value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S1"])
                    ≈ value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S2"])
                    ≈ launcher.previsions["prod_1", TS[1], ech]
                    ≈ 18. )
            @test ( value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S1"])
                    ≈ value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S2"])
                    ≈ launcher.previsions["prod_1", TS[2], ech]
                    ≈ 21. )

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

            @test TestHelpers.safe_leq( value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S1"]) - value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S2"]),
                                        launcher.SCENARIOS_FLEXIBILITY )
            @test TestHelpers.safe_leq( value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S1"]) - value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S2"]),
                                        launcher.SCENARIOS_FLEXIBILITY )

            @test value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S1"]) ≈ 20.
            @test value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S2"]) ≈ 20.
            @test value(result.reserve_modeler.p_res_pos[TS[1], "S1"]) <= 1e-6
            @test value(result.reserve_modeler.p_res_pos[TS[1], "S2"]) ≈ 10.

            @test value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S1"]) ≈ 22.
            @test value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S2"]) ≈ 22.
            @test value(result.reserve_modeler.p_res_pos[TS[2], "S1"]) <= 1e-6
            @test value(result.reserve_modeler.p_res_pos[TS[2], "S2"]) ≈ 11.

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

            @test TestHelpers.safe_leq( value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S1"]) - value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S2"]),
                                        launcher.SCENARIOS_FLEXIBILITY )
            @test TestHelpers.safe_leq( value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S1"]) - value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S2"]),
                                        launcher.SCENARIOS_FLEXIBILITY )

            @test value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S1"]) ≈ 20.
            @test value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S2"]) ≈ 25.
            @test value(result.reserve_modeler.p_res_pos[TS[1], "S1"]) <= 1e-6
            @test value(result.reserve_modeler.p_res_pos[TS[1], "S2"]) ≈ 5.

            @test value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S1"]) ≈ 22.
            @test value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S2"]) ≈ 27.
            @test value(result.reserve_modeler.p_res_pos[TS[2], "S1"]) <= 1e-6
            @test value(result.reserve_modeler.p_res_pos[TS[2], "S2"]) ≈ 6.

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

            @test TestHelpers.safe_leq( value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S1"]) - value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S2"]),
                                        launcher.SCENARIOS_FLEXIBILITY )
            @test TestHelpers.safe_leq( value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S1"]) - value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S2"]),
                                        launcher.SCENARIOS_FLEXIBILITY )

            @test value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S1"]) ≈ 20.
            @test value(result.imposable_modeler.p_imposable["prod_1", TS[1], "S2"]) ≈ 30.
            @test value(result.reserve_modeler.p_res_pos[TS[1], "S1"]) <= 1e-6
            @test value(result.reserve_modeler.p_res_pos[TS[1], "S2"]) <= 1e-6

            @test value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S1"]) ≈ 22.
            @test value(result.imposable_modeler.p_imposable["prod_1", TS[2], "S2"]) ≈ 33.
            @test value(result.reserve_modeler.p_res_pos[TS[2], "S1"]) <= 1e-6
            @test value(result.reserve_modeler.p_res_pos[TS[2], "S2"]) <= 1e-6

            Workflow.clear_output_files(launcher);
        end

    end #testset "2bus_imposable"

end #testset "multiple_ts"
