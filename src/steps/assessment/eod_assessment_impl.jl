using .Networks

using Dates
using JuMP
using Printf
using Parameters

@with_kw mutable struct EODAssessmentModel <: AbstractModelContainer
    model::Model = Model()

    # Uncertainty model
    #bus,ts
    uncertain_load = SortedDict{Tuple{String, DateTime},VariableRef}();
    #limitableUnit,ts
    uncertain_prod = SortedDict{Tuple{String, DateTime},VariableRef}();

    # Market model
    #unit, ts
    p_injected = Dict{Tuple{String, DateTime},VariableRef}();
    b_in = Dict{Tuple{String, DateTime},VariableRef}();
    b_marg = Dict{Tuple{String, DateTime},VariableRef}();
    b_out = Dict{Tuple{String, DateTime},VariableRef}();

    #ts :
    #cut prod
    p_cut_prod = Dict{DateTime,VariableRef}();
    #LoL
    p_cut_conso = Dict{DateTime,VariableRef}();

    #objective
    cut_conso_obj =  AffExpr(0.)
    prod_obj =  AffExpr(0.)
    cut_prod_obj =  AffExpr(0.)
    full_obj = AffExpr(0.)
end



function add_load_uncertainties_vars!(model_container::EODAssessmentModel,
                                    network, TS, assessment_uncertainties)
    for bus in Networks.get_buses(network)
        bus_id = Networks.get_id(bus)
        lb_l = get_assessment_uncertainties_lb(assessment_uncertainties, bus_id)
        ub_l = get_assessment_uncertainties_ub(assessment_uncertainties, bus_id)
        for ts in TS
            name =  @sprintf("uncertain_load[%s,%s]", bus_id, ts);
            model_container.uncertain_load[bus_id,ts] = @variable(model_container.model, base_name = name,
                                                                lower_bound = lb_l, upper_bound = ub_l)
        end
    end

    return model_container.uncertain_load
end
function add_prod_uncertainties_vars!(model_container::EODAssessmentModel,
                                    network, TS, assessment_uncertainties, tso_actions)
    for limitable_gen in Networks.get_generators_of_type(network, Networks.LIMITABLE)
        gen_id = Networks.get_id(limitable_gen)
        lb_l = get_assessment_uncertainties_lb(assessment_uncertainties, gen_id)
        for ts in TS
            # this allows to set p_inj[gen_id] == uncertain_prod without needing to express min(uncertain, limit) in the model
            ub_l = min(get_assessment_uncertainties_ub(assessment_uncertainties, gen_id),
                    get_limitation(tso_actions, gen_id, ts))
            name =  @sprintf("uncertain_prod[%s,%s]", gen_id, ts);
            model_container.uncertain_prod[gen_id, ts] = @variable(model_container.model, base_name=name,
                                                                lower_bound = lb_l, upper_bound = ub_l)
        end
    end

    return model_container.uncertain_prod
end
function add_uncertainties_vars!(model_container::EODAssessmentModel,
                                network, TS, assessment_uncertainties, tso_actions)
    add_load_uncertainties_vars!(model_container,
                                network, TS, assessment_uncertainties)
    add_prod_uncertainties_vars!(model_container,
                                network, TS, assessment_uncertainties, tso_actions)
    return model_container
end


function add_limitable_prod_vars!(model_container::EODAssessmentModel, network, TS)
    for limitable_gen in Networks.get_generators_of_type(network, Networks.LIMITABLE)
        gen_id = Networks.get_id(limitable_gen)
        for ts in TS
            name =  @sprintf("p_injected[%s,%s]", gen_id, ts)
            model_container.p_injected[gen_id,ts] = @variable(model_container.model, base_name=name)
        end
    end

    return model_container.p_injected
end

function add_use_limitables_constraints!(model_container::EODAssessmentModel, network, TS, tso_actions)
    for limitable_gen in Networks.get_generators_of_type(network, Networks.LIMITABLE)
        gen_id = Networks.get_id(limitable_gen)
        for ts in TS
            limit_l = get_limitation(tso_actions, gen_id, ts)
            @assert(upper_bound(model_container.uncertain_prod[gen_id, ts]) <= limit_l)
            @constraint(model_container.model,
                        model_container.p_injected[gen_id,ts] == model_container.uncertain_prod[gen_id, ts])
        end
    end
    return model_container
