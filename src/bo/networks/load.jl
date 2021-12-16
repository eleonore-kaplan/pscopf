
mutable struct Load
    id::String
    bus_id::Int # pas directement un Bus, parce que ca fait des porblemes de references circulaires
end


################
## INFO / LOG ##
################

function get_info(load::Load)::String
    # utiliser * pour composer des string,
    # et les "\n" passent pour faire des retours à la ligne dans l'affichage du graphe
    info::String = 
        load.id
    return info
end
