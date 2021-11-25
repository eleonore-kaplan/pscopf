

module Workflow    
    export Launcher;
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
    
    @with_kw    mutable struct Launcher
        NO_IMPOSABLE::Bool;
        NO_LIMITABLE::Bool
        NO_LIMITATION::Bool;

        dirpath::String;
        # amplTxt description of the network
        ampltxt;
        # uncertainties, name-scenario-h-ech->value
        uncertainties::Dict{Tuple{String,String,DateTime,DateTime},Float64};
        # previsionnal planning
        previsions::Dict{Tuple{String,DateTime,DateTime},Float64};
        # name->P-maxP-startCost-propCost
        units::Dict{String, Vector{Float64}};
        # gen->type-bus
        gen_type_bus::Dict{String, Vector{String}};
        # line-bus->ptdf
        ptdf::Dict{Tuple{String,String}, Float64};

        limits::Dict{String, Float64};

    end

    @with_kw    mutable struct ImposableModeler
        p_imposable = Dict{Tuple{String,DateTime,String},VariableRef}();
        p_is_imp = Dict{Tuple{String,DateTime},VariableRef}();
        p_is_imp_and_on = Dict{Tuple{String,DateTime},VariableRef}();
        p_imp = Dict{Tuple{String,DateTime},VariableRef}();
        p_start = Dict{Tuple{String,DateTime},VariableRef}();
        p_on = Dict{Tuple{String,DateTime},VariableRef}();
        c_imp_pos = Dict{Tuple{String,DateTime,String},VariableRef}();
        c_imp_neg = Dict{Tuple{String,DateTime,String},VariableRef}();
    end
    @with_kw mutable struct LimitableModeler
        p_lim = Dict{Tuple{String,DateTime},VariableRef}();
        
        is_limited = Dict{Tuple{String,DateTime,String},VariableRef}();
        p_enr = Dict{Tuple{String,DateTime,String},VariableRef}();
        is_limited_x_p_lim = Dict{Tuple{String,DateTime,String},VariableRef}();
        c_lim = Dict{Tuple{String,DateTime,String},VariableRef}();
    end

    @with_kw mutable struct ReserveModeler
        p_res = Dict{Tuple{DateTime,String},VariableRef}();
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
                    result[buffer[1]] = (parse.(Float64, buffer[3:6]));
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
                    # println(ln)
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
    function read_previsions(dir_path::String)
        result = Dict{Tuple{String,DateTime,DateTime},Float64}();
        open(joinpath(dir_path, "pscopf_previsions.txt"), "r") do file
            for ln in eachline(file)
                # don't read commentted line 
                if ln[1] != '#'
                    # println(ln)
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

    function Launcher(dir_path::String)        
        return Launcher(false, false, false, dir_path, AmplTxt.read(dir_path),read_uncertainties(dir_path), read_previsions(dir_path), read_units(dir_path), read_gen_type_bus(dir_path), read_ptdf(dir_path), read_limits(dir_path))
    end

    function read_ampl_txt(launcher::Launcher, dir_path::String)
        launcher.ampltxt = AmplTxt.read(dir_path);
    end
        
    function add_uncertainties(launcher::Launcher, name::String, bus_name::String, ech::DateTime, ts::DateTime, value)
        launcher.uncertainties[name, bus_name, ech, ts] = value;
    end
    

    include("WorkflowModeler.jl");
end
