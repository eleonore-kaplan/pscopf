

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
    return sort(collect(ech_set)),sort(collect(ts_set)),sort(collect(s_set)), name_set;
end

function get_units_by_kind(launcher::Launcher)
    result = Dict{String, Dict{String, String}}();
    result[K_LIMITABLE]=Dict{String, String}()
    result[K_IMPOSABLE]=Dict{String, String}()
    for gen in launcher.gen_type_bus
        kind = gen[2][1];
        push!(result[kind],  gen[1]=>gen[2][2]);
    end 
    return result;
end

function get_units_by_bus(launcher::Launcher, buses::Set{String})
    result = Dict{String,  Dict{String, Vector{String}}}();
    result[K_LIMITABLE]=Dict{String, Vector{String}}([bus => Vector{String}() for bus in buses])
    result[K_IMPOSABLE]=Dict{String, Vector{String}}([bus => Vector{String}() for bus in buses])
    for gen in launcher.gen_type_bus
        name = gen[1]
        kind = gen[2][1];
        bus  = gen[2][2];
        tmp = get(result[kind], bus, Vector{String}());
        push!(tmp, name);
        result[kind][bus] = tmp;
    end 
    return result;
end

function sc_opf(launcher::Launcher, ech::DateTime)        
    ##############################################################
    ### optimisation modelling sets
    ##############################################################
    ECH,TS, S, NAMES = Workflow.get_ech_ts_s_name(launcher);
    BUSES =  Workflow.get_bus(launcher, NAMES);
    units_by_kind = Workflow.get_units_by_kind(launcher);
    units_by_bus =  Workflow.get_units_by_bus(launcher, BUSES);

    println("Number of scenario ", length(S));
    println("Number of time step is ", length(TS));
    println(ECH);
    K_IMPOSABLE = Workflow.K_IMPOSABLE;
    K_LIMITABLE = Workflow.K_LIMITABLE;

    netloads = Dict([(bus, ts, s) => launcher.uncertainties[bus, s, ts, ech] for bus in BUSES, ts in TS, s in S]);
    NO_LIMITABLE = false
    NO_IMPOSABLE = false

    ##############################################################
    # to be in a function ...
    ##############################################################

    model = Model();

    # p_limitable[ts, s]  = min(p0[ts, s], pMax[ts])
    p_lim = Dict{Tuple{String, DateTime}, VariableRef}()
    p_imposable = Dict{Tuple{String, DateTime, String}, VariableRef}()
    
    is_limited = Dict{Tuple{String, DateTime, String}, VariableRef}()
    is_limited_x_p_lim = Dict{Tuple{String, DateTime, String}, VariableRef}()
    for kvp in units_by_kind[K_LIMITABLE], ts in TS
        gen = kvp[1]
        p_lim[gen, ts] =  @variable(model, base_name=@sprintf("p_lim[%s,%s]", gen, ts), lower_bound=0)
        pLimMax = 0
        for s in S
            pLimMax = max(pLimMax, launcher.uncertainties[kvp[1], s, ts, ech])
        end
        if ! NO_LIMITABLE
            for s in S
                p0 = launcher.uncertainties[kvp[1], s, ts, ech]
                name =  @sprintf("p_delta_limitable[%s,%s,%s]", gen, ts, s);
                
                is_limited[gen, ts, s] = @variable(model, base_name=name, binary=true);

                is_limited_x_p_lim[gen, ts, s] = @variable(model, base_name=name, lower_bound=0);
                
                @constraint(model, is_limited_x_p_lim[gen, ts, s] <= p_lim[gen, ts]);
                @constraint(model, is_limited_x_p_lim[gen, ts, s] <= is_limited[gen, ts, s]*pLimMax);
                @constraint(model, is_limited_x_p_lim[gen, ts, s] + pLimMax * (1-is_limited[gen, ts, s])-p_lim[gen, ts] >= 0);
            end
        end
    end
    if ! NO_IMPOSABLE
        for kvp in units_by_kind[K_IMPOSABLE], ts in TS, s in S
            name =  @sprintf("p_imposable[%s,%s,%s]", kvp[1], ts, s);
            p_imposable[kvp[1], ts, s] = @variable(model, base_name=name, lower_bound=0);
        end
    end
    # println(units_by_kind)
    # println(p_imposable)

    eod_expr = Dict([(ts, s)=>AffExpr(0) for ts in TS, s in S]);

    for ts in TS, s in S
        for bus in BUSES
            if ! NO_IMPOSABLE
                for gen in units_by_bus[K_IMPOSABLE][bus]
                    eod_expr[ts, s] += p_imposable[gen, ts, s]
                end
            end
            if ! NO_LIMITABLE
                for gen in units_by_bus[K_LIMITABLE][bus]
                    p0 = launcher.uncertainties[gen, s, ts, ech]
                    eod_expr[ts, s] +=  ((1-is_limited[gen, ts, s])*p0+is_limited_x_p_lim[gen, ts, s])
                end
            end
        end
    end
    # println(launcher.uncertainties)
    for ts in TS, s in S
        load=0
        for bus in BUSES
            load+=netloads[bus, ts, s]
        end
        @constraint(model, eod_expr[ts, s] ==load)
    end
    # println(units_by_bus)
    # println(eod_expr)
    if ! NO_LIMITABLE
        eod_obj = sum(x[2] for x in p_lim)
    end
    if ! NO_IMPOSABLE
        eod_obj +=sum(100*x[2] for x in p_imposable)
    end
    @objective(model, Min, eod_obj);

    println(model);
    set_optimizer(model, Xpress.Optimizer);
    optimize!(model);

    print_nz(p_imposable);
    print_nz(p_lim);

    if ! NO_LIMITABLE
         for bus in BUSES, ts in TS, s in S, gen in units_by_bus[K_LIMITABLE][bus]
            p0 = launcher.uncertainties[gen, s, ts, ech]
            println(gen, " : ", value((1-is_limited[gen, ts, s])*p0+is_limited_x_p_lim[gen, ts, s]))
        end
    end
    
    return model, p_lim, p_imposable;
end

function print_nz(variables)    
    for x in variables
        if abs( value(x[2]))>1e-6 || true
            println( x, " = ", value(x[2]));
        end
    end
end