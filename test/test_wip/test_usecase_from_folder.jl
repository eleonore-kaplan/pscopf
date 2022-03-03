using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_usecase_from_folder" begin

    @testset "test_2bus_mode1" begin
        data_path = joinpath(@__DIR__, "..", "..", "data", "2buses_usecase")
        out_path = joinpath(data_path, "test_out")
        rm(out_path, recursive=true, force=true)
        mode = PSCOPF.PSCOPF_MODE_1

        # load network
        network = PSCOPF.Data.pscopfdata2network(data_path)
        uncertainties = PSCOPF.PSCOPFio.read_uncertainties(data_path)
        gen_init_state = PSCOPF.PSCOPFio.read_initial_state(data_path)
        println("init_state: ", gen_init_state)

        ts1 = Dates.DateTime("2015-01-01T11:00:00")
        TS = PSCOPF.create_target_timepoints(ts1) #11h, 11h15, 11h30, 11h45

        ECH = PSCOPF.generate_ech(network, TS, mode)

        sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

        exec_context = PSCOPF.PSCOPFContext(network, TS, mode, gen_init_state, uncertainties,
                                            nothing,
                                            out_path)
        PSCOPF.run!(exec_context, sequence)
    end

end
