# ##############################################################
# ### optimisation modelling sets
# ##############################################################
# ECH, TS, S, NAMES = Workflow.get_ech_ts_s_name(launcher);
# BUSES =  Workflow.get_bus(launcher, NAMES);
# units_by_kind = Workflow.get_units_by_kind(launcher);
# units_by_bus =  Workflow.get_units_by_bus(launcher, BUSES);

# println("NAMES : ", NAMES);
# println("BUSES : ", BUSES);
# println("units_by_bus : ", units_by_bus);


# println("Number of scenario ", length(S));
# println("Number of time step is ", length(TS));
# println("ECH : ", ECH);
# K_IMPOSABLE = Workflow.K_IMPOSABLE;
# K_LIMITABLE = Workflow.K_LIMITABLE;

# # netloads = Dict([(bus, ts, s) => launcher.uncertainties[bus, s, ts, ech] for bus in BUSES, ts in TS, s in S]);
# eod_slack = Dict([(ts,s) => 0.0 for s in S, ts in TS]);
# factor = Dict([name => 1 for name in NAMES]);
# for bus in BUSES
#     factor[bus] = -1;
# end
# for ((name, s, ts, ech), v) in launcher.uncertainties
#     eod_slack[ts,  s] += factor[name] * v;
# end
# println("eod_slack is $eod_slack");


function worse_case(launcher::Launcher, ech::DateTime)
    #######################################################################
    # for a given ts, at a given ech, find the worst case within            
    # uncertainties for why the economical balance maximise the constraints
    #######################################################################
    # max rho
    # u in [lb, ub]
    # sum p = u 
    # p empilement économique
    # rho est la surcharge minimale

    is_on = Dict([kvp[1] => true for kvp in launcher.units])
    units_cost = Dict();
    # name->P-maxP-startCost-propCost
    for unit in launcher.units
        name = unit[1];
        minP = unit[2][1];
        maxP = unit[2][2];
        startCost = unit[2][3];
        propCost = unit[2][4];
        
    end

    units_by_kind = Workflow.get_units_by_kind(launcher);
    println(is_on);
end