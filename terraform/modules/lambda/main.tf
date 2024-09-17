locals {
  prefix = "us-${var.environment}-"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "${local.prefix}${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${local.prefix}${var.lambda_function_name}-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ],
          Resource = "arn:aws:logs:*:log-group:/aws/lambda/${local.prefix}${var.lambda_function_name}:*",
          Effect   = "Allow",
        }
      ],
      var.custom_policy_statements
    )
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "null_resource" "package_deployment" {
  triggers = {
    always_run : timestamp()
  }

  provisioner "local-exec" {
    command     = <<-EOT
      if [ -f "tsconfig.json" ]; then
        echo "Detected TypeScript project"
        mv ../../package.json ../../temp-package-no-workspaces.json
        echo "Installing node_modules"
        npm i
        echo "Building TypeScript project"
        npm run build
        echo "Packing dist folder"
        cd dist && zip -qr ../deployment-package.zip . && cd ..
        rm -rf dist
        if [ "${var.pack_dependencies}" = "true" ]; then
          echo "Packing node_modules"
          zip -qr deployment-package.zip node_modules/
        fi
        mv ../../temp-package-no-workspaces.json ../../package.json
      elif [ -f "package.json" ]; then
        echo "Detected Node.js project"
        zip -qr deployment-package.zip index.js
        if [ "${var.pack_dependencies}" = "true" ]; then
          echo "Installing node_modules"
          mv ../../package.json ../../temp-package-no-workspaces.json
          npm i
          echo "Packing node_modules"
          zip -qr deployment-package.zip node_modules/
          mv ../../temp-package-no-workspaces.json ../../package.json
        fi
      elif [ -f "requirements.txt" ]; then
        echo "Detected Python project"
        zip -qr deployment-package.zip handler.py
        if [ "${var.pack_dependencies}" = "true" ]; then
          echo "Installing Python dependencies"
          pip3 install -r requirements.txt -t ./package
          echo "Packing Python dependencies"
          cd package && zip -qr ../deployment-package.zip . && cd ..
          rm -rf package
        fi
      fi

      aws s3 cp deployment-package.zip s3://us-cicd/${var.lambda_function_name}/deployment_package.zip
      rm deployment-package.zip
    EOT
    working_dir = path.root
  }
}

resource "aws_lambda_function" "lambda" {
  depends_on    = [null_resource.package_deployment]
  function_name = "${local.prefix}${var.lambda_function_name}"
  handler       = var.lambda_handler
  role          = aws_iam_role.lambda_execution_role.arn
  runtime       = var.lambda_runtime
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout
  layers        = var.lambda_layers
  s3_bucket     = "us-cicd"
  s3_key        = "${var.lambda_function_name}/deployment_package.zip"

  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
      },
      var.environment_variables
    )
  }

  lifecycle {
    replace_triggered_by = [null_resource.package_deployment]
  }
}
