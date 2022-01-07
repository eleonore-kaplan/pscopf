using Test
using Dates
using JuMP

@testset verbose=true "feasibility_slacks" begin
    data_path = joinpath(@__DIR__, "tests_data", "feasibility_slacks")
    ts = Dates.DateTime("2015-01-01T11:00:00")
    ech = Dates.DateTime("2015-01-01T10:00:00")
    res_min = 0.
    res_max = 0.

    #=
    ECH: 10h, TS:11h,
    S: [S1]
    RESERVE: [0]
                        bus 1                   bus 2
                        |                      |
      (imposable) prod_1|       "1_2"          |load_2
                prev:18 |----------------------|
                S1: 22  |        100           | S1: 22
                Pmin=25 |                      |
                dmo=0   |                      |
                        |                      |

    The solution should not be feasible but since the production level set in uncertainties allow this, the solution is accepted
    (This is due to the Pmin-Pmax constraint being applied on p_imp and not on p_imposable)
    =#
    @info "feasible"
    @testset "feasible" begin
        dir_path = joinpath(data_path, "feasible")
        launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_"));

        Workflow.clear_output_files(launcher);
        result = Workflow.sc_opf(launcher, ech, res_min, res_max)

        @test result.status == Workflow.pscopf_OPTIMAL

        @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) ≈ 22.
        @test value(result.imposable_modeler.p_is_imp["prod_1", ts, "S1"]) < 1e-6
        @test value(result.slack_modeler.p_cut_prod["prod_1", ts, "S1"]) < 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus1", ts, "S1"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus2", ts, "S1"]) <= 1e-6
    end

    #=
    ECH: 10h, TS:11h,
    S: [S1]
    RESERVE: [0]
                        bus 1                   bus 2
                        |                      |
      (imposable) prod_1|       "1_2"          |load_2
                prev:18 |----------------------|
                S1: 0   |        100           | S1: 22
                Pmin=25 |                      |
                dmo=0   |                      |
                        |                      |
    =#
    @info "cut_prod"
    @testset "cut_prod" begin
        dir_path = joinpath(data_path, "cut_prod")
        launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_"));

        Workflow.clear_output_files(launcher);
        result = Workflow.sc_opf(launcher, ech, res_min, res_max)

        @test result.status == Workflow.pscopf_CUT_PROD

        @test value(result.reserve_modeler.p_res_pos[ts, "S1"]) ≈ 0.
        @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) ≈ 25.
        @test value(result.slack_modeler.p_cut_prod["prod_1", ts, "S1"]) ≈ 3.
        @test value(result.slack_modeler.p_cut_conso["bus1", ts, "S1"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus2", ts, "S1"]) <= 1e-6
    end

    #=
    ECH: 10h, TS:11h,
    S: [S1]
    RESERVE: [0]
                        bus 1                   bus 2
                        |                      |
      (imposable) prod_1|       "1_2"          |load_2
                prev:18 |----------------------|
                S1: 0   |        100           | S1: 22
                Pmax=20 |                      |
                dmo=0   |                      |
                        |                      |
    =#
    @info "cut_conso"
    @testset "cut_conso" begin
        dir_path = joinpath(data_path, "cut_conso")
        launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_"));

        Workflow.clear_output_files(launcher);
        result = Workflow.sc_opf(launcher, ech, res_min, res_max)

        @test result.status == Workflow.pscopf_CUT_CONSO

        @test value(result.reserve_modeler.p_res_pos[ts, "S1"]) ≈ 0.
        @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) ≈ 20.
        @test value(result.slack_modeler.p_cut_prod["prod_1", ts, "S1"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus1", ts, "S1"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus2", ts, "S1"]) ≈ 2.
    end


    #=
    ECH: 10h, TS:11h,
    S: [S1]
    RESERVE: [0]
                        bus 1                   bus 2
                        |                      |
      (imposable) prod_1|       "1_2"          |load_2
                prev:18 |----------------------|
                S1: 0   |         20           | S1: 22
                        |       => +2          |
                dmo=0   |                      |
                        |                      |
    =#
    @info "branch_slack"
    @testset "branch_slack" begin
        dir_path = joinpath(data_path, "branch_slack")
        launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_"));

        launcher.NO_CUT_PRODUCTION = true
        launcher.NO_CUT_CONSUMPTION = true

        Workflow.clear_output_files(launcher);
        result = Workflow.sc_opf(launcher, ech, res_min, res_max)

        @test result.status == Workflow.pscopf_BRANCH_SLACK

        @test value(result.reserve_modeler.p_res_pos[ts, "S1"]) ≈ 0.
        @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) ≈ 22.
        @test value(result.slack_modeler.v_branch_slack_pos["1_2", ts, "S1"]) ≈ 2.
        @test value(result.slack_modeler.v_branch_slack_neg["1_2", ts, "S1"]) <= 1e-6
    end

    #=
    ECH: 10h, TS:11h,
    S: [S1,S2]
    RESERVE: [0]
                        bus 1                   bus 2
                        |                      |
      (imposable) prod_1|       "1_2"          |load_2
                prev:18 |----------------------|
                S1: 0   |        100           | S1: 22  => need to cut prod
                S2: 0   |                      | S2: 32  => need to cut conso
                Pmin=25 |                      |
                Pmax=30 |                      |
                dmo=0   |                      |
                        |                      |
    =#
    @info "cut_prod_and_conso"
    @testset "cut_prod_and_conso" begin
        dir_path = joinpath(data_path, "cut_prod_and_conso")
        launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_"));

        Workflow.clear_output_files(launcher);
        result = Workflow.sc_opf(launcher, ech, res_min, res_max)

        @test result.status == Workflow.pscopf_SLACK_FEASIBLE

        #S1 : cut prod
        @test value(result.reserve_modeler.p_res_pos[ts, "S1"]) ≈ 0.
        @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S1"]) ≈ 25.
        @test value(result.slack_modeler.p_cut_prod["prod_1", ts, "S1"]) ≈ 3.
        @test value(result.slack_modeler.p_cut_conso["bus1", ts, "S1"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus2", ts, "S1"]) <= 1e-6
        #S2 : cut conso
        @test value(result.reserve_modeler.p_res_pos[ts, "S2"]) ≈ 0.
        @test value(result.imposable_modeler.p_imposable["prod_1", ts, "S2"]) ≈ 30.
        @test value(result.slack_modeler.p_cut_prod["prod_1", ts, "S2"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus1", ts, "S2"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus2", ts, "S2"]) ≈ 2.
    end

    #=
    ECH: 10h, TS:11h,
    S: [S1,S2]
    RESERVE: [0]
                        bus 1                   bus 2
                        |                      |
      (limitable) wind_1|       "1_2"          |load_2
                prev:18 |----------------------|
                S1: 20  |        100           | S1: 15
                S2: 25  |                      | S2: 22
                        |                      |
    =#
    @info "limitable_cut_prod"
    @testset "limitable_cut_prod" begin
        dir_path = joinpath(data_path, "limitable_cut_prod")
        launcher = Workflow.Launcher(dir_path, joinpath(dir_path, "out_"));

        Workflow.clear_output_files(launcher);
        result = Workflow.sc_opf(launcher, ech, res_min, res_max)

        @test result.status == Workflow.pscopf_CUT_PROD

        #Plim is independant of scenario
        @test value(result.limitable_modeler.p_lim["wind_1", ts]) ≈ 22.
        #S1 :
        @test value(result.reserve_modeler.p_res_pos[ts, "S1"]) ≈ 0.
        @test value(result.limitable_modeler.p_enr["wind_1", ts, "S1"]) ≈ 20.
        @test value(result.slack_modeler.p_cut_prod["wind_1", ts, "S1"]) ≈ 5.
        @test value(result.slack_modeler.p_cut_conso["bus1", ts, "S1"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus2", ts, "S1"]) <= 1e-6
        #S2 :
        @test value(result.reserve_modeler.p_res_pos[ts, "S2"]) ≈ 0.
        @test value(result.limitable_modeler.p_enr["wind_1", ts, "S2"]) ≈ 22.
        @test value(result.slack_modeler.p_cut_prod["wind_1", ts, "S2"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus1", ts, "S2"]) <= 1e-6
        @test value(result.slack_modeler.p_cut_conso["bus2", ts, "S2"]) <= 1e-6
    end

end #testset "feasibility_slacks"
