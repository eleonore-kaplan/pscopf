itools_path=raw"D:\AppliRTE\repo\naza-mpc\powsybl\bin\itools"

# convert-network --input-file --output-file ampl --output-format AMPL

root_path = raw"D:\AppliRTE\repo\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);

include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "SCOPF.jl"));
include(joinpath(root_path, "ProductionUnits.jl"));
include(joinpath(root_path, "FakeData.jl"));

