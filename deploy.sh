#!/bin/bash

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <project_name> [env]"
    exit 1
fi

project_name=$1
env="dev"

if [[ -n "$2" ]]; then
    if [[ "$2" != "prd" && "$2" != "dev" ]]; then
        echo "Invalid environment: $2. Use 'dev' or 'prd'."
        exit 1
    fi
    env="$2"
fi

project_dir="src/$project_name"
build_dir="dist/$project_name"

if [[ ! -d $project_dir ]]; then
    echo "Project '$project_dir' does not exist"
    exit 1
fi

echo "Installing build dependencies..."
npm ci

echo "Building TypeScript projects..."
npm run build

echo "Installing project dependencies..."
rm -rf "$project_dir/node_modules"
npm i --prefix "$project_dir" --omit=dev

echo "Copying source files to package directory..."
package_dir=`mktemp -d -p dist`
rsync -av \
    --exclude='*.test.js' \
    --exclude='*.map' \
    $build_dir/* $package_dir

echo "Checking dependencies to copy..."
non_aws_deps=$(jq -r '.dependencies | to_entries[] | select(.key != "aws-sdk" and (.key | test("^@?aws-sdk") | not)) | .key' "$project_dir/package.json")

if [[ -z "$non_aws_deps" ]]; then
    echo "Skipping - No non aws-sdk dependencies found"
else
    echo "Copying dependencies..."

    rsync -qav \
        --exclude='.*' \
        --exclude='*.md' \
        --exclude='*.ts' \
        --exclude='*.map' \
        --exclude='test' \
        --exclude='tests' \
        --exclude='__tests__' \
        --exclude='LICENSE' \
        --exclude='aws-sdk' \
        --exclude='@aws-sdk' \
        "$project_dir/node_modules" "$package_dir/"
fi

# package_file="$project_name.zip"

# echo "Creating zip package..."
# (cd $package_dir && zip -qr "../../$package_file" .)

# echo "Created package: $(du -hs $package_file)"

# lambda_name="us-$env-$project_name"
# echo "Updating $lambda_name lambda code..."
# aws lambda update-function-code \
#     --no-cli-pager \
#     --function-name "$lambda_name" \
#     --zip-file "fileb://$package_file"

# package_size=$(du -hs "$package_file" | awk '{print $1}')

# echo "Cleaning up..."
# rm $package_file
# rm -rf $package_dir

# echo "Deployed $project_dir to $lambda_name (size=$package_size)."