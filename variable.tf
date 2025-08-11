variable "tabby_docker_image" {
  type    = string
  default = "tabbyml/tabby"
}

variable "ollama_docker_image" {
  type    = string
  default = "ollama/ollama"
}
variable "nginx_proxy_docker_image" {
  type    = string
  default = "nginxproxy/nginx-proxy:1.7"
}

variable "your_domain" {
  type = string
}

variable "your_email" {
  type = string
}

variable "tabby_jwt_token" {
  type        = string
  description = "JWT token for tabby web interface (UUID format)"
}

