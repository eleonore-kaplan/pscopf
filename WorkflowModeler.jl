

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
                throw(e_xpress)
            end
        end
    else
        throw(e_xpress)
    end
end
println("optimizer: ", OPTIMIZER)

function get_bus(launcher::Launcher, names::Set{String})
    result = Set{String}();
    for name in names
        if !haskey(launcher.gen_type_bus, name)
            push!(result, name);
        end
    end
    return result;
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
function add_limitable!(launcher::Launcher, ech::DateTime, model, units_by_kind, TS, S)
    p_lim = Dict{Tuple{String,DateTime},VariableRef}();    
    is_limited = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_enr = Dict{Tuple{String,DateTime,String},VariableRef}();
    is_limited_x_p_lim = Dict{Tuple{String,DateTime,String},VariableRef}();
    c_lim = Dict{Tuple{String,DateTime,String},VariableRef}();
    if ! launcher.NO_LIMITABLE
        for kvp in units_by_kind[K_LIMITABLE], ts in TS
            gen = kvp[1];
            p_lim[gen, ts] =  @variable(model, base_name = @sprintf("p_lim[%s,%s]", gen, ts), lower_bound = 0);
            pLimMax = 0;
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

function add_imposable!(launcher::Launcher, ech, model,  units_by_kind, TS, S)
    p_imposable = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_is_imp = Dict{Tuple{String,DateTime},VariableRef}();
    p_is_imp_and_on = Dict{Tuple{String,DateTime},VariableRef}();
    p_imp = Dict{Tuple{String,DateTime},VariableRef}();
    p_start = Dict{Tuple{String,DateTime},VariableRef}();
    p_on = Dict{Tuple{String,DateTime},VariableRef}();
    c_imp_pos  = Dict{Tuple{String,DateTime,String},VariableRef}();
    c_imp_neg   = Dict{Tuple{String,DateTime,String},VariableRef}();
    if ! launcher.NO_IMPOSABLE
        for kvp in units_by_kind[K_IMPOSABLE]
            gen = kvp[1];
            for ts in TS
                pMin = launcher.units[gen][1];
                pMax = launcher.units[gen][2];            

                name =  @sprintf("p_imp[%s,%s]", gen, ts);
                p_imp[gen, ts] = @variable(model, base_name = name);
                
                name =  @sprintf("p_is_imp[%s,%s]", gen, ts);
                p_is_imp[gen, ts] = @variable(model, base_name = name, binary = true);

                name =  @sprintf("p_start[%s,%s]", gen, ts);
                p_start[gen, ts] = @variable(model, base_name = name, binary = true);
                
                name =  @sprintf("p_on[%s,%s]", gen, ts);
                p_on[gen, ts] = @variable(model, base_name = name, binary = true);

                name =  @sprintf("p_is_imp_and_on[%s,%s]", gen, ts);
                p_is_imp_and_on[gen, ts] = @variable(model, base_name = name, binary = true);

                # if in(gen, ["park_city", "alta", "sundance"])
                #     println("WARNING");
                #     @constraint(model,  p_on[gen, ts]==0);
                #     @constraint(model,  p_is_imp[gen, ts]==0);
                # end
                for s in S
                    p0 = launcher.uncertainties[gen, s, ts, ech];
                    name =  @sprintf("p_imposable[%s,%s,%s]", gen, ts, s);
                    p_imposable[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0);
                    
                    name =  @sprintf("c_imp_pos[%s,%s,%s]", gen, ts, s);
                    c_imp_pos[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0);
                    
                    name =  @sprintf("c_imp_neg[%s,%s,%s]", gen, ts, s);
                    c_imp_neg[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0);

                    @constraint(model, p_imposable[gen, ts, s] == p0 + c_imp_pos[gen, ts, s] - c_imp_neg[gen, ts, s]);

                    @constraint(model, p_imposable[gen, ts, s] == (1 - p_is_imp[gen, ts]) * p0 + p_imp[gen, ts]);
                    @constraint(model, p_imp[gen, ts] <= pMax * p_is_imp_and_on[gen, ts]);
                    @constraint(model, p_imp[gen, ts] >= pMin * p_is_imp_and_on[gen, ts]);

                    @constraint(model, p_is_imp_and_on[gen, ts] <= p_is_imp[gen, ts]);
                    @constraint(model, p_is_imp_and_on[gen, ts] <= p_on[gen, ts]);
                    @constraint(model, 1 + p_is_imp_and_on[gen, ts] >= p_on[gen, ts] + p_is_imp[gen, ts]);
                end
            end
            i = 0;
            for ts in TS                
                i += 1;
                if i > 1
                    ts_1 = TS[i - 1];
                    @constraint(model, p_start[gen, ts] <= p_on[gen, ts]);
                    @constraint(model, p_start[gen, ts] <= 1 - p_on[gen, ts_1]);
                    @constraint(model, p_start[gen, ts] >= p_on[gen, ts] - p_on[gen, ts_1]);
                else                    
                    prev0 = launcher.previsions[gen, ts, ech];
                    println(@sprintf("%s %s is at %f\n", gen, ts, prev0));
                    if abs(prev0) < 1
                        @constraint(model, p_start[gen, ts] == p_on[gen, ts]);
                    end
                end
            end
        end
    end
    return Workflow.ImposableModeler(p_imposable, p_is_imp, p_imp, p_is_imp_and_on, p_start, p_on, c_imp_pos, c_imp_neg);
