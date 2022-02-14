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

function Base.parse(type::Type{GeneratorType}, str::String)
    if lowercase(str) == "limitable"
        return LIMITABLE
    elseif  lowercase(str) == "imposable"
        return IMPOSABLE
    else
        throw( error("Unable to convert `", str, "` to a GeneratorType") )
    end
end

mutable struct Generator
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
        if p_min < 0
            msg = @sprintf("Invalid input %f : p_min must be positive.", p_min)
            error(msg)
        end
        if p_max < p_min
            msg = @sprintf("Invalid input %f : p_max must be greater than or equal to p_min (i.e. %f).", p_max, p_min)
            error(msg)
        end
        if dmo < dp
            msg = @sprintf("Invalid input %s : dmo must be greater than or equal to dp (i.e. %s).", dmo, dp)
            error(msg)
        end
        if type == LIMITABLE
            if p_min > 0
                msg = @sprintf("Invalid input %f : Limitable units must have a minimum production capacity of 0.", p_min)
                error(msg)
            end
            if start_cost > 0
                msg = @sprintf("Invalid input %f : Limitable units must have a start_cost of 0.", start_cost)
                error(msg)
            end
            if dmo != dp
                #cause no pmin => no DMO
                # => either have DP=DMO for convenience or handle limitables separately so they don't have a commitment_firmness
                msg = @sprintf("Invalid input %s : For limitable units, dmo must be equal to dp (i.e. %s).", dmo, dp)
                error(msg)
            end
        end
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

function safeget_p_max(gen::Generator)
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
