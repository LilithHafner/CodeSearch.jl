module CodeSearch

using JuliaSyntax, Compat

export @j_str, indices
@compat public Match, Pattern, pattern

############################################################################################
#### Data structures and constructors (Match, Pattern, pattern, and @j_str)             ####
############################################################################################

"""
    struct Match <: AbstractMatch
        syntax_node::JuliaSyntax.SyntaxNode
        captures::Vector{JuliaSyntax.SyntaxNode}
    end

Represents a single match to a [`Pattern`](@ref), typically created from the `eachmatch` or
`match` function.

The `syntax_node` field stores the `SyntaxNode` that matched the
[`Pattern`](@ref) and the `captures` field stores the `SyntaxNode`s that fill match each
wildcard in the [`Pattern`](@ref), indexed in the order they appear.

Methods that accept `Match` objects are defined for `Expr`, `SyntaxNode`,
`AbstractString`, [`indices`](@ref), and `getindex`.

# Examples
```jldoctest
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

julia> AbstractString(m)
" √ x"

julia> CodeSearch.indices(m)
4:9
```
"""
struct Match <: AbstractMatch
    syntax_node::SyntaxNode
    captures::Vector{SyntaxNode}
end

"""
    Pattern <: AbstractPattern

A struct that represents a Julia expression with wildcards. When matching `Pattern`s, it is
possilbe for multiple matches to nest within one another.

The fields and constructor of this struct are not part of the public API. See
[`@j_str`](@ref) and [`pattern`](@ref) for the public API for creating
`Pattern`s.

Methods accepting `Pattern` objects are defined for `eachmatch`, `match`,
`findall`, `findfirst`, `findlast`, `occursin`, and `count`.

# Extended Help

The following are implmenetation details:

The expression is stored as an ordinary `SyntaxNode` in the internal
`syntax_node` field. Wildcards in that expression are represented by the symbol stored in
the internal `wildcard_symbol` field. For example, the expression `a + (b + *)` might be stored
as `Pattern((call-i a + (call-i b + wildcard)), :wildcard)`.
"""
struct Pattern <: AbstractPattern
    _internal::NamedTuple{(:syntax_node, :wildcard_symbol), Tuple{SyntaxNode, Symbol}}
    global _Pattern
    _Pattern(syntax_node, wildcard_symbol) = new((; syntax_node, wildcard_symbol))
end

"""
    j"str" -> Pattern

Construct a `Pattern`, such as `j"a + (b + *)"` that matches Julia code.

The `*` character is a wildcard that matches any expression, and matching is performed
insensitive of whitespace and comments. Only the characters `"` and `*` must be escaped,
and interpolation is not supported.

See [`pattern`](@ref) for the function version of this macro if you need
interpolation.

# Examples
```jldoctest
julia> j"a + (b + *)"
j"a + (b + *)"

julia> match(j"(b + *)", "(b + 6)")
CodeSearch.Match((call-i b + 6), captures=[6])

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
 Match((call print (string "hello world")), captures=[print])
 Match((call display (string "hello world")), captures=[display])

julia> count(j"*(*)", "a(b(c))")
2

julia> match(j"(* + *) \\* *", "(a+b)*(d+e)")
CodeSearch.Match((call-i (call-i a + b) * (call-i d + e)), captures=[a, b, (call-i d + e)])
```
"""
macro j_str(str)
    pattern(str)
end

"""
    pattern(str::AbstractString) -> Pattern

Function version of the `j"str"` macro. See [`@j_str`](@ref) for documentation.

# Examples
```jldoctest
julia> using CodeSearch: pattern

julia> pattern("a + (b + *)")
j"a + (b + *)"

julia> match(pattern("(b + *)"), "(b + 6)")
CodeSearch.Match((call-i b + 6), captures=[6])

julia> findall(pattern("* + *"), "(a+b)+(d+e)")
3-element Vector{UnitRange{Int64}}:
 1:11
 2:4
 8:10

julia> match(pattern("(* + *) \\\\* *"), "(a-b)*(d+e)") # no match -> returns nothing

julia> occursin(pattern("(* + *) \\\\* *"), "(a-b)*(d+e)")
false

julia> eachmatch(pattern("*(\\"hello world\\")"), "print(\\"hello world\\"), display(\\"hello world\\")")
2-element Vector{CodeSearch.Match}:
 Match((call print (string "hello world")), captures=[print])
 Match((call display (string "hello world")), captures=[display])

julia> count(pattern("*(*)"), "a(b(c))")
2

julia> match(pattern("(* + *) \\\\* *"), "(a+b)*(d+e)")
CodeSearch.Match((call-i (call-i a + b) * (call-i d + e)), captures=[a, b, (call-i d + e)])
```
"""
function pattern(str::AbstractString)
    str, wildcard_str = prepare_wildcards(str)

    syntax_node = parseall(SyntaxNode, str)
    if kind(syntax_node) == K"toplevel" && length(syntax_node.children) == 1
        syntax_node = only(syntax_node.children)
    end
    _Pattern(syntax_node, Symbol(wildcard_str))
