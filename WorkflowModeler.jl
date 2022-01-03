

export get_ts_s;
export get_units_by_kind;
export get_units_by_bus;
export get_bus;
export sc_opf;
export print_nz;

try
    using Xpress;
    global OPTIMIZER = Xpress.Optimizer
catch e_xpress
    if isa(e_xpress, ArgumentError)
        try
            using CPLEX;
            global OPTIMIZER = CPLEX.Optimizer
        catch e_cplex
            if isa(e_cplex, ArgumentError)
                using Cbc;
                global OPTIMIZER = Cbc.Optimizer
            else
                throw(e_cplex)
            end
        end
    else
        throw(e_xpress)
    end
end
println("optimizer: ", OPTIMIZER)

using Dates
import Statistics

"""
    redirect_to_file(f::Function, file_p::String, mode_p="w")

Execute function `f` while redirecting C and Julia level stdout to the file file_p.
Note that `file_p` is open in write mode by default.

# Arguments
- `f::Function` : the function to execute
- `file_p::String` : name of the file to print to
- `mode_p` : open mode of the file (defaults to "w")
"""
function redirect_to_file(f::Function, file_p::String, mode_p="w")
    open(file_p, mode_p) do file_l
        Base.Libc.flush_cstdio()
        redirect_stdout(file_l) do
            f()
            Base.Libc.flush_cstdio()
        end
    end
end

function get_bus(launcher::Launcher, names::Set{String})
    result = Set{String}();
    for name in names
        if !haskey(launcher.gen_type_bus, name)
            push!(result, name);
        end
    end
    return result;
end

function get_sorted_ech(launcher::Launcher)
    ech_set = Set{DateTime}();
    for uncertainty in launcher.uncertainties
        ech = uncertainty[1][U_ECH];
        push!(ech_set, ech);
    end
    return sort(collect(ech_set));
end

function get_ts_s_name(launcher::Launcher, ech_p::DateTime)
    ts_set = Set{DateTime}();
    s_set =  Set{String}();
    name_set = Set{String}();
    for uncertainty in launcher.uncertainties
        ech_l = uncertainty[1][U_ECH];
        if ech_l == ech_p
            ts = uncertainty[1][U_H];
            s = uncertainty[1][U_SCENARIO];
            name = uncertainty[1][U_NAME];
            push!(ts_set, ts);
            push!(s_set, s);
            push!(name_set, name);
        end
    end
    return sort(collect(ts_set)), sort(collect(s_set)), name_set;
end

function get_ech_ts_s_name(launcher::Launcher)
    ech_set = Set{DateTime}();
    ts_set = Set{DateTime}();
    s_set =  Set{String}();
    name_set = Set{String}();
    for uncertainty in launcher.uncertainties
        ts = uncertainty[1][U_H];
        ech = uncertainty[1][U_ECH];
        s = uncertainty[1][U_SCENARIO];
        name = uncertainty[1][U_NAME];
        push!(ech_set, ech);
        push!(ts_set, ts);
        push!(s_set, s);
        push!(name_set, name);
    end
    return sort(collect(ech_set)), sort(collect(ts_set)), sort(collect(s_set)), name_set;
end

function get_units_by_kind(launcher::Launcher)
    result = Dict{String,Dict{String,String}}();
    result[K_LIMITABLE] = Dict{String,String}();
    result[K_IMPOSABLE] = Dict{String,String}();
    for gen in launcher.gen_type_bus
        kind = gen[2][1];
        push!(result[kind],  gen[1] => gen[2][2]);
    end 
    return result;
end

function get_units_by_bus(launcher::Launcher, buses::Set{String})
    result = Dict{String,Dict{String,Vector{String}}}();
    result[K_LIMITABLE] = Dict{String,Vector{String}}([bus => Vector{String}() for bus in buses]);
    result[K_IMPOSABLE] = Dict{String,Vector{String}}([bus => Vector{String}() for bus in buses]);
    for gen in launcher.gen_type_bus
        name = gen[1];
        kind = gen[2][1];
        bus  = gen[2][2];
        tmp = get(result[kind], bus, Vector{String}())
        push!(tmp, name);
        result[kind][bus] = tmp;
    end 
    return result;
end

function get_branches(launcher_p::Launcher)
    return get_branches(launcher_p.ptdf)
end
function get_branches(ptdf_data_p::Dict{Tuple{String, String}, Float64})
    return unique([branch_i for ((branch_i,_),_) in ptdf_data_p])
end

function print_config(launcher_p::Launcher)
    println("NO_IMPOSABLE   : ", launcher_p.NO_IMPOSABLE);
    println("NO_LIMITABLE   : ", launcher_p.NO_LIMITABLE);
    println("NO_LIMITATION  : ", launcher_p.NO_LIMITATION);
    println("NO_DMO         : ", launcher_p.NO_DMO);
    println("NO_EOD_SLACK   : ", launcher_p.NO_EOD_SLACK);
    println("NO_BRANCH_SLACK: ", launcher_p.NO_BRANCH_SLACK);
end

