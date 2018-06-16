python -m pip install --user boto3 gitpython
mkdir -p "${HOME}/.aws"
echo -e "[default]\\noutput = json\\nregion = ${AWSREGION}\\n\\n[profile production]\\noutput = json\\nregion = ${AWSREGION}\\n[preview]\\ncloudfront = true" > "${HOME}/.aws/config"
echo -e "[default]\\naws_access_key_id = ${AWS_ACCESS_KEY_ID_DEV}\\naws_secret_access_key = ${AWS_SECRET_ACCESS_KEY_DEV}\\n\\n[production]\\naws_access_key_id = ${AWS_ACCESS_KEY_ID_PROD}\\naws_secret_access_key = ${AWS_SECRET_ACCESS_KEY_PROD}" > "${HOME}/.aws/credentials"
local_app_dir="$(pwd -P)"
deploy_app_dir="${local_app_dir}/../deploy"
git clone --depth 1 -b master git@github.com:cricut/deploy.git "$deploy_app_dir"
cd "$deploy_app_dir" || exit
python deploy.py --application="$APP_NAME" --branch="$CI_BRANCH" --version="$CI_BUILD_NUMBER" --commit="$CI_COMMIT_ID" --local_app_dir="$local_app_dir" --prod_enabled
curl -X POST "https://api.newrelic.com/v2/applications/${NEWRELIC_APP_ID}/deployments.json" -H "X-Api-Key:${NEWRELIC_API_KEY}" -i -H 'Content-Type: application/json' -d "{ \"deployment\": { \"revision\": \"$CI_BUILD_NUMBER\" } }"