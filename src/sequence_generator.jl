using Dates
using DataStructures
using Parameters

@with_kw struct Sequence
    operations::SortedDict{Dates.DateTime, Vector{AbstractRunnable}} = SortedDict{Dates.DateTime, Vector{AbstractRunnable}}()
end

function get_operations(sequence::Sequence)
    return sequence.operations
end

function add_step!(sequence::Sequence, step_type::Type{T}, ech::Dates.DateTime) where T<:AbstractRunnable
    step_instance = step_type()
    steps_at_ech = get!(sequence.operations, ech, Vector{AbstractRunnable}())
    push!(steps_at_ech, step_instance)
end

function run!(context_p::AbstractContext, sequence_p::Sequence)
    println("Lancement du mode : ", context_p.management_mode.name)
    println("Dates d'interet : ", context_p.target_timepoints)
    for (ech, steps_at_ech) in get_operations(sequence_p)
        println("-"^50)
        delta = Dates.value(Dates.Minute(context_p.target_timepoints[1]-ech))
        println("ECH : ", ech, " : M-", delta)
        println("-"^50)
        set_current_ech!(context_p, ech)
        for step in steps_at_ech
            result = run(step, context_p)
            update!(context_p, result, step)
        end
    end
end

struct SequenceGenerator <: AbstractDataGenerator
    grid::AbstractGrid #Not used for now (but potentially we can have specific operations at DMO horizons)
    target_timepoints::Vector{Dates.DateTime}
    horizon_timepoints::Vector{Dates.DateTime}
    management_mode::ManagementMode
end

function launch(seq_generator::SequenceGenerator)
    if seq_generator.management_mode == PSCOPF_MODE_1
        return gen_seq_mode1(seq_generator)

    elseif seq_generator.management_mode == PSCOPF_MODE_2
        return gen_seq_mode2(seq_generator)

    elseif seq_generator.management_mode == PSCOPF_MODE_3
        return gen_seq_mode3(seq_generator)
    end

    error("unsuppported mode : ", seq_generator.management_mode)
end

"""
    generate_sequence
"""
function generate_sequence(grid::AbstractGrid, target_timepoints::Vector{Dates.DateTime},
                            horizon_timepoints::Vector{Dates.DateTime}, management_mode::ManagementMode)
    generator = SequenceGenerator(grid, target_timepoints, horizon_timepoints, management_mode)
    return launch(generator)
end


function gen_seq_mode1(seq_generator::SequenceGenerator)
    sequence = Sequence()
    fo_startpoint = seq_generator.target_timepoints[1] - get_fo_length(seq_generator.management_mode)

    for ech in seq_generator.horizon_timepoints
        if ech <  seq_generator.horizon_timepoints[end]
            if ech < fo_startpoint
                add_step!(sequence, EnergyMarket, ech)
                add_step!(sequence, TSOOutFO, ech)

            elseif ech == fo_startpoint
                add_step!(sequence, EnergyMarketAtFO, ech)
                add_step!(sequence, EnterFO, ech)
                add_step!(sequence, TSOInFO, ech)

            else
                add_step!(sequence, TSOInFO, ech)
            end
        end
    end

    add_step!(sequence, Assessment, seq_generator.horizon_timepoints[end])

    return sequence
end


function gen_seq_mode2(seq_generator::SequenceGenerator)
    sequence = Sequence()
    fo_startpoint = seq_generator.target_timepoints[1] - get_fo_length(seq_generator.management_mode)

    for ech in seq_generator.horizon_timepoints
        if ech <  seq_generator.horizon_timepoints[end]
            if ech < fo_startpoint
                add_step!(sequence, EnergyMarket, ech)
                add_step!(sequence, TSOOutFO, ech)

            elseif ech == fo_startpoint
                add_step!(sequence, EnergyMarketAtFO, ech)
                add_step!(sequence, EnterFO, ech)
                add_step!(sequence, TSOBiLevel, ech)

            else
                add_step!(sequence, BalanceMarket, ech)
                add_step!(sequence, TSOBiLevel, ech)
            end
        end
    end

    add_step!(sequence, Assessment, seq_generator.horizon_timepoints[end])

    return sequence
end


function gen_seq_mode3(seq_generator::SequenceGenerator)
    sequence = Sequence()
    fo_startpoint = seq_generator.target_timepoints[1] - get_fo_length(seq_generator.management_mode)

    for ech in seq_generator.horizon_timepoints
        if ech <  seq_generator.horizon_timepoints[end]
            if ech < fo_startpoint
                add_step!(sequence, EnergyMarket, ech)
                add_step!(sequence, TSOOutFO, ech)

            elseif ech == fo_startpoint
                add_step!(sequence, EnergyMarket, ech)
                add_step!(sequence, EnterFO, ech)
                add_step!(sequence, TSOAtFOBiLevel, ech)

            else
                add_step!(sequence, EnergyMarket, ech)
            end
        end
    end

    add_step!(sequence, Assessment, seq_generator.horizon_timepoints[end])

    return sequence
end