function add_limitable!(launcher::Launcher, ech::DateTime, model, units_by_kind, TS, S)
    p_lim = Dict{Tuple{String,DateTime},VariableRef}();
    is_limited = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_enr = Dict{Tuple{String,DateTime,String},VariableRef}();
    is_limited_x_p_lim = Dict{Tuple{String,DateTime,String},VariableRef}();
    c_lim = Dict{Tuple{String,DateTime,String},VariableRef}();
    if ! launcher.NO_LIMITABLE
        for kvp in units_by_kind[K_LIMITABLE], ts in TS
            gen = kvp[1];
            pLimMax = 0;
            p_lim[gen, ts] =  @variable(model, base_name = @sprintf("p_lim[%s,%s]", gen, ts), lower_bound = 0);
            for s in S
                pLimMax = max(pLimMax, launcher.uncertainties[gen, s, ts, ech]);
            end
            for s in S
                name =  @sprintf("is_limited[%s,%s,%s]", gen, ts, s);
                is_limited[gen, ts, s] = @variable(model, base_name = name, binary = true);

                name =  @sprintf("is_limited_x_p_lim[%s,%s,%s]", gen, ts, s);
                is_limited_x_p_lim[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0);

                name =  @sprintf("c_lim[%s,%s,%s]", gen, ts, s);
                c_lim[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0);

                @constraint(model, is_limited_x_p_lim[gen, ts, s] <= p_lim[gen, ts]);
                @constraint(model, is_limited_x_p_lim[gen, ts, s] <= is_limited[gen, ts, s] * pLimMax);
                @constraint(model, is_limited_x_p_lim[gen, ts, s] + pLimMax * (1 - is_limited[gen, ts, s]) - p_lim[gen, ts] >= 0);

                p0 = launcher.uncertainties[gen, s, ts, ech];
                name =  @sprintf("p_enr[%s,%s,%s]", gen, ts, s);
                p_enr[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0, upper_bound = p0);
                @constraint(model, p_enr[gen, ts, s] == (1 - is_limited[gen, ts, s]) * p0 + is_limited_x_p_lim[gen, ts, s]);
                @constraint(model, p_enr[gen, ts, s] <= p_lim[gen, ts]);

                @constraint(model, c_lim[gen, ts, s] >= p0 - p_lim[gen, ts]);

                if launcher.NO_LIMITATION
                    @constraint(model, is_limited[gen, ts, s] == 0);
                end
            end
        end
    end
    return Workflow.LimitableModeler(p_lim, is_limited, p_enr, is_limited_x_p_lim, c_lim);
    # return p_lim, is_limited, is_limited_x_p_lim, c_lim;
end

"""
    is_already_fixed(ech_p, ts_p, dmo_p)

returns true if the production level for time step ts_p for a unit having a delay equal to dmo_p can no longer be changed by the time ech_p

# Arguments
- `ech_p::DateTime` : is the time we decide (the optimisation launch time)
- `ts_p::DateTime` : is the production time
- `dmo_p` : is the necessary time (in seconds) for the unit to start producing. Should be losslessly convertible to Int64.
"""
function is_already_fixed(ech_p::DateTime, ts_p::DateTime, dmo_p)
    return (ts_p - Dates.Second(dmo_p)) < ech_p
end

"""
    is_to_decide(ech_p, ts_p, dmo_p)

returns true if the production level for time step ts_p for a unit having a delay equal to dmo_p must definately be decided at time ech_p

# Arguments
- `ech_p::DateTime` : is the time we decide (the optimisation launch time)
- `ts_p::DateTime` : is the production time
- `dmo_p` : is the necessary time (in seconds) for the unit to start producing. Should be losslessly convertible to Int64.
"""
function is_to_decide(ech_p::DateTime, ts_p::DateTime, dmo_p)
    return (ts_p - Dates.Second(dmo_p)) == ech_p
end

function add_imposable!(launcher::Launcher, ech, model,  units_by_kind, TS, S)
    p_imposable = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_is_imp = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_is_imp_and_on = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_imp = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_start = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_on = Dict{Tuple{String,DateTime,String},VariableRef}();
    c_imp_pos  = Dict{Tuple{String,DateTime,String},VariableRef}();
    c_imp_neg   = Dict{Tuple{String,DateTime,String},VariableRef}();

    if ! launcher.NO_IMPOSABLE
        for kvp in units_by_kind[K_IMPOSABLE]
            gen = kvp[1];
            pMin = launcher.units[gen][1];
            pMax = launcher.units[gen][2];
            dmo_l = launcher.units[gen][5];

            for ts in TS
                prev0 = launcher.previsions[gen, ts, ech];

                if (!launcher.NO_DMO) && (is_already_fixed(ech, ts, dmo_l))
                    @printf("production level of unit %s is already fixed to %.3f for timestep %s.\n", gen, prev0, ts)
                elseif (launcher.NO_DMO) || (is_to_decide(ech, ts, dmo_l))
                    @printf("unit %s must be fixed for timestep %s.\n", gen, ts)
                else
                    @printf("still early to fix unit %s for timestep %s.\n", gen, ts)
                end

                for (s_index_l, s) in enumerate(S)
                    name =  @sprintf("p_imp[%s,%s,%s]", gen, ts, s);
                    p_imp[gen, ts, s] = @variable(model, base_name = name);

                    name =  @sprintf("p_is_imp[%s,%s,%s]", gen, ts, s);
                    p_is_imp[gen, ts, s] = @variable(model, base_name = name, binary = true);

                    name =  @sprintf("p_start[%s,%s,%s]", gen, ts, s);
                    p_start[gen, ts, s] = @variable(model, base_name = name, binary = true);

                    name =  @sprintf("p_on[%s,%s,%s]", gen, ts, s);
                    p_on[gen, ts, s] = @variable(model, base_name = name, binary = true);

                    name =  @sprintf("p_is_imp_and_on[%s,%s,%s]", gen, ts, s);
                    p_is_imp_and_on[gen, ts, s] = @variable(model, base_name = name, binary = true);

                    p0 = launcher.uncertainties[gen, s, ts, ech];
                    name =  @sprintf("p_imposable[%s,%s,%s]", gen, ts, s);
                    p_imposable[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0);

                    name =  @sprintf("c_imp_pos[%s,%s,%s]", gen, ts, s);
                    c_imp_pos[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0);

                    name =  @sprintf("c_imp_neg[%s,%s,%s]", gen, ts, s);
                    c_imp_neg[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0);

                    @constraint(model, p_imposable[gen, ts, s] == p0 + c_imp_pos[gen, ts, s] - c_imp_neg[gen, ts, s]);

                    @constraint(model, p_imposable[gen, ts, s] == (1 - p_is_imp[gen, ts, s]) * p0 + p_imp[gen, ts, s]);
                    @constraint(model, p_imp[gen, ts, s] <= pMax * p_is_imp_and_on[gen, ts, s]);
                    @constraint(model, p_imp[gen, ts, s] >= pMin * p_is_imp_and_on[gen, ts, s]);

                    @constraint(model, p_is_imp_and_on[gen, ts, s] <= p_is_imp[gen, ts, s]);
                    @constraint(model, p_is_imp_and_on[gen, ts, s] <= p_on[gen, ts, s]);
                    @constraint(model, 1 + p_is_imp_and_on[gen, ts, s] >= p_on[gen, ts, s] + p_is_imp[gen, ts, s]);

                    if (!launcher.NO_DMO) && (is_already_fixed(ech, ts, dmo_l))
                    # it is too late to change the production level
                        @constraint(model, p_imposable[gen, ts, s] == prev0);
                    elseif (launcher.NO_DMO) || (is_to_decide(ech, ts, dmo_l))
                    # must decide now on production level
                        if s_index_l > 1
                            s_other_l = S[s_index_l-1]
                            @constraint(model, p_imposable[gen, ts, s] == p_imposable[gen, ts, s_other_l]);
                        end
                    #else no special constraints for now. TODO : limit the decision window (power levels variation between the scenarios)
                    end
                end
            end

            for s in S
                for (i,ts) in enumerate(TS)
                    if i > 1
                        ts_1 = TS[i - 1];
                        @constraint(model, p_start[gen, ts, s] <= p_on[gen, ts, s]);
                        @constraint(model, p_start[gen, ts, s] <= 1 - p_on[gen, ts_1, s]);
                        @constraint(model, p_start[gen, ts, s] >= p_on[gen, ts, s] - p_on[gen, ts_1, s]);
                    else
                        prev0 = launcher.previsions[gen, ts, ech];
                        @printf("%s %s is at %f\n", gen, ts, prev0)
                        if abs(prev0) < 1
                            @constraint(model, p_start[gen, ts, s] == p_on[gen, ts, s]);
                        end
                    end
                end
            end
        end
    end
    return Workflow.ImposableModeler(p_imposable, p_is_imp, p_imp, p_is_imp_and_on, p_start, p_on, c_imp_pos, c_imp_neg);
