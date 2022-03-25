using PSCOPF

using Test
using Dates

@testset verbose=true "test_tso_actions" begin

    ts = Dates.DateTime("2015-01-01T14:00:00")
    ts2 = Dates.DateTime("2015-01-01T14:30:00")

    @testset "empty" begin
        tso_actions = PSCOPF.TSOActions()

        @test isempty( PSCOPF.get_limitations(tso_actions) )
        @test ismissing( PSCOPF.get_limitation(tso_actions, "lim_1", ts) )

        @test isempty( PSCOPF.get_impositions(tso_actions) )
        @test ismissing( PSCOPF.get_imposition(tso_actions, "imp", ts) )

        @test isempty( PSCOPF.get_commitments(tso_actions) )
        @test ismissing( PSCOPF.get_commitment(tso_actions, "imp", ts) )
    end

    @testset "definitive_value" begin
        tso_actions = PSCOPF.TSOActions()
        PSCOPF.set_limitation_value!(tso_actions, "lim_1", ts, 300.)
        PSCOPF.set_limitation_value!(tso_actions, "lim_2", ts, 90.)
        PSCOPF.set_imposition_value!(tso_actions, "imp", ts, 2.)
        PSCOPF.set_imposition_value!(tso_actions, "imp", ts2, 55.)
        PSCOPF.set_commitment_value!(tso_actions, "imp", ts, PSCOPF.OFF) #careful : no coherence check, imposition_value is 2. but generator is off
        PSCOPF.set_commitment_value!(tso_actions, "imp", ts2, PSCOPF.ON)

        @test length( PSCOPF.get_limitations(tso_actions) ) == 2
        @test PSCOPF.get_limitation(tso_actions, "lim_1", ts) == 300.
        @test PSCOPF.get_limitation(tso_actions, "lim_2", ts) == 90.

        @test length( PSCOPF.get_impositions(tso_actions) ) == 2
        @test PSCOPF.get_imposition(tso_actions, "imp", ts) == 2.
        @test PSCOPF.get_imposition(tso_actions, "imp", ts2) == 55.

        @test length( PSCOPF.get_commitments(tso_actions) ) == 2
        @test PSCOPF.get_commitment(tso_actions, "imp", ts) == PSCOPF.OFF
        @test PSCOPF.get_commitment(tso_actions, "imp", ts2) == PSCOPF.ON
    end

end
