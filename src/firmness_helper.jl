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

