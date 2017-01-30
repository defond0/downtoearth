
provider "aws" {
  region = "${var.region}"
}

variable "region" {
  type = "string"
  default = "us-east-1"
}


resource "aws_api_gateway_rest_api" "DownToEarthApi" {
  name = "DownToEarthApi"
  description = "test API for the downtoearth tool"
}


variable "production_version" {
  type = "string"
  default = "$LATEST"
}

resource "aws_api_gateway_deployment" "DownToEarthApi_Deployment_production" {
  stage_name = "production"
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  stage_name = "production"
  variables = {
    "stage" = "production"
  }
}


resource "aws_api_gateway_model" "GenericModel" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  name = "InstanceInfoModel"
  content_type = "application/json"
  schema = <<EOF
{
  "type": "object"
}
EOF
}

resource "aws_iam_role_policy" "DownToEarthApi_Policy" {
    name = "DownToEarthApi_Policy"
    role = "${aws_iam_role.DownToEarthApi_Role.id}"
    policy = <<EOF
{"Version": "2012-10-17", "Statement": [{"Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], "Resource": "arn:aws:logs:*:*:*", "Effect": "Allow"}]}
EOF
}

resource "aws_iam_role" "DownToEarthApi_Role" {
  name = "DownToEarthApi_Role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "DownToEarthApi_Lambda" {
  function_name = "DownToEarthApi_root"
  handler = "lambda_handler.lambda_handler"
  runtime = "python2.7"
  role = "${aws_iam_role.DownToEarthApi_Role.arn}"
  timeout = 30
  filename = "dist/api-lambda.zip"
}


resource "aws_lambda_permission" "with_api_gateway_production" {
  statement_id = "AllowExecutionFromApiGateway"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.DownToEarthApi_Lambda.arn}"
  principal = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${var.region}:651193231129:*"
  qualifier = "production"
}

resource "aws_lambda_alias" "production" {
  name = "production"
  description = "deploy"
  function_name = "${aws_lambda_function.DownToEarthApi_Lambda.arn}"
  function_version = "${aws_lambda_function.DownToEarthApi_Lambda.version}"
}




resource "aws_api_gateway_resource" "api" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  parent_id = "${ aws_api_gateway_rest_api.DownToEarthApi.root_resource_id }"
  path_part = "api"
}








resource "aws_api_gateway_resource" "api_Y" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  parent_id = "${ aws_api_gateway_resource.api.id }"
  path_part = "Y"
}




resource "aws_api_gateway_method" "api_Y_OPTION" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_Y_OPTION_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_OPTION.http_method}"
  type = "MOCK"
  request_templates = {
        "application/json"= "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "api_Y_OPTION_200" {
  depends_on = ["aws_api_gateway_integration.api_Y_OPTION_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_OPTION.http_method}"
  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true,
        "method.response.header.Access-Control-Allow-Headers"= true,
        "method.response.header.Access-Control-Allow-Methods"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_OPTION_IntegrationResponse" {
//  depends_on = ["aws_api_gateway_method_response.api_Y_OPTION_200"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_OPTION.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_OPTION_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Headers"= "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Origin"= "'*'",
        "method.response.header.Access-Control-Allow-Methods"= "'GET,POST'"
  }
}




