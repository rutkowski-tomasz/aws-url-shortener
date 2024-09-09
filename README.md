# ✂️ aws-url-shortener

A serverless URL shortener built on AWS. This project aims to demonstrate a practical implementation of a serverless architecture for a URL shortening service. It leverages the power of cloud computing to provide reliable, scalable and lightning-fast API endpoints to shorten any URL.

In real world scenario all the projects would probably be managed as separate repositories. However I wanted to showcase how you can utilize best-for-the-job technology and manage everything from business logic to infrastructure in code.

# 🏙️ Architecture

![Architecture Diagram](assets/link-shortener.phase7.drawio.svg)
Note: transparent elements are ideas for future development.

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

1. ✅ Project Initialization
    - Organize the folder structure for clarity and efficiency.
    - Develop a basic logic for shorten-url-lambda.
    - Elaborate the purpose and scope of this repository in the README.md.
    - Update the initial project architecture diagram to reflect the latest design decisions.
2. ✅ Initial CI/CD & AWS Integration
    - Configure access tokens for CI/CD within GitHub Secrets.
    - Establish GitHub Actions workflows for continuous integration and deployment, triggered on every push to the main branch.
    - Automate the packaging of shorten-url-lambda into a zip file within GitHub Actions.
    - Automate the update of AWS Lambda code directly from GitHub Actions.
3. ✅ Infrastructure as Code (IaC)
    - Initialize Terraform for infrastructure management.
    - Set up Terraform state management using Terraform Cloud.
    - Enable combined code and infrastructure deployment for shorten-url-lambda through GitHub Actions.
    - Refine IAM policies and roles to adhere to the principle of least privilege for all access tokens and AWS resources.
4. ✅ DynamoDB Provisioning
    - Define the DynamoDB table for storing URL mappings in Terraform and provision through GitHub Actions.
5. ✅ Resource Monitoring and Management
    - Implement tagging strategy for resources provisioned by Terraform for easier identification and management (tags: application name, project, Terraform-managed).
6. ✅ Business Logic for shorten-url-lambda
    - Implement the logic for generating a unique shortcode for each URL.
    - Integrate DynamoDB to persist shortcode-URL mappings.
7. ✅ Local deployment
    - Package source code
    - Update lambda code without changing configuration
8. ✅ Unit Testing
    - Develop unit tests for the shorten-url-lambda business logic.
    - Integrate unit testing into the CI/CD pipeline, requiring all tests to pass before deployment.
9. ✅ Implement get-url-lambda
    - Develop the lambda function to retrieve URLs from DynamoDB based on the shortcode.
    - Implement HTTP redirection to the original URL based on the retrieved mapping.
10. ✅ Integration Testing
    - Conduct post-deployment tests to ensure the URL shortening and retrieval functionalities work as expected in the live environment.
11. ✅ Environment Differentiation
    - Set up distinct environments for development and production to enable safe testing and stable deployment.
    - Modify GitHub Actions workflows to support manual triggers for production deployments, allowing controlled updates.
12. ✅ Infrastructure tear-down
    - Create manually dispatched workflow in GitHub Actions
    - Perform terrafrom destroy of all resources
13. ✅ Describe structure of repo
    - Add tree overview
    - Describe each folder and it's purpose
14. ✅ Define common prefix for resources 'us-' for UrlShortener
    - Adjust IAM policies to allow access to prefixed resources
15. ✅ Add API Gateway
    - Integrate shorten-url-lambda and get-url-lambda into single API Gateway
    - Provide it within shared-infrastructure
16. ✅ Cognito SignUp, Login, RefreshToken flows
17. ✅ Link preview generation
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