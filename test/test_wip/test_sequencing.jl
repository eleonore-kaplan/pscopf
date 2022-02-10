using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_sequencing" begin

    @testset "test_sequencing" begin
        println("\n\n\n")
        network = PSCOPF.Networks.Network()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        ECH = [DateTime("2015-01-01T07:00:00"),
                DateTime("2015-01-01T10:00:00"),
                DateTime("2015-01-01T10:30:00")]

        struct MockMarket <: PSCOPF.AbstractMarket
        end
        function PSCOPF.run(runnable::MockMarket, ech, firmness, TS, context::PSCOPF.AbstractContext)
            return nothing
        end
        function PSCOPF.update_market_schedule!(context::PSCOPF.AbstractContext, ech, result, firmness, runnable::MockMarket)
            schedule = PSCOPF.Schedule(PSCOPF.Market(), ech)
            PSCOPF.add_schedule!(context, schedule)
        end

        struct MockTSO <: PSCOPF.AbstractTSO
        end
        function PSCOPF.run(runnable::MockTSO, ech, firmness, TS, context::PSCOPF.AbstractContext)
            return nothing
        end
        function PSCOPF.update_tso_schedule!(context::PSCOPF.AbstractContext, ech, result, firmness, runnable::MockTSO)
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), ech)
            PSCOPF.add_schedule!(context, schedule)
        end
        function PSCOPF.update_limitations!(context::PSCOPF.AbstractContext, ech, result, firmness, runnable::MockTSO)
            nothing
        end
        function PSCOPF.update_impositions!(context::PSCOPF.AbstractContext, ech, result, firmness, runnable::MockTSO)
            nothing
        end

        sequence = PSCOPF.Sequence(SortedDict(
            ECH[1]     => [MockMarket(), MockTSO()],
            ECH[2]     => [MockTSO()],
            ECH[3]     => [MockTSO()]
        ))

        mode = PSCOPF.ManagementMode("test_sequencing", Dates.Minute(0))
        exec_context = PSCOPF.PSCOPFContext(network, TS, mode)

        PSCOPF.run!(exec_context, sequence)

        @test length(exec_context.schedule_history) == 4 #one for each executed step
        @test PSCOPF.is_market(exec_context.schedule_history[1].decider)
        @test exec_context.schedule_history[1].decision_time == ECH[1]
        @test PSCOPF.is_tso(exec_context.schedule_history[2].decider)
        @test exec_context.schedule_history[2].decision_time == ECH[1]
        @test PSCOPF.is_tso(exec_context.schedule_history[3].decider)
        @test exec_context.schedule_history[3].decision_time == ECH[2]
        @test PSCOPF.is_tso(exec_context.schedule_history[4].decider)
        @test exec_context.schedule_history[4].decision_time == ECH[3]
    end

end
