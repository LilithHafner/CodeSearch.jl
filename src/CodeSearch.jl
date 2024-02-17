module CodeSearch

using JuliaSyntax

export code_search_pattern, @j_str, indices

"""
    Pattern <: AbstractPattern

A struct that represents a julia expression with holes. The expression is stored as an
ordinary `JuliaSyntax.SyntaxNode` in the `syntax_node` field. Holes in that expression are
represented by the symbol stored in the `hole` field. For example, the expression
`a + (b + *)` might be stored as `Pattern((call-i a + (call-i b + hole)), :hole)`. When
matching `Pattern`s, it is possilbe for multiple matches to nest within one another.

See [`@j_str`](@ref) and [`code_search_pattern`](@ref) for the public API for creating
`Pattern`s.

Methods accepting `Pattern` objects are defined for `eachmatch`, `match`,
`findall`, `findfirst`, `findlast`, `occursin`, and `count`.
"""
struct Pattern <: AbstractPattern
    syntax_node::SyntaxNode
    hole_symbol::Symbol
end

"""
    gen_hole(str, prefix="hole")

return a string starting with `prefix` that is not in `str`
"""
function gen_hole(str, prefix="hole")
    occursin(prefix, str) || return prefix
    i = 1
    while occursin("$prefix$i", str)
        i += 1
    end
    "$prefix$i"
end

"""
    code_search_pattern(str::AbstractString) -> Pattern

Function version of the `j"str"` macro. See [`@j_str`](@ref) for documentation.

# Examples
```julia
julia> code_search_pattern("a + (b + *)")
j"a + (b + *)"

julia> match(code_search_pattern("(b + *)"), "(b + 6)")
CodeSearch.Match((call-i b + 6), holes=[6])

julia> match(code_search_pattern("(* + *) \\\\* *"), "(a+b)*(d+e)")
CodeSearch.Match((call-i (call-i a + b) * (call-i d + e)), holes=[a, b, (call-i d + e)])

julia> findall(code_search_pattern("* + *"), "(a+b)+(d+e)")
3-element Vector{UnitRange{Int64}}:
 1:11
 2:4
 8:10

julia> match(code_search_pattern("(* + *) \\\\* *"), "(a-b)*(d+e)") # no match -> returns nothing

julia> occursin(code_search_pattern("(* + *) \\\\* *"), "(a-b)*(d+e)")
false

julia> eachmatch(code_search_pattern("*(\\"hello world\\")"), "print(\\"hello world\\"), display(\\"hello world\\")")
2-element Vector{CodeSearch.Match}:
 Match((call print (string "hello world")), holes=[print])
 Match((call display (string "hello world")), holes=[display])

julia> count(code_search_pattern("*(*)"), "a(b(c))")
2
"""
function code_search_pattern(str::AbstractString)
    hole_symbol = gen_hole(str)
    str = replace(str,
        r"^\*" => hole_symbol,
        r"([^\\])\*" => SubstitutionString("\\1$hole_symbol"),
        "\\*" => '*')
    # "a*b\\*chole1" => "ahole2b*chole1"

    syntax_node = parseall(SyntaxNode, str)
    if kind(syntax_node) == K"toplevel" && length(syntax_node.children) == 1
        syntax_node = only(syntax_node.children)
    end
    Pattern(syntax_node, Symbol(hole_symbol))
end

"""
    j"str" -> Pattern

Construct a `Pattern`, such as j"a + (b + *)" that matches Julia code.

The `*` character is a wildcard that matches any expression, and matching is performed
insensitive of whitespace and comments. Only the characters `"` and `*` must be escaped,
and interpolation is not supported.

See [`code_search_pattern`](@ref) for the function version of this macro if you need
interpolation.

# Examples
```julia
julia> j"a + (b + *)"
j"a + (b + *)"

julia> match(j"(b + *)", "(b + 6)")
CodeSearch.Match((call-i b + 6), holes=[6])

julia> match(j"(* + *) \\* *", "(a+b)*(d+e)")
CodeSearch.Match((call-i (call-i a + b) * (call-i d + e)), holes=[a, b, (call-i d + e)])

julia> findall(j"* + *", "(a+b)+(d+e)")
3-element Vector{UnitRange{Int64}}:
 1:11
 2:4
 8:10

julia> match(j"(* + *) \\* *", "(a-b)*(d+e)") # no match -> returns nothing

julia> occursin(j"(* + *) \\* *", "(a-b)*(d+e)")
false

julia> eachmatch(j"*(\\"hello world\\")", "print(\\"hello world\\"), display(\\"hello world\\")")
2-element Vector{CodeSearch.Match}:
 Match((call print (string "hello world")), holes=[print])
 Match((call display (string "hello world")), holes=[display])

julia> count(j"*(*)", "a(b(c))")
2
"""
macro j_str(str)
    code_search_pattern(str)
end

