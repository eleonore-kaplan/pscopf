using PSCOPF

using Test
using Dates
using DataStructures


@testset verbose=true  "test_seq_generator" begin

    #=
    INPUT :
        Network := Electric grid description
        TS := target time steps (dates d'intérêt)
        Mode de gestion = mode 1
        ECH := list of horizon points as generated by the generate_ech responsibility
    EXPECTED OUTPUT :
        At each horizon point, a sequence (an ordered list of operations i.e. AbstractRunnable)
    CARE POINTs:
        - generate_sequences assumes TS is sorted and unique ?
        - generate_sequences assumes ECH is sorted and unique ?
    =#

    @testset "mode_1" begin
        network = PSCOPF.Networks.Network()
        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_1
        ECH = PSCOPF.generate_ech(network, TS, mode)

        sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

        EXPECTED_OPERATIONS = SortedDict(
            ts1 - Dates.Hour(4)      => [PSCOPF.EnergyMarket, PSCOPF.TSOOutFO],
            ts1 - Dates.Hour(1)      => [PSCOPF.EnergyMarketAtFO, PSCOPF.EnterFO, PSCOPF.TSOInFO],
            ts1 - Dates.Minute(30)   => [PSCOPF.TSOInFO],
            ts1 - Dates.Minute(15)   => [PSCOPF.TSOInFO],
            ts1                      => [PSCOPF.Assessment]
        )

        @test length(sequence) == length(ECH)
        for (ech, steps) in sequence.operations
            for (index,step) in enumerate(steps)
                @test isa(step, EXPECTED_OPERATIONS[ech][index])
            end
        end
    end

    @testset "mode_2" begin
        network = PSCOPF.Networks.Network()
        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_2
        ECH = PSCOPF.generate_ech(network, TS, mode)

        sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

        EXPECTED_OPERATIONS = SortedDict(
            ts1 - Dates.Hour(4)      => [PSCOPF.EnergyMarket, PSCOPF.TSOOutFO],
            ts1 - Dates.Hour(1)      => [PSCOPF.EnergyMarketAtFO, PSCOPF.EnterFO, PSCOPF.TSOBiLevel],
            ts1 - Dates.Minute(30)   => [PSCOPF.BalanceMarket, PSCOPF.TSOBiLevel],
            ts1 - Dates.Minute(15)   => [PSCOPF.BalanceMarket, PSCOPF.TSOBiLevel],
            ts1                      => [PSCOPF.Assessment]
        )

        @test length(sequence) == length(ECH)
        for (ech, steps) in sequence.operations
            for (index,step) in enumerate(steps)
                @test isa(step, EXPECTED_OPERATIONS[ech][index])
            end
        end
    end

    @testset "mode_3" begin
        network = PSCOPF.Networks.Network()
        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1)
        mode = PSCOPF.PSCOPF_MODE_3
        ECH = PSCOPF.generate_ech(network, TS, mode)

        sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

        EXPECTED_OPERATIONS = SortedDict(
            ts1 - Dates.Hour(4)      => [PSCOPF.EnergyMarket, PSCOPF.TSOOutFO],
            ts1 - Dates.Hour(1)      => [PSCOPF.EnergyMarket, PSCOPF.EnterFO, PSCOPF.TSOAtFOBiLevel],
            ts1 - Dates.Minute(30)   => [PSCOPF.EnergyMarket],
            ts1 - Dates.Minute(15)   => [PSCOPF.EnergyMarket],
            ts1                      => [PSCOPF.Assessment]
        )

        @test length(sequence) == length(ECH)
        for (ech, steps) in sequence.operations
            for (index,step) in enumerate(steps)
                @test isa(step, EXPECTED_OPERATIONS[ech][index])
            end
        end
    end

end