resource "aws_api_gateway_method" "api_Y_GET" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "GET"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "api_Y_GET_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "GET"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.DownToEarthApi_Lambda.arn}:$${stageVariables.stage}/invocations"
  request_templates = {
    "application/json" = <<EOF
{
  "body": $input.json('$'),
  "route": "$context.httpMethod:$context.resourcePath",
  "querystring": {
    #foreach($param in $input.params().querystring.keySet())
    "$param": "$util.escapeJavaScript($input.params().querystring.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "path": {
    #foreach($param in $input.params().path.keySet())
    "$param": "$util.escapeJavaScript($input.params().path.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "headers": {
    #foreach($param in $input.params().header.keySet())
    "$param": "$util.escapeJavaScript($input.params().header.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "stage" : "$context.stage"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_GET_200" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_GET_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.api_Y_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_GET_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "api_Y_GET_201" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_GET_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.api_Y_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_GET_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_GET_400" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_GET_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.api_Y_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_GET_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_GET_404" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_GET_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.api_Y_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_GET_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_GET_409" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_GET_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.api_Y_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_GET_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_GET_500" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_GET_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.api_Y_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_GET_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_GET_501" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_GET_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.api_Y_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_GET_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}


resource "aws_api_gateway_method" "api_Y_POST" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "POST"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "api_Y_POST_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "POST"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.DownToEarthApi_Lambda.arn}:$${stageVariables.stage}/invocations"
  request_templates = {
    "application/json" = <<EOF
{
  "body": $input.json('$'),
  "route": "$context.httpMethod:$context.resourcePath",
  "querystring": {
    #foreach($param in $input.params().querystring.keySet())
    "$param": "$util.escapeJavaScript($input.params().querystring.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "path": {
    #foreach($param in $input.params().path.keySet())
    "$param": "$util.escapeJavaScript($input.params().path.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "headers": {
    #foreach($param in $input.params().header.keySet())
    "$param": "$util.escapeJavaScript($input.params().header.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "stage" : "$context.stage"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_POST_200" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_POST_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.api_Y_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_POST_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "api_Y_POST_201" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_POST_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.api_Y_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_POST_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_POST_400" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_POST_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.api_Y_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_POST_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_POST_404" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_POST_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.api_Y_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_POST_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_POST_409" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_POST_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.api_Y_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_POST_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_POST_500" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_POST_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.api_Y_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_POST_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y_POST_501" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y_POST_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.api_Y_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y.id}"
  http_method = "${aws_api_gateway_method.api_Y_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y_POST_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}





resource "aws_api_gateway_resource" "api_Y__1_" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  parent_id = "${ aws_api_gateway_resource.api_Y.id }"
  path_part = "{1}"
}




resource "aws_api_gateway_method" "api_Y__1__OPTION" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_Y__1__OPTION_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__OPTION.http_method}"
  type = "MOCK"
  request_templates = {
        "application/json"= "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "api_Y__1__OPTION_200" {
  depends_on = ["aws_api_gateway_integration.api_Y__1__OPTION_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__OPTION.http_method}"
  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true,
        "method.response.header.Access-Control-Allow-Headers"= true,
        "method.response.header.Access-Control-Allow-Methods"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y__1__OPTION_IntegrationResponse" {
//  depends_on = ["aws_api_gateway_method_response.api_Y__1__OPTION_200"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__OPTION.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y__1__OPTION_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Headers"= "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Origin"= "'*'",
        "method.response.header.Access-Control-Allow-Methods"= "'GET'"
  }
}




resource "aws_api_gateway_method" "api_Y__1__GET" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "GET"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "api_Y__1__GET_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "GET"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.DownToEarthApi_Lambda.arn}:$${stageVariables.stage}/invocations"
  request_templates = {
    "application/json" = <<EOF
{
  "body": $input.json('$'),
  "route": "$context.httpMethod:$context.resourcePath",
  "querystring": {
    #foreach($param in $input.params().querystring.keySet())
    "$param": "$util.escapeJavaScript($input.params().querystring.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "path": {
    #foreach($param in $input.params().path.keySet())
    "$param": "$util.escapeJavaScript($input.params().path.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "headers": {
    #foreach($param in $input.params().header.keySet())
    "$param": "$util.escapeJavaScript($input.params().header.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "stage" : "$context.stage"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y__1__GET_200" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y__1__GET_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.api_Y__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y__1__GET_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "api_Y__1__GET_201" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y__1__GET_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.api_Y__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y__1__GET_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y__1__GET_400" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y__1__GET_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.api_Y__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y__1__GET_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y__1__GET_404" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y__1__GET_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.api_Y__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y__1__GET_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y__1__GET_409" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y__1__GET_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.api_Y__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y__1__GET_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y__1__GET_500" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y__1__GET_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.api_Y__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y__1__GET_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_Y__1__GET_501" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_Y__1__GET_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.api_Y__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_Y__1_.id}"
  http_method = "${aws_api_gateway_method.api_Y__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_Y__1__GET_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}





resource "aws_api_gateway_resource" "api_X" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  parent_id = "${ aws_api_gateway_resource.api.id }"
  path_part = "X"
}




resource "aws_api_gateway_method" "api_X_OPTION" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_X_OPTION_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_OPTION.http_method}"
  type = "MOCK"
  request_templates = {
        "application/json"= "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "api_X_OPTION_200" {
  depends_on = ["aws_api_gateway_integration.api_X_OPTION_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_OPTION.http_method}"
  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true,
        "method.response.header.Access-Control-Allow-Headers"= true,
        "method.response.header.Access-Control-Allow-Methods"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_OPTION_IntegrationResponse" {
//  depends_on = ["aws_api_gateway_method_response.api_X_OPTION_200"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_OPTION.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_OPTION_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Headers"= "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Origin"= "'*'",
        "method.response.header.Access-Control-Allow-Methods"= "'GET,POST'"
  }
}




resource "aws_api_gateway_method" "api_X_GET" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "GET"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "api_X_GET_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "GET"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.DownToEarthApi_Lambda.arn}:$${stageVariables.stage}/invocations"
  request_templates = {
    "application/json" = <<EOF
{
  "body": $input.json('$'),
  "route": "$context.httpMethod:$context.resourcePath",
  "querystring": {
    #foreach($param in $input.params().querystring.keySet())
    "$param": "$util.escapeJavaScript($input.params().querystring.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "path": {
    #foreach($param in $input.params().path.keySet())
    "$param": "$util.escapeJavaScript($input.params().path.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "headers": {
    #foreach($param in $input.params().header.keySet())
    "$param": "$util.escapeJavaScript($input.params().header.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "stage" : "$context.stage"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_GET_200" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_GET_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.api_X_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_GET_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "api_X_GET_201" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_GET_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.api_X_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_GET_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_GET_400" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_GET_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.api_X_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_GET_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_GET_404" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_GET_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.api_X_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_GET_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_GET_409" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_GET_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.api_X_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_GET_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_GET_500" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_GET_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.api_X_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_GET_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_GET_501" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_GET_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.api_X_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_GET_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}


resource "aws_api_gateway_method" "api_X_POST" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "POST"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "api_X_POST_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "POST"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.DownToEarthApi_Lambda.arn}:$${stageVariables.stage}/invocations"
  request_templates = {
    "application/json" = <<EOF
{
  "body": $input.json('$'),
  "route": "$context.httpMethod:$context.resourcePath",
  "querystring": {
    #foreach($param in $input.params().querystring.keySet())
    "$param": "$util.escapeJavaScript($input.params().querystring.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "path": {
    #foreach($param in $input.params().path.keySet())
    "$param": "$util.escapeJavaScript($input.params().path.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "headers": {
    #foreach($param in $input.params().header.keySet())
    "$param": "$util.escapeJavaScript($input.params().header.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "stage" : "$context.stage"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_POST_200" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_POST_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.api_X_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_POST_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "api_X_POST_201" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_POST_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.api_X_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_POST_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_POST_400" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_POST_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.api_X_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_POST_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_POST_404" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_POST_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.api_X_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_POST_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_POST_409" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_POST_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.api_X_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_POST_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_POST_500" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_POST_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.api_X_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_POST_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X_POST_501" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X_POST_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.api_X_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X.id}"
  http_method = "${aws_api_gateway_method.api_X_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X_POST_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}





resource "aws_api_gateway_resource" "api_X__1_" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  parent_id = "${ aws_api_gateway_resource.api_X.id }"
  path_part = "{1}"
}




resource "aws_api_gateway_method" "api_X__1__OPTION" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_X__1__OPTION_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__OPTION.http_method}"
  type = "MOCK"
  request_templates = {
        "application/json"= "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "api_X__1__OPTION_200" {
  depends_on = ["aws_api_gateway_integration.api_X__1__OPTION_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__OPTION.http_method}"
  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true,
        "method.response.header.Access-Control-Allow-Headers"= true,
        "method.response.header.Access-Control-Allow-Methods"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X__1__OPTION_IntegrationResponse" {
//  depends_on = ["aws_api_gateway_method_response.api_X__1__OPTION_200"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__OPTION.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X__1__OPTION_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Headers"= "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Origin"= "'*'",
        "method.response.header.Access-Control-Allow-Methods"= "'GET'"
  }
}




resource "aws_api_gateway_method" "api_X__1__GET" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "GET"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "api_X__1__GET_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "GET"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.DownToEarthApi_Lambda.arn}:$${stageVariables.stage}/invocations"
  request_templates = {
    "application/json" = <<EOF
{
  "body": $input.json('$'),
  "route": "$context.httpMethod:$context.resourcePath",
  "querystring": {
    #foreach($param in $input.params().querystring.keySet())
    "$param": "$util.escapeJavaScript($input.params().querystring.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "path": {
    #foreach($param in $input.params().path.keySet())
    "$param": "$util.escapeJavaScript($input.params().path.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "headers": {
    #foreach($param in $input.params().header.keySet())
    "$param": "$util.escapeJavaScript($input.params().header.get($param))" #if($foreach.hasNext),#end

    #end
  },
  "stage" : "$context.stage"
}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X__1__GET_200" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X__1__GET_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.api_X__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X__1__GET_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "api_X__1__GET_201" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X__1__GET_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.api_X__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X__1__GET_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X__1__GET_400" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X__1__GET_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.api_X__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X__1__GET_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X__1__GET_404" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X__1__GET_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.api_X__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X__1__GET_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X__1__GET_409" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X__1__GET_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.api_X__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X__1__GET_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X__1__GET_500" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X__1__GET_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.api_X__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X__1__GET_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "api_X__1__GET_501" {
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "api_X__1__GET_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.api_X__1__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
  resource_id = "${aws_api_gateway_resource.api_X__1_.id}"
  http_method = "${aws_api_gateway_method.api_X__1__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.api_X__1__GET_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}







output "rest_api_id" {
  value = "${aws_api_gateway_rest_api.DownToEarthApi.id}"
}

output "rest_api_url" {
  value = "https://${aws_api_gateway_rest_api.DownToEarthApi.id}.execute-api.${var.region}.amazonaws.com"
}


output "production_deployment" {
  value = "${aws_api_gateway_deployment.DownToEarthApi_Deployment_production.id}"
}
