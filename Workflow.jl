module Workflow
    export Launcher;
    export read_ampl_txt;
    export read_uncertainties;
    export read_ptdf;
    export read_units;
    export get_program;
    export apply_market;
    export apply_scopf;

    using ..AmplTxt;
    using ..ProductionUnits;

    mutable struct Launcher
        ampltxt;
        uncertainties;
        units;
    end

    function Launcher(dir_path::String)
        uncertainties_path = joinpath(dir_path, "all_uncertainties.txt")
        units_path = joinpath(dir_path, "all_units.txt")
        return Launcher(
            AmplTxt.read(dir_path), 
            ProductionUnits.read_uncertainties(uncertainties_path), 
            ProductionUnits.read_units(units_path)
            )
    end

    function read_ampl_txt(launcher::Launcher, dir_path::String)
        launcher.ampltxt = AmplTxt.read(dir_path)
    end
        
    function read_uncertainties(launcher::Launcher, dir_path::String)
    end

    function read_ptdf(launcher::Launcher, dir_path::String)
    end

    function read_units(launcher::Launcher, dir_path::String)
    end

    function get_program(launcher::Launcher)
    end
    
    function apply_market(launcher::Launcher)
    end
    
    function apply_scopf(launcher::Launcher)
    end
end
