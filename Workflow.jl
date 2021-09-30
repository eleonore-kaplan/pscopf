module Workflow
    
    export Launcher;
    export add_uncertainties;


    using ..AmplTxt;
    using ..ProductionUnits;
    using Dates: Date, DateTime;

    mutable struct Launcher
        ampltxt;

        uncertainties::Dict{ Tuple{String, String, DateTime, DateTime}, Float64};
        certainties::Dict{Tuple{String, String, DateTime}, Float64};
        
    end

    function Launcher(dir_path::String)
        u = Dict{Tuple{String, String, DateTime, DateTime}, Float64}()
        c=  Dict{Tuple{String, String, DateTime}, Float64}()
        return Launcher(AmplTxt.read(dir_path),u, c)
    end

    function read_ampl_txt(launcher::Launcher, dir_path::String)
        launcher.ampltxt = AmplTxt.read(dir_path)
    end
    
    function add_uncertainties(launcher::Launcher, name::String, bus_name::String, ech::DateTime, ts::DateTime, value)
        launcher.uncertainties[name, bus_name, ech, ts] = value
    end
end
