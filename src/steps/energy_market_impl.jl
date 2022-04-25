using .Networks

using JuMP
using Dates
using DataStructures
using Printf
using Parameters

"""
REF_SCHEDULE_TYPE : Indicates wether to consider the preceding market or TSO schedule as a reference.
                    The reference schedule is used to get decided commitment and production levels if
                      tso actions are missing.
"""
@with_kw mutable struct EnergyMarketConfigs
    force_limitables::Bool = true
    cut_conso_penalty = 1e7
    out_path = nothing
    problem_name = "EnergyMarket"
    REF_SCHEDULE_TYPE::Union{Market,TSO} = Market(); # by default the market does not see the preceding tso schedule
                                                    # cause in mode 1, tso should not affect market
    CONSIDER_TSOACTIONS_LIMITATIONS::Bool = false
    CONSIDER_TSOACTIONS_IMPOSITIONS::Bool = false
    CONSIDER_TSOACTIONS_COMMITMENTS::Bool = true
    CONSIDER_GRATIS_STARTS::Bool = true
end

@with_kw struct EnergyMarketLimitableModel <: AbstractLimitableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #ts,s
    p_capping = SortedDict{Tuple{DateTime,String},VariableRef}();
    #firmness_constraints
end

@with_kw struct EnergyMarketImposableModel <: AbstractImposableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_start = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_on = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #commitment_constraints = Dict{Tuple{String,DateTime,String},ConstraintRef}();
    #firmness_constraints
end

@with_kw struct EnergyMarketSlackModel <: AbstractSlackModel
    #ts,s
    p_cut_conso = SortedDict{Tuple{DateTime,String},VariableRef}();
end

@with_kw mutable struct EnergyMarketObjectiveModel <: AbstractObjectiveModel
    prop_cost = AffExpr(0)
    start_cost = AffExpr(0)
    penalty = AffExpr(0)

    full_obj = AffExpr(0)
end


@with_kw mutable struct EnergyMarketModel <: AbstractModelContainer
    model::Model = Model()
    limitable_model::EnergyMarketLimitableModel = EnergyMarketLimitableModel()
    imposable_model::EnergyMarketImposableModel = EnergyMarketImposableModel()
    slack_model::EnergyMarketSlackModel = EnergyMarketSlackModel()
    objective_model::EnergyMarketObjectiveModel = EnergyMarketObjectiveModel()
    eod_constraint::SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef} =
        SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef}()
end

SCENARIOS_DELIMITER = "_+_"

function aggregate_scenario_name(scenarios::Vector{String})
    return join(scenarios, SCENARIOS_DELIMITER)
end
function aggregate_scenario_name(context::AbstractContext, ech::Dates.DateTime)
    scenarios = get_scenarios(context, ech)
    return aggregate_scenario_name(scenarios)
end

function has_positive_slack(model_container::EnergyMarketModel)::Bool
    return has_positive_value(model_container.slack_model.p_cut_conso)
end

