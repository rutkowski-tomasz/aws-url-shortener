# ✂️ aws-url-shortener

A serverless URL shortener built on AWS. This project aims to demonstrate a practical implementation of a serverless architecture for a URL shortening service. It leverages the power of cloud computing to provide reliable, scalable and lightning-fast API endpoints to shorten any URL.

In real world scenario all the projects would probably be managed as separate repositories. However I wanted to showcase how you can utilize best-for-the-job technology and manage everything from business logic to infrastructure in code.

# 🏙️ Architecture

![Architecture Diagram](assets/link-shortener.phase7.drawio.svg)

# 🌳 Repository structure

```sh
├── README.md
├── assets # Image files included in the README file
├── dynamodb-stream-lamda # Lambda handling streams from DynamoDB, dispatching to SNS topics
│   ├── index.js
│   ├── index.test.js
│   └── main.tf
├── generate-preview-lamda # Lambda handling generation of URL preview
│   ├── index.js
│   ├── index.test.js
│   └── main.tf
├── get-preview-url-lamda # Lambda returning generated preview URLs
│   ├── index.js
│   ├── index.test.js
│   └── main.tf
├── get-url-lambda # Python lambda resolving short url
│   ├── handler_test.py
│   ├── handler.py
│   └── main.tf
├── requests # Prepared requests to test the whole solution, see /.vscode/settings.json
├── setup # Scripts required for setup
├── shared-infrastructure # Resources managed outside of projects life-cycle
├── shorten-url-lambda # Lambda shortening long url
│   ├── index.js
│   ├── index.test.js
│   └── main.tf
├── system-tests # Tests veryfing if the application works all together
└── terraform-modules # Shared TF modules between projects
    └── lambda
```

# 🛣️ Roadmap

The development of this solution is iterative, with the roadmap subject to changes as the project evolves. Here's the planned progression:

1. ✅ Project Initialization. Organize the folder structure for clarity and efficiency.
2. ✅ Initial CI/CD & AWS Integration. GitHub actions workflows.
3. ✅ Infrastructure as Code (IaC). Terraform.
4. ✅ DynamoDB Provisioning
5. ✅ Resource Monitoring and Management. Add tags: environment, application, project, terraform-managed.
6. ✅ Implement shorten-url-lambda
7. ✅ Local deployment option
8. ✅ Unit Testing
9. ✅ Implement get-url-lambda. Get URL from DynamoDB and redirect.
10. ✅ Integration Testing
11. ✅ Environment Differentiation. Development and Production. Integrate with TF workspace.
12. ✅ Infrastructure tear-down GitHub actions workflow
13. ✅ Documentation. Tree folder overview. Usefull commands.
14. ✅ Define common prefix for resources 'us-' for UrlShortener
15. ✅ API Gateway. Integrate with lambdas.
16. ✅ Cognito SignUp, Login, RefreshToken flows
17. ✅ Get link to generated previews
17. Utilize more AWS services...

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
# Node lambdas
cd shorten-url-lambda
npm test
# Python lambdas
cd get-url-lambda
python3 -m unittest discover -v -s ./ -p "*_test.py"
```

## Connect to WS API Gateway
```sh
wscat -c wss://os6c0elcng.execute-api.eu-central-1.amazonaws.com/dev/ \
-H 'Authorization: Bearer eyJraWQiOiJSWmhsT' 
```