end

function add_imposable_prod_vars!(model_container_p::EODAssessmentModel, network, TS, tso_actions)
    p_injected_l = model_container_p.p_injected
    b_in_l = model_container_p.b_in
    b_marg_l = model_container_p.b_marg
    b_out_l = model_container_p.b_out

    for imposable_gen in Networks.get_generators_of_type(network, Networks.IMPOSABLE)
        gen_id = Networks.get_id(imposable_gen)
        for ts in TS
            pmin_l = get_firm_imposition(tso_actions, gen_id, ts)[1]
            pmax_l = get_firm_imposition(tso_actions, gen_id, ts)[2]
            name_l =  @sprintf("b_in[%s,%s]", gen_id, ts);
            b_in_l[gen_id,ts] = @variable(model_container_p.model, base_name = name_l, binary = true)
            name_l =  @sprintf("b_marginal[%s,%s]", gen_id, ts);
            b_marg_l[gen_id,ts] = @variable(model_container_p.model, base_name = name_l, binary = true)
            name_l =  @sprintf("b_out[%s,%s]", gen_id, ts);
            b_out_l[gen_id,ts] = @variable(model_container_p.model, base_name = name_l, binary = true)
            name_l =  @sprintf("prod[%s,%s]", gen_id, ts);
            p_injected_l[gen_id,ts] = @variable(model_container_p.model, base_name = name_l, upper_bound = pmax_l);

            @constraint(model_container_p.model,
                        p_injected_l[gen_id,ts] >= ( pmax_l * b_in_l[gen_id,ts] +  pmin_l * b_marg_l[gen_id,ts] ));
            @constraint(model_container_p.model,
                        p_injected_l[gen_id,ts] <= (1 - b_out_l[gen_id,ts]) * pmax_l);
            @constraint(model_container_p.model,
                        b_out_l[gen_id,ts] + b_marg_l[gen_id,ts] + b_in_l[gen_id,ts] == 1.);
        end
    end

    return model_container_p
end

function add_market_vars!(model_container::EODAssessmentModel, network, TS, assessment_uncertainties, tso_actions)
    add_limitable_prod_vars!(model_container, network, TS)
    add_imposable_prod_vars!(model_container, network, TS, tso_actions)
end

function add_cut_prod_vars!(model_container::EODAssessmentModel, network, TS)
    for ts in TS
        name_l =  @sprintf("cut_prod[%s]", ts);
        model_container.p_cut_prod[ts] = @variable(model_container.model,
                                                    base_name = name_l, lower_bound=0.)

        prod_expr = sum(model_container.p_injected[gen_id,ts]
                        for gen_id in Networks.get_id.(Networks.get_generators(network)))
        @constraint(model_container.model, model_container.p_cut_prod[ts] <= prod_expr)
    end
    return model_container
end

function add_cut_conso_vars!(model_container::EODAssessmentModel, network, TS)
    for ts in TS
        name_l =  @sprintf("cut_conso[%s]", ts);
        model_container.p_cut_conso[ts] = @variable(model_container.model,
                                                    base_name = name_l, lower_bound=0.)

        conso_expr = sum(model_container.uncertain_load[bus_id,ts]
                        for bus_id in Networks.get_id.(Networks.get_buses(network)))
        @constraint(model_container.model, model_container.p_cut_conso[ts] <= conso_expr)
    end
    return model_container
end

function add_cheapest_prod_constraints!(model_container::EODAssessmentModel, network, TS)
    imposables = Networks.get_generators_of_type(network, Networks.IMPOSABLE)
    for (index, gen_1) in enumerate(imposables)
        cost_1 = Networks.get_prop_cost(gen_1)
        gen_id_1 = Networks.get_id(gen_1)
        for gen_2 in imposables[index:end]
            cost_2 = Networks.get_prop_cost(gen_2)
            if cost_1 < cost_2
                gen_id_2 = Networks.get_id(gen_2)
                for ts in TS
                    @constraint(model_container.model, model_container.b_in[gen_id_1,ts] >= model_container.b_in[gen_id_2,ts] );
                end
            end
        end
    end

    return model_container