end

function add_eod_constraint!(launcher::Launcher, ech, model, units_by_bus, TS, S, BUSES, v_lim::Workflow.LimitableModeler, v_imp::Workflow.ImposableModeler, v_res::Workflow.ReserveModeler, netloads )
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

function add_obj!(launcher::Launcher, model, TS, S, v_lim::Workflow.LimitableModeler, v_imp::Workflow.ImposableModeler, v_res::Workflow.ReserveModeler)
    eod_obj = AffExpr(0);
    w_lim = 1 / length(S);
    for x in v_lim.c_lim
        # implicit looping on #ts, #s and gen
        gen = x[1][1];
        cProp = launcher.units[gen][4];
        eod_obj += w_lim * cProp * x[2];
    end
    if length(v_lim.is_limited) > 0
        eod_obj += sum(1e-4 * x[2] for x in v_lim.is_limited);
    end
    for x in v_imp.p_start
        gen = x[1][1];
        cStart = launcher.units[gen][3];
        eod_obj += cStart * x[2];
    end
    for x in v_imp.c_imp_pos
        gen = x[1][1];
        cProp = launcher.units[gen][4];
        eod_obj += w_lim * cProp * x[2];
    end
    for x in v_imp.c_imp_neg
        gen = x[1][1];
        cProp = launcher.units[gen][4];
        eod_obj += w_lim * cProp * x[2];
    end
    for x in v_res.p_res_pos
        eod_obj += (1e-3)*w_lim*x[2];
    end
    for x in v_res.p_res_neg
        eod_obj += (1e-3)*w_lim* x[2];
    end
    @objective(model, Min, eod_obj);
end


function add_flow!(launcher::Workflow.Launcher, model, TS, S,  units_by_bus, v_lim::Workflow.LimitableModeler, v_imp::Workflow.ImposableModeler, netloads)
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
            @constraint(model, v_flow[branch, ts, s] == f_ref + xpr);
        end
    end
    return v_flow;
end

function sc_opf(launcher::Launcher, ech::DateTime, p_res_min, p_res_max)
    ##############################################################
    ### optimisation modelling sets
    ##############################################################
    ECH, TS, S, NAMES = Workflow.get_ech_ts_s_name(launcher);
    BUSES =  Workflow.get_bus(launcher, NAMES);
    units_by_kind = Workflow.get_units_by_kind(launcher);
    units_by_bus =  Workflow.get_units_by_bus(launcher, BUSES);

    println("NAMES : ", NAMES);
    println("BUSES : ", BUSES);
    println("units_by_bus : ", units_by_bus);


    println("Number of scenario ", length(S));
    println("Number of time step is ", length(TS));
    println(ECH);
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
    
    model = Model();
    v_lim = add_limitable!(launcher, ech, model, units_by_kind, TS, S);
    p_lim = v_lim.p_lim;
    is_limited = v_lim.is_limited;
    is_limited_x_p_lim = v_lim.is_limited_x_p_lim;
    c_lim = v_lim.c_lim;

    v_imp = add_imposable!(launcher, ech, model, units_by_kind, TS, S);

    p_imposable = v_imp.p_imposable;
    p_is_imp = v_imp.p_is_imp;
    p_imp = v_imp.p_imp;
    p_start = v_imp.p_start;
    p_on = v_imp.p_on;

    v_res = add_reserve!(launcher, ech, model, TS, S, p_res_min, p_res_max);

    add_eod_constraint!(launcher, ech, model, units_by_bus, TS, S, BUSES, v_lim, v_imp, v_res, netloads);

    v_flow = add_flow!(launcher, model, TS, S, units_by_bus,  v_lim, v_imp, netloads);

    # println(units_by_bus)
    # println(eod_expr)
    add_obj!(launcher,  model, TS, S, v_lim, v_imp, v_res);

    # println(model)
    set_optimizer(model, OPTIMIZER);
    write_to_file(model, launcher.dirpath*"/model.lp")
    optimize!(model);

    println("end of optim.")
    if termination_status(model) == INFEASIBLE
        error("Model is infeasible")
    end
    println(termination_status(model))
    println(objective_value(model))

    # print_nz(p_imposable);
    # print_nz(p_is_imp);
    # print_nz(p_start);
    # print_nz(p_on);
    # print_nz(is_limited);

    println("NO_IMPOSABLE   : ", launcher.NO_IMPOSABLE);
    println("NO_LIMITABLE   : ", launcher.NO_LIMITABLE);
    println("NO_LIMITATION  : ", launcher.NO_LIMITATION);
    println("BUSES          : ", BUSES);
    println("NAMES          : ", NAMES);
    println("TS             : ", TS);
    println("S              : ", S);
    
    @printf("%30s[%s,%s] %4s %10s %10s %10s\n", "gen", "ts", "s", "b_enr", "p_enr", "p_lim_enr", "p0");
    if ! launcher.NO_LIMITABLE
        # println(launcher.uncertainties)
        for bus in BUSES, ts in TS, s in S, gen in units_by_bus[K_LIMITABLE][bus]
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
        for bus in BUSES, ts in TS, gen in units_by_bus[K_IMPOSABLE][bus]
            b_start = value(p_start[gen, ts]);
            b_imp = value(p_is_imp[gen, ts]);
            if b_imp > 0.5
                @printf("%10s[%s] IMPOSED\n", gen, ts);
            end
            if b_start > 0.5
                @printf("%10s[%s] STARTED\n", gen, ts);
            end
            b_on = value(p_on[gen, ts]);
            for s in S
                if b_on > 0.5
                    @printf("%10s[%s] %10.3f\n", gen, ts, value(v_imp.p_imposable[gen, ts, s]));
                end
            end

        end
    end
    println("v_res.p_res_pos");
    print_nz(v_res.p_res_pos);
    println("v_res.p_res_neg");
    print_nz(v_res.p_res_neg);
    println("v_res.v_flow");
    print_nz(v_flow);
    write_output_csv(launcher, ech, TS, S, v_lim, v_imp);
    write_extra_output_csv(launcher, v_res, v_flow);

    return model, v_lim, v_imp, v_res, v_flow;
