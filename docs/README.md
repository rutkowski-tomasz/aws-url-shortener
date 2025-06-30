# ✂️ aws-url-shortener

A serverless URL shortener built on AWS. This project aims to demonstrate a practical implementation of a serverless architecture for a URL shortening service. It leverages the power of cloud computing to provide reliable, scalable and lightning-fast API endpoints to shorten any URL.

In real world scenario all the projects would probably be managed as separate repositories. However I wanted to showcase how you can utilize best-for-the-job technology and manage everything from business logic to infrastructure in code.

# 🏙️ Architecture

![Architecture Diagram](link-shortener.phase9.drawio.svg)

# 🌳 Repository structure

```sh
├── deploy.sh
├── docs
├── jest.config.js
├── package-lock.json
├── package.json # Configuration for npm workspaces
├── requests # Prepared requests to test the whole solution, configuration at .vscode/settings.json
├── setup # Scripts required for setup first IAM role
├── src
│   ├── delete-url-lambda # Handles delayed deletion after 30 days (TS)
│   ├── dynamodb-stream-lambda # Handling streams from DynamoDB, dispatching to SNS topics (TS)
│   ├── generate-preview-lambda # Generating preview (screenshot) of URL (JS)
│   ├── get-preview-url-lambda # Get signed URL of the generated previews (JS)
│   ├── get-url-lambda # Resolving short url and redirecting (Python)
│   ├── push-notification-lambda # Pusing notification on preview generated event (TS)
│   ├── shorten-url-lambda # Shortening long url (JS)
│   ├── websocket-authorizer-lambda # Authorizing Websocket API connections (TS)
│   └── websocket-manager-lambda # Managing connect and disconnect Websocket API connections (TS)
├── system-tests # Tests veryfing if the application works all together
├── terraform # IaC
└── tsconfig.json
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
1. ✅ X-Ray integration
![X-Ray Trace Map](xray.png)
1. ✅ Create endpoint /get-my-urls using direct API Gateway AWS service direct integration with DynamoDb
1. ✅ Auto generated swagger documentation, TF defined CloudWatch dashboard & alarms
1. ✅ EventBridge bus and rules with scheduling delayed one-time off delete command, Lambda handler
1. ✅ EventBridge schema discovery, event schema generation using AWS Toolkit for VSC
1. ✅ [Powertune](https://docs.aws.amazon.com/lambda/latest/operatorguide/profile-functions.html) lambdas, for example: [shorten-url-lambda](https://lambda-power-tuning.show/#gAAAAQACAAQABsAL;q6rWP7y7zz+x5L8/oNPGP4JOzz/UBs4/;l0+QMZdPEDKXT5Ayl08QM2N3WDPm9NMz), [generate-preview-lambda](https://lambda-power-tuning.show/#AAQABsAL;fWX9RYo0u0XUs2dF;y90OOVNVHjnz4D85)
1. ✅ Performance testing using k6, especially breakpoint-point type
1. Utilize more AWS services...

# 👨🏻‍💻 Development

## CI/CD user permissions update
```sh
./setup/initial-iam-provision.sh # creates ci-cd user that will be used in GitHub Actions
```

## Local apply terraform
```sh
terraform -chdir=terraform workspace select -or-create dev # or 'prd'
terraform -chdir=terraform apply -auto-approve
```

## Local deploy lambda
```sh
# Deploy one or many projects at once
./deploy.sh dev get-url-lambda shorten-url-lambda
# Or just create packages without deploying
./deploy.sh pack websocket-authorizer-lambda
```

## Run tests
```sh
# System tests
npm run system-tests
# All JS & TS projects
npm test
npm test:unit # only unit tests
npm test:integration # only integration tests
npm open:coverage # open coverage HTML
# Single project tests
npm test -w shorten-url-lambda
# Python lambdas
cd src/get-url-lambda && python3 -m unittest discover -v -s ./ -p "*_test.py"
# Performance tests - requires k6 installed
k6 run performance-tests/breaking-point.js
```

## Connect to WS API Gateway
```sh
wscat -c wss://n5qi08a4gg.execute-api.eu-central-1.amazonaws.com/dev \
-H 'Authorization: Bearer eyJraWQiOiJSWmhsT...'
```
