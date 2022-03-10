module PSCOPFDocs

using Documenter, PSCOPF

format = Documenter.HTML(
    prettyurls = false,
)

pages = Any[
            "Home" => "index.md",

            "Introduction" => Any[
                "Introduction" => "0_intro/1_introduction.md",
                "Glossaire" => "0_intro/2_glossaire.md",
               ],

            "Description" => Any[
                "Architecture et Design" => "1_description/1_architecture.md",
                "Sequence" => "1_description/2_sequence.md",
               ],

           "Modèles" => Any[
               "Notations" => "2_modeles/0_notations.md",
               "Modèles du marché" => Any[
                   "Marché de L'Energie avant FO" => Any[
                        "Le Problème" => "2_modeles/1_marche/1_marche_de_energie_avant_fo/1_problem.md",
                        "Les Variables et Les Contraintes" => "2_modeles/1_marche/1_marche_de_energie_avant_fo/2_vars_and_cstrs.md",
                        "L'objectif" => "2_modeles/1_marche/1_marche_de_energie_avant_fo/3_objective.md"
                        ],

                   "Marché de L'Energie à la FO" => Any[],
                   ],

                "Modèles du TSO" => Any[
                    "Mode 1 (ANCIEN)" => Any[
                        "Problem Description" => "2_modeles/2_tso/1_mode_1/1_problem.md",
                        "Variables" => "2_modeles/2_tso/1_mode_1/2_variables.md",
                        "Constraints" => "2_modeles/2_tso/1_mode_1/3_constraints.md",
                        "Objective" => "2_modeles/2_tso/1_mode_1/4_objective.md",
                        ],
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