end

#FIXME : add_slack!(::ModelContainer, ::Launcher)
#FIXME : add_slack!(::ModelContainer, ::Launcher, branches, TS, S)
function add_slack!(launcher, ech, model, TS, S)
    #ts, s
    p_extra_res_pos = Dict{Tuple{DateTime,String},VariableRef}();
    p_extra_res_neg = Dict{Tuple{DateTime,String},VariableRef}();
    #branch, ts, s
    v_extra_flow_pos = Dict{Tuple{String,DateTime,String},VariableRef}();
    v_extra_flow_neg = Dict{Tuple{String,DateTime,String},VariableRef}();

    if ! launcher.NO_EOD_SLACK
        for ts in TS, s in S
            name =  @sprintf("p_extra_res_pos[%s,%s]", ts, s);
            p_extra_res_pos[ts, s] = @variable(model, base_name = name, lower_bound = 0);
            name =  @sprintf("p_extra_res_neg[%s,%s]", ts, s);
            p_extra_res_neg[ts, s] = @variable(model, base_name = name, lower_bound = 0);
        end
    end

    if ! launcher.NO_BRANCH_SLACK
        for branch in get_branches(launcher), ts in TS, s in S
            name =  @sprintf("v_extra_flow_pos[%s,%s,%s]", branch, ts, s);
            v_extra_flow_pos[branch, ts, s] = @variable(model, base_name = name, lower_bound = 0);
            name =  @sprintf("v_extra_flow_neg[%s,%s,%s]", branch, ts, s);
            v_extra_flow_neg[branch, ts, s] = @variable(model, base_name = name, lower_bound = 0);
        end
    end

    return Workflow.SlackModeler(p_extra_res_pos, p_extra_res_neg, v_extra_flow_pos, v_extra_flow_neg);
end

function add_eod_constraint!(launcher::Launcher, ech, model, units_by_bus, TS, S, BUSES,
                            v_lim::Workflow.LimitableModeler, v_imp::Workflow.ImposableModeler, v_res::Workflow.ReserveModeler, v_slack::Workflow.SlackModeler,
                            netloads )
    eod_expr = Dict([(ts, s) => AffExpr(0) for ts in TS, s in S]);
    for ts in TS, s in S
        for bus in BUSES
            if ! launcher.NO_IMPOSABLE
                for gen in units_by_bus[K_IMPOSABLE][bus]
                    eod_expr[ts, s] += v_imp.p_imposable[gen, ts, s];
                end
            end
            if ! launcher.NO_LIMITABLE
                for gen in units_by_bus[K_LIMITABLE][bus]
                    p0 = launcher.uncertainties[gen, s, ts, ech];
                    # println(gen, " ", ts, " ", s, " ", p0);
                    #eod_expr[ts, s] +=  ((1 -  v_lim.is_limited[gen, ts, s]) * p0 + v_lim.is_limited_x_p_lim[gen, ts, s]);
                    eod_expr[ts, s] += v_lim.p_enr[gen,ts,s]
                end
            end
        end
    end
    for ts in TS, s in S
        eod_expr[ts, s] += v_res.p_res_pos[ts, s];
        eod_expr[ts, s] -= v_res.p_res_neg[ts, s];
    end

    for ((ts_l,s_l), var_l) in v_slack.p_extra_res_pos
        eod_expr[ts_l, s_l] += var_l;
    end
    for ((ts_l,s_l), var_l) in v_slack.p_extra_res_neg
        eod_expr[ts_l, s_l] -= var_l;
    end

    # println(launcher.uncertainties)
    for ts in TS, s in S
        load = 0;
        for bus in BUSES
            load += netloads[bus, ts, s];
        end
        @constraint(model, eod_expr[ts, s] == load);
    end
end

function add_reserve!(launcher::Launcher, ech, model, TS, S, p_res_min, p_res_max)
    if p_res_min > 0
        msg_l = @sprintf("Illegal value (%f) for argument p_res_min : a non-positive value is required.", p_res_min)
        throw(ArgumentError(msg_l))
    end

    p_res_pos = Dict{Tuple{DateTime,String},VariableRef}();
    p_res_neg = Dict{Tuple{DateTime,String},VariableRef}();
    for ts in TS, s in S
        name =  @sprintf("p_res_pos[%s,%s]", ts, s);
        p_res_pos[ts, s] = @variable(model, base_name = name, lower_bound = 0, upper_bound = p_res_max);
        name =  @sprintf("p_res_neg[%s,%s]", ts, s);
        p_res_neg[ts, s] = @variable(model, base_name = name, lower_bound = 0, upper_bound = -p_res_min);
    end
    return Workflow.ReserveModeler(p_res_pos, p_res_neg);
