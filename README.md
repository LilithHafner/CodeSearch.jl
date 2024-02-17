# CodeSearch

<!-- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LilithHafner.github.io/CodeSearch.jl/stable/) -->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LilithHafner.github.io/CodeSearch.jl/dev/)
[![Build Status](https://github.com/LilithHafner/CodeSearch.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LilithHafner/CodeSearch.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LilithHafner/CodeSearch.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LilithHafner/CodeSearch.jl)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CodeSearch.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/C/CodeSearch.html)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)


CodeSearch.jl is a package for semantically searching Julia code. Unlike plain string search
and regex search, CodeSearch performs search operations _after_ parsing. Thus the search
patterns `j"a + b"` and `j"a+b"` are equivalent, and both match the code `a +b`.

```julia
julia> using CodeSearch

julia> j"a + b" == j"a+b"
true

julia> findfirst(j"a+b", "sqrt(a +b)/(a+ b)")
6:9
```

The other key feature in this package is wildcard matching. You can use the character `*` to
match any expression. For example, the pattern `j"a + *"` matches both `a + b` and
`a + (b + c)` .

```julia
julia> Expr.(eachmatch(j"a + *", "a + (a + b), a + sqrt(2)"))
3-element Vector{Expr}:
 :(a + (a + b))
 :(a + b)
 :(a + sqrt(2))
```

Here we can see that `j"a + *"` matches multiple places, even some that nest within
eachother!

Finally, it is possible to extract the "captured values" that match the wildcards.

```julia
julia> m = match(j"a + *", "a + (a + b), a + sqrt(2)")
CodeSearch.Match((call-i a + (call-i a + b)), captures=[(call-i a + b)])

julia> m.captures
1-element Vector{JuliaSyntax.SyntaxNode}:
 (call-i a + b)

julia> Expr(only(m.captures))
:(a + b)
```

## How to use this package

1. Create `Pattern`s with the `@j_str` macro or the
    `CodeSearch.pattern` function.
2. Search an `AbstractString` or a `JuliaSyntax.SyntaxNode` for whether and where that
    pattern occurs with generic functions like `occursin`, `findfirst`, `findlast`, or
    `findall` _OR_ extract the actual `Match`es with generic functions like `eachmatch` and
    `match`.
3. If you extracted an actual match, access relevant information using the public
    `syntax_node` and `captures` fields, convert to a `SyntaxNode`, `Expr`, or
    `AbstractString` via constructors, index into the captures directly with `getindex`, or
    extract the indices in the original string that match the capture with
    `indices`.
