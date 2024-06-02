#!/bin/bash

#This script will deploy all relevant infra for wdc-devops-assinment, from VPC to attaching the ARC to GitHub.
#Add your relevant information when prompt and hope for the best :)

# Function to prompt for input with a default value


check_s3_bucket_permissions() {
    local bucket_name=$1
    local test_file_path=$2

    # Create a test file
    echo "Testing S3 permissions" > /tmp/testfile.txt

    # Attempt to upload the test file
    if aws s3 cp /tmp/testfile.txt "s3://$bucket_name/$test_file_path/testfile.txt"; then
        echo "Successfully uploaded test file."

        # Attempt to delete the test file
        if aws s3 rm "s3://$bucket_name/$test_file_path/testfile.txt"; then
            echo "Successfully deleted test file."
            return 0
        else
            echo "Failed to delete test file."
            return 1
        fi
    else
        echo "Failed to upload test file."
        return 1
    fi
}

ensure_secret_keys() {
    local secret_name=$1
    local secret_value=$2

    if aws secretsmanager describe-secret --secret-id "$secret_name" > /dev/null 2>&1; then
        echo "Secret '$secret_name' exists. Updating keys..."
    else
        echo "Secret '$secret_name' does not exist. Creating it..."
        aws secretsmanager create-secret --name "$secret_name" --secret-string "{}"
    fi

    # Update secret with the necessary keys
    aws secretsmanager put-secret-value --secret-id "$secret_name" --secret-string "$secret_value"
}


printsuccess() {
echo "Terraform Script completed, save the information below if you want to apply changes without running this script again -"
echo """Terraform Command:
terraform fmt && terraform validate
terraform init -reconfigure -backend-config=\"bucket=$S3_BUCKET_NAME\" -backend-config=\"region=$AWS_REGION\" -backend-config=\"key=$GITHUB_PATH/remote.tf\"

Then to apply -
terraform $terraform_args \
        -var-file=env.tfvars

Or to destroy - 
terraform $terraform_args -var-file=env.tfvars -target module.eks-resources.helm_release.actions-runner-set
terraform $terraform_args -var-file=env.tfvars
aws logs delete-log-group --log-group-name /aws/eks/$CLUSTER_NAME/cluster || true

In order to control the newly created EKS cluster, run the following - 
aws eks update-kubeconfig --name $CLUSTER_NAME
"""

}





###### START HERE ######

if [ -n "$1" ]; then
	terraform_args="${@:1}"
else
	terraform_args="apply"
fi

# Retreive public ip for kubernetes api public CIDER access 
PUBLIC_ACCESS_CIDRS=$(curl -s ipv4.icanhazip.com)

# Prompt user for GitHub username
read -p "Enter your GitHub username: " GITHUB_USERNAME

echo " "
echo " "
# Prompt user for GitHub password (hidden input)
read -sp "Enter your GitHub password (hidden input): " GITHUB_PASSWORD
echo

echo " "
echo " "

GITHUB_URL=$(git config --get remote.origin.url | sed -E 's|git@github.com:(.*)/(.*)\.git|https://github.com/\1/\2|')
read -p "Found GitHub URL '$GITHUB_URL'. Is this correct? (y/n): " url_confirm
if [ "$url_confirm" != "y" ]; then
    read -p "Enter the correct GitHub URL: " GITHUB_URL
fi


echo " "
echo " "
echo "Enter the AWS SecretsManager secret name for GitHub information."
echo "The script will create the secret if it does not exist."
read -p "AWS SecretsManager secret name: " AWS_SM_NAME

secret_value=$(jq -n --arg GITHUB_USERNAME "$GITHUB_USERNAME" --arg GITHUB_PASSWORD "$GITHUB_PASSWORD" --arg GITHUB_URL "$GITHUB_URL" '{
    "GITHUB_USERNAME": $GITHUB_USERNAME,
    "GITHUB_PASSWORD": $GITHUB_PASSWORD,
    "GITHUB_URL": $GITHUB_URL
}')
ensure_secret_keys "$AWS_SM_NAME" "$secret_value"

#Remove sensetive values from variables
unset GITHUB_PASSWORD
unset GITHUB_USERNAME

echo " "
echo " "
# Prompt user for Cluster Name
read -p "Please select a cluster name, only dash allowed as secial charectehrs: " CLUSTER_NAME


