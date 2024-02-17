using CodeSearch
using Test
using Aqua

@testset "CodeSearch.jl" begin
    @testset "code quality (Aqua.jl)" begin
        Aqua.test_all(CodeSearch, deps_compat=false, ambiguities=false)
        Aqua.test_deps_compat(CodeSearch, check_extras=false)
        # The method error from an ambiguity is appropriate for these:
        Aqua.test_ambiguities(CodeSearch, exclude=[findall, count])
    end
    @testset "unit tests" begin
        @testset "gen_hole" begin
            @test CodeSearch.gen_hole("ho = le") === "hole"
            @test CodeSearch.gen_hole("hole + 1") === "hole1"
            @test CodeSearch.gen_hole("hope + hole1") === "hole2"
            @test CodeSearch.gen_hole("hole + hole10") === "hole2"
            @test CodeSearch.gen_hole(
                    "hole2, hole3, hole4, hole5, hole6, hole7, hole8, hole9, hole10"
                ) === "hole11"
        end

        @testset "is_match!" begin
            holes = CodeSearch.SyntaxNode[]
            @test CodeSearch.is_match!(holes, :hole, j"a + *"._internal.syntax_node, CodeSearch.parsestmt(CodeSearch.SyntaxNode, "a + b")) === true
            @test CodeSearch.is_match!(holes, :hole, j"a + *"._internal.syntax_node, CodeSearch.parsestmt(CodeSearch.SyntaxNode, "b + b")) === false
            @test CodeSearch.is_match!(holes, :hole, j"a + *"._internal.syntax_node, CodeSearch.parsestmt(CodeSearch.SyntaxNode, "a + b + c")) === false
            @test CodeSearch.is_match!(holes, :hole, j"a + *"._internal.syntax_node, CodeSearch.parsestmt(CodeSearch.SyntaxNode, "a + (b + c)")) === true
            @test Expr.(holes) == [:b, :(b + c)]
        end

        @testset "find_matches" begin
            @test Expr(only(CodeSearch.find_matches(j"f(*)", "f(g(x))"))[1]) == :(g(x))
        end

        @testset "j_str" begin
            @test repr(j"* !== nothing") == "j\"* !== nothing\"" # Start with *
            @test Expr(j"a\*b"._internal.syntax_node) == :(a*b)
            @test_broken Expr(j"a*b"._internal.syntax_node) != :aholeb # but it still reprs fine :(!
        end
    end


    @testset "generic functions" begin

        haystack = """
        function f()
            println("Hello, world!")
        end

        while true
            f()
        end

        if false
            f()
            g( )
        end

        1+1 # Comments

        for _ in 1:
        """

        @testset "occursin" begin
            @test occursin(j"while *; f(); end", haystack)
            @test !occursin(j"while *; g(); end", haystack)
            @test occursin(j"while *; *; end", haystack)
            @test !occursin(j"if false; *; end", haystack) # TODO: should * match multiple statements?
            @test !occursin(j"while * end", haystack)
            @test !occursin(j"if *
                                g()
                            end", haystack)
            @test occursin(j"if *
                                f()
                                g()
                            end", haystack)
            @test occursin(j"1 + 1 # Comments", haystack)
            @test_broken !occursin(j"1 + 1 # Conts", haystack)
        end

        @testset "assorted" begin
            m1 = match(j"f()", haystack)
            m2 = match(j"h()", haystack)
            m3 = match(j"function *(); *; end", haystack)
            m4 = match(j"1 + 1", haystack)
            m5 = match(j"g()", haystack)

            @test m1 isa CodeSearch.Match
            @test indices(m1) isa UnitRange{Int}
            @test m2 === nothing
            @test indices(m1) ⊆ indices(m3) ⊆ eachindex(haystack)
            @test last(indices(m3)) < first(indices(m4))
            @test m3[1] isa CodeSearch.JuliaSyntax.SyntaxNode
            @test indices(m3[1])::UnitRange ⊆ indices(m3)
            @test last(indices(m3[1])) < first(indices(m3[2]))
            @test_throws BoundsError m3[3]

            @test Expr(m1) == :(f())
            @test Expr(m4) == :(1 + 1)
            # m3 has line number nodes which won't align

            @test AbstractString(m1) == "f()"
            @test AbstractString(m4) == "1+1"
            @test AbstractString(m3) == """function f()
                println(\"Hello, world!\")
            end"""
            @test AbstractString(m5) == "g( )"
            @test_broken AbstractString(m3[1]) # AbstractString(::SyntaxNode) is piracy.

            em = eachmatch(j"f()", haystack)
            @test length(em) == count(j"f()", haystack) == 3
            @test indices.(em) == findall(j"f()", haystack)
            @test indices(em[begin]) == findfirst(j"f()", haystack)
            @test indices(em[end]) == findlast(j"f()", haystack)
            @test findfirst(j"blue + *", haystack) === findlast(j"blue + *", haystack) === nothing
        end
        @testset "showing patterns" begin
            x = j"a + (b + *) \* hole"
            @test repr(eval(Meta.parse(repr(x)))) == repr(x) == "j\"a + (b + *) \\* hole\""
            @test x == eval(Meta.parse(repr(x)))
            @test x !== eval(Meta.parse(repr(x)))
        end

        @testset "showing matches" begin
            # These are kinda ugly.
            @test sprint(show, match(j"sqrt(2)", "sqrt(2 )")) == "CodeSearch.Match((call sqrt 2))"
            @test sprint.(print, eachmatch(j"a+*", "a+((a+b)+c)")) == [
                "CodeSearch.Match((call-i a + (call-i (call-i a + b) + c)), captures=[(call-i (call-i a + b) + c)])"
                "CodeSearch.Match((call-i a + b), captures=[b])"
            ]
        end
        @testset "equality and hashing" begin
            a = j"1 + *"
            b = j"1 + *"
            c = CodeSearch._Pattern(CodeSearch.parsestmt(CodeSearch.SyntaxNode, "1 + b"), :b)
            d = j"1 + b"

            @test a == b == c != d
            @test hash(a) == hash(b) == hash(c) != hash(d)
            @test isequal(a, b)
            @test !isequal(a, d)

            @test match(a, haystack) != match(d, haystack)

            # I know it's wierd, but the only reason we have semantic equality for patterns
            # is that they are indistinguishable because they have a small accessor API.
            # Two patterns are equal if they match the same things.

            # However, match objects can be accessed in all sorts of interesting ways, and
            # because we don't know which properties interest a user and there is no
            # canonical notion of identity, we keep the default egal behavior.
            m = match(a, haystack)
            @test match(a, haystack) != m
            @test m == m
        end
    end
end
