using Documenter, PSCOPF

module PSCOPFDocs

using Documenter

format = Documenter.HTML(
    prettyurls = false,
)

pages = Any[
            "Home" => "index.md",
            "Library" => Any[
                "PSCOPF" => "lib/pscopf.md",
                ],
            "Model" => Any[
                "Problem Description" => "model/1_problem.md",
                "Variables" => "model/2_variables.md",
                "Constraints" => "model/3_constraints.md",
                "Objective" => "model/4_objective.md",
                ],
]

end # PSCOPFDocs

makedocs(modules = [PSCOPF],
        sitename="PSCOPF",
        format = PSCOPFDocs.format,
        pages = PSCOPFDocs.pages,
        )