"""
    energy_market
# Arguments
    - `network::Networks.Network`
    - `target_timepoints::Vector{Dates.DateTime}`
    - `generators_initial_state::SortedDict{String,GeneratorState}` :
        The ON/OFF state of each generator just before the first target timepoint.
    - `scenarios::Vector{String}` : considered scenarios
    - `uncertainties_at_ech::UncertaintiesAtEch` :
        The considered limitables injections and bus consumption realisations per scenario
         for the current timepoint of execution (i.e. `ech`).
    - `firmness::Firmness` : The required level of firmness for commitment and power level decisions
    - `preceding_market_schedule::Schedule` : The preceding market schedule may be used to set already decided values.
    - `preceding_tso_schedule::Schedule` : The preceding tso schedule may be used to set already decided values.
    - `tso_actions::TSOActions` : The preceding tso actions maybe used for additional constraints.
        The behaviour of the model wit hrespect to the TSO actions is defined by the parameters
         `CONSIDER_TSOACTIONS_LIMITATIONS`, `CONSIDER_TSOACTIONS_IMPOSITIONS`, and `CONSIDER_TSOACTIONS_COMMITMENTS`
         of `configs::EnergyMarketConfigs`
    - `gratis_starts::Set{Tuple{String,Dates.DateTime}}` :
        Tuples of (gen_id, ts) giving already paid for starting decisions. So if the market starts
         unit gen_id at timestep ts, it will not pay the starting cost.
        These are ignored if EnergyMarketConfigs::CONSIDER_GRATIS_STARTS is false
    - `configs::EnergyMarketConfigs` :
        settings modifying the behaviour of the model.
"""
function energy_market(network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    generators_initial_state::SortedDict{String,GeneratorState},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch,
                    firmness::Firmness,
                    preceding_market_schedule::Schedule,
                    preceding_tso_schedule::Schedule,
                    tso_actions::TSOActions,
                    gratis_starts::Set{Tuple{String,Dates.DateTime}},
                    configs::EnergyMarketConfigs
                    )
    #if gratis_starts is not empty, we should CONSIDER_GRATIS_STARTS
    @assert( configs.CONSIDER_GRATIS_STARTS | isempty(gratis_starts) )
    #if not there a risk of cutting conso instead of using a generator
    @assert all(configs.cut_conso_penalty > Networks.get_prop_cost(gen)
                for gen in Networks.get_generators(network))

    model_container_l = EnergyMarketModel()

    add_limitables!(model_container_l,
                    network, target_timepoints,
                    scenarios,
                    uncertainties_at_ech,
                    tso_actions,
                    force_limitables=configs.force_limitables,
                    has_global_capping_vars=true,
                    )

    if is_market(configs.REF_SCHEDULE_TYPE)
        reference_schedule = preceding_market_schedule
    elseif is_tso(configs.REF_SCHEDULE_TYPE)
        reference_schedule = preceding_tso_schedule
    else
        throw( error("Invalid REF_SCHEDULE_TYPE config.") )
    end
    add_imposables!(model_container_l,
                    network, target_timepoints, scenarios,
                    generators_initial_state,
                    firmness, reference_schedule, tso_actions)

    add_slacks!(model_container_l,
                network, target_timepoints, scenarios,
                uncertainties_at_ech)


    add_eod_constraint!(model_container_l,
                        network, target_timepoints, scenarios,
                        uncertainties_at_ech
                        )

    add_objective!(model_container_l, network, gratis_starts, configs.cut_conso_penalty)

    solve!(model_container_l, configs.problem_name, configs.out_path)

    return model_container_l
end

function add_objective!(model_container::EnergyMarketModel, network, gratis_starts, cut_conso_cost)
    # cost for starting imposables
    add_imposable_start_cost!(model_container.objective_model.start_cost,
                            model_container.imposable_model.b_start, network, gratis_starts)

    # cost for using limitables : but most of the times these are fixed
    add_prop_cost!(model_container.objective_model.prop_cost,
                    model_container.limitable_model.p_injected, network)

    # cost for using imposables
    add_prop_cost!(model_container.objective_model.prop_cost,
                    model_container.imposable_model.p_injected, network)

    # cost for cutting load/consumption
    add_coeffxsum_cost!(model_container.objective_model.penalty,
                        model_container.slack_model.p_cut_conso, cut_conso_cost)

    model_container.objective_model.full_obj = ( model_container.objective_model.start_cost +
                                                model_container.objective_model.prop_cost +
                                                model_container.objective_model.penalty )
    @objective(model_container.model, Min, model_container.objective_model.full_obj)
    return model_container
end

function add_imposable!(imposable_model::EnergyMarketImposableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generator_initial_state::GeneratorState,
                        commitment_firmness::Union{Missing,SortedDict{Dates.DateTime, DecisionFirmness}}, #by ts #or Missing
                        power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                        generator_reference_schedule::GeneratorSchedule,
                        tso_actions::TSOActions
                        )
    gen_id = Networks.get_id(generator)
    p_min = Networks.get_p_min(generator)
    p_max = Networks.get_p_max(generator)
    for ts in target_timepoints
        for s in scenarios
            add_p_injected!(imposable_model, model, gen_id, ts, s, p_max, false)
        end
    end

    add_scenarios_linking_constraints!(model, generator,
                                        imposable_model.p_injected,
                                        target_timepoints, scenarios,
                                        power_level_firmness,
                                        false
                                        )

    add_power_level_sequencing_constraints!(model, generator,
                                        imposable_model.p_injected,
                                        target_timepoints, scenarios,
                                        power_level_firmness,
                                        generator_reference_schedule,
                                        tso_actions
                                        )

    if p_min > 0
        add_commitment!(imposable_model, model, generator,
                        target_timepoints, scenarios, generator_initial_state
                        )
        add_scenarios_linking_constraints!(model,
                        generator, imposable_model.b_on,
                        target_timepoints, scenarios,
                        commitment_firmness, false
                        )
        #linking b_on => linking b_start
        add_commitment_sequencing_constraints!(model, generator,
                                            imposable_model.b_on,
                                            imposable_model.b_start,
                                            target_timepoints, scenarios,
                                            commitment_firmness,
                                            generator_reference_schedule,
                                            get_commitments(tso_actions)
                                            )
    end

    return imposable_model, model
