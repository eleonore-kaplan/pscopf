module TestFirmnessInSequence

using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_firmness_in_sequence" begin

    #=
    "D" indicates the decision time (TO_DECIDE state)
    Before "D", we have a FREE state
    After "D", we have a DECIDED state
          10h                13h             13h30    13h45     14h             14h30
          ECH1               ECH2            ECH3     ECH4      TS1              TS2
            |                  |               |        |        |                |
fuel_1_0    |                  |               |        |        |                |
commitment  |                  |               |        |        |                |
TS1:        D<------------------------------DMO----------------->|                |
TS2:        D         <---------------------------------DMO---------------------->|
power                          |               |        |        |                |
TS1:                           D  <----------------DP----------->|                |
TS2:                                           D     <--------------DP----------->|
                                               |        |        |                |
wind_1_0                                       |        |        |                |
commitment                                     |        |        |                |
= power                                        |        |        |                |
TS1:                                           D     <--DP=DMO-->|                |
TS2:                                                    D        X    <--DP=DMO-->|
                                                                 ^we cannot decide at this point
=#

    @testset "test_firmness_in_sequence" begin
        network = PSCOPF.Networks.Network()
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_0", PSCOPF.Networks.LIMITABLE,
                                                0., 100., 0., 0.,
                                                Dates.Second(20*60), Dates.Second(20*60))
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "fuel_1_0", PSCOPF.Networks.IMPOSABLE,
                                                0., 100., 0., 0.,
                                                Dates.Second(4*60*60), Dates.Second(50*60))

        TS = [DateTime("2015-01-01T14:00:00"),
            DateTime("2015-01-01T14:30:00")]
        ECH = [DateTime("2015-01-01T10:00:00"),
            DateTime("2015-01-01T13:00:00"),
            DateTime("2015-01-01T13:30:00"),
            DateTime("2015-01-01T13:45:00")]
        firmness_history = Dict{DateTime,PSCOPF.Firmness}()

        struct MockRunnable <: PSCOPF.AbstractRunnable
        end
        function PSCOPF.run(runnable::MockRunnable, ech, firmness, TS, context::PSCOPF.AbstractContext)
            firmness_history[ech] = firmness
        end

        sequence = PSCOPF.Sequence(SortedDict(
            ECH[1]     => [MockRunnable()],
            ECH[2]     => [MockRunnable()],
            ECH[3]     => [MockRunnable()],
            ECH[4]     => [MockRunnable()]
        ))

        mode = PSCOPF.ManagementMode("test_firmness_in_sequence", Dates.Minute(0))
        exec_context = PSCOPF.PSCOPFContext(network, TS, mode)

        PSCOPF.run!(exec_context, sequence)

        @test length(firmness_history) == 4 # one for each executed step

        #ECH1
        firmness = firmness_history[ECH[1]]
        @test PSCOPF.get_commitment_firmness(firmness, "fuel_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "fuel_1_0", TS[2]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "fuel_1_0", TS[1]) == PSCOPF.FREE
        @test PSCOPF.get_power_level_firmness(firmness, "fuel_1_0", TS[2]) == PSCOPF.FREE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.FREE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.FREE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE

        #ECH2
        firmness = firmness_history[ECH[2]]
        @test PSCOPF.get_commitment_firmness(firmness, "fuel_1_0", TS[1]) == PSCOPF.DECIDED
        @test PSCOPF.get_commitment_firmness(firmness, "fuel_1_0", TS[2]) == PSCOPF.DECIDED
        @test PSCOPF.get_power_level_firmness(firmness, "fuel_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "fuel_1_0", TS[2]) == PSCOPF.FREE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.FREE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.FREE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE

        #ECH3
        firmness = firmness_history[ECH[3]]
        @test PSCOPF.get_commitment_firmness(firmness, "fuel_1_0", TS[1]) == PSCOPF.DECIDED
        @test PSCOPF.get_commitment_firmness(firmness, "fuel_1_0", TS[2]) == PSCOPF.DECIDED
        @test PSCOPF.get_power_level_firmness(firmness, "fuel_1_0", TS[1]) == PSCOPF.DECIDED
        @test PSCOPF.get_power_level_firmness(firmness, "fuel_1_0", TS[2]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.FREE

        #ECH4
        firmness = firmness_history[ECH[4]]
        @test PSCOPF.get_commitment_firmness(firmness, "fuel_1_0", TS[1]) == PSCOPF.DECIDED
        @test PSCOPF.get_commitment_firmness(firmness, "fuel_1_0", TS[2]) == PSCOPF.DECIDED
        @test PSCOPF.get_power_level_firmness(firmness, "fuel_1_0", TS[1]) == PSCOPF.DECIDED
        @test PSCOPF.get_power_level_firmness(firmness, "fuel_1_0", TS[2]) == PSCOPF.DECIDED
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.DECIDED
        @test PSCOPF.get_commitment_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.TO_DECIDE
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[1]) == PSCOPF.DECIDED
        @test PSCOPF.get_power_level_firmness(firmness, "wind_1_0", TS[2]) == PSCOPF.TO_DECIDE
    end

end

end #module
