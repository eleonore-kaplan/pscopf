using .Networks

using Dates

"""
    Determines whether a decision should be :
    - already decided : DECIDED
    - to decide firmly (setting a common value for all scenarios) : TO_DECIDE
    - to decide freely (possibly setting different values for different scenarios): FREE
    The decision is based on the characteristic time period `delta` (delta can represent the DMO or DP)
"""
function compute_firmness(ech::Dates.DateTime, next_ech::Union{Nothing,Dates.DateTime},
                        ts::Dates.DateTime, delta::Dates.Period)
    if ( !isnothing(next_ech) && (next_ech < ech) )
        throw( error("next_ech (", next_ech, ") must be later than ech (", ech,").") )
    end

    final_decision_time = ts - delta

    if final_decision_time < ech
        return DECIDED
    elseif ( isnothing(next_ech) || (final_decision_time < next_ech) )
        return TO_DECIDE
    else
        return FREE
    end
end

function init_firmness(ech::Dates.DateTime, next_ech::Union{Nothing,Dates.DateTime},
                    TS::Vector{Dates.DateTime}, generators::Vector{Networks.Generator})
    firmness = Firmness()
    for generator in generators
        gen_id = Networks.get_id(generator)
        dmo = Networks.get_dmo(generator)
        dp = Networks.get_dp(generator)

        for ts in TS
            if Networks.get_p_min(generator) > eps()
                #commitment
                commitment_firmness = compute_firmness(ech, next_ech, ts, dmo)
                set_commitment_firmness!(firmness, gen_id, ts, commitment_firmness)
            end

            #power level
            power_level_firmness = compute_firmness(ech, next_ech, ts, dp)
            set_power_level_firmness!(firmness, gen_id, ts, power_level_firmness)
        end
    end
    return firmness
end


#########################################
#       Schedule Firmness
#########################################

function verify_firmness(firmness::Firmness, schedule::Schedule;
                        excluded_ids::Union{Set{String},Vector{String}}=Set{String}())
    excluded_ids = Set{String}(excluded_ids)
    return ( verify_commitment_firmness(get_commitment_firmness(firmness), schedule, excluded_ids=excluded_ids)
            && verify_production_firmness(get_power_level_firmness(firmness), schedule, excluded_ids=excluded_ids) )
end

function verify_commitment_firmness(firmness::SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} },
                                    schedule::Schedule;
                                    excluded_ids::Set{String}=Set{String}())
    for (gen_id, generator_firmness) in firmness
        if gen_id in excluded_ids
            continue
        end
        if !verify_firmness(generator_firmness, get_sub_schedule(schedule, gen_id).commitment)
            @warn(@sprintf("commitment schedule of generator %s violates firmness", gen_id))
            return false
        end
    end
    return true
end

function verify_production_firmness(firmness::SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} },
                                    schedule::Schedule;
                                    excluded_ids::Set{String}=Set{String}())
    for (gen_id, generator_firmness) in firmness
        if gen_id in excluded_ids
            continue
        end
        if !verify_firmness(generator_firmness, get_sub_schedule(schedule, gen_id).production)
            @warn(@sprintf("production schedule of generator %s violates firmness", gen_id))
            return false
        end
    end
    return true
end

"""
    Verfies if a given schedule respects the firmness constraints at a given timestep
"""
function verify_firmness(generator_firmness::SortedDict{Dates.DateTime, DecisionFirmness},
                        scheduled_values::SortedDict{Dates.DateTime, UncertainValue{T}}) where T

    for (ts, decision_firmness) in generator_firmness
        #if firmness is defined, a schedule value must exist
        if !haskey(scheduled_values, ts)
            @warn(@sprintf("firmness violation : missing required schedule value at timestep %s", ts))
            return false
        end

        uncertain_value = scheduled_values[ts]
        if ((decision_firmness == TO_DECIDE) || (decision_firmness == DECIDED))
            if !is_definitive(uncertain_value)
                @warn(@sprintf("firmness violation : non-definitive value at timestep %s while a firm value is required", ts))
                return false
            end

        elseif (decision_firmness == FREE)
            # FIXME: are definitive values accepted as FREE ? (might be useful for EnergyMarketAtFO, which considers one scenario)
            # if (is_definitive(uncertain_value))
            #     @warn(@sprintf("firmness violation : definitive value at timestep %s while a non-firm value is required", ts))
            #     return false
            # end
            if (is_missing_values(uncertain_value))
                @warn(@sprintf("firmness violation : missing value at timestep %s while a non-firm value is required", ts))
                return false
            end

        else
            throw( error("Non-handled DecisionFirmness value : ", decision_firmness) )
        end
    end

    return true
end
