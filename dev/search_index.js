var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = CodeSearch","category":"page"},{"location":"#CodeSearch.jl","page":"Home","title":"CodeSearch.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"CodeSearch.jl is a package for semantically searching Julia code. Unlike plain string search and regex search, CodeSearch performs search operations after parsing. Thus the search patterns j\"a + b\" and j\"a+b\" are equivalent, and both match the code a +b.","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> using CodeSearch\n\njulia> j\"a + b\" == j\"a+b\"\ntrue\n\njulia> findfirst(j\"a+b\", \"sqrt(a +b)/(a+ b)\")\n6:9","category":"page"},{"location":"","page":"Home","title":"Home","text":"The other key feature in this package is wildcard matching. You can use the character * to match any expression. For example, the pattern j\"a + *\" matches both a + b and a + (b + c) .","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> Expr.(eachmatch(j\"a + *\", \"a + (a + b), a + sqrt(2)\"))\n3-element Vector{Expr}:\n :(a + (a + b))\n :(a + b)\n :(a + sqrt(2))","category":"page"},{"location":"","page":"Home","title":"Home","text":"Here we can see that j\"a + *\" matches multiple places, even some that nest within eachother!","category":"page"},{"location":"","page":"Home","title":"Home","text":"Finally, it is possible to extract the \"captured values\" that match the wildcards.","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> m = match(j\"a + *\", \"a + (a + b), a + sqrt(2)\")\nCodeSearch.Match((call-i a + (call-i a + b)), captures=[(call-i a + b)])\n\njulia> m.captures\n1-element Vector{JuliaSyntax.SyntaxNode}:\n (call-i a + b)\n\njulia> Expr(only(m.captures))\n:(a + b)","category":"page"},{"location":"#How-to-use-this-package","page":"Home","title":"How to use this package","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Create Patterns with the @j_str macro or the  CodeSearch.pattern function.\nSearch an AbstractString or a JuliaSyntax.SyntaxNode for whether and where that  pattern occurs with generic functions like occursin, findfirst, findlast, or  findall OR extract the actual Matches with generic functions like eachmatch and  match.\nIf you extracted an actual match, access relevant information using the public  syntax_node and captures fields, convert to a SyntaxNode, Expr, or  AbstractString via constructors, index into the captures directly with getindex, or  extract the indices in the original string that match the capture with  indices.","category":"page"},{"location":"#Reference","page":"Home","title":"Reference","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"@j_str\nCodeSearch.pattern\nCodeSearch.Pattern\nCodeSearch.Match\nindices\nGeneric functions","category":"page"},{"location":"","page":"Home","title":"Home","text":"The following are manually selected docstrings","category":"page"},{"location":"","page":"Home","title":"Home","text":"@j_str\nCodeSearch.pattern\nCodeSearch.Pattern\nCodeSearch.Match\nindices","category":"page"},{"location":"#CodeSearch.@j_str","page":"Home","title":"CodeSearch.@j_str","text":"j\"str\" -> Pattern\n\nConstruct a Pattern, such as j\"a + (b + *)\" that matches Julia code.\n\nThe * character is a wildcard that matches any expression, and matching is performed insensitive of whitespace and comments. Only the characters \" and * must be escaped, and interpolation is not supported.\n\nSee pattern for the function version of this macro if you need interpolation.\n\nExamples\n\njulia> j\"a + (b + *)\"\nj\"a + (b + *)\"\n\njulia> match(j\"(b + *)\", \"(b + 6)\")\nCodeSearch.Match((call-i b + 6), captures=[6])\n\njulia> findall(j\"* + *\", \"(a+b)+(d+e)\")\n3-element Vector{UnitRange{Int64}}:\n 1:11\n 2:4\n 8:10\n\njulia> match(j\"(* + *) \\* *\", \"(a-b)*(d+e)\") # no match -> returns nothing\n\njulia> occursin(j\"(* + *) \\* *\", \"(a-b)*(d+e)\")\nfalse\n\njulia> eachmatch(j\"*(\\\"hello world\\\")\", \"print(\\\"hello world\\\"), display(\\\"hello world\\\")\")\n2-element Vector{CodeSearch.Match}:\n Match((call print (string \"hello world\")), captures=[print])\n Match((call display (string \"hello world\")), captures=[display])\n\njulia> count(j\"*(*)\", \"a(b(c))\")\n2\n\njulia> match(j\"(* + *) \\* *\", \"(a+b)*(d+e)\")\nCodeSearch.Match((call-i (call-i a + b) * (call-i d + e)), captures=[a, b, (call-i d + e)])\n\n\n\n\n\n","category":"macro"},{"location":"#CodeSearch.pattern","page":"Home","title":"CodeSearch.pattern","text":"pattern(str::AbstractString) -> Pattern\n\nFunction version of the j\"str\" macro. See @j_str for documentation.\n\nExamples\n\njulia> using CodeSearch: pattern\n\njulia> pattern(\"a + (b + *)\")\nj\"a + (b + *)\"\n\njulia> match(pattern(\"(b + *)\"), \"(b + 6)\")\nCodeSearch.Match((call-i b + 6), captures=[6])\n\njulia> findall(pattern(\"* + *\"), \"(a+b)+(d+e)\")\n3-element Vector{UnitRange{Int64}}:\n 1:11\n 2:4\n 8:10\n\njulia> match(pattern(\"(* + *) \\\\* *\"), \"(a-b)*(d+e)\") # no match -> returns nothing\n\njulia> occursin(pattern(\"(* + *) \\\\* *\"), \"(a-b)*(d+e)\")\nfalse\n\njulia> eachmatch(pattern(\"*(\\\"hello world\\\")\"), \"print(\\\"hello world\\\"), display(\\\"hello world\\\")\")\n2-element Vector{CodeSearch.Match}:\n Match((call print (string \"hello world\")), captures=[print])\n Match((call display (string \"hello world\")), captures=[display])\n\njulia> count(pattern(\"*(*)\"), \"a(b(c))\")\n2\n\njulia> match(pattern(\"(* + *) \\\\* *\"), \"(a+b)*(d+e)\")\nCodeSearch.Match((call-i (call-i a + b) * (call-i d + e)), captures=[a, b, (call-i d + e)])\n\n\n\n\n\n","category":"function"},{"location":"#CodeSearch.Pattern","page":"Home","title":"CodeSearch.Pattern","text":"Pattern <: AbstractPattern\n\nA struct that represents a Julia expression with wildcards. When matching Patterns, it is possilbe for multiple matches to nest within one another.\n\nThe fields and constructor of this struct are not part of the public API. See @j_str and pattern for the public API for creating Patterns.\n\nMethods accepting Pattern objects are defined for eachmatch, match, findall, findfirst, findlast, occursin, and count.\n\nExtended Help\n\nThe following are implmenetation details:\n\nThe expression is stored as an ordinary SyntaxNode in the internal syntax_node field. Wildcards in that expression are represented by the symbol stored in the internal wildcard_symbol field. For example, the expression a + (b + *) might be stored as Pattern((call-i a + (call-i b + wildcard)), :wildcard).\n\n\n\n\n\n","category":"type"},{"location":"#CodeSearch.Match","page":"Home","title":"CodeSearch.Match","text":"struct Match <: AbstractMatch\n    syntax_node::JuliaSyntax.SyntaxNode\n    captures::Vector{JuliaSyntax.SyntaxNode}\nend\n\nRepresents a single match to a Pattern, typically created from the eachmatch or match function.\n\nThe syntax_node field stores the SyntaxNode that matched the Pattern and the captures field stores the SyntaxNodes that fill match each wildcard in the Pattern, indexed in the order they appear.\n\nMethods that accept Match objects are defined for Expr, SyntaxNode, AbstractString, indices, and getindex.\n\nExamples\n\njulia> m = match(j\"√*\", \"2 + √ x\")\nCodeSearch.Match((call-pre √ x), captures=[x])\n\njulia> m.captures\n1-element Vector{JuliaSyntax.SyntaxNode}:\n x\n\njulia> m[1]\nline:col│ tree        │ file_name\n   1:7  │x\n\njulia> Expr(m)\n:(√x)\n\njulia> AbstractString(m)\n\" √ x\"\n\njulia> CodeSearch.indices(m)\n4:9\n\n\n\n\n\n","category":"type"},{"location":"#CodeSearch.indices","page":"Home","title":"CodeSearch.indices","text":"indices(m)\n\nReturn the indices into a source datastructure that a view is derived from.\n\nExamples\n\njulia> m = match(j\"x/*\", \"4 + x/2\")\nCodeSearch.Match((call-i x / 2), captures=[2])\n\njulia> indices(m)\n4:7\n\njulia> c = m[1]\nline:col│ tree        │ file_name\n   1:7  │2\n\n\njulia> indices(c)\n7:7\n\n\n\n\n\n","category":"function"},{"location":"#Generic-functions","page":"Home","title":"Generic functions","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Many functions that accept Regexs also accept CodeSearch.Patterns and behave according to their generic docstrings. Here are some of those supported functions:","category":"page"},{"location":"","page":"Home","title":"Home","text":"findfirst\nfindlast\nfindall\neachmatch\nmatch\noccursin","category":"page"},{"location":"","page":"Home","title":"Home","text":"<!– - startswith [TODO] –> <!– - endswith [TODO] –> <!– - findnext [TODO] –> <!– - findprev [TODO] –>","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"CurrentModule = CodeSearch","category":"page"},{"location":"internals/#Internals","page":"Internals","title":"Internals","text":"","category":"section"},{"location":"internals/","page":"Internals","title":"Internals","text":"Documentation for the internals of CodeSearch. The content on this page is not a part of the public API and isn't intended for most users. It's all subject to change in non-breaking versions.","category":"page"},{"location":"internals/","page":"Internals","title":"Internals","text":"CodeSearch.gen_wildcard\nCodeSearch.prepare_wildcards","category":"page"},{"location":"internals/#CodeSearch.gen_wildcard","page":"Internals","title":"CodeSearch.gen_wildcard","text":"gen_wildcard(str, prefix=\"wildcard\")\n\nreturn a string starting with prefix that is not in str\n\n\n\n\n\n","category":"function"},{"location":"internals/#CodeSearch.prepare_wildcards","page":"Internals","title":"CodeSearch.prepare_wildcards","text":"prepare_wildcards(str) -> (new_str, wildcard_str)\n\nReplace * with an identifier that does not occur in str (preferrably \"wildcard\") and return the new string and the identifier. * may be escaped, and the new identifier is padded with spaces only when necessary to prevent it from parsing together with characters before or after it.\n\n\n\n\n\n","category":"function"}]
}
