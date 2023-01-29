# PostgreSQL Flexible Server with VNet injection and Customer Managed Key
Demonstrates that it is not necessary to expose the instance of Azure Key Vault to any public access or through a private endpoint so that an instance of Azure Database for PostgreSQL Flexible Server can get to the key used for data encryption as long as the instance of AKV is set to **Allow trusted Microsoft services to bypass this firewall**.

Output variable **ssh_command** of this Terraform config contains the `ssh` command you can run from the machine from where `terraform apply` was executed. A Network Security Group with an Inbound rule allowing SSH traffic from that machine is deployed as part of the configuration.

Execute `terraform output output.ssh_command` to retrieve the value stored in that output variable.

Once logged into the machine, run the Bash script named `psqltest.sh` to test connectivity and functionality of PostgreSQL.