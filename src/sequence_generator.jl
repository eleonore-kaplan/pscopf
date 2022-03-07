using Dates
using DataStructures
using Parameters
using Printf

using .Networks

###############################################
# Sequence
###############################################

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

###############################################
# Sequence Launch
###############################################

function init!(context_p::AbstractContext, sequence_p::Sequence, check_context::Bool)
    println("Lancement du mode : ", context_p.management_mode.name)
    println("Dates d'interet : ", get_target_timepoints(context_p))
    set_horizon_timepoints(context_p, get_timepoints(sequence_p))
    println("Dates d'échéances : ", get_horizon_timepoints(context_p))

    if check_context && !check(context_p)
        throw( error("Invalid context!") )
    end
end

function run_step!(context_p::AbstractContext, step::AbstractRunnable, ech, next_ech)
    println(typeof(step), " à l'échéance ", ech)
    firmness = compute_firmness(step, ech, next_ech,
                            get_target_timepoints(context_p), context_p)
    trace_firmness(firmness)
    result = run(step, ech, firmness,
                get_target_timepoints(context_p),
                context_p)

    if affects_market_schedule(step)
        println("update market schedule based on optimization results")
        old_market_schedule = deepcopy(get_market_schedule(context_p))
        update_market_schedule!(context_p, ech, result, firmness, step)
        println("Changes to the market schedule:")
        trace_delta_schedules(old_market_schedule, get_market_schedule(context_p))
        #TODO : error if !verify
        verify_firmness(firmness, context_p.market_schedule,
                        excluded_ids=get_limitables_ids(context_p))
        PSCOPF.PSCOPFio.write(context_p, get_market_schedule(context_p), "market_")
        update_market_flows!(context_p)
        trace_flows(get_market_flows(context_p), get_network(context_p))
    end

    if affects_tso_schedule(step)
        println("update TSO schedule based on optimization results")
        old_tso_schedule = deepcopy(get_tso_schedule(context_p))
        update_tso_schedule!(context_p, ech, result, firmness, step)
        println("Changes to the TSO schedule:")
        trace_delta_schedules(old_tso_schedule, get_tso_schedule(context_p))
        #TODO : error if !verify
        verify_firmness(firmness, context_p.tso_schedule,
                        excluded_ids=get_limitables_ids(context_p))
        # PSCOPF.PSCOPFio.write(context_p, get_tso_schedule(context_p), "tso_")
        # update_tso_flows!(context_p)
        # trace_flows(get_tso_flows(context_p), get_network(context_p))
    end

    if affects_tso_actions(step)
        println("update TSO actions based on optimization results")
        update_tso_actions!(context_p.tso_actions,
                            ech, result, firmness, context_p, step)
        # verify_firmness(firmness, context_p.tso_actions)
    end

    #TODO
    # println("Changes from market schedule to tso schedule:")
    # trace_delta_schedules(get_market_schedule(context_p), get_tso_schedule(context_p))
end

function run!(context_p::AbstractContext, sequence_p::Sequence;
                check_context=true)
    init!(context_p, sequence_p, check_context)

    for (steps_index, (ech, steps_at_ech)) in enumerate(get_operations(sequence_p))
        next_ech = (steps_index == length(sequence_p)) ? nothing : get_ech(sequence_p, steps_index+1)
        println("-"^50)
        delta = Dates.value(Dates.Minute(get_target_timepoints(context_p)[1]-ech))
        println("ECH : ", ech, " : M-", delta)
        println("-"^50)
        for step in steps_at_ech
            run_step!(context_p, step, ech, next_ech)
        end
    end
end

###############################################
# Sequence Generation
###############################################

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
    first_ts = seq_generator.target_timepoints[1]
    fo_startpoint = first_ts - get_fo_length(seq_generator.management_mode)

    for ech in seq_generator.horizon_timepoints
        if ech <  first_ts
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
        elseif first_ts < ech
            msg = @sprintf(("Error when generating sequence: ech (%s) is after target timepoint (%s)."),
                            ech, first_ts)
            throw( error(msg) )
        end
    end

    add_step!(sequence, Assessment, seq_generator.horizon_timepoints[end])

    return sequence
end


function gen_seq_mode2(seq_generator::SequenceGenerator)
    sequence = Sequence()
    first_ts = seq_generator.target_timepoints[1]
    fo_startpoint = first_ts - get_fo_length(seq_generator.management_mode)

    for ech in seq_generator.horizon_timepoints
        if ech <  first_ts
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
        elseif first_ts < ech
            msg = @sprintf(("Error when generating sequence: ech (%s) is after target timepoint (%s)."),
                            ech, first_ts)
            throw( error(msg) )
        end
    end

    add_step!(sequence, Assessment, seq_generator.horizon_timepoints[end])

    return sequence
