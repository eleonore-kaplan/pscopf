using Documenter, Dummy

module DummyDocs

using Documenter

format = Documenter.HTML(
    prettyurls = false,
)

pages = Any[
            "Home" => "index.md",
            "Library" => Any[
                "Dummy" => "lib/dummy.md",
                ],
            "Model" => Any[
                "Problem Description" => "model/1_problem.md",
                "Variables" => "model/2_variables.md",
                "Constraints" => "model/3_constraints.md",
                "Objective" => "model/4_objective.md",
                ],
]

end # DummyDocs

makedocs(modules = [Dummy],
        sitename="PSCOPF",
        format = DummyDocs.format,
        pages = DummyDocs.pages,
        )
