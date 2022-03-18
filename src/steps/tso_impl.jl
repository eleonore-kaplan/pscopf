using .Networks

using JuMP
using Dates
using DataStructures
using Printf
using Parameters

@with_kw mutable struct TSOConfigs
    cut_conso_penalty = 1e7
    out_path = nothing
    problem_name = "TSO"
end


@with_kw struct TSOLimitableModel <: AbstractLimitableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    delta_p = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts
    p_limit = SortedDict{Tuple{String,DateTime},VariableRef}();
end

@with_kw struct TSOImposableModel <: AbstractImposableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    delta_p = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_start = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_on = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #commitment_constraints = Dict{Tuple{String,DateTime,String},ConstraintRef}();
    #firmness_constraints
end

@with_kw struct TSOSlackModel <: AbstractSlackModel
    #bus,ts,s
    p_cut_conso = SortedDict{Tuple{String,DateTime,String},VariableRef}();
end

@with_kw mutable struct TSOObjectiveModel <: AbstractObjectiveModel
    deltas = AffExpr(0)

    prop_cost = AffExpr(0)
    start_cost = AffExpr(0)

    penalty = AffExpr(0)

    full_obj_1 = AffExpr(0)
    full_obj_2 = AffExpr(0)
end


@with_kw mutable struct TSOModel <: AbstractModelContainer
    model::Model = Model()
    limitable_model::TSOLimitableModel = TSOLimitableModel()
    imposable_model::TSOImposableModel = TSOImposableModel()
    slack_model::TSOSlackModel = TSOSlackModel()
    objective_model::TSOObjectiveModel = TSOObjectiveModel()
    #ts,s
    eod_constraint::SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef} =
        SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef}()
    #branch,ts,s
    flows::SortedDict{Tuple{String,DateTime,String},VariableRef} =
        SortedDict{Tuple{String,DateTime,String},VariableRef}()
    status::PSCOPFStatus = pscopf_UNSOLVED
end

function has_positive_slack(model_container::TSOModel)::Bool
    return has_positive_value(model_container.slack_model.p_cut_conso)
end

function get_p_injected(model_container::TSOModel, type::Networks.GeneratorType)
    if type == Networks.LIMITABLE
        return model_container.limitable_model.p_injected
    elseif type == Networks.IMPOSABLE
        return model_container.imposable_model.p_injected
    end
    return nothing
end

function add_p_delta!(generator_model::AbstractGeneratorModel, model::Model,
                        gen_id::String, ts::DateTime, s::String,
                        p_reference::Float64
                        )
    deltas = generator_model.delta_p
    p_injected = generator_model.p_injected

    name =  @sprintf("Delta_p[%s,%s,%s]", gen_id, ts, s)
    deltas[gen_id, ts, s] = @variable(model, base_name=name)
    @constraint(model, deltas[gen_id, ts, s] >= p_injected[gen_id, ts, s] - p_reference)
    @constraint(model, deltas[gen_id, ts, s] >= p_reference - p_injected[gen_id, ts, s])

    return generator_model.delta_p[gen_id, ts, s]
end

function add_limitable!(limitable_model::TSOLimitableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        inject_uncertainties::InjectionUncertainties,
                        power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                        preceding_limitations::SortedDict{Tuple{String, Dates.DateTime}, Float64},
                        preceding_market_subschedule::GeneratorSchedule
                        )
    gen_id = Networks.get_id(generator)
    gen_pmax = Networks.get_p_max(generator)
    for ts in target_timepoints
        for s in scenarios
            p_enr = min(gen_pmax, inject_uncertainties[ts][s])
            add_p_injected!(limitable_model, model, gen_id, ts, s, p_enr, false)
            p_ref = get_prod_value(preceding_market_subschedule, ts, s)
            p_ref = ismissing(p_ref) ? 0. : p_ref
            add_p_delta!(limitable_model, model, gen_id, ts, s, p_ref)
        end

        add_p_limit!(limitable_model, model, gen_id, ts, scenarios, gen_pmax,
                    inject_uncertainties,
                    power_level_firmness[ts],
                    get_limitation(preceding_limitations, gen_id, ts))
    end

    return limitable_model, model
end

function add_limitables!(model_container::TSOModel, network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        uncertainties_at_ech::UncertaintiesAtEch,
                        firmness::Firmness,
                        preceding_limitations::SortedDict{Tuple{String, Dates.DateTime}, Float64},
                        preceding_market_schedule::Schedule
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
                        get_power_level_firmness(firmness, gen_id),
                        preceding_limitations,
                        get_sub_schedule(preceding_market_schedule, gen_id)
                        )
    end

    return model_container.limitable_model
end

