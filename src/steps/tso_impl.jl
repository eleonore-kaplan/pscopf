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
@with_kw mutable struct TSOConfigs
    loss_of_load_penalty = 1e7
    limitation_penalty = 1e-03
    out_path = nothing
    problem_name = "TSO"
    REF_SCHEDULE_TYPE::Union{Market,TSO} = TSO();
end


@with_kw struct TSOLimitableModel <: AbstractLimitableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    delta_p = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    p_limit = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_is_limited = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    p_limit_x_is_limited = SortedDict{Tuple{String,DateTime,String},VariableRef}();
end

@with_kw struct TSOPilotableModel <: AbstractPilotableModel
    #gen,ts,s
    p_injected = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    delta_p = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_start = SortedDict{Tuple{String,DateTime,String},VariableRef}();
    #gen,ts,s
    b_on = SortedDict{Tuple{String,DateTime,String},VariableRef}();
end

@with_kw struct TSOLoLModel <: AbstractLoLModel
    #bus,ts,s
    p_loss_of_load = SortedDict{Tuple{String,DateTime,String},VariableRef}();
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
    pilotable_model::TSOPilotableModel = TSOPilotableModel()
    lol_model::TSOLoLModel = TSOLoLModel()
    objective_model::TSOObjectiveModel = TSOObjectiveModel()
    #ts,s
    eod_constraint::SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef} =
        SortedDict{Tuple{Dates.DateTime,String}, ConstraintRef}()
    #branch,ts,s
    flows::SortedDict{Tuple{String,DateTime,String},VariableRef} =
        SortedDict{Tuple{String,DateTime,String},VariableRef}()
    rso_constraint::SortedDict{Tuple{String,DateTime,String},ConstraintRef} =
        SortedDict{Tuple{String,DateTime,String},ConstraintRef}()
end

function has_positive_slack(model_container::TSOModel)::Bool
    return has_positive_value(model_container.lol_model.p_loss_of_load)
end


function sum_capping(limitable_model::TSOLimitableModel, ts,s, network::Networks.Network)
    error("TODO : requires uncertainties cause capping=uncertainties-injection")
end

#TODO define a struct LocalisedLolModel to use it for TSOLoLModel and TSOBilevelTSOLoLModel
function sum_lol(lol_model::TSOLoLModel, ts, s, network::Networks.Network)
    sum_l = 0.
    for bus in Networks.get_buses(network)
        bus_id = Networks.get_id(bus)
        sum_l += lol_model.p_loss_of_load[bus_id,ts,s]
    end
    return sum_l
end

function add_pilotable!(pilotable_model::TSOPilotableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generator_initial_state::GeneratorState,
                        commitment_firmness::Union{Missing,SortedDict{Dates.DateTime, DecisionFirmness}}, #by ts #or Missing
                        power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                        reference_subschedule::GeneratorSchedule,
                        preceding_market_subschedule::GeneratorSchedule
                        )
    #FIXME take into account the preceding TSOActions ? or not (cause they are already included in the tso_schedule)
    gen_id = Networks.get_id(generator)
    p_min = Networks.get_p_min(generator)
    p_max = Networks.get_p_max(generator)
    for ts in target_timepoints
        for s in scenarios
            add_p_injected!(pilotable_model, model, gen_id, ts, s, p_max, false)
            p_ref = get_prod_value(preceding_market_subschedule, ts, s)
            p_ref = ismissing(p_ref) ? 0. : p_ref
            add_p_delta!(pilotable_model, model, gen_id, ts, s, p_ref)
        end
    end

    add_scenarios_linking_constraints!(model, generator,
                                        pilotable_model.p_injected,
                                        target_timepoints, scenarios,
                                        power_level_firmness,
                                        false
                                        )

    add_power_level_sequencing_constraints!(model, generator,
                                        pilotable_model.p_injected,
                                        target_timepoints, scenarios,
                                        power_level_firmness,
                                        reference_subschedule
                                        #does not consider TSOActions
                                        )

    if p_min > 0
        add_commitment!(pilotable_model, model, generator,
                        target_timepoints, scenarios, generator_initial_state
                        )
        #linking b_on scenarios => linking b_start
        add_scenarios_linking_constraints!(model,
                                        generator, pilotable_model.b_on,
                                        target_timepoints, scenarios,
                                        commitment_firmness, false
                                        )

        add_commitment_sequencing_constraints!(model, generator,
                                            pilotable_model.b_on,
                                            pilotable_model.b_start,
                                            target_timepoints, scenarios,
                                            commitment_firmness,
                                            reference_subschedule
                                            )
    end

    return pilotable_model, model
end

function add_pilotables!(model_container::TSOModel, network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        generators_initial_state::SortedDict{String,GeneratorState},
                        firmness::Firmness,
                        reference_schedule::Schedule,
                        preceding_market_schedule::Schedule
                        )
    pilotable_generators = Networks.get_generators_of_type(network, Networks.PILOTABLE)
    for pilotable_gen in pilotable_generators
        gen_id = Networks.get_id(pilotable_gen)
        gen_initial_state = get_initial_state(generators_initial_state, pilotable_gen)
        add_pilotable!(model_container.pilotable_model, model_container.model,
                        pilotable_gen,
                        target_timepoints,
                        scenarios,
                        gen_initial_state,
                        get_commitment_firmness(firmness, gen_id),
                        get_power_level_firmness(firmness, gen_id),
                        get_sub_schedule(reference_schedule, gen_id),
                        get_sub_schedule(preceding_market_schedule, gen_id)
                        )
    end
    return model_container.pilotable_model
end

function add_slacks!(model_container::TSOModel,
                    network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch)
    model = model_container.model
    p_loss_of_load = model_container.lol_model.p_loss_of_load
    buses = Networks.get_buses(network)

    add_loss_of_load_by_bus!(model, p_loss_of_load,
                        buses, target_timepoints, scenarios, uncertainties_at_ech)

    return model_container.lol_model
