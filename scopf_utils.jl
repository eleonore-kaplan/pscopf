
module SCOPFutils

import Logging
import LoggingExtras

function pretty_print(d::Dict; spacing=1, sort_p::Bool=false)
    d_l = d
    if sort_p
        d_l = sort(d)
    end
    for (k,v) in d_l
        if typeof(v) <: Dict
            str_k = "$(repr(k)) => "
            println(join(fill(" ", spacing)), str_k)
            pretty_print(v, spacing=spacing+1+length(str_k), sort_p=sort_p)
        else
            println(join(fill(" ", spacing)), k, " => ", v)
        end
    end
    nothing
end

"""
    Sets a two-logger TeeLogger as the global_logger:
    - the current logger
    - a logger to a file with debug minimum level

# Arguments
- `dir_p` : directory to which the log file will be created
"""
function init_logging(dir_p)
    """
    formats output to only print source_info for level > Warn
    """
    function logger_metafmt(level::Logging.LogLevel, _module, group, id, file, line)
        @nospecialize
        color = Logging.default_logcolor(level)
        prefix = string(level == Logging.Warn ? "Warning" : string(level), ':')
        suffix::String = ""
        level < Logging.Warn && return color, prefix, suffix
        _module !== nothing && (suffix *= "$(_module)")
        if file !== nothing
            _module !== nothing && (suffix *= " ")
            suffix *= Base.contractuser(file)::String
            if line !== nothing
                suffix *= ":$(isa(line, UnitRange) ? "$(first(line))-$(last(line))" : line)"
            end
        end
        !isempty(suffix) && (suffix = "@ " * suffix)
        return color, prefix, suffix
    end

    log_file = joinpath(dir_p, "execution.log")
    file_logger = Logging.ConsoleLogger(open(log_file, "w"), Logging.Debug, meta_formatter=logger_metafmt)
    #file_logger = LoggingExtras.MinLevelLogger(LoggingExtras.FileLogger(log_file), Logging.Debug) #print souce_info at each log line
    logger = LoggingExtras.TeeLogger(Logging.current_logger(), file_logger)

    Base.global_logger(logger)
end

end #module SCOPFutils