end


############################################################################################
####  Implmenetation of primary search functionality                                    ####
############################################################################################

"""
    prepare_wildcards(str) -> (new_str, wildcard_str)


Replace `*` with an identifier that does not occur in `str` (preferrably `"wildcard"`) and
return the new string and the identifier. `*` may be escaped, and the new identifier is
padded with spaces only when necessary to prevent it from parsing together with characters
before or after it.
"""
function prepare_wildcards(str)
    wildcard_str = gen_wildcard(str)
    old = Vector{Char}(str) # Why be fast when you could be slow instead?
    new = resize!(similar(old), 0)
    wildcard_array = Vector{Char}(string(wildcard_str))
    for i in eachindex(old)
        char = old[i]
        if char == '*'
            if i == firstindex(old) || old[i-1] != '\\'
                # Insert wildcard
                if !isempty(new) && Base.is_id_char(last(new))
                    # Add a space to separate the wildcard from the previous identifier
                    # character and avoid something like a* -> awildcard
                    push!(new, ' ')
                end
                append!(new, wildcard_array)
                if i+1 <= lastindex(old) && Base.is_id_char(old[i+1])
                    push!(new, ' ')
                end
            else
                # Escaped *, replace the \ with a *
                new[end] = char
            end
        else
            push!(new, char)
        end
    end
    join(new), wildcard_str
end

"""
    gen_wildcard(str, prefix="wildcard")

return a string starting with `prefix` that is not in `str`
"""
function gen_wildcard(str, prefix="wildcard")
    occursin(prefix, str) || return prefix
    i = 1
    while occursin("$prefix$i", str)
        i += 1
    end
    "$prefix$i"
end

find_matches(needle::Pattern, haystack::AbstractString) =
    find_matches(needle, parseall(SyntaxNode, haystack, ignore_errors=true))

find_matches(needle::Pattern, haystack::SyntaxNode) =
    find_matches!(Match[], SyntaxNode[], needle, haystack)
function find_matches!(matches, captures, needle::Pattern, haystack::SyntaxNode)
    if is_match!(empty!(captures), needle._internal.wildcard_symbol, needle._internal.syntax_node, haystack)
        push!(matches, Match(haystack, copy(captures)))
    end
    if haystack.children !== nothing
        # Type annotation improves performance because the compiler cannot infer this
        # type despite the fieldtype of children being Union{Nothing, Vector{SyntaxNode}}.
        for child in haystack.children::Vector{SyntaxNode}
            find_matches!(matches, captures, needle, child)
        end
    end
    matches
end

function is_match!(captures, wildcard_symbol::Symbol, needle::SyntaxNode, haystack::SyntaxNode)
    if kind(needle) == K"Identifier" && needle.data.val == wildcard_symbol
        push!(captures, haystack)
        return true
    end
    kind(needle) == kind(haystack) || return false

    # Use === instead of == for performance because val is typed Any but is
    # almost always Symbol or Nothing, which use the ==(a,b) = a === b fallback.
    # This branch hints the compiler to specialize for those types and use egality.
    if needle.data.val isa Union{Symbol, Nothing} && haystack.data.val isa Union{Symbol, Nothing}
        needle.data.val === haystack.data.val || return false
    else
        needle.data.val == haystack.data.val || return false
    end

    needle.children === haystack.children && return true
    needle.children === nothing && return false
    haystack.children === nothing && return false
    axes(needle.children) == axes(haystack.children) || return false

    # Type annotations improve performance because the compiler cannot infer these
    # types despite the fieldtype of children being Union{Nothing, Vector{SyntaxNode}}.
    all(is_match!(captures, wildcard_symbol, n, h) for (n,h) in
        zip(needle.children::Vector{SyntaxNode}, haystack.children::Vector{SyntaxNode}))
