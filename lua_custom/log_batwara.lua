-- Heka custom module to convert type of message based on application
-- A bucket contains a bunch of applications

require "cjson"
require "string"

-- Global variable
appTopicMap = {
{{TEMPLATE CSV}}
    ['{{value}}'] = '{{key}}',
{{TEMPLATE CSV}}
}
defaultBucket = "{{REPLACE_ENV|KAFKA_DEFAULT_TOPIC}}"


function findApplicationBucket(app)
    if appTopicMap[app] then 
        return appTopicMap[app]
    end
    return defaultBucket
end

function process_message()
    local ok, json = pcall(cjson.decode, read_message("Payload"))
    if not ok then 
        return -1
    end

    topic = findApplicationBucket(json['_application'])
    write_message("Type", topic)
    return 0
end