function add_imposable!(imposable_model::TSOImposableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generator_initial_state::GeneratorState,
                        commitment_firmness::Union{Missing,SortedDict{Dates.DateTime, DecisionFirmness}}, #by ts #or Missing
                        power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                        preceding_tso_subschedule::GeneratorSchedule,
                        preceding_market_subschedule::GeneratorSchedule
                        )
    gen_id = Networks.get_id(generator)
    p_min = Networks.get_p_min(generator)
    p_max = Networks.get_p_max(generator)
    for ts in target_timepoints
        for s in scenarios
            add_p_injected!(imposable_model, model, gen_id, ts, s, p_max, false)
            p_ref = get_prod_value(preceding_market_subschedule, ts, s)
            p_ref = ismissing(p_ref) ? 0. : p_ref
            add_p_delta!(imposable_model, model, gen_id, ts, s, p_ref)
        end
    end

    add_power_level_firmness_constraints!(model, generator,
                                        imposable_model.p_injected,
                                        target_timepoints, scenarios,
                                        power_level_firmness,
                                        preceding_tso_subschedule
                                        )

    if p_min > 0
        add_commitment!(imposable_model, model, generator,
                        target_timepoints, scenarios, generator_initial_state
                        )
        add_commitment_firmness_constraints!(model, generator,
                                            imposable_model.b_on,
                                            imposable_model.b_start,
                                            target_timepoints, scenarios,
                                            generator_initial_state,
                                            commitment_firmness,
                                            preceding_tso_subschedule
                                            )
    end

    return imposable_model, model
end

function add_imposables!(model_container::TSOModel, network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generators_initial_state::SortedDict{String,GeneratorState},
                        firmness::Firmness,
                        preceding_tso_schedule::Schedule,
                        preceding_market_schedule::Schedule
                        )
    imposable_generators = Networks.get_generators_of_type(network, Networks.IMPOSABLE)
    for imposable_gen in imposable_generators
        gen_id = Networks.get_id(imposable_gen)
        gen_initial_state = get_initial_state(generators_initial_state, imposable_gen)
        add_imposable!(model_container.imposable_model, model_container.model,
                        imposable_gen,
                        target_timepoints,
                        scenarios,
                        gen_initial_state,
                        get_commitment_firmness(firmness, gen_id),
                        get_power_level_firmness(firmness, gen_id),
                        get_sub_schedule(preceding_tso_schedule, gen_id),
                        get_sub_schedule(preceding_market_schedule, gen_id)
                        )
    end
    return model_container.imposable_model
end

function add_slacks!(model_container::TSOModel,
                    network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch)
    model = model_container.model
    slack_model = model_container.slack_model
    for ts in target_timepoints
        for s in scenarios
            for bus in Networks.get_buses(network)
                bus_id = Networks.get_id(bus)
                name =  @sprintf("P_cut_conso[%s,%s,%s]", bus_id, ts, s)
                load = get_uncertainties(uncertainties_at_ech, bus_id, ts, s)
                slack_model.p_cut_conso[bus_id, ts, s] = @variable(model, base_name=name,
                                                            lower_bound=0., upper_bound=load)
            end
        end
    end
    return model_container.slack_model
end

function add_eod_constraint!(model_container::TSOModel,
                            network::Networks.Network,
                            ts::Dates.DateTime,
                            scenario::String,
                            load::Float64)
    cut_conso = AffExpr(0)
    for bus in Networks.get_buses(network)
        bus_id = Networks.get_id(bus)
        cut_conso += model_container.slack_model.p_cut_conso[bus_id, ts, scenario]
    end

    prod = ( sum_injections(model_container.limitable_model, ts, scenario) +
                sum_injections(model_container.imposable_model, ts, scenario) )

    model_container.eod_constraint[ts,scenario] = @constraint(model_container.model,
                                                    prod == load - cut_conso )

    return model_container
end

function add_eod_constraints!(model_container::TSOModel,
                            network::Networks.Network,
                            target_timepoints::Vector{Dates.DateTime},
                            scenarios::Vector{String},
                            uncertainties_at_ech::UncertaintiesAtEch)
    for ts in target_timepoints
        for s in scenarios
            load = compute_load(uncertainties_at_ech, network, ts, s)
            add_eod_constraint!(model_container, network, ts, s, load)
        end
    end
    return model_container
end

