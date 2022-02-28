using ..Networks

using JuMP


function energy_market(network::Networks.Network,
                    target_timepoints::Vector{Dates.DateTime},
                    generators_initial_state::SortedDict{String,GeneratorState},
                    scenarios::Vector{String},
                    uncertainties_at_ech::UncertaintiesAtEch,
                    firmness::Firmness,
                    reference_schedule::Schedule,
                    gratis_starts::Set{Tuple{String,Dates.DateTime}};
                    out_path=@__DIR__,
                    problem_name="energy_market",
                    )

    model_container_l = EnergyMarketModel()

    add_limitables!(model_container_l,
                    network, target_timepoints,
                    scenarios,
                    uncertainties_at_ech,
                    #firmness, reference_schedule
                    )

    add_imposables!(model_container_l,
                    network, target_timepoints,
                    generators_initial_state,
                    scenarios,
                    firmness, reference_schedule)


    add_eod_constraint!(model_container_l,
                        network, target_timepoints, scenarios,
                        uncertainties_at_ech
                        )

    add_objective!(model_container_l, network, gratis_starts)

    solve!(model_container_l, problem_name, out_path)

    status_l = get_status(model_container_l)

    @info "pscopf model status: $status_l"
    @info "Termination status : $(termination_status(model_container_l.model))"
    @info "Objective value : $(objective_value(model_container_l.model))"

    return model_container_l
end

function add_objective!(model_container, network, gratis_starts)
    # No cost for starting limitables

    # cost for starting imposables
    for ((gen_id,ts,_), b_start_var) in model_container.imposable_model.b_start
        if (gen_id,ts) in gratis_starts
            @info(@sprintf("ignore starting cost of %s at %s", gen_id, ts))
            continue
        end
        generator = Networks.get_generator(network, gen_id)
        gen_start_cost = Networks.get_start_cost(generator)
        model_container.objective_model.start_cost += b_start_var * gen_start_cost
    end

    # cost for using limitables : but most of the times these are fixed
    for ((gen_id,_,_), p_injected_var) in model_container.limitable_model.p_injected
        generator = Networks.get_generator(network, gen_id)
        gen_prop_cost = Networks.get_prop_cost(generator)
        model_container.objective_model.prop_cost += p_injected_var * gen_prop_cost
    end

    # cost for using imposables
    for ((gen_id,_,_), p_injected_var) in model_container.imposable_model.p_injected
        generator = Networks.get_generator(network, gen_id)
        gen_prop_cost = Networks.get_prop_cost(generator)
        model_container.objective_model.prop_cost += p_injected_var * gen_prop_cost
    end

    model_container.objective_model.full_obj = ( model_container.objective_model.start_cost +
                                                model_container.objective_model.prop_cost )
    @objective(model_container.model, Min, model_container.objective_model.full_obj)
    return model_container
end

function add_commitment_constraints!(model::Model,
                                    generator::Networks.Generator,
                                    b_on_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                    b_start_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                    target_timepoints::Vector{Dates.DateTime},
                                    generator_initial_state::GeneratorState,
                                    scenarios::Vector{String}
                                    )
    gen_id = Networks.get_id(generator)
    for s in scenarios
        for (ts_index, ts) in enumerate(target_timepoints)
            #commitment_constraints
            preceding_on = (ts_index > 1) ? b_on_vars[gen_id, target_timepoints[ts_index-1], s] : float(generator_initial_state)
            @constraint(model, b_start_vars[gen_id, ts, s] <= b_on_vars[gen_id, ts, s])
            @constraint(model, b_start_vars[gen_id, ts, s] <= 1 - preceding_on)
            @constraint(model, b_start_vars[gen_id, ts, s] >= b_on_vars[gen_id, ts, s] - preceding_on)
        end
    end
end

