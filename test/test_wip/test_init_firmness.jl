using PSCOPF

using Test
using Dates

@testset "test_init_firmness" begin

    gen1 = PSCOPF.Networks.Generator("wind_1_0", "bus_1", PSCOPF.Networks.LIMITABLE, 0., 0., 0., 10.,
                                    Dates.Second(210*60), Dates.Second(210*60)) #dmo, dp
    gen2 = PSCOPF.Networks.Generator( "gen_1_0", "bus_1", PSCOPF.Networks.IMPOSABLE, 0., 0., 0., 10.,
                                    Dates.Second(4*60*60), Dates.Second(210*60)) #dmo, dp

    TS = [DateTime("2015-01-01T14:00:00"), DateTime("2015-01-01T14:30:00")]

    #=
       10h30         12h            14h   14h30
    TS1-Delta        ECH            TS1    TS2
            |          |             |      |
             <---------------------->
                          3h30
                   |<---------------------->
           TS2-Delta
                 11h
    =#
    @testset "ech_late" begin
        generators = [gen1]
        ech = Dates.DateTime("2015-01-01T12:00:00")

        next_ech = Dates.DateTime("2015-01-01T13:00:00")
        firmness = PSCOPF.init_firmness(ech, next_ech, TS, generators)
        @test length(PSCOPF.get_commitment_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.DECIDED
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.DECIDED
        @test length(PSCOPF.get_power_level_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.DECIDED
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.DECIDED
    end

    #=
       10h30                      14h   14h30
    TS-Delta                       TS    TS2
         ECH
           |                        |     |
           |<---------------------->|     |
                           3h30           |
                  <---------------------->|
                11h
    =#
    @testset "ech_last_moment" begin
        generators = [gen1]
        ech = Dates.DateTime("2015-01-01T10:30:00")

        next_ech = Dates.DateTime("2015-01-01T10:30:00")
        firmness = PSCOPF.init_firmness(ech, next_ech, TS, generators)
        @test length(PSCOPF.get_commitment_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.FREE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE
        @test length(PSCOPF.get_power_level_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.FREE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE

        next_ech = Dates.DateTime("2015-01-01T10:45:00")
        firmness = PSCOPF.init_firmness(ech, next_ech, TS, generators)
        @test length(PSCOPF.get_commitment_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE
        @test length(PSCOPF.get_power_level_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE

        next_ech = Dates.DateTime("2015-01-01T13:00:00")
        firmness = PSCOPF.init_firmness(ech, next_ech, TS, generators)
        @test length(PSCOPF.get_commitment_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.TO_DECIDE
        @test length(PSCOPF.get_power_level_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.TO_DECIDE

        next_ech = nothing
        firmness = PSCOPF.init_firmness(ech, next_ech, TS, generators)
        @test length(PSCOPF.get_commitment_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.TO_DECIDE
        @test length(PSCOPF.get_power_level_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.TO_DECIDE
    end

    #=
      7h             10h30                      14h   14h30
     ECH          TS-Delta                      TS1    TS2
       |                 |                        |     |
                          <---------------------->
                                     3h30
                               |<---------------------->
                       TS2-Delta
                            11h
    =#
    @testset "ech_early" begin
        generators = [gen1]
        ech = Dates.DateTime("2015-01-01T07:00:00")

        next_ech = Dates.DateTime("2015-01-01T10:30:00")
        firmness = PSCOPF.init_firmness(ech, next_ech, TS, generators)
        @test length(PSCOPF.get_commitment_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.FREE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE
        @test length(PSCOPF.get_power_level_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.FREE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE

        next_ech = Dates.DateTime("2015-01-01T10:45:00")
        firmness = PSCOPF.init_firmness(ech, next_ech, TS, generators)
        @test length(PSCOPF.get_commitment_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE
        @test length(PSCOPF.get_power_level_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE

        next_ech = Dates.DateTime("2015-01-01T13:00:00")
        firmness = PSCOPF.init_firmness(ech, next_ech, TS, generators)
        @test length(PSCOPF.get_commitment_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.TO_DECIDE
        @test length(PSCOPF.get_power_level_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.TO_DECIDE
    end

    #=
      7h             10h30                      14h   14h30
     ECH            TS1-DP                      TS1    TS2
       |                 |                        |     |
       |                 |<---------------------->|     |
       |                 |           3h30               |
       |                 |     |<---------------------->
       |                 | TS2-DP
       |                 |   11h
       |          |      |
            TS1-DMO TS2-DMO
                10h   10h30

    =#
    @testset "two_generators" begin
        generators = [gen1, gen2]
        ech = Dates.DateTime("2015-01-01T07:00:00")

        next_ech = Dates.DateTime("2015-01-01T10:45:00")
        firmness = PSCOPF.init_firmness(ech, next_ech, TS, generators)

        @test length(PSCOPF.get_commitment_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE
        @test length(PSCOPF.get_power_level_firmness(firmness, "wind_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE

        @test length(PSCOPF.get_commitment_firmness(firmness, "gen_1_0")) == 2
        @test PSCOPF.get_commitment_firmness(firmness, "gen_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "gen_1_0", TS[2]) == PSCOPF.TO_DECIDE
        @test length(PSCOPF.get_power_level_firmness(firmness, "gen_1_0")) == 2
        @test PSCOPF.get_power_level_firmness(firmness, "gen_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "gen_1_0", TS[2]) == PSCOPF.FREE

    end

end