end


function gen_seq_mode3(seq_generator::SequenceGenerator)
    sequence = Sequence()
    first_ts = seq_generator.target_timepoints[1]
    fo_startpoint = first_ts - get_fo_length(seq_generator.management_mode)

    for ech in seq_generator.horizon_timepoints
        if ech <  first_ts
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
        elseif first_ts < ech
            msg = @sprintf(("Error when generating sequence: ech (%s) is after target timepoint (%s)."),
                            ech, first_ts)
            throw( error(msg) )
        end
    end

    add_step!(sequence, Assessment, seq_generator.horizon_timepoints[end])

    return sequence
end


##################################
# Trace
##################################

function trace_firmness(firmness::Firmness)
    for (gen_id,_) in firmness.commitment
        TS_to_decide_for = Vector{DateTime}()
        for (ts, decision_firmness) in firmness.commitment[gen_id]
            if decision_firmness == TO_DECIDE
                push!(TS_to_decide_for, ts)
            end
        end
        if !isempty(TS_to_decide_for)
            @printf("Firm commitment decision must be issued for generator %s for timesteps %s\n",
                    gen_id, TS_to_decide_for)
        end
    end

    for (gen_id,_) in firmness.power_level
        TS_to_decide_for = Vector{DateTime}()
        for (ts, decision_firmness) in firmness.power_level[gen_id]
            if decision_firmness == TO_DECIDE
                push!(TS_to_decide_for, ts)
            end
        end
        if !isempty(TS_to_decide_for)
            @printf("Firm production level decision must be issued for generator %s at timesteps %s\n",
                    gen_id, TS_to_decide_for)
        end
    end
end

function trace_flows(flows::SortedDict{Tuple{String, DateTime, String}, Float64},
                    network::Networks.Network)
    for ((branch_id, ts, scenario), flow_val) in flows
        branch = Networks.safeget_branch(network, branch_id)
        limit = Networks.get_limit(branch)
        if abs(flow_val) > limit
            @printf("Flow value %f for branch %s, at timestep %s and scenario %s exceeds branch limit (%f)\n",
                    flow_val, branch_id, ts, scenario, limit)
        end
    end
end

function trace_delta_schedules(old_schedule::Schedule, new_schedule::Schedule)
    println("Commitment updates : (only showing firm decisions changes)")
    trace_delta_schedule_component(old_schedule, new_schedule, get_commitment_sub_schedule, false)
    println("Production updates : (only showing firm decisions changes)")
    trace_delta_schedule_component(old_schedule, new_schedule, get_production_sub_schedule, false)
end

function trace_delta_schedule_component(old_schedule::Schedule, new_schedule::Schedule,
                                        component_accessor::Function,
                                        print_non_firm_changes=false)
    for (gen_id, new_gen_schedule) in new_schedule.generator_schedules
        @assert(haskey(old_schedule.generator_schedules, gen_id))
        old_schedule_component = component_accessor(old_schedule, gen_id)
        new_schedule_component = component_accessor(new_schedule, gen_id)

        for (ts, new_uncertain) in new_schedule_component
            @assert(haskey(old_schedule_component, ts))
            old_uncertain = old_schedule_component[ts]
            if is_definitive(new_uncertain) && is_definitive(old_uncertain)
                if get_value(new_uncertain) != get_value(old_uncertain)
                    @printf("firm value for generator %s at timestep %s changed from %s to %s\n",
                            gen_id, ts, get_value(old_uncertain), get_value(new_uncertain))
                end
            elseif is_definitive(new_uncertain) && !is_definitive(old_uncertain)
                @printf("A firm value for generator %s at timestep %s set to %s\n",
                        gen_id, ts, get_value(new_uncertain))
            elseif !is_definitive(new_uncertain) && is_definitive(old_uncertain)
                @printf("the firm value for generator %s at timestep %s \
                        is changed from %s to a by scenario value:\n",
                        gen_id, ts, get_value(new_uncertain))
                println(new_uncertain.anticipated_value)
            elseif print_non_firm_changes
                for scenario in get_scenarios(new_uncertain)
                    old_val = get_value(old_uncertain, scenario)
                    new_val = get_value(new_uncertain, scenario)
                    if ( (ismissing(new_val) != ismissing(old_val))
                        || ( !ismissing(old_val) && !ismissing(new_val) && (new_val != old_val) )
                        )
                        @printf("gen_id=%s, ts=%s, scenario=%s \
                                old_value=%s, new_value=%s\n",
                                gen_id, ts, scenario, old_val, new_val)
                    end
                end
            end
        end
    end
end