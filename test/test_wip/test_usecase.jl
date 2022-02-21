using PSCOPF

using Test
using Dates
using DataStructures

@testset verbose=true "test_usecase" begin

    @testset "test_2bus" begin
        network = PSCOPF.Networks.Network()

        # Buses
        PSCOPF.Networks.add_new_bus!(network, "bus_1")
        PSCOPF.Networks.add_new_bus!(network, "bus_2")

        # Branches
        PSCOPF.Networks.add_new_branch!(network, "branch_1_2", 500.);

        # PTDF
        PSCOPF.Networks.add_ptdf_elt!(network, "branch_1_2", "bus_1", 0.5)
        PSCOPF.Networks.add_ptdf_elt!(network, "branch_1_2", "bus_2", -0.5)
        #Alternatively,
        # network.ptdf = SortedDict{String,SortedDict{String, Float64}}(
        #                         "branch_1_2" => SortedDict{String, Float64}(
        #                             "bus_1" => 0.5,
        #                             "bus_2" => -0.5,
        #                             ),
        #                         )

        # Generators
        #Limitables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1_0", PSCOPF.Networks.LIMITABLE,
                                                0., 0., #pmin, pmax : Not concerned ? min is always 0, max is the limitation
                                                0., 10., #start_cost, prop_cost : start cost is always 0 ?
                                                Dates.Second(0), Dates.Second(0)) #dmo, dp : always 0. ?
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "wind_2_0", PSCOPF.Networks.LIMITABLE,
                                                0., 0.,
                                                0., 11.,
                                                Dates.Second(0), Dates.Second(0))
        #Imposables
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "ccg_1_0", PSCOPF.Networks.IMPOSABLE,
                                                10., 200., #pmin, pmax
                                                45000., 30., #start_cost, prop_cost
                                                Dates.Second(4*3600), Dates.Second(15*60)) #dmo, dp
        PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "tac_2_0", PSCOPF.Networks.IMPOSABLE,
                                                10., 200.,
                                                12000., 120.,
                                                Dates.Second(30*60), Dates.Second(15*60))

        #initial generators state
        generators_init_state = SortedDict(
                        "ccg_1_0" => PSCOPF.ON,
                        "tac_2_0" => PSCOPF.OFF,
                    )

        # Uncertainties
        uncertainties = PSCOPF.Uncertainties(
                                DateTime("2015-01-01T07:00:00") => SortedDict(
                                        "wind_1_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "wind_2_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_1" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_2" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                ),
                                DateTime("2015-01-01T10:00:00") => SortedDict(
                                        "wind_1_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "wind_2_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_1" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_2" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                ),
                                DateTime("2015-01-01T10:30:00") => SortedDict(
                                        "wind_1_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "wind_2_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_1" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_2" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                ),
                                DateTime("2015-01-01T10:45:00") => SortedDict(
                                        "wind_1_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "wind_2_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_1" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_2" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                ),
                                DateTime("2015-01-01T11:00:00") => SortedDict(
                                        "wind_1_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "wind_2_0" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_1" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                        "bus_2" => SortedDict(
                                            DateTime("2015-01-01T11:00:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:15:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:30:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                            DateTime("2015-01-01T11:45:00") => SortedDict(
                                                                                        "S1" => 0.,
                                                                                        "S2" => 0.,
                                                                                        ),
                                        ),
                                ),
        )
        #Alternatively, PSCOPF.add_uncertainty!(uncertainties, ech, nodal_injection_name, ts, scenario_name, value)

        # Timesteps
        TS = [DateTime("2015-01-01T11:00:00"),
                DateTime("2015-01-01T11:15:00"),
                DateTime("2015-01-01T11:30:00"),
                DateTime("2015-01-01T11:45:00")]

        mode = PSCOPF.PSCOPF_MODE_1
        ECH = PSCOPF.generate_ech(network, TS, mode)

        sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

        exec_context = PSCOPF.PSCOPFContext(network, TS, mode, generators_init_state, uncertainties, nothing)
        PSCOPF.run!(exec_context, sequence)

        market_schedule = PSCOPF.get_market_schedule(exec_context)
        tso_schedule = PSCOPF.get_tso_schedule(exec_context)
    end

end
