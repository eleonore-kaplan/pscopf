

module Workflow    
    export Launcher;
    export get_ts_s;
    export get_units_by_kind;
    export get_units_by_bus;
    export get_bus;
    export sc_opf;
    export print_nz;

    using ..AmplTxt;
    using Dates: Date, DateTime;
    using JuMP;
    using Printf;
    using Parameters;
    U_NAME=1;
    U_SCENARIO=2;
    U_H=3;
    U_ECH=4;
    K_LIMITABLE="Limitable";
    K_IMPOSABLE="Imposable";

    IMPOSITION_CSV = "imposition.csv"
    LIMITATION_CSV = "limitation.csv"
    FLOWS_CSV = "flows.csv"
    RESERVE_CSV = "reserve.csv"
    SCHEDULE_CSV = "previsions.csv"
    COSTS_CSV = "costs.csv"
    SEVERED_POWERS_CSV = "severed_power.csv"
    CUT_CONSO_CSV = "cut_consumption.csv"
    CLEARED_OUTPUT = [IMPOSITION_CSV, LIMITATION_CSV, FLOWS_CSV, RESERVE_CSV, SCHEDULE_CSV, COSTS_CSV, SEVERED_POWERS_CSV, CUT_CONSO_CSV]

    @with_kw    mutable struct Launcher
        #TODO : create a LauncherConfig
        NO_IMPOSABLE::Bool;
        NO_LIMITABLE::Bool
        NO_LIMITATION::Bool;
        NO_DMO::Bool;
        NO_CUT_PRODUCTION::Bool;
        NO_CUT_CONSUMPTION::Bool;
        NO_BRANCH_SLACK::Bool;
        SCENARIOS_FLEXIBILITY::Union{Float64,Nothing}; #allowed difference between the production levels of the different scenarios for an imposable, given a unit,ts,ech
        COEFF_CUT_PROD::Union{Float64,Nothing}; #coefficient to use in objective fct for slack variables cutting production (if NO_CUT_PRODUCTION is false)
        COEFF_CUT_CONSO::Union{Float64,Nothing}; #coefficient to use in objective fct for slack variables cutting consumption (if NO_CUT_CONSUMPTION is false)
        COEFF_BRANCH_SLACK::Union{Float64,Nothing}; #coefficient to use in objective fct for slack variables increasing branch capacity (if NO_BRANCH_SLACK is false)

        dirpath::String;
        # uncertainties, name-scenario-h-ech->value
        uncertainties::Dict{Tuple{String,String,DateTime,DateTime},Float64};
        # previsionnal planning
        previsions::Dict{Tuple{String,DateTime,DateTime},Float64};
        # name->minP-maxP-startCost-propCost-dmo
        units::Dict{String, Vector{Float64}};
        # gen->type-bus
        gen_type_bus::Dict{String, Vector{String}};
        # line-bus->ptdf
        ptdf::Dict{Tuple{String,String}, Float64};

        limits::Dict{String, Float64};

    end

    @with_kw    mutable struct ImposableModeler
        p_imposable = Dict{Tuple{String,DateTime,String},VariableRef}();
        p_imp = Dict{Tuple{String,DateTime,String},VariableRef}();
        p_is_imp = Dict{Tuple{String,DateTime,String},VariableRef}();
        p_is_imp_and_on = Dict{Tuple{String,DateTime,String},VariableRef}();
        p_start = Dict{Tuple{String,DateTime,String},VariableRef}();
        p_on = Dict{Tuple{String,DateTime,String},VariableRef}();
        c_imp_pos = Dict{Tuple{String,DateTime,String},VariableRef}();
        c_imp_neg = Dict{Tuple{String,DateTime,String},VariableRef}();
    end

    @with_kw mutable struct LimitableModeler
        p_enr = Dict{Tuple{String,DateTime,String},VariableRef}();
        p_lim = Dict{Tuple{String,DateTime},VariableRef}();
        is_limited = Dict{Tuple{String,DateTime,String},VariableRef}();
        is_limited_x_p_lim = Dict{Tuple{String,DateTime,String},VariableRef}();
        c_lim = Dict{Tuple{String,DateTime,String},VariableRef}();
    end

    @with_kw mutable struct ReserveModeler
        p_res_pos = Dict{Tuple{DateTime,String},VariableRef}();
        p_res_neg = Dict{Tuple{DateTime,String},VariableRef}();
    end

    @with_kw mutable struct SlackModeler
        #bus, ts, s
        p_cut_conso = Dict{Tuple{String,DateTime,String},VariableRef}();
        #gen,ts, s
        p_cut_prod = Dict{Tuple{String,DateTime,String},VariableRef}();
        #branch, ts, s
        v_branch_slack_pos = Dict{Tuple{String,DateTime,String},VariableRef}();
        v_branch_slack_neg = Dict{Tuple{String,DateTime,String},VariableRef}();
    end

    @with_kw mutable struct ObjectiveModeler
        penalties = AffExpr(0)
        lim_cost_obj = AffExpr(0)
        imp_prop_cost_obj = AffExpr(0)
        imp_starting_cost_obj = AffExpr(0)

        cut_production_obj = AffExpr(0)
        cut_consumption_obj = AffExpr(0)
        branch_slack_obj = AffExpr(0)

        full_obj = AffExpr(0)
    end


    """
    Possible status values for a pscopf model container

        - pscopf_OPTIMAL : a solution that does not use slacks was retrieved
        - pscopf_CUT_PROD : retrieved solution uses a cut production slack variable
        - pscopf_CUT_CONSO : retrieved solution uses a cut consumption slack variable
        - pscopf_BRANCH_SLACK : retrieved solution uses a branch capacity slack variable
        - pscopf_SLACK_FEASIBLE : retrieved solution uses more than one type of slack variables
        - pscopf_INFEASIBLE : no solution was retrieved
        - pscopf_UNSOLVED : model is not solved yet
    """
    @enum PSCOPFStatus begin
        pscopf_OPTIMAL
        pscopf_CUT_PROD
        pscopf_CUT_CONSO
        pscopf_BRANCH_SLACK
        pscopf_SLACK_FEASIBLE
        pscopf_INFEASIBLE
        pscopf_UNSOLVED
    end

    @with_kw mutable struct ModelContainer
        model = Model()
        imposable_modeler::ImposableModeler = ImposableModeler()
        limitable_modeler::LimitableModeler = LimitableModeler()
        reserve_modeler::ReserveModeler = ReserveModeler()
        slack_modeler::SlackModeler = SlackModeler()
        objective_modeler::ObjectiveModeler = ObjectiveModeler()
        v_flow = Dict{Tuple{String,DateTime,String},VariableRef}()
        status::PSCOPFStatus = pscopf_UNSOLVED
    end

    function read_ptdf(dir_path::String)
        result = Dict{Tuple{String,String}, Float64}();
        open(joinpath(dir_path, "pscopf_ptdf.txt"), "r") do file
            for ln in eachline(file)
                # don't read commentted line 
                if ln[1] != '#'
                    buffer = AmplTxt.split_with_space(ln);
                    result[buffer[1], buffer[2]] = parse(Float64, buffer[3]);
                end
            end
        end
        return result;
    end
    function read_limits(dir_path::String)
        result = Dict{String, Float64}();
        open(joinpath(dir_path, "pscopf_limits.txt"), "r") do file
            for ln in eachline(file)
                # don't read commentted line 
                if ln[1] != '#'
                    buffer = AmplTxt.split_with_space(ln);
                    result[buffer[1]] = parse(Float64, buffer[2]);
                end
            end
        end
        return result;
    end

    function read_gen_type_bus(dir_path::String)
        result = Dict{String, Vector{String}}();
        open(joinpath(dir_path, "pscopf_gen_type_bus.txt"), "r") do file
            for ln in eachline(file)
                # don't read commentted line 
                if ln[1] != '#'
                    buffer = AmplTxt.split_with_space(ln);
                    result[buffer[1]] = buffer[2:3];
                end
            end
        end
        return result
    end

    function read_units(dir_path::String)
        result = Dict{String, Vector{Float64}}();
        open(joinpath(dir_path, "pscopf_units.txt"), "r") do file
            for ln in eachline(file)
                # don't read commentted line 
                if ln[1] != '#'
                    buffer = AmplTxt.split_with_space(ln);
                    result[buffer[1]] = (parse.(Float64, buffer[3:7]));
                end
            end
        end
        return result
    end
    
    function read_uncertainties(dir_path::String)
        result = Dict{Tuple{String,String,DateTime,DateTime},Float64}();
        open(joinpath(dir_path, "pscopf_uncertainties.txt"), "r") do file
            for ln in eachline(file)
                # don't read commentted line 
                if ln[1] != '#'
                    buffer = AmplTxt.split_with_space(ln);
                    name = buffer[1];
                    h = DateTime(buffer[2]);
                    ech = DateTime(buffer[3]);
                    scenario = buffer[4];
                    value = parse(Float64, buffer[5]);
                    result[name, scenario, h, ech] = value;
                end
            end
        end
        return result;
    end    
    function read_previsions(dir_path::String, filename_p="pscopf_previsions.txt")
        result = Dict{Tuple{String,DateTime,DateTime},Float64}();
        open(joinpath(dir_path, filename_p), "r") do file
            for ln in eachline(file)
                # don't read commentted line 
                if ln[1] != '#'
                    buffer = AmplTxt.split_with_space(ln);
                    name = buffer[1];
                    h = DateTime(buffer[2]);
                    ech = DateTime(buffer[3]);
                    value = parse(Float64, buffer[4]);
                    result[name, h, ech] = value;
                end
            end
        end
        return result;
    end

    function Launcher(input_path::String, dir_path::String)
        if !isdir(input_path)
            error("Input folder does not exist : "*input_path)
        end
        if !isdir(dir_path)
            mkpath(dir_path)
        end

        return Launcher(false, false, false, false, false, false, false,
                        nothing,
                        nothing, nothing, nothing,
                        dir_path,
                        read_uncertainties(input_path), read_previsions(input_path),
                        read_units(input_path), read_gen_type_bus(input_path),
                        read_ptdf(input_path), read_limits(input_path))
    end

    function Launcher(dir_path::String)        
        return Launcher(dir_path, dir_path)
    end


    function read_ampl_txt(launcher::Launcher, dir_path::String)
        launcher.ampltxt = AmplTxt.read(dir_path);
    end
        
    function add_uncertainties(launcher::Launcher, name::String, bus_name::String, ech::DateTime, ts::DateTime, value)
        launcher.uncertainties[name, bus_name, ech, ts] = value;
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

    function get_highest_pmax(units_p::Dict{String, Vector{Float64}})
        return maximum([gen_data_l[2] for (_,gen_data_l) in units_p])
    end

    include("WorkflowModeler.jl");
    include("WorkflowWorstCase.jl");


    function balance_scenarios_eod!(launcher_p::Launcher, ech_p)
        @info "-"^10 * "   balance scenarios   " * "-"^20
        #I/O still to specify :
        #probably this will read probabilistic uncertainties
        #write the uncertainties to consider by pscopf
        #FIXME : read market ECH to only launch market at specific dates ?
        @warn "balance action by scenario at ech $(ech_p) not implemented!"
    end

    """
        run_mode1(launcher::Launcher, lst_ech_p, p_res_min::Number, p_res_max::Number)

    Launch the optimization for multiple launch dates in coordinated mode (fr. mode de gestion coordonnee)

    # Arguments
    - `launcher::Launcher` : the optimization launcher containing the necessary data
    - `lst_ech_p` : List of launch dates to consider
    - `p_res_min` : The minimum allowed reserve level
    - `p_res_max` : The maximum allowed reserve level
    """
    function run_mode1(launcher_p::Launcher, lst_ech_p, p_res_min::Number, p_res_max::Number)
        @info "Launch PSCOPF mode 1 for horizons : $(lst_ech_p)"
        dict_results_l = Dict{DateTime, ModelContainer}()
        clear_output_files(launcher_p);

        for (index_l, ech_l)  in enumerate(lst_ech_p)
            @info "-"^30 * "   ECH : $ech_l   " * "-"^60

            #Balance the uncertainties for each scenario separately
            balance_scenarios_eod!(launcher_p, ech_l)

            #Decide on the production levels of the units based on the DMO and ech
            #Decisions can be fixed for all scenarios (limitables and DMO>=ECH) or by scenario (DMO<ECH)
            result_l = sc_opf(launcher_p, ech_l, p_res_min, p_res_max)
            dict_results_l[ech_l] = result_l

            #Propagate PSCOPF decisions
            #If needed, Update the production schedule to be considered in the following ech
            if index_l < length(lst_ech_p)
                @info "Update schedule for upcoming iteration : $(lst_ech_p[index_l+1])"
                update_schedule!(launcher_p, lst_ech_p[index_l+1], ech_l, result_l.limitable_modeler, result_l.imposable_modeler)
            end
        end
        write_previsions(launcher_p)
        return dict_results_l
    end

    """
        run(launcher::Launcher, lst_ech_p, p_res_min::Number, p_res_max::Number, mode_p::Int64)

    Launch the optimization for the specified launch dates

    # Arguments
    - `launcher::Launcher` : the optimization launcher containing the necessary data
    - `lst_ech_p` : List of launch dates to consider
    - `p_res_min` : The minimum allowed reserve level
    - `p_res_max` : The maximum allowed reserve level
    - `mode_p::Int64` : Launch mode (fr. mode de gestion : 1:coordonnee, 2:alternee, 3:separee)
    """
    function run(launcher_p::Launcher, lst_ech_p, p_res_min::Number, p_res_max::Number, mode_p::Int64)
        if mode_p == 1
            return run_mode1(launcher_p, lst_ech_p, p_res_min, p_res_max)
        else
            msg_l = @sprintf("mode %d is not implemented!", mode_p)
            error(msg_l)
        end
    end

    """
        run(launcher::Launcher, p_res_min::Number, p_res_max::Number, mode_p::Int64)

    Launch the optimization for all launch dates listed in pscopf_uncertainties.txt

    # Arguments
    - `launcher::Launcher` : the optimization launcher containing the necessary data
    - `p_res_min` : The minimum allowed reserve level
    - `p_res_max` : The maximum allowed reserve level
    - `mode_p::Int64` : Launch mode (fr. mode de gestion : 1:coordonnee, 2:alternee, 3:separee)
    """
    function run(launcher_p::Launcher, p_res_min::Number, p_res_max::Number; mode_p::Int64=1)
        print_config(launcher_p)

        ECH = Workflow.get_sorted_ech(launcher_p);
        return run(launcher_p, ECH, p_res_min, p_res_max, mode_p)
    end

    function assessment_step(launcher::Launcher, results::Dict{Dates.DateTime, ModelContainer}, p_res_min::Number, p_res_max::Number)
        @warn "assessment_step not implemented!"
    end
end
