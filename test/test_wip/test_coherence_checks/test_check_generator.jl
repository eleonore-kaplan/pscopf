using PSCOPF

using Test
using Dates

@testset "test_check_generator" begin

    @testset "definition_example" begin
        gen_imp = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            10., 200.,
                                            50000., 1000.,
                                            Dates.Second(4*3600), Dates.Second(15*60))
        @test PSCOPF.check(gen_imp)

        gen_lim = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.LIMITABLE,
                                            0., 200.,
                                            0., 1000.,
                                            Dates.Second(15*60), Dates.Second(15*60))
        @test PSCOPF.check(gen_lim)
    end

    @testset "prop_cost>=0" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            10., 200.,
                                            50000., -1000.,
                                            Dates.Second(4*3600), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

    @testset "start_cost>=0" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            10., 200.,
                                            -50000., 1000.,
                                            Dates.Second(4*3600), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

    @testset "dp<=dmo" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            10., 200.,
                                            50000., 1000.,
                                            Dates.Second(2*60), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

    @testset "dp>=0" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            10., 200.,
                                            50000., 1000.,
                                            Dates.Second(4*3600), Dates.Second(-15*60))
        @test !PSCOPF.check(gen)
    end

    #implied by dp<=dmo and dp>=0
    @testset "dmo>=0" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            10., 200.,
                                            50000., 1000.,
                                            Dates.Second(-4*3600), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

    @testset "pmax>=pmin" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            500., 200.,
                                            50000., 1000.,
                                            Dates.Second(4*3600), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

    @testset "pmin>=0" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            -10., 200.,
                                            50000., 1000.,
                                            Dates.Second(4*3600), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

    #implied by pmin<=pmax and pmin>=0
    @testset "pmax>=0" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            10., -200.,
                                            50000., 1000.,
                                            Dates.Second(4*3600), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

    # If pmin=0, a unit can be supposed always ON even if it has a prod level of 0.
    # The DMO is not useful in this case and should not be a constraint
    # => dmo=dp, the unit will always be ON, at DP we decide the ferm production level
    @testset "if_pmin=0_then_dmo=dp" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            0., 200.,
                                            0., 1000.,
                                            Dates.Second(4*3600), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

    # If pmin=0, a unit can be supposed always ON even if it has a prod level of 0.
    # and the starting cost was paid far in the past
    @testset "if_pmin=0_then_startcost=0" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.IMPOSABLE,
                                            0., 200.,
                                            50000., 1000.,
                                            Dates.Second(15*60), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end


    @testset "if_limitable_then_pmin=0" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.LIMITABLE,
                                            10., 200.,
                                            0., 1000.,
                                            Dates.Second(15*60), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

    @testset "if_limitable_then_startcost=0" begin
        gen = PSCOPF.Networks.Generator("gen", "bus",
                                            PSCOPF.Networks.LIMITABLE,
                                            0., 200.,
                                            50000., 1000.,
                                            Dates.Second(15*60), Dates.Second(15*60))
        @test !PSCOPF.check(gen)
    end

end