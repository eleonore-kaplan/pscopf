using Test
using Dates
using JuMP

@testset verbose=true "tso" begin

    #=
    INPUT :
        Network := Electric grid description
        NetworkSituation := Schedule + Units state
        # MISSING current_ech := cf. test_market
    EXPECTED OUTPUT :
        A new NetworkSituation
    =#
    @testset "mode_1" begin
        grid = create_grid(#=FIXME initial input or mocks=#)
        ts1 #=FIXME initial input or mocks=#
        TS = create_TS(Dates.DateTime(ts1)) #ts1 .+ [Dates.Minute(0), Dates.Minute(15), Dates.Minute(30), Dates.Minute(45)]
        ech #=FIXME initial input or mocks=#
        N #=FIXME=#
        uncertainties = generate_uncertainties(grid, TS, [ech], uncertainties_distribution, N)
        uncertainties = get_uncertainties_for_ech(uncertainties, ech)
        initialSituation #=FIXME initial input or mocks=#

        tso_instance = Mode1TSO(grid, TS, ech, uncertainties, initialSituation) #FIXME or simply Mode1TSO(::Session) (cf. test_market)
        new_network_situation = launch(tso_instance)

        #FIXME TESTs :
        #contains the correct TS, S
        #contains correctly fixed units
        #contains correctly flexible units
        #contains null reserve (or not)
        #test the production levels, the EOD, the RSO
    end

    @testset "mode_1_FO" begin
        @test false
    end

    @testset "mode_2" begin
        @test false
    end

    @testset "mode_3" begin
        @test false
    end

end