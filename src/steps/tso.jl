using .Networks

using Dates
using JuMP
using Printf
using Parameters

@with_kw struct TSOOutFO <: AbstractTSO
    configs::TSOConfigs = TSOConfigs()
end

function run(runnable::TSOOutFO, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    println("\tJe me référencie au précédent planning du marché pour les arrets/démarrage et l'estimation des couts : ",
            get_market_schedule(context).decider_type, ",", get_market_schedule(context).decision_time)
    println("\tJe me référencie à mon précédent planning du TSO pour les arrets/démarrage : ",
            get_tso_schedule(context).decider_type, ",", get_tso_schedule(context).decision_time)

    fo_start_time = TS[1] - get_fo_length(get_management_mode(context))
    if fo_start_time <= ech
        msg = @sprintf("invalid step at ech=%s : TSOOutFO needs to be launched before FO start (ie %s)", ech, fo_start_time)
        throw( error(msg) )
    end

    problem_name_l = @sprintf("tso_out_fo_%s", ech)

    tso_starts = definitive_starts(get_tso_schedule(context), get_generators_initial_state(context))
    market_starts = definitive_starts(get_market_schedule(context), get_generators_initial_state(context))
    gratis_starts = union(tso_starts, market_starts)

    runnable.configs.out_path = context.out_dir
    runnable.configs.problem_name = problem_name_l

    return tso_out_fo(get_network(context),
                    TS,
                    get_generators_initial_state(context),
                    get_scenarios(context, ech),
                    get_uncertainties(context, ech),
                    firmness,
                    get_market_schedule(context),
                    get_tso_schedule(context),
                    get_tso_actions(context),
                    gratis_starts,
                    runnable.configs
                    )
end

function update_tso_schedule!(context::AbstractContext, ech, result, firmness,
                            runnable::TSOOutFO)
    tso_schedule = get_tso_schedule(context)
    tso_schedule.decider_type = DeciderType(runnable)
    tso_schedule.decision_time = ech
    println("\tJe mets à jour le planning tso: ",
    tso_schedule.decider_type, ",",tso_schedule.decision_time,
    " en me basant sur les résultats d'optimisation.")
    println("\tet je ne touche pas au planning du marché")

    for ((gen_id, ts, s), p_injected_var) in result.limitable_model.p_injected
        set_prod_value!(tso_schedule, gen_id, ts, s, value(p_injected_var))
    end
    for ((gen_id, ts, s), p_injected_var) in result.imposable_model.p_injected
        if get_power_level_firmness(firmness, gen_id, ts) == FREE
            set_prod_value!(tso_schedule, gen_id, ts, s, value(p_injected_var))
        elseif get_power_level_firmness(firmness, gen_id, ts) == TO_DECIDE
            set_prod_definitive_value!(tso_schedule, gen_id, ts, value(p_injected_var))
        elseif get_power_level_firmness(firmness, gen_id, ts) == DECIDED
            @assert( value(p_injected_var) ≈ get_prod_value(tso_schedule, gen_id, ts) )
        end
    end

    for ((gen_id, ts, s), b_on_var) in result.imposable_model.b_on
        gen_state_value = parse(GeneratorState, value(b_on_var))
        if get_commitment_firmness(firmness, gen_id, ts) == FREE
            set_commitment_value!(tso_schedule, gen_id, ts, s, gen_state_value)
        elseif get_commitment_firmness(firmness, gen_id, ts) in [TO_DECIDE, DECIDED]
            set_commitment_definitive_value!(tso_schedule, gen_id, ts, gen_state_value)
        end
    end

    return tso_schedule
end

function update_tso_actions!(tso_actions, ech, result, firmness,
                            context::AbstractContext, runnable::TSOOutFO)
    println("\tJe mets à jour les actions TSO (limitations, impositions) à prendre en compte par le marché")
end
