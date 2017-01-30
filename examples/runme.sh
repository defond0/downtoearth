LAMBDA_SOURCE="./lambda_handler.py"
LAMBDA_ZIP="./dist/api-lambda.zip"
INPUT_JSON="./api.json"
TERRAFORM_OUTPUT="./sample.tf"

zip -r $LAMBDA_ZIP $LAMBDA_SOURCE

## remove flag [--deploy] to only generate terraform without deploying resources
downtoearth $INPUT_JSON $TERRAFORM_OUTPUT --deploy