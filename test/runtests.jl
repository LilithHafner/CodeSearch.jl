using CodeSearch
using Test
using Aqua

@testset "CodeSearch.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(CodeSearch)
    end
    # Write your tests here.
end
