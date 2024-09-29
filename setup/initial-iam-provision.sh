#!/bin/bash

# Variables
policy_name="aws-url-shortener-cicd-policy"
policy_document="policy-document.json"
account_id="024853653660"
region="eu-central-1"

# Policy Document JSON
cat > ${policy_document} << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SnsGlobalManagement",
      "Effect": "Allow",
      "Action": [
        "sns:ListTopics"
      ],
      "Resource": [
        "arn:aws:sns:${region}:${account_id}:*"
      ]
    },
    {
      "Sid": "ResourceManagement",
      "Effect": "Allow",
      "Action": [
        "sns:*",
        "sqs:*",
        "s3:*",
        "cloudwatch:*",
        "events:*"
      ],
      "Resource": [
        "arn:aws:sns:${region}:${account_id}:us-*",
        "arn:aws:sqs:${region}:${account_id}:us-*",
        "arn:aws:s3:::us-*",
        "arn:aws:cloudwatch::${account_id}:dashboard/us-*",
        "arn:aws:events:${region}:${account_id}:event-bus/us-*",
        "arn:aws:events:${region}:${account_id}:rule/us-*",
        "arn:aws:events:${region}:${account_id}:archive/us-*"
      ]
    },
    {
      "Sid": "LogGroupWriteAccess",
      "Effect": "Allow",
      "Action": [
        "logs:DeleteLogGroup"
      ],
      "Resource": "arn:aws:logs:${region}:***:log-group:/aws/api-gateway/us-*"
    },
    {
      "Sid": "LogGroupReadAccess",
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups",
        "logs:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LambdaEventSourceManagement",
      "Effect": "Allow",
      "Action": [
        "lambda:GetEventSourceMapping",
        "lambda:CreateEventSourceMapping",
        "lambda:DeleteEventSourceMapping",
        "lambda:GetLayerVersion",
        "s3:CreateBucket",
        "cognito-idp:ListUserPools",
        "xray:ListResourcePolicies"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LambdaManagement",
      "Effect": "Allow",
      "Action": [
        "lambda:Get*",
        "lambda:List*",
        "lambda:Describe*",
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:TagResource",
        "lambda:AddPermission",
        "lambda:RemovePermission"
      ],
      "Resource": [
        "arn:aws:lambda:${region}:${account_id}:function:us-*"
      ]
    },
    {
      "Sid": "IamManagement",
      "Effect": "Allow",
      "Action": [
        "iam:Get*",
        "iam:List*",
        "iam:CreatePolicy",
        "iam:CreatePolicyVersion",
        "iam:DeletePolicyVersion",
        "iam:CreateRole",
        "iam:DeletePolicy",
        "iam:DeleteRole",
        "iam:TagPolicy",
        "iam:TagRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PassRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:PutRolePolicy"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:policy/us-*",
        "arn:aws:iam::${account_id}:role/us-*"
      ]
    },
    {
      "Sid": "DynamoDbManagement",
      "Effect": "Allow",
      "Action": [
        "dynamodb:Get*",
        "dynamodb:Describe*",
        "dynamodb:List*",
        "dynamodb:CreateTable",
        "dynamodb:UpdateTable",
        "dynamodb:DeleteTable",
        "dynamodb:TagResource"
      ],
      "Resource": [
        "arn:aws:dynamodb:${region}:${account_id}:table/us-*"
      ]
    },
    {
      "Sid": "APIGatewayManagement",
      "Effect": "Allow",
      "Action": [
        "apigateway:GET",
        "apigateway:PUT",
        "apigateway:PATCH",
        "apigateway:POST",
        "apigateway:DELETE"
      ],
      "Resource": [
        "arn:aws:apigateway:eu-central-1::*"
      ]
    },
    {
      "Sid": "ServiceLinkedRoleManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateServiceLinkedRole",
        "iam:DeleteServiceLinkedRole",
        "iam:GetServiceLinkedRoleDeletionStatus"
      ],
      "Resource": "arn:aws:iam::*:role/aws-service-role/*"
    },
    {
      "Sid": "CognitoManagement",
      "Effect": "Allow",
      "Action": [
        "cognito-idp:Get*",
        "cognito-idp:Describe*",
        "cognito-idp:CreateUserPool",
        "cognito-idp:UpdateUserPool",
        "cognito-idp:CreateUserPoolClient",
        "cognito-idp:UpdateUserPoolClient",
        "cognito-idp:DeleteUserPool",
        "cognito-idp:TagResource"
      ],
      "Resource": "arn:aws:cognito-idp:${region}:${account_id}:userpool/*"
    }
  ]
}
EOF

policy_arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName==\`${policy_name}\`].Arn" --output text)
policy_versions_json=$(aws iam list-policy-versions --policy-arn ${policy_arn})
versions_count=$(echo "$policy_versions_json" | jq '.Versions | length')

if [ "$versions_count" -eq 5 ]; then
  oldest_version=$(echo "$policy_versions_json" | jq -r '[.Versions[] | select(.IsDefaultVersion == false) | .VersionId][0]')

  if [ -n "$oldest_version" ] && [ "$oldest_version" != "null" ]; then
    echo "Maximum number of policy versions reached. Deleting oldest non-default version (${oldest_version})..."
    aws iam delete-policy-version --policy-arn ${policy_arn} --version-id ${oldest_version}
  else
    echo "Error: No non-default versions available to delete."
    exit 1
  fi
fi

aws iam create-policy-version \
  --no-cli-pager \
  --policy-arn ${policy_arn} \
  --policy-document file://${policy_document} \
  --set-as-default

# Cleanup
rm -f ${policy_document}
