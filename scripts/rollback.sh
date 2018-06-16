#!/bin/bash

rollbackDir=$(cd /var/www/rollback && pwd -P)

if [ ! -z "${rollbackDir}" ]; then
  apiRealDir=$(cd /var/www/api2 && pwd -P)
  if [ ! -z "${apiRealDir}" ]; then
    ln -s ${apiRealDir} /var/www/broken
  fi

  if [ -L "/var/www/api2" ]; then
    unlink /var/www/api2
  elif [ -d "/var/www/api2" ]; then
    rm -rf /var/www/api2
  fi
  ln -s ${rollbackDir} /var/www/api2

  if [ ! -d "${rollbackDir}/node_modules/forever" ]; then
    if [ -d "${rollbackDir}/node_modules" ]; then
      mkdir -p ${rollbackDir}/node_modules/forever
      cd ${rollbackDir}
      npm install forever
      npm install forever -g
    else
      echo "NPM install didn't run, or node_modules directory missing."
      exit 1;
    fi
  fi
  nodejsc=$(grep -c "env nodejs" ${rollbackDir}/node_modules/forever/bin/forever)
  if [ "$nodejsc" -eq 0 ]; then sed -i -e 's/env node/env nodejs/g' ${rollbackDir}/node_modules/forever/bin/forever; fi
  if [ ! -e "${rollbackDir}/bin/forever" ]; then
    if [ ! -d "${rollbackDir}/bin" ]; then
      mkdir -p ${rollbackDir}/bin
    fi
    ln -s ${rollbackDir}/node_modules/forever/bin/forever ${rollbackDir}/bin/forever
    cd ${rollbackDir}
    chmod +x bin/forever
  fi

  chown -R root.root ${rollbackDir}

  cd ${rollbackDir}
  nodeJsRunning=$(ps aux | grep node | grep -v grep)
  if [ ! -z "${nodeJsRunning}" ]; then
    sudo killall -9 nodejs
    sudo killall -9 node
  fi

  source /root/.bashrc
  sudo su root
  sudo NODE_ENV=___node_env___ ${rollbackDir}/bin/forever start -l ${rollbackDir}/server.log -o ${rollbackDir}/out.log -e ${rollbackDir}/error.log --append ___start_script___.js
fi

sleep 10

result=$(curl -s -I http://localhost:3000/healthCheck)

echo "Curl Result: "
echo "${result}"

export AWS_ACCESS_KEY_ID="___aws_access_key___"
export AWS_SECRET_ACCESS_KEY="___aws_secret_key___"
export AWS_DEFAULT_REGION="us-west-2"

if [[ "${result}" == *"200 OK"* ]]; then
    echo "OKAY. Rollback succeeded. Notifying production support engineers and release engineering..."
    /usr/local/bin/aws ses send-email --from releaseengineering@cricut.com --destination\
      "{ \"ToAddresses\": [\"releaseengineering@cricut.com\"], \"CcAddresses\": [\"softwareengineering@cricut.com\"], \"BccAddresses\": [] }"\
      --message "{ \"Subject\": { \"Data\": \"*** API2 *___node_env___* was Rolled Back to a Previous Revision ***\", \"Charset\": \"UTF-8\" },\
      \"Body\": { \"Text\": { \"Data\": \"API2 deployment failed for *___node_env___*, so it was rolled back to a previous revision.  Rollback was successful.\",\
      \"Charset\": \"UTF-8\" }, \"Html\": { \"Data\": \"API2 *___node_env___* deployment failed, so it was rolled back to a previous revision.  Rollback was successful.\", \"Charset\": \"UTF-8\" }}}"
else
    echo "NO RESPONSE. Notifying production support engineers and release engineering..."
    /usr/local/bin/aws ses send-email --from releaseengineering@cricut.com --destination\
      "{ \"ToAddresses\": [\"releaseengineering@cricut.com\"], \"CcAddresses\": [\"softwareengineering@cricut.com\"], \"BccAddresses\": [] }"\
      --message "{ \"Subject\": { \"Data\": \"*** API2 *___node_env___* Rollback Failed ***\", \"Charset\": \"UTF-8\" },\
      \"Body\": { \"Text\": { \"Data\": \"API2 deployment failed for *___node_env___*, so rollback was attempted, but failed.\", \"Charset\": \"UTF-8\" },\
      \"Html\": { \"Data\": \"API2 *___node_env___* deployment failed, so rollback was attempted, but failed.\", \"Charset\": \"UTF-8\" }}}"
fi
