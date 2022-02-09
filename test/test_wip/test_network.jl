using PSCOPF

using Test
using Dates

@testset verbose=true "test_network" begin

    @testset "test_empty_network" begin
        network = PSCOPF.Networks.Network()
        println("network: ", network)
        @test length(network.buses) == 0
        @test length(network.branches) == 0
        @test length(network.generators) == 0
    end

    @testset "test_network_read" begin
        data_path = joinpath(@__DIR__, "..", "..", "2buses")
        network = PSCOPF.Data.pscopfdata2network(data_path)
        println("network: ", network)
        @test length(network.buses) == 2
        @test length(network.branches) == 1
        @test length(network.generators) == 4

        @test network.generators["alta"].type == PSCOPF.Networks.IMPOSABLE
        @test network.generators["park_city"].type == PSCOPF.Networks.IMPOSABLE
        @test network.generators["wind_1"].type == PSCOPF.Networks.LIMITABLE
        @test network.generators["wind_2"].type == PSCOPF.Networks.LIMITABLE

        @test network.generators["alta"].id == "alta"
        @test network.generators["alta"].bus_id == "poste_1_0"
        @test network.generators["alta"].p_min == 10.
        @test network.generators["alta"].p_max == 200.
        @test network.generators["alta"].start_cost == 45000.
        @test network.generators["alta"].prop_cost == 30.
        @test network.generators["alta"].dmo == Dates.Second(45000)
        @test network.generators["alta"].dp == Dates.Second(45000)

        @test network.generators["park_city"].id == "park_city"
        @test network.generators["park_city"].bus_id == "poste_1_0"
        @test network.generators["park_city"].p_min == 10.
        @test network.generators["park_city"].p_max == 100.
        @test network.generators["park_city"].start_cost == 12000.
        @test network.generators["park_city"].prop_cost == 120.
        @test network.generators["park_city"].dmo == Dates.Second(12000)
        @test network.generators["park_city"].dp == Dates.Second(12000)

        @test network.generators["wind_1"].id == "wind_1"
        @test network.generators["wind_1"].bus_id == "poste_1_0"
        @test network.generators["wind_1"].p_min == 0.
        @test network.generators["wind_1"].p_max == 50. #not used!
        @test network.generators["wind_1"].start_cost == 0.
        @test network.generators["wind_1"].prop_cost == 50.
        @test network.generators["wind_1"].dmo == Dates.Second(0)
        @test network.generators["wind_1"].dp == Dates.Second(0)

        @test network.generators["wind_2"].id == "wind_2"
        @test network.generators["wind_2"].bus_id == "poste_2_0"
        @test network.generators["wind_2"].p_min == 0.
        @test network.generators["wind_2"].p_max == 20. #not used!
        @test network.generators["wind_2"].start_cost == 0.
        @test network.generators["wind_2"].prop_cost == 50.
        @test network.generators["wind_2"].dmo == Dates.Second(0)
        @test network.generators["wind_2"].dp == Dates.Second(0)

    end

end
