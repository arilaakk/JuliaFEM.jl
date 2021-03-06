# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/JuliaFEM.jl/blob/master/LICENSE.md

module abaqus_reader

using Logging
@Logging.configure(level=DEBUG)

VERSION < v"0.4-" && using Docile

eldims = Dict({"C3D10" => 10})
global handlers = Dict()


"""
Register new handler for parser
"""
function add_handler(section, function_name)
  handlers[section] = function_name
end

function create_or_get(model, key)
    if !(key in keys(model))
        model[key] = Dict()
    end
    return model[key]
end

function parse_header(header_line)
    args = map(s -> strip(s), split(header_line, ","))
    args[1] = strip(args[1], '*')
    d = Dict({"section" => args[1]})
    options = Dict()
    for k in args[2:end]
        args2 = split(k, "=")
        options[args2[1]] = args2[2]
    end
    d["options"] = options
    return d
end

function parse_node_section(model, header, data)
    nodes = create_or_get(model, "nodes")
    for line in split(data, "\n")
        m = matchall(r"[-0-9.]+", line)
        id = parse(Int, m[1])
        coords = float(m[2:end])
        nodes[id] = coords
    end
end

function parse_element_section(model, header, data)
    eltype = header["options"]["TYPE"]
    if !(eltype in keys(eldims))
        throw("Element $eltype dimension information missing")
    end
    eldim = eldims[eltype]
    m = matchall(r"[0-9]+", data)
    m = map(integer, m)
    elements = create_or_get(model, "elements")
    m = reshape(m, eldim+1, round(Int, length(m)/(eldim+1)))
    nel = size(m)[2]
    Logging.debug("$nel elements found")
    for i=1:nel
        elements[m[1,i]] = m[2:end,i]
    end
    if "ELSET" in keys(header["options"])
        elsets = create_or_get(model, "elsets")
        elset_name = header["options"]["ELSET"]
        Logging.info("Creating ELSET $elset_name")
        elsets[elset_name] = Int64[]
        for i=1:nel
            push!(elsets[elset_name], m[1,i])
        end
    end
end


function parse_nodeset_section(model, header, data)
    nset_name = header["options"]["NSET"]
    Logging.debug("Creating node set $nset_name")
    m = matchall(r"[0-9]+", data)
    node_ids = map(integer, m)
    nsets = create_or_get(model, "nsets")
    nsets[nset_name] = Int64[]
    for j in node_ids
        push!(nsets[nset_name], j)
    end
end


function parse_abaqus(fid)
    model = Dict()
    section = None
    header = None
    data = ""
    Logging.info("Registered handlers: $(keys(handlers))")

    function process_section(section)
        if section == None
            return
        end
        if !(section in keys(handlers))
            Logging.info("Don't know what to do with data in section $section")
            Logging.info("Skipping $(length(data)) bytes of unknown data")
            return
        end
        handlers[section](model, header, strip(data))
        data = ""
    end

    for line in eachline(fid)
        if beginswith(line, "**")
            continue
        end
        if beginswith(line, "*")
            process_section(section)
            header = parse_header(line)
            Logging.debug("Found ", header["section"], " section")
            section = header["section"]
            continue
        end
        data *= line
    end
    process_section(section)
    return model
end

# add handlers
add_handler("NODE", parse_node_section)
add_handler("ELEMENT", parse_element_section)
add_handler("NSET", parse_nodeset_section)

end

