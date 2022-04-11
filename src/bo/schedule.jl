using .Networks

using Printf
using Dates
using Parameters
using DataStructures

@enum GeneratorState begin
    ON
    OFF
end

function Base.float(generator_state::GeneratorState)
    if generator_state == ON
        return 1.
    elseif generator_state == OFF
        return 0.
    else
        throw( error("Unknown GeneratorState value : ", generator_state) )
    end
end

function Base.parse(::Type{GeneratorState}, str::String)
    if lowercase(str) == "on"
        return ON
    elseif  lowercase(str) == "off"
        return OFF
    else
        throw( error("Unable to convert `", str, "` to a GeneratorState") )
    end
end

function Base.parse(::Type{GeneratorState}, val::Float64)
    if val > 1e-09
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

@with_kw_noshow struct Firmness
    #gen,ts
    commitment::SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} } =
        SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} }()
    power_level::SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} } =
        SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} }()
end

Base.:(==)(a::Firmness, b::Firmness) = a.commitment==b.commitment && a.power_level==b.power_level

function get_commitment_firmness(firmness::Firmness)
    return firmness.commitment
end

function get_power_level_firmness(firmness::Firmness)
    return firmness.power_level
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

function Base.show(io::IO, firmness::Firmness)
    println(io, "commitment :")
    pretty_print(io, firmness.commitment)
    println(io, "power_level :")
    pretty_print(io, firmness.power_level)
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

function get_scenarios(uncertain_value::UncertainValue{T}) where T
    return keys(uncertain_value.anticipated_value)
end

function is_missing_values(uncertain_value::UncertainValue{T})::Bool where T
    for (_,value) in uncertain_value.anticipated_value
        if ismissing(value)
            return true
        end
    end
    return false
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

function safeset_definitive_value!(uncertain_value::UncertainValue{T}, value::T)::Union{T, Missing} where T
    if is_definitive(uncertain_value)
        existing_value = get_value(uncertain_value)
        if is_different(existing_value, value)
            msg = @sprintf("Unable to set definitive value to %s : The definitive value `%s` was already set to the UncertainValue.",
                            value, existing_value)
            throw( error(msg) )
        end
    else
        uncertain_value.definitive_value = value
        for (scenario, _) in uncertain_value.anticipated_value
            uncertain_value.anticipated_value[scenario] = value
        end
    end
    return uncertain_value.definitive_value
end
function set_definitive_value!(uncertain_value::UncertainValue{T}, value::T)::Union{T, Missing} where T
    if is_definitive(uncertain_value)
        existing_value = get_value(uncertain_value)
        if existing_value != value
            msg = @sprintf("changed value to %s : The definitive value was already set to `%s` for the UncertainValue.",
                    value, existing_value)
            @debug msg
        end
    end

    uncertain_value.definitive_value = value
    for (scenario, _) in uncertain_value.anticipated_value
        uncertain_value.anticipated_value[scenario] = value
    end
    return uncertain_value.definitive_value
end

function get_value(uncertain_value::UncertainValue{T})::Union{T, Missing} where T
    return uncertain_value.definitive_value
end

function safeget_value(uncertain_value::UncertainValue{T})::T where T
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

struct GeneratorSchedule
    gen_id::String
    commitment::SortedDict{Dates.DateTime, UncertainValue{GeneratorState}}
    production::SortedDict{Dates.DateTime, UncertainValue{Float64}}
end
function GeneratorSchedule(gen_id::String)
    return  GeneratorSchedule(gen_id,
                            SortedDict{Dates.DateTime, UncertainValue{GeneratorState}}(),
                            SortedDict{Dates.DateTime, UncertainValue{Float64}}())
end


function get_commitment(generator_schedule::GeneratorSchedule)
    return generator_schedule.commitment
end

function get_production(generator_schedule::GeneratorSchedule)
    return generator_schedule.production
end

mutable struct Schedule <: AbstractSchedule
    decider_type::DeciderType
    decision_time::Dates.DateTime
    #gen_id => ts => uncertainValue(s)
    generator_schedules::SortedDict{String, GeneratorSchedule }

    #bus,ts,s
    cut_conso_by_bus::SortedDict{Tuple{String,DateTime,String}, Float64 }
    #limitable_gen_id,ts,s
    capping::SortedDict{Tuple{String,DateTime,String}, Float64 }
