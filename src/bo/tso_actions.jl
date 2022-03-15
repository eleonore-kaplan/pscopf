using Dates
using Parameters
using DataStructures

##########################################
## TSOActions
##########################################

@with_kw struct TSOActions
    #gen_id, ts => Float (values are firm)
    limitations::SortedDict{Tuple{String, Dates.DateTime}, Float64} =
        SortedDict{Tuple{String, Dates.DateTime}, Float64}()
    impositions::SortedDict{Tuple{String, Dates.DateTime}, Float64} =
        SortedDict{Tuple{String, Dates.DateTime}, Float64}()
end

## Limitations
#--------------

function get_limitations(tso_actions::TSOActions)
    return tso_actions.limitations
end
function get_limitations(limitations_dict::SortedDict{Tuple{String, Dates.DateTime}, Float64})
    return limitations_dict
end
function get_impositions(impositions_dict::SortedDict{Tuple{String, Dates.DateTime}, Float64})
    return impositions_dict
end

function get_limitation(tso_actions, gen_id::String, ts::Dates.DateTime)::Union{Float64, Missing}
    limitations = get_limitations(tso_actions)
    if !haskey(limitations, (gen_id, ts))
        return missing
    else
        return limitations[gen_id, ts]
    end
end
function safeget_limitation(tso_actions, gen_id::String, ts::Dates.DateTime)::Union{Float64, Missing}
    limitation = get_limitation(tso_actions, gen_id, ts)
    if ismissing(limitation)
        msg = @sprintf("Missing limitation value for (gen_id=%s,ts=%s).", gen_id, ts)
        throw( error(msg) )
    else
        return limitations[gen_id, ts]
    end
end

function set_limitation_value!(tso_actions, gen_id::String, ts::Dates.DateTime, value::Float64)
    limitations = get_limitations(tso_actions)
    limitations[gen_id, ts] = value
end

## Impositions
#--------------

function get_impositions(tso_actions::TSOActions)
    return tso_actions.impositions
end

function get_imposition(tso_actions::TSOActions, gen_id::String, ts::Dates.DateTime)::Union{Float64, Missing}
    impositions = get_impositions(tso_actions)
    if !haskey(impositions, (gen_id, ts))
        return missing
    else
        return impositions[gen_id, ts]
    end
end

function set_imposition_value!(tso_actions, gen_id::String, ts::Dates.DateTime, value::Float64)
    impositions = get_impositions(tso_actions)
    impositions[gen_id, ts] = value
end
