#!/bin/bash

scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
deployDir=$(cd "${scriptDir}" && cd .. && pwd)
userdir=$(cd ~ && pwd)

echo "Script: ${BASH_SOURCE[0]}"
echo "Deploy dir: ${deployDir}"
echo "User: $(whoami)"
echo "User dir: ${userdir}"

if [ ! -e "${deployDir}/package.json" ]; then
  echo "File 'package.json' not found in the deploy directory '$deployDir'."
  exit 1;
fi

chown -R "$(whoami):$(id -g)" "$deployDir"

cd "$deployDir" || exit

export deploymentDir="${deployDir}" # Needed for common.sh and environment.sh
source "${deployDir}/config/common.sh"

export environment=___node_env___
export cleanShortName="api2" # Needed for environment.sh
export appShortName="Api2" # Needed for environment.sh
source "${deployDir}/config/environment.sh"

export NVM_DIR="/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
# The nvm use command will read the Node version from the .nvmrc file located in
# the directory from where the command is ran.
# See https://github.com/creationix/nvm#nvmrc
nvm use

forever stopall
node_running="$(pgrep -f "node")"
if [ ! -z "$node_running" ]; then
  killall node
fi

NODE_ENV="production" \
NODE_CONFIG_ENV="${environment}" \
forever start ./___start_script___.js
