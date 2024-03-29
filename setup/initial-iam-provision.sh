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
        "iam:CreatePolicy"
      ],
      "Resource": [
        "arn:aws:iam::${account_id}:policy/*"
      ]
    }
  ]
}
EOF

# Check if the policy exists
policy_arn=$(aws iam list-policies --scope Local --query "Policies[?PolicyName==\`${policy_name}\`].Arn" --output text)

if [ -n "$policy_arn" ]; then
  echo "Policy exists. Updating policy..."
  # Update the policy
  aws iam create-policy-version --policy-arn ${policy_arn} --policy-document file://${policy_document} --set-as-default
else
  echo "Policy does not exist. Creating policy..."
  # Create the policy
  aws iam create-policy --policy-name ${policy_name} --policy-document file://${policy_document}
fi

# Cleanup
rm -f ${policy_document}
