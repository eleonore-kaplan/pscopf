using PSCOPF

using Test
using Dates

@testset verbose=true "test_network" begin

    @testset "test_network_obj" begin
        network = PSCOPF.Networks.Network("test_network")
        println("network: ", network)
    end

    @testset "test_network_read" begin
        data_path = joinpath(@__DIR__, "..", "..", "2buses")
        network = PSCOPF.Data.pscopfdata2network(data_path)
        println("network: ", network)
    end

end
