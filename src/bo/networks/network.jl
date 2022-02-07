using DataStructures

using ..PSCOPF

mutable struct Network <: PSCOPF.AbstractGrid
    name::String
    # Direct access containers
    buses::OrderedDict{String, Bus}
    branches::OrderedDict{String, Branch}

    generators::OrderedDict{String, Generator}

    #Branch_id, Bus_id
    ptdf::OrderedDict{String,OrderedDict{String, Float64}}

    # Constructor
    function Network(name::String)
        return new( name
                  , OrderedDict{String, Bus}()
                  , OrderedDict{String, Branch}()
                  , OrderedDict{String, Generator}()
                  , OrderedDict{String,OrderedDict{String, Float64}}()
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
    return values(network.buses)
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

function get_branch(network::Network, bus_id::String)::Union{Missing, Branch}
    # Get branch
    if haskey(network.branches, bus_id)
        return network.branches[bus_id]
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
    branches = Vector{Tuple{Branch, Bool}}()
    for bus_src in values(network.branches)
        for branch in values(bus_src)
            push!(branches, branch)
        end
    end
    return branches
end


########################
##      Generator     ##
########################

function add_new_generator_to_bus!(network::Network, bus::Union{Bus, String}, generator_id::String,
                                type::GeneratorType, p_min::Float64, p_max::Float64,
                                start_cost::Float64, prop_cost::Float64, dmo::Dates.Second, dp::Dates.Second)
    bus::Bus = typeof(bus) == String ? get_bus(network, bus) : bus
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
    ptdf_component::Union{OrderedDict{String, Float64}, Missing} = get_ptdf_component(network, branch_id)
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

function add_ptdf_elt(network, branch_id::String, bus_id::String, ptdf_value::Float64)
    ptdf_component = get!(network.ptdf, branch_id, OrderedDict{String, Float64}())
    ptdf_component[bus_id] = ptdf_value
end
