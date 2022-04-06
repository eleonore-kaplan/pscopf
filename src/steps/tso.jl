using .Networks

using Dates
using JuMP
using Printf
using Parameters

@with_kw struct TSOOutFO <: AbstractTSO
    configs::TSOConfigs = TSOConfigs()
end

TSOInFO = TSOOutFO

function run(runnable::TSOOutFO, ech::Dates.DateTime, firmness, TS::Vector{Dates.DateTime}, context::AbstractContext)
    problem_name_l = @sprintf("tso_out_fo_%s", ech)

    tso_starts = get_starts(get_tso_schedule(context), get_generators_initial_state(context))
    market_starts = get_starts(get_market_schedule(context), get_generators_initial_state(context))
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

    # Capping
    update_schedule_capping!(tso_schedule, context, ech, result.limitable_model)

    # cut_conso (load-shedding)
    update_schedule_cut_conso!(tso_schedule, context, ech, result.slack_model)

    return tso_schedule
end

function update_schedule_capping!(tso_schedule, context, ech,
                                    limitable_model::TSOLimitableModel)
    reset_capping!(tso_schedule)
    for ((gen_id,ts, s), p_injected_var) in limitable_model.p_injected
        available_prod = get_uncertainties(get_uncertainties(context, ech), gen_id, ts, s)
        injected_prod = value(p_injected_var)
        tso_schedule.capping[gen_id, ts, s] = available_prod - injected_prod
    end
end

function update_schedule_cut_conso!(tso_schedule, context, ech, slack_model::TSOSlackModel)
    reset_cut_conso_by_bus!(tso_schedule)

    for ((bus_id, ts, s), p_cut_conso_var) in slack_model.p_cut_conso
        tso_schedule.cut_conso_by_bus[bus_id, ts, s] = value(p_cut_conso_var)
    end
end


function update_tso_actions!(context::AbstractContext, ech, result, firmness,
                            ::TSOOutFO)
    tso_actions = get_tso_actions(context)

    # Limitations :
    # FIXME ; limit only if there is a limitation needed !?
    limitations = SortedDict{Tuple{String,DateTime}, Float64}() #TODELETE
    for ((gen_id, ts, s), p_limit_var) in result.limitable_model.p_limit
        if get_power_level_firmness(firmness, gen_id, ts) in [TO_DECIDE, DECIDED]
            @assert( value(p_limit_var) ≈ get!(limitations, (gen_id, ts), value(p_limit_var)) ) #TODELETE : checks that all values are the same across scenarios
            set_limitation_value!(tso_actions, gen_id, ts, value(p_limit_var))
        end
    end

    # Impositions
    impositions = SortedDict{Tuple{String,DateTime}, Float64}() #TODELETE
    for ((gen_id, ts, s), p_injected_var) in result.imposable_model.p_injected
        if get_power_level_firmness(firmness, gen_id, ts) in [TO_DECIDE, DECIDED]
            @assert( value(p_injected_var) ≈ get!(impositions, (gen_id, ts), value(p_injected_var)) ) #TODELETE : checks that all values are the same across scenarios
            set_imposition_value!(tso_actions, gen_id, ts, s, value(p_injected_var), value(p_injected_var))
        end
    end

    # Commitments
    commitments = SortedDict{Tuple{String,DateTime}, GeneratorState}() #TODELETE
    for ((gen_id, ts, s), b_on_var) in result.imposable_model.b_on
        if get_commitment_firmness(firmness, gen_id, ts) in [TO_DECIDE, DECIDED]
            gen_state_value = parse(GeneratorState, value(b_on_var))
            @assert( gen_state_value == get!(commitments, (gen_id, ts), gen_state_value) ) #TODELETE : checks that all values are the same across scenarios
            set_commitment_value!(tso_actions, gen_id, ts, gen_state_value)
        end
    end

end