end
function Schedule(decider_type, ech)
    return Schedule(decider_type, ech,
                    SortedDict{String, GeneratorSchedule}(),
                    SortedDict{Tuple{String,DateTime,String}, Float64 }(),
                    SortedDict{Tuple{String,DateTime,String}, Float64 }()
                    )
end
function Schedule(decider_type, ech, generator_schedules)
    return Schedule(decider_type, ech, generator_schedules,
                    SortedDict{Tuple{String,DateTime,String}, Float64 }(),
                    SortedDict{Tuple{String,DateTime,String}, Float64 }()
                    )
end

function init!(schedule::Schedule, network::Networks.Network,
            target_timepoints::Vector{Dates.DateTime}, scenarios::Vector{String})
    empty!(schedule.generator_schedules)
    for generator_l in Networks.get_generators(network)
        gen_id = Networks.get_id(generator_l)
        schedule.generator_schedules[gen_id] = GeneratorSchedule(gen_id)
        for ts in target_timepoints

            schedule.generator_schedules[gen_id].production[ts] = UncertainValue{Float64}(scenarios)

            #commitment values are only defined for generators that have a pmin > 0
            if (Networks.get_p_min(generator_l) > 1e-09)
                schedule.generator_schedules[gen_id].commitment[ts] = UncertainValue{GeneratorState}(scenarios)
            end
        end
    end
end

function get_sub_schedule(schedule::Schedule, gen_id::String)::Union{GeneratorSchedule,Missing}
    if haskey(schedule.generator_schedules, gen_id)
        return schedule.generator_schedules[gen_id]
    else
        throw( error("no generator schedule was initialized for generator ", gen_id))
        #return missing
    end
end

function get_prod_uncertain_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime)::Union{UncertainValue{Float64},Missing}
    if haskey(sub_schedule.production, ts)
        return sub_schedule.production[ts]
    else
        @warn("power level schedule is not defined for generator ", sub_schedule.gen_id)
        return missing
    end
end
function get_prod_uncertain_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime)::Union{UncertainValue{Float64},Missing}
    return get_prod_uncertain_value(schedule.generator_schedules[gen_id], ts)
end

function get_commitment_uncertain_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime)::Union{UncertainValue{GeneratorState},Missing}
    if haskey(sub_schedule.commitment, ts)
        return sub_schedule.commitment[ts]
    else
        # @warn("commitment schedule is not defined for generator ", sub_schedule.gen_id)
        return missing
    end
end
function get_commitment_uncertain_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime)::Union{UncertainValue{GeneratorState},Missing}
    return get_commitment_uncertain_value(schedule.generator_schedules[gen_id], ts)
end


function get_prod_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime)::Union{Float64, Missing}
    uncertain_value = get_prod_uncertain_value(sub_schedule, ts)
    if ismissing(uncertain_value)
        return missing
    end
    return get_value(uncertain_value)
end
function get_prod_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime)::Union{Float64, Missing}
    return get_prod_value(schedule.generator_schedules[gen_id], ts)
end

function safeget_prod_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime)::Float64
    prod = get_prod_value(sub_schedule, ts)
    if ismissing(prod)
        msg = @sprintf("Missing production value for ts=%s in schedule %s",
                        ts, sub_schedule.gen_id)
        throw( error(msg) )
    else
        return prod
    end
end

function get_commitment_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime)::Union{GeneratorState, Missing}
    uncertain_value = get_commitment_uncertain_value(sub_schedule, ts)
    if ismissing(uncertain_value)
        return missing
    end
    return get_value(uncertain_value)
end
function get_commitment_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime)::Union{GeneratorState, Missing}
    return get_commitment_value(schedule.generator_schedules[gen_id], ts)
end

function safeget_commitment_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime)::GeneratorState
    commitment = get_commitment_value(sub_schedule, ts)
    if ismissing(commitment)
        msg = @sprintf("Missing commitment value for ts=%s in schedule %s",
                        ts, sub_schedule.gen_id)
        throw( error(msg) )
    else
        return commitment
    end
