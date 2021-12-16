
mutable struct Generator
    id::String
    bus_id::Int # pas directement un Bus, parce que ca fait des porblemes de references circulaires
end


################
## INFO / LOG ##
################

function get_info(generator::Generator)::String
    info::String = 
        generator.id
    return info
end
