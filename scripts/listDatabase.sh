#!/bin/bash
export PATH='/bin:/usr/local/bin/:/usr/bin:/Applications/KeePassXC.app/Contents/MacOS/:/opt/homebrew/bin:${PATH}'

# Set default cache file if enabled but not set
if [ "${cacheEnabled}" = 1 ]; then
    echo "Cache is enabled" >&2
    echo "Cache Enabled Value: ${cacheEnabled}" >&2
    if [ -z "${cacheFile}" ]; then
        cacheFile="${HOME}/Library/Caches/kpass.cache"
        echo "Cache file not set, using default: ${cacheFile}" >&2
        echo "cacheFile=${cacheFile}"
    # if the cache is enabled and a cache file is set, inform the user
    elif [ "${cacheFile}" ]; then
        echo "Cache file already set: ${cacheFile}" >&2
        # echo "$(cat "${cacheFile}")"
    fi
else
    echo "Cache is disabled" >&2
    if [ -f "${cacheFile}" ]; then
        rm -f "${cacheFile}"
        echo "Cache file purged: ${cacheFile}" >&2
    fi
fi

function get_db_keys {
    if [ ! -z "${keePassKeyFile}" ]; then
        security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" |\
            keepassxc-cli search --key-file "${keePassKeyFile}" "${database}" - -q
    else
        security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" |\
            keepassxc-cli search "${database}" - -q
    fi
}

function update_cache {
    echo "Cache is Stale - Updating cache file: ${cacheFile}" >&2
    > "${cacheFile}"
    while read -r entry; do
        if [ ! -z "${keePassKeyFile}" ]; then
            username=$(security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" | \
                keepassxc-cli show --key-file "${keePassKeyFile}" -a Username -q "${database}" "$entry" 2>/dev/null)
        else
            username=$(security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" | \
                keepassxc-cli show -a Username -q "${database}" "$entry" 2>/dev/null)
        fi
        echo "${entry}|${username}" >> "${cacheFile}"
    done < <(get_db_keys)
    touch "${cacheFile}"
}

function get_keys {
    if [ "${cacheEnabled}" != 1 ]; then
        get_db_keys
    else
        # Cache is enabled
        if [ -f "${cacheFile}" ]; then
            lastModifiedTime=$(GetFileInfo -m "${cacheFile}")
        else
            lastModifiedTime=$(date +"%m/%d/%Y %H:%M:%S")
        fi
        lastModifiedTime=$(date -jf "%m/%d/%Y %H:%M:%S" "${lastModifiedTime}" +%s)
        echo "Last Modified Time: ${lastModifiedTime}" >&2
        currTime=$(date +%s)
        interval=$( expr $currTime - $lastModifiedTime )
        if [ ! -f "${cacheFile}" ] || [ "${interval}" -gt "${cacheTimeout}" ]; then
            update_cache
            echo "Interval: ${interval}, Timeout: ${cacheTimeout}" >&2
        else
            echo "Cache is Fine - Using cache file: ${cacheFile}" >&2
            echo "Interval: ${interval}, Timeout: ${cacheTimeout}" >&2
        fi
        # Get keys from the cache
        cat "${cacheFile}" | grep -i "${query}"
    fi
}

function get_errorInfo {
    exec 3<&1
    if [ ! -z "${keePassKeyFile}" ]; then
        security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" 2>&3 |\
            keepassxc-cli search --key-file "${keePassKeyFile}" "${database}" - -q 2>&3
    else
        security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" 2>&3 |\
            keepassxc-cli search "${database}" - -q 2>&3
    fi
    exec 3>&-
}

if [[ -z "${database}" ]] || [[ -z "${keychain}" ]]; then
    echo "{\"items\": [{\"title\":\"Not configured, please run: kpassinit\"}]}"
    exit
fi

items=()
while IFS='|' read -r entry username; do
    iconPath="${PWD}/icon.png"
    items+=("{\"uid\":\"$entry\", \"title\":\"${entry#/}\", \"subtitle\":\"$username\", \"arg\":\"$entry\", \"autocomplete\": \"$entry\", \"icon\":{\"type\":\"png\", \"path\": \"$iconPath\"}}")
done < <(get_keys)

if [ $? -ne 0 ]; then
    info=$(get_errorInfo | sed 's/"/\\"/g')
    info=${info//$'\n'/}
    echo "{\"items\": [{\"title\":\"Error listing database, please check config: Error: ${info}\"}]}"
    exit
else
    printf '{"items": [%s]}\n' "$(IFS=,; echo "${items[*]}")"
fi