using Dates

mutable struct PSCOPFContext <: AbstractContext
    grid::AbstractGrid
    target_timepoints::Vector{Dates.DateTime}
    horizon_timepoints::Vector{Dates.DateTime}
    management_mode::ManagementMode

    #FIXME : which gen is on ? Question : need info by TS ?
    generators_initial_state::SortedDict{String,GeneratorState}

    #uncertainties
    uncertainties::Uncertainties

    #AssessmentUncertainties
    assessment_uncertainties

    schedule_history::Vector{AbstractSchedule}
    #flows ?
    current_ech::Dates.DateTime
end

# function PSCOPFContext(grid::AbstractGrid, target_timepoints::Vector{Dates.DateTime}, horizon_timepoints::Vector{Dates.DateTime},
#                     management_mode::ManagementMode)
#     return PSCOPFContext(grid, target_timepoints, horizon_timepoints, management_mode,
#                         Uncertainties(), nothing,
#                         horizon_timepoints[1], Vector{AbstractSchedule}(),
#                         SortedDict{String,GeneratorState}())
# end
function PSCOPFContext(grid::AbstractGrid, target_timepoints::Vector{Dates.DateTime}, horizon_timepoints::Vector{Dates.DateTime},
                    management_mode::ManagementMode,
                    generators_initial_state::SortedDict{String,GeneratorState}=SortedDict{String,GeneratorState}(),
                    uncertainties::Uncertainties=Uncertainties(),
                    assessment_uncertainties=nothing,
                    )
    return PSCOPFContext(grid, target_timepoints, horizon_timepoints, management_mode,
                        generators_initial_state,
                        uncertainties, assessment_uncertainties,
                        Vector{AbstractSchedule}(),
                        horizon_timepoints[1])
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
