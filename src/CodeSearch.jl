module CodeSearch

using JuliaSyntax

export SearchPattern, @j_str, holes

struct SearchPattern
    syntax_node::SyntaxNode
    hole::Symbol
end

function gen_hole(str, prefix="hole")
    occursin(prefix, str) || return prefix
    i = 1
    while occursin("$prefix$i", str)
        i += 1
    end
    "$prefix$i"
end

function SearchPattern(str::AbstractString)
    hole = gen_hole(str)
    str = replace(str,
        r"^\*" => hole,
        r"([^\\])\*" => SubstitutionString("\\1$hole"),
        "\\*" => '*')
    # "a*b\\*chole1" => "ahole2b*chole1"

    syntax_node = parseall(SyntaxNode, str)
    if kind(syntax_node) == K"toplevel" && length(syntax_node.children) == 1
        syntax_node = only(syntax_node.children)
    end
    SearchPattern(syntax_node, Symbol(hole))
end

macro j_str(str)
    SearchPattern(str)
end

struct Match
    syntax_node::SyntaxNode
    holes::Vector{SyntaxNode}
end

find_matches(needle::SearchPattern, haystack::AbstractString) =
    find_matches(needle, parseall(SyntaxNode, haystack, ignore_errors=true))

find_matches(needle::SearchPattern, haystack::SyntaxNode) =
    find_matches!(Match[], SyntaxNode[], needle, haystack)
function find_matches!(matches, holes, needle::SearchPattern, haystack::SyntaxNode)
    if is_match!(empty!(holes), needle.hole, needle.syntax_node, haystack)
        push!(matches, Match(haystack, copy(holes)))
    end
    if haystack.children !== nothing
        for child in haystack.children
            find_matches!(matches, holes, needle, child)
        end
    end
    matches
end

function is_match!(holes, hole::Symbol, needle::SyntaxNode, haystack::SyntaxNode)
    if kind(needle) == K"Identifier" && needle.data.val == hole
        push!(holes, haystack)
        return true
    end
    kind(needle) == kind(haystack) || return false
    needle.data.val == haystack.data.val || return false
    needle.children === haystack.children && return true
    needle.children === nothing && return false
    haystack.children === nothing && return false
    axes(needle.children) == axes(haystack.children) || return false
    all(is_match!(holes, hole, n, h) for (n,h) in zip(needle.children, haystack.children))
end

maybe_first(x) = isempty(x) ? nothing : first(x)
maybe_last(x) = isempty(x) ? nothing : last(x)

# API

# @j_str, SearchPattern

# JuliaSyntax.range === Base.range, but I want to be clear that the reason we are defining
# a method for that function is that JuliaSyntax already defined a method for it.
JuliaSyntax.range(m::Match) = JuliaSyntax.range(m.syntax_node)
JuliaSyntax.SyntaxNode(m::Match) = m.syntax_node::SyntaxNode
Base.Expr(m::Match) = Expr(m.syntax_node)
holes(m::Match) = m.holes
Base.getindex(m::Match, i::Int) = m.holes[i]

Base.eachmatch(needle::SearchPattern, haystack) = find_matches(needle, haystack)
Base.match(needle::SearchPattern, haystack) = maybe_first(eachmatch(needle, haystack))
Base.findall(needle::SearchPattern, haystack) = range.(eachmatch(needle, haystack))
Base.occursin(needle::SearchPattern, haystack) = !isempty(eachmatch(needle, haystack))

Base.findfirst(needle::SearchPattern, haystack) = maybe_first(findall(needle, haystack))
Base.findlast(needle::SearchPattern, haystack) = maybe_last(findall(needle, haystack))

# Narrow type signature to avoid ambiguity with
# count(f, A::Union{Base.AbstractBroadcasted, AbstractArray}; dims, init)
Base.count(needle::SearchPattern, haystack::Union{AbstractString, SyntaxNode}) = length(eachmatch(needle, haystack))


# TODO: semantic equality between SearchPatterns

# Display

function Base.show(io::IO, m::SearchPattern)
    print(io, "j\"")
    str = sprint(print, Expr(m.syntax_node))
    str = replace(str, '*' => "\\*", string(m.hole) => '*')
    print(io, str)
    print(io, "\"")
end

function Base.show(io::IO, m::Match)
    if get(io, :typeinfo, nothing) != Match
        print(io, "CodeSearch.")
    end
    print(io, "Match(")
    show(io, m.syntax_node)
    if !isempty(m.holes)
        print(io, ", holes=")
        show(IOContext(io, :typeinfo=>Vector{SyntaxNode}), m.holes)
    end
    print(io, ")")
end

end # module
