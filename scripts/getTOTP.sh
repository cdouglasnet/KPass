#Get the 6 digit TOTP code of a specific entry in the database if there is one using keepassxc-cli
export PATH='/bin:/usr/local/bin/:/usr/bin:/Applications/KeePassXC.app/Contents/MacOS/:/opt/homebrew/bin:${PATH}'
function get_TOTP {
    if [ ! -z "${keePassKeyFile}" ]; then
        security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" |\
            keepassxc-cli show --key-file "${keePassKeyFile}" -q -t "${database}" "$1"
    else
        security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" |\
            keepassxc-cli show -q -t "${database}" "$1"
    fi
}

function get_errorInfo {
    exec 3<&1
    if [ ! -z "${keePassKeyFile}" ]; then
        security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" 2>&3 |\
           keepassxc-cli ls -R --key-file "${keePassKeyFile}" -f "$database" 2>&3 | grep -Ev '(/|\[empty\]?)$'
    else
        security find-generic-password -a $(id -un) -c 'kpas' -C 'kpas' -s "${keychainItem}" -w "${keychain}" 2>&3 |\
           keepassxc-cli ls -R -f "$database" 2>&3 | grep -Ev '(/|\[empty\]?)$'
    fi
    exec 3>&-
}

data=$(get_TOTP "$1")
if [ $? -ne 0 ]; then
  echo $(get_errorInfo)
else
  echo -n $data
fi