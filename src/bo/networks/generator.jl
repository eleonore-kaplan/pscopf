using Dates
using Printf

@enum GeneratorType begin
    LIMITABLE
    IMPOSABLE
end

function Base.string(g::GeneratorType)
    if g==IMPOSABLE
        return "Imposable"
    elseif g==LIMITABLE
        return "Limitable"
    else
        throw( error("Undefined conversion of GeneratorType `", g, "` to a string") )
    end
end

function Base.parse(::Type{GeneratorType}, str::String)
    if lowercase(str) == "limitable"
        return LIMITABLE
    elseif  lowercase(str) == "imposable"
        return IMPOSABLE
    else
        throw( error("Unable to convert `", str, "` to a GeneratorType") )
    end
end

struct Generator
    id::String
    bus_id::String # pas directement un Bus, parce que ca fait des porblemes de references circulaires

    type::GeneratorType
    p_min::Float64
    p_max::Float64
    start_cost::Float64
    prop_cost::Float64
    dmo::Dates.Second
    dp::Dates.Second

    function Generator(id::String, bus_id::String,
                        type::GeneratorType,
                        p_min::Float64, p_max::Float64,
                        start_cost::Float64, prop_cost::Float64,
                        dmo::Dates.Second, dp::Dates.Second)
        return new(id, bus_id, type, p_min, p_max, start_cost, prop_cost, dmo, dp)
    end
end

function get_bus_id(gen::Generator)
    return gen.bus_id
end

function get_type(gen::Generator)
    return gen.type
end

function get_p_min(gen::Generator)
    return gen.p_min
end

function get_p_max(gen::Generator)
    return gen.p_max
end

function get_start_cost(gen::Generator)
    return gen.start_cost
end

function get_prop_cost(gen::Generator)
    return gen.prop_cost
end

function get_dmo(gen::Generator)
    return gen.dmo
end

function get_dp(gen::Generator)
    return gen.dp
end


################
## INFO / LOG ##
################

function get_info(generator::Generator)::String
    info::String =
        generator.id
    return info
end
