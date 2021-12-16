mutable struct Bus
    id::Int
    loads::Vector{Load}
    generators::Vector{Generator}

    # Constructor
    function Bus(id::Int)
        return new(id, Vector{Load}(), Vector{Generator}())
    end
end

# Never use it directly, only use add function in Network!!!
function add_new_load!(bus::Bus, load_id::String)::Load
    load::Load = Load(load_id, bus.id)
    push!(bus.loads, load)
    return load
end

# Never use it directly, only use add function in Network!!!
function add_new_generator!(bus::Bus, generator_id::String)::Generator
    generator::Generator = Generator(generator_id, bus.id)
    push!(bus.generators, generator)
    return generator
end

function get_loads(bus::Bus)::Vector{Load}
    return bus.loads
end

function get_generators(bus::Bus)::Vector{Generator}
    return bus.generators
end


################
## INFO / LOG ##
################

function get_info(bus::Bus)::String
    info::String = 
        string(bus.id)
    return info
end
