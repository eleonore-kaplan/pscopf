
struct SequenceGenerator
    grid::Grid #Not used for now (but potentially we can have specific operations at DMO horizons)
    target_timepoints::Vector{Dates.DateTime}
    horizon_timepoints::Vector{Dates.DateTime}
    management_mode::ManagementMode

    sequence::Sequence
end
function SequenceGenerator(grid::Grid,
                            target_timepoints::Vector{Dates.DateTime},
                            horizon_timepoints::Vector{Dates.DateTime},
                            management_mode::ManagementMode)
    return SequenceGenerator(grid, target_timepoints, horizon_timepoints, management_mode, Sequence())
end

function reset!(seq_generator)
    empty!(seq_generator.sequence)
end

function empty!(sequence::Sequence) error("unimplemented") end
function add_step!(sequence::Sequence, step::Step, step_order) error("unimplemented") end

#Sequence is executed in the order specified by step_order than by insertion order
# example :
#   add_step(seq_gen, step1, "1")
#   add_step(seq_gen, step2, "2")
#   add_step(seq_gen, step3, "3")
#   add_step(seq_gen, step1_2, "1")
#   add_step(seq_gen, step0, "0")
# => [step0, [step1, step1_2], step2, step3]
# step0 is added last but executed first
# step1 and step1_2 have the same order : step1 is added first so step 1 will be executed first
#Alternatively simply have steps and explicitly implement a step to increment time if needed
function add_step!(seq_generator::SequenceGenerator, step::Step, step_order)
    add_step!(seq_generator.sequence, step, step_order)
end

function launch!(seq_generator::SequenceGenerator)
    if seq_generator.management_mode == PSCOPF_MODE_1
        return gen_seq_mode1!(seq_generator)
        
    elseif seq_generator.management_mode == PSCOPF_MODE_2
        error("unimplemented")
    elseif seq_generator.management_mode == PSCOPF_MODE_3
        error("unimplemented")
    end 
    error("unsuppported mode : ", seq_generator.management_mode)
end

##########################################################################################################
#                            PARTIE IMPORTANTE :
##########################################################################################################
function generate_sequence(grid::Grid, target_timepoints::Vector{Dates.DateTime},
                            horizon_timepoints::Vector{Dates.DateTime}, management_mode::ManagementMode)
    generator = SequenceGenerator(grid, target_timepoints, horizon_timepoints, management_mode)
    return launch!(generator)
end

function gen_seq_mode1!(seq_generator)
    reset!(seq_generator)
    fo_startpoint = seq_generator.target_timepoints[1] - seq_generator.management_mode.fo
    
    for ech in seq_generator.horizon_timepoints
        
        if ech < fo_startpoint
            add_step!(seq_generator, MarketMode1OutFO, ech) #MarketMode1OutFO ~ Marché d'energie
            add_step!(seq_generator, TSOMode1, ech)
        
        else
            add_step!(seq_generator, MarketMode1InFO, ech) #MarketMode1InFO ~ Marché d'équilibrage
            add_step!(seq_generator, TSOMode1, ech)
        end

    end
    add_step!(seq_generator, Assessment, seq_generator.horizon_timepoints[end])

    return seq_generator.sequence
end

##########################################################################################################
##########################################################################################################


#alternative 
function gen_seq_mode1!(seq_generator)
    reset!(seq_generator)
    fo_startpoint = seq_generator.target_timepoints[1] - seq_generator.management_mode.fo
    
    for ech in seq_generator.horizon_timepoints
        
        if ech < fo_startpoint
            add_step!(seq_generator, MarketMode1OutFO)
            add_step!(seq_generator, TSOMode1)
        
        else
            add_step!(seq_generator, MarketMode1InFO)
            add_step!(seq_generator, TSOMode1)
        end
        
        add_step!(seq_generator, IncrementEch)
    end
    add_step!(seq_generator, Assessment, seq_generator.horizon_timepoints[end])

    return seq_generator.sequence
end

