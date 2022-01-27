using PSCOPF

using Dates

@testset "create_ts" begin
    ts1 = DateTime("2015-01-01T11:00:00")
    TS = PSCOPF.create_target_timepoints(ts1)
    
    EXPECTED_TS = [DateTime("2015-01-01T11:00:00"),
                    DateTime("2015-01-01T11:15:00"),
                    DateTime("2015-01-01T11:30:00"),
                    DateTime("2015-01-01T11:45:00")]
    @test length(TS) == length(EXPECTED_TS)
    @test TS == EXPECTED_TS
end
