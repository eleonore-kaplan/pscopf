

export get_ts_s;
export get_units_by_kind;
export get_units_by_bus;
export get_bus;
export sc_opf;
export print_nz;

using Xpress;

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
function add_limitable!(launcher::Launcher, ech::DateTime, model, units_by_kind, TS, S, NO_LIMITABLE)
    p_lim = Dict{Tuple{String,DateTime},VariableRef}();
    
    is_limited = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_enr = Dict{Tuple{String,DateTime,String},VariableRef}();
    is_limited_x_p_lim = Dict{Tuple{String,DateTime,String},VariableRef}();
    if ! NO_LIMITABLE
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
                
                @constraint(model, is_limited_x_p_lim[gen, ts, s] <= p_lim[gen, ts]);
                @constraint(model, is_limited_x_p_lim[gen, ts, s] <= is_limited[gen, ts, s] * pLimMax);
                @constraint(model, is_limited_x_p_lim[gen, ts, s] + pLimMax * (1 - is_limited[gen, ts, s]) - p_lim[gen, ts] >= 0);

                p0 = launcher.uncertainties[gen, s, ts, ech];
                name =  @sprintf("p_enr[%s,%s,%s]", gen, ts, s);
                p_enr[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0, upper_bound = p0);
                @constraint(model, p_enr[gen, ts, s] == (1 - is_limited[gen, ts, s]) * p0 + is_limited_x_p_lim[gen, ts, s]);
                @constraint(model, p_enr[gen, ts, s] <= p_lim[gen, ts]);
            end
        end
    end
    return p_lim, is_limited, is_limited_x_p_lim;
end

function add_imposable!(launcher::Launcher, ech, model,  units_by_kind, TS, S, NO_IMPOSABLE)
    p_imposable = Dict{Tuple{String,DateTime,String},VariableRef}();
    p_is_imp = Dict{Tuple{String,DateTime},VariableRef}();
    p_imp = Dict{Tuple{String,DateTime},VariableRef}();
    p_start = Dict{Tuple{String,DateTime},VariableRef}();
    p_on = Dict{Tuple{String,DateTime},VariableRef}();
    if ! NO_IMPOSABLE
        for kvp in units_by_kind[K_IMPOSABLE]
            for ts in TS
                gen = kvp[1];
                pMin = 10;
                pMax = 250;            

                name =  @sprintf("p_imp[%s,%s]", gen, ts);
                p_imp[gen, ts] = @variable(model, base_name = name, lower_bound = pMin, upper_bound = pMax);
                
                name =  @sprintf("p_is_imp[%s,%s]", gen, ts);
                p_is_imp[gen, ts] = @variable(model, base_name = name, binary = true);

                name =  @sprintf("p_start[%s,%s]", gen, ts);
                p_start[gen, ts] = @variable(model, base_name = name, binary = true);
                
                name =  @sprintf("p_on[%s,%s]", gen, ts);
                p_on[gen, ts] = @variable(model, base_name = name, binary = true);


                for s in S
                    p0 = launcher.uncertainties[gen, s, ts, ech];
                    name =  @sprintf("p_imposable[%s,%s,%s]", gen, ts, s);
                    p_imposable[gen, ts, s] = @variable(model, base_name = name, lower_bound = 0);

                    @constraint(model, p_imposable[gen, ts, s] == (1 - p_is_imp[gen, ts]) * p0 + p_imp[gen, ts]);
                    @constraint(model, p_imp[gen, ts] <= pMax * p_is_imp[gen, ts]);
                    @constraint(model, p_imp[gen, ts] >= pMin * p_is_imp[gen, ts]);
                end
            end
            i=0;
            for ts in TS                
                i+=1;
                if i>1
                    @constraint(model, p_start[gen, ts] <= p_on[gen, ts]);
                    @constraint(model, p_start[gen, ts] <= 1-p_on[gen, ts-1]);
                    @constraint(model, p_start[gen, ts] >= 1-p_on[gen, ts]-p_on[gen, ts-1]);
                else
                    prev0 = launcher.previsions[gen, ts, ech];
                    if abs(prev0)<1
                        @constraint(model, p_start[gen, ts] == p_on[gen, ts]);
                    else
                end
            end
        end
    end
    return p_imposable, p_is_imp, p_imp, p_start;
end