end

function add_eod_constraint!(model_container_p::EODAssessmentModel, network, TS)

    for ts in TS
        eod_expr_l = AffExpr(0)

        for gen in Networks.get_generators(network)
            gen_id = Networks.get_id(gen)
            eod_expr_l += model_container_p.p_injected[gen_id, ts];
        end
        eod_expr_l -= model_container_p.p_cut_prod[ts];

        for bus in Networks.get_buses(network)
            bus_id = Networks.get_id(bus)
            eod_expr_l -= model_container_p.uncertain_load[bus_id, ts];
        end
        eod_expr_l += model_container_p.p_cut_conso[ts];

        @constraint(model_container_p.model, eod_expr_l == 0.);
    end

    return model_container_p
end

function create_objective!(model_container, network, TS, cut_conso_coeff, inj_prod_coeff, cut_prod_coeff)
    @assert(cut_conso_coeff >= 0.)
    @assert(inj_prod_coeff >= 0.)
    @assert(cut_prod_coeff >= 0.)

    model_container.cut_conso_obj = AffExpr(0.)
    for ts in TS
        add_to_expression!(model_container.cut_conso_obj, cut_conso_coeff * model_container.p_cut_conso[ts])
    end

    model_container.cut_prod_obj = AffExpr(0.)
    for ts in TS
        add_to_expression!(model_container.cut_prod_obj, -cut_prod_coeff * model_container.p_cut_prod[ts])
    end

    model_container.prod_obj = AffExpr(0.)
    #exclude limitables to allow setting their uncertainties at a low level
    for gen in Networks.get_generators_of_type(network, Networks.IMPOSABLE)
        gen_id = Networks.get_id(gen)
        for ts in TS
            add_to_expression!(model_container.prod_obj, inj_prod_coeff * model_container.p_injected[gen_id, ts])
        end
    end

    model_container.full_obj = model_container.cut_conso_obj + model_container.cut_prod_obj + model_container.prod_obj
    return model_container.full_obj
end

function formulate_eod_assessment(network, TS, assessment_uncertainties, tso_actions, configs)
    model_container_l = EODAssessmentModel()

    add_uncertainties_vars!(model_container_l, network, TS, assessment_uncertainties, tso_actions)
    add_market_vars!(model_container_l, network, TS, assessment_uncertainties, tso_actions)
    add_cut_prod_vars!(model_container_l, network, TS)
    add_cut_conso_vars!(model_container_l, network, TS)

    add_use_limitables_constraints!(model_container_l, network, TS, tso_actions)
    add_cheapest_prod_constraints!(model_container_l, network, TS)
    add_eod_constraint!(model_container_l, network, TS)

    create_objective!(model_container_l, network, TS,
                    configs.cut_conso_coeff, configs.cut_prod_coeff, configs.inj_prod_coeff)
    @objective(get_model(model_container_l), Max, model_container_l.full_obj)

    return model_container_l
end

function is_validated(model_container::EODAssessmentModel)
    return value(model_container.cut_conso_obj) < 1e-09
end

function has_positive_slack(model_container::EODAssessmentModel)::Bool
    return false # ( has_positive_value(model_container.lower.slack_model.p_cut_conso)
           #  || has_positive_value(model_container.lower.slack_model.p_cut_prod) )
end

function get_assessment_uncertainties_lb(assessment_uncertainties, bus_or_limitable::String)
    return assessment_uncertainties[bus_or_limitable][1]
end
function get_assessment_uncertainties_ub(assessment_uncertainties, bus_or_limitable::String)
    return assessment_uncertainties[bus_or_limitable][2]
end

function get_firm_imposition(tso_actions, gen_id, ts)
    return get_imposition(tso_actions, gen_id, ts, "S")
end
