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
