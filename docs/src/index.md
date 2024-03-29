```@meta
CurrentModule = CodeSearch
```

# CodeSearch.jl

[CodeSearch.jl](https://github.com/LilithHafner/CodeSearch.jl) is a package for semantically searching Julia code. Unlike plain string search
and regex search, CodeSearch performs search operations _after_ parsing. Thus the search
patterns `j"a + b"` and `j"a+b"` are equivalent, and both match the code `a +b`.

```jldoctest intro
julia> using CodeSearch

julia> j"a + b" == j"a+b"
true

julia> findfirst(j"a+b", "sqrt(a +b)/(a+ b)")
6:9
```

The other key feature in this package is wildcard matching. You can use the character `*` to
match any expression. For example, the pattern `j"a + *"` matches both `a + b` and
`a + (b + c)` .

```jldoctest intro
julia> Expr.(eachmatch(j"a + *", "a + (a + b), a + sqrt(2)"))
3-element Vector{Expr}:
 :(a + (a + b))
 :(a + b)
 :(a + sqrt(2))
```

Here we can see that `j"a + *"` matches multiple places, even some that nest within
eachother!

Finally, it is possible to extract the "captured values" that match the wildcards.

```jldoctest intro
julia> m = match(j"a + *", "a + (a + b), a + sqrt(2)")
CodeSearch.Match((call-i a + (call-i a + b)), captures=[(call-i a + b)])

julia> m.captures
1-element Vector{JuliaSyntax.SyntaxNode}:
 (call-i a + b)

julia> Expr(only(m.captures))
:(a + b)
```

## How to use this package

1. Create [`Pattern`](@ref CodeSearch.Pattern)s with the [`@j_str`](@ref) macro or the
    [`CodeSearch.pattern`](@ref) function.
2. Search an `AbstractString` or a `JuliaSyntax.SyntaxNode` for whether and where that
    pattern occurs with generic functions like `occursin`, `findfirst`, `findlast`, or
    `findall` _OR_ extract the actual [`Match`](@ref CodeSearch.Match)es with generic functions like `eachmatch` and
    `match`.
3. If you extracted an actual match, access relevant information using the public
    `syntax_node` and `captures` fields, convert to a `SyntaxNode`, `Expr`, or
    `AbstractString` via constructors, index into the captures directly with `getindex`, or
    extract the indices in the original string that match the capture with
    [`indices`](@ref).

## Reference

- [`@j_str`](@ref)
- [`CodeSearch.pattern`](@ref)
- [`CodeSearch.Pattern`](@ref)
- [`CodeSearch.Match`](@ref)
- [`indices`](@ref)
- [Generic functions](@ref)

The following are manually selected docstrings

```@docs
@j_str
CodeSearch.pattern
CodeSearch.Pattern
CodeSearch.Match
indices
```
### Generic functions

Many functions that accept `Regex`s also accept `CodeSearch.Pattern`s and behave according
to their generic docstrings. Here are some of those supported functions:

- `findfirst`
- `findlast`
- `findall`
- `eachmatch`
- `match`
- `occursin`

## Performance

The code search performance bottleneck is parsing. The search itself is about 20x faster
than parsing and similar in performance to an optimized regex library. Consequently, if you
want high performance repeated code search, you should cache parsed SyntaxNodes and pass
them directly to search functions.

#### Benchmarks

Using the [395 lines of source code of this package as of 6820e64232](https://github.com/LilithHafner/CodeSearch.jl/blob/6820e642320f803407bcbc07e691277dc4d91ae4/src/CodeSearch.jl)
as a test case, on a 2022 M2 mac running [Asahi Linux](https://asahilinux.org/), we can see the following performance:

| Operation              | Time         | Time per line | Benchmark |
|------------------------|--------------|-------------|-------------|
| Searching a string     | `541.0 μs` | `1.37 μs`  | `@b collect(eachmatch(j"* !== nothing", node)) seconds=1` |
| Parsing a string       | `516.8 μs` | `1.31 μs`  | `@b parseall(SyntaxNode, str, ignore_errors=true) seconds=1` |
| Searching a SyntaxNode | `20.9 μs`  | `53.0 ns` | `@b collect(eachmatch(j"* !== nothing", node)) seconds=1` |
| Regex search           | `22.7 μs`  | `57.5 ns` | `@b collect(eachmatch(r".* !== nothing", str)) seconds=1` |

#### Setup for benchmarks
```julia
shell> git clone https://github.com/LilithHafner/CodeSearch.jl CodeSearch
[...]

shell> cd CodeSearch

shell> git checkout 6820e642320f803407bcbc07e691277dc4d91ae4
[...]

julia> using CodeSearch, JuliaSyntax, Chairmarks

julia> str = read("src/CodeSearch.jl", String);

julia> node = parseall(SyntaxNode, str, ignore_errors=true);
```

## Credits

Lilith Hafner is the original author of this package. CodeSearch.jl would not exist without
Claire Foster's [JuliaSyntax](https://github.com/JuliaLang/JuliaSyntax.jl/) which does all
the parsing and provides appropriate data structures to represent parsed code.
