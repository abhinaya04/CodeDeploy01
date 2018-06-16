#!/bin/bash

function configure_bashrc_with_hosts
{
  bashRcPath="$1"

  touch $bashRcPath
  bashRc=$(cat $bashRcPath)

  if [[ "${bashRc}" != *bash_scripts* ]]; then
    echo "source /var/bash_scripts/*.sh" >> $bashRcPath
  fi

  if [[ "${bashRc}" != *127.0.0.1* ]]; then
    echo "sed -i -e \"s/^127.0.0.1 ip-.*/127.0.0.1 \$(cat /etc/hostname)/\" /etc/hosts" >> $bashRcPath
  fi
}

function setup_bash
{
  if [ ! -d "/var/bash_scripts" ]; then
    mv ${deployDir}/bash_scripts /var/bash_scripts
    chmod -R 755 /var/bash_scripts/*.sh
  fi

  configure_bashrc_with_hosts /root/.bashrc
  configure_bashrc_with_hosts /home/ubuntu/.bashrc
}

setup_bash
