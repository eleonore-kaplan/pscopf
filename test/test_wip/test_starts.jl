using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_starts" begin

    TS = [DateTime("2015-01-01T11:00:00"), DateTime("2015-01-01T11:15:00"), DateTime("2015-01-01T11:30:00"), DateTime("2015-01-01T11:45:00")]

    initial_state = SortedDict{String, PSCOPF.GeneratorState}(
            "gen1" => PSCOPF.ON,
            "gen2" => PSCOPF.OFF,
            "gen3" => PSCOPF.OFF,
        )

    commitments = SortedDict{Tuple{String, Dates.DateTime}, PSCOPF.GeneratorState}(
        ("gen1", TS[1]) => PSCOPF.ON,
        ("gen1", TS[2]) => PSCOPF.ON,
        ("gen1", TS[3]) => PSCOPF.OFF,
        ("gen1", TS[4]) => PSCOPF.ON,#start

        ("gen2", TS[1]) => PSCOPF.ON,#start
        ("gen2", TS[2]) => PSCOPF.ON,
        ("gen2", TS[3]) => PSCOPF.ON,
        ("gen2", TS[4]) => PSCOPF.ON,

        ("gen3", TS[1]) => PSCOPF.OFF,
        ("gen3", TS[2]) => PSCOPF.ON,#start
        ("gen3", TS[3]) => PSCOPF.OFF,
        ("gen3", TS[4]) => PSCOPF.ON,#start
    )

    expected = Set{Tuple{String,Dates.DateTime}}([
            ("gen1", TS[4]), ("gen2", TS[1]), ("gen3", TS[2]), ("gen3", TS[4])
        ])

    @testset "test_starts_testcase" begin

        @testset "test_starts_simple" begin
            result = PSCOPF.get_starts(commitments, initial_state)
            @test result == expected
        end

        @testset "test_starts_from_tso_actions" begin
            tso_actions = PSCOPF.TSOActions(commitments=commitments)

            result = PSCOPF.get_starts(tso_actions, initial_state)
            @test result == expected
        end

    end



    @testset "test_starts_if_different_timesteps_in_comitments" begin
        initial_state = SortedDict{String, PSCOPF.GeneratorState}(
            "gen1" => PSCOPF.ON,
            "gen2" => PSCOPF.OFF,
            "gen3" => PSCOPF.OFF,
        )

        commitments = SortedDict{Tuple{String, Dates.DateTime}, PSCOPF.GeneratorState}(
            ("gen1", TS[1]) => PSCOPF.ON,
            ("gen1", TS[2]) => PSCOPF.ON,
            ("gen1", TS[3]) => PSCOPF.OFF,
            ("gen1", TS[4]) => PSCOPF.ON,#start

            ("gen2", Hour(1) + TS[1]) => PSCOPF.ON,#start
            ("gen2", Hour(1) + TS[2]) => PSCOPF.ON,
            ("gen2", Hour(1) + TS[3]) => PSCOPF.ON,
            ("gen2", Hour(1) + TS[4]) => PSCOPF.ON,

            ("gen3", TS[1]) => PSCOPF.OFF,
            ("gen3", TS[2]) => PSCOPF.ON,#start
            ("gen3", TS[3]) => PSCOPF.OFF,
            ("gen3", TS[4]) => PSCOPF.ON,#start
        )

        expected = Set{Tuple{String,Dates.DateTime}}([
            ("gen1", TS[4]), ("gen2", Hour(1) + TS[1]), ("gen3", TS[2]), ("gen3", TS[4])
        ])

        result = PSCOPF.get_starts(commitments, initial_state)
        @test result == expected
    end

end
