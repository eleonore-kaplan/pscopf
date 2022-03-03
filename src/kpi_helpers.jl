using ..Networks

using Dates

function compute_prod(schedule, ts, scenario)
    prod = 0.
    for (gen_id, _) in schedule.generator_schedules
        gen_prod = safeget_prod_value(schedule, gen_id, ts, scenario)
        prod += gen_prod
    end
    return prod
end

function compute_eod(uncertainties_at_ech,
                    schedule,
                    network,
                    ts, scenario)
    prod = compute_prod(schedule, ts, scenario)
    load = compute_load(uncertainties_at_ech, network, ts, scenario)
    return (prod - load)
end
function compute_eod(uncertainties,
                    schedule,
                    network,
                    ech, ts, scenario)
    return compute_eod(get_uncertainties(uncertainties, ech),
                        schedule,
                        network,
                        ts, scenario)
end

function compute_flow(branch_id::String,
                uncertainties_at_ech::UncertaintiesAtEch,
                schedule::Schedule,
                network::Networks.Network,
                ts, scenario)
    flow = 0.
    for bus in Networks.get_buses(network)
        bus_id = Networks.get_id(bus)
        ptdf = Networks.get_ptdf(network, branch_id, bus_id)

        flow -= ptdf * get_uncertainties(uncertainties_at_ech, bus_id, ts, scenario)

        for generator in Networks.get_generators(bus)
            gen_id = Networks.get_id(generator)
            flow += ptdf * safeget_prod_value(schedule, gen_id, ts, scenario)
        end

    end
    return flow
end
function compute_flow(branch_id::String,
                uncertainties::Uncertainties,
                schedule::Schedule,
                network::Networks.Network,
                ech, ts, scenario)
    return compute_flow(branch_id,
                        get_uncertainties(uncertainties, ech),
                        schedule,
                        network,
                        ts, scenario)
end

function compute_flows(uncertainties_at_ech::UncertaintiesAtEch,
                        schedule::Schedule,
                        network::Networks.Network,
                        TS, scenarios)
    #branch, ts, s
    flows = SortedDict{Tuple{String, DateTime, String}, Float64}()
    for branch in Networks.get_branches(network)
        branch_id = Networks.get_id(branch)
        for ts in TS
            for scenario in scenarios
                val = compute_flow(branch_id,
                                uncertainties_at_ech,
                                schedule,
                                network,
                                ts, scenario)
                flows[branch_id, ts, scenario] = val
            end
        end
    end
    return flows
end

function compute_flows(context::PSCOPFContext,
                        schedule::Schedule)
    ech = schedule.decision_time
    return compute_flows(get_uncertainties(context, ech), schedule, get_network(context),
                        get_target_timepoints(context), get_scenarios(context))
end
