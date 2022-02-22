variable "project" {
  type        = string
  description = "The default project to manage resources in. If another project is specified on a resource, it will take precedence."
}

variable "project_number" {
  type        = string
  description = "The GCP project number"
}

variable "region" {
  type        = string
  description = "The default region to manage resources in. If another region is specified on a regional resource, it will take precedence."
  default     = "northamerica-northeast1"
}

variable "environment" {
  type        = string
  description = "The environment the project corresponds to. Allowed values: non-production, production"
}

variable "image" {
  type        = string
  description = "Docker image name. This is most often a reference to a container located in the container registry, such as gcr.io/cloudrun/hello More info: https://kubernetes.io/docs/concepts/containers/images"
}

variable "location" {
  type        = string
  description = "The location of the cloud run instance. eg us-central1"
}

variable "auth_secret_key" {
  type        = string
  description = "The secret used to sign the JSON Web Tokens used for authentication. More info: https://jwt.io/introduction"
}

variable "auth_issuer" {
  type        = string
  description = "The required JWT issuer claim. More info: https://jwt.io/introduction"
}

variable "db_user" {
  type        = string
  description = "The user name that the application will connected to the database with"
}

variable "db_password" {
  type        = string
  description = "The user password that the application will connected to the database with"
}
