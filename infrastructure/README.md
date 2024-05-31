# Terraform infra  
  
The current folder contains the relevant tf files to raise an EKS cluster on private subnets, NGWs on a 3 AZ configuration.

## Preperation  

as an AWS account with propper permissions to use multiple AWS resources (eks\vpc\ec2\kms\secretsManager and more...) create a secret in the relevant AWS region containing the following information - 
```
GITHUB_USERNAME = <your account github username>
GITHUB_PASSWORD = <your account github developer key>
GITHUB_URL = <the relevant github URL for ARC>
```  
document the secret name for `env.tfvars` below

### Edit configurations  
1. edit `env.tfvars.example` with your relevant content.
2. edit `backend.tf.example` with your relevant s3 backend information
2. remove `example` file extention from `env.tfvars.example` and `backend.tf.example` 

## Deployment -  




### TF apply 


```

terraform fmt && terraform validate
terraform init
terraform plan -var-file=env.tfvars

```