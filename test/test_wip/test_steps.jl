using PSCOPF

using Test
using Dates
using DataStructures


@testset verbose=true  "test_steps" begin

    @testset verbose=true  "test_assessment_steps" begin

        #=
        INPUT :
            Network := Electric grid description
            NetworkSituation := Schedule + Units state
            UncertaintiesBounds := MISSING the responsability that generates this entry
        EXPECTED OUTPUT :
            Estimation of the overflow (non-satisfiable RSO constraints)
        =#
        @testset "assessment_launch" begin
            network = PSCOPF.Networks.Network()
            ts1 = Dates.DateTime("2015-01-01T11:00:00")
            TS = PSCOPF.create_target_timepoints(ts1)
            ech = ts1
            mode = PSCOPF.PSCOPF_MODE_1

            #FIXME add AssessmentUncertainties to context
            exec_context = PSCOPF.PSCOPFContext(network, TS, ECH, mode)
            PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.Market(), ECH[1]))
            PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.TSO(), ECH[1]))

            PSCOPF.set_current_ech!(exec_context, ech)
            result = PSCOPF.run(PSCOPF.Assessment(), exec_context)
            PSCOPF.update!(exec_context, result)

            #FIXME TESTs :
        end

    end


    @testset verbose=true "test_market_steps" begin

        @testset "EnergyMarket" begin
            network = PSCOPF.Networks.Network()
            TS = PSCOPF.create_target_timepoints(DateTime("2015-01-01T11:00:00"))
            mode = PSCOPF.PSCOPF_MODE_1
            ech = DateTime("2015-01-01T10:00:00")
            ECH = [ech]

            exec_context = PSCOPF.PSCOPFContext(network, TS, ECH, mode)
            PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.Market(), ECH[1]))
            PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.TSO(), ECH[1]))

            PSCOPF.set_current_ech!(exec_context, ech)
            result = PSCOPF.run(PSCOPF.EnergyMarket(), exec_context)
            PSCOPF.update!(exec_context, result)

            #test
        end

    end

    @testset verbose=true "test_tso_steps" begin

    end

end
