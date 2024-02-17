using CodeSearch
using Test
using Aqua

@testset "CodeSearch.jl" begin
    @testset "code quality (Aqua.jl)" begin
        Aqua.test_all(CodeSearch, deps_compat=false)
        Aqua.test_deps_compat(CodeSearch, check_extras=false)
    end

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
