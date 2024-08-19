-- Script that create HTTP POST request containing a bitmap image.
-- Post request inspired of: https://gist.github.com/tonytonyjan/d2a612f2b3f37837fc4d5c1409ac0b1e

-- Load image data from file
local filename = "grace_hopper.bmp"
local file_path = "./assets/wrk/grace_hopper.bmp" -- relative to the experiment notebook
local file = io.open(file_path, "rb")
local file_data = file:read("*all")
file:close()

-- Generate the multipart body
local boundary = "-------YouShallNotPassBondary";
local part_name = "image"
local content_type = "application/octet-stream"
local crlf = "\r\n"

local content_disposition = 'Content-Disposition: form-data; name="' .. part_name .. '"; filename="' .. filename .. '"'
local content_type = 'Content-Type: ' .. content_type

-- Create the HTTP request
wrk.method = "POST"
wrk.body = "--" .. boundary .. crlf .. content_disposition .. crlf .. content_type .. crlf .. crlf .. file_data .. crlf .. "--" .. boundary .. "--" .. crlf
wrk.headers["Content-Type"] = "multipart/form-data; boundary=" .. boundary
