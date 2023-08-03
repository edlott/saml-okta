#!/bin/bash
# SCRIPT ARGUMENTS
# $1 = environment

# $1 = environment
function validate_env {
  case $1 in
    dev)
      echo "Running Okta for the $1 environment"
    ;;
    *)
      echo "Must specify an environment (dev)"
      exit 1
    ;;
  esac
}

# $1 = environment
function get_workspace {
  case $1 in
    dev) echo "ed-dev" ;;
  esac
}

# $1 = environment
function check_for_and_source_creds {
  if [ ! -f ./okta_creds.sh ]; then
    echo "Must provide the okta_creds.sh script to run okta terraform"
    exit 1
  fi

  source ./okta_creds.sh

  case $1 in
    dev)
      export OKTA_API_TOKEN="$DEV_OKTA_API_TOKEN"
    ;;
  esac
}

validate_env $1
check_for_and_source_creds $1
terraform workspace select $(get_workspace $1)
terraform ${@:2}
