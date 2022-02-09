using Dates

using ..Networks

mutable struct PSCOPFContext <: AbstractContext
    network::Networks.Network
    target_timepoints::Vector{Dates.DateTime}
    management_mode::ManagementMode

    #FIXME : which gen is on ? Question : need info by TS ?
    generators_initial_state::SortedDict{String,GeneratorState}

    #uncertainties
    uncertainties::Uncertainties

    #AssessmentUncertainties
    assessment_uncertainties

    schedule_history::Vector{Schedule}
    #Imposition
    # ts,gen,s
    # SortedDict{Dates.DateTime, SortedDict{String, SortedDict{String, Float64}} }
    #Limitation : because the schedule is not enough to know the limit
    # ts,gen
    # SortedDict{Dates.DateTime, SortedDict{String, Float64} }
    #flows ?

    horizon_timepoints::Vector{Dates.DateTime}
    current_ech::Union{Dates.DateTime,Nothing}
end

function PSCOPFContext(network::Networks.Network, target_timepoints::Vector{Dates.DateTime},
                    management_mode::ManagementMode,
                    generators_initial_state::SortedDict{String,GeneratorState}=SortedDict{String,GeneratorState}(),
                    uncertainties::Uncertainties=Uncertainties(),
                    assessment_uncertainties=nothing,
                    horizon_timepoints=Vector{Dates.DateTime}(),
                    )
    return PSCOPFContext(network, target_timepoints, management_mode,
                        generators_initial_state,
                        uncertainties, assessment_uncertainties,
                        Vector{Schedule}(),
                        horizon_timepoints,
                        nothing)
end

function set_horizon_timepoints!(context_p::PSCOPFContext, horizons::Vector{Dates.DateTime})
    context_p.horizon_timepoints = horizons
end

function get_network(context::PSCOPFContext)
    return context.network
end

function get_target_timepoints(context::PSCOPFContext)
    return context.target_timepoints
end

function get_horizon_timepoints(context::PSCOPFContext)
    return context.horizon_timepoints
end

function get_management_mode(context::PSCOPFContext)
    return context.management_mode
end

function get_generators_initial_state(context::PSCOPFContext)
    return context.generators_initial_state
end

function get_uncertainties(context::PSCOPFContext)
    return context.uncertainties
end

function get_assessment_uncertainties(context::PSCOPFContext)
    return context.assessment_uncertainties
end

function set_current_ech!(context_p::PSCOPFContext, ech::Dates.DateTime)
    context_p.current_ech = ech
end

function get_current_ech(context_p::PSCOPFContext)
    return context_p.current_ech
end

function get_next_ech(context_p::PSCOPFContext)
    ech = get_current_ech(context_p)
    next_ech_index = findfirst(x->x>ech, get_horizon_timepoints(context_p))
    if isnothing(next_ech_index)
        return nothing
    else
        return get_horizon_timepoints(context_p)[next_ech_index]
    end
end

function safeget_last_schedule(context_p::PSCOPFContext)
    if isempty(context_p.schedule_history)
        throw( error("empty schedule history!") )
    end
    return context_p.schedule_history[end]
end

function safeget_last_tso_schedule(context_p::PSCOPFContext)
    index_l = findlast(schedule -> is_tso(schedule.decider), context_p.schedule_history)
    if isnothing(index_l)
        throw( error("no TSO schedule in schedule history!") )
    end
    return context_p.schedule_history[index_l]
end

function safeget_last_market_schedule(context_p::PSCOPFContext)
    index_l = findlast(schedule -> is_market(schedule.decider), context_p.schedule_history)
    if isnothing(index_l)
        throw( error("no market schedule in schedule history!") )
    end
    return context_p.schedule_history[index_l]
end

function add_schedule!(context_p::PSCOPFContext, schedule::Schedule)
    push!(context_p.schedule_history, schedule)
end
