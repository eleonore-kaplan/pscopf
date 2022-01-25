using Test
using Dates
using JuMP

@testset verbose=true "assessment" begin

    #=
    INPUT :
        Network := Electric grid description
        NetworkSituation := Schedule + Units state
        UncertaintiesBounds := MISSING the responsability that generates this entry
    EXPECTED OUTPUT :
        Estimation of the overflow (non-satisfiable RSO constraints)
    =#
    @testset "assessment_launch" begin
        grid = create_grid(#=FIXME initial input or mocks=#)
        ts1 #=FIXME initial input or mocks=#
        TS = create_TS(Dates.DateTime(ts1)) #ts1 .+ [Dates.Minute(0), Dates.Minute(15), Dates.Minute(30), Dates.Minute(45)]
        ech #=FIXME initial input or mocks=#

        uncertaintiesBounds #=FIXME initial input or mocks=#
        initialSituation #=FIXME initial input or mocks=#

        assessment_step = AssessmentStep(grid, TS, ech, uncertaintiesBounds, initialSituation) #FIXME or simply Mode1TSO(::Session) (in this case, Session should support get_uncertaintiesBounds(Session, ech))
        assessment_status, overflow = launch(assessment_step)

        #FIXME TESTs :
    end

end