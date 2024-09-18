# ✂️ aws-url-shortener

A serverless URL shortener built on AWS. This project aims to demonstrate a practical implementation of a serverless architecture for a URL shortening service. It leverages the power of cloud computing to provide reliable, scalable and lightning-fast API endpoints to shorten any URL.

In real world scenario all the projects would probably be managed as separate repositories. However I wanted to showcase how you can utilize best-for-the-job technology and manage everything from business logic to infrastructure in code.

# 🏙️ Architecture

![Architecture Diagram](link-shortener.phase8.drawio.svg)

# 🌳 Repository structure

```sh
├── docs
├── jest.config.js
├── package.json # Configuration for npm workspaces
├── requests # Prepared requests to test the whole solution, see /.vscode/settings.json
├── setup # Scripts required for setup first IAM role
├── src
│   ├── dynamodb-stream-lambda # Handling streams from DynamoDB, dispatching to SNS topics (TS)
│   ├── generate-preview-lambda # Generating preview (screenshot) of URL (JS)
│   ├── get-preview-url-lambda # Get signed URL of the generated previews (JS)
│   ├── get-url-lambda # Resolving short url and redirecting (Python)
│   ├── push-notification-lambda # Pusing notification on preview generated event (TS)
│   ├── shorten-url-lambda # Shortening long url (JS)
│   ├── websocket-authorizer-lambda # Authorizing Websocket API connections (TS)
│   └── websocket-manager-lambda # Managing connect and disconnect Websocket API connections (TS)
├── system-tests # Tests veryfing if the application works all together
└── terraform
    ├── modules # Shared TF modules between projects
    │   └── lambda # Reused by all lambdas
    └── shared-infrastructure # Resources managed outside of projects life-cycle
```

# 🛣️ Roadmap

The development of this solution is iterative, with the roadmap subject to changes as the project evolves. Here's the planned progression:

1. ✅ Project Initialization. Organize the folder structure for clarity and efficiency.
1. ✅ Initial CI/CD & AWS Integration. GitHub actions workflows.
1. ✅ Infrastructure as Code (IaC). Terraform.
1. ✅ Resource Monitoring and Management. Add tags: environment, application, project, terraform-managed.
1. ✅ Implement shorten-url-lambda, DynamoDB Provisioning
1. ✅ Local deployment option, Jest integration for VSC
1. ✅ Unit Testing
1. ✅ IaC - Configure CloudWatch permissions for lambdas
1. ✅ Implement get-url-lambda. Get URL from DynamoDB and redirect.
1. ✅ Integration Testing
1. ✅ Environment Differentiation. Development and Production. Integrate with TF workspace.
1. ✅ Documentation. Tree folder overview. Usefull commands.
1. ✅ Define common prefix for resources 'us-' for UrlShortener
1. ✅ API Gateway. Integrate with lambdas.
1. ✅ Cognito SignUp, Login, RefreshToken flows
1. ✅ Get presigned URL to generated previews
1. ✅ Create Websocket API (with custom lambda Cognito Authorizer)
1. ✅ Push generated preview event to user
1. Utilize more AWS services...

# 👨🏻‍💻 Development

## CI/CD user permissions update
```sh
./setup/initial-iam-provision.sh
```

## Local apply terraform

```sh
cd shared-infrastructure
terraform workspace select dev # 'dev' or 'prd'
terraform apply -auto-approve
```

## Run tests
```sh
# JS or TS lambdas
npm test -w shorten-url-lambda
# Python lambdas
cd get-url-lambda && python3 -m unittest discover -v -s ./ -p "*_test.py"
```

## Connect to WS API Gateway
```sh
wscat -c wss://os6c0elcng.execute-api.eu-central-1.amazonaws.com/dev/ \
-H 'Authorization: Bearer eyJraWQiOiJSWmhsT...'
```