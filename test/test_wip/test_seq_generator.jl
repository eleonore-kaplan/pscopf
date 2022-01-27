using PSCOPF

using Dates
using DataStructures


@testset verbose=true  "test_sequence_generation" begin

    # @testset "mode_1" begin
    #     grid = PSCOPF.Grid()
    #     TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
    #     mode = PSCOPF.PSCOPF_MODE_1
    #     ECH = PSCOPF.generate_ech(grid, TS, mode)

    #     sequence = PSCOPF.generate_sequence(grid, TS, ECH, mode)

    #     EXPECTED_OPERATIONS = SortedDict(
    #         DateTime("2015-01-01T07:00:00") => [PSCOPF.MarketMode1OutFO, PSCOPF.TSOMode1],
    #         DateTime("2015-01-01T10:00:00") => [PSCOPF.MarketMode1OutFO, PSCOPF.EnterFO, PSCOPF.TSOMode1],
    #         DateTime("2015-01-01T10:30:00") => [PSCOPF.MarketMode1InFO, PSCOPF.TSOMode1],
    #         DateTime("2015-01-01T10:45:00") => [PSCOPF.MarketMode1InFO, PSCOPF.TSOMode1],
    #         DateTime("2015-01-01T11:00:00") => [PSCOPF.Assessment]
    #     )

    #     @test length(sequence.operations) == length(ECH)
    #     for (ech, steps) in sequence.operations
    #         for (index,step) in enumerate(steps)
    #             @test isa(step, EXPECTED_OPERATIONS[ech][index])
    #         end
    #     end
    # end

    @testset "mode_1" begin
        grid = PSCOPF.Grid()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        mode = PSCOPF.PSCOPF_MODE_1
        ECH = PSCOPF.generate_ech(grid, TS, mode)

        sequence = PSCOPF.generate_sequence(grid, TS, ECH, mode)

        EXPECTED_OPERATIONS = SortedDict(
            DateTime("2015-01-01T07:00:00") => [PSCOPF.MarketOutFO, PSCOPF.TSOOutFO],
            DateTime("2015-01-01T10:00:00") => [PSCOPF.MarketAtFO, PSCOPF.EnterFO, PSCOPF.TSOInFO],
            DateTime("2015-01-01T10:30:00") => [PSCOPF.TSOInFO],
            DateTime("2015-01-01T10:45:00") => [PSCOPF.TSOInFO],
            DateTime("2015-01-01T11:00:00") => [PSCOPF.Assessment]
        )

        @test length(sequence.operations) == length(ECH)
        for (ech, steps) in sequence.operations
            for (index,step) in enumerate(steps)
                @test isa(step, EXPECTED_OPERATIONS[ech][index])
            end
        end
    end

    @testset "mode_2" begin
        grid = PSCOPF.Grid()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        mode = PSCOPF.PSCOPF_MODE_2
        ECH = PSCOPF.generate_ech(grid, TS, mode)

        sequence = PSCOPF.generate_sequence(grid, TS, ECH, mode)

        EXPECTED_OPERATIONS = SortedDict(
            DateTime("2015-01-01T07:00:00") => [PSCOPF.MarketOutFO, PSCOPF.TSOOutFO],
            DateTime("2015-01-01T10:00:00") => [PSCOPF.MarketOutFO, PSCOPF.EnterFO, PSCOPF.TSOBiLevel],
            DateTime("2015-01-01T10:30:00") => [PSCOPF.MarketInFO, PSCOPF.TSOBiLevel],
            DateTime("2015-01-01T10:45:00") => [PSCOPF.MarketInFO, PSCOPF.TSOBiLevel],
            DateTime("2015-01-01T11:00:00") => [PSCOPF.Assessment]
        )

        @test length(sequence.operations) == length(ECH)
        for (ech, steps) in sequence.operations
            for (index,step) in enumerate(steps)
                @test isa(step, EXPECTED_OPERATIONS[ech][index])
            end
        end
    end

    @testset "mode_3" begin
        grid = PSCOPF.Grid()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        mode = PSCOPF.PSCOPF_MODE_3
        ECH = PSCOPF.generate_ech(grid, TS, mode)

        sequence = PSCOPF.generate_sequence(grid, TS, ECH, mode)

        EXPECTED_OPERATIONS = SortedDict(
            DateTime("2015-01-01T07:00:00") => [PSCOPF.MarketOutFO, PSCOPF.TSOOutFO],
            DateTime("2015-01-01T10:00:00") => [PSCOPF.MarketOutFO, PSCOPF.EnterFO, PSCOPF.TSOAtFO],
            DateTime("2015-01-01T10:30:00") => [PSCOPF.MarketInFO],
            DateTime("2015-01-01T10:45:00") => [PSCOPF.MarketInFO],
            DateTime("2015-01-01T11:00:00") => [PSCOPF.Assessment]
        )

        @test length(sequence.operations) == length(ECH)
        for (ech, steps) in sequence.operations
            for (index,step) in enumerate(steps)
                @test isa(step, EXPECTED_OPERATIONS[ech][index])
            end
        end
    end

end
