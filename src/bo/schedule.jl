using .Networks

using Printf
using Dates
using Parameters

@enum GeneratorState begin
    ON
    OFF
end

function float(generator_state::GeneratorState)
    if generator_state == ON
        return 1.
    elseif generator_state == OFF
        return 0.
    else
        throw( error("Unknown GeneratorState value : ", generator_state) )
    end
end

function Base.parse(type::Type{GeneratorState}, str::String)
    if lowercase(str) == "on"
        return ON
    elseif  lowercase(str) == "off"
        return OFF
    else
        throw( error("Unable to convert `", str, "` to a GeneratorState") )
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
    #FIXME: add a scenario list if need to check only certain scenarios are handled
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
    if is_definitive(uncertain_value)
        existing_value = get_value(uncertain_value)
        throw( error("A definitive value was already set to the UncertainValue : ", existing_value) )
    else
        uncertain_value.anticipated_value[scenario] = value
    end
end

function is_definitive(uncertain_value::UncertainValue{T})::Bool where T
    existing_value = get_value(uncertain_value)
    return !ismissing(existing_value)
end

function set_definitive_value!(uncertain_value::UncertainValue{T}, value::T)::Union{T, Missing} where T
    if is_definitive(uncertain_value)
        existing_value = get_value(uncertain_value)
        throw( error("A definitive value was already set to the UncertainValue : ", existing_value) )
    else
        uncertain_value.definitive_value = value
        for (scenario, _) in uncertain_value.anticipated_value
            uncertain_value.anticipated_value[scenario] = value
        end
    end
    return uncertain_value.definitive_value
end

function get_value(uncertain_value::UncertainValue{T})::Union{T, Missing} where T
    return uncertain_value.definitive_value
end

function safeget_value(uncertain_value::UncertainValue{T})::Union{T, Missing} where T
    if is_definitive(uncertain_value)
        return get_value(uncertain_value)
    else
        throw( error("UncertainValue is not definitive") )
    end
end

function get_value(uncertain_value::UncertainValue{T}, scenario::String)::Union{Missing,T} where T
    if is_definitive(uncertain_value)
        return get_value(uncertain_value)
    else
        if haskey(uncertain_value.anticipated_value, scenario)
            return uncertain_value.anticipated_value[scenario]
        else
            return missing
        end
    end
end

function safeget_value(uncertain_value::UncertainValue{T}, scenario::String)::T where T
    value = get_value(uncertain_value, scenario)
    if !ismissing( value )
        return value
    else
        msg = @sprintf("No decision was made for scenario %s yet", scenario)
        throw( error(msg) )
    end
end

##########################################
## Schedule
##########################################

GeneratorSchedule = SortedDict{Dates.DateTime, UncertainValue{Float64}}
mutable struct Schedule <: AbstractSchedule
    type::DeciderType
    decision_time::Dates.DateTime
    #gen_id => ts => uncertainValue(s)
    values::SortedDict{String, GeneratorSchedule }
end

function Schedule(type::DeciderType, ech::Dates.DateTime)
    return Schedule(type, ech, SortedDict{String, GeneratorSchedule}())
end

function init!(schedule::Schedule, network::Networks.Network, target_timepoints::Vector{Dates.DateTime}, scenarios::Vector{String})
    empty!(schedule.values)
    for generator_l in Networks.get_generators(network)
        gen_id = Networks.get_id(generator_l)
        schedule.values[gen_id] = SortedDict{String, GeneratorSchedule}()
        for ts in target_timepoints
            schedule.values[gen_id][ts] = UncertainValue{Float64}(scenarios)
        end
    end
end

function get_values(schedule::Schedule)
    return schedule.values
end

function get_sub_schedule(schedule::Schedule, gen_id::String)::SortedDict{Dates.DateTime, UncertainValue{Float64}}
    return get_values(schedule)[gen_id]
end

function get_uncertain_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime)::UncertainValue{Float64}
    return sub_schedule[ts]
end
function get_uncertain_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime)::UncertainValue{Float64}
    return get_uncertain_value(get_sub_schedule(schedule, gen_id), ts)
end

function get_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime)::Union{Float64, Missing}
    uncertain_value = get_uncertain_value(sub_schedule, ts)
    return get_value(uncertain_value)
end
function get_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime)::Union{Float64, Missing}
    return get_value(get_sub_schedule(schedule, gen_id), ts)
end

function get_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, scenario::String)::Union{Float64, Missing}
    uncertain_value = get_uncertain_value(sub_schedule, ts)
    return get_value(uncertain_value, scenario)
end
function get_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime, scenario::String)::Union{Float64, Missing}
    uncertain_value = get_uncertain_value(schedule, gen_id, ts)
    return get_value(uncertain_value, scenario)
end

function set_value!(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, scenario::String, value::Float64)
    uncertain_value = get_uncertain_value(sub_schedule, ts)
    set_value!(uncertain_value, scenario, value)
end
function set_value!(schedule, gen_id::String, ts::Dates.DateTime, scenario::String, value::Float64)
    uncertain_value = get_uncertain_value(schedule, gen_id, ts)
    set_value!(uncertain_value, scenario, value)
end

function set_definitive_value!(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, value::Float64)
    uncertain_value = get_uncertain_value(sub_schedule, ts)
    set_definitive_value!(uncertain_value, value)
end
function set_definitive_value!(schedule, gen_id::String, ts::Dates.DateTime, value::Float64)
    uncertain_value = get_uncertain_value(schedule, gen_id, ts)
    set_definitive_value!(uncertain_value, value)
end
