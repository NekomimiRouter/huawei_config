#!/bin/bash
# Huawei switches Netconf HTTP API demo

# config here
DEVICE_HTTPS_URL_BASE="https://192.168.1.253"
DEVICE_USERNAME="admin"
DEVICE_PASSWORD="Admin@huawei.com"

# runtime global variables
SESSION_ID=""
TOKEN=""

# Authenticate to the web service with username & password
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

# Must be called every 20s to keep the session alive
function keepalive() {
    curl --insecure --compressed -X 'POST' "${DEVICE_HTTPS_URL_BASE}/handshake.cgi" \
        -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
        -H "Cookie: SessionID=${SESSION_ID}" \
        --data-raw 'MessageID=114514&interval=20'

    echo "Keepalive."
}

# Get another token
# Note: the argument "_" is required, its content does not matter
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

# Unknown function
# Usage: customize_service args
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

# NETCONF api
# Usage: config path/to/commands.xml
# XML examples are in the examples directory; see official documentation too
function config() {
    CONFIG_XML=$(<"$1")

    curl --insecure --compressed -X 'POST' "${DEVICE_HTTPS_URL_BASE}/config.cgi" \
        -H "Content-Type: application/x-www-form-urlencoded; text/xml; charset=utf-8" \
        -H "Token: ${TOKEN}" \
        -H "Cookie: SessionID=${SESSION_ID}" \
        --data "MessageID=114514&${CONFIG_XML}]]>]]>"

    echo -e "\n\nConfig done."
}

# Upload a file to the switch
# Usage: upload_file local_path remote_filename
# example: `upload_file ./s1720.cfg s1720.cfg`
# remote filename must be full lower case & ends in a known extension (e.g. *.cfg) & must not be too long
function upload_file() {
    curl --insecure --compressed -X 'POST' "${DEVICE_HTTPS_URL_BASE}/simple/view/main/upload.cgi" \
        -H "Cookie: SessionID=${SESSION_ID}; Token=${TOKEN}" \
        --form "uploadFile_fileDivfileInput=@$1;filename=$2"
}

# Download a file from the switch
# Usage: download_file remote_path local_path
# example: `download_file "flash:/s1720-gw-v200r019sph025.pat" "./test.pat"`
function download_file() {
    curl --insecure --compressed -X 'GET' 'https://192.168.1.253/simple/view/main/download.cgi?0_1' \
        -H "Cookie: SessionID=${SESSION_ID}; filename=\"$1\"; Token=${TOKEN}" \
        --output "$2"
}

# main procedure
source ./credential.sh || true
login
config ./examples/cli_config_auth.xml
