using PSCOPF

using Test
using Dates

@testset "test_modes" begin

    @testset "mode1" begin
        @test PSCOPF.PSCOPF_MODE_1.name == "mode_1"
        @test PSCOPF.get_fo_length(PSCOPF.PSCOPF_MODE_1) == Dates.Minute(60)
    end

    @testset "mode2" begin
        @test PSCOPF.PSCOPF_MODE_2.name == "mode_2"
        @test PSCOPF.get_fo_length(PSCOPF.PSCOPF_MODE_2) == Dates.Minute(60)
    end

    @testset "mode3" begin
        @test PSCOPF.PSCOPF_MODE_3.name == "mode_3"
        @test PSCOPF.get_fo_length(PSCOPF.PSCOPF_MODE_3) == Dates.Minute(60)
    end

end
