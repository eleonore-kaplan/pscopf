using Dates
using Parameters
using DataStructures

##########################################
## TSOActions
##########################################

@with_kw struct TSOActions
    #gen_id, ts => Float (values are firm)
    # Max allowed P of a limitable for a given ts
    limitations::SortedDict{Tuple{String, Dates.DateTime}, Float64} =
        SortedDict{Tuple{String, Dates.DateTime}, Float64}()
    # Imposed P of a imposable for a given ts
    impositions::SortedDict{Tuple{String, Dates.DateTime}, Float64} =
        SortedDict{Tuple{String, Dates.DateTime}, Float64}()
    # Imposed commitment of a generator (with Pmin>0) for a given ts
    commitments::SortedDict{Tuple{String, Dates.DateTime}, GeneratorState} =
        SortedDict{Tuple{String, Dates.DateTime}, GeneratorState}()
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

function safeget_imposition(tso_actions, gen_id::String, ts::Dates.DateTime)::GeneratorState
    imposition = get_imposition(tso_actions, gen_id, ts)
    if ismissing(imposition)
        msg = @sprintf("No imposition entry in TSOActions for (gen_id=%s,ts=%s).", gen_id, ts)
        throw(error(msg))
    else
        return imposition
    end
end

function set_imposition_value!(tso_actions, gen_id::String, ts::Dates.DateTime, value::Float64)
    impositions = get_impositions(tso_actions)
    impositions[gen_id, ts] = value
end

## Commitment
#--------------

function get_commitments(tso_actions)
    return tso_actions.commitments
end

function get_commitment(tso_actions, gen_id::String, ts::Dates.DateTime)::Union{GeneratorState, Missing}
    commitment = get_commitments(tso_actions)
    if !haskey(commitment, (gen_id, ts))
        return missing
    else
        return commitment[gen_id, ts]
    end
end

function safeget_commitment(tso_actions, gen_id::String, ts::Dates.DateTime)::GeneratorState
    commitment = get_commitment(tso_actions, gen_id, ts)
    if ismissing(commitment)
        msg = @sprintf("No commitment entry in TSOActions for (gen_id=%s,ts=%s).", gen_id, ts)
        throw(error(msg))
    else
        return commitment
    end
end

function set_commitment_value!(tso_actions, gen_id::String, ts::Dates.DateTime, value::GeneratorState)
    commitment = get_commitments(tso_actions)
    commitment[gen_id, ts] = value
end

function get_commitments(tso_actions, gen_id::String)
    gen_commitments = SortedDict{Dates.DateTime, GeneratorState}
    for ((gen_id_l,ts),commitment_val) in get_commitments(tso_actions)
        if gen_id_l == gen_id
            gen_commitments[ts] = commitment_val
        end
    end
    return gen_commitments
end

"""
Performs a partial shallow copy of the input TSOActions
Modifying the returned tso_actions' kept attributes will modify the original one's.
"""
function filter_tso_actions(tso_actions::TSOActions;
                        keep_limitations::Bool=false,
                        keep_impositions::Bool=false,
                        keep_commitments::Bool=false)::TSOActions
    limitations_l = keep_limitations ? tso_actions.limitations : SortedDict{Tuple{String, Dates.DateTime}, Float64}()
    impositions_l = keep_impositions ? tso_actions.impositions : SortedDict{Tuple{String, Dates.DateTime}, Float64}()
    commitments_l = keep_commitments ? tso_actions.commitments : SortedDict{Tuple{String, Dates.DateTime}, GeneratorState}()

    return TSOActions(limitations_l, impositions_l, commitments_l)
end
