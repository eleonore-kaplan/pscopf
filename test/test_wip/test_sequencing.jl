using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_sequencing" begin

    @testset "test_sequencing" begin
        println("\n\n\n")
        grid = PSCOPF.Networks.Network()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        ECH = [DateTime("2015-01-01T07:00:00"),
                DateTime("2015-01-01T10:00:00"),
                DateTime("2015-01-01T10:30:00")]

        struct MockInitializer <: PSCOPF.AbstractRunnable
        end
        function PSCOPF.run(step::MockInitializer, context::PSCOPF.PSCOPFContext)
            schedule = PSCOPF.Schedule(PSCOPF.Market(), PSCOPF.get_current_ech(context))
            return schedule
        end
        function PSCOPF.update!(context::PSCOPF.PSCOPFContext, result, step::MockInitializer)
            PSCOPF.add_schedule!(context, result)
        end

        struct MockTSO <: PSCOPF.AbstractRunnable
        end
        function PSCOPF.run(step::MockTSO, context::PSCOPF.PSCOPFContext)
            schedule = PSCOPF.Schedule(PSCOPF.TSO(), PSCOPF.get_current_ech(context))
            return schedule
        end
        function PSCOPF.update!(context::PSCOPF.PSCOPFContext, result, step::MockTSO)
            PSCOPF.add_schedule!(context, result)
        end

        sequence = PSCOPF.Sequence(SortedDict(
            ECH[1]     => [MockInitializer(), MockTSO()],
            ECH[2]     => [MockTSO()],
            ECH[3]     => [MockTSO()]
        ))

        mode = PSCOPF.ManagementMode("test_sequencing", Dates.Minute(0))
        exec_context = PSCOPF.PSCOPFContext(grid, TS, ECH, mode, PSCOPF.Uncertainties(), nothing)

        @test PSCOPF.get_current_ech(exec_context) == ECH[1]

        PSCOPF.run!(exec_context, sequence)

        @test PSCOPF.get_current_ech(exec_context) == ECH[end]
        @test length(exec_context.schedule_history) == 4 #one for each executed step
        @test PSCOPF.is_market(exec_context.schedule_history[1].decider)
        @test PSCOPF.is_tso(exec_context.schedule_history[2].decider)
        @test PSCOPF.is_tso(exec_context.schedule_history[3].decider)
        @test PSCOPF.is_tso(exec_context.schedule_history[4].decider)
    end

end
