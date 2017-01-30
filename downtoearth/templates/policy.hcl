resource "aws_iam_role_policy" "{{API_NAME}}_Policy" {
    name = "{{API_NAME}}_Policy"
    role = "${aws_iam_role.{{API_NAME}}_Role.id}"
    policy = <<EOF
{{DEFAULT_ROLE}}
EOF
}

resource "aws_iam_role" "{{API_NAME}}_Role" {
  name = "{{API_NAME}}_Role"
  assume_role_policy = <<EOF
{{ROLE_TRUST}}
EOF
}
