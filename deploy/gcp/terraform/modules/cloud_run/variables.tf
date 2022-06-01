variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "image" {
  type = string
}

variable "environment" {
  type = string
}

variable "auth_secret_key" {
  type      = string
  sensitive = true
}

variable "auth_issuer" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_connection_name" {
  type = string
}
