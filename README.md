# juice-shop-terraform


This terraform project is used to deploy multiple web security target website into AWS automatically. The commands are listed below:
```
terraform apply -var="target_app=dvwa"
terraform apply -var="target_app=webgoat"
terraform apply -var="target_app=bwapp"
terraform apply -var="target_app=juice_shop"   # by default
terraform apply -var="target_app=mutillidae"
terraform apply -var="target_app=vuln_bank"
terraform apply -var="target_app=altoroj"
```


## Infrastructure Graph of js-terraform-1.tf

![alt text](image-1.png)


# The architectual graph of js-terraform-2.tf

![alt text](terraform_network_architecture_v2.png)
![alt text](terraform_security_observability.png)
