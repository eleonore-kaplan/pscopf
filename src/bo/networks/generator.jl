using Dates

@enum GeneratorType begin
    LIMITABLE
    IMPOSABLE
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
    dmo::Dates.Minute
    dp::Dates.Minute
end


################
## INFO / LOG ##
################

function get_info(generator::Generator)::String
    info::String =
        generator.id
    return info
end