end

function add_flows!(model_container::TSOModel,
                    network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch)
    for branch in Networks.get_branches(network)
        branch_id = Networks.get_id(branch)
        flow_limit_l = Networks.get_limit(branch)
        for ts in target_timepoints
            for s in scenarios
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
                    flow_l += ptdf * model_container.lol_model.p_loss_of_load[bus_id, ts, s]
                end
                @constraint(model_container.model, model_container.flows[branch_id, ts, s] == flow_l )
            end
        end
    end
    return model_container
end


function add_tso_limitable_prop_cost!(obj_component::AffExpr,
                                uncertainties_at_ech::UncertaintiesAtEch,
                                p_injected::AbstractDict{T,V}, network)  where T <: Tuple where V <: VariableRef
    #NOTE: need to make sure uncertainty > injection

    for ((gen_id,ts,s), p_injected_var) in p_injected
        generator = Networks.get_generator(network, gen_id)
        gen_prop_cost = Networks.get_prop_cost(generator)
        uncertainty = get_uncertainties(uncertainties_at_ech, gen_id, ts, s)
        add_to_expression!(obj_component,
                            (uncertainty - p_injected_var) * gen_prop_cost)
    end

    return obj_component
end

function create_objectives!(model_container::TSOModel,
                            network, uncertainties_at_ech, gratis_starts, loss_of_load_cost, limitation_penalty)

    # cost for cutting load/consumption
    add_coeffxsum_cost!(model_container.objective_model.penalty,
                        model_container.lol_model.p_loss_of_load, loss_of_load_cost)

    # avoid limiting when not necessary
    for (_, var_is_limited) in model_container.limitable_model.b_is_limited
        model_container.objective_model.penalty += limitation_penalty * var_is_limited
    end

    ## Objective 1 :

    # cost for deviating from market schedule
    for (_, var_delta) in model_container.pilotable_model.delta_p
        model_container.objective_model.deltas += var_delta
    end
    for (_, var_delta) in model_container.limitable_model.delta_p
        model_container.objective_model.deltas += var_delta
    end

    ## Objective 2 :

    # cost for starting pilotables
    add_pilotable_start_cost!(model_container.objective_model.start_cost,
                            model_container.pilotable_model.b_start, network, gratis_starts)

    # cost for limitables : cost of capped limitable power
    add_tso_limitable_prop_cost!(model_container.objective_model.prop_cost,
                                uncertainties_at_ech,
                                model_container.limitable_model.p_injected, network)

    # cost for using pilotables
    add_prop_cost!(model_container.objective_model.prop_cost,
                            model_container.pilotable_model.p_injected, network)

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

function add_limitables_vars!(model_container::TSOModel, limitables_list, target_timepoints, scenarios, reference_market_schedule)
    add_injection_vars!(model_container.model, model_container.limitable_model,
                        limitables_list, target_timepoints, scenarios)
    add_limitation_vars!(model_container.model, model_container.limitable_model, limitables_list, target_timepoints, scenarios)
    add_delta_p_vars!(model_container.model, model_container.limitable_model,
                    limitables_list, target_timepoints, scenarios, reference_market_schedule)
end

function tso_out_fo(network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    generators_initial_state::SortedDict{String,GeneratorState},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch,
                    firmness::Firmness,
                    preceding_market_schedule::Schedule,
                    preceding_tso_schedule::Schedule,
                    gratis_starts::Set{Tuple{String,Dates.DateTime}},
                    configs::TSOConfigs
                    )

    pilotables_list_l = Networks.get_generators_of_type(network, Networks.PILOTABLE)
    limitables_list_l = Networks.get_generators_of_type(network, Networks.LIMITABLE)
    buses_list = Networks.get_buses(network)

    model_container_l = TSOModel()

    # Variables
    # add_pilotables_vars!(model_container_l, pilotables_list_l, target_timepoints, scenarios)
    add_limitables_vars!(model_container_l, limitables_list_l, target_timepoints, scenarios, preceding_market_schedule)
    # add_lol_vars!(model_container_l, target_timepoints, scenarios)


    # Constraints
    limitable_power_constraints!(model_container_l.model,
                                model_container_l.limitable_model, limitables_list_l, target_timepoints, scenarios,
                                firmness, uncertainties_at_ech,
                                always_link_scenarios=false)

    # TODO : check coherence between : preceding_reference_schedule and TSOActions.impositions cause we do not consider TSOActions
    if is_market(configs.REF_SCHEDULE_TYPE)
        reference_schedule = preceding_market_schedule
    elseif is_tso(configs.REF_SCHEDULE_TYPE)
        reference_schedule = preceding_tso_schedule
    else
        throw( error("Invalid REF_SCHEDULE_TYPE config.") )
    end
    add_pilotables!(model_container_l,
                    network, target_timepoints,
                    scenarios,
                    generators_initial_state,
                    firmness,
                    reference_schedule,
                    preceding_market_schedule)

    add_slacks!(model_container_l,
                network, target_timepoints, scenarios,
                uncertainties_at_ech)

    eod_constraints!(model_container_l.model, model_container_l.eod_constraint,
                    model_container_l.pilotable_model,
                    model_container_l.limitable_model,
                    model_container_l.lol_model,
                    target_timepoints, scenarios,
                    uncertainties_at_ech, network
                    )

    add_flows!(model_container_l,
                        network, target_timepoints, scenarios,
                        uncertainties_at_ech
                        )

    create_objectives!(model_container_l,
                        network, uncertainties_at_ech,
                        gratis_starts,
                        configs.loss_of_load_penalty, configs.limitation_penalty)

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
