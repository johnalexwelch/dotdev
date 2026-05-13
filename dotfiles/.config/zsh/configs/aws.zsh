# AWS configuration
export AWS_PAGER=""  # Disable default pager for AWS CLI output
export AWS_DEFAULT_OUTPUT="json"
export AWS_SESSION_DURATION=43200  # 12 hours

# AWS aliases
alias awsl='aws sso login'  # Login to AWS SSO
alias awsi='aws sts get-caller-identity'  # Show current identity
alias awsw='aws sso login && aws sts get-caller-identity'  # Login and verify

# AWS with FZF integration
alias awsp='aws configure list-profiles | fzf --height 40% --layout=reverse --border --preview "aws configure list --profile {}"'
alias awsr='aws configure list-regions | fzf --height 40% --layout=reverse --border'

# AWS helper functions
aws-profile() {
    if [ -z "$1" ]; then
        # If no argument provided, use fzf to select
        local AWS_PROFILE
        AWS_PROFILE=$(aws configure list-profiles | fzf --height 40% --layout=reverse --border)
        export AWS_PROFILE
    else
        export AWS_PROFILE="$1"
    fi
    # Show current identity after profile switch
    aws sts get-caller-identity
}

aws-region() {
    if [ -z "$1" ]; then
        # If no argument provided, use fzf to select
        local AWS_DEFAULT_REGION
        AWS_DEFAULT_REGION=$(aws configure list-regions | fzf --height 40% --layout=reverse --border)
        export AWS_DEFAULT_REGION
    else
        export AWS_DEFAULT_REGION="$1"
    fi
    echo "AWS region set to: $AWS_DEFAULT_REGION"
}

# AWS SSM helper
aws-ssm() {
    if [ -z "$1" ]; then
        echo "Please provide an instance ID"
        return 1
    fi
    aws ssm start-session --target "$1"
}

# List EC2 instances with FZF and connect
aws-ec2() {
    local instance_id
    instance_id=$(aws ec2 describe-instances \
        --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,PrivateIpAddress]' \
        --output text | \
        column -t | \
        fzf --height 40% --layout=reverse --border | \
        awk '{print $1}')

    if [ ! -z "$instance_id" ]; then
        aws-ssm "$instance_id"
    fi
}

# AWS CloudWatch logs helper
aws-logs() {
    local group
    group=$(aws logs describe-log-groups --query 'logGroups[].logGroupName' --output text | \
        tr '\t' '\n' | \
        fzf --height 40% --layout=reverse --border)

    if [ ! -z "$group" ]; then
        aws logs tail "$group" --follow
    fi
}

# AWS profile management
aws-profiles() {
    aws configure list-profiles | while read -r profile; do
        echo -n "$profile: "
        AWS_PROFILE=$profile aws sts get-caller-identity 2>/dev/null || echo "No session"
    done
}

# Print the most recent SSO access token from the local cache.
# Skips registration files (clientId/clientSecret-only); only emits tokens.
aws-sso-token() {
    local f
    for f in $(/bin/ls -t "$HOME/.aws/sso/cache"/*.json 2>/dev/null); do
        local token
        token=$(jq -r '.accessToken // empty' "$f" 2>/dev/null)
        if [[ -n "$token" ]]; then
            print -r -- "$token"
            return 0
        fi
    done
    echo "aws-sso-token: no cached SSO token — run 'awsl' first" >&2
    return 1
}

# List SSO-accessible accounts using the cached token.
aws-sso-accounts() {
    local token
    token=$(aws-sso-token) || return 1
    aws sso list-accounts --access-token "$token" --region "${AWS_DEFAULT_REGION:-us-east-1}" | jq .
}
