module CodeSearch

get_symbols!(symbols, expr::Symbol) = push!(symbols, expr)
function get_symbols!(symbols, expr::Expr)
    for arg in expr.args
        get_symbols!(symbols, arg)
    end
    symbols
end
get_symbols!(symbols, expr::Any) = symbols
get_unique_symbols(expr) = get_symbols!(Set{Symbol}(), expr)

"""
    gen_unused_symbol(expr, prefix=:hole)

Generate a symbol with the given `prefix` that does not occur in `expr`.

Tries, in order:
1. `prefix`
2. `prefix`1
3. `prefix`2
4. ...
"""
function gen_unused_symbol(expr, prefix=:hole)
    symbols = get_unique_symbols(expr)
    if prefix in symbols
        i = 1
        while Symbol(prefix, i) in symbols
            i += 1
        end
        Symbol(prefix, i)
    else
        prefix
    end
end

end