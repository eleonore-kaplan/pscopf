using .Networks

using Printf
using Dates
using Parameters

@enum GeneratorState begin
    ON
    OFF
end

function Base.parse(type::Type{GeneratorState}, str::String)
    if lowercase(str) == "on"
        return ON
    elseif  lowercase(str) == "off"
        return OFF
    else
        throw( error("Unable to convert `", str, "` to a GeneratorType") )
    end
end

function Base.parse(type::Type{GeneratorState}, val::Float64)
    if val > 1e-9
        return ON
    else
        return OFF
    end
end

##########################################
## Firmness
##########################################

@enum DecisionFirmness begin
    DECIDED # a firm decision was already taken
    TO_DECIDE # a firm decision needs to be taken
    FREE # by scenario decisions
end

@with_kw struct Firmness
    #gen,ts
    commitment::SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} } =
        SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} }()
    power_level::SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} } =
        SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} }()

    #FIXME firmness for Plim of Limitables ? (not concerned by commitment normally)
    # as implemented now, will look at the dmo/dp (which are 0 for limitables)
    # => FREE decisions for limitables
end

function set_commitment_firmness!(firmness::Firmness, gen_id::String, ts, decision_firmness::DecisionFirmness)
    get!(firmness.commitment, gen_id, SortedDict{Dates.DateTime, DecisionFirmness}())
    firmness.commitment[gen_id][ts] = decision_firmness
end

function set_power_level_firmness!(firmness::Firmness, gen_id::String, ts, decision_firmness::DecisionFirmness)
    get!(firmness.power_level, gen_id, SortedDict{Dates.DateTime, DecisionFirmness}())
    firmness.power_level[gen_id][ts] = decision_firmness
end

function get_commitment_firmness(firmness::Firmness, gen_id::String)
    if haskey(firmness.commitment,gen_id)
        return firmness.commitment[gen_id]
    else
        return missing
    end
end

function get_commitment_firmness(firmness::Firmness, gen_id::String, ts::Dates.DateTime)
    if haskey(firmness.commitment,gen_id)
        if haskey(firmness.commitment[gen_id], ts)
            return firmness.commitment[gen_id][ts]
        else
            return missing
        end
    else
        return missing
    end
end

function get_power_level_firmness(firmness::Firmness, gen_id::String)
    if haskey(firmness.power_level,gen_id)
        return firmness.power_level[gen_id]
    else
        return missing
    end
end

function get_power_level_firmness(firmness::Firmness, gen_id::String, ts::Dates.DateTime)
    if haskey(firmness.power_level,gen_id)
        if haskey(firmness.power_level[gen_id], ts)
            return firmness.power_level[gen_id][ts]
        else
            return missing
        end
    else
        return missing
    end
end

##########################################
## UncertainValue
##########################################

mutable struct UncertainValue{T}
    definitive_value::Union{T, Missing}
    anticipated_value::SortedDict{String, Union{T, Missing}}
end

function UncertainValue{T}() where T
    return UncertainValue{T}( missing, SortedDict{String, T}() )
end
function UncertainValue{T}(scenarios::Vector{String}) where T
    antcipated_values = SortedDict(zip(scenarios, fill(missing, length(scenarios))))
    return UncertainValue{T}(missing, antcipated_values)
end

function set_value!(uncertain_value::UncertainValue{T}, scenario::String, value::T)::Union{T, Missing} where T
    uncertain_value.anticipated_value[scenario] = value
end

function set_definitive_value!(uncertain_value::UncertainValue{T}, value::T)::Union{T, Missing} where T
    uncertain_value.definitive_value = value
    for (scenario, _) in uncertain_value.anticipated_value
        uncertain_value.anticipated_value[scenario] = value
    end
end

function get_value(uncertain_value::UncertainValue{T})::Union{T, Missing} where T
    return uncertain_value.definitive_value
end

function safeget_value(uncertain_value::UncertainValue{T})::Union{T, Missing} where T
    definitiveValue = uncertain_value.definitive_value
    if !isequal(definitiveValue, missing)
        return definitiveValue
    else
        throw( error("UncertainValue is not definitive") )
    end
end

function get_value(uncertain_value::UncertainValue{T}, scenario::String)::T where T
    return uncertain_value.anticipated_value[scenario]
end

function safeget_value(uncertain_value::UncertainValue{T}, scenario::String)::T where T
    value = uncertain_value.anticipated_value[scenario]
    if !isequal(value, missing)
        return value
    else
        msg = @sprintf("No decision was made for scenario %s yet", scenario)
        throw( error(msg) )
    end
end

##########################################
## Schedule
##########################################

struct Schedule <: AbstractSchedule
    type::DeciderType
    decision_time::Dates.DateTime
    #TS => sub-keys : id of a : generator, reserve, relaxation,... => uncertainValue
    values::SortedDict{Dates.DateTime, SortedDict{String, UncertainValue{Float64}} }
end

function Schedule(type::DeciderType, ech::Dates.DateTime)
    return Schedule(type, ech, SortedDict{Dates.DateTime, SortedDict{String, UncertainValue{Float64}}}())
end
function Schedule(step::AbstractRunnable, ech::Dates.DateTime)
    return Schedule(DeciderType(step), ech, SortedDict{Dates.DateTime, SortedDict{String, UncertainValue{Float64}}}())
end

function init!(schedule::Schedule, network::Networks.Network, target_timepoints::Vector{Dates.DateTime}, scenarios::Vector{String})
    empty!(schedule.values)
    for ts in target_timepoints
        schedule.values[ts] = SortedDict{String, UncertainValue{Float64}}()
        for generator_l in Networks.get_generators(network)
            schedule.values[ts][Networks.get_id(generator_l)] = UncertainValue{Float64}(scenarios::Vector{String})
        end
    end
end

function get_values(schedule::Schedule)
    return schedule.values
end

function get_values(schedule::Schedule, ts::Dates.DateTime)::SortedDict{String, UncertainValue{Float64}}
    return get_values(schedule)[ts]
end

function get_uncertain_value(schedule::Schedule, ts::Dates.DateTime, id::String)::UncertainValue{Float64}
    return get_values(schedule, ts)[id]
end

function get_value(schedule::Schedule, ts::Dates.DateTime, id::String)::Union{Float64, Missing}
    return get_value(get_values(schedule, ts)[id])
end

function get_value(schedule::Schedule, ts::Dates.DateTime, id::String, scenario::String)::Union{Float64, Missing}
    return get_value( get_values(schedule, ts)[id], scenario)
end

function set_value!(schedule, ts::Dates.DateTime, id::String, scenario::String, value::Float64)
    uncertain_value = get_uncertain_value(schedule, ts, id)
    set_value!(uncertain_value, scenario, value)
end

function set_definitive_value!(schedule, ts::Dates.DateTime, id::String, value::Float64)
    uncertain_value = get_uncertain_value(schedule, ts, id)
    set_definitive_value!(uncertain_value, value)
end