end

"""
    next_pow10(input_p::Number)

returns the next power of ten

# Arguments
- `input_p` : The input number

# Examples
```jldoctest
julia> next_pow10(5)
10

julia> next_pow10(5.5)
10

julia> next_pow10(10)
100

julia> next_pow10(62.005)
100
```
"""
function next_pow10(input_p::Number)
    return 10^length(string(floor(Int, input_p)))
end

function get_max_miniwork_cost(launcher_p::Launcher)
    max_cost_l = 0.
    for (_,gen_data_l) in launcher_p.units
        min_prod_level_l = max(1., gen_data_l[1])
        start_cost_l = gen_data_l[3]
        prop_cost_l = gen_data_l[4]
        work_cost_l = start_cost_l + min_prod_level_l * prop_cost_l
        max_cost_l = max(max_cost_l, work_cost_l)
    end
    return max_cost_l
end
function get_max_mini_p(launcher_p::Launcher)
    max_min_p_l = 0.
    for (_,gen_data_l) in launcher_p.units
        min_prod_level_l = gen_data_l[1]
        max_min_p_l = max(max_min_p_l, min_prod_level_l)
    end
    return max_min_p_l
end

function get_cut_production_cost(launcher_p::Launcher)
    cost_l = get_max_miniwork_cost(launcher_p)
    return next_pow10(cost_l)
end
function get_cut_consumption_cost(launcher_p::Launcher)
    miniwork_cost_l = get_max_miniwork_cost(launcher_p)
    max_mini_p_l = max(1., get_max_mini_p(launcher_p))
    cost_l = miniwork_cost_l + max_mini_p_l * get_cut_production_cost(launcher_p)
    return next_pow10(cost_l)
end
function get_branch_capa_cost(launcher_p::Launcher)
    return next_pow10(get_cut_consumption_cost(launcher_p))
end

function add_obj!(launcher::Launcher, model, TS, S,
                v_lim::Workflow.LimitableModeler, v_imp::Workflow.ImposableModeler, v_res::Workflow.ReserveModeler,
                v_slack::Workflow.SlackModeler)
    sum_obj_l = AffExpr(0);

    penalties_obj_l = AffExpr(0);
    lim_cost_obj_l = AffExpr(0);
    imp_prop_cost_obj_l = AffExpr(0);
    imp_starting_cost_obj_l = AffExpr(0);
    cut_production_obj_l = AffExpr(0);
    cut_consumption_obj_l = AffExpr(0);
    branch_capacity_obj_l = AffExpr(0);

    w_scenario_l = 1 / length(S);

    for x in v_lim.c_lim
        # implicit looping on #ts, #s and gen
        gen = x[1][1];
        cProp = launcher.units[gen][4];
        lim_cost_obj_l += w_scenario_l * cProp * x[2];
    end
    if length(v_lim.is_limited) > 0
        penalties_obj_l += sum(1e-4 * x[2] for x in v_lim.is_limited);
    end

    for x in v_imp.p_start
        gen = x[1][1];
        cStart = launcher.units[gen][3];
        imp_starting_cost_obj_l += w_scenario_l * cStart * x[2];
    end
    for x in v_imp.c_imp_pos
        gen = x[1][1];
        cProp = launcher.units[gen][4];
        imp_prop_cost_obj_l += w_scenario_l * cProp * x[2];
    end
    for x in v_imp.c_imp_neg
        gen = x[1][1];
        cProp = launcher.units[gen][4];
        imp_prop_cost_obj_l += w_scenario_l * cProp * x[2];
    end

    for x in v_res.p_res_pos
        penalties_obj_l += (1e-3)*w_scenario_l*x[2];
    end
    for x in v_res.p_res_neg
        penalties_obj_l += (1e-3)*w_scenario_l* x[2];
    end

    w_cut_prod_l = get_cut_production_cost(launcher)
    for x in v_slack.p_extra_res_neg
        cut_production_obj_l += w_cut_prod_l * x[2]
    end

    w_cut_consumption_l = get_cut_consumption_cost(launcher)
    for x in v_slack.p_extra_res_pos
        cut_consumption_obj_l += w_cut_consumption_l * x[2]
    end

    w_branch_capa_l = get_branch_capa_cost(launcher)
    for x in v_slack.v_extra_flow_neg
        branch_capacity_obj_l += w_branch_capa_l * x[2]
    end
    for x in v_slack.v_extra_flow_pos
        branch_capacity_obj_l += w_branch_capa_l * x[2]
    end

    sum_obj_l += penalties_obj_l
    sum_obj_l += lim_cost_obj_l
    sum_obj_l += imp_prop_cost_obj_l
    sum_obj_l += imp_starting_cost_obj_l
    sum_obj_l += cut_production_obj_l
    sum_obj_l += cut_consumption_obj_l
    sum_obj_l += branch_capacity_obj_l

    obj_l = @objective(model, Min, sum_obj_l);

    return Workflow.ObjectiveModeler( penalties_obj_l, lim_cost_obj_l, imp_prop_cost_obj_l, imp_starting_cost_obj_l,
                                    cut_production_obj_l, cut_consumption_obj_l, branch_capacity_obj_l,
                                    obj_l)
end

