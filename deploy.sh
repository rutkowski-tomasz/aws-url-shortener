#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 [dev|prd|pack] <project_name1> <project_name2> ..."
    exit 1
fi

env="$1"
shift

if [[ "$env" != "prd" && "$env" != "dev" && "$env" != "pack" ]]; then
    echo "Invalid environment: $env. Use 'dev', 'prd', or 'pack'."
    exit 1
fi

requires_npm=false
for project_name in "$@"; do
    project_dir="src/$project_name"
    if [[ -f "$project_dir/index.js" || -f "$project_dir/index.ts" ]]; then
        requires_npm=true
        break
    fi
done

if $requires_npm; then
    echo "Installing build dependencies..."
    npm ci

    echo "Building TypeScript projects..."
    npm run build
fi

for project_name in "$@"; do
    start_time=$(date +%s)
    project_dir="src/$project_name"
    build_dir="dist/$project_name"

    if [[ ! -d $project_dir ]]; then
        echo "Project '$project_dir' does not exist"
        continue
    fi

    is_node=$(test -f "$project_dir/index.js" && echo 1 || echo 0)
    is_typescript=$(test -f "$project_dir/index.ts" && echo 1 || echo 0)
    is_python=$(test -f "$project_dir/handler.py" && echo 1 || echo 0)

    mkdir -p dist
    package_dir=$(mktemp -d -p dist)

    if [[ $is_node -eq 1 || $is_typescript -eq 1 ]]; then
        echo "Installing project dependencies..."
        rm -rf "$project_dir/node_modules"
        npm i --prefix "$project_dir" --omit=dev

        count_dependecies=$(jq -r '.dependencies | length' "$project_dir/package.json")

        if [[ $count_dependecies -eq 0 ]]; then
            echo "Skipping - found $count_dependecies dependencies to copy..."
        else
            echo "Found $count_dependecies dependencies - copying..."

            rsync -qav \
                --exclude='.*' \
                --exclude='*.md' \
                --exclude='*.ts' \
                --exclude='*.map' \
                --exclude='*.test.js' \
                --exclude='*.spec.js' \
                --exclude='test' \
                --exclude='tests' \
                --exclude='__tests__' \
                --exclude='__mocks__' \
                --exclude='coverage' \
                --exclude='docs' \
                --exclude='example' \
                --exclude='examples' \
                --exclude='LICENSE' \
                --exclude='*.md' \
                --exclude='yarn.lock' \
                --exclude='jest.config.js' \
                --exclude='webpack.config.js' \
                --exclude='rollup.config.js' \
                --exclude='gulpfile.js' \
                --exclude='Gruntfile.js' \
                --exclude='*.tgz' \
                --exclude='*.log' \
                --exclude='*.d.ts' \
                --exclude='*.json' \
                --exclude='bin' \
                --exclude='obj' \
                "$project_dir/node_modules" "$package_dir/"
        fi
    fi

    if [[ $is_typescript -eq 1 ]]; then
        echo "Copying built files to package directory..."
        rsync -av \
            --exclude='*.test.js' \
            --exclude='*.map' \
            $build_dir/* $package_dir
    fi

    if [[ $is_node -eq 1 ]]; then
        echo "Copying source files to package directory..."
        rsync -av \
            --exclude='node_modules' \
            --exclude='.terraform' \
            --exclude='.terraform.lock.hcl' \
            --exclude='*.test.js' \
            --exclude='*.tf' \
            --exclude='package-lock.json' \
            --exclude='package.json' \
            $project_dir/* $package_dir
    fi

    if [[ $is_python -eq 1 ]]; then
        echo "Copying source files to package directory..."
        rsync -av \
            --exclude='.terraform' \
            --exclude='.terraform.lock.hcl' \
            --exclude='*_test.py' \
            --exclude='*.tf' \
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

    package_file="dist/$project_name.zip"

    echo "Creating zip package..."
    rm -f $package_file
    (cd $package_dir && zip -qr "../../$package_file" .)

    echo "Cleaning up..."
    rm -rf $package_dir

    end_time=$(date +%s)
    build_time=$((end_time - start_time))
    package_size=$(du -hs "$package_file" | awk '{print $1}')

    if [[ $env == "pack" ]]; then
        echo "Packed $project_dir into $package_file (size=$package_size, time=${build_time}s)."
        echo "📦 $project_name → 🏋🏻 $package_size, ⏱️ ${build_time}s" >> $GITHUB_STEP_SUMMARY
    else
        lambda_name="us-$env-$project_name"
        echo "Updating $lambda_name lambda code..."
        aws lambda update-function-code \
            --no-cli-pager \
            --function-name "$lambda_name" \
            --zip-file "fileb://$package_file"

        rm $package_file

        echo "Deployed $project_dir to $lambda_name (size=$package_size, time=${build_time}s)."
    fi
done
