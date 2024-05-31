# Terraform infra  
  
The current folder contains the relevant tf files to raise an EKS cluster on private subnets, NGWs on a 3 AZ configuration.



## Deployment -  

### Edit configurations  
1. edit `env.tfvars.example` with your relevant content.
2. edit `backend.tf.example` with your relevant s3 backend information
2. remove `example` file extention from `env.tfvars.example` and `backend.tf.example` 

### TF apply 


```

terraform fmt && terraform validate
terraform init
terraform plan -var-file=env.tfvars

```