using CodeSearch
using Test
using Aqua

@testset "CodeSearch.jl" begin
    @testset "code quality (Aqua.jl)" begin
        Aqua.test_all(CodeSearch, deps_compat=false)
        Aqua.test_deps_compat(CodeSearch, check_extras=false)
    end

    @testset "occursin" begin
        haystack = """
        function f()
            println("Hello, world!")
        end

        while true
            f()
        end

        if false
            f()
            g()
        end

        1+1 # Comments

        for _ in 1:
        """

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

    @testset "gen_hole" begin
        @test CodeSearch.gen_hole("ho = le") === "hole"
        @test CodeSearch.gen_hole("hole + 1") === "hole1"
        @test CodeSearch.gen_hole("hope + hole1") === "hole2"
        @test CodeSearch.gen_hole("hole + hole10") === "hole2"
        @test CodeSearch.gen_hole(
                "hole2, hole3, hole4, hole5, hole6, hole7, hole8, hole9, hole10"
            ) === "hole11"
    end
    @testset "show" begin
        x = j"a + (b + *) \* hole"
        @test repr(eval(Meta.parse(repr(x)))) == repr(x) == "j\"a + (b + *) \\* hole\""
        @test Expr(x.syntax_node) == Expr(eval(Meta.parse(repr(x))).syntax_node)
        @test x.hole == eval(Meta.parse(repr(x))).hole
    end

    @testset "is_match!" begin
        holes = CodeSearch.SyntaxNode[]
        @test CodeSearch.is_match!(holes, :hole, j"a + *".syntax_node, CodeSearch.parsestmt(CodeSearch.SyntaxNode, "a + b")) === true
        @test CodeSearch.is_match!(holes, :hole, j"a + *".syntax_node, CodeSearch.parsestmt(CodeSearch.SyntaxNode, "b + b")) === false
        @test CodeSearch.is_match!(holes, :hole, j"a + *".syntax_node, CodeSearch.parsestmt(CodeSearch.SyntaxNode, "a + b + c")) === false
        @test CodeSearch.is_match!(holes, :hole, j"a + *".syntax_node, CodeSearch.parsestmt(CodeSearch.SyntaxNode, "a + (b + c)")) === true
        @test Expr.(holes) == [:b, :(b + c)]
    end

    @testset "combined" begin
        @test Expr(only(CodeSearch.find_matches(j"f(*)", "f(g(x))"))[1]) == :(g(x))
    end

    @testset "j_str" begin
        @test repr(j"* !== nothing") == "j\"* !== nothing\"" # Start with *
        @test Expr(j"a\*b".syntax_node) == :(a*b)
        @test_broken Expr(j"a*b".syntax_node) != :aholeb # but it still reprs fine :(!
    end
end
