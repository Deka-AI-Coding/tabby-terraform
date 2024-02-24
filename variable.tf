variable "tabby_docker_image" {
  type    = string
  default = "tabbyml/tabby"
}

variable "tabby_jwt_token" {
  type        = string
  description = "JWT token for tabby web interface (UUID format)"
}

variable "tabby_worker_token" {
  type        = string
  description = "Token to register worker"
}

variable "tabby_chat_model" {
  type        = string
  default     = "TabbyML/Mistral-7B"
  description = "Chatmodel for tabby workers"
}

variable "tabby_chat_device" {
  type        = string
  default     = "cpu"
  description = "Device to pass with --device flag"
}

variable "tabby_completion_model" {
  type        = string
  default     = "TabbyML/CodeLlama-7B"
  description = "Chatmodel for tabby workers"
}

variable "tabby_completion_device" {
  type        = string
  default     = "rocm"
  description = "Device to pass with --device flag"
}

variable "tabby_gpu_device" {
  type        = string
  default     = "rocm"
  description = "Device to pass with --device flag"
}

