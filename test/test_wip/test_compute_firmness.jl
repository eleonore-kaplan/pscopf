using PSCOPF

using Test
using Dates

@testset "test_compute_firmness" begin

    #=
       10h30        12h           14h
    TS-Delta        ECH            TS
           |          |             |
            <---------------------->
                    Delta
                    3h30
    =#
    @testset "ech_late" begin
        ech = Dates.DateTime("2015-01-01T12:00:00")
        ts = Dates.DateTime("2015-01-01T14:00:00")
        delta = Dates.Minute(210) #3h30

        next_ech = Dates.DateTime("2015-01-01T05:00:00")
        @test_throws ErrorException PSCOPF.compute_firmness(ech, next_ech, ts, delta)

        next_ech = Dates.DateTime("2015-01-01T13:00:00")
        @test PSCOPF.compute_firmness(ech, next_ech, ts, delta) == PSCOPF.DECIDED

        next_ech = nothing
        @test PSCOPF.compute_firmness(ech, next_ech, ts, delta) == PSCOPF.DECIDED
    end

    #=
       10h30                      14h
    TS-Delta                       TS
         ECH
           |                        |
            <---------------------->
                    Delta
                    3h30
    =#
    @testset "ech_last_moment" begin
        ech = Dates.DateTime("2015-01-01T10:30:00")
        ts = Dates.DateTime("2015-01-01T14:00:00")
        delta = Dates.Minute(210) #3h30

        next_ech = Dates.DateTime("2015-01-01T05:00:00")
        @test_throws ErrorException PSCOPF.compute_firmness(ech, next_ech, ts, delta)

        next_ech = Dates.DateTime("2015-01-01T10:30:00")
        @test PSCOPF.compute_firmness(ech, next_ech, ts, delta) == PSCOPF.FREE

        next_ech = Dates.DateTime("2015-01-01T13:00:00")
        @test PSCOPF.compute_firmness(ech, next_ech, ts, delta) == PSCOPF.TO_DECIDE

        next_ech = nothing
        @test PSCOPF.compute_firmness(ech, next_ech, ts, delta) == PSCOPF.TO_DECIDE
    end

    #=
      7h             10h30                      14h
     ECH          TS-Delta                       TS
       |                 |                        |
                          <---------------------->
                                    Delta
                                     3h30
    =#
    @testset "ech_early" begin
        ech = Dates.DateTime("2015-01-01T07:00:00")
        ts = Dates.DateTime("2015-01-01T14:00:00")
        delta = Dates.Minute(210) #3h30

        next_ech = Dates.DateTime("2015-01-01T05:00:00")
        @test_throws ErrorException PSCOPF.compute_firmness(ech, next_ech, ts, delta)

        next_ech = Dates.DateTime("2015-01-01T10:30:00")
        @test PSCOPF.compute_firmness(ech, next_ech, ts, delta) == PSCOPF.FREE

        next_ech = Dates.DateTime("2015-01-01T13:00:00")
        @test PSCOPF.compute_firmness(ech, next_ech, ts, delta) == PSCOPF.TO_DECIDE

        next_ech = nothing
        @test PSCOPF.compute_firmness(ech, next_ech, ts, delta) == PSCOPF.TO_DECIDE
    end

end