end

function get_prod_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, scenario::String)::Union{Float64, Missing}
    uncertain_value = get_prod_uncertain_value(sub_schedule, ts)
    if ismissing(uncertain_value)
        return missing
    end
    return get_value(uncertain_value, scenario)
end
function get_prod_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime, scenario::String)::Union{Float64, Missing}
    return get_prod_value(schedule.generator_schedules[gen_id], ts, scenario)
end
function safeget_prod_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime, scenario::String)::Union{Float64, Missing}
    prod = get_prod_value(schedule.generator_schedules[gen_id], ts, scenario)
    if ismissing(prod)
        msg = @sprintf("Missing production value in schedule for (gen_id=%s,ts=%s,s=%s)",
                        gen_id,ts,scenario)
        throw( error(msg) )
    else
        return prod
    end
end
function safeget_prod_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, scenario::String)::Float64
    prod = get_prod_value(sub_schedule, ts, scenario)
    if ismissing(prod)
        msg = @sprintf("Missing production value for (ts=%s,s=%s) in schedule %s",
                        ts, scenario, sub_schedule.gen_id)
        throw( error(msg) )
    else
        return prod
    end
end

function get_commitment_value(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, scenario::String)::Union{GeneratorState, Missing}
    uncertain_value = get_commitment_uncertain_value(sub_schedule, ts)
    if ismissing(uncertain_value)
        return missing
    end
    return get_value(uncertain_value, scenario)
end
function get_commitment_value(schedule::Schedule, gen_id::String, ts::Dates.DateTime, scenario::String)::Union{GeneratorState, Missing}
    return get_commitment_value(schedule.generator_schedules[gen_id], ts, scenario)
end

function get_capping(schedule::Schedule, gen_id::String, ts::Dates.DateTime, scenario)::Union{Float64, Missing}
    key_l = (gen_id, ts, scenario)
    if !haskey(schedule.capping, key_l)
        return missing
    else
        return schedule.capping[key_l]
    end
end
function safeget_capping(schedule::Schedule, gen_id::String, ts::Dates.DateTime, scenario)::Float64
    capping = get_capping(schedule, gen_id, ts, scenario)
    if ismissing(capping)
        msg = @sprintf("Missing capping value for (gen_id=%s,ts=%s,s=%s) in schedule",
                        gen_id, ts, scenario)
        throw( error(msg) )
    else
        return capping
    end
end

function get_cut_conso(schedule::Schedule, bus_id, ts::Dates.DateTime, scenario)::Union{Float64, Missing}
    key_l = (bus_id, ts, scenario)
    if !haskey(schedule.cut_conso_by_bus, key_l)
        return missing
    else
        return schedule.cut_conso_by_bus[key_l]
    end
end
function safeget_cut_conso(schedule::Schedule, bus_id, ts::Dates.DateTime, scenario)::Float64
    cut_conso = get_cut_conso(schedule, bus_id, ts, scenario)
    if ismissing(cut_conso)
        msg = @sprintf("Missing cut_conso value for (gen_id=%s,ts=%s,s=%s) in schedule",
                        bus_id, ts, scenario)
        throw( error(msg) )
    else
        return cut_conso
    end
end

function set_prod_value!(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, scenario::String, value::Float64)
    uncertain_value = get_prod_uncertain_value(sub_schedule, ts)
    if ismissing(uncertain_value)
        msg = @sprintf("cannot set uninitialized schedule production value for generator `%s` at timestep %s and scenario %s",
                        sub_schedule.gen_id, ts, scenario)
        throw( error(msg) )
    end
    set_value!(uncertain_value, scenario, value)
end
function set_prod_value!(schedule, gen_id::String, ts::Dates.DateTime, scenario::String, value::Float64)
    return set_prod_value!(schedule.generator_schedules[gen_id], ts, scenario, value)
end

