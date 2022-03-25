using PSCOPF

using Test
using Dates

@testset "test_check_timesteps" begin

    @testset "definition_example" begin
        TS = [DateTime("2015-01-01T11:00:00"),
            DateTime("2015-01-01T11:15:00"),
            DateTime("2015-01-01T11:30:00"),
            DateTime("2015-01-01T11:45:00")]

        @test PSCOPF.check_target_timepoints(TS)
    end

    @testset "not_sorted" begin
        TS = [DateTime("2015-01-01T11:15:00"),
            DateTime("2015-01-01T11:00:00"),
            DateTime("2015-01-01T11:30:00"),
            DateTime("2015-01-01T11:45:00")]

        @test !PSCOPF.check_target_timepoints(TS)
    end

    @testset "duplicate_value" begin
        TS = [DateTime("2015-01-01T11:00:00"),
            DateTime("2015-01-01T11:00:00"),
            DateTime("2015-01-01T11:30:00"),
            DateTime("2015-01-01T11:45:00")]

        @test !PSCOPF.check_target_timepoints(TS)
    end

    #=
    # FIXME Do we assume it is 1 hour with 4 equally spaced Timesteps ?
    # not for now, to allow simple test cases
    # i.e.:
    #       length(TS) == 4
    #       TS[i] - TS[i-1] == 15 mins
    @testset "duplicate_value" begin
        TS = [DateTime("2015-01-01T11:00:00"),
            DateTime("2015-01-01T11:00:00"),
            DateTime("2015-01-01T11:30:00"),
            DateTime("2015-01-01T11:45:00")]

        @test !PSCOPF.check_target_timepoints(TS)
    end
    =#

end