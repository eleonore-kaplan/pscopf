"""
    main_mode1
A main file to launch PSCOPF in MODE 1.

Parameters:
    instance_path : path to input data directory
    output_path : path to output directory
"""

using Dates
using DataStructures

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PSCOPF.jl"));




#########################
# INPUT & PARAMS
#########################

#input path : parameters
"e"

#instance_path : files.txt
instance_path = ( length(ARGS) > 0 ? ARGS[1] :
                    joinpath(@__DIR__, "..", "usecases-euro-with-generator", "usecase1-arret-demarrage"))

# output_path is the path where output files will be write_commitment_schedule
#NOTE: all files in output_path, except those starting with pscopf_, will be deleted
output_path = length(ARGS) > 1 ? ARGS[2] : joinpath(instance_path, "output")



#create network
function create_network()

    println("Creating the network")
    network = PSCOPF.Networks.Network()

    network = create_buses(network)
    network = create_branch_limits(network)
    network = create_limitables(network)
    network = create_pilotables(network)
    println("Network created!")

    return network
end

function create_buses(network)
    println("adding buses")
    PSCOPF.Networks.add_new_bus!(network, "bus_1")
    PSCOPF.Networks.add_new_bus!(network, "bus_2")
    return network
end

function create_branch_limits(network)
    println("adding branch_limits")
    PSCOPF.Networks.add_new_branch!(network, "branch_1_2", 500.);
    return network
end

function create_limitables(network)
    println("adding limitables")
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "wind_1", PSCOPF.Networks.LIMITABLE,
                                            0., 200.,
                                            0., 10.,
                                            Dates.Second(15*60), Dates.Second(15*60)) #dmo, dp : always 0. ?
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "wind_2", PSCOPF.Networks.LIMITABLE,
                                            0., 200.,
                                            0., 11.,
                                            Dates.Second(15*60), Dates.Second(15*60))
    return network
end

function create_pilotables(network)
    println("adding pilotables")
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "ccg_1", PSCOPF.Networks.PILOTABLE,
                                            150., 600., #pmin, pmax
                                            45000., 30., #start_cost, prop_cost
                                            Dates.Second(4*3600), Dates.Second(15*60)) #dmo, dp
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_1", "tac_1", PSCOPF.Networks.PILOTABLE,
                                            10., 300.,
                                            12000., 100.,
                                            Dates.Second(30*60), Dates.Second(15*60))
    PSCOPF.Networks.add_new_generator_to_bus!(network, "bus_2", "ccg_2", PSCOPF.Networks.PILOTABLE,
                                            100., 600., #pmin, pmax
                                            50000., 20., #start_cost, prop_cost
                                            Dates.Second(4*3600), Dates.Second(15*60)) #dmo, dp
    return network
end



# create init_state
function create_init_state(network::Union{Nothing,PSCOPF.Network}=nothing)
    println("setting the initial state of generators (ON/OFF)")
    generators_init_state = SortedDict([
                        "ccg_1" => PSCOPF.ON,
                        "ccg_2" => PSCOPF.OFF,
                        "tac_1" => PSCOPF.OFF,
                        ])
    return generators_init_state
end



#generate ptdf
function compute_ptdf(input_path::String, ref_bus_num::Int=1, EPS_DIAG=1e-6, distributed=false)    
    output_path = joinpath(input_path, "pscopf_ptdf.txt")

    network = PTDF.read_network(input_path)
    ptdf = PTDF.compute_ptdf(network, ref_bus_num, EPS_DIAG)
    if distributed
        ptdf = PTDF.distribute_slack(ptdf);
        # coeffs = Dict([ "poste_1_0" => .2,
        #                 "poste_2_0" => .8])
        # ptdf = PTDF.distribute_slack(ptdf, coeffs, network);
    end
    PTDF.write_PTDF(output_path, network, ptdf, distributed, ref_bus_num)

end



###write

function write_branches()
end

function write_buses()
end


### create instance 
function create_instance(dir_path)

    network = create_network()
    write(dir_path, network.generators)
    write(dir_path, network.branches)
    write(dir_path, network.ptdf)

    generators_init_state = create_init_state(network)
    PSCOPF.PSCOPFio.write(dir_path, generators_init_state)

    PSCOPF.check(network)




    println("instance files written to ", dir_path)
end

create_instance(joinpath(@__DIR__, "usecases-euro-with-generator", "test0"))





# load Data
network = PSCOPF.Data.pscopfdata2network(instance_path)
uncertainties = PSCOPF.PSCOPFio.read_uncertainties(instance_path)
generators_init_state = PSCOPF.PSCOPFio.read_initial_state(instance_path)

# Launch mode 1
mode = PSCOPF.PSCOPF_MODE_1

ts1 = Dates.DateTime("2015-01-01T11:00:00") #11h
TS = PSCOPF.create_target_timepoints(ts1) #T: 11h, 11h15, 11h30, 11h45
#ECH = PSCOPF.generate_ech(network, TS, mode) #ech: -4h, -1h, -30mins, -15mins, 0h

#sequence = PSCOPF.generate_sequence(network, TS, ECH, mode)

# Personalised sequence

sequence = PSCOPF.Sequence(Dict([
        ts1 - Dates.Hour(4)     => [PSCOPF.EnergyMarket()],
        ts1 - Dates.Minute(15)  => [PSCOPF.TSOBilevel(), PSCOPF.BalanceMarket()],
        ts1                     => [PSCOPF.BalanceMarket()]
    ]))

PSCOPF.rm_non_prefixed(output_path, "pscopf_")
exec_context = PSCOPF.PSCOPFContext(network, TS, mode,
                                    generators_init_state,
                                    uncertainties, nothing,
                                    output_path)

PSCOPF.run!(exec_context, sequence)
