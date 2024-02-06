REPO_NAME=$(echo $1 | awk -F '/' '{print $(NF)}')
echo $REPO_NAME

