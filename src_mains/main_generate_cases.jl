"""
    main_ptdf
A main file to generate a PTDF file

Parameters:
    input_path : path to input data directory describing a grid
                (not the pscopf_ files but branches.txt and buses.txt)
"""

using Random
using Dates
using Printf
using StatsBase
using Distributions
using DataStructures
using JuMP

using PSCOPF

root_path = dirname(@__DIR__)
push!(LOAD_PATH, root_path);
cd(root_path)
include(joinpath(root_path, "src", "PTDF.jl"));


###############################################
# Definitions & utils
###############################################

struct PilotableTemplate
    name::String
    p_min::Float64
    p_max::Float64
    start_cost::Float64
    prop_cost::Float64
    dmo::Second
    dp::Second
end


function add_template_to_bus!(network::PSCOPF.Network, bus::PSCOPF.Bus,
                            template::PilotableTemplate)
    unit_name = @sprintf("%s_%s", PSCOPF.get_id(bus), template.name)
    PSCOPF.Networks.add_new_generator_to_bus!(network, PSCOPF.get_id(bus), unit_name, PSCOPF.Networks.PILOTABLE,
                                                template.p_min, template.p_max, #pmin, pmax
                                                template.start_cost, template.prop_cost, #start_cost, prop_cost
                                                template.dmo, template.dp) #dmo, dp
end


"""
probs : list st probs[i] is the probability that a given bus holds exactly i generators
        The probability that a bus holds no generators is 1-sum(probs)
"""
function add_pilotable_generators!(network::PSCOPF.Network, 
                                nb_generators_probabilities::Vector{Float64},
                                # template_probabilities::Vector{Float64},
                                pilotables_templates::Vector{PilotableTemplate})
    @assert (length(nb_generators_probabilities) == length(pilotables_templates))
    @assert all(p>-1e-09 for p in nb_generators_probabilities)
    @assert ( 1 >= sum(nb_generators_probabilities) > 0)

    no_generators_prob = 1 - sum(nb_generators_probabilities)
    nb_generators_probs = ProbabilityWeights(vcat(no_generators_prob, nb_generators_probabilities))
    nb_generators = length(pilotables_templates)

    for bus in PSCOPF.get_buses(network)
        n_generators_on_bus = sample(0:nb_generators, nb_generators_probs)
        templates_to_add = sample(pilotables_templates, n_generators_on_bus, replace=false)
        for pilotable_template in templates_to_add
            add_template_to_bus!(network, bus, pilotable_template)
        end
    end

end


function generate_initial_network(ptdf_network::PTDF.Network,
                                ptdf_folder,
                                default_limit,
                                nb_generators_probabilities, pilotables_templates,
                                )::PSCOPF.Networks.Network
    network = PSCOPF.Networks.Network("generated_network")

    #Buses
    #######
    buses_ids::Set{String} = Set{String}(bus.name for bus in values(ptdf_network.buses))
    PSCOPF.add_new_buses!(network, buses_ids);

    #Branches
    ##########
    branches_ids = Set{String}(branch.name for  branch in values(ptdf_network.branches))
    n_1_cases = branches_ids
    for branch_id in branches_ids
        PSCOPF.add_new_branch!(network, branch_id, default_limit);
        for network_case in n_1_cases
            PSCOPF.add_new_limit!(network, branch_id, network_case, default_limit)
        end
    end

    #PTDF
    ######
    PSCOPF.PSCOPFio.read_ptdf!(network, ptdf_folder)

    #Limitables
    ############
    # None for now

    #Pilotables
    ############
    add_pilotable_generators!(network, nb_generators_probabilities, pilotables_templates)

    return network
end

function generate_init_state(initial_network, output_folder)
    gen_init = SortedDict{String, PSCOPF.GeneratorState}(
        PSCOPF.get_id(gen) => PSCOPF.ON
            for gen in PSCOPF.get_generators(initial_network)
                if PSCOPF.needs_commitment(gen)
    )

    return gen_init
end

