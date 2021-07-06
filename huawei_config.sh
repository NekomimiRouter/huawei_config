#!/bin/bash
# Huawei switches Netconf HTTP API demo

# config here
DEVICE_HTTPS_URL_BASE="https://192.168.1.253"
DEVICE_USERNAME="admin"
DEVICE_PASSWORD="Admin@huawei.com"

# runtime global variables
SESSION_ID=""
TOKEN=""

# authenticate to the web service with username & password
function login() {
    RET_TEMP=$(
        curl -Lv --insecure --compressed -X 'POST' "${DEVICE_HTTPS_URL_BASE}/login.cgi" \
            -H 'content-type: application/x-www-form-urlencoded; text/xml; charset=UTF-8' \
            --data-raw "UserName=${DEVICE_USERNAME}&Password=${DEVICE_PASSWORD}&Edition=0" \
            2>&1
    )

    SESSION_ID=$(grep -ohP "SessionID=(\w+)" <<< "${RET_TEMP}" | cut -d'=' -f2)
    TOKEN=$(grep -ohP "Token=(\w+)" <<< "${RET_TEMP}" | cut -d'=' -f2)
    echo "Logged in."
}

# called every 20s to keep the session alive
function keepalive() {
    curl --insecure --compressed -X 'POST' "${DEVICE_HTTPS_URL_BASE}/handshake.cgi" \
        -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
        -H "Cookie: SessionID=${SESSION_ID}" \
        --data-raw 'MessageID=114514&interval=20'

    echo "Keepalive."
}

# get another token
# argument "_" is required
function token_refresh() {
    RET_TEMP=$(
        curl --insecure --compressed -X 'POST' "${DEVICE_HTTPS_URL_BASE}/token.cgi?_=0" \
            -H 'Content-Length: 0' \
            -H "Token: ${TOKEN}" \
            -H "Cookie: LSWlanguage=lsw_lang_en.js; icbs_language=en; UserName=admin; SessionID=${SESSION_ID}"
    )

    TOKEN=$(grep -ohP "Token=(\w+)" <<< "${RET_TEMP}" | cut -d'=' -f2)
    echo "Token refreshed."
}

# Unknown
# call patterns:
# "CustomizeCode=173"
# "CustomizeCode=126"
# "CustomizeCode=100&SlotID=[1:0]"
function customize_service() {
    curl --insecure --compressed -X 'POST' 'https://192.168.1.253/customizeservice.cgi' \
        -H 'content-type: application/x-www-form-urlencoded; text/xml; charset=UTF-8' \
        -H "Cookie: SessionID=${SESSION_ID}" \
        --data-raw "$1"
}

# get/set device status
function config() {
    CONFIG_XML=$(<"$1")

    curl --insecure --compressed -X 'POST' "${DEVICE_HTTPS_URL_BASE}/config.cgi" \
        -H "Content-Type: application/x-www-form-urlencoded; text/xml; charset=utf-8" \
        -H "Token: ${TOKEN}" \
        -H "Cookie: SessionID=${SESSION_ID}" \
        --data "MessageID=114514&${CONFIG_XML}]]>]]>"

    echo -e "\n\nConfig done."
}

source ./credential.sh || true
login
config ./examples/cli_config_auth.xml
