module TestHelpers
using Test

function safe_leq(a,b;atol=1e-6)
    return a <= (b + atol)
end

end #TestHelpers
