using Dates
using DataStructures
using Parameters

using ..Networks

@with_kw struct Sequence
    operations::SortedDict{Dates.DateTime, Vector{AbstractRunnable}} = SortedDict{Dates.DateTime, Vector{AbstractRunnable}}()
end

function get_operations(sequence::Sequence)
    return sequence.operations
end

function get_timepoints(sequence::Sequence)
    return collect(keys(get_operations(sequence)))
end

"""
    length of the sequence in terms of time not in terms of number of runnables to execute
"""
function Base.length(sequence::Sequence)
    return length(get_operations(sequence))
end

function get_horizon_timepoints(sequence::Sequence)::Vector{Dates.DateTime}
    return collect(keys(get_operations(sequence)))
end

function get_ech(sequence::Sequence, index)
    if length(sequence) < index
        throw( error("attempt to acess ", length(sequence), "-element Sequence at index ", index, ".") )
    else
        return get_horizon_timepoints(sequence)[index]
    end
end

function add_step!(sequence::Sequence, step_type::Type{T}, ech::Dates.DateTime) where T<:AbstractRunnable
    step_instance = step_type()
    add_step!(sequence, step_instance, ech)
end
function add_step!(sequence::Sequence, step_instance::AbstractRunnable, ech::Dates.DateTime)
    steps_at_ech = get!(sequence.operations, ech, Vector{AbstractRunnable}())
    push!(steps_at_ech, step_instance)
end

function run!(context_p::AbstractContext, sequence_p::Sequence;
                check_context=true)
    println("Lancement du mode : ", context_p.management_mode.name)
    println("Dates d'interet : ", get_target_timepoints(context_p))
    set_horizon_timepoints(context_p, get_timepoints(sequence_p))
    println("Dates d'échéances : ", get_horizon_timepoints(context_p))

    if check_context && !check(context_p)
        throw( error("Invalid context!") )
    end

    for (steps_index, (ech, steps_at_ech)) in enumerate(get_operations(sequence_p))
        next_ech = (steps_index == length(sequence_p)) ? nothing : get_ech(sequence_p, steps_index+1)
        println("-"^50)
        delta = Dates.value(Dates.Minute(get_target_timepoints(context_p)[1]-ech))
        println("ECH : ", ech, " : M-", delta)
        println("-"^50)
        for step in steps_at_ech
            println(typeof(step), " à l'échéance ", ech)
            firmness = init_firmness(step, ech, next_ech,
                                    get_target_timepoints(context_p), context_p)
            result = run(step, ech, firmness,
                        get_target_timepoints(context_p),
                        context_p)

            if affects_market_schedule(step)
                update_market_schedule!(context_p, ech, result, firmness, step)
                #TODO : error if !verify
                verify_firmness(firmness, context_p.market_schedule,
                                excluded_ids=get_limitables_ids(context_p))
                PSCOPF.PSCOPFio.write(context_p, get_market_schedule(context_p), "market_")
            end

            if affects_tso_schedule(step)
                update_tso_schedule!(context_p, ech, result, firmness, step)
                #TODO : error if !verify
                verify_firmness(firmness, context_p.tso_schedule,
                                excluded_ids=get_limitables_ids(context_p))
                # PSCOPF.PSCOPFio.write(context_p, get_tso_schedule(context_p), "tso_")
            end

            if affects_tso_actions(step)
                update_tso_actions!(context_p.tso_actions,
                                    ech, result, firmness, context_p, step)
                # verify_firmness(firmness, context_p.tso_actions)
            end
        end
    end
end

struct SequenceGenerator <: AbstractDataGenerator
    network::Networks.Network #Not used for now (but potentially we can have specific operations at DMO horizons)
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
function generate_sequence(network::Networks.Network, target_timepoints::Vector{Dates.DateTime},
                            horizon_timepoints::Vector{Dates.DateTime}, management_mode::ManagementMode)
    generator = SequenceGenerator(network, target_timepoints, horizon_timepoints, management_mode)
    return launch(generator)
end


function gen_seq_mode1(seq_generator::SequenceGenerator)
    sequence = Sequence()
    fo_startpoint = seq_generator.target_timepoints[1] - get_fo_length(seq_generator.management_mode)

    for ech in seq_generator.horizon_timepoints
        if ech <  seq_generator.target_timepoints[1]
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
        if ech <  seq_generator.target_timepoints[1]
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
        if ech <  seq_generator.target_timepoints[1]
            if ech < fo_startpoint
                add_step!(sequence, EnergyMarket, ech)
                add_step!(sequence, TSOOutFO, ech)

            elseif ech == fo_startpoint
                add_step!(sequence, EnergyMarket, ech)
                add_step!(sequence, EnterFO, ech)
                add_step!(sequence, TSOAtFOBiLevel, ech)

            else
                #TODO : check if this is an EnergyMarket or BalanceMarket or another implem
                add_step!(sequence, EnergyMarket, ech)
            end
        end
    end

    add_step!(sequence, Assessment, seq_generator.horizon_timepoints[end])

    return sequence
end
