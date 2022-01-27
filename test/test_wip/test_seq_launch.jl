using PSCOPF

using Dates
using DataStructures

@testset verbose=true "test_sequence_launch" begin

    @testset "execution_mode_1" begin
        grid = PSCOPF.Grid()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        mode = PSCOPF.PSCOPF_MODE_1
        ECH = PSCOPF.generate_ech(grid, TS, mode)

        sequence = PSCOPF.generate_sequence(grid, TS, ECH, mode)

        exec_context = PSCOPF.PSCOPFContext(PSCOPF.Grid(), TS, ECH, mode, PSCOPF.Planning("TSO"), PSCOPF.Planning("Market"))
        PSCOPF.run!(exec_context, sequence)
    end

end