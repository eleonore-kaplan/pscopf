using Dates

using ..Networks

mutable struct PSCOPFContext <: AbstractContext
    network::Networks.Network
    target_timepoints::Vector{Dates.DateTime}
    management_mode::ManagementMode

    #FIXME : Question : Do we need an initial schedule for power levels ?
    #Not if we make sure ECH[1] <= TS-DMO

    generators_initial_state::SortedDict{String,GeneratorState}

    #uncertainties
    uncertainties::Uncertainties

    #AssessmentUncertainties
    assessment_uncertainties

    horizon_timepoints::Vector{Dates.DateTime}

    market_schedule::Schedule
    tso_schedule::Schedule

    tso_actions::TSOActions
    #flows ?
end

function PSCOPFContext(network::Networks.Network, target_timepoints::Vector{Dates.DateTime},
                    management_mode::ManagementMode,
                    generators_initial_state::SortedDict{String,GeneratorState}=SortedDict{String,GeneratorState}(),
                    uncertainties::Uncertainties=Uncertainties(),
                    assessment_uncertainties=nothing
                    )
    market_schedule = Schedule(Market(), Dates.DateTime(0))
    init!(market_schedule, network, target_timepoints, get_scenarios(uncertainties))
    tso_schedule = Schedule(TSO(), Dates.DateTime(0))
    init!(tso_schedule, network, target_timepoints, get_scenarios(uncertainties))
    return PSCOPFContext(network, target_timepoints, management_mode,
                        generators_initial_state,
                        uncertainties, assessment_uncertainties,
                        Vector{Dates.DateTime}(),
                        market_schedule,
                        tso_schedule,
                        TSOActions())
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

function set_horizon_timepoints(context::PSCOPFContext, horizon_timepoints::Vector{Dates.DateTime})
    context.horizon_timepoints = horizon_timepoints
end

function get_management_mode(context::PSCOPFContext)
    return context.management_mode
end

function get_generators_initial_state(context::PSCOPFContext)
    return context.generators_initial_state
end

function get_uncertainties(context::PSCOPFContext)::Uncertainties
    return context.uncertainties
end

function get_uncertainties(context::PSCOPFContext, ech::Dates.DateTime)::UncertaintiesAtEch
    return get_uncertainties(context)[ech]
end

function get_scenarios(context::PSCOPFContext, ech::Dates.DateTime)::Vector{String}
    uncertainties_at_ech = get_uncertainties(context, ech)
    if isnothing(uncertainties_at_ech)
        return Vector{String}()
    else
        return get_scenarios(uncertainties_at_ech)
    end
end

function get_scenarios(context::PSCOPFContext)::Vector{String}
    uncertainties = get_uncertainties(context)
    if isnothing(uncertainties)
        return Vector{String}()
    else
        return get_scenarios(uncertainties)
    end
end

function get_assessment_uncertainties(context::PSCOPFContext)
    return context.assessment_uncertainties
end

function set_current_ech!(context_p::PSCOPFContext, ech::Dates.DateTime)
    context_p.current_ech = ech
end

function get_tso_schedule(context_p::PSCOPFContext)
    return context_p.tso_schedule
end

function get_market_schedule(context_p::PSCOPFContext)
    return context_p.market_schedule
end


function get_limitables_ids(context_p::PSCOPFContext)
    limitables = Networks.get_generators_of_type(get_network(context_p), Networks.LIMITABLE)
    limitables_ids = map(lim_gen->Networks.get_id(lim_gen), limitables)
    return limitables_ids
end
