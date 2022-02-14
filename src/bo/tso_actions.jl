using ..Networks

using Dates
using Parameters

##########################################
## TSOActions
##########################################

@with_kw struct TSOActions
    #gen_id, ts => uncertainValue (potentially by scenario)
    limitations::SortedDict{String, SortedDict{Dates.DateTime, UncertainValue{Float64}}} =
        SortedDict{String, SortedDict{Dates.DateTime, UncertainValue{Float64}}}()
    impositions::SortedDict{String, SortedDict{Dates.DateTime, UncertainValue{Float64}}} =
        SortedDict{String, SortedDict{Dates.DateTime, UncertainValue{Float64}}}()
end

## Limitations
#--------------

function get_limitations(tso_actions::TSOActions)
    return tso_actions.limitations
end

function init_limitations!(tso_actions::TSOActions, network::Networks.Network, target_timepoints::Vector{Dates.DateTime}, scenarios::Vector{String})
    limitations = get_limitations(tso_actions)
    empty!(limitations)
    for generator_l in Networks.get_generators_of_type(network, Networks.LIMITABLE)
        gen_id = Networks.get_id(generator_l)
        limitations[gen_id] = SortedDict{Dates.DateTime, UncertainValue{Float64}}()
        for ts in target_timepoints
            limitations[gen_id][ts] = UncertainValue{Float64}(scenarios)
        end
    end
end

function get_limitations(tso_actions::TSOActions, gen_id::String)::Union{Missing,SortedDict{Dates.DateTime, UncertainValue{Float64}}}
    limitations = get_limitations(tso_actions)
    if haskey(limitations, gen_id)
        return limitations[gen_id]
    else
        return missing
    end
end
function get_limitations!(tso_actions::TSOActions, gen_id::String)::SortedDict{Dates.DateTime, UncertainValue{Float64}}
    limitations = get_limitations(tso_actions)
    return get!(limitations, gen_id, SortedDict{Dates.DateTime, UncertainValue{Float64}}())
end

function get_limitations_uncertain_value(tso_actions::TSOActions, gen_id::String, ts::Dates.DateTime)::Union{Missing,UncertainValue{Float64}}
    limitations = get_limitations(tso_actions, gen_id)
    if ismissing(limitations)
        return missing
    else
        if haskey(limitations, ts)
            return limitations[ts]
        else
            return missing
        end
    end
end
function get_limitations_uncertain_value!(tso_actions::TSOActions, gen_id::String, ts::Dates.DateTime)::UncertainValue{Float64}
    limitations = get_limitations!(tso_actions, gen_id)
    return get!(limitations, ts, UncertainValue{Float64}())
end

function get_limitation(tso_actions::TSOActions, gen_id::String, ts::Dates.DateTime)::Union{Float64, Missing}
    limitation_uncertain_value = get_limitations_uncertain_value(tso_actions, gen_id, ts)
    if ismissing(limitation_uncertain_value)
        return missing
    else
        return get_value(limitation_uncertain_value)
    end
end

function get_limitation(tso_actions::TSOActions, gen_id::String, ts::Dates.DateTime, scenario::String)::Union{Float64, Missing}
    limitation_uncertain_value = get_limitations_uncertain_value(tso_actions, gen_id, ts)
    if ismissing(limitation_uncertain_value)
        return missing
    else
        return get_value(limitation_uncertain_value, scenario)
    end
end

function set_limitation_value!(tso_actions, gen_id::String, ts::Dates.DateTime, scenario::String, value::Float64)
    uncertain_value = get_limitations_uncertain_value!(tso_actions, gen_id, ts)
    set_value!(uncertain_value, scenario, value)
end

function set_definitive_limitation_value!(tso_actions, gen_id::String, ts::Dates.DateTime, value::Float64)
    uncertain_value = get_limitations_uncertain_value!(tso_actions, gen_id, ts)
    set_definitive_value!(uncertain_value, value)
end

## Impositions
#--------------

function get_impositions(tso_actions::TSOActions)
    return tso_actions.impositions
end

function init_impositions!(tso_actions::TSOActions, network::Networks.Network, target_timepoints::Vector{Dates.DateTime}, scenarios::Vector{String})
    impositions = get_impositions(tso_actions)
    empty!(impositions)
    for generator_l in Networks.get_generators_of_type(network, Networks.IMPOSABLE)
        gen_id = Networks.get_id(generator_l)
        impositions[gen_id] = SortedDict{Dates.DateTime, UncertainValue{Float64}}()
        for ts in target_timepoints
            impositions[gen_id][ts] = UncertainValue{Float64}(scenarios)
        end
    end
end

function get_impositions(tso_actions::TSOActions, gen_id::String)::Union{Missing,SortedDict{Dates.DateTime, UncertainValue{Float64}}}
    impositions = get_impositions(tso_actions)
    if haskey(impositions, gen_id)
        return impositions[gen_id]
    else
        return missing
    end
end
function get_impositions!(tso_actions::TSOActions, gen_id::String)::SortedDict{Dates.DateTime, UncertainValue{Float64}}
    impositions = get_impositions(tso_actions)
    return get!(impositions, gen_id, SortedDict{Dates.DateTime, UncertainValue{Float64}}())
end

function get_impositions_uncertain_value(tso_actions::TSOActions, gen_id::String, ts::Dates.DateTime)::Union{Missing,UncertainValue{Float64}}
    impositions = get_impositions(tso_actions, gen_id)
    if ismissing(impositions)
        return missing
    else
        if haskey(impositions, ts)
            return impositions[ts]
        else
            return missing
        end
    end
end
function get_impositions_uncertain_value!(tso_actions::TSOActions, gen_id::String, ts::Dates.DateTime)::UncertainValue{Float64}
    impositions = get_impositions!(tso_actions, gen_id)
    return get!(impositions, ts, UncertainValue{Float64}())
end

function get_imposition(tso_actions::TSOActions, gen_id::String, ts::Dates.DateTime)::Union{Float64, Missing}
    imposition_uncertain_value = get_impositions_uncertain_value(tso_actions, gen_id, ts)
    if ismissing(imposition_uncertain_value)
        return missing
    else
        return get_value(imposition_uncertain_value)
    end
end

function get_imposition(tso_actions::TSOActions, gen_id::String, ts::Dates.DateTime, scenario::String)::Union{Float64, Missing}
    imposition_uncertain_value = get_impositions_uncertain_value(tso_actions, gen_id, ts)
    if ismissing(imposition_uncertain_value)
        return missing
    else
        return get_value(imposition_uncertain_value, scenario)
    end
end

function set_imposition_value!(tso_actions, gen_id::String, ts::Dates.DateTime, scenario::String, value::Float64)
    #FIXME : error when the scenario was not defined ?
    uncertain_value = get_impositions_uncertain_value!(tso_actions, gen_id, ts)
    set_value!(uncertain_value, scenario, value)
end

function set_definitive_imposition_value!(tso_actions, gen_id::String, ts::Dates.DateTime, value::Float64)
    uncertain_value = get_impositions_uncertain_value!(tso_actions, gen_id, ts)
    set_definitive_value!(uncertain_value, value)
end