function generate_base_consumptions(network::PSCOPF.Network,
                                    ech::DateTime, ts::DateTime, base_s::String,
                                    conso_ratio::Float64)::PSCOPF.Uncertainties
    @assert ( 0 < conso_ratio <= 1. )

    uncertainties = PSCOPF.Uncertainties()

    network_capacity = sum( PSCOPF.get_p_max(generator)
                            for generator in PSCOPF.get_generators_of_type(network, PSCOPF.PILOTABLE))
    total_consumptio = network_capacity * conso_ratio

    nb_buses = PSCOPF.get_nb_buses(network)
    buses_ids = PSCOPF.get_id.(PSCOPF.get_buses(network))
    bus_conso_ratios = rand(Dirichlet(nb_buses, 1.0))
    distribution = Dict(zip(buses_ids, bus_conso_ratios))

    for (bus_id, bus_conso_ratio) in distribution
        conso_l = bus_conso_ratio * total_consumptio
        PSCOPF.add_uncertainty!(uncertainties, ech, bus_id, ts, base_s, conso_l)
    end

    return uncertainties
end


function compute_free_flows(network::PSCOPF.Network, ech, ts, gen_init, uncertainties)
    custom_mode = PSCOPF.ManagementMode("custom_mode", Dates.Minute(60))
    tso = PSCOPF.TSOOutFO(PSCOPF.TSOConfigs(CONSIDER_N_1_CSTRS=true))
    initial_context = PSCOPF.PSCOPFContext(network, [ts], custom_mode,
                                    gen_init,
                                    uncertainties, nothing,
                                    "init_limits")
    result, _ = PSCOPF.run_step!(initial_context, tso, ech, nothing)

    free_flows = SortedDict{Tuple{String,String},Float64}()
    for ((branch_id,_,_,ptdf_case), flow_expr) in result.flows
        free_flows[branch_id, ptdf_case] = value(flow_expr)
    end

    return free_flows
end


function update_network_limits!(network::PSCOPF.Network, flows::SortedDict{Tuple{String,String},Float64}, ratio)
    for ( (branch_id, network_case), flow_l) in flows
        limit_l = ceil(abs(flow_l * ratio))
        PSCOPF.add_new_limit!(network, branch_id, network_case, limit_l)
    end
end


function generate_uncertainties(network, base_values::PSCOPF.UncertaintiesAtEch, ts, base_s, ECH, nb_scenarios, prediction_error)
    TS = PSCOPF.create_target_timepoints(ts)
    uncertainties_distributions = SortedDict{String, PSCOPF.UncertaintyErrorNDistribution}()
    for bus in PSCOPF.get_buses(network)
        bus_id = PSCOPF.get_id(bus)
        uncertainties_distributions[bus_id] = PSCOPF.UncertaintyErrorNDistribution(
                                                            bus_id,
                                                            0., 5000,
                                                            PSCOPF.get_uncertainties(base_values, bus_id, ts, base_s),
                                                            prediction_error,
                                                            )
    end

    return PSCOPF.generate_uncertainties(network,
                                        TS, ECH,
                                        uncertainties_distributions,
                                        nb_scenarios)
end

###############################################
# INPUT & PARAMS
###############################################
Random.seed!(0)

input_path = ( length(ARGS) > 0 ? ARGS[1] :
                    joinpath(@__DIR__, "..", "data_matpower", "case5") )
output_folder = joinpath(@__DIR__, "..", "data", "case5")

# PTDF
#######
ref_bus_num = 1
distributed = true

# Initial Network
##################
default_limit = 1e5
pilotables_templates = [
    PilotableTemplate("_0h",  0., 500.,     0., 30., Second(Minute(15)), Second(Minute(15)))
    PilotableTemplate("_1h", 50., 200., 25000., 25.,    Second(Hour(1)), Second(Minute(15)))
    PilotableTemplate("_2h", 50., 300., 10000., 20.,    Second(Hour(2)), Second(Minute(15)))
    PilotableTemplate("_4h", 50., 600., 15000., 15.,    Second(Hour(4)), Second(Minute(15)))
]
nb_generators_probabilities = [.35, .3, .1, .05] #no_generator_proba : 0.2
@assert (length(nb_generators_probabilities) == length(pilotables_templates))


# Base Uncertainties
#####################
limits_conso_to_unit_capa_ratio = 0.7 #consumption used for branch dimensioning will represent 70% of the units' max capacities (distributed randomly)


# Limits
#########
free_flow_to_limit_ratio = 0.7

# Uncertainties
################
ts1 = DateTime("2015-01-01T11:00:00")
ECH = [ts1-Hour(4), ts1-Hour(2), ts1-Hour(1), ts1-Minute(30), ts1-Minute(15)]
nb_scenarios = 3
prediction_error = 0.01


