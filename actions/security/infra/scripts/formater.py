import json
import argparse

def format_ansible_lint_issues(json_string):
    data = json.loads(json_string)
    formatted_output = "### Ansible Lint Issues:\n\n"

    for issue in data:
        description = issue.get('description', '')
        file_path = issue.get('location', {}).get('path', '')
        line_number = issue.get('location', {}).get('positions', {}).get('begin', {}).get('line', '')
        column_number = issue.get('location', {}).get('positions', {}).get('begin', {}).get('column', '')

        role_name = None
        if "the role '" in description:
            try:
                role_name = description.split("the role '")[1].split("'")[0]
            except IndexError:
                pass

        formatted_output += f"#### Role '{role_name or 'Unknown'}' Issue:\n\n"
        formatted_output += f"- **File Path:** {file_path}\n"
        formatted_output += f"- **Line Number:** {line_number}\n"
        formatted_output += f"- **Column Number:** {column_number}\n"
        formatted_output += f"- **Description:** {description}\n\n"

    return formatted_output

def main():
    parser = argparse.ArgumentParser(description="Format Ansible Lint Issues JSON to Markdown")
    parser.add_argument("input_file", help="Path to the input JSON file")
    parser.add_argument("output_file", help="Path to the output Markdown file")
    args = parser.parse_args()

    with open(args.input_file, 'r') as file:
        json_string = file.read()

    markdown_output = format_ansible_lint_issues(json_string)

    with open(args.output_file, 'w') as file:
        file.write(markdown_output)

if __name__ == "__main__":
    main()
