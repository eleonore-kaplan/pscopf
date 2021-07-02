root_path = "D:\\AppliRTE\\repo\\scopf-quanti"
push!(LOAD_PATH, root_path);
cd(root_path);
include(joinpath(root_path, "AmplTxt.jl"));

include(joinpath(root_path, "SCOPF.jl"));

amplTxt = AmplTxt.read(".");

network = SCOPF.Network();
SCOPF.add_bus!(network, amplTxt);
SCOPF.add_branches!(network, amplTxt);

B = SCOPF.get_B(network, 1e-6)
Binv = SCOPF.get_B_inv(B, 1);