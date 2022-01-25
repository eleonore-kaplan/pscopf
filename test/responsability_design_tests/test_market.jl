using Test
using Dates
using JuMP

@testset verbose=true "market" begin

    #=
    INPUT :
        Network := Electric grid description
        NetworkSituation := Schedule + Units state
        # MISSING current_ech := the market may need to know the upcomming horizon points (i.e. the current ech) to define what to fix for example
    EXPECTED OUTPUT :
        A new NetworkSituation
    =#
    @testset "mode_1" begin
        grid = create_grid(#=FIXME initial input or mocks=#)
        ts1 #=FIXME initial input or mocks=#
        TS = create_TS(Dates.DateTime(ts1)) #ts1 .+ [Dates.Minute(0), Dates.Minute(15), Dates.Minute(30), Dates.Minute(45)]
        ech #=FIXME initial input or mocks=#
        N #=FIXME=#
        #FIXME mock uncertainties
        uncertainties = generate_uncertainties(grid, TS, [ech], uncertainties_distribution, N)
        uncertainties = get_uncertainties_for_ech(uncertainties, ech)
        initialSituation #=FIXME initial input or mocks=#

        market_instance = Mode1Market(grid, TS, ech, uncertainties, initialSituation) #FIXME or simply Mode1Market(::Session) and the Session has current_schedule(::Session) et current_ech(::Session)
                                                                    #may be it needs next_ech()
        new_network_situation = launch(market_instance)

        #FIXME TESTs :
        #UnitsState correctly updated (potentially a "shutdown" unit can be changed into "starting" ?)
        #contains the correct TS, S
        #contains correctly fixed units
        #contains correctly flexible units
        #contains null reserve (or not)
        #test the production levels and the EOD
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