function add_eod_constraint!(launcher::Launcher, ech, model, units_by_bus, TS, S, NO_LIMITABLE, NO_IMPOSABLE, p_imposable, is_limited, is_limited_x_p_lim, BUSES)
    eod_expr = Dict([(ts, s) => AffExpr(0) for ts in TS, s in S]);
    for ts in TS, s in S
        for bus in BUSES
            if ! NO_IMPOSABLE
                for gen in units_by_bus[K_IMPOSABLE][bus]
                    eod_expr[ts, s] += p_imposable[gen, ts, s];
                end
            end
            if ! NO_LIMITABLE
                for gen in units_by_bus[K_LIMITABLE][bus]
                    p0 = launcher.uncertainties[gen, s, ts, ech];
                    # println(gen, " ", ts, " ", s, " ", p0);
                    eod_expr[ts, s] +=  ((1 - is_limited[gen, ts, s]) * p0 + is_limited_x_p_lim[gen, ts, s]);
                end
            end
        end
    end
    netloads = Dict([(bus, ts, s) => launcher.uncertainties[bus, s, ts, ech] for bus in BUSES, ts in TS, s in S]);
    # println(launcher.uncertainties)
    for ts in TS, s in S
        load = 0;
        for bus in BUSES
            load += netloads[bus, ts, s];
        end
        @constraint(model, eod_expr[ts, s] == load);
    end
end

function add_obj!(model,p_lim, is_limited, is_limited_x_p_lim, p_imposable, p_is_imp, p_imp, p_start)
    eod_obj = AffExpr(0);
    eod_obj += sum(x[2] for x in p_lim);
    eod_obj += sum(100 * x[2] for x in p_imposable);
    eod_obj += sum(1e-2 * x[2] for x in is_limited);
    @objective(model, Min, eod_obj);
end

function sc_opf(launcher::Launcher, ech::DateTime)        
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

    NO_LIMITABLE = false;
    NO_IMPOSABLE = false;

    ##############################################################
    # to be in a function ...
    ##############################################################

    model = Model();
    p_lim, is_limited, is_limited_x_p_lim = add_limitable!(launcher, ech, model, units_by_kind, TS, S, NO_LIMITABLE);

    p_imposable, p_is_imp, p_imp, p_start = add_imposable!(launcher, ech, model, units_by_kind, TS, S, NO_IMPOSABLE);

    add_eod_constraint!(launcher, ech, model, units_by_bus, TS, S, NO_LIMITABLE, NO_IMPOSABLE, p_imposable, is_limited, is_limited_x_p_lim, BUSES);
    # println(units_by_bus)
    # println(eod_expr)
    add_obj!(model,p_lim, is_limited, is_limited_x_p_lim, p_imposable, p_is_imp, p_imp, p_start);

    println(model)
    set_optimizer(model, Xpress.Optimizer);
    optimize!(model);

    print_nz(p_imposable);
    print_nz(p_lim);
    
    println("NO_IMPOSABLE   : ", NO_IMPOSABLE);
    println("NO_LIMITABLE   : ", NO_LIMITABLE);
    println("BUSES          : ", BUSES);
    println("NAMES          : ", NAMES);
    println("TS             : ", TS);
    println("S              : ", S);
    
    @printf("%30s[%s,%s] %4s %10s %10s %10s\n", "gen", "ts", "s", "b_enr", "p_enr", "p_lim_enr", "p0");
    if ! NO_LIMITABLE
        # println(launcher.uncertainties)
        for bus in BUSES, ts in TS, s in S, gen in units_by_bus[K_LIMITABLE][bus]
            p0 = launcher.uncertainties[gen, s, ts, ech];
            b_enr = value(is_limited[gen, ts, s]);
            p_enr = value((1 - is_limited[gen, ts, s]) * p0 + is_limited_x_p_lim[gen, ts, s]);
            p_lim_enr = value(p_lim[gen, ts]);
            # println(value(is_limited_x_p_lim[gen, ts, s]) - b_enr * p_lim_enr)
            @printf("%10s[%s,%s] %4d %10.3f %10.3f %10.3f\n", gen, ts, s, b_enr, p_enr, p_lim_enr, p0);
            # println(gen, " : ", value((1 - is_limited[gen, ts, s]) * p0 + is_limited_x_p_lim[gen, ts, s]))
        end
    end
    
    return model, p_lim, p_imposable;
end

function print_nz(variables)    
    for x in variables
        if abs(value(x[2])) > 1e-6
            println(x, " = ", value(x[2]));
        end
    end
end