#!/bin/bash

# Define the output file
output_file="app_structure_and_contents.txt"

# Function to check if a file is relevant (add more extensions as needed)
is_relevant_file() {
    case "$1" in
        *.rb|*.js|*.html|*.erb|*.yml|*.yaml|*.json|*.md|Gemfile|Rakefile|*.ru)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Create or overwrite the output file
echo "App Structure and Contents" > "$output_file"
echo "===========================" >> "$output_file"
echo >> "$output_file"

# Generate and append the directory tree
echo "Directory Structure:" >> "$output_file"
tree -L 3 -I 'node_modules|tmp|log|*.log' >> "$output_file"
echo >> "$output_file"

# Function to append file contents to the output file
append_file_contents() {
    local file="$1"
    echo "File: $file" >> "$output_file"
    echo "----------------------" >> "$output_file"
    cat "$file" >> "$output_file"
    echo >> "$output_file"
    echo "----------------------" >> "$output_file"
    echo >> "$output_file"
}

# Traverse the directory and append relevant file contents
find . -type f | while read -r file; do
    if is_relevant_file "$file"; then
        append_file_contents "$file"
    fi
done

echo "App structure and contents have been written to $output_file"
