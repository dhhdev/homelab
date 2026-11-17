variable "switch_ip" {
  description = "Management IP address of the TP-Link TL-SG108E switch"
  type        = string
  default     = "10.0.10.3"
}

variable "switch_mac" {
  description = "MAC Address of the actual switch."
  type        = string
  default     = "60:15:6f:6e:92:7a"
}

variable "switch_user" {
  description = "Switch admin username."
  type        = string
  default     = "admin"
}

variable "switch_password" {
  description = "Switch admin password."
  type        = string
  sensitive   = true
}
