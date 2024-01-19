#!/bin/bash

HARBOR_ENDPOINT="http://kcr.khalti.com.np:5000/api/v2.0"
CREATE_PROJECT_ENDPOINT="$HARBOR_ENDPOINT/projects"
GET_PROJECT_ENDPOINT="$HARBOR_ENDPOINT/projects?page=1&page_size=50&public=false&with_detail=false"
RETENTATION_ENPOINT="$HARBOR_ENDPOINT/retentions"
VAULT_PATH=$VAULT_SECRETS_CICD_PATH

curl -H "X-Vault-Token: ${VAULT_TOKEN}" "https://${VAULT_SERVER}/v1/${VAULT_PATH}" | jq -r .data.ADMIN_PASSWORD > "$USERNAME"
curl -H "X-Vault-Token: ${VAULT_TOKEN}" "https://${VAULT_SERVER}/v1/${VAULT_PATH}" | jq -r .data.DB_PASSWORD > "$PASSWORD"

new_project="$1"

# Function to list existing projects
list_projects() {
    response=$(curl -s -u "$USERNAME:$PASSWORD" "$GET_PROJECT_ENDPOINT")
    if [ $? -eq 0 ]; then
        echo "$response" | jq -r '.[] | "\(.project_id) \(.name)"'
    else
        echo "Failed to fetch projects $response"
        return 1
    fi
}

# Create Project
create_project() {
    project_list=$(list_projects)
    for project in $project_list; do
        if [ "$new_project" == "$project" ]; then
            echo "Project Name already exists! Select a new project name and run the script again"
            return
        fi
    done

    response=$(curl -s -u "$USERNAME:$PASSWORD" -H "Content-Type: application/json" "$CREATE_PROJECT_ENDPOINT" -d "{\"project_name\":\"$new_project\",\"metadata\":{\"public\":\"false\"}}")
    
    if [ $? -eq 0 ]; then
        echo "Project with name: $new_project created"
    else
        echo "Failed to create project $new_project. Status code: $?"
        echo "Response: $response"
    fi
}

# Function to get project id
get_project_id() {
    project_endpoint="$CREATE_PROJECT_ENDPOINT/$new_project"
    response=$(curl -s -u "$USERNAME:$PASSWORD" "$project_endpoint")
    if [ $? -eq 0 ]; then
        echo "$response" | jq -r '.project_id'
    else
        echo "Failed to fetch project id $response"
        return 1
    fi
}

create_retention_policy() {
    project_ref=$(get_project_id)
    # Retention policy payload
    local payload='{
        "algorithm": "or",
        "id": 1,
        "rules": [
            {
                "action": "retain",
                "params": {
                    "latestPushedK": 10
                },
                "scope_selectors": {
                    "repository": [
                        {
                            "decoration": "repoMatches",
                            "kind": "doublestar",
                            "pattern": "**"
                        }
                    ]
                },
                "tag_selectors": [
                    {
                        "decoration": "matches",
                        "extras": "{\"untagged\":true}",
                        "kind": "doublestar",
                        "pattern": "**"
                    }
                ],
                "template": "latestPushedK"
            }
        ],
        "scope": {
            "level": "project",
            "ref": '$project_ref'
        },
        "trigger": {
            "kind": "Schedule",
            "settings": {
              "cron": "0 0 0 * * *"  
            }
        }
    }'

    # Send POST request
    local response=$(curl  --write-out %{http_code} --silent --output /dev/null -s -u "$USERNAME:$PASSWORD" -H "Content-Type: application/json" "$RETENTATION_ENPOINT" -d "$payload")
    # status_code=$(curl --write-out %{http_code} --silent --output /dev/null $)

    if [ $response -eq 201 ]; then
        echo "Retention policy created successfully"
    else
        echo "Failed to create retention policy. Status code: $status_code"
        echo "$response"
        exit 1
    fi


}

if [ "$#" -eq 0 ]; then
    echo "No arguments provided. Please provide project name as an argument."
    echo "Usage: bash create_project_retention_policy <project_name_to_create>"
    exit 1
fi

create_project
create_retention_policy