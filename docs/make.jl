using CodeSearch
using Documenter

DocMeta.setdocmeta!(CodeSearch, :DocTestSetup, :(using CodeSearch); recursive=true)

makedocs(;
    modules=[CodeSearch],
    authors="Lilith Orion Hafner <lilithhafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/CodeSearch.jl/blob/{commit}{path}#{line}",
    sitename="CodeSearch.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/CodeSearch.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/CodeSearch.jl",
    devbranch="main",
)
