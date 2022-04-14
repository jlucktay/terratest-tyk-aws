#!/usr/bin/env bash

### Check if this script is being sourced.
if [[ ${BASH_SOURCE[0]} != "${0}" ]]; then
  echo >&2 "Please use 'eval \$('${BASH_SOURCE[0]}' \"{ <itemName> | <itemID> }\")' (where <item> refers to a 1Password vault item) to make use of this script!"
  return
fi

### Set up some options and a usage func now that we know they won't pollute the shell calling this script.
set -euo pipefail

function usage() {
  echo >&2 "Please use 'eval \$('${BASH_SOURCE[0]}' \"{ <itemName> | <itemID> }\")'"
  echo >&2 "(where <item> refers to a 1Password vault item) to make use of this script!"
  echo >&2 ""
  echo >&2 "The referenced 1Password vault item should have the following labels/fields:"
  echo >&2 "- label 'Access Key ID' on a field containing a valid AWS access key ID"
  echo >&2 "- label 'Secret Access Key' on a field containing a valid AWS secret access key"
  echo >&2 "- label 'MFA ARN' on a field containing an ARN to the virtual MFA configured against the IAM user"
  echo >&2 "- a field of type 'One-Time Password' that gives the token code from the configured MFA"
}

### Check if stdout refers to a terminal.
### It shouldn't, because the output of this script should be run through 'eval'.
if [[ -t 1 ]]; then
  usage
  echo false && exit 1
fi

### Check if exactly one argument was supplied.
### We're expecting the name/ID of a 1Password vault item, that is laid out in a certain way. TODO: more docs.
if [[ $# -ne 1 ]]; then
  usage
  echo false && exit 1
fi

### Set a minimum AWS CLI session limit of 600 seconds/10 minutes.
### Note that 1Password CLI sessions expire after 30 minutes of inactivity.
declare -i -r epoch_minimum=600

### Check if there was a previous AWS session, and if so, how long until it expires.
if [[ -z ${AWS_SESSION_EXPIRATION:-} ]]; then
  echo >&2 "Existing AWS session not found, continuing to authenticate..."

  ### There may be an expired session token that needs to be cleared here.
  ### If not unset, the AWS CLI call below will reference it and always fail.
  unset AWS_SESSION_TOKEN
else
  ### Calculate session expiration in seconds since epoch.
  declare -i sesh_epoch
  sesh_epoch=$(gdate -d"$AWS_SESSION_EXPIRATION" +%s)

  declare -i now_epoch
  now_epoch=$(gdate +%s)

  epoch_diff=$(("$sesh_epoch" - "$now_epoch"))

  if [[ $epoch_diff -lt $epoch_minimum ]]; then
    echo >&2 "Existing AWS session has less than ${epoch_minimum}s remaining, continuing to refresh..."

    ### Expired session token needs to be cleared here, or the AWS CLI call below will reference it and always fail.
    unset AWS_SESSION_TOKEN
  else
    echo >&2 "Existing AWS session has ${epoch_diff}s remaining, asyncing 1Password CLI session refresh and exiting."
    op account get &> /dev/null &
    exit 0
  fi
fi

### Check if there is a valid 1Password CLI session in the current environment.
### If there is, it should reset/refresh the 30m lifespan of the current 1Password CLI session.
echo >&2 "Checking for valid 1Password CLI session..."

if ! op_account_output=$(op account get --format json 2>&1); then
  ### Check whether error output contains 'You are not currently signed in.'
  if [[ $op_account_output != *"You are not currently signed in."* ]]; then
    echo >&2 "Unknown error when checking 1Password CLI session status:"
    echo >&2 "$op_account_output"
    echo false && exit 1
  fi

  echo >&2 "Signing in to 1Password CLI..."

  if ! op_signin_output="$(op signin --force 2>&1)"; then
    echo >&2 "Could not sign in to 1Password CLI:"
    echo >&2 "$op_signin_output"
    echo false && exit 1
  fi

  eval "$op_signin_output"
  echo "$op_signin_output"
fi

### Get the AWS secrets out of 1Password, which also refreshes the 30m 1Password CLI session lifespan.
echo >&2 "Getting details of 1Password item '$1'..."

if ! op_item_json="$(op item get "$1" --format json)"; then
  echo >&2 "Could not get item '$1' from 1Password."
  echo false && exit 1
fi

### Parse out details fetched from 1Password CLI.
echo >&2 "Parsing details of 1Password item '$1'..."

access_key_id="$(jq --exit-status --raw-output \
  '.fields[] | select( .label == "Access Key ID" ) | .value' <<< "$op_item_json")"
secret_access_key="$(jq --exit-status --raw-output \
  '.fields[] | select( .label == "Secret Access Key" ) | .value' <<< "$op_item_json")"
mfa_arn="$(jq --exit-status --raw-output \
  '.fields[] | select( .label == "MFA ARN" ) | .value' <<< "$op_item_json")"
token_code="$(jq --exit-status --raw-output \
  '.fields[] | select( .type == "OTP" ) | .totp' <<< "$op_item_json")"

### Get a new session token using the AWS CLI.
### Session duration will be 1h.
echo >&2 "Getting new AWS session token via the AWS CLI..."

duration_seconds=$(("$epoch_minimum" * 6))

session_token_json=$(
  AWS_ACCESS_KEY_ID="$access_key_id" \
    AWS_SECRET_ACCESS_KEY="$secret_access_key" \
    aws sts get-session-token \
    --duration-seconds "$duration_seconds" \
    --serial-number "$mfa_arn" \
    --token-code "$token_code"
)

sesh_access_key_id=$(jq --exit-status --raw-output .Credentials.AccessKeyId <<< "$session_token_json")
sesh_secret_access_key=$(jq --exit-status --raw-output .Credentials.SecretAccessKey <<< "$session_token_json")
sesh_token=$(jq --exit-status --raw-output .Credentials.SessionToken <<< "$session_token_json")
sesh_expiration=$(jq --exit-status --raw-output .Credentials.Expiration <<< "$session_token_json")

### Output the time-limited session token and associated values, formatted for the calling shell to export via 'eval'.
echo >&2 "Exporting new AWS session token..."

echo "export AWS_ACCESS_KEY_ID=\"$sesh_access_key_id\""
echo "export AWS_SECRET_ACCESS_KEY=\"$sesh_secret_access_key\""
echo "export AWS_SESSION_TOKEN=\"$sesh_token\""
echo 'export AWS_DEFAULT_REGION="eu-west-2"' # London
echo "export AWS_SESSION_EXPIRATION=\"$sesh_expiration\""

echo >&2 "AWS CLI session token expires at: $sesh_expiration"
