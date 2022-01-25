using Test
using Dates
using JuMP

@testset verbose=true "generate_ech" begin

    #=
    INPUT :
        Network := Electric grid description
        TS := target time steps (dates d'intérêt)
        Mode de gestion = mode 1
    EXPECTED OUTPUT :
        Une liste d'échéances correspondant au mode 1:
            - TS_1 - {15mins, 30mins, 1h, 2h, 4h} ?
            - TS_1 - {DMO_i} ? TS_1 - {DP_i} ?
            - { TS_i - DMO_j } U { TS_i - DP_j }
    CARE POINTs:
        - generate_ech assumes TS is sorted and unique ?
        - generate_ech should return sorted and unique horizons ?
    =#
    @testset "mode_1" begin
        grid = create_grid(#=FIXME initial input or mocks=#)
        ts1 #=FIXME initial input or mocks=#
        TS = create_TS(Dates.DateTime(ts1)) #ts1 .+ [Dates.Minute(0), Dates.Minute(15), Dates.Minute(30), Dates.Minute(45)]
        mode = PSCOPF_MODE_1

        list_ech = generate_ech(grid, TS, mode)

        EXPECTED_ECH #=FIXME=#
        @test length(list_ech) == length(EXPECTED_ECH)
        @test list_ech == EXPECTED_ECH
    end

    @testset "mode_2" begin
        @test false
    end

    @testset "mode_3" begin
        @test false
    end

end