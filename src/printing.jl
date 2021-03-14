function show_option(io::IO, m::MIME"text/plain", x)
    if !get(io, :no_indent_first_line, false)
        indent_print(io)
    end

    summary(io, x)
    print(io, "(")
    println(io)

    show_option_fields(io, m, x)
    indent_print(io, ")")
end

function show_option_fields(io::IO, m::MIME"text/plain", x)
    within_indent(io) do io
        for name in fieldnames(typeof(x))
            indent_print(io, name, " = ")
            show_option_value(no_indent_first_line(io), m, getfield(x, name))
            println(io, ",")
        end
    end
end

function show_option_value(io::IO, m::MIME, x)
    if is_option(x)
        show_option(io, m, x)
    else
        show(io, x)
    end
end
show_option_value(io::IO, ::MIME, x::AbstractDict) = show(io, x)

function show_option_value(io::IO, m::MIME, x::AbstractDict{String})
    indent_print(io)
    summary(io, x)
    with_parathesis(io) do
        println(io)
        within_indent(io) do io
            for (k, v) in x
                indent_print(io, k, " => ")
                show_option_value(no_indent_first_line(io), m, v)
                println(io, ",")
            end
        end
    end
end

function show_option_value(io::IO, m::MIME, x::Vector)
    if !(any(is_option, list) || length(list) > 4)
        return show(io, list)
    end

    with_brackets(io) do
        within_indent(io) do io
            for each in x
                show_option_value(io, m, each)
                if length(x) > 1
                    println(io, ",")
                end
            end
        end
    end
end
