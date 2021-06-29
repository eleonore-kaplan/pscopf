

function split_with_space(str::String)
    result = String[]
    if length(str) > 0
        start_with_quote = startswith(str, "\"")
        buffer_quote = split(str, keepempty=false, "\"")
        i = 1
        while i <= length(buffer_quote) 
            if i > 1 || !start_with_quote
                str2 = buffer_quote[i]
                buffer_space = split(str2, keepempty=false)
                for str3 in buffer_space
                    push!(result, str3)
                end
                i += 1
            end
            if i <= length(buffer_quote)
                push!(result, buffer_quote[i])
                i += 1
            end
        end
    end    
    return result
end

cd("D:\\AppliRTE\\PROJET\\eod_rso");
splitted_lines = Vector{String}[]
open("test1.txt") do file
    for ln in eachline(file)
        push!(splitted_lines, split_with_space(ln))
        # println()
        # println("$(length(ln)), $(ln)")
        # println(split(ln, keepempty=false, "\""))
        # println(ln, " gives : ", split_with_space(ln))
    end
end
println(splitted_lines)