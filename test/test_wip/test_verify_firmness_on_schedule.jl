using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_verify_firmness_on_schedule" begin

    c_hollow_uncertain_value = PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                SortedDict("S1"=>PSCOPF.OFF,"S2"=>missing))
    c_non_firm_uncertain_value = PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                SortedDict("S1"=>PSCOPF.OFF,"S2"=>PSCOPF.ON))
    c_same_uncertain_value = PSCOPF.UncertainValue{PSCOPF.GeneratorState}(missing,
                                                SortedDict("S1"=>PSCOPF.OFF,"S2"=>PSCOPF.OFF))
    c_definitive_uncertain_value = PSCOPF.UncertainValue{PSCOPF.GeneratorState}(PSCOPF.OFF,
                                                SortedDict("S1"=>PSCOPF.OFF,"S2"=>PSCOPF.OFF))

    p_hollow_uncertain_value = PSCOPF.UncertainValue{Float64}(missing,
                                                SortedDict("S1"=>10.,"S2"=>missing))
    p_non_firm_uncertain_value = PSCOPF.UncertainValue{Float64}(missing,
                                                SortedDict("S1"=>10.,"S2"=>15.))
    p_same_uncertain_value = PSCOPF.UncertainValue{Float64}(missing,
                                                SortedDict("S1"=>10.,"S2"=>10.))
    p_definitive_uncertain_value = PSCOPF.UncertainValue{Float64}(10.,
                                                SortedDict("S1"=>10.,"S2"=>10.))

    #=
        INPUT :
        - firmness (for commitments and power levels)
        - schedule (commitment and production)
        OUTPUT :
        - boolean indicating if the schedule is compatible with the firmness values

        Note that this does not check the schedule itself or the firmness itself
        e.g.:
            In the example we allow having a firm power level while the commitment is not
    =#
    @testset "verifies" begin
        schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                        "gen1" => PSCOPF.GeneratorSchedule("gen1",
                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_definitive_uncertain_value),
                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_definitive_uncertain_value)
                            ),
                        "gen2" => PSCOPF.GeneratorSchedule("gen2",
                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_definitive_uncertain_value),
                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                            )
                        ))

        firmness = PSCOPF.Firmness(
                    SortedDict("gen1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                                "gen2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED) ),
                    SortedDict("gen1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                                "gen2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                    )

        @test PSCOPF.verify_firmness(firmness, schedule)
    end

    @testset "violates" begin
        schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                        "gen1" => PSCOPF.GeneratorSchedule("gen1",
                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_definitive_uncertain_value),
                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_definitive_uncertain_value)
                            ),
                        "gen2" => PSCOPF.GeneratorSchedule("gen2",
                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_definitive_uncertain_value),
                            SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value) #Problematic value
                            )
                        ))

        firmness = PSCOPF.Firmness(
                    SortedDict("gen1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                                "gen2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED) ),
                    SortedDict("gen1" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED),
                                "gen2" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED))
                    )

        @test !PSCOPF.verify_firmness(firmness, schedule)
    end

    @testset "commitment" begin

        @testset "free_with_hollow" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_hollow_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "free_with_non_firm" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "free_with_same" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_same_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "free_with_definitive" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_definitive_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "to_decide_with_hollow" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_hollow_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "to_decide_with_non_firm" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "to_decide_with_same" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_same_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "to_decide_with_definitive" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_definitive_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "decided_with_hollow" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_hollow_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "decided_with_non_firm" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "decided_with_same" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_same_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "decided_with_definitive" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_definitive_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

    end

    @testset "power_level" begin

        @testset "free_with_hollow" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_hollow_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "free_with_non_firm" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "free_with_same" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_same_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "free_with_definitive" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_definitive_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "to_decide_with_hollow" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_hollow_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "to_decide_with_non_firm" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "to_decide_with_same" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_same_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "to_decide_with_definitive" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_definitive_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "decided_with_hollow" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_hollow_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "decided_with_non_firm" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_non_firm_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "decided_with_same" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_same_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED))
                        )

            @test !PSCOPF.verify_firmness(firmness, schedule)
        end

        @testset "decided_with_definitive" begin
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), Dates.DateTime("2015-01-01T11:00:00"), SortedDict(
                            "gen" => PSCOPF.GeneratorSchedule("gen",
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => c_non_firm_uncertain_value),
                                SortedDict(Dates.DateTime("2015-01-01T11:00:00") => p_definitive_uncertain_value)
                                )
                            ))

            firmness = PSCOPF.Firmness(
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)),
                        SortedDict("gen" => SortedDict(Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED))
                        )

            @test PSCOPF.verify_firmness(firmness, schedule)
        end

    end
end