function add_firmness_constraints!(model::Model,
                                    generator::Networks.Generator,
                                    vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                    target_timepoints::Vector{Dates.DateTime},
                                    scenarios::Vector{String},
                                    vars_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                                    generator_reference_schedule::SortedDict{Dates.DateTime, UncertainValue{T}}, #by ts
                                    ) where T
    gen_id = Networks.get_id(generator)
    for ts in target_timepoints
        if vars_firmness[ts] == DECIDED
            val = float(safeget_value(generator_reference_schedule[ts]))
            for s in scenarios
                @assert( !has_upper_bound(vars[gen_id, ts, s]) || (val <= upper_bound(vars[gen_id, ts, s])) )
                # fix(vars[gen_id, ts, s], val, force=true)
                @constraint(model, vars[gen_id, ts, s] == val)
            end
        elseif vars_firmness[ts] == TO_DECIDE
            #all scenario values are equal
            s1 = scenarios[1]
            for (s_index, s) in enumerate(scenarios)
                if s_index > 1
                    @constraint(model, vars[gen_id, ts, s] == vars[gen_id, ts, s1]);
                end
            end
        end
    end
end

function add_commitment_firmness_constraints!(model::Model,
                                            generator::Networks.Generator,
                                            b_on_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                            target_timepoints::Vector{Dates.DateTime},
                                            scenarios::Vector{String},
                                            commitment_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                                            generator_reference_schedule::GeneratorSchedule
                                            )
    add_firmness_constraints!(model, generator,
                            b_on_vars,
                            target_timepoints, scenarios,
                            commitment_firmness,
                            generator_reference_schedule.commitment)
end

function add_power_level_firmness_constraints!(model::Model,
                                                generator::Networks.Generator,
                                                p_injected_vars::SortedDict{Tuple{String,DateTime,String},VariableRef},
                                                target_timepoints::Vector{Dates.DateTime},
                                                scenarios::Vector{String},
                                                power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                                                generator_reference_schedule::GeneratorSchedule
                                                )
    add_firmness_constraints!(model, generator,
                            p_injected_vars,
                            target_timepoints, scenarios,
                            power_level_firmness,
                            generator_reference_schedule.production)
end

function add_imposable!(imposable_model::EnergyMarketImposableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        generator_initial_state::GeneratorState,
                        scenarios::Vector{String},
                        commitment_firmness::Union{Missing,SortedDict{Dates.DateTime, DecisionFirmness}}, #by ts #or Missing
                        power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                        generator_reference_schedule::GeneratorSchedule
                        )
    gen_id = Networks.get_id(generator)
    p_min = Networks.get_p_min(generator)
    p_max = Networks.get_p_max(generator)
    for (ts_index, ts) in enumerate(target_timepoints)
        for s in scenarios
            name =  @sprintf("P_injected[%s,%s,%s]", gen_id, ts, s)
            imposable_model.p_injected[gen_id, ts, s] = @variable(model, base_name=name)

            if p_min > 0
                @constraint(model, imposable_model.p_injected[gen_id, ts, s] in MOI.Semicontinuous(p_min, p_max))
                name =  @sprintf("B_on[%s,%s,%s]", gen_id, ts, s)
                imposable_model.b_on[gen_id, ts, s] = @variable(model, base_name=name, binary=true)
                name =  @sprintf("B_start[%s,%s,%s]", gen_id, ts, s)
                imposable_model.b_start[gen_id, ts, s] = @variable(model, base_name=name, binary=true)

                # pmin < P_injected < pmax OR = 0
                @constraint(model, imposable_model.p_injected[gen_id, ts, s] <= p_max * imposable_model.b_on[gen_id, ts, s]);
                @constraint(model, imposable_model.p_injected[gen_id, ts, s] >= p_min * imposable_model.b_on[gen_id, ts, s]);
            else #pmin=0
                set_lower_bound(imposable_model.p_injected[gen_id, ts, s], 0.) #p_min=0
                set_upper_bound(imposable_model.p_injected[gen_id, ts, s], p_max)
            end
        end
    end

    add_power_level_firmness_constraints!(model, generator,
                                        imposable_model.p_injected,
                                        target_timepoints, scenarios,
                                        power_level_firmness,
                                        generator_reference_schedule
                                        )

    if p_min > 0
        add_commitment_constraints!(model, generator,
                                    imposable_model.b_on, imposable_model.b_start,
                                    target_timepoints, generator_initial_state, scenarios
                                    )
        add_commitment_firmness_constraints!(model, generator,
                                            imposable_model.b_on,
                                            target_timepoints, scenarios,
                                            commitment_firmness,
                                            generator_reference_schedule
                                            )
    end

    return imposable_model, model
end

