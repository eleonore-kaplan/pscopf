
module SCOPFutils

function pretty_print(d::Dict, spacing=1)
    for (k,v) in d
        if typeof(v) <: Dict
            str_k = "$(repr(k)) => "
            println(join(fill(" ", spacing)), str_k)
            pretty_print(v, spacing+1+length(str_k))
        else
            println(join(fill(" ", spacing)), k, " => ", v)
        end
    end
    nothing
end

end #module SCOPFutils