function main_instance_generate(input_path,
            ref_bus_num, distributed,
            default_limit, nb_generators_probabilities, pilotables_templates,
            limits_conso_to_unit_capa_ratio,
            free_flow_to_limit_ratio,
            ECH, ts, nb_scenarios, prediction_error,
            output_folder)

    ech = ECH[1]

    ###############################################
    # COMPUTE PTDF for N and N-1
    ###############################################
    ptdf_network = PTDF.read_network(input_path)
    time_ptdf = @elapsed PTDF.compute_and_write_all(ptdf_network, ref_bus_num, distributed, output_folder)


    ###############################################
    # Generate Initial Network
    ###############################################
    initial_network = generate_initial_network(ptdf_network,
                                            output_folder,
                                            default_limit,
                                            nb_generators_probabilities, pilotables_templates)
    gen_init = generate_init_state(initial_network, output_folder)
    PSCOPF.PSCOPFio.write(joinpath(output_folder, "initial_network"), initial_network)
    PSCOPF.PSCOPFio.write(joinpath(output_folder, "initial_network"), gen_init)
    PSCOPF.PSCOPFio.write(joinpath(output_folder, "instance"), gen_init)


    ###############################################
    # Generate Base Uncertainties for limits
    ###############################################
    base_consumptions = generate_base_consumptions(initial_network, ech, ts, "BASE_S", limits_conso_to_unit_capa_ratio)
    PSCOPF.PSCOPFio.write(joinpath(output_folder, "initial_network"), base_consumptions)


    ###############################################
    # Compute Base Flows
    ###############################################
    time_free_flows = @elapsed free_flows = compute_free_flows(initial_network, ech, ts, gen_init, base_consumptions)


    ###############################################
    # Generate Network : update branch limits
    ###############################################
    update_network_limits!(initial_network, free_flows, free_flow_to_limit_ratio)
    generated_network = initial_network
    PSCOPF.PSCOPFio.write(joinpath(output_folder, "instance"), generated_network)


    ###############################################
    # Generate Uncertainties
    ###############################################
    uncertainties = generate_uncertainties(generated_network, base_consumptions[ech], ts, "BASE_S", ECH, nb_scenarios, prediction_error)
    PSCOPF.PSCOPFio.write(joinpath(output_folder, "instance"), uncertainties)

    return (generated_network, gen_init, uncertainties), (time_ptdf, time_free_flows)
end

time_generation = @elapsed (generated_network, gen_init, uncertainties), (time_ptdf, time_free_flows) =
                            main_instance_generate(input_path,
                                ref_bus_num, distributed,
                                default_limit, nb_generators_probabilities, pilotables_templates,
                                limits_conso_to_unit_capa_ratio,
                                free_flow_to_limit_ratio,
                                ECH, ts1, nb_scenarios, prediction_error,
                                output_folder)

print("\n"^10)

###############################################
# Solve usecase : mode 1
###############################################
output_mode_1 = joinpath(output_folder, "mode1")
mode_1 = PSCOPF.PSCOPF_MODE_1
TS = PSCOPF.create_target_timepoints(ts1)
sequence = PSCOPF.generate_sequence(generated_network, TS, ECH, mode_1)

PSCOPF.rm_non_prefixed(output_mode_1, "pscopf_")
exec_context = PSCOPF.PSCOPFContext(generated_network, TS, mode_1,
                                    gen_init,
                                    uncertainties, nothing,
                                    output_mode_1)

time_mode_1 = @elapsed PSCOPF.run!(exec_context, sequence)

print("\n"^10)

###############################################
# Solve usecase : mode 2
###############################################
output_mode_2 = joinpath(output_folder, "mode2")
mode_2 = PSCOPF.PSCOPF_MODE_2
TS = PSCOPF.create_target_timepoints(ts1)
sequence = PSCOPF.generate_sequence(generated_network, TS, ECH, mode_2)

PSCOPF.rm_non_prefixed(output_mode_2, "pscopf_")
exec_context = PSCOPF.PSCOPFContext(generated_network, TS, mode_2,
                                    gen_init,
                                    uncertainties, nothing,
                                    output_mode_2)

time_mode_2 = @elapsed PSCOPF.run!(exec_context, sequence)


println("Computing all ptdfs took:", time_ptdf)
println("Computing free flows took :", time_free_flows)
println("Generating the whole network instance took :", time_generation)
println("Mode 1 took :", time_mode_1)
println("Mode 2 took :", time_mode_2)