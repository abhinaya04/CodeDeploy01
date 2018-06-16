#!/bin/bash

scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

sleep 10

result=$(curl -s -I http://localhost:3000/healthCheck)

echo "Curl Result: "
echo "${result}"

if [[ "${result}" == *"200 OK"* ]]; then
  echo "OKAY"
  exit 0
else
  # If the expected response is not returned, check the status in forever.js to
  # see if it reports that the service is running or not.
  export NVM_DIR="/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . ${NVM_DIR}/nvm.sh
  forever list

  echo "NO RESPONSE. Rollback script started"
  source ${scriptDir}/rollback.sh
  exit 1;
fi