end

function add_limitable!(limitable_model::EnergyMarketLimitableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        inject_uncertainties::InjectionUncertainties,
                        tso_actions::TSOActions,
                        force_limitables::Bool,
                        )
    gen_id = Networks.get_id(generator)
    gen_pmax = Networks.get_p_max(generator)
    for ts in target_timepoints
        p_limit = ismissing(get_limitation(tso_actions, gen_id, ts)) ? gen_pmax : get_limitation(tso_actions, gen_id, ts)
        for s in scenarios
            p_enr = min(gen_pmax, inject_uncertainties[ts][s], p_limit)
            add_p_injected!(limitable_model, model, gen_id, ts, s, p_enr, force_limitables)
        end
    end

    return limitable_model, model
end

function add_imposables!(model_container::EnergyMarketModel, network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generators_initial_state::SortedDict{String,GeneratorState},
                        firmness::Firmness,
                        reference_schedule::Schedule,
                        tso_actions::TSOActions
                        )
    imposable_generators = Networks.get_generators_of_type(network, Networks.IMPOSABLE)
    for imposable_gen in imposable_generators
        gen_id = Networks.get_id(imposable_gen)
        # gen_commitment = get_commitment_firmness(firmness, gen_id)
        gen_initial_state = get_initial_state(generators_initial_state, imposable_gen)
        add_imposable!(model_container.imposable_model, model_container.model,
                        imposable_gen,
                        target_timepoints,
                        scenarios,
                        gen_initial_state,
                        get_commitment_firmness(firmness, gen_id),
                        get_power_level_firmness(firmness, gen_id),
                        get_sub_schedule(reference_schedule, gen_id),
                        tso_actions
                        )
    end
    return model_container.imposable_model
end

function add_limitables!(model_container::EnergyMarketModel, network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        uncertainties_at_ech::UncertaintiesAtEch,
                        tso_actions::TSOActions;
                        force_limitables::Bool=false,
                        has_global_capping_vars::Bool=false,
                        )
    limitable_model = model_container.limitable_model
    model = model_container.model

    limitable_generators = Networks.get_generators_of_type(network, Networks.LIMITABLE)
    for limitable_gen in limitable_generators
        gen_id = Networks.get_id(limitable_gen)
        add_limitable!(limitable_model, model,
                        limitable_gen,
                        target_timepoints,
                        scenarios,
                        get_uncertainties(uncertainties_at_ech, gen_id),
                        tso_actions,
                        force_limitables,
                        )
    end

    if has_global_capping_vars
        for ts in target_timepoints
            for s in scenarios
                uncertain_power = compute_prod(uncertainties_at_ech, network, ts, s)
                capped_by_limitation = compute_capped(uncertainties_at_ech, get_limitations(tso_actions), network, ts, s)
                @debug(@sprintf("capped by limitations : %f", capped_by_limitation))
                @debug(@sprintf("uncertain_power : %f", uncertain_power))

                name =  @sprintf("P_capping[%s,%s]", ts, s)
                limitable_model.p_capping[ts, s] = @variable(model, base_name=name, lower_bound=0.)
                @constraint(model, limitable_model.p_capping[ts, s] <= uncertain_power)
                @constraint(model, capped_by_limitation <= limitable_model.p_capping[ts, s])

                if !force_limitables
                    limitable_injections = sum_injections(limitable_model, ts, s)
                    @constraint(model, limitable_model.p_capping[ts, s] == uncertain_power - limitable_injections)
                end
            end
        end
    end

    return model_container.limitable_model
end

function add_slacks!(model_container::EnergyMarketModel,
                    network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch)
    model = model_container.model
    slack_model = model_container.slack_model
    for ts in target_timepoints
        for s in scenarios
            name =  @sprintf("P_cut_conso[%s,%s]", ts, s)
            load = compute_load(uncertainties_at_ech, network, ts, s)
            slack_model.p_cut_conso[ts, s] = @variable(model, base_name=name,
                                                        lower_bound=0., upper_bound=load)
        end
    end
    return model_container.slack_model
end

function add_eod_constraint!(model_container::EnergyMarketModel,
                            network::Networks.Network,
                            target_timepoints::Vector{Dates.DateTime},
                            scenarios::Vector{String},
                            uncertainties_at_ech::UncertaintiesAtEch)
    for ts in target_timepoints
        for s in scenarios
            load = compute_load(uncertainties_at_ech, network, ts, s)
            cut_conso = model_container.slack_model.p_cut_conso[ts,s]

            supply_l = AffExpr(0.)
            supply_l += sum_injections(model_container.imposable_model, ts, s)
            supply_l += compute_prod(uncertainties_at_ech, network, ts, s)
            supply_l -= model_container.limitable_model.p_capping[ts,s]

            model_container.eod_constraint[ts,s] = @constraint(model_container.model,
                                                            supply_l == load - cut_conso )
        end
    end
