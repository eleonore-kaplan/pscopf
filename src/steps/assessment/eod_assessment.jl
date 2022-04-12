using .Networks

using Dates
using JuMP
using Printf
using Parameters

#FIXME
#Lose control on EOD, model has no incentive to start the units since it allows it to maximise LoL
#if we try to add injections in objective, it simply decides wether to opt for injections or cutting first
#if high inject_coeff => will try to allow all units to inject however we wont the opposite
#we want :
#   imposible units to inject (to try satisfy the EOD),
#   limitables to be at their lowest levels
#   conso to be at highest level
#if we try to minimize Lol than we are no longer doing an assessment, the model would choose a situation that works fine
#=
#does not work with :
cut_prod_coeff = 100 #must be greater than LoL coeff in objective
inj_prod_coeff = 10 #must be greater than LoL coeff in objective
cut_conso_coeff = 1 #LoL

@testset verbose=true "test_calling_with_run" begin
    limit_1 = 75.
    impositions_1 = (0., 0.)
    impositions_2 = (20., 60.)

    context = create_instance(limit_1, impositions_1, impositions_2,
                        35.,"assess")

    assessment = PSCOPF.EODAssessment()
    result = PSCOPF.run(assessment, ech, TS, context)

    @test !PSCOPF.is_validated(result)
end

uncertain_load[bus_1,2015-01-01T11:00:00] = 50.0
uncertain_load[bus_2,2015-01-01T11:00:00] = 70.0
uncertain_prod[wind_1_1,2015-01-01T11:00:00] = 75.0
p_injected[wind_1_1,2015-01-01T11:00:00] = 75.0
b_in[prod_1_1,2015-01-01T11:00:00] = 1.0
b_marginal[prod_1_1,2015-01-01T11:00:00] = 0.0
b_out[prod_1_1,2015-01-01T11:00:00] = 0.0
prod[prod_1_1,2015-01-01T11:00:00] = 0.0
b_in[prod_2_1,2015-01-01T11:00:00] = 0.0
b_marginal[prod_2_1,2015-01-01T11:00:00] = 1.0
b_out[prod_2_1,2015-01-01T11:00:00] = 0.0
prod[prod_2_1,2015-01-01T11:00:00] = 60.0
cut_prod[2015-01-01T11:00:00] = 14.999999999999996
cut_conso[2015-01-01T11:00:00] = 0.0

=#

@with_kw mutable struct EODAssessmentConfigs
    cut_prod_coeff = 100 #must be greater than LoL coeff in objective
    inj_prod_coeff = 10 #must be greater than LoL coeff in objective
    cut_conso_coeff = 1 #LoL
    out_path = nothing
    problem_name = "EODAssessment"
end

@with_kw struct EODAssessment <: AbstractRunnable
    configs::EODAssessmentConfigs = EODAssessmentConfigs()
end

function run(runnable::EODAssessment, ech::Dates.DateTime, TS::Vector{Dates.DateTime}, context::AbstractContext)
    problem_name_l = @sprintf("tso_out_fo_%s", ech)
    runnable.configs.out_path = context.out_dir
    runnable.configs.problem_name = problem_name_l

    # @assert( runnable.configs.cut_conso_penalty >=
    #         biggest_min_imposition(get_tso_actions(context)) * runnable.configs.cut_prod_penalty)
    @assert( runnable.configs.cut_conso_coeff
                <= runnable.configs.inj_prod_coeff
                    <= runnable.configs.cut_prod_coeff )

    #FIXME : only create vars for started units

    return eod_assessment(get_network(context),
                        TS,
                        get_assessment_uncertainties(context),
                        get_tso_actions(context),
                        runnable.configs
                    )
end

function eod_assessment(network,
                        TS,
                        assessment_uncertainties,
                        tso_actions,
                        configs::EODAssessmentConfigs
                    )
    model_container_l = formulate_eod_assessment(network, TS, assessment_uncertainties, tso_actions, configs)
    solve!(model_container_l, configs.problem_name, configs.out_path)

    for var in all_variables(model_container_l.model)
        println(name(var), " = ", value(var))
    end

    return model_container_l
end

function biggest_min_imposition(tso_actions::TSOActions)
    return maximum(x->x[2][1], get_impositions(tso_actions))
end

