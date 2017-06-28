LAMBDA_SOURCE="./lambda_handler.py"
LAMBDA_ZIP="./dist/api-lambda.zip"
LAMBDA_STAGE="production"
INPUT_JSON="./api.json"
TERRAFORM_OUTPUT="./sample.tf"

zip -r $LAMBDA_ZIP $LAMBDA_SOURCE

## Use this command to deploy your terraform
downtoearth deploy $INPUT_JSON $LAMBDA_STAGE

## Use this command to only generate the terraform without deploying
# downtoearth generate $INPUT_JSON $TERRAFORM_OUTPUT