end

###########################
# Context-update
###########################

function update_schedule_capping!(market_schedule, context, ech, limitable_model::EnergyMarketLimitableModel,
                                distribute_by_uncertainties::Bool)
    reset_capping!(market_schedule)
    uncertainties = get_uncertainties(context, ech)

    for ((ts, scenario), p_capping_var) in limitable_model.p_capping
        capped_lim_prod = value(p_capping_var)
        for s in split_str(scenario, SCENARIOS_DELIMITER, keepempty=false)
        #for EnergyMarket, s==scenario
        #for EnergyMarketAtFO, this allows handling aggregate scenarios "S1_+_S2"
            limitables_ids = Networks.get_id.(Networks.get_generators_of_type(get_network(context), Networks.LIMITABLE))

            if capped_lim_prod > 1e-09
            #distribute the capped power on limitables
                @printf("capped %f power in scenario %s at ts %s\n", capped_lim_prod, s, ts)
                if distribute_by_uncertainties
                    distribution_key = Dict{String,Float64}(gen_id_l => get_uncertainties(uncertainties, gen_id_l, ts, s)
                                                            for gen_id_l in limitables_ids)
                    distribution_key = normalize_values(distribution_key)
                    @debug(@sprintf("distribution_key : %s", distribution_key))

                    for (gen_id, coeff) in distribution_key
                        capped_value = coeff * capped_lim_prod
                        market_schedule.capping[gen_id, ts, s] = capped_value
                    end
                else
                    for gen_id in limitables_ids
                        capped_value = value(get_uncertainties(uncertainties, gen_id, ts, s) - limitable_model.p_injected[gen_id, ts, s])
                        market_schedule.capping[gen_id, ts, s] = capped_value
                    end
                end
            else
                for gen_id in limitables_ids
                    market_schedule.capping[gen_id, ts, s] = 0.
                end
            end
        end
    end
end

function update_schedule_cut_conso!(market_schedule, context, ech, slack_model::EnergyMarketSlackModel)
    reset_cut_conso_by_bus!(market_schedule)
    uncertainties = get_uncertainties(context, ech)

    for ((ts, scenario), p_cut_conso_var) in slack_model.p_cut_conso
        total_cut_conso = value(p_cut_conso_var)
        for s in split_str(scenario, SCENARIOS_DELIMITER, keepempty=false)
        #for EnergyMarket, s==scenario
        #for EnergyMarketAtFO, this allows handling aggregate scenarios "S1_+_S2"
            bus_ids = Networks.get_id.(Networks.get_buses(get_network(context)))

            if total_cut_conso > 1e-09
            #distribute the cut conso on buses
                @printf("cut conso %f in scenario %s at ts %s\n", total_cut_conso, s, ts)
                distribution_key = Dict{String,Float64}(bus_id_l => get_uncertainties(uncertainties, bus_id_l, ts, s)
                                                        for bus_id_l in bus_ids)
                distribution_key = normalize_values(distribution_key)
                @debug(@sprintf("distribution_key : %s", distribution_key))

                for (bus_id, coeff) in distribution_key
                    cut_load_on_bus = coeff * total_cut_conso
                    market_schedule.cut_conso_by_bus[bus_id, ts, s] = cut_load_on_bus
                end
            else
                for bus_id in bus_ids
                    market_schedule.cut_conso_by_bus[bus_id, ts, s] = 0.
                end
            end
        end
    end
end

function compute_capped(uncertainties_at_ech::UncertaintiesAtEch,
                        limitations::SortedDict{Tuple{String, Dates.DateTime}, Float64},
                        network, ts, s)
    if isempty(limitations)
        return 0.
    end

    capped = 0.
    for limitable_gen in Networks.get_generators_of_type(network, Networks.LIMITABLE)
        gen_id = Networks.get_id(limitable_gen)
        p_lim = get_limitation(limitations, gen_id, ts)

        if ismissing(p_lim)
            continue
        else
            gen_capped = ( get_uncertainties(uncertainties_at_ech, gen_id, ts, s) - p_lim )
            @debug(@sprintf("%s capped %f : limit is %f out of %f",
                            gen_id, gen_capped, p_lim, get_uncertainties(uncertainties_at_ech, gen_id, ts, s)))
            capped += gen_capped
        end
    end
    return capped
end