function add_flow!(launcher::Workflow.Launcher, model, TS, S,  units_by_bus,
                v_lim::Workflow.LimitableModeler, v_imp::Workflow.ImposableModeler, v_slack::Workflow.SlackModeler,
                netloads)
    v_flow = Dict{Tuple{String,DateTime,String},VariableRef}();

    ptdf_by_branch = Dict{String,Dict{String,Float64}}() ;
    for ptdf in launcher.ptdf
        branch, bus = ptdf[1]
        if ! haskey(ptdf_by_branch, branch)
            ptdf_by_branch[branch] = Dict{String,Float64}();
        end
        ptdf_by_branch[branch][bus] = ptdf[2];
    end
    println("ptdf_by_branch : ", ptdf_by_branch);
    for ts in TS, s in S
        for limit in launcher.limits
            branch = limit[1];
            v = limit[2]
            name =  @sprintf("p_flow[%s, %s,%s]", branch, ts, s);
            v_flow[branch, ts, s] = @variable(model, base_name = name, lower_bound = -v, upper_bound = v);
            f_ref = 0;
            xpr = AffExpr(0);
            for (bus, ptdf) in ptdf_by_branch[branch]
                f_ref -= ptdf * netloads[bus, ts, s];
                if ! launcher.NO_IMPOSABLE
                    for gen in units_by_bus[K_IMPOSABLE][bus]
                        xpr += v_imp.p_imposable[gen, ts, s] * ptdf;
                    end
                end
                if ! launcher.NO_LIMITABLE
                    for gen in units_by_bus[K_LIMITABLE][bus]
                        xpr += v_lim.p_enr[gen, ts, s] * ptdf;
                    end
                end
            end
            pos_slack_l = get(v_slack.v_extra_flow_pos, (branch, ts, s), 0.)
            neg_slack_l = get(v_slack.v_extra_flow_neg, (branch, ts, s), 0.)
            @constraint(model, v_flow[branch, ts, s] + pos_slack_l - neg_slack_l == f_ref + xpr);
        end
    end
    return v_flow;
end


"""
    sc_opf(launcher::Launcher, ech::DateTime, p_res_min, p_res_max)

Launch a single optimization iteration

# Arguments
- `launcher::Launcher` : the optimization launcher containing the necessary data
- `ech_p::DateTime` : the optimization launch time
- `p_res_min` : The minimum allowed reserve level
- `p_res_max` : The maximum allowed reserve level
"""
function sc_opf(launcher::Launcher, ech::DateTime, p_res_min, p_res_max)
    ##############################################################
    ### optimisation modelling sets
    ##############################################################
    TS, S, NAMES = Workflow.get_ts_s_name(launcher, ech);
    BUSES =  Workflow.get_bus(launcher, NAMES);
    units_by_kind = Workflow.get_units_by_kind(launcher);
    units_by_bus =  Workflow.get_units_by_bus(launcher, BUSES);

    println("NAMES : ", NAMES);
    println("BUSES : ", BUSES);
    println("units_by_bus : ", units_by_bus);
    println("TS             : ", TS);
    println("S              : ", S);

    println("ech: ", ech);
    println("Number of scenario ", length(S));
    println("Number of time step is ", length(TS));
    K_IMPOSABLE = Workflow.K_IMPOSABLE;
    K_LIMITABLE = Workflow.K_LIMITABLE;

    netloads = Dict([(bus, ts, s) => launcher.uncertainties[bus, s, ts, ech] for bus in BUSES, ts in TS, s in S]);
    eod_slack = Dict([(ts,s) => 0.0 for s in S, ts in TS]);
    factor = Dict([name => 1 for name in NAMES]);
    for bus in BUSES
        factor[bus] = -1;
    end
    for ((name, s, ts, ech), v) in launcher.uncertainties
        eod_slack[ts,  s] += factor[name] * v;
    end
    println("eod_slack is $eod_slack");
    ##############################################################
    # to be in a function ...
    ##############################################################

    model_container_l = Workflow.ModelContainer()
    model = model_container_l.model;

    v_lim = add_limitable!(launcher, ech, model, units_by_kind, TS, S);
    model_container_l.limitable_modeler = v_lim
    p_lim = v_lim.p_lim;
    is_limited = v_lim.is_limited;
    is_limited_x_p_lim = v_lim.is_limited_x_p_lim;
    c_lim = v_lim.c_lim;

    v_imp = add_imposable!(launcher, ech, model, units_by_kind, TS, S);
    model_container_l.imposable_modeler = v_imp
    p_imposable = v_imp.p_imposable;
    p_is_imp = v_imp.p_is_imp;
    p_imp = v_imp.p_imp;
    p_start = v_imp.p_start;
    p_on = v_imp.p_on;

    v_res = add_reserve!(launcher, ech, model, TS, S, p_res_min, p_res_max);
    model_container_l.reserve_modeler = v_res

    v_slack = add_slack!(launcher, ech, model, TS, S)
    model_container_l.slack_modeler = v_slack

    add_eod_constraint!(launcher, ech, model, units_by_bus, TS, S, BUSES, v_lim, v_imp, v_res, v_slack, netloads);

    v_flow = add_flow!(launcher, model, TS, S, units_by_bus,  v_lim, v_imp, v_slack, netloads);
    model_container_l.v_flow = v_flow

    obj_l = add_obj!(launcher,  model, TS, S, v_lim, v_imp, v_res, v_slack);
    model_container_l.objective_modeler = obj_l

    # println(model)
    set_optimizer(model, OPTIMIZER);
    model_file_l = joinpath(launcher.dirpath, @sprintf("model_%s.lp", ech))
    write_to_file(model, model_file_l)

    println("Call optimizer")
    solver_logfile_l = joinpath(launcher.dirpath, @sprintf("model_%s.log", ech))
    redirect_to_file(solver_logfile_l) do
        optimize!(model)
    end

    if termination_status(model) == INFEASIBLE
        error("Model is infeasible")
    end
    @printf("Termination status : %s\n", termination_status(model))
    @printf("Objective value : %f\n", objective_value(model))

    # print_nz(p_imposable);
    # print_nz(p_is_imp);
    # print_nz(p_start);
    # print_nz(p_on);
    # print_nz(is_limited);

    @printf("%30s[%s,%s] %4s %10s %10s %10s\n", "gen", "ts", "s", "b_enr", "p_enr", "p_lim_enr", "p0");
    if ! launcher.NO_LIMITABLE
        # println(launcher.uncertainties)
        for bus in BUSES, ts in TS, s in S, gen in units_by_bus[K_LIMITABLE][bus]
            b_lim = value(is_limited[gen, ts, s]);
            if b_lim > 0.5
                @printf("%10s[%s,%s] LIMITED\n", gen, ts, s);
            end
            p0 = launcher.uncertainties[gen, s, ts, ech];
            b_enr = value(is_limited[gen, ts, s]);
            p_enr = value((1 - is_limited[gen, ts, s]) * p0 + is_limited_x_p_lim[gen, ts, s]);
            p_lim_enr = value(p_lim[gen, ts]);
            # println(value(is_limited_x_p_lim[gen, ts, s]) - b_enr * p_lim_enr)
            if b_enr > 0.5
                @printf("%10s[%s,%s] %4d %10.3f %10.3f %10.3f\n", gen, ts, s, b_enr, p_enr, p_lim_enr, p0);
            end
            # println(gen, " : ", value((1 - is_limited[gen, ts, s]) * p0 + is_limited_x_p_lim[gen, ts, s]))
        end
    end
    if ! launcher.NO_IMPOSABLE
        # println(launcher.uncertainties)
        for bus in BUSES, ts in TS, s in S, gen in units_by_bus[K_IMPOSABLE][bus]
            b_start = value(p_start[gen, ts, s]);
            b_imp = value(p_is_imp[gen, ts, s]);
            if b_imp > 0.5
                @printf("%10s[%s, %s] IMPOSED\n", gen, ts, s);
            end
            if b_start > 0.5
                @printf("%10s[%s, %s] STARTED\n", gen, ts, s);
            end
            b_on = value(p_on[gen, ts, s]);
            if b_on > 0.5
                @printf("%10s[%s, %s] %10.3f\n", gen, ts, s, value(v_imp.p_imposable[gen, ts, s]));
            end
        end
    end
    println("v_res.p_res_pos");
    print_nz(v_res.p_res_pos);
    println("v_res.p_res_neg");
    print_nz(v_res.p_res_neg);
    println("v_res.v_flow");
    print_nz(v_flow);
    println("v_slack.p_extra_res_pos (cut consumption)");
    print_nz(v_slack.p_extra_res_pos);
    println("v_slack.p_extra_res_neg (cut production)");
    print_nz(v_slack.p_extra_res_neg);
    println("v_slack.v_extra_flow_pos");
    print_nz(v_slack.v_extra_flow_pos)
    println("v_slack.v_extra_flow_neg");
    print_nz(v_slack.v_extra_flow_neg)

    write_output_csv(launcher, ech, TS, S, model_container_l)

    return model_container_l;
