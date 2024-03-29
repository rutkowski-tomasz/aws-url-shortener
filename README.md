# ✂️ aws-url-shortener

A serverless URL shortener built on AWS. This project aims to demonstrate a practical implementation of a serverless architecture for a URL shortening service. It leverages the power of cloud computing to provide reliable, scalable and lightning-fast API endpoints to shorten any URL.

# 🏙️ Architecture

![Architecture Diagram](assets/link-shortener.phase1.drawio.svg)
Phase 1. As basic as it gets

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
4. DynamoDB Provisioning
    - Define the DynamoDB table for storing URL mappings in Terraform and provision through GitHub Actions.
5. Resource Monitoring and Management
    - Implement tagging strategy for resources provisioned by Terraform for easier identification and management (tags: application name, project, Terraform-managed).
6. Business Logic for shorten-url-lambda
    - Implement the logic for generating a unique shortcode for each URL.
    - Integrate DynamoDB to persist shortcode-URL mappings.
7. Unit Testing
    - Develop unit tests for the shorten-url-lambda business logic.
    - Integrate unit testing into the CI/CD pipeline, requiring all tests to pass before deployment.
8. Implement get-url-lambda
    - Develop the lambda function to retrieve URLs from DynamoDB based on the shortcode.
    - Implement HTTP redirection to the original URL based on the retrieved mapping.
9. Integration Testing
    - Conduct post-deployment tests to ensure the URL shortening and retrieval functionalities work as expected in the live environment.
10. Environment Differentiation
    - Set up distinct environments for development and production to enable safe testing and stable deployment.
    - Modify GitHub Actions workflows to support manual triggers for production deployments, allowing controlled updates.
11. Infrastructure tear-down
    - Create manually dispatched workflow in GitHub Actions
    - Perform terrafrom destroy of all resources
12. Utilize more AWS services...