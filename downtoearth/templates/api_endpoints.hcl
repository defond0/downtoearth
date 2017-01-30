{% for e in ENDPOINTS %}

resource "aws_api_gateway_resource" "{{ e["NAME"] }}" {
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  parent_id = "${ {{ e["PARENT_RESOURCE_IDENTIFIER"] }} }"
  path_part = "{{ e["PATH_PART"] }}"
}


{% if CORS and e["METHODS"]%}

resource "aws_api_gateway_method" "{{e["NAME"]}}_OPTION" {
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "{{e["NAME"]}}_OPTION_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "${aws_api_gateway_method.{{e["NAME"]}}_OPTION.http_method}"
  type = "MOCK"
  request_templates = {
        "application/json"= "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "{{e["NAME"]}}_OPTION_200" {
  depends_on = ["aws_api_gateway_integration.{{e["NAME"]}}_OPTION_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "${aws_api_gateway_method.{{e["NAME"]}}_OPTION.http_method}"
  status_code = "200"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true,
        "method.response.header.Access-Control-Allow-Headers"= true,
        "method.response.header.Access-Control-Allow-Methods"= true
  }
}

resource "aws_api_gateway_integration_response" "{{e["NAME"]}}_OPTION_IntegrationResponse" {
//  depends_on = ["aws_api_gateway_method_response.{{e["NAME"]}}_OPTION_200"]
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "${aws_api_gateway_method.{{e["NAME"]}}_OPTION.http_method}"
  status_code = "${aws_api_gateway_method_response.{{e["NAME"]}}_OPTION_200.status_code}"
  response_parameters = {
        "method.response.header.Access-Control-Allow-Headers"= "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
        "method.response.header.Access-Control-Allow-Origin"= "'*'",
        "method.response.header.Access-Control-Allow-Methods"= "'{{ e["METHODS_STRING"] }}'"
  }
}

{% endif %}

{% for m in e["METHODS"] %}
resource "aws_api_gateway_method" "{{e["NAME"]}}_{{m}}" {
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "{{m}}"
  authorization = "{{AUTH_TYPE}}"
//  request_models= {
//        "application/json" = "${aws_api_gateway_model.GenericModel.name}"
//    }

}

resource "aws_api_gateway_integration" "{{e["NAME"]}}_{{m}}_Integration" {
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "{{m}}"
  integration_http_method = "POST"
  type = "AWS"
  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.{{API_NAME}}_Lambda.arn}:$${stageVariables.stage}/invocations"
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

resource "aws_api_gateway_method_response" "{{e["NAME"]}}_{{m}}_200" {
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "${aws_api_gateway_method.{{e["NAME"]}}_{{m}}.http_method}"

  status_code = "200"{% if CORS %}
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= true
  }{% endif %}
}

resource "aws_api_gateway_integration_response" "{{e["NAME"]}}_{{m}}_IntegrationResponse" {
  depends_on = ["aws_api_gateway_integration.{{e["NAME"]}}_{{m}}_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "${aws_api_gateway_method.{{e["NAME"]}}_{{m}}.http_method}"
  status_code = "${aws_api_gateway_method_response.{{e["NAME"]}}_{{m}}_200.status_code}"{% if CORS %}
  response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"= "'*'"
  }{% endif %}
}

{#- This enumerates HTTP status codes & messages from RFC7231 #}
{#- Find others at: https://tools.ietf.org/html/rfc7231 #}
{#- this is a tuple to ensure stable ordering #}
{%- set rfc7231codes = (
  ('201', 'Created'),
  ('400', 'Bad Request'),
  ('404', 'Not Found'),
  ('409', 'Conflict'),
  ('500', 'Internal Server Error'),
  ('501', 'Not Implemented')) %}

{%- for code, descr in rfc7231codes %}
resource "aws_api_gateway_method_response" "{{e["NAME"]}}_{{m}}_{{code}}" {
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "${aws_api_gateway_method.{{e["NAME"]}}_{{m}}.http_method}"
  status_code = "{{code}}"
{%- if CORS %}
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"= true
  }
{%- endif %}
}

resource "aws_api_gateway_integration_response" "{{e["NAME"]}}_{{m}}_IntegrationResponse_{{code}}" {
  depends_on = ["aws_api_gateway_integration.{{e["NAME"]}}_{{m}}_Integration"]
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  resource_id = "${aws_api_gateway_resource.{{ e["NAME"] }}.id}"
  http_method = "${aws_api_gateway_method.{{e["NAME"]}}_{{m}}.http_method}"
  status_code = "${aws_api_gateway_method_response.{{e["NAME"]}}_{{m}}_{{code}}.status_code}"
  selection_pattern = ".*\\[{{descr}}\\].*"
  response_templates = {
    "application/json" = <<EOF
{"message": "$input.path('$.errorMessage')"}
EOF
  }
}
{% endfor %}
{% endfor %}

{% endfor %}


