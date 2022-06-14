using DataStructures

struct Network
    name::String
    # Direct access containers
    buses::SortedDict{String, Bus}
    branches::SortedDict{String, Branch}

    generators::SortedDict{String, Generator}

    #Branch_id, Bus_id
    ptdf::SortedDict{String,SortedDict{String, Float64}}
    #FIXME : create ptdf structure to indicate reference bus

    # Constructor
    function Network(name::String)
        return new( name
                  , SortedDict{String, Bus}()
                  , SortedDict{String, Branch}()
                  , SortedDict{String, Generator}()
                  , SortedDict{String,SortedDict{String, Float64}}()
                  )
    end
end

function Network()
    return Network("empty_network")
end

#########
## Bus ##
#########

function add_new_bus!(network::Network, bus_id::String)
    if haskey(network.buses,bus_id)
        throw( error("Bus with id ", bus_id, " already exists in Network ", network.name) )
    end
    bus = Bus(bus_id)
    network.buses[bus_id] = bus
end

function add_new_buses!(network::Network, buses_id::Vector{String})
    for bus_id in buses_id
        add_new_bus!(network, bus_id)
    end
end

function add_bus!(network::Network, bus::Bus)
    bus_id = bus.id
    if haskey(network.buses,bus_id)
        throw( error("Bus with id ", bus_id, " already exists in Network ", network.name) )
    end
    network.buses[bus_id] = bus
end

function add_buses!(network::Network, buses::Vector{Bus})
    for bus in buses
        add_bus!(network, bus)
    end
end

function get_bus(network::Network, bus_id::String)::Union{Missing, Bus}
    if haskey(network.buses,bus_id)
        return network.buses[bus_id]
    else
        return missing
    end
end

function safeget_bus(network::Network, bus_id::String)::Bus
    bus::Union{Bus, Missing} = get_bus(network, bus_id)
    if !isequal(bus, missing)
        return bus
    else
        throw( error("Bus with id ", bus_id, " does not exist in Network ", network.name) )
    end
end

function get_buses(network::Network)
    return collect(values(network.buses))
end

############
## Branch ##
############

function add_new_branch!(network::Network, id_branch::String, limit::Float64)
    try
        branch = Branch(id_branch, limit)
        network.branches[id_branch] = branch
    catch
        rethrow()
    end
end

function add_branch!(network::Network, branch::Branch)
    try
        network.branches[branch.id] = branch
    catch
        rethrow()
    end
end

function add_branches!(network::Network, branches::Vector{Branch})
    for branch in branches
        add_branch!(network, branch)
    end
end

function get_branch(network::Network, branch_id::String)::Union{Missing, Branch}
    # Get branch
    if haskey(network.branches, branch_id)
        return network.branches[branch_id]
    else
        return missing
    end
end

function safeget_branch(network::Network, branch_id::String)::Branch
    branch::Union{Missing, Branch} = get_branch(network, branch_id)
    if !isequal(branch, missing)
        return branch
    else
        throw( error("Branch ", branch_id, " does not exist in Network ", network.name) )
    end
end

function get_branches(network::Network, bus::Union{Int, Bus})::Vector{Tuple{Branch, Bool}}
    bus_id::Int = typeof(bus) == Int ? bus : bus.id
    branches = Vector{Tuple{Branch, Bool}}()
    if haskey(network.branches, bus_id)
        for branch in values(network.branches[bus_id]) # il y a surement moyen de faire plus efficace
            push!(branches, branch)
        end
    end
    return branches
end

function get_branches(network::Network)
    return values(network.branches)
end


########################
##      Generator     ##
########################

function add_new_generator_to_bus!(network::Network, bus::Union{Bus, String}, generator_id::String,
                                type::GeneratorType, p_min::Float64, p_max::Float64,
                                start_cost::Float64, prop_cost::Float64, dmo::Dates.Second, dp::Dates.Second)
    bus::Bus = typeof(bus) == String ? safeget_bus(network, bus) : bus
    if generator_id in map(bus->get_id(bus), get_buses(network))
        throw( error("Generators and buses must have distinct names :
                    a bus having the name ", generator_id, " already exists.") )
    end
    generator::Generator = add_new_generator!(bus, generator_id,
                                            type, p_min, p_max, start_cost, prop_cost, dmo, dp)
    # Store it in direct access containers
    network.generators[generator_id] = generator
end

function get_generator(network::Network, generator_id::String)
    if haskey(network.generators,generator_id)
        return network.generators[generator_id]
    else
        return missing
    end
end

function safeget_generator(network::Network, generator_id::String)
    generator::Union{Generator, Missing} = get_generator(network, generator_id)
    if !isequal(generator, missing)
        return generator
    else
        throw( error("Generator with id ", generator_id, " does not exist in Network ", network.name) )
    end
end

function get_generators(network::Network)
    return values(network.generators)
end

function get_generators_of_type(generators, type::GeneratorType)
    selected_generators = Vector{Generator}()
    for generator in generators
        if get_type(generator) == type
            push!(selected_generators, generator)
        end
    end
    return selected_generators
end
function get_generators_of_type(bus::Bus, type::GeneratorType)
    return get_generators_of_type(get_generators(bus), type)
end
function get_generators_of_type(network::Network, type::GeneratorType)
    return get_generators_of_type(get_generators(network), type)
end

########################
##        PTDF        ##
########################

function get_ptdf_component(network::Network, branch_id::String)
    if haskey(network.ptdf,branch_id)
        return network.ptdf[branch_id]
    else
        return missing
    end
end

function safeget_ptdf_component(network::Network, branch_id::String)
    ptdf_component::Union{SortedDict{String, Float64}, Missing} = get_ptdf_component(network, branch_id)
    if !isequal(ptdf_component, missing)
        return ptdf_component
    else
        throw( error("PTDF value for branch ", branch_id, " does not exist in Network ", network.name) )
    end
end

function get_ptdf(network::Network, branch_id::String, bus_id::String)
    if haskey(network.ptdf,branch_id)
        if haskey(network.ptdf[branch_id], bus_id)
            return network.ptdf[branch_id][bus_id]
        else
            return missing
        end
    else
        return missing
    end
end

function safeget_ptdf(network::Network, branch_id::String, bus_id::String)
    ptdf::Union{Float64, Missing} = get_ptdf(network, branch_id, bus_id)
    if !isequal(ptdf, missing)
        return ptdf
    else
        throw( error("PTDF value for branch ", branch_id, " and bus ", bus_id, " does not exist in Network ", network.name) )
    end
end

function add_ptdf_elt!(network, branch_id::String, bus_id::String, ptdf_value::Float64)
    ptdf_component = get!(network.ptdf, branch_id, SortedDict{String, Float64}())
    ptdf_component[bus_id] = ptdf_value
end

########################
##        utils       ##
########################

function get_generator_or_bus(network::Network, id::String)
    generator::Union{Generator, Missing} = get_generator(network, id)
    if !isequal(generator, missing)
        return generator
    else
        return get_bus(network, id) #bus or missing
    end
end

function safeget_generator_or_bus(network::Network, id::String)
    generator_or_bus::Union{Generator, Bus, Missing} = get_generator_or_bus(network, id)
    if ismissing(generator_or_bus)
        throw( error("No Generator or Bus with id `", id, "` exists in Network ", network.name) )
    else
        return generator_or_bus
    end
end
