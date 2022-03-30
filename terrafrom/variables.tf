variable "region" {
  description = "AWS region"
  default     = "ap-southeast-1"
}

variable "tidb_instance_type" {
  description = "Type of tidb EC2 instance to provision"
  default     = "c5.2xlarge"
}

variable "tikv_instance_type" {
  description = "Type of tikv EC2 instance to provision"
  default     = "r5.2xlarge"
}

variable "pd_instance_type" {
  description = "Type of tidb EC2 instance to provision"
  default     = "c5.xlarge"
}

variable "tools_instance_type" {
  description = "Type of tidb EC2 instance to provision"
  default     = "t3.medium"
}

variable "tikv_storage_size" {
  description = "tikv storage size"
  default     = 1000
}

variable "pd_storage_size" {
  description = "pd storage size"
  default     = 20
}


variable "amis" {
  description = "ami for all instances"
  default     = "ami-06cad7eb677878d8a"
}

variable "usedby_tags" {
  description = "ami for all instances"
  default     = "tidb-tikv-cross-az-gzip"
}
