using PSCOPF

using Test
using Dates

@testset "test_check_branch" begin

    @testset "definition_example" begin
        branch = PSCOPF.Networks.Branch("branch_1_2", 1000.)
        @test PSCOPF.check(branch)
    end

    @testset "limit>0" begin
        branch = PSCOPF.Networks.Branch("branch_1_2", -1000.)
        @test !PSCOPF.check(branch)
    end

end