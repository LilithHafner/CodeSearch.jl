using CodeSearch
using Test
using Aqua

@testset "CodeSearch.jl" begin
    @testset "code quality (Aqua.jl)" begin
        Aqua.test_all(CodeSearch, deps_compat=false)
        Aqua.test_deps_compat(CodeSearch, check_extras=false)
    end
    # Write your tests here.
end
