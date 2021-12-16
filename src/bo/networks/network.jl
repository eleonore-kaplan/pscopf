using DataStructures

mutable struct Network
    name::String
    buses::OrderedDict{Int, Bus}
    branches::OrderedDict{Int, OrderedDict{Int, Tuple{Branch, Bool}}}

    # Direct access containers
    loads::OrderedDict{String, Load}
    generators::OrderedDict{String, Generator}

    # Constructor
    function Network(name::String)
        return new( name
                  , OrderedDict{Int, Bus}()
                  , OrderedDict{Int, OrderedDict{Int, Tuple{Branch, Bool}}}()
                  , OrderedDict{String, Load}()
                  , OrderedDict{String, Generator}())
    end
end

#########
## Bus ##
#########

function add_new_bus!(network::Network, bus_id::Int)
    if haskey(network.buses,bus_id)
        throw( error("Bus with id ", bus_id, " already exists in Network ", network.name) )
    end
    bus = Bus(bus_id)
    network.buses[bus_id] = bus
end

function add_new_buses!(network::Network, buses_id::Vector{Int})
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

function get_bus(network::Network, bus_id::Int)::Union{Missing, Bus}
    if haskey(network.buses,bus_id)
        return network.buses[bus_id]
    else
        return missing
    end
end

function safeget_bus(network::Network, bus_id::Int)::Bus
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

function check_branch(network::Network, bus_src_id::Int, bus_dst_id::Int)
    # Buses must exist
    if !haskey(network.buses,bus_src_id)
        throw( error("Cannot add Branch from Bus ", bus_src_id, ": Bus does not exist in Network ", network.name) )
    end
    if !haskey(network.buses,bus_dst_id)
        throw( error("Cannot add Branch to Bus ", bus_dst_id, ": Bus does not exist in Network ", network.name) )
    end
    # Branch should not have already been defined
    if haskey(network.branches,bus_src_id) # genial julia qui peut pas faire la deuxieme condition en un if
        if haskey(network.branches[bus_src_id],bus_dst_id)
            throw( error("Branch from Bus ", bus_src_id, " to Bus ", bus_dst_id, " already exists in Network ", network.name) )
        end
    end
    if haskey(network.branches,bus_dst_id) # idem
        if haskey(network.branches[bus_dst_id],bus_src_id)
            throw( error("Branch from Bus ", bus_dst_id, " to Bus ", bus_src_id, " already exists in Network ", network.name) )
        end
    end
    # No branch to oneself
    if bus_src_id == bus_dst_id
        throw( error("Cannot add Branch from Bus ", bus_src_id, " to itself") )
    end
end

function add_new_branch!(network::Network, bus_src::Union{Int,Bus}, bus_dst::Union{Int,Bus})
    # Retrieve buses ids
    bus_src_id::Int = typeof(bus_src) == Int ? bus_src : bus_src.id
    bus_dst_id::Int = typeof(bus_dst) == Int ? bus_dst : bus_dst.id
    try
        check_branch(network, bus_src_id, bus_dst_id)
        # Create branch
        branch = Branch(bus_src_id, bus_dst_id)
        # Store it
        if !haskey(network.branches, bus_src_id)
            network.branches[bus_src_id] = OrderedDict{Int, Tuple{Branch, Bool}}()
        end
        network.branches[bus_src_id][bus_dst_id] = (branch, true)
        if !haskey(network.branches, bus_dst_id)
            network.branches[bus_dst_id] = OrderedDict{Int, Tuple{Branch, Bool}}()
        end
        network.branches[bus_dst_id][bus_src_id] = (branch, false)
    catch
        rethrow()
    end
end

# NB : on ne peut pas faire un type Tuple{Union{Int, Bus}, Union{Int, Bus}}
# c'est mal interprete derrire.
# ou alors lors de l'appel il faut re-preciser le type. Ce qui est lourd alors que la fonction doit simplifier la vie
function add_new_branches!(network::Network, buses_src_dst::Vector{Tuple{Int, Int}})
    for branch_src_dst in buses_src_dst
        add_new_branch!(network, branch_src_dst[1], branch_src_dst[2])
    end
end

function add_banch!(network::Network, branch::Branch)
    bus_src_id::Int = branch.src
    bus_dst_id::Int = branch.dst
    try
        check_branch(network, bus_src_id, bus_dst_id)
        if !haskey(network.branches, bus_src_id)
            network.branches[bus_src_id] = OrderedDict{Int, Tuple{Branch, Bool}}()
        end
        network.branches[bus_src_id][bus_dst_id] = (branch, true)
        if !haskey(network.branches, bus_dst_id)
            network.branches[bus_dst_id] = OrderedDict{Int, Tuple{Branch, Bool}}()
        end
        network.branches[bus_dst_id][bus_src_id] = (branch, false)
    catch
        rethrow()
    end
end

function add_branches!(network::Network, branches::Vector{Branch})
    for branch in branches
        add_branch!(network, branch)
    end
end

function get_branch(network::Network, bus_src::Union{Int, Bus}, bus_dst::Union{Int, Bus})::Union{Missing, Tuple{Branch, Bool}}
    # Retrieve buses ids
    bus_src_id::Int = typeof(bus_src) == Int ? bus_src : bus_src.id
    bus_dst_id::Int = typeof(bus_dst) == Int ? bus_dst : bus_dst.id
    # Get branch
    if haskey(network.branches, bus_src_id)
        if haskey(network.branches[bus_src_id], bus_dst_id)
            return network.branches[bus_src_id][bus_dst_id]
        else
            return missing
        end
    else
        return missing
    end
end

function safeget_branch(network::Network, bus_src::Union{Int, Bus}, bus_dst::Union{Int, Bus})::Tuple{Branch, Bool}
    branch::Union{Missing, Tuple{Branch, Bool}} = get_branch(network, bus_src, bus_dst)
    if !isequal(branch, missing)
        return branch
    else
        throw( error("Branch from Bus ", bus_src, " to Bus ", bus_dst, " does not exist in Network ", network.name) )
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
## Load and Generator ##
########################

function add_new_load_to_bus!(network::Network, bus::Union{Bus, Int}, load_id::String)
    bus::Bus = typeof(bus) == Int ? get_bus(network, bus) : bus
    load::Load = add_new_load!(bus, load_id)
    # Store it in direct access containers
    network.loads[load_id] = load
end

function add_new_generator_to_bus!(network::Network, bus::Union{Bus, Int}, generator_id::String)
    bus::Bus = typeof(bus) == Int ? get_bus(network, bus) : bus
    generator::Generator = add_new_generator!(bus, generator_id)
    # Store it in direct access containers
    network.generators[generator_id] = generator
end

function get_load(network::Network, load_id::String)
    if haskey(network.loads,load_id)
        return network.loads[load_id]
    else
        return missing
    end
end

function safeget_load(network::Network, load_id::String)
    load::Union{Load, Missing} = get_load(network, load_id)
    if !isequal(load, missing)
        return load
    else
        throw( error("Load with id ", load_id, " does not exist in Network ", network.name) )
    end
end

function get_loads(network::Network)
    return values(network.loads)
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
