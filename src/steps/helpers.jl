
function init_gratis_start(context::PSCOPFContext, ref_schedule_type::DeciderType)

    if is_market(ref_schedule_type)
        reference_schedule = get_market_schedule(context)
    elseif is_tso(ref_schedule_type)
        reference_schedule = get_tso_schedule(context)
    else
        @sprintf("Invalid reference schedule type config : %s.", ref_schedule_type)
        throw( error(msg) )
    end
    gratis_starts = get_starts(reference_schedule, get_generators_initial_state(context))

    return gratis_starts
end

function get_starts(commitments::SortedDict{Tuple{String, Dates.DateTime}, GeneratorState}, initial_state::SortedDict{String, GeneratorState})
    result = Set{Tuple{String,Dates.DateTime}}()

    preceding_id, preceding_state = nothing, nothing
    for ((gen_id,ts), gen_state) in commitments
        if ( isnothing(preceding_id) || gen_id!=preceding_id )
            preceding_state = initial_state[gen_id]
        end

        if get_start_value(preceding_state, gen_state) > 1e-09
            push!(result, (gen_id,ts) )
        end

        preceding_id = gen_id
        preceding_state = gen_state
    end

    return result
end

function get_starts(schedule::Schedule, initial_state::SortedDict{String, GeneratorState})
    commitments = SortedDict{Tuple{String, Dates.DateTime}, GeneratorState}()

    for (gen_id, gen_schedule) in schedule.generator_schedules
        if isempty(gen_schedule.commitment)
            continue
        end
        for (ts, current_state) in gen_schedule.commitment
            if !is_definitive(current_state)
                break #if current state is not definitive the following starts cannot be definitive
            else
                commitments[gen_id, ts] = get_value(current_state)
            end
        end
    end

    return get_starts(commitments, initial_state)
end