end

function print_nz(variables)    
    for x in variables
        if abs(value(x[2])) > 1e-6
            println(x, " = ", value(x[2]));
        end
    end
end    

function write_output_csv(launcher::Workflow.Launcher, ech, TS, S, v_lim::Workflow.LimitableModeler, v_imp::Workflow.ImposableModeler)
    open(joinpath(launcher.dirpath, "limitation.csv"), "w") do file
        write(file, @sprintf("%s;%s;%s;%s;%s;%s;\n", "gen", "TS","S", "is_lim", "p_lim", "p0"));
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
            write(file, @sprintf("%s;%s;%s;%s;%f;%f\n", gen, ts,s, is_lim, p_sol, p0));
        end
    end
    open(joinpath(launcher.dirpath, "imposition.csv"), "w") do file
        write(file, @sprintf("%s;%s;%s;%s;%s;%s;\n", "gen", "TS","S", "is_imp", "p_imp", "p0"));
        for x in v_imp.p_imposable
            key = x[1];
            gen, ts, s = key;

            is_imp = false;
            if value(v_imp.p_is_imp[gen, ts]) > 0.5
                is_imp = true;
            end
            p_sol = value(v_imp.p_imposable[gen, ts, s]);
            p0 = launcher.uncertainties[gen, s, ts, ech];
            write(file, @sprintf("%s;%s;%s;%s;%f;%f\n", gen, ts,s, is_imp, p_sol, p0));
        end
    end
end

function write_extra_output_csv(launcher::Workflow.Launcher, v_res::Workflow.ReserveModeler, v_flow::Dict{Tuple{String,DateTime,String},VariableRef})
    open(joinpath(launcher.dirpath, "reserve.csv"), "w") do file
        write(file, @sprintf("%s;%s;%s\n", "TS","S", "res"));
        dict_reserve_l = Dict{Tuple{DateTime,String}, Float64}()
        for ((ts_l,s_l), var_l) in v_res.p_res_pos
            if value(var_l) > 1e-6
                dict_reserve_l[ts_l, s_l] = value(var_l)
            end
        end
        for ((ts_l,s_l), var_l) in v_res.p_res_neg
            if value(var_l) > 1e-6
                @assert !haskey(dict_reserve_l, (ts_l,s_l)) #avoid having positive and negative reserves at once
                dict_reserve_l[ts_l, s_l] = -value(var_l) #negative reserve
            end
        end

        for ((ts_l,s_l), value_l) in dict_reserve_l
            write(file, @sprintf("%s;%s;%f\n", ts_l,s_l, value_l));
        end
    end

    open(joinpath(launcher.dirpath, "flows.csv"), "w") do file
        write(file, @sprintf("%s;%s;%s;%s\n", "branch", "TS","S", "flow"));
        for ((branch_l, ts_l, s_l), flow_var_l) in v_flow
            write(file, @sprintf("%s;%s;%s;%f\n", branch_l, ts_l,s_l, value(flow_var_l)));
        end
    end
end