function add_flows!(model_container::TSOModel,
                    network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch)
    for branch in Networks.get_branches(network)
        branch_id = Networks.get_id(branch)
        for ts in target_timepoints
            for s in scenarios
                flow_limit_l = Networks.get_limit(branch)
                name =  @sprintf("Flow[%s,%s,%s]", branch_id, ts, s)
                model_container.flows[branch_id, ts, s] =
                    @variable(model_container.model, base_name=name, lower_bound=-flow_limit_l, upper_bound=flow_limit_l)

                flow_l = AffExpr(0)
                for bus in Networks.get_buses(network)
                    bus_id = Networks.get_id(bus)
                    ptdf = Networks.safeget_ptdf(network, branch_id, bus_id)

                    # + injections
                    for gen in Networks.get_generators(bus)
                        gen_id = Networks.get_id(gen)
                        gen_type = Networks.get_type(gen)
                        var_p_injected = get_p_injected(model_container, gen_type)[gen_id, ts, s]
                        flow_l += ptdf * var_p_injected
                    end

                    # - loads
                    flow_l -= ptdf * get_uncertainties(uncertainties_at_ech, bus_id, ts, s)

                    # + cutting loads ~ injections
                    flow_l += ptdf * model_container.slack_model.p_cut_conso[bus_id, ts, s]
                end
                @constraint(model_container.model, model_container.flows[branch_id, ts, s] == flow_l )
            end
        end
    end
    return model_container
end

function create_objectives!(model_container::TSOModel, network, gratis_starts, cut_conso_cost)

    # cost for cutting load/consumption
    add_cut_conso_cost!(model_container.objective_model.penalty,
                        model_container.slack_model.p_cut_conso, cut_conso_cost)

    # to force Plim = max(Pinj)
    for (_, var_limit) in model_container.limitable_model.p_limit
        model_container.objective_model.penalty += 1e-03 * var_limit
    end

    ## Objective 1 :

    # cost for deviating from market schedule
    for (_, var_delta) in model_container.imposable_model.delta_p
        model_container.objective_model.deltas += var_delta
    end
    for (_, var_delta) in model_container.limitable_model.delta_p
        model_container.objective_model.deltas += var_delta
    end

    ## Objective 2 :

    # cost for starting imposables
    add_imposable_start_cost!(model_container.objective_model.start_cost,
                            model_container.imposable_model.b_start, network, gratis_starts)

    # cost for using limitables : but most of the times these are fixed
    add_limitable_prop_cost!(model_container.objective_model.prop_cost,
                            model_container.limitable_model.p_injected, network)

    # cost for using imposables
    add_imposable_prop_cost!(model_container.objective_model.prop_cost,
                            model_container.imposable_model.p_injected, network)

    # Objective 1 :
    model_container.objective_model.full_obj_1 = ( model_container.objective_model.deltas +
                                                model_container.objective_model.penalty )
    # Objective 2 :
    model_container.objective_model.full_obj_2 = ( model_container.objective_model.start_cost +
                                                model_container.objective_model.prop_cost +
                                                model_container.objective_model.penalty )

    return model_container
end

function bound_sum_p_deltas(model_container::TSOModel)
    model_l = get_model(model_container)
    deltas_expr = model_container.objective_model.deltas
    value_sum_deltas = value(deltas_expr)

    @constraint(model_l, deltas_expr<=value_sum_deltas)
    return model_container
end

function tso_out_fo(network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    generators_initial_state::SortedDict{String,GeneratorState},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch,
                    firmness::Firmness,
                    preceding_market_schedule::Schedule,
                    preceding_tso_schedule::Schedule,
                    preceding_tso_actions::TSOActions,
                    gratis_starts::Set{Tuple{String,Dates.DateTime}},
                    configs::TSOConfigs
                    )

    model_container_l = TSOModel()

    add_limitables!(model_container_l,
                    network, target_timepoints,
                    scenarios,
                    uncertainties_at_ech,
                    firmness,
                    get_limitations(preceding_tso_actions),
                    preceding_market_schedule
                    )

    # TODO : check coherence between : preceding_tso_schedule and TSOActions.impositions
    add_imposables!(model_container_l,
                    network, target_timepoints,
                    scenarios,
                    generators_initial_state,
                    firmness,
                    preceding_tso_schedule,
                    preceding_market_schedule)

    add_slacks!(model_container_l,
                network, target_timepoints, scenarios,
                uncertainties_at_ech)

    add_eod_constraints!(model_container_l,
                        network, target_timepoints, scenarios,
                        uncertainties_at_ech
                        )

    add_flows!(model_container_l,
                        network, target_timepoints, scenarios,
                        uncertainties_at_ech
                        )

    create_objectives!(model_container_l, network, gratis_starts, configs.cut_conso_penalty)

    obj = model_container_l.objective_model.full_obj_1
    @objective(get_model(model_container_l), Min, obj)
    solve!(model_container_l, configs.problem_name*"_step1", configs.out_path)
    @info "step2 objective current value : $(value(model_container_l.objective_model.full_obj_2))"

    if (get_status(model_container_l)!=pscopf_INFEASIBLE
        && value(model_container_l.objective_model.deltas)>0 )
        bound_sum_p_deltas(model_container_l)

        obj = model_container_l.objective_model.full_obj_2
        @objective(get_model(model_container_l), Min, obj)
        solve!(model_container_l, configs.problem_name*"_step2", configs.out_path)
    end

    return model_container_l
end
