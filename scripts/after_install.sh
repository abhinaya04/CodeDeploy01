#!/bin/bash

echo "Starting"
scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
deployDir=$(cd "${scriptDir}" && cd .. && pwd)

echo "Script: ${BASH_SOURCE[0]}"
echo "Deploy dir: ${deployDir}"
echo "User: $(whoami)"

cd "${deployDir}" || exit

export NVM_DIR="/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . ${NVM_DIR}/nvm.sh
nvm use

rm -rf ./node_modules
npm install --production
