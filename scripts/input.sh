#!/bin/bash

userdir=$(cd ~ && pwd)

apt-get update
sudo apt-get -y dist-upgrade
apt-get install -y -q curl wget
apt-get install -q -y nodejs npm
apt-get install -q -y node-cli build-essential
apt-get install -y ruby2.0
apt-get install -y python-pip
apt-get install -y imagemagick
### NEWRELIC ENV HERE ###

pip install --upgrade awscli
touch ${userdir}/.bashrc
export AWS_ACCESS_KEY_ID="___aws_access_key___"
export AWS_SECRET_ACCESS_KEY="___aws_secret_key___"
export AWS_DEFAULT_REGION="us-west-2"
if [ -e "${userdir}/.bash_profile" ]; then
  echo "export AWS_ACCESS_KEY_ID=\"___aws_access_key___\"" >> ${userdir}/.bash_profile
  echo "export AWS_SECRET_ACCESS_KEY=\"___aws_secret_key___\"" >> ${userdir}/.bash_profile
  echo "export AWS_DEFAULT_REGION=\"us-west-2\"" >> ${userdir}/.bash_profile
fi
echo "export AWS_ACCESS_KEY_ID=\"___aws_access_key___\"" >> ${userdir}/.bashrc
echo "export AWS_SECRET_ACCESS_KEY=\"___aws_secret_key___\"" >> ${userdir}/.bashrc
echo "export AWS_DEFAULT_REGION=\"us-west-2\"" >> ${userdir}/.bashrc

# Get the user directory, make an .aws folder in it.
if [ ! -d "${userdir}/.aws" ]; then
  mkdir -p "${userdir}/.aws"
fi

mkdir -p /var/www/api2
cd /var/www/api2

if [ ! -d "/.nvm" ]; then
  npm uninstall -g forever
  touch ${userdir}/.bashrc
fi

export NVM_DIR="/.nvm"
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | bash

bashRc=$(cat ${userdir}/.bashrc)
if [[ "${bashRc}" != *NVM_DIR* ]]; then
  echo "export NVM_DIR=\"/.nvm\"" >> ${userdir}/.bashrc
  echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"  # This loads nvm" >> ${userdir}/.bashrc
fi

if [ -e "${userdir}/.bash_profile" ]; then
  bashProfile=$(cat ${userdir}/.bash_profile)
  if [[ "${bashProfile}" != *NVM_DIR* ]]; then
    echo "export NVM_DIR=\"/.nvm\"" >> ${userdir}/.bash_profile
    echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"  # This loads nvm" >> ${userdir}/.bash_profile
  fi
else
  touch ${userdir}/.bash_profile
  echo "source ~/.bashrc" > ${userdir}/.bash_profile
fi

chmod a+x $NVM_DIR/nvm.sh
export NVM_DIR="/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . ${NVM_DIR}/nvm.sh

if [ -z "command -v nvm" ]; then
  echo "NVM is not installed properly. Exiting..." && exit 1;
fi

nvm install 8.5.0
nvm alias default 8.5.0

if [ ! -L /usr/bin/nodejs ]; then
  sudo mv /usr/bin/nodejs /usr/bin/nodejs-OLD
  sudo ln -s /.nvm/versions/node/v8.5.0/bin/node /usr/bin/nodejs
fi

cat > /var/www/api2/server.js <<- EOM
//Lets require/import the HTTP module
var http = require('http');

//Lets define a port we want to listen to
const PORT=3000;

//We need a function which handles requests and send response
function handleRequest(request, response){
    response.end('It Works!! Path Hit: ' + request.url);
}

//Create a server
var server = http.createServer(handleRequest);

//Lets start our server
server.listen(PORT, function(){
    //Callback triggered when server is successfully listening. Hurray!
    console.log("Server listening on: http://localhost:%s", PORT);
});
EOM

cat > /var/www/api2/app.json <<- EOM
{
	"uid":"www-data",
	"append":true,
	"watch":false,
	"script":"server.js",
	"sourceDir":"/var/www/api2"
}
EOM

OPWD=$PWD
if [ ! -d "/var/www/api2/node_modules/forever" ]; then
	mkdir -p /var/www/api2/node_modules/forever
fi

cd /var/www/api2
npm install forever
npm install forever -g

nodejsc=$(grep -c "env nodejs" /var/www/api2/node_modules/forever/bin/forever)
if [ "${nodejsc}" -eq 0 ]; then sed -i -e 's/env node/env nodejs/g' /var/www/api2/node_modules/forever/bin/forever; fi
if [ ! -e "/var/www/api2/bin/forever" ]; then
	if [ ! -d "/var/www/api2/bin" ]; then
		mkdir -p /var/www/api2/bin
	fi
	ln -s /var/www/api2/node_modules/forever/bin/forever /var/www/api2/bin/forever
fi

cd /var/www/api2
chmod +x bin/forever
./bin/forever start app.json

cd ${userdir}
wget https://aws-codedeploy-us-west-2.s3.amazonaws.com/latest/install
chmod +x ./install
./install auto

cd $OPWD
