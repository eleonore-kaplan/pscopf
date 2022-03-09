using PSCOPF

function get_test_case()
    network = PSCOPF.Networks.Network()
    # Buses : BUS 
    PSCOPF.Networks.add_new_bus!(network, "bus_1")
    PSCOPF.Networks.add_new_bus!(network, "bus_2")
    # Branches : BRANCH LIMIT
    PSCOPF.Networks.add_new_branch!(network, "branch_1_2", 500.);
    # PTDF : BRANCH BUS VALUE
    PSCOPF.Networks.add_ptdf_elt(network, "branch_1_2", "bus_1", 0.5)
    PSCOPF.Networks.add_ptdf_elt(network, "branch_1_2", "bus_2", -0.5)
    #Alternatively,
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

    # Uncertainties : ECH NAME TS S VALUE
    uncertainties = PSCOPF.Uncertainties()
    #Alternatively, PSCOPF.add_uncertainty!(uncertainties, ech, nodal_injection_name, ts, scenario_name, value)

    # Timesteps
    TS = [DateTime("2015-01-01T11:00:00"),
            DateTime("2015-01-01T11:15:00"),
            DateTime("2015-01-01T11:30:00"),
            DateTime("2015-01-01T11:45:00")]

    mode = PSCOPF.PSCOPF_MODE_1
    ECH = PSCOPF.generate_ech(network, TS, mode)

    sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

    exec_context = PSCOPF.PSCOPFContext(network, TS, ECH, mode, generators_init_state, uncertainties, nothing)
    PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.Market(), ECH[1]))
    PSCOPF.add_schedule!(exec_context, PSCOPF.Schedule(PSCOPF.TSO(), ECH[1]))
    PSCOPF.run!(exec_context, sequence)

    market_schedule = PSCOPF.safeget_last_market_schedule(exec_context)
    tso_schedule = PSCOPF.safeget_last_tso_schedule(exec_context)


end
#=
    Description of all optimization problems
=#


# ech : value
# TS : list
# SCENARIO : list
# commitment : 
function energy_market(ech, TS, SCENARIO, commitment)
#=
    availability is given by DMO/DP and ECH 

    minimize production cost + fixed cost
    s.c.
        EOD[ts, s] for all ts in TS, s in SCENARIO
    output : 
        - commitment market for DMO=ECH or commitment[s] : this is because market realization cannot be forecasted
        - P for DP=ECH or P[s] 
=#
end

# ech : value
# TS : list
# SCENARIO : list
# commitment : 
function tso_out_operationnal_window(ech, TS, SCENARIO, commitment)
    #=
        imposition are related to DP/DMO, cost are computed by delta = |P[s]-P_imp|
        
        1- sum delta_up+delta_down
        2- minimize cost to have 

        minimize 1- or 2- with 1- in constraints
        s.c.
            energy_market result EOD OK
            line constraints
            equilibrated imposition (computed how ? ) sum delta = 0

        output : 
            - commitment tso for DMO=ECH or commitment[s]
            - P for DP=ECH, P[s] tso
    =#
end
    


# ech : value
# TS : list
# SCENARIO : value or list
# commitment : 
# question : one scenario to be sure it is feasible (average, other ?), or multi-scenario with delta allowed 
function entering_operationnal_window(ech, TS, SCENARIO, commitment)
    #=
    availability is given by DMO/DP and ECH 

    minimize production cost
    s.c.
        EOD[ts] for all ts in TS

    output : 
        - commitment, same value for all s in SCENARIO, market
        - P, same value for all s in SCENARIO, market
    =#
end

# ech : value
# TS : list
# SCENARIO : list
# commitment : 
function tso_in_operationnal_window(ech, TS, SCENARIO, commitment)
    #=
        
    =#
end
