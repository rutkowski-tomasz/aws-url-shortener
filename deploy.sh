#!/bin/bash

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <project_name> [dev|prd|pack]"
    exit 1
fi

project_name=$1
env="dev"

if [[ -n "$2" ]]; then
    if [[ "$2" != "prd" && "$2" != "dev" && $2 != "pack" ]]; then
        echo "Invalid environment: $2. Use 'dev' or 'prd' or 'pack'."
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

is_node=$(test -f "$project_dir/index.js" && echo 1 || echo 0)
is_typescript=$(test -f "$project_dir/index.ts" && echo 1 || echo 0)
is_python=$(test -f "$project_dir/handler.py" && echo 1 || echo 0)
package_dir=mktemp -d -p dist

if [[ $is_node -eq 1 || $is_typescript -eq 1 ]]; then
    echo "Installing build dependencies..."
    npm ci

    echo "Installing project dependencies..."
    rm -rf "$project_dir/node_modules"
    npm i --prefix "$project_dir" --omit=dev

    count_dependecies=$(jq -r '.dependencies | length' "$project_dir/package.json")

    if [[ $count_dependecies -eq 0 ]]; then
        echo "Skipping - found $count_dependecies dependencies to copy..."
    else
        echo "Found $count_dependecies dependencies - copying..."

        rsync -qav \
            --exclude='.' \
            --exclude='.md' \
            --exclude='.ts' \
            --exclude='.map' \
            --exclude='test' \
            --exclude='tests' \
            --exclude='tests' \
            --exclude='LICENSE' \
            "$project_dir/node_modules" "$package_dir/"
    fi
fi

if [[ $is_typescript -eq 1 ]]; then
    echo "Building TypeScript projects..."
    npm run build

    echo "Copying built files to package directory..."
    rsync -av \
        --exclude='.test.js' \
        --exclude='.map' \
        $build_dir/* $package_dir
fi

if [[ $is_node -eq 1 ]]; then

    echo "Copying source files to package directory..."
    rsync -av \
        --exclude='node_modules' \
        --exclude='.terraform' \
        --exclude='.terraform.lock.hcl' \
        --exclude='.test.js' \
        --exclude='.tf' \
        --exclude='package-lock.json' \
        --exclude='package.json' \
        $project_dir/* $package_dir
fi

if [[ $is_python -eq 1 ]]; then

    echo "Copying source files to package directory..."
    rsync -av \
        --exclude='.terraform' \
        --exclude='.terraform.lock.hcl' \
        --exclude='_test.py' \
        --exclude='.tf' \
        --exclude='requirements-dev.txt' \
        --exclude='requirements.txt' \
        $project_dir/* $package_dir

    count_dependecies=$(cat "$project_dir/requirements.txt" | sed '/^\s*$/d' | wc -l)

    if [[ $count_dependecies -eq 0 ]]; then
        echo "Skipping - found $count_dependecies dependencies to install..."
    else
        echo "Found $count_dependecies dependencies - installing..."

        (cd $project_dir && pip3 install -r requirements.txt -t "../../$package_dir")
        ls -l $package_dir
    fi
fi

package_file="$project_name.zip"
package_size=$(du -hs "$package_file" | awk '{print $1}')

echo "Creating zip package..."
(cd $package_dir && zip -qr "../../$package_file" .)

if [[ $env == "pack" ]]; then
    echo "Cleaning up..."
    rm -rf $package_dir

    echo "Packed $project_dir into $package_dir (size=$package_size)."
else
    lambda_name="us-$env-$project_name"
    echo "Updating $lambda_name lambda code..."
    aws lambda update-function-code \
        --no-cli-pager \
        --function-name "$lambda_name" \
        --zip-file "fileb://$package_file"

    echo "Cleaning up..."
    rm $package_file
    rm -rf $package_dir

    echo "Deployed $project_dir to $lambda_name (size=$package_size)."
fi
