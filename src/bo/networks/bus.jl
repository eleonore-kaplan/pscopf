struct Bus
    id::String
    generators::Vector{Generator}

    # Constructor
    function Bus(id::String)
        return new(id, Vector{Generator}())
    end
end

# Never use it directly, only use add function in Network!!!
function add_new_generator!(bus::Bus, generator_id::String,
                            type::GeneratorType, p_min::Float64, p_max::Float64,
                            start_cost::Float64, prop_cost::Float64, dmo::Dates.Second, dp::Dates.Second
                            )::Generator
    generator::Generator = Generator(generator_id, bus.id,
                                    type, p_min, p_max, start_cost, prop_cost, dmo, dp)
    push!(bus.generators, generator)
    return generator
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
