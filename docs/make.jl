using Documenter, PSCOPF

module PSCOPFDocs

using Documenter

format = Documenter.HTML(
    prettyurls = false,
)

pages = Any[
            "Home" => "index.md",

            "Descriptions" => Any[
                "Introduction" => "0_descriptions/1_introduction.md",
                "Glossaire" => "0_descriptions/2_glossaire.md",
                "Architecture" => "0_descriptions/3_architecture.md",
               ],

           "Modèles" => Any[
                "Modèles du TSO" => Any[
                    "Général" => Any[],
                    "Mode 1" => Any[
                        "Problem Description" => "1_models/1_pscopf_model/1_mode_1/1_problem.md",
                        "Variables" => "1_models/1_pscopf_model/1_mode_1/2_variables.md",
                        "Constraints" => "1_models/1_pscopf_model/1_mode_1/3_constraints.md",
                        "Objective" => "1_models/1_pscopf_model/1_mode_1/4_objective.md",
                        ],
                    ],

                "Modèles du marché" => Any[
                    "Général" => Any[],
                    "Mode 1" => Any[],
                    ],

                ],

            "Library" => Any[
                "PSCOPF" => "lib/pscopf.md",
                ],
]

end # PSCOPFDocs

makedocs(modules = [PSCOPF],
        sitename="PSCOPF",
        format = PSCOPFDocs.format,
        pages = PSCOPFDocs.pages,
        )
