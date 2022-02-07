include("./bo/networks/Networks.jl")
include("../AmplTxt.jl")
include("./data/DataToNetwork.jl")

using .Networks
using .Data

### TESTS

# Initialisatin d'un reseau
# network = Networks.Network("test") # pas moyen d'appeler le constructeur sans rappeler le module, malgre le using...
# add_new_buses!(network, [1,2,3,4,5])
# add_new_branches!(network, [(1,2), (1,4), (1,5), (2,3), (3,4), (4,5)])

# load network
network = data2network("5buses_wind")

