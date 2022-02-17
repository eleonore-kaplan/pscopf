using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_schedule" begin

    @testset "test_market_empty_schedule" begin
        println("\n\n\n")
        network = PSCOPF.Networks.Network()
        PSCOPF.Networks.add_new_bus!(network, "bus");
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus", "lim", PSCOPF.Networks.LIMITABLE, 0., 10., 0., 10., Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus", "imp", PSCOPF.Networks.IMPOSABLE, 0., 10., 1000., 10., Dates.Second(0), Dates.Second(0))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus", "gen_pmin", PSCOPF.Networks.IMPOSABLE, 1., 10., 1000., 10., Dates.Second(0), Dates.Second(0))

        TS = [DateTime("2015-01-01T11:00:00"),
                DateTime("2015-01-01T11:15:00"),
                DateTime("2015-01-01T11:30:00"),
                DateTime("2015-01-01T11:45:00")]
        scenarios = ["S1","S2"]
        ech = DateTime("2015-01-01T07:00:00")
        schedule = PSCOPF.Schedule(PSCOPF.Market(), ech)
        PSCOPF.init!(schedule, network, TS, scenarios)

        @test PSCOPF.is_market(schedule.type)
        @test !PSCOPF.is_tso(schedule.type)
        @test schedule.decision_time == ech
        @test length(schedule.generator_schedules) == 3

        # No commitment defined for generators with pmin=0
        @test isempty(PSCOPF.get_sub_schedule(schedule, "lim").commitment)
        @test length(PSCOPF.get_sub_schedule(schedule, "lim").production) == 4
        for ts in TS
            #"missing" is returned cause the values are not set yet
            @test ismissing(PSCOPF.get_prod_value(schedule, "lim", ts))
            #"missing" is returned even if the generator does not have commitment values
            @test ismissing(PSCOPF.get_commitment_value(schedule, "lim", ts))
        end

        # No commitment defined for generators with pmin=0
        @test isempty(PSCOPF.get_sub_schedule(schedule, "imp").commitment)
        @test length(PSCOPF.get_sub_schedule(schedule, "imp").production) == 4
        for ts in TS
            #"missing" is returned cause the values are not set yet
            @test ismissing(PSCOPF.get_prod_value(schedule, "imp", ts))
            #"missing" is returned even if the generator does not have commitment values
            @test ismissing(PSCOPF.get_commitment_value(schedule, "imp", ts))
        end

        # generator with pmin > 0
        @test length(PSCOPF.get_sub_schedule(schedule, "gen_pmin").commitment) == 4
        @test length(PSCOPF.get_sub_schedule(schedule, "gen_pmin").production) == 4
        for ts in TS
            #"missing" is returned cause the values are not set yet
            @test ismissing(PSCOPF.get_prod_value(schedule, "gen_pmin", ts))
            @test ismissing(PSCOPF.get_commitment_value(schedule, "gen_pmin", ts))
        end

    end

end
