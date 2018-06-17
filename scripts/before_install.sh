#!/bin/bash
echo "Starting"
scriptDir=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
deployDir=$(cd "${scriptDir}" && cd .. && pwd)
userdir=$(cd ~ && pwd)

echo "Script: ${BASH_SOURCE[0]}"
echo "Deploy dir: ${deployDir}"
echo "User: ${whoami}"
echo "User dir: ${userdir}"

OPWD=$PWD

apt-get update
apt-get -y dist-upgrade
apt-get install -y curl wget
apt-get install -y ruby2.0
apt-get install -y python-pip

pip install --upgrade awscli

touch ${userdir}/.bashrc
bashRc=$(cat ${userdir}/.bashrc)

if [[ "${bashRc}" != *AWS_ACCESS_KEY_ID* ]]; then
  echo "export AWS_ACCESS_KEY_ID=\"___aws_access_key___\"" >> ${userdir}/.bashrc
  echo "export AWS_SECRET_ACCESS_KEY=\"___aws_secret_key___\"" >> ${userdir}/.bashrc
  echo "export AWS_DEFAULT_REGION=\"us-west-2\"" >> ${userdir}/.bashrc
fi

if [ ! -d "/etc/codedeploy-agent" ]; then
  cd ${userdir}
  wget https://aws-codedeploy-us-west-2.s3.amazonaws.com/latest/install
  chmod +x ./install
  ./install auto
  cd ${OPWD}
fi

source ${scriptDir}/setup_bash.sh

if [[ "${bashRc}" != *NODE_ENV* ]]; then
  echo "export NODE_ENV=___node_env___" >> "${userdir}/.bashrc"
fi

# -----------------AWS LOGS---------------------

# Get the user directory, make an .aws folder in it.
if [ ! -d "${userdir}/.aws" ]; then
  mkdir -p "${userdir}/.aws"
fi

# copy the aws_logs folder contents to the newly created directory
cp -rf ${deployDir}/aws_logs/* ${userdir}/.aws/

# Go to user directory and get the setup python script.  Run script, pointing to the awslogs-agent.cfg file we
# just copied over.
cd "${userdir}" || exit
curl https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O
chmod +x ./awslogs-agent-setup.py

# TODO: Find way to get app name in here so the log_group_name can be specific,
# ie profiles, materials, search
read -r -d '' AwsLogsAgentTemplate << template
[general]
state_file = /var/awslogs/state/agent-state

# The error.log is for legacy compatilbity
[/var/www/api2/error.log]
datetime_format = %Y-%m-%dT%H:%M:%S
file = /var/www/api2/error.log
buffer_duration = 5000
log_stream_name = ${NODE_ENV}
initial_position = start_of_file
log_group_name = Api2-Out

[/var/www/api2/app.log]
datetime_format = %Y-%m-%dT%H:%M:%S
file = /var/www/api2/app.log
buffer_duration = 5000
log_stream_name = ${NODE_ENV}
initial_position = start_of_file
log_group_name = Api2-Out

template

echo "$AwsLogsAgentTemplate" > "${userdir}/.aws/awslogs-agent.cfg"

./awslogs-agent-setup.py -n -r us-west-2 -c "${userdir}/.aws/awslogs-agent.cfg"

mkdir -p /var/www

function setupRollback
{
  if [ -L "/var/www/rollback" ]; then
    unlink /var/www/rollback
  fi

  if [ -d "/var/www/api2" ] || [ -L "/var/www/api2" ]; then
    prevRevision=$(cd /var/www/api2 && pwd -P)
    ln -s ${prevRevision} /var/www/rollback
  fi
}

function symlinkIncrementalDeployment
{
  if [ -L "/var/www/api2" ]; then
    unlink /var/www/api2
  elif [ -d "/var/www/api2" ]; then
    rm -rf /var/www/api2
  fi

  ln -s ${deployDir} /var/www/api2
}

setupRollback
symlinkIncrementalDeployment

cd ${deployDir}

if [ ! -d "/.nvm" ]; then
  touch ${userdir}/.bashrc

  export NVM_DIR="/.nvm"
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash

  if [[ "${bashRc}" != *NVM_DIR* ]]; then
    echo "export NVM_DIR=\"/.nvm\"" >> ${userdir}/.bashrc
    echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"  # This loads nvm" >> ${userdir}/.bashrc
  fi
fi

export NVM_DIR="/.nvm"
chmod a+x $NVM_DIR/nvm.sh
[ -s "$NVM_DIR/nvm.sh" ] && . ${NVM_DIR}/nvm.sh

if [ -z "$(command -v nvm)" ]; then
  echo "NVM is not installed properly. Exiting..." && exit 1;
fi

nodeVersionToUse=$(cat $deployDir/.nvmrc)
nvm install "$nodeVersionToUse"
nvm use "$nodeVersionToUse"

echo "node version: $(node -v)"
echo "npm version: $(npm -v)"

if [ -z "$(which forever)" ]; then
  npm install -g forever
fi
