using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_seq_launch" begin

    @testset "execution_mode_1" begin
        println("\n\n\n")
        network = PSCOPF.Networks.Network()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        mode = PSCOPF.PSCOPF_MODE_1
        ECH = PSCOPF.generate_ech(network, TS, mode)

        sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

        exec_context = PSCOPF.PSCOPFContext(network, TS, mode)
        PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.Market(), ECH[1]))
        PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.TSO(), ECH[1]))
        PSCOPF.run!(exec_context, sequence)
    end

    @testset "execution_mode_2" begin
        println("\n\n\n")
        network = PSCOPF.Networks.Network()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        mode = PSCOPF.PSCOPF_MODE_2
        ECH = PSCOPF.generate_ech(network, TS, mode)

        sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

        exec_context = PSCOPF.PSCOPFContext(network, TS, mode)
        PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.Market(), ECH[1]))
        PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.TSO(), ECH[1]))
        PSCOPF.run!(exec_context, sequence)
    end

    @testset "execution_mode_3" begin
        println("\n\n\n")
        network = PSCOPF.Networks.Network()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        mode = PSCOPF.PSCOPF_MODE_3
        ECH = PSCOPF.generate_ech(network, TS, mode)

        sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

        exec_context = PSCOPF.PSCOPFContext(network, TS, mode)
        PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.Market(), ECH[1]))
        PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.TSO(), ECH[1]))
        PSCOPF.run!(exec_context, sequence)
    end

end
