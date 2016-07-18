-- Heka custom module to convert type of message based on application
-- A bucket contains a bunch of applications

cjson = require "cjson"
string = require "string"
os = require "os"

-- Global variable
appTopicMap = {
{{TEMPLATE CSV}}
    ['{{value}}'] = '{{key}}',
{{TEMPLATE CSV}}
}
defaultBucket = "{{REPLACE_ENV|KAFKA_DEFAULT_TOPIC}}"
max_field_len = 8192
trunc_postfix = "\n...truncated"
trunc_msg_len = max_field_len - string.len(trunc_postfix)
short_field_len = 1024


function findApplicationBucket(app)
    if appTopicMap[app] then 
        return appTopicMap[app]
    end
    return defaultBucket
end

function process_message()
    logger = read_message("Logger")
    gelf_json = gelf_format(read_message("Payload"), logger)
    if gelf_json then
        local ok, message = pcall(cjson.encode, gelf_json)
        if not ok then 
            return nil
        end
        write_message("Payload", message)
        topic = findApplicationBucket(gelf_json['_application'])
        write_message("Type", topic)
    end
    return 0
end


function validated_gelf_value(value)
    if not (type(value) == 'string') then
        value = cjson.encode(value)
    end
    if value and (string.len(value) > max_field_len) then
        value = string.sub(value, 1, trunc_msg_len) .. "\n...truncated"
    end
    return value
end


function gelf_format(payload, logger)
    local gelfentry = {}
    gelfentry['timestamp'] = os.time()
    if logger then
        if string.sub(logger, 1, string.len('container_id.')) == 'container_id.' then
            gelfentry['_container_id'] = string.sub(logger, string.len('container_id.') + 1, -1)
        end
    end

    local json_msg
    local ok
    if type(payload) == 'table' then
        json_msg = payload
    else
        ok, json_msg = pcall(cjson.decode, payload)
        if not ok then 
            json_msg = {}
            json_msg['log'] = payload
        end
    end

    for key, value in pairs(json_msg) do
        if (key == 'attrs') and (type(value) == 'table') then
            for k, v in pairs(value) do
                gelfentry['_' .. k] = validated_gelf_value(v)
            end
        else
            gelfentry['_' .. key] = validated_gelf_value(value)
        end
    end
    if not gelfentry['short_message'] then
        gelfentry['short_message'] = string.sub(payload, 1, short_field_len)
    end

    return gelfentry
end
