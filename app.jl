using Genie
using Genie.Router
using Genie.Renderer.Html
using Genie.Renderer.Json
using Genie.Requests
using HTTP
using JSON3

const INDEX_PATH = joinpath(@__DIR__, "public", "index.html")
const UPSTREAM_URL = get(ENV, "SCRIPT_API_URL", "")

function read_index()
    return isfile(INDEX_PATH) ? read(INDEX_PATH, String) : "<h1>Missing index.html</h1>"
end

function extract_prompt(payload)
    if payload === nothing
        return ""
    end

    try
        if haskey(payload, "prompt")
            return string(payload["prompt"])
        end
    catch
    end

    try
        if haskey(payload, :prompt)
            return string(payload[:prompt])
        end
    catch
    end

    return ""
end

function call_upstream(prompt::AbstractString)
    if isempty(strip(UPSTREAM_URL))
        return "DEMO MODE: no SCRIPT_API_URL set.\n\n" * prompt
    end

    body = JSON3.write(Dict("prompt" => prompt))
    resp = HTTP.request("POST", UPSTREAM_URL, ["Content-Type" => "application/json"], body)

    if resp.status < 200 || resp.status >= 300
        return "UPSTREAM ERROR: HTTP $(resp.status)"
    end

    data = JSON3.read(String(resp.body), Dict{String, Any})
    return string(get(data, "script", ""))
end

route("/") do
    html(read_index())
end

route("/script/generate", method = POST) do
    payload = jsonpayload()
    prompt = extract_prompt(payload)

    if isempty(strip(prompt))
        return json(Dict("script" => ""))
    end

    script = try
        call_upstream(prompt)
    catch e
        "ERROR: " * sprint(showerror, e)
    end

    json(Dict("script" => script))
end

Genie.config.run_as_server = true
Genie.config.server_port = parse(Int, get(ENV, "PORT", "8000"))
Genie.config.server_host = get(ENV, "HOST", "127.0.0.1")

Genie.up()
