#!/bin/bash
# Huawei switches Netconf HTTP API demo

# config here
DEVICE_HTTPS_URL_BASE="https://192.168.1.253"
DEVICE_USERNAME="admin"
DEVICE_PASSWORD="Admin@huawei.com"

# runtime global variables
SESSION_ID=""
TOKEN=""

function login() {
    RET_TEMP=$(
        curl -Lv --insecure --compressed "${DEVICE_HTTPS_URL_BASE}/login.cgi" \
            -H 'content-type: application/x-www-form-urlencoded; text/xml; charset=UTF-8' \
            --data-raw "UserName=${DEVICE_USERNAME}&Password=${DEVICE_PASSWORD}&Edition=0" \
            2>&1
    )

    SESSION_ID=$(grep -ohP "SessionID=(\w+)" <<< "${RET_TEMP}" | cut -d'=' -f2)
    TOKEN=$(grep -ohP "Token=(\w+)" <<< "${RET_TEMP}" | cut -d'=' -f2)
    echo "Logged in."
}

function config() {
    CONFIG_XML=$(<"$1")

    curl --insecure --compressed "${DEVICE_HTTPS_URL_BASE}/config.cgi" \
        -H "Content-Type: application/x-www-form-urlencoded; text/xml; charset=utf-8" \
        -H "Token: ${TOKEN}" \
        -H "Cookie: SessionID=${SESSION_ID}" \
        --data "MessageID=114514&${CONFIG_XML}]]>]]>"

    echo -e "\n\nConfig done."
}

login
config ./examples/auth.xml
