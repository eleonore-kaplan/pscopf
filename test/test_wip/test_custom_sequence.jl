module TestCustomSequence

using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_custom_sequence" begin

    @testset "test_custom_sequence" begin
        println("\n\n\n")
        network = PSCOPF.Networks.Network()
        TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
        ECH = [DateTime("2015-01-01T07:00:00"),
                DateTime("2015-01-01T10:00:00"),
                DateTime("2015-01-01T10:30:00")]
        schedule_history = Vector{PSCOPF.Schedule}()
        uncertainties = PSCOPF.Uncertainties(
            DateTime("2015-01-01T07:00:00") => PSCOPF.UncertaintiesAtEch(),
            DateTime("2015-01-01T10:00:00") => PSCOPF.UncertaintiesAtEch(),
            DateTime("2015-01-01T10:30:00") => PSCOPF.UncertaintiesAtEch()
            )

        struct MockMarket <: PSCOPF.AbstractMarket
        end
        function PSCOPF.run(runnable::MockMarket, ech, firmness, TS, context::PSCOPF.AbstractContext)
            return nothing
        end
        #affects_market_schedule default to true cause <:AbstractMarket
        function PSCOPF.update_market_schedule!(context::PSCOPF.AbstractContext, ech, result, firmness, runnable::MockMarket)
            market_schedule = PSCOPF.get_market_schedule(context)
            market_schedule.decider_type = PSCOPF.DeciderType(runnable)
            market_schedule.decision_time = ech
            push!(schedule_history, deepcopy(market_schedule))
        end

        struct MockTSO <: PSCOPF.AbstractTSO
        end
        function PSCOPF.run(runnable::MockTSO, ech, firmness, TS, context::PSCOPF.AbstractContext)
            return nothing
        end
        #affects_tso_schedule default to true cause <:AbstractTSO
        function PSCOPF.update_tso_schedule!(context::PSCOPF.AbstractContext, ech, result, firmness,  runnable::MockTSO)
            tso_schedule = PSCOPF.get_tso_schedule(context)
            tso_schedule.decider_type = PSCOPF.DeciderType(runnable)
            tso_schedule.decision_time = ech
            push!(schedule_history, deepcopy(tso_schedule))
        end
        #affects_tso_actions_schedule default to true cause <:AbstractTSO
        function PSCOPF.update_tso_actions!(tso_actions, ech, result, firmness, runnable::MockTSO)
            nothing
        end

        sequence = PSCOPF.Sequence(SortedDict(
            ECH[1]     => [MockMarket(), MockTSO()],
            ECH[2]     => [MockTSO()],
            ECH[3]     => [MockTSO()]
        ))

        mode = PSCOPF.ManagementMode("test_sequencing", Dates.Minute(0))
        exec_context = PSCOPF.PSCOPFContext(network, TS, mode,
                                            SortedDict{String,PSCOPF.GeneratorState}(), uncertainties)

        PSCOPF.run!(exec_context, sequence, check_context=false)

        @test length(schedule_history) == 4 # one for each executed step

        @test PSCOPF.is_market(schedule_history[1].decider_type)
        @test schedule_history[1].decision_time == ECH[1]
        @test PSCOPF.is_tso(schedule_history[2].decider_type)
        @test schedule_history[2].decision_time == ECH[1]
        @test PSCOPF.is_tso(schedule_history[3].decider_type)
        @test schedule_history[3].decision_time == ECH[2]
        @test PSCOPF.is_tso(schedule_history[4].decider_type)
        @test schedule_history[4].decision_time == ECH[3]
    end

end

end #module
