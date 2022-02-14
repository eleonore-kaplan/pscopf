using PSCOPF

using Test
using Dates

@testset "test_tso_actions" begin

    ts = Dates.DateTime("2015-01-01T14:00:00")

    @testset "empty" begin
        tso_actions = PSCOPF.TSOActions()

        @test ismissing( PSCOPF.get_limitation(tso_actions, "lim_1", ts, "S1") )
        @test ismissing( PSCOPF.get_limitation(tso_actions, "lim_1", ts) )
        @test ismissing( PSCOPF.get_limitations_uncertain_value(tso_actions, "lim_1", ts) )
        @test ismissing( PSCOPF.get_limitations(tso_actions, "lim_1") )

        @test ismissing( PSCOPF.get_imposition(tso_actions, "imp", ts, "S1") )
        @test ismissing( PSCOPF.get_imposition(tso_actions, "imp", ts) )
        @test ismissing( PSCOPF.get_impositions_uncertain_value(tso_actions, "imp", ts) )
        @test ismissing( PSCOPF.get_impositions(tso_actions, "imp") )
    end

    @testset "definitive_value" begin
        tso_actions = PSCOPF.TSOActions()
        PSCOPF.set_definitive_limitation_value!(tso_actions, "lim_1", ts, 300.)
        PSCOPF.set_definitive_limitation_value!(tso_actions, "lim_2", ts, 90.)
        PSCOPF.set_definitive_imposition_value!(tso_actions, "imp", ts, 50.)

        @test length( PSCOPF.get_limitations(tso_actions) ) == 2
        @test length( PSCOPF.get_limitations(tso_actions, "lim_1") ) == 1
        @test length( PSCOPF.get_limitations(tso_actions, "lim_2") ) == 1

        @test PSCOPF.get_limitation(tso_actions, "lim_1", ts) == 300.

        @test PSCOPF.get_limitation(tso_actions, "lim_2", ts, "S1") == 90.
        @test PSCOPF.get_limitation(tso_actions, "lim_2", ts, "S99") == 90.
        @test PSCOPF.get_limitation(tso_actions, "lim_2", ts) == 90.
        @test isa( PSCOPF.get_limitations_uncertain_value(tso_actions, "lim_2", ts) , PSCOPF.UncertainValue{Float64})
        @test PSCOPF.get_value(PSCOPF.get_limitations_uncertain_value(tso_actions, "lim_2", ts)) == 90.

        @test length( PSCOPF.get_impositions(tso_actions) ) == 1
        @test length( PSCOPF.get_impositions(tso_actions, "imp") ) == 1

        @test PSCOPF.get_imposition(tso_actions, "imp", ts, "S1") == 50.
        @test PSCOPF.get_imposition(tso_actions, "imp", ts, "S101") == 50.
        @test PSCOPF.get_imposition(tso_actions, "imp", ts) == 50.
        @test isa( PSCOPF.get_impositions_uncertain_value(tso_actions, "imp", ts) , PSCOPF.UncertainValue{Float64})
        @test PSCOPF.get_value(PSCOPF.get_impositions_uncertain_value(tso_actions, "imp", ts)) == 50.
    end

    @testset "by_scenario" begin
        tso_actions = PSCOPF.TSOActions()
        PSCOPF.set_limitation_value!(tso_actions, "gen_1", ts, "S1", 10.)
        PSCOPF.set_limitation_value!(tso_actions, "gen_1", ts, "S2", 12.)

        @test length( PSCOPF.get_limitations(tso_actions) ) == 1
        @test length( PSCOPF.get_limitations(tso_actions, "gen_1") ) == 1

        @test PSCOPF.get_limitation(tso_actions, "gen_1", ts, "S1") == 10.
        @test PSCOPF.get_limitation(tso_actions, "gen_1", ts, "S2") == 12.
        @test ismissing( PSCOPF.get_limitation(tso_actions, "gen_1", ts, "S99") )
        @test ismissing( PSCOPF.get_limitation(tso_actions, "gen_1", ts) )
        @test isa( PSCOPF.get_limitations_uncertain_value(tso_actions, "gen_1", ts) , PSCOPF.UncertainValue{Float64})
        @test ismissing( PSCOPF.get_value(PSCOPF.get_limitations_uncertain_value(tso_actions, "gen_1", ts)) )
    end

end
