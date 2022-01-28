using PSCOPF

using Test
using Dates
using DataStructures


@testset verbose=true  "test_sequence_generation" begin

    #=
    INPUT :
        Network := Electric grid description
        TS := target time steps (dates d'intérêt)
        Mode de gestion = mode 1
        ECH := list of horizon points as generated by the generate_ech responsibility
    EXPECTED OUTPUT :
        At each horizon point, a sequence (an ordered list of operations i.e. AbstractRunnable)
        #FIXME: Improvement: implement a singleton pattern to avoid having a lot of Market/TSO instances
                            or use structs in the Sequence and only create an instance at launch time
    CARE POINTs:
        - generate_sequences assumes TS is sorted and unique ?
        - generate_sequences assumes ECH is sorted and unique ?
    =#

    @testset "mode_1" begin
        grid = PSCOPF.Grid()
        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_1
        ECH = PSCOPF.generate_ech(grid, TS, mode)

        sequence = PSCOPF.generate_sequence(grid, TS, ECH, mode)

        EXPECTED_OPERATIONS = SortedDict(
            ts1 - Dates.Hour(4)      => [PSCOPF.EnergyMarket, PSCOPF.TSOOutFO],
            ts1 - Dates.Hour(1)      => [PSCOPF.EnergyMarketAtFO, PSCOPF.EnterFO, PSCOPF.TSOInFO],
            ts1 - Dates.Minute(30)   => [PSCOPF.TSOInFO],
            ts1 - Dates.Minute(15)   => [PSCOPF.TSOInFO],
            ts1                      => [PSCOPF.Assessment]
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
        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_2
        ECH = PSCOPF.generate_ech(grid, TS, mode)

        sequence = PSCOPF.generate_sequence(grid, TS, ECH, mode)

        EXPECTED_OPERATIONS = SortedDict(
            ts1 - Dates.Hour(4)      => [PSCOPF.EnergyMarket, PSCOPF.TSOOutFO],
            ts1 - Dates.Hour(1)      => [PSCOPF.EnergyMarketAtFO, PSCOPF.EnterFO, PSCOPF.TSOBiLevel],
            ts1 - Dates.Minute(30)   => [PSCOPF.BalanceMarket, PSCOPF.TSOBiLevel],
            ts1 - Dates.Minute(15)   => [PSCOPF.BalanceMarket, PSCOPF.TSOBiLevel],
            ts1                      => [PSCOPF.Assessment]
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
        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_3
        ECH = PSCOPF.generate_ech(grid, TS, mode)

        sequence = PSCOPF.generate_sequence(grid, TS, ECH, mode)

        EXPECTED_OPERATIONS = SortedDict(
            ts1 - Dates.Hour(4)      => [PSCOPF.EnergyMarket, PSCOPF.TSOOutFO],
            ts1 - Dates.Hour(1)      => [PSCOPF.EnergyMarket, PSCOPF.EnterFO, PSCOPF.TSOAtFOBiLevel],
            ts1 - Dates.Minute(30)   => [PSCOPF.EnergyMarket],
            ts1 - Dates.Minute(15)   => [PSCOPF.EnergyMarket],
            ts1                      => [PSCOPF.Assessment]
        )

        @test length(sequence.operations) == length(ECH)
        for (ech, steps) in sequence.operations
            for (index,step) in enumerate(steps)
                @test isa(step, EXPECTED_OPERATIONS[ech][index])
            end
        end
    end

end
