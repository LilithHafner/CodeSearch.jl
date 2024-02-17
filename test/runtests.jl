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
        @test occursin(j"if false; *; end", haystack)
        @test !occursin(j"while * end", haystack)
        @test !occursin(j"if *
                            g()
                        end", haystack)
        @test !occursin(j"if *
                            f()
                            g()
                        end", haystack)
        @test occursin(j"1 + 1 # Comments", haystack)
        @test_broken !occursin(j"1 + 1 # Conts", haystack)
    end

    @testset "gen_unused_symbol" begin
        @test CodeSearch.gen_unused_symbol(:(ho = le)) === :hole
        @test CodeSearch.gen_unused_symbol(:(hole + 1)) === :hole1
        @test CodeSearch.gen_unused_symbol(:(hole + hole1)) === :hole2
        @test CodeSearch.gen_unused_symbol(:(hole + hole10)) === :hole1
        @test CodeSearch.gen_unused_symbol(
                :(hole, hole1, hole2, hole3, hole4, hole5, hole6, hole7, hole8, hole9, hole10)
            ) === :hole11
    end
end
