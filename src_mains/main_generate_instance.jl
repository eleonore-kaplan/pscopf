"""
    main_generate_instance
A main file allowing to generate a pscopf instance and write its describing files.

For that,
1- set the parameter `instance_out_path` to the directory where instance files will be written.
2- define `create_network` to create the desired network.
This main provides an example for creating the network using PSCOPF's api
3- define `create_init_state` to create an initial state for the units with pmin>0.
This main provides an example for that.
"""

using Dates
using DataStructures

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PSCOPF.jl"));




#############################
# PARAMS
#############################

# instance_out_path is the path that will contain the partial instance data (missing pscopf_uncertainties):
# pscopf_units : the description of the units
# pscopf_init : the description of the initial state of units (just before the first interest timepoit T)
# pscopf_limits : the flow capacity of each branch
# pscopf_ptdf : the ptdf coefficients per (branch, bus_id)
instance_out_path = ( length(ARGS) > 0 ? ARGS[1] :
                            joinpath(@__DIR__, "..", "data", "2buses_small_usecase", "generate_instance") )




#############################
# CREATE INSTANCE
#############################
function create_network()
    println("Creating the network")
    network = PSCOPF.Networks.Network()
    # Buses
    println("adding buses")
    PSCOPF.Networks.add_new_bus!(network, "bus_1")
    PSCOPF.Networks.add_new_bus!(network, "bus_2")
    # Branches
    println("adding branches")
    PSCOPF.Networks.add_new_branch!(network, "branch_1_2", 500.);
    # PTDF
    println("adding the PTDF")
    PSCOPF.Networks.add_ptdf_elt!(network, "branch_1_2", "bus_1", 0.5)
    PSCOPF.Networks.add_ptdf_elt!(network, "branch_1_2", "bus_2", -0.5)
    #Generators - Limitables
    println("adding Limitables")
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1", PSCOPF.Networks.LIMITABLE,
                                            0., 200.,
                                            0., 10.,
                                            Dates.Second(15*60), Dates.Second(15*60)) #dmo, dp : always 0. ?
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "wind_2", PSCOPF.Networks.LIMITABLE,
                                            0., 200.,
                                            0., 11.,
                                            Dates.Second(15*60), Dates.Second(15*60))
    #Generators - Imposables
    println("adding Imposables")
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "ccg_1", PSCOPF.Networks.IMPOSABLE,
                                            150., 600., #pmin, pmax
                                            45000., 30., #start_cost, prop_cost
                                            Dates.Second(4*3600), Dates.Second(15*60)) #dmo, dp
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "tac_1", PSCOPF.Networks.IMPOSABLE,
                                            10., 300.,
                                            12000., 100.,
                                            Dates.Second(30*60), Dates.Second(15*60))
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "ccg_2", PSCOPF.Networks.IMPOSABLE,
                                            100., 600., #pmin, pmax
                                            50000., 20., #start_cost, prop_cost
                                            Dates.Second(4*3600), Dates.Second(15*60)) #dmo, dp

    return network
end

function create_init_state(network::Union{Nothing,PSCOPF.Network}=nothing;
                        all_off=false, all_on=false)
    println("Setting the initial state of generators (ON/OFF)")
    generators_init_state = SortedDict{String, PSCOPF.GeneratorState}()
    state = nothing
    if all_off && all_on
        throw(error("cannot set to ON and OFF at the same time"))
    elseif all_off && !isnothing(network)
        state = PSCOPF.OFF
    elseif all_on && !isnothing(network)
        state = PSCOPF.ON
    end

    if !isnothing(state)
        for generator in PSCOPF.get_generators(network)
            if PSCOPF.get_p_min(generator) > 0
                generators_init_state[PSCOPF.get_id(generator)] = state
            end
        end
    else
        throw(error("You need to define generators initial states"))
        #otherwise, we can define a dictionary
        # generators_init_state = SortedDict(
        #                     "ccg_1" => PSCOPF.ON,
        #                     "ccg_2" => PSCOPF.OFF,
        #                     "tac_1" => PSCOPF.OFF,
        #                 )
    end

    return generators_init_state
end





#############################
# GENERATE INSTANCE FILES
#############################
function generate_instance(dir_path)
    network = create_network() # User-defined
    PSCOPF.check(network)
    println("Network created!")

    generators_init_state = create_init_state(network, all_off=true) # User-defined
    PSCOPF.check_initial_state(generators_init_state, network)
    println("Generators' initial state created!")

    PSCOPF.PSCOPFio.write(dir_path, network)
    PSCOPF.PSCOPFio.write(dir_path, generators_init_state)
    println("instance files written to ", dir_path)
end

generate_instance(instance_out_path)