function add_limitable!(limitable_model::EnergyMarketLimitableModel, model::Model,
                        generator::Networks.Generator,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        inject_uncertainties::InjectionUncertainties,
                        #power_level_firmness::SortedDict{Dates.DateTime, DecisionFirmness}, #by ts
                        #generator_reference_schedule::GeneratorSchedule
                        )
    gen_id = Networks.get_id(generator)
    for ts in target_timepoints
        for s in scenarios
            p_max = min(Networks.get_p_max(generator), inject_uncertainties[ts][s]) #FIXME and limit induced by the TSO, potentially (for other markets, this for now does not look at the TSO constraints)
            name =  @sprintf("P_injected[%s,%s,%s]", gen_id, ts, s)
            limitable_model.p_injected[gen_id, ts, s] = @variable(model, base_name=name, lower_bound=0., upper_bound=p_max)

            #Level of the limitable is set to the uncertainty or pmax
            #FIXME : if decided : set minimum(decided,uncertain)
            #        if to_decide : add firmness constraints
            #        else (if free) : fix to upper_bound
            #fix(limitable_model.p_injected[gen_id, ts, s], p_max, force=true)
            @constraint(model, limitable_model.p_injected[gen_id, ts, s] == p_max)
        end
    end


    # add_power_level_firmness_constraints!(model, generator,
    #                                     limitable_model.p_injected,
    #                                     target_timepoints, scenarios,
    #                                     power_level_firmness,
    #                                     generator_reference_schedule
    #                                     )

    return limitable_model, model
end

function add_imposables!(model_container::EnergyMarketModel, network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        generators_initial_state::SortedDict{String,GeneratorState},
                        scenarios::Vector{String},
                        firmness::Firmness,
                        reference_schedule::Schedule
                        )
    imposable_generators = Networks.get_generators_of_type(network, Networks.IMPOSABLE)
    for imposable_gen in imposable_generators
        gen_id = Networks.get_id(imposable_gen)
        # gen_commitment = get_commitment_firmness(firmness, gen_id)
        gen_initial_state = get_initial_state(generators_initial_state, imposable_gen)
        add_imposable!(model_container.imposable_model, model_container.model,
                        imposable_gen,
                        target_timepoints,
                        gen_initial_state,
                        scenarios,
                        get_commitment_firmness(firmness, gen_id),
                        get_power_level_firmness(firmness, gen_id),
                        get_sub_schedule(reference_schedule, gen_id)
                        )
    end
    return model_container.imposable_model
end

function add_limitables!(model_container::EnergyMarketModel, network::Networks.Network,
                        target_timepoints::Vector{Dates.DateTime},
                        scenarios::Vector{String},
                        uncertainties_at_ech::UncertaintiesAtEch,
                        # firmness::Firmness,
                        # reference_schedule::Schedule
                        )
    limitable_generators = Networks.get_generators_of_type(network, Networks.LIMITABLE)
    for limitable_gen in limitable_generators
        gen_id = Networks.get_id(limitable_gen)
        add_limitable!(model_container.limitable_model, model_container.model,
                        limitable_gen,
                        target_timepoints,
                        scenarios,
                        get_uncertainties(uncertainties_at_ech, gen_id),
                        # get_power_level_firmness(firmness, gen_id),
                        # get_sub_schedule(reference_schedule, gen_id)
                        )
    end
    return model_container.limitable_model
end

function add_eod_constraint!(model_container::EnergyMarketModel,
                            network::Networks.Network,
                            target_timepoints::Vector{Dates.DateTime},
                            scenarios::Vector{String},
                            uncertainties_at_ech::UncertaintiesAtEch)
    for ts in target_timepoints
        for s in scenarios
            load = compute_load(uncertainties_at_ech, network, ts, s)

            prod = AffExpr(0)
            for generator in Networks.get_generators(network)
                gen_id = Networks.get_id(generator)
                gen_type = Networks.get_type(generator)
                if gen_type == Networks.LIMITABLE
                    prod += model_container.limitable_model.p_injected[gen_id,ts,s]
                elseif gen_type == Networks.IMPOSABLE
                    prod += model_container.imposable_model.p_injected[gen_id,ts,s]
                end
            end

            model_container.eod_constraint[ts,s] = @constraint(model_container.model, prod == load)
        end
    end
end
