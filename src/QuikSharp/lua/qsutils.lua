--~ Copyright Ⓒ 2014 Victor Baybekov

local socket = require ("socket")
local json = require "cjson"

local qsutils = {}

--- Sleep that always works
function delay(msec)
    if sleep then
        pcall(sleep, msec)
    else
        pcall(socket.select, nil, nil, msec / 1000)
    end
end

-- high precision current time
function timemsec()
    local st, res = pcall(socket.gettime)
    if st then
        return (res) * 1000
    else
        log("unexpected error in timemsec", 3)
        error("unexpected error in timemsec")
    end
end

is_debug = true

--- Write to log file and to Quik messages
function log(msg, level)
    if not msg then msg = "" end
    if level == 1 or level == 2 or level == 3 or is_debug then
        -- only warnings and recoverable errors to Quik
        if message then
            pcall(message, msg, level)
        end
    end
    if not level then level = 0 end
    local logLine = "LOG "..level..": "..msg
    print(logLine)
    pcall(logfile.write, logfile, timemsec().." "..logLine.."\n")
    pcall(logfile.flush, logfile)
end


function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

function from_json(str)
    local status, msg= pcall(json.decode, str)
    if status then
        return msg
    else
        return nil, msg
    end
end

function to_json(msg)
    local status, str= pcall(json.encode, msg)
    if status then
        return str
    else
        error(str)
    end
end

-- log files
os.execute("mkdir " .. "logs")
logfile = io.open (script_path.. "/logs/QuikSharp.log", "a")
missed_values_file = nil
missed_values_file_name = nil

-- current connection state
is_connected = false
--- indicates that QuikSharp was connected during this session
-- used to write missed values to a file and then resend them if a client reconnects
-- to avoid resending missed values, stop the script in Quik
was_connected = false
local port = 34130
local server = socket.bind('localhost', port, 1)
local client

--- accept client on server
local function getClient()
    print('Waiting for a client')
    local i = 0
    while true do
        local status, client, err = pcall(server.accept, server)
        if status and client then
            return client
        else
            log(err, 3)
        end
    end
end

function qsutils.connect()
    if not is_connected then
        log('Connecting...', 1)
        if client then
            log("is_connected is false but client is not nil", 3)
            -- Quik crashes without pcall
            pcall(client.close, requestClient)
        end
        client = getClient()
        if client then
            is_connected = true
            was_connected = true
            log('Connected!', 1)
            if missed_values_file then
                log("Loading values that a client missed during disconnect", 2)
                missed_values_file:flush()
                missed_values_file:close()
                missed_values_file = nil
                local previous_file_name = missed_values_file_name
                missed_values_file_name = nil
                for line in io.lines(previous_file_name) do
                    client:send(line..'\n')
                end
                -- remove previous file
                pcall(os.remove, previous_file_name)
            end
        end
    end
end

local function disconnected()
    is_connected = false
    print('Disconnecting...')
    if client then
        pcall(client.close, client)
        client = nil
    end
    OnQuikSharpDisconnected()
end

--- get a decoded message as a table
function receiveRequest()
    if not is_connected then
        return nil, "not conencted"
    end
    local status, requestString= pcall(client.receive, client)
    if status and requestString then
        local msg_table, err = from_json(requestString)
        if err then
            log(err, 3)
            return nil, err
        else
            return msg_table
        end
    else
        disconnected()
        return nil, err
    end
end

function sendResponse(msg_table)
    -- if not set explicitly then set CreatedTime "t" property here
    -- if not msg_table.t then msg_table.t = timemsec() end
    local responseString = to_json(msg_table)
    if is_connected then
        local status, res = pcall(client.send, client, responseString..'\n')
        if status and res then
            return true
        else
            disconnected()
            return nil, err
        end
    end
    -- we need this break instead of else because we could lose connection inside the previous if
    if not is_connected and was_connected then
        if not missed_values_file then
            missed_values_file_name = script_path .. "/logs/MissedValues."..os.time()..".log"
            missed_values_file = io.open(missed_values_file_name, "a")
        end
        missed_values_file:write(responseString..'\n')
        return nil, "Message added to the response queue"
    end
end

return qsutils