"""
    Match <: AbstractMatch

Represents a single match to a `Pattern`, typically created from the `eachmatch` or
`match` function.

The `syntax_node` field stores the `JuliaSyntax.SyntaxNode` that matched the
`Pattern`, and the `captures` field stores the `SyntaxNode`s that fill match each
wildcard in the `Pattern`, indexed in the order they appear in the `Pattern`.

Methods that accept `Match` objects are defined for [`Expr`], [`JuliaSyntax.SyntaxNode`],
[`String`], [`indices`](@ref), and [`getindex`].

# Examples
```julia
julia> m = match(j"√*", "2 + √ x")
CodeSearch.Match((call-pre √ x), captures=[x])

julia> m.captures
1-element Vector{JuliaSyntax.SyntaxNode}:
 x

julia> m[1]
line:col│ tree        │ file_name
   1:7  │x

julia> Expr(m)
:(√x)

julia> String(m)
" √ x"

julia> CodeSearch.indices(m)
4:9
```
"""
struct Match <: AbstractMatch
    syntax_node::SyntaxNode
    captures::Vector{SyntaxNode}
end

find_matches(needle::Pattern, haystack::AbstractString) =
    find_matches(needle, parseall(SyntaxNode, haystack, ignore_errors=true))

find_matches(needle::Pattern, haystack::SyntaxNode) =
    find_matches!(Match[], SyntaxNode[], needle, haystack)
function find_matches!(matches, captures, needle::Pattern, haystack::SyntaxNode)
    if is_match!(empty!(captures), needle.hole_symbol, needle.syntax_node, haystack)
        push!(matches, Match(haystack, copy(captures)))
    end
    if haystack.children !== nothing
        for child in haystack.children
            find_matches!(matches, captures, needle, child)
        end
    end
    matches
end

function is_match!(captures, hole_symbol::Symbol, needle::SyntaxNode, haystack::SyntaxNode)
    if kind(needle) == K"Identifier" && needle.data.val == hole_symbol
        push!(captures, haystack)
        return true
    end
    kind(needle) == kind(haystack) || return false
    needle.data.val == haystack.data.val || return false
    needle.children === haystack.children && return true
    needle.children === nothing && return false
    haystack.children === nothing && return false
    axes(needle.children) == axes(haystack.children) || return false
    all(is_match!(captures, hole_symbol, n, h) for (n,h) in zip(needle.children, haystack.children))
end

maybe_first(x) = isempty(x) ? nothing : first(x)
maybe_last(x) = isempty(x) ? nothing : last(x)


"""
    indices(m)

Return the indices of a source datastructure that a view is derived from.

# Examples
```julia
julia> m = match(j"x/*", "4 + x/2")
CodeSearch.Match((call-i x / 2), captures=[2])

julia> indices(m)
4:7

julia> c = m[1]
line:col│ tree        │ file_name
   1:7  │2


julia> indices(c)
7:7
"""
function indices end

# I don't like JuliaSyntax's choice to overload the generic Base.range function for this.
indices(sn::SyntaxNode) = range(sn)
indices(m::Match) = indices(m.syntax_node)

Base.Expr(m::Match) = Expr(m.syntax_node)
Base.String(m::Match) = m.syntax_node.data.source.code[indices(m.syntax_node)]
Base.getindex(m::Match, i::Int) = m.captures[i]

Base.eachmatch(needle::Pattern, haystack) = find_matches(needle, haystack)
Base.match(needle::Pattern, haystack) = maybe_first(eachmatch(needle, haystack))
Base.findall(needle::Pattern, haystack) = indices.(eachmatch(needle, haystack))
Base.occursin(needle::Pattern, haystack) = !isempty(eachmatch(needle, haystack))

Base.findfirst(needle::Pattern, haystack) = maybe_first(findall(needle, haystack))
Base.findlast(needle::Pattern, haystack) = maybe_last(findall(needle, haystack))

# Narrow type signatures to avoid ambiguity with
# count(f, A::Union{Base.AbstractBroadcasted, AbstractArray}; dims, init)
# count(t::Union{AbstractPattern, AbstractChar, AbstractString}, s::AbstractString; overlap)
Base.count(needle::Pattern, haystack) = length(eachmatch(needle, haystack))

# Resolve Ambiguities
Base.count(needle::Pattern, haystack::AbstractString) = length(eachmatch(needle, haystack))
Base.findall(needle::Pattern, haystack::AbstractString) = indices.(eachmatch(needle, haystack))

# TODO: semantic equality between Patterns

# Display

function Base.show(io::IO, m::Pattern)
    print(io, "j\"")
    str = sprint(print, Expr(m.syntax_node))
    str = replace(str, '*' => "\\*", string(m.hole_symbol) => '*')
    print(io, str)
    print(io, "\"")
end

function Base.show(io::IO, m::Match)
    if get(io, :typeinfo, nothing) != Match
        print(io, "CodeSearch.")
    end
    print(io, "Match(")
    show(io, m.syntax_node)
    if !isempty(m.captures)
        print(io, ", captures=")
        show(IOContext(io, :typeinfo=>Vector{SyntaxNode}), m.captures)
    end
    print(io, ")")
end

end # module
