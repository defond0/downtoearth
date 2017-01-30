{%- if not COMPOSABLE %}
provider "aws" {
  region = "${var.region}"
}

variable "region" {
  type = "string"
  default = "{{API_REGION}}"
}

{%- endif %}


resource "aws_api_gateway_rest_api" "{{API_NAME}}" {
  name = "{{API_NAME}}"
  description = "{{API_DESCRIPTION}}"
}

{% for s in STAGES %}
variable "{{s}}_version" {
  type = "string"
  default = "$LATEST"
}

resource "aws_api_gateway_deployment" "{{API_NAME}}_Deployment_{{s}}" {
  stage_name = "{{s}}"
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  stage_name = "{{s}}"
  variables = {
    "stage" = "{{s}}"
  }
}
{% endfor %}

resource "aws_api_gateway_model" "GenericModel" {
  rest_api_id = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
  name = "InstanceInfoModel"
  content_type = "application/json"
  schema = <<EOF
{
  "type": "object"
}
EOF
}

{% include "policy.hcl" %}

{% include "lambda.hcl" %}

{% include "api_endpoints.hcl" %}

output "rest_api_id" {
  value = "${aws_api_gateway_rest_api.{{API_NAME}}.id}"
}

output "rest_api_url" {
  value = "https://${aws_api_gateway_rest_api.{{API_NAME}}.id}.execute-api.${var.region}.amazonaws.com"
}

{% for s in STAGES %}
output "{{s}}_deployment" {
  value = "${aws_api_gateway_deployment.{{API_NAME}}_Deployment_{{s}}.id}"
}
{% endfor %}
