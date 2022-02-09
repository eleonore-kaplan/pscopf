using Dates

mutable struct PSCOPFContext <: AbstractContext
    grid::AbstractGrid
    target_timepoints::Vector{Dates.DateTime}
    horizon_timepoints::Vector{Dates.DateTime}
    management_mode::ManagementMode
    #uncertainties
    uncertainties::Uncertainties
    #AssessmentUncertainties
    assessment_uncertainties

    #FIXME : besoin d'info sur les états des groupes

    current_ech::Dates.DateTime
    schedule_history::Vector{AbstractSchedule}
    #flows ?
end

function PSCOPFContext(grid::AbstractGrid, target_timepoints::Vector{Dates.DateTime}, horizon_timepoints::Vector{Dates.DateTime},
                    management_mode::ManagementMode)
    return PSCOPFContext(grid, target_timepoints, horizon_timepoints, management_mode,
                        Uncertainties(), nothing,
                        horizon_timepoints[1], Vector{AbstractSchedule}())
end
function PSCOPFContext(grid::AbstractGrid, target_timepoints::Vector{Dates.DateTime}, horizon_timepoints::Vector{Dates.DateTime},
                    management_mode::ManagementMode,
                    uncertainties::Uncertainties, assessment_uncertainties)
    return PSCOPFContext(grid, target_timepoints, horizon_timepoints, management_mode,
                        uncertainties, assessment_uncertainties,
                        horizon_timepoints[1], Vector{AbstractSchedule}())
end

function set_current_ech!(context_p::PSCOPFContext, ech::Dates.DateTime)
    context_p.current_ech = ech
end

function get_current_ech(context_p::PSCOPFContext)
    return context_p.current_ech
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
