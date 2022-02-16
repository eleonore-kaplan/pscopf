using ..Networks

using Dates

function init_firmness(ech::Dates.DateTime, next_ech::Union{Nothing,Dates.DateTime},
                    TS::Vector{Dates.DateTime}, generators::Vector{Networks.Generator})
    firmness = Firmness()
    for generator in generators
        gen_id = Networks.get_id(generator)
        dmo = Networks.get_dmo(generator)
        dp = Networks.get_dp(generator)

        for ts in TS
            if Networks.get_type(generator) != Networks.LIMITABLE
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


function verify_firmness(firmness::Firmness, schedule::Schedule)
    return ( verify_commitment_firmness(get_commitment_firmness(firmness), schedule)
            && verify_production_firmness(get_power_level_firmness(firmness), schedule) )
end

function verify_commitment_firmness(firmness::SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} },
                                    schedule::Schedule)
    for (gen_id, generator_firmness) in firmness
        if !verify_firmness(generator_firmness, get_sub_schedule(schedule, gen_id).commitment)
            @warn(@sprintf("commitment schedule of generator %s violates firmness", gen_id))
            return false
        end
    end
    return true
end

function verify_production_firmness(firmness::SortedDict{String, SortedDict{Dates.DateTime, DecisionFirmness} },
                                    schedule::Schedule)
    for (gen_id, generator_firmness) in firmness
        if !verify_firmness(generator_firmness, get_sub_schedule(schedule, gen_id).production)
            @warn(@sprintf("production schedule of generator %s violates firmness", gen_id))
            return false
        end
    end
    return true
end

"""
    Verfies if a given schedule respects the firmness constraints at a given timestep
    Note that this does not verify if successive values do not change with the time
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
