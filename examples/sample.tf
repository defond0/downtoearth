
provider "aws" {
  region = "${var.region}"
}

variable "region" {
  type = "string"
  default = "us-east-1"
}
variable "stage_name" {
  description = "StageToDeploy"
  default = "develop"
}

resource "aws_api_gateway_rest_api" "Book-API" {
  name = "Book-API"
  description = "An example API for books"
}

resource "aws_api_gateway_deployment" "Book-API_Deployment" {
  stage_name = "${var.stage_name}"
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"

}

resource "aws_api_gateway_model" "GenericModel" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  name = "InstanceInfoModel"
  content_type = "application/json"
  schema = <<EOF
{
  "type": "object"
}
EOF
}

resource "aws_iam_role_policy" "Book-API_Policy" {
    name = "Book-API_Policy"
    role = "${aws_iam_role.Book-API_Role.id}"
    policy = <<EOF
{"Version": "2012-10-17", "Statement": [{"Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], "Resource": "arn:aws:logs:*:*:*", "Effect": "Allow"}]}
EOF
}

resource "aws_iam_role" "Book-API_Role" {
  name = "Book-API_Role"
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

resource "aws_lambda_function" "Book-API_Lambda" {
  function_name = "Book-API_root"
  handler = "lambda_handler.lambda_handler"
  runtime = "python2.7"
  role = "${aws_iam_role.Book-API_Role.arn}"
  timeout = 30

  filename = "dist/api-lambda.zip"
  source_code_hash = "${base64sha256(file("dist/api-lambda.zip"))}"
}

resource "aws_lambda_permission" "with_api_gateway" {
    statement_id = "AllowExecutionFromApiGateway"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.Book-API_Lambda.arn}"
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:${var.region}:[AWS ACCOUNT NUMBER]:*"
}



resource "aws_api_gateway_resource" "v1" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  parent_id = "${ aws_api_gateway_rest_api.Book-API.root_resource_id }"
  path_part = "v1"
}








resource "aws_api_gateway_resource" "v1_book" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  parent_id = "${ aws_api_gateway_resource.v1.id }"
  path_part = "book"
}




resource "aws_api_gateway_method" "v1_book_OPTION" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "v1_book_OPTION_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_OPTION.http_method}"
  type = "MOCK"
  request_templates = {
        "application/json"= "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "v1_book_OPTION_200" {
  depends_on = ["aws_api_gateway_integration.v1_book_OPTION_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_OPTION.http_method}"
  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true,
        "method.response.header.Access-Control-Allow-Headers"= true,
        "method.response.header.Access-Control-Allow-Methods"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_OPTION_IntegrationResponse" {
//  depends_on = ["aws_api_gateway_method_response.v1_book_OPTION_200"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_OPTION.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_OPTION_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Headers"= "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Origin"= "'*'",
        "method.response.header.Access-Control-Allow-Methods"= "'GET,POST'"
  }
}




resource "aws_api_gateway_method" "v1_book_GET" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "GET"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "v1_book_GET_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "GET"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.Book-API_Lambda.arn}/invocations"
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

resource "aws_api_gateway_method_response" "v1_book_GET_200" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_GET_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.v1_book_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_GET_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "v1_book_GET_201" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_GET_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.v1_book_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_GET_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_GET_400" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_GET_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.v1_book_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_GET_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_GET_404" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_GET_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.v1_book_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_GET_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_GET_409" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_GET_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.v1_book_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_GET_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_GET_500" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_GET_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.v1_book_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_GET_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_GET_501" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_GET_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.v1_book_GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_GET_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}


resource "aws_api_gateway_method" "v1_book_POST" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "POST"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "v1_book_POST_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "POST"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.Book-API_Lambda.arn}/invocations"
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

resource "aws_api_gateway_method_response" "v1_book_POST_200" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_POST_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.v1_book_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_POST_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "v1_book_POST_201" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_POST_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.v1_book_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_POST_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_POST_400" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_POST_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.v1_book_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_POST_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_POST_404" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_POST_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.v1_book_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_POST_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_POST_409" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_POST_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.v1_book_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_POST_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_POST_500" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_POST_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.v1_book_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_POST_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book_POST_501" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book_POST_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.v1_book_POST_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book.id}"
  http_method = "${aws_api_gateway_method.v1_book_POST.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book_POST_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}





resource "aws_api_gateway_resource" "v1_book__isbn_" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  parent_id = "${ aws_api_gateway_resource.v1_book.id }"
  path_part = "{isbn}"
}