end

maybe_first(x) = isempty(x) ? nothing : first(x)
maybe_last(x) = isempty(x) ? nothing : last(x)


############################################################################################
### Methods for generic functions (and the definition of the generic function `indices`) ###
############################################################################################

"""
    indices(m)

Return the indices into a source datastructure that a view is derived from.

# Examples
```jldoctest
julia> m = match(j"x/*", "4 + x/2")
CodeSearch.Match((call-i x / 2), captures=[2])

julia> indices(m)
4:7

julia> c = m[1]
line:col│ tree        │ file_name
   1:7  │2


julia> indices(c)
7:7
```
"""
function indices end

# I don't like JuliaSyntax's choice to overload the generic Base.range function for this.
indices(sn::SyntaxNode) = range(sn)
indices(m::Match) = indices(m.syntax_node)

Base.Expr(m::Match) = Expr(m.syntax_node)
Base.AbstractString(m::Match) = m.syntax_node.data.source.code[indices(m.syntax_node)]
Base.getindex(m::Match, i::Int) = m.captures[i]

Base.eachmatch(needle::Pattern, haystack) = find_matches(needle, haystack)

Base.match(needle::Pattern, haystack) = maybe_first(eachmatch(needle, haystack))
Base.occursin(needle::Pattern, haystack) = !isempty(eachmatch(needle, haystack))
Base.findall(needle::Pattern, haystack) = indices.(eachmatch(needle, haystack))
Base.findfirst(needle::Pattern, haystack) = maybe_first(findall(needle, haystack))
Base.findlast(needle::Pattern, haystack) = maybe_last(findall(needle, haystack))
Base.count(needle::Pattern, haystack) = length(eachmatch(needle, haystack))

# Resolve Ambiguities
Base.count(needle::Pattern, haystack::AbstractString) = length(eachmatch(needle, haystack))
Base.findall(needle::Pattern, haystack::AbstractString) = indices.(eachmatch(needle, haystack))

# Display

function Base.show(io::IO, m::Pattern)
    print(io, "j\"")
    str = sprint(print, Expr(m._internal.syntax_node))
    str = replace(str, '*' => "\\*")
    str = replace(str, string(m._internal.wildcard_symbol) => '*')
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

# Equality and hashing
# 10x slower than the default implementation (object identity) but it's semantically correct
# and folks can always use IdDict in the highly unlikley event that this is a bottleneck.
function Base.:(==)(a::Pattern, b::Pattern)
    kind(a._internal.syntax_node) == kind(b._internal.syntax_node) || return false
    if kind(a._internal.syntax_node) == K"Identifier"
        a_wildcard = a._internal.syntax_node.data.val == a._internal.wildcard_symbol
        b_wildcard = b._internal.syntax_node.data.val == b._internal.wildcard_symbol
        a_wildcard && b_wildcard && return true
        a_wildcard != b_wildcard && return false
    end
    a._internal.syntax_node.data.val == b._internal.syntax_node.data.val || return false
    a._internal.syntax_node.children === nothing && b._internal.syntax_node.children === nothing && return true
    a._internal.syntax_node.children === nothing && return false
    b._internal.syntax_node.children === nothing && return false
    axes(a._internal.syntax_node.children) == axes(b._internal.syntax_node.children) || return false
    all(_Pattern(a_child, a._internal.wildcard_symbol) == _Pattern(b_child, b._internal.wildcard_symbol) for
        (a_child,b_child) in zip(a._internal.syntax_node.children, b._internal.syntax_node.children))
end

const PATTERN_HASH = Sys.WORD_SIZE == 64 ? 0xc75fd9c0b0129c95 : 0x5770933b
const HOLE_HASH = Sys.WORD_SIZE == 64 ? 0x12e261218f8c027e : 0xf5e30575
Base.hash(p::Pattern, h::UInt) = _hash(p._internal.wildcard_symbol, p._internal.syntax_node, hash(h, PATTERN_HASH))
function _hash(wildcard_symbol, syntax_node, h)
    kind(syntax_node) == K"Identifier" && syntax_node.data.val == wildcard_symbol && return hash(h, HOLE_HASH)
    h = hash(kind(syntax_node), h)
    h = hash(syntax_node.data.val, h)
    syntax_node.children === nothing && return h
    h = hash(length(syntax_node.children), h)
    for child in syntax_node.children
        h = _hash(wildcard_symbol, child, h)
    end
    h
end

end # module
