using PSCOPF

using Test
using Dates
using DataStructures

@testset "test_verify_firmness" begin

    hollow_uncertain_value = PSCOPF.UncertainValue{Int64}(missing,
                                                SortedDict("S1"=>10,"S2"=>missing))
    non_firm_uncertain_value = PSCOPF.UncertainValue{Int64}(missing,
                                                SortedDict("S1"=>10,"S2"=>15))
    same_uncertain_value = PSCOPF.UncertainValue{Int64}(missing,
                                                SortedDict("S1"=>10,"S2"=>10))
    definitive_uncertain_value = PSCOPF.UncertainValue{Int64}(10,
                                                SortedDict("S1"=>10,"S2"=>10))

    @testset "verifies_on_generator_schedule" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE,
            Dates.DateTime("2015-01-01T11:30:00") => PSCOPF.FREE,
            Dates.DateTime("2015-01-01T12:00:00") => PSCOPF.TO_DECIDE,
            Dates.DateTime("2015-01-01T13:00:00") => PSCOPF.DECIDED )

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => non_firm_uncertain_value,
            Dates.DateTime("2015-01-01T11:30:00") => same_uncertain_value,
            Dates.DateTime("2015-01-01T12:00:00") => definitive_uncertain_value,
            Dates.DateTime("2015-01-01T13:00:00") => definitive_uncertain_value )

        @test PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "violates_on_generator_schedule" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE,
            Dates.DateTime("2015-01-01T11:30:00") => PSCOPF.FREE,
            Dates.DateTime("2015-01-01T12:00:00") => PSCOPF.TO_DECIDE,
            Dates.DateTime("2015-01-01T13:00:00") => PSCOPF.DECIDED )

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => non_firm_uncertain_value,
            Dates.DateTime("2015-01-01T11:30:00") => same_uncertain_value,
            Dates.DateTime("2015-01-01T12:00:00") => non_firm_uncertain_value, # the problematic value
            Dates.DateTime("2015-01-01T13:00:00") => definitive_uncertain_value )

        @test !PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "missing_schedule_value" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T10:00:00") => PSCOPF.FREE, #No corresponding value in schedule
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => hollow_uncertain_value)

        @test !PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "ignored_schedule_values" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T10:00:00") => hollow_uncertain_value, # No firmness constraint
            Dates.DateTime("2015-01-01T11:00:00") => non_firm_uncertain_value)

        @test PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "free_with_hollow" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => hollow_uncertain_value)

        @test !PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "free_with_non_firm" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => non_firm_uncertain_value)

        @test PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "free_with_same" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => same_uncertain_value)

        @test PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "free_with_definitive" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.FREE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => definitive_uncertain_value)

        @test PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end


    @testset "decided_with_hollow" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => hollow_uncertain_value)

        @test !PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "decided_with_non_firm" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => non_firm_uncertain_value)

        @test !PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "decided_with_same" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => same_uncertain_value)

        @test !PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "decided_with_definitive" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.DECIDED)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => definitive_uncertain_value)

        @test PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "to_decided_with_hollow" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => hollow_uncertain_value)

        @test !PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "to_decided_with_non_firm" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => non_firm_uncertain_value)

        @test !PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "to_decided_with_same" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => same_uncertain_value)

        @test !PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

    @testset "to_decided_with_definitive" begin
        generator_firmness = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => PSCOPF.TO_DECIDE)

        scheduled_values = SortedDict(
            Dates.DateTime("2015-01-01T11:00:00") => definitive_uncertain_value)

        @test PSCOPF.verify_firmness(generator_firmness, scheduled_values)
    end

end
