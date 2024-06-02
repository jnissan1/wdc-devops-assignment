# Terraform Infrastructure  
  
The current folder contains the relevant script and tf files to deploy a fully working and connected GitHub ARC Runner on an EKS cluster with private subnets, routing,  NATGateways.

## Preperation  

1. Needed applications - awc-cli, git, terraform, jq, kubectl, helm.
2. An AWS account with propper permissions to provision multiple AWS resources (eks\vpc\ec2\kms\secretsManager and more...) configured via `aws configure` OR `AWS_ACCESS..` ENV Variables)
3. The following information documented securly - 
```
GITHUB_USERNAME = Your account github username.
GITHUB_PASSWORD = Your account github developer key.
GITHUB_URL = The script will search for the current git repo and prompt for confirmation\change. 
```  

## Initial Infrastructure deployment

In order to prepare the `env.tfvars` file run the `./deploy-infrastructure.sh <tf-command>` and input relvant information when prompted. example - `./deploy-infrastructure.sh plan` or `./deploy-infrastructure.sh destroy`. if argument is provided, apply is assumed. 
The script will ask you for releant information - 
1. Git - 
    * `GITHUB_USERNAME` - The GitHub username associated with the api key
    * `GITHUB_PASSWORD` - The GitHub developer API Key
    * `GITHUB_URL` - The GitHub repository to connect the ARC runner to. there's a check in the script if the current repository is the relevant one.  

    **_NOTE:_** The GitHub credentials are consumed as `helm login` for `oci://ghcr.io/` and as a `github` listener token for the ARC runner. 
2. AWS -
    * AWS_SM_NAME - AWS Secrets Manager secret name. The script will create one if not preasent and makes sure the relevant information is there.
    * S3_BUCKET_NAME - The S3 bucket name for the terraform backend. 
    * AWS_REGION - if a region is found, you will be prompt for confirmation\region change.

After the initial infrastructure deployment, if you want, you can run `terraform apply -var-file=env.tfvars` or ` terraform destroy -var-file=env.tfvars` normally inside the Infrastructure folder. 

## Additional configurations  
You can edit `env.tfvars.template` and add additional access information -   
* K8s API Access - `public_access_cidrs = ["PUBLIC_ACCESS_CIDRS"]` can become `public_access_cidrs = ["PUBLIC_ACCESS_CIDRS/32","0.0.0.0/0"]` for a wider and unsecured access\or have additional addresses added. 
* Cluster Admin Users - `cluster_users = ["USER_ARN"]` can become `cluster_users = ["USER_ARN","arn:<partition>:iam::<account-id>:user/<yourusername>"]` for additional k8s admin users. 


## Cleanup -

There's a bug in the action-runner-set helm uninstall process, it keeps leftover resources and is unalbe to remote it from the terraform resource.  
To address this at this time, we first need to remove it's resrouce with `-target` by itself and then remove all other resources.

```
terraform destroy -var-file=env.tfvars -target module.eks-resources.helm_release.actions-runner-set
terraform destroy -var-file=env.tfvars
CLUSTER_NAME="$(cat env.tfvars | grep cluster_name | awk -F\" '{ print $2}')"
aws logs delete-log-group --log-group-name /aws/eks/$CLUSTER_NAME/cluster
```
Or just run - 
```
./deploy-infrastructure.sh destroy
```