end

"""
update_schedule!(launcher_p::Launcher, next_ech_p::DateTime, ech_p::DateTime, v_lim_p::Workflow.LimitableModeler, v_imp_p::Workflow.ImposableModeler)

    Launch the optimization for multiple launch dates

    # Arguments
    - `launcher_p::Launcher` : the optimization launcher containing the necessary data. Attribute previsions will be updated.
    - `next_ech_p::DateTime` : The next date at which optimization will be relaunched
    - `ech_p::DateTime` : The last date we launch optimization at. (The values we are using for the update)
    - `v_lim_p::LimitableModeler` : container for the decision values for limitable units at time ech_p
    - `v_imp_p::ImposableModeler` : container for the decision values for imposable units at time ech_p
"""
function update_schedule!(launcher_p::Launcher, next_ech_p::DateTime, ech_p::DateTime, v_lim_p::Workflow.LimitableModeler, v_imp_p::Workflow.ImposableModeler)
    @assert( next_ech_p > ech_p )
    # keep previsionnal planning for dates != next_ech_p
    filter!( x -> x[1][3] !=  next_ech_p, launcher_p.previsions)

    #NOTE: This supposes TS(next_ech_p) included in TS(ech_p)
    TS, S, _ = get_ts_s_name(launcher_p, ech_p)
    units_by_kind_l = get_units_by_kind(launcher_p)

    for ts_l in TS
        for (gen_limitable_l,_) in units_by_kind_l[K_LIMITABLE]
            values_l = []
            for s_l in S
                push!(values_l, value(v_lim_p.p_enr[gen_limitable_l, ts_l, s_l]))
            end
            launcher_p.previsions[gen_limitable_l,ts_l,next_ech_p] = Statistics.mean(values_l)
        end
        for (gen_imposable_l,_) in units_by_kind_l[K_IMPOSABLE]
            values_l = []
            for s_l in S
                push!(values_l, value(v_imp_p.p_imposable[gen_imposable_l, ts_l, s_l]))
            end
            launcher_p.previsions[gen_imposable_l,ts_l,next_ech_p] = Statistics.mean(values_l)
        end
    end

    return launcher_p.previsions
end

"""
    sum_dict_along_key_element(dict_p::Dict{<:Tuple, VariableRef}, along_k_p::Int)

sums a dictionary along a given key element position
i.e. given the dictionary input[(1,...,k,...,n)]
return the dictionary output[1,...,k-1,k+1,...,n] = sum(input[(1,...,k,...,n)] for k)

`dict_p` : dictionary to treat
`along_k_p` : position of the element of the key to sum along
# Note
    counterintuitive if the key has length 2, the resulting dictionary will be indexed by a tuple of length 1.
"""
function sum_dict_along_key_element(dict_p::Dict{<:Tuple, VariableRef}, along_k_p::Int)
    result_dict_l = Dict{Tuple,Float64}();

    for (key_l, variable_l) in dict_p
        new_key_l = key_l[1:end .!=along_k_p] #copy the key while removing the element at position along_k_p
        get!(result_dict_l, new_key_l, 0);
        result_dict_l[new_key_l] += value(variable_l)
    end

    return result_dict_l
end

function get_lim_severed_power(v_lim_p::Workflow.LimitableModeler)
    #sum along the gen to produce a dict by (ts,s)
    gen_position_in_key_l = 1
    severed_power_by_ts_s_l = sum_dict_along_key_element(v_lim_p.c_lim, gen_position_in_key_l)
    return severed_power_by_ts_s_l
end

