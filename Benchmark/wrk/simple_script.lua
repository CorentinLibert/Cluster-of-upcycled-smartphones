-- Script that create HTTP POST request containing a file.
-- Post request inspired of: https://gist.github.com/tonytonyjan/d2a612f2b3f37837fc4d5c1409ac0b1e
-- Response logger inspired of: https://gist.github.com/zhu327/6bb6d56ed379b36534c6db4365dbb431

function read_file(path)
    local file, errorMessage = io.open(path, "rb")
    if not file then
        error("Could not read the file:" .. errorMessage .. "\n")
    end
  
    local content = file:read "*all"
    file:close()
    return content
  end

  local logfile = io.open("wrk.log", "w"); -- for local use
-- local logfile = io.open("../wrk.log", "w"); -- For NPF use
local cnt = 0;
  
local Boundary = "------------------------MyBeautifulBoundary";
local BodyBoundary = "--" .. Boundary;
local LastBoundary = "--" .. Boundary .. "--";
local CRLF = "\r\n";
local FileBody = read_file("/home/corentin/Documents/TFE/TFE_Git/Benchmark/wrk/grace_hopper.bmp"); -- for local use
-- local FileBody = read_file("../../wrk/grace_hopper.bmp"); -- For NPF use
local Filename = "grace_hopper.bmp";
local ContentDisposition = 'Content-Disposition: form-data; name="image"; filename="' .. Filename .. '"';
local ContentType = 'Content-Type: application/octet-stream';

wrk.method = "POST";
wrk.body = BodyBoundary .. CRLF .. ContentDisposition .. CRLF .. ContentType .. CRLF .. CRLF .. FileBody .. CRLF .. LastBoundary;
wrk.headers["Accept"] = "*/*";
wrk.headers["Content-Type"] = "multipart/form-data; boundary=" .. Boundary;

response = function(status, header, body)
     cnt = cnt + 1;
     logfile:write("count:" .. cnt .. "\n")
     logfile:write("status:" .. status .. "\n" .. body .. "\n-------------------------------------------------\n");
end

done = function(summary, latency, requests)
     logfile:write("------------- SUMMARY -------------\n")
     print("Response count: ", cnt)
     logfile.close();
end