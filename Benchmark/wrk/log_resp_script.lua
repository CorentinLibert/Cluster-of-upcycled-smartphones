-- Script that logs the responses.
-- From: https://gist.github.com/zhu327/6bb6d56ed379b36534c6db4365dbb431


logfile = io.open("wrk.log", "w");
local cnt = 0;

response = function(status, header, body)
    --  logfile:write("status:" .. status .. "\n");
     cnt = cnt + 1;
     logfile:write("status:" .. status .. "\n" .. body .. "\n-------------------------------------------------\n");
end

done = function(summary, latency, requests)
     logfile:write("------------- SUMMARY -------------\n")
     print("Response count: ", cnt)
     logfile.close();
end