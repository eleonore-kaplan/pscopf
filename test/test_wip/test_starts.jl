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

        @testset "test_starts_from_schedule" begin
            schedule = PSCOPF.Schedule(PSCOPF.Utilitary(), DateTime("2015-01-01T06:00:00"), SortedDict(
                    "gen1" => PSCOPF.GeneratorSchedule("gen1",
                        SortedDict(TS[1]=> PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()),
                                    TS[2] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()),
                                    TS[3] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF, SortedDict()),
                                    TS[4] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()),
                                    ),
                        SortedDict(),
                        ),
                    "gen2" => PSCOPF.GeneratorSchedule("gen2",
                        SortedDict(TS[1]=> PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()),
                                    TS[2] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()),
                                    TS[3] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()),
                                    TS[4] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()),
                                    ),
                        SortedDict(),
                        ),
                    "gen3" => PSCOPF.GeneratorSchedule("gen3",
                        SortedDict(TS[1]=> PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF, SortedDict()),
                                    TS[2] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()),
                                    TS[3] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF, SortedDict()),
                                    TS[4] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()),
                                    ),
                        SortedDict(),
                        )
                    )
            )

            result = PSCOPF.get_starts(schedule, initial_state)
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

    @testset "test_starts_from_schedule_ignores_non_definitive_starts" begin
        initial_state = SortedDict{String, PSCOPF.GeneratorState}(
            "unit_1" => PSCOPF.OFF,
        )

        schedule = PSCOPF.Schedule(PSCOPF.Utilitary(), DateTime("2015-01-01T06:00:00"), SortedDict(
                "unit_1" => PSCOPF.GeneratorSchedule("unit_1",
                    SortedDict(TS[1]=> PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing, SortedDict("S1"=>PSCOPF.ON)), # non definitive start
                                TS[2] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing, SortedDict("S1"=>PSCOPF.ON)),
                                TS[3] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing, SortedDict("S1"=>PSCOPF.ON)),
                                TS[4] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing, SortedDict("S1"=>PSCOPF.ON)),
                                ),
                    SortedDict(),
                    )
                )
        )

        result = PSCOPF.get_starts(schedule, initial_state)
        @test isempty(result)
    end

    @testset "test_starts_from_schedule_breaks_at_first_non_definitive_value" begin
        initial_state = SortedDict{String, PSCOPF.GeneratorState}(
            "unit_1" => PSCOPF.OFF,
        )

        schedule = PSCOPF.Schedule(PSCOPF.Utilitary(), DateTime("2015-01-01T06:00:00"), SortedDict(
                "unit_1" => PSCOPF.GeneratorSchedule("unit_1",
                    SortedDict(TS[1]=> PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()), # definitive start
                                TS[2] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing, SortedDict()), # Non-definitive value => later values will be ignored
                                TS[3] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF, SortedDict()),
                                TS[4] => PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.ON, SortedDict()), # ignored start
                                ),
                    SortedDict(),
                    ),
                )
        )

        # ("unit_1", TS[4]) is not reported
        #  because it is preceded by non-definitive commitment at TS[2]
        #  even if TS[3] is definitive
        #  This should not happen in PSCOPF launches
        expected = Set{Tuple{String,Dates.DateTime}}([
            ("unit_1", TS[1])
        ])

        result = PSCOPF.get_starts(schedule, initial_state)
        @test result == expected
    end

end
