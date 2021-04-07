function show_option(io::IO, m::MIME"text/plain", x)
    if !get(io, :no_indent_first_line, false)
        indent_print(io)
    end

    print(io, GREEN_FG(string(typeof(x))), "(;")
    println(io)

    show_option_fields(io, m, x)
    indent_print(io, ")")
end

function show_option(io::IO, m::MIME"text/html", x)
    buf = IOBuffer()
    show(buf, MIME("text/plain"), x)
    printer = HTMLPrinter(buf; root_class="configurations-option-type")
    ascii_css = "https://cdn.jsdelivr.net/gh/JuliaDocs/ANSIColoredPrinters.jl@0.0.1/docs/src/assets/default.css"
    write(io, """
        <link rel="stylesheet" href="$ascii_css" />
    """)
    show(io, m, printer)
end

function show_option_fields(io::IO, m::MIME"text/plain", x)
    within_indent(io) do io
        for name in fieldnames(typeof(x))
            value = getfield(x, name)
            if value != field_default(typeof(x), name)
                indent_print(io, LIGHT_BLUE_FG(string(name)), " = ")
                show_option_value(no_indent_first_line(io), m, value)
                println(io, ",")
            end
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
    if !get(io, :no_indent_first_line, false)
        indent_print(io)
    end

    print(io, typeof(x))
    print(io, "(")

    println(io)
    within_indent(io) do io
        for (k, v) in x
            indent_print(io, repr(k), " => ")
            show_option_value(no_indent_first_line(io), m, v)
            println(io, ",")
        end
    end
    indent_print(io, ")")
end

function show_option_value(io::IO, m::MIME, list::Vector)
    if !(any(is_option, list) || length(list) > 4)
        return show(io, list)
    end

    println(io, "[")
    within_indent(io) do io
        for each in list
            indent_print(io)
            show_option_value(io, m, each)
            if length(list) > 1
                println(io, ",")
            end
        end
    end
    indent_print(io, "]")
end