function set_commitment_value!(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, scenario::String, value::GeneratorState)
    uncertain_value = get_commitment_uncertain_value(sub_schedule, ts)
    if ismissing(uncertain_value)
        msg = @sprintf("cannot set uninitialized schedule commitment value for generator `%s` at timestep %s and scenario %s",
                        sub_schedule.gen_id, ts, scenario)
        throw( error(msg) )
    end
    set_value!(uncertain_value, scenario, value)
end
function set_commitment_value!(schedule, gen_id::String, ts::Dates.DateTime, scenario::String, value::GeneratorState)
    return set_commitment_value!(schedule.generator_schedules[gen_id], ts, scenario, value)
end


function set_prod_definitive_value!(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, value::Float64)
    uncertain_value = get_prod_uncertain_value(sub_schedule, ts)
    if ismissing(uncertain_value)
        msg = @sprintf("cannot set uninitialized schedule production value for generator `%s` at timestep %s",
                        sub_schedule.gen_id, ts)
        throw( error(msg) )
    end
    safeset_definitive_value!(uncertain_value, value)
end
function set_prod_definitive_value!(schedule, gen_id::String, ts::Dates.DateTime, value::Float64)
    return set_prod_definitive_value!(schedule.generator_schedules[gen_id], ts, value)
end

function set_commitment_definitive_value!(sub_schedule::GeneratorSchedule, ts::Dates.DateTime, value::GeneratorState)
    uncertain_value = get_commitment_uncertain_value(sub_schedule, ts)
    if ismissing(uncertain_value)
        msg = @sprintf("cannot set uninitialized schedule commitment value for generator `%s` at timestep %s",
                        sub_schedule.gen_id, ts)
        throw( error(msg) )
    end
    set_definitive_value!(uncertain_value, value)
end
function set_commitment_definitive_value!(schedule, gen_id::String, ts::Dates.DateTime, value::GeneratorState)
    return set_commitment_definitive_value!(schedule.generator_schedules[gen_id], ts, value)
end

function set_capping_value!(schedule::Schedule, gen_id::String, ts::Dates.DateTime, scenario::String, value::Float64)
    schedule.capping[gen_id, ts, scenario] = value
end
function set_cut_conso_value!(schedule::Schedule, bus_id::String, ts::Dates.DateTime, scenario::String, value::Float64)
    schedule.cut_conso_by_bus[bus_id, ts, scenario] = value
end

function reset_cut_conso_by_bus!(schedule::Schedule)
    empty!(schedule.cut_conso_by_bus)
end
function reset_capping!(schedule::Schedule)
    empty!(schedule.capping)
end

function get_commitment_sub_schedule(schedule::Schedule, gen_id::String)
    return get_commitment(get_sub_schedule(schedule, gen_id))
end

function get_production_sub_schedule(schedule::Schedule, gen_id::String)
    return get_production(get_sub_schedule(schedule, gen_id))
end

function Base.show(io::IO, gen_schedule::GeneratorSchedule)
    @printf("generator %s:\n", gen_schedule.gen_id)
    println("commitment:")
    pretty_print(io, gen_schedule.commitment)
    println("production:")
    pretty_print(io, gen_schedule.production)
end
function Base.show(io::IO, schedule::Schedule)
    @printf("schedule decided by %s at %s:\n", schedule.decider_type, schedule.decision_time)
    pretty_print(io, schedule.generator_schedules)
    println("capping:")
    pretty_print(io, schedule.capping)
    println("cut_conso_by_bus:")
    pretty_print(io, schedule.cut_conso_by_bus)
end


#######################
# Helpers
########################

function get_target_timepoints(gen_schedule::GeneratorSchedule)
    return union(keys(gen_schedule.commitment), keys(gen_schedule.production))
end

function get_start_value(preceding_state, current_state)
    if preceding_state==OFF && current_state==ON
        return 1
    else
        return 0
    end
end

function get_start_value(generator_reference_schedule, ts, preceding_ts, generator_initial_state)
    current_state = safeget_commitment_value(generator_reference_schedule, ts)
    preceding_state = ( isnothing(preceding_ts) ? generator_initial_state :
                            safeget_commitment_value(generator_reference_schedule, preceding_ts) )
    return get_start_value(preceding_state, current_state)
end