function get_imp_neg_power(v_imp_p::Workflow.ImposableModeler)
    #sum along the gen to produce a dict by (ts,s)
    gen_position_in_key_l = 1
    imp_neg_power_by_ts_s_l = sum_dict_along_key_element(v_imp_p.c_imp_neg, gen_position_in_key_l)
    return imp_neg_power_by_ts_s_l
end

function get_imp_pos_power(v_imp_p::Workflow.ImposableModeler)
    #sum along the gen to produce a dict by (ts,s)
    gen_position_in_key_l = 1
    imp_pos_power_by_ts_s_l = sum_dict_along_key_element(v_imp_p.c_imp_pos, gen_position_in_key_l)
    return imp_pos_power_by_ts_s_l
end

function get_vals_dict_from_vars_dict(dict_p::Dict{<:Any,VariableRef})
    values_dict_l = Dict{keytype(dict_p), Float64}()

    for (key_l, variable_l) in dict_p
        values_dict_l[key_l] = value(variable_l)
    end

    return values_dict_l
end

#=========
   I/O
=========#

function print_nz(variables)
    for x in variables
        if abs(value(x[2])) > 1e-6
            println(x, " = ", value(x[2]));
        end
    end
end

function clear_output_files(launcher)
    for output_file_l in CLEARED_OUTPUT
        output_path_l = joinpath(launcher.dirpath, output_file_l)
        if isfile(output_path_l)
            rm(output_path_l)
            println("removed ", output_path_l)
        end
    end
end

function write_limitations_csv(launcher::Workflow.Launcher, ech, v_lim::Workflow.LimitableModeler)
    open(joinpath(launcher.dirpath, LIMITATION_CSV), "a") do file
        if filesize(file) == 0
            write(file, @sprintf("%s;%s;%s;%s;%s;%s;%s;%s;\n", "ech", "gen", "TS","S", "is_lim", "p_lim", "p0", "prev0"));
        end
        for x in v_lim.p_enr
            key = x[1];
            gen = key[1];
            ts =  key[2];
            s = key[3];

            is_lim = false;
            if value(v_lim.is_limited[key]) > 0.5
                is_lim = true;
            end
            p_sol = value(v_lim.p_lim[gen, ts]);
            p0 = launcher.uncertainties[gen, s, ts, ech];
            prev0 = launcher.previsions[gen, ts, ech];
            write(file, @sprintf("%s;%s;%s;%s;%s;%f;%f;%f\n", ech, gen, ts, s, is_lim, p_sol, p0, prev0));
        end
    end
end

function write_impositions_csv(launcher::Workflow.Launcher, ech, v_imp::Workflow.ImposableModeler)
    open(joinpath(launcher.dirpath, IMPOSITION_CSV), "a") do file
        if filesize(file) == 0
            write(file, @sprintf("%s;%s;%s;%s;%s;%s;%s;%s;\n", "ech", "gen", "TS","S", "is_imp", "p_imp", "p0", "prev0"));
        end
        for x in v_imp.p_imposable
            key = x[1];
            gen, ts, s = key;

            is_imp = false;
            if value(v_imp.p_is_imp[gen, ts, s]) > 0.5
                is_imp = true;
            end
            p_sol = value(v_imp.p_imposable[gen, ts, s]);
            p0 = launcher.uncertainties[gen, s, ts, ech];
            prev0 = launcher.previsions[gen, ts, ech];
            write(file, @sprintf("%s;%s;%s;%s;%s;%f;%f;%f\n", ech, gen, ts, s, is_imp, p_sol, p0, prev0));
        end
    end
end

function write_reserve_csv(launcher::Workflow.Launcher, ech::DateTime,
                            v_res::Workflow.ReserveModeler,
                            v_slack::Workflow.SlackModeler)
    open(joinpath(launcher.dirpath, RESERVE_CSV), "a") do file
        if filesize(file) == 0
            write(file, @sprintf("%s;%s;%s;%s;%s;%s\n", "ech", "TS", "S", "reserve", "production_cut", "consumption_cut"));
        end

        TS_l = Set{Dates.DateTime}()
        S_l = Set{String}()

        dict_reserve_l = Dict{Tuple{DateTime,String}, Float64}()
        for ((ts_l,s_l), var_l) in v_res.p_res_pos
            push!(TS_l, ts_l)
            push!(S_l, s_l)
            if value(var_l) > 1e-6
                dict_reserve_l[ts_l, s_l] = value(var_l)
            end
        end
        for ((ts_l,s_l), var_l) in v_res.p_res_neg
            push!(TS_l, ts_l)
            push!(S_l, s_l)
            if value(var_l) > 1e-6
                @assert !haskey(dict_reserve_l, (ts_l,s_l)) #avoid having positive and negative reserves at once
                dict_reserve_l[ts_l, s_l] = -value(var_l) #negative reserve
            end
        end

        dict_extra_reserve_pos_l = Dict{Tuple{DateTime,String}, Float64}()
        dict_extra_reserve_neg_l = Dict{Tuple{DateTime,String}, Float64}()
        for ((ts_l,s_l), var_l) in v_slack.p_extra_res_pos
            push!(TS_l, ts_l)
            push!(S_l, s_l)
            if value(var_l) > 1e-6
                dict_extra_reserve_pos_l[ts_l, s_l] = value(var_l)
            end
        end
        for ((ts_l,s_l), var_l) in v_slack.p_extra_res_neg
            push!(TS_l, ts_l)
            push!(S_l, s_l)
            if value(var_l) > 1e-6
                @assert !haskey(dict_extra_reserve_pos_l, (ts_l,s_l)) #avoid having extra positive and negative reserves at once
                dict_extra_reserve_neg_l[ts_l, s_l] = -value(var_l) #negative reserve
            end
        end

        for ts_l in TS_l, s_l in S_l
            reserve_l = get(dict_reserve_l, (ts_l, s_l), 0.)
            extra_pos_l = get(dict_extra_reserve_pos_l, (ts_l,s_l), 0.)
            extra_neg_l = get(dict_extra_reserve_neg_l, (ts_l,s_l), 0.)
            write(file, @sprintf("%s;%s;%s;%f;%f;%f\n", ech, ts_l, s_l, reserve_l, extra_neg_l, extra_pos_l));
        end
    end