resource "aws_api_gateway_method" "v1_book__isbn__OPTION" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "v1_book__isbn__OPTION_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__OPTION.http_method}"
  type = "MOCK"
  request_templates = {
        "application/json"= "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__OPTION_200" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__OPTION_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__OPTION.http_method}"
  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true,
        "method.response.header.Access-Control-Allow-Headers"= true,
        "method.response.header.Access-Control-Allow-Methods"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__OPTION_IntegrationResponse" {
//  depends_on = ["aws_api_gateway_method_response.v1_book__isbn__OPTION_200"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__OPTION.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__OPTION_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Headers"= "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Origin"= "'*'",
        "method.response.header.Access-Control-Allow-Methods"= "'GET,PUT,DELETE'"
  }
}




resource "aws_api_gateway_method" "v1_book__isbn__GET" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "GET"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "v1_book__isbn__GET_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "GET"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.Book-API_Lambda.arn}/invocations"
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

resource "aws_api_gateway_method_response" "v1_book__isbn__GET_200" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__GET_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__GET_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "v1_book__isbn__GET_201" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__GET_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__GET_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__GET_400" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__GET_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__GET_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__GET_404" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__GET_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__GET_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__GET_409" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__GET_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__GET_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__GET_500" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__GET_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__GET_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__GET_501" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__GET_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__GET_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__GET.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__GET_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}


resource "aws_api_gateway_method" "v1_book__isbn__PUT" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "PUT"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "v1_book__isbn__PUT_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "PUT"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.Book-API_Lambda.arn}/invocations"
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

resource "aws_api_gateway_method_response" "v1_book__isbn__PUT_200" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__PUT_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__PUT_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__PUT_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "v1_book__isbn__PUT_201" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__PUT_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__PUT_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__PUT_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__PUT_400" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__PUT_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__PUT_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__PUT_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__PUT_404" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__PUT_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__PUT_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__PUT_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__PUT_409" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__PUT_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__PUT_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__PUT_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__PUT_500" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__PUT_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__PUT_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__PUT_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__PUT_501" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__PUT_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__PUT_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__PUT.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__PUT_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}


resource "aws_api_gateway_method" "v1_book__isbn__DELETE" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "DELETE"
  authorization = "AWS_IAM"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "v1_book__isbn__DELETE_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "DELETE"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.Book-API_Lambda.arn}/invocations"
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

resource "aws_api_gateway_method_response" "v1_book__isbn__DELETE_200" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"

  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__DELETE_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__DELETE_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__DELETE_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }
}
resource "aws_api_gateway_method_response" "v1_book__isbn__DELETE_201" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "201"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__DELETE_IntegrationResponse_201" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__DELETE_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__DELETE_201.status_code}"
  selection_pattern = ".*\\[Created\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__DELETE_400" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "400"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__DELETE_IntegrationResponse_400" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__DELETE_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__DELETE_400.status_code}"
  selection_pattern = ".*\\[Bad Request\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__DELETE_404" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "404"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__DELETE_IntegrationResponse_404" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__DELETE_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__DELETE_404.status_code}"
  selection_pattern = ".*\\[Not Found\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__DELETE_409" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "409"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__DELETE_IntegrationResponse_409" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__DELETE_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__DELETE_409.status_code}"
  selection_pattern = ".*\\[Conflict\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__DELETE_500" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "500"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__DELETE_IntegrationResponse_500" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__DELETE_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__DELETE_500.status_code}"
  selection_pattern = ".*\\[Internal Server Error\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}

resource "aws_api_gateway_method_response" "v1_book__isbn__DELETE_501" {
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "501"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
}

resource "aws_api_gateway_integration_response" "v1_book__isbn__DELETE_IntegrationResponse_501" {
  depends_on = ["aws_api_gateway_integration.v1_book__isbn__DELETE_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.Book-API.id}"
  resource_id = "${aws_api_gateway_resource.v1_book__isbn_.id}"
  http_method = "${aws_api_gateway_method.v1_book__isbn__DELETE.http_method}"
  status_code = "${aws_api_gateway_method_response.v1_book__isbn__DELETE_501.status_code}"
  selection_pattern = ".*\\[Not Implemented\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}







output "rest_api_id" {
  value = "${aws_api_gateway_rest_api.Book-API.id}"
}

output "rest_api_url" {
  value = "https://${aws_api_gateway_rest_api.Book-API.id}.execute-api.${var.region}.amazonaws.com"
}