# Prompt user for S3 bucket name for Terraform backend
attempts=0
max_attempts=3
GITHUB_PATH=$(echo "$GITHUB_URL" | sed -E 's|https://github.com/(.*)/(.*)|\1/\2|')
echo " "
echo " "
echo "S3 Configuration"
while [ $attempts -lt $max_attempts ]; do
    # S3 bucket names are uniq, added retry mechanism 
    echo "Enter the S3 bucket name for Terraform backend."
    echo "The script will create the S3 bucket if it does not exist."
    read -p "S3 bucket name: " S3_BUCKET_NAME

    # Check if bucket exists
    if aws s3 ls "s3://$S3_BUCKET_NAME" > /dev/null 2>&1; then
        echo "Bucket exists. Checking permissions..."
    else
        echo "Bucket does not exist, creating it..."
        if aws s3 mb "s3://$S3_BUCKET_NAME" > /dev/null 2>&1; then
            echo "Bucket created successfully."
        else
            echo "Failed to create bucket. Please try again."
            attempts=$((attempts+1))
            continue
        fi
    fi

    # Check for read/write/delete permissions
    if check_s3_bucket_permissions "$S3_BUCKET_NAME" "$GITHUB_PATH"; then
        echo "S3 bucket '$S3_BUCKET_NAME' has the necessary permissions."
        break
    else
        echo "Bucket '$S3_BUCKET_NAME' exists but with no read/write/delete permissions. Please input a different bucket name."
    fi

    attempts=$((attempts+1))
    if [ $attempts -ge $max_attempts ]; then
        echo "Maximum attempts reached. Exiting script."
        exit 1
    fi
done


# Check for default AWS region in ~/.aws/config
AWS_REGIONS=($(grep 'region' ~/.aws/config | awk '{print $3}'))
if [ ${#AWS_REGIONS[@]} -eq 0 ]; then
    read -p "Enter your AWS region: " AWS_REGION
elif [ ${#AWS_REGIONS[@]} -eq 1 ]; then
    AWS_REGION=${AWS_REGIONS[0]}
    read -p "Found AWS region '$AWS_REGION'. Do you want to use this region? (y/n): " region_confirm
    if [ "$region_confirm" != "y" ]; then
        read -p "Enter your AWS region: " AWS_REGION
    fi
else
    echo "Multiple AWS regions found in your configuration:"
    select region in "${AWS_REGIONS[@]}"; do
        if [[ " ${AWS_REGIONS[@]} " =~ " $region " ]]; then
            AWS_REGION=$region
            break
        else
            echo "Invalid selection. Please choose a valid region."
        fi
    done
fi

USER_ARN=$(aws sts get-caller-identity  | jq -r .Arn)

# Create a template file and replace variables
TEMPLATE_FILE="env.tfvars.template"
OUTPUT_FILE="env.tfvars"


# Copy template file to output file
cp "$TEMPLATE_FILE" "$OUTPUT_FILE"

# Replace placeholders in the output file
sed -i ''  "s|{{AWS_SM_NAME}}|$AWS_SM_NAME|g" "$OUTPUT_FILE"
sed -i ''  "s|{{AWS_REGION}}|$AWS_REGION|g" "$OUTPUT_FILE"
sed -i ''  "s|{{PUBLIC_ACCESS_CIDRS}}|$PUBLIC_ACCESS_CIDRS|g" "$OUTPUT_FILE"
sed -i ''  "s|{{USER_ARN}}|$USER_ARN|g" "$OUTPUT_FILE"
sed -i ''  "s|{{CLUSTER_NAME}}|$CLUSTER_NAME|g" "$OUTPUT_FILE"

echo "Variables have been applied to '$OUTPUT_FILE'."


terraform fmt && terraform validate
terraform init -reconfigure \
		-backend-config="bucket=$S3_BUCKET_NAME" \
		-backend-config="region=$AWS_REGION" \
		-backend-config="key=$GITHUB_PATH/remote.tf"

#There's a bug in the action-runner-set helm uninstall process,
#it keeps leftover resources and is unalbe to remote it from the terraform resource.  
#To address this at this time, we first need to remove it's resrouce with `-target` by itself and then remove all other resources.

if [[ $terraform_args == *"destroy"* ]]; then
    echo "destroying"
    terraform apply -destroy -auto-approve -var-file=env.tfvars -target module.eks-resources.helm_release.actions-runner-set
    terraform apply -destroy -auto-approve \
        -var-file=env.tfvars
    aws logs delete-log-group --log-group-name /aws/eks/$CLUSTER_NAME/cluster || true
    else
    terraform $terraform_args \
        -var-file=env.tfvars
    printsuccess
fi


