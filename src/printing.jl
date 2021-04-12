tab(n::Int) = " "^n
no_indent(io::IO) = IOContext(io, :indent=>0)
no_indent_first_line(io::IO) = IOContext(io, :no_indent_first_line=>true)

# 1.0 compatibility
function indent_print(io::IO, ::Nothing)
    indent = get(io, :indent, 0)
    print(io, tab(indent), "nothing")
end

function indent_print(io::IO, xs...)
    indent = get(io, :indent, 0)
    Base.print(io, tab(indent), xs...)
end

function indent_println(io::IO, xs...)
    if get(io, :no_indent_first_line, false)
        indent_print(no_indent(io), xs..., "\n")
    else
        indent_print(io, xs..., "\n")
    end
end

function within_indent(f, io)
    f(indent(io))
end

function indent(io)
    IOContext(io, :indent => get(io, :indent, 0) + 4)
end

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
    topmost = get(io, :configurations_style_sheet, true)
    if topmost
        print(io, """
        <style>
        @font-face {
            font-family: JuliaMono;
            src: local('JuliaMono'),
            url("https://cdn.jsdelivr.net/gh/cormullion/juliamono/webfonts/JuliaMono-Regular.woff2");
        }
        .configurations-option-type {
            font-family: "JuliaMono";
            font-size: 1em;
        }
        .configurations-option-type ul{
            list-style-type: none;
        }

        .configurations-list ul {
            list-style: none;
        }

        .configurations-bullet {
            color: hsl(0, 0%, 25%, 0.7);
            padding: 20px;
        }

        .configurations-option-head {
            color: #5e7ad3;
            cursor: pointer;
            user-select: none;
        }
        .configurations-option-head::before {
            content: "\\25B6";
            color: black;
            display: inline-block;
            margin-right: 6px;
        }
        .configurations-option-head-down::before {
            transform: rotate(90deg);
        }
        .configurations-option-fields {
            display: none;
        }
        .configurations-option-active {
            display: block;
        }
        </style>
        <script>
        var toggler = document.getElementsByClassName("configurations-option-head");
        var i;

        for (i = 0; i < toggler.length; i++) {
        toggler[i].addEventListener("click", function() {
            this.parentElement.querySelector(".configurations-option-fields").classList.toggle("configurations-option-active");
            this.classList.toggle("configurations-option-head-down");
        });
        }
        </script>
        <dev class="configurations-option-type">
        """)
    end

    print(io, """
        <ul>
        <li><span class="configurations-option-head">$(summary(x))</span>
    """)
    show_option_fields(IOContext(io, :configurations_style_sheet=>false), m, x)
    print(io, """
            </li>
        </ul>
    """)
    topmost && print(io, "</dev>")
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

function show_option_fields(io::IO, m::MIME"text/html", x)
    print(io, "<ul class=\"configurations-option-fields\">")
    for name in fieldnames(typeof(x))
        value = getfield(x, name)
        if value != field_default(typeof(x), name)
            print(io, "<li>")
            print(io, "<span>", string(name), "=</span>")
            show_option_value(io, m, value)
            print(io, "</li>")
        end
    end
    print(io, "</ul>")
end

function show_option_value(io::IO, m::MIME, x)
    if is_option(x)
        show_option(io, m, x)
    else
        show(io, x)
    end
end

function show_option_value(io::IO, m::MIME"text/html", x::AbstractDict)
    print(io, "<span>", typeof(x), "(</span>")

    print(io, "<ul>")
    for (k, v) in x
        print(io, "<li>")
        print(io, "<span>&nbsp&nbsp", repr(k), "=>")
        print(io, "</span>")
        show_option_value(io, m, v)
        print(io, "</li>")
    end
    print(io, ")</ul>")
end

function show_option_value(io::IO, m::MIME, x::AbstractDict)
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

function show_option_value(io::IO, m::MIME"text/html", list::Vector)
    if !(any(is_option, list) || length(list) > 4)
        return print(io, string(list))
    end

    print(io, "<span>[</span>")
    print(io, "<ul class=\"configurations-list\">")
    for (i, each) in enumerate(list)
        print(io, "<li>")
        print(io, "<span class=\"configurations-bullet\">", i, ".", "</span>")
        show_option_value(io, m, each)
        print(io, "</li>")
    end
    print(io, "<span>]</span></ul>")
end
