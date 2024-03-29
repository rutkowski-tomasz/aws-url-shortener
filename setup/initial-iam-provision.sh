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
      "Sid": "LambdaManagement",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:UpdateFunctionCode"
      ],
      "Resource": [
        "arn:aws:lambda:${region}:${account_id}:function:*"
      ]
    },
    {
      "Sid": "IamManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreatePolicy",
        "iam:GetPolicy"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:policy/*"
      ]
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

aws iam create-policy-version --policy-arn ${policy_arn} --policy-document file://${policy_document} --set-as-default

# Cleanup
rm -f ${policy_document}
