root_path = raw"D:\AppliRTE\repo\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);

include(joinpath(root_path, "AmplTxt.jl"));
include(joinpath(root_path, "SCOPF.jl"));
include(joinpath(root_path, "ProductionUnits.jl"));
include(joinpath(root_path, "FakeData.jl"));


include(joinpath(root_path, "AmplTxt.jl"));
# Compute ptdf and export them as node branch value file

# test_name = "RC_PPE2035_S0_deboucle"
test_name = "5buses_wind"

amplTxt = AmplTxt.read(test_name);
test_path = joinpath(root_path, test_name)
network = SCOPF.Network(amplTxt);

ref_bus = 1 ;
B = SCOPF.get_B(network, 1e-6);
Binv = SCOPF.get_B_inv(B, ref_bus);
PTDF = SCOPF.get_PTDF(network, Binv, ref_bus);


PTDF_TRIMMER = 1e-6;

# println(PTDF);
file_path =  joinpath(test_path, "ptdf.txt")
SCOPF.write_PTDF(file_path, network, ref_bus, PTDF, PTDF_TRIMMER)