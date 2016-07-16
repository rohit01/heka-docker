#!/usr/bin/env bash
#
# Startup scrit - heka
# Author: Rohit Gupta - @rohit01
#

set -e

export CONFIG_FILE="/heka/etc/${HEKA_CONF}"


#### START - function definitions ###############################################
replace_csv_macro() {
    tmp_content="${1}"
    key="$(echo "${tmp_content}" | grep "{{REPLACE_CSV|[a-zA-Z0-9_][a-zA-Z0-9_]*}}" | head -n 1 | sed "s/^.*{{REPLACE_CSV|\([a-zA-Z0-9_][a-zA-Z0-9_]*\)}}.*/\1/")"
    if [ "X${key}" = "X" ]; then
       echo "${tmp_content}"
       exit 1
    fi
    value="[\"$(env | grep "^${key}=.*$" | sed -e "s/^${key}=\(.*\)$/\1/" -e 's/,/", "/g')\"]"
    echo "${tmp_content}" | sed "s/{{REPLACE_CSV|${key}}}/${value}/g"
}

env_variable_macro() {
    tmp_content="${1}"
    key="$(echo "${tmp_content}" | grep "{{REPLACE_ENV|[a-zA-Z0-9_][a-zA-Z0-9_]*}}" | head -n 1 | sed "s/^.*{{REPLACE_ENV|\([a-zA-Z0-9_][a-zA-Z0-9_]*\)}}.*/\1/")"
    if [ "X${key}" = "X" ]; then
       echo "${tmp_content}"
       exit 1
    fi
    value="$(env | grep "^${key}=.*$" | sed -e "s/^${key}=\(.*\)$/\1/")"
    echo "${tmp_content}" | sed "s/{{REPLACE_ENV|${key}}}/${value}/g"
}

get_template() {
    tmp_content="${1}"
    echo "${tmp_content}" | while read line; do
        if [ "X${found}" == "Xtrue" ]; then
            if echo "${line}" | grep "^{{TEMPLATE}}$" >/dev/null; then
                break
            fi
            echo "${line}"
        else
            if echo "${line}" | grep "^{{TEMPLATE}}$" >/dev/null; then
                found="true"
            fi
        fi
    done
}

generate_value() {
    template="${1}"
    key="${2}"
    value="${3}"
    echo "${template}" | sed -e "s/{{key}}/${key}/g" -e "s/{{value}}/${value}/g"
}

apply_template() {
    tmp_content="${1}"
    template="${2}"
    value="${3}"
    delete_template="${4}"
    IFS="\n"
    echo "${tmp_content}" | while read line; do
        if [ "X${justprint}" == "Xtrue" ]; then
            echo "${line}"
        elif [ "X${found}" == "Xtrue" ]; then
            if echo "${line}" | grep "^{{TEMPLATE}}$" >/dev/null; then
                if [ "X${delete_template}" == "Xtrue" ]; then
                    justprint="true"
                    continue
                fi
                echo "${value}"
                echo "{{TEMPLATE}}"
                echo "${template}"
                echo "{{TEMPLATE}}"
                justprint="true"
                continue
            fi
        else
            if echo "${line}" | grep "^{{TEMPLATE}}$" >/dev/null; then
                found="true"
                continue
            fi
            echo "${line}"
        fi
    done
}

generate_content_using_template() {
    tmp_content="${1}"
    # Use REPLACE_CSV function
    tmp_content="$(replace_csv_macro "${tmp_content}")"
    while [ $? == 0 ]; do 
        tmp_content="$(replace_csv_macro "${tmp_content}")"
    done
    # Apply environment variable macro
    tmp_content="$(env_variable_macro "${tmp_content}")"
    # Intellegent curly braces templates
    if [ "X${ITERATE_PREFIX}" != "X" ]; then
        while echo "${tmp_content}" | grep "^{{TEMPLATE}}$" >/dev/null; do
            template="$(get_template "${tmp_content}")"
            for var in $(env); do
                if echo "${var}" | grep "^${ITERATE_PREFIX}" >/dev/null; then
                    key=$(echo "${var}" | sed -r "s/^${ITERATE_PREFIX}([^=]*)=.*/\1/")
                    value=$(echo "${var}" | sed -r "s/^[^=]*=(.*)/\1/")
                        if echo "${ITERATE_CSV_VALUE}" | grep -i -e "^y$" -e "^yes$" -e "^true$" >/dev/null; then
                            for new_val in $(echo "${value}" | tr ',' ' '); do
                                generated_val="$(generate_value "${template}" "${key}" "${new_val}")"
                                tmp_content="$(apply_template "${tmp_content}" "${template}" "${generated_val}")"
                            done
                        else
                            generated_val="$(generate_value "${template}" "${key}" "${value}")"
                            tmp_content="$(apply_template "${tmp_content}" "${template}" "${generated_val}")"
                        fi
                fi
            done
            tmp_content="$(apply_template "${tmp_content}" " " " " true)"
        done
        echo "${tmp_content}"
    fi
}
#### END - function definitions ###############################################


#### EXECUTE ##################################################################
content="$(cat ${CONFIG_FILE})"
content="$(generate_content_using_template "${content}")"
echo "${content}" > "${CONFIG_FILE}"

custom_files="$(echo "${content}" | grep "[\"']lua_custom/" | sed 's|^.*lua_custom/\([a-zA-Z_.]*\).*$|\1|')"
if [ "X${custom_files}" != "X" ]; then
    echo "${custom_files}" | while read module_file; do
        content="$(cat "/usr/share/heka/lua_custom/${module_file}")"
        content="$(generate_content_using_template "${content}")"
        echo "${content}" > "/usr/share/heka/lua_custom/${module_file}"
    done
fi

# Run Heka
exec hekad --config "${CONFIG_FILE}"