end

function write_flows_csv(launcher::Workflow.Launcher, ech::DateTime,
                        v_flow::Dict{Tuple{String,DateTime,String},VariableRef},
                        v_slack::Workflow.SlackModeler)
    open(joinpath(launcher.dirpath, FLOWS_CSV), "a") do file
        if filesize(file) == 0
            write(file, @sprintf("%s;%s;%s;%s;%s;%s\n", "ech", "branch", "TS", "S", "flow", "capacity_increase"));
        end
        for ((branch_l, ts_l, s_l), flow_var_l) in v_flow
            @assert ( (value(v_slack.v_extra_flow_neg[branch_l,ts_l,s_l])<1e-6) || (value(v_slack.v_extra_flow_pos[branch_l,ts_l,s_l])<1e-6) )
            increase_l = max( value(v_slack.v_extra_flow_neg[branch_l,ts_l,s_l]), value(v_slack.v_extra_flow_pos[branch_l,ts_l,s_l]) )
            increase_l = increase_l > 1e-6 ? increase_l : 0.
            write(file, @sprintf("%s;%s;%s;%s;%f;%f\n", ech, branch_l, ts_l, s_l, value(flow_var_l),increase_l));
        end
    end
end

function write_power_csv(launcher_p::Workflow.Launcher, ech_p::DateTime, model_container_p::Workflow.ModelContainer)
    open(joinpath(launcher_p.dirpath, SEVERED_POWERS_CSV), "a") do file
        if filesize(file) == 0
            write(file, @sprintf("%s;%s;%s;%s;%s;%s;%s;%s;%s;%s\n",
                                "ech", "s", "ts",
                                "lim_severed_power","imp_severed_power","imp_increased_power","pos_res","neg_res",
                                "pos_extra_res", "neg_extra_res",
                                ));
        end

        lim_severed_power_l = get_lim_severed_power(model_container_p.limitable_modeler)
        imp_neg_power_l = get_imp_neg_power(model_container_p.imposable_modeler)
        imp_pos_power_l = get_imp_pos_power(model_container_p.imposable_modeler)
        pos_reserve_l = get_vals_dict_from_vars_dict(model_container_p.reserve_modeler.p_res_pos)
        neg_reserve_l = get_vals_dict_from_vars_dict(model_container_p.reserve_modeler.p_res_neg)
        pos_extra_reserve_l = get_vals_dict_from_vars_dict(model_container_p.slack_modeler.p_extra_res_pos)
        neg_extra_reserve_l = get_vals_dict_from_vars_dict(model_container_p.slack_modeler.p_extra_res_neg)
        for (ts_l,s_l) in union(keys(lim_severed_power_l), keys(imp_neg_power_l), keys(imp_pos_power_l))
            write(file, @sprintf("%s;%s;%s;%f;%f;%f;%f;%f;%f;%f\n",
                                ech_p,
                                s_l,
                                ts_l,
                                lim_severed_power_l[ts_l, s_l],
                                imp_neg_power_l[ts_l, s_l],
                                imp_pos_power_l[ts_l, s_l],
                                pos_reserve_l[ts_l, s_l],
                                neg_reserve_l[ts_l, s_l],
                                pos_extra_reserve_l[ts_l, s_l],
                                neg_extra_reserve_l[ts_l, s_l]
                        )
            )
        end
    end
end

function write_costs_csv(launcher_p::Workflow.Launcher, ech_p::DateTime, obj_p::Workflow.ObjectiveModeler)
    open(joinpath(launcher_p.dirpath, COSTS_CSV), "a") do file
        if filesize(file) == 0
            write(file, @sprintf("%s;%s;%s;%s;%s;%s;%s;%s;%s\n",
                                "ech", "penalties_cost", "lim_cost", "imp_prop_cost", "imp_starting_cost",
                                "cut_production_cost", "cut_consumption_cost", "branch_slack_cost",
                                "total_cost",
                        )
            );
        end

        write(file, @sprintf("%s;%f;%f;%f;%f;%f;%f;%f;%f\n",
                                ech_p,
                                value(obj_p.penalties),
                                value(obj_p.lim_cost_obj),
                                value(obj_p.imp_prop_cost_obj),
                                value(obj_p.imp_starting_cost_obj),
                                value(obj_p.cut_production_obj),
                                value(obj_p.cut_consumption_obj),
                                value(obj_p.branch_capacity_obj),
                                value(obj_p.full_obj)
                    )
        )
    end
end


function write_output_csv(launcher::Workflow.Launcher, ech, TS, S, model_container_p::Workflow.ModelContainer)
    write_limitations_csv(launcher, ech, model_container_p.limitable_modeler)
    write_impositions_csv(launcher, ech, model_container_p.imposable_modeler)
    write_reserve_csv(launcher, ech, model_container_p.reserve_modeler, model_container_p.slack_modeler)
    write_flows_csv(launcher, ech, model_container_p.v_flow, model_container_p.slack_modeler)
    write_power_csv(launcher, ech, model_container_p)
    write_costs_csv(launcher, ech, model_container_p.objective_modeler)
end

function write_previsions(launcher_p::Workflow.Launcher)
    open(joinpath(launcher_p.dirpath, SCHEDULE_CSV), "w") do file
        if filesize(file) == 0
            write(file, @sprintf("%s;%s;%s;%s;%s\n", "unit", "h_15m", "ech", "value", "decision_type"));
        end
        for ((gen_l, ts_l, ech_l), value_l) in launcher_p.previsions
            dmo_l = launcher_p.units[gen_l][5]
            decision_type_l = "flexible"
            if is_already_fixed(ech_l, ts_l, dmo_l)
                decision_type_l = "already_fixed"
            elseif is_to_decide(ech_l, ts_l, dmo_l)
                decision_type_l = "to_decide"
            end
            write(file, @sprintf("%s;%s;%s;%f;%s\n", gen_l, ts_l, ech_l, value_l, decision_type_l));
        end
    end
end
