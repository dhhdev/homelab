variable "switch_ip" {
  description = "Management IP address of the TP-Link TL-SG108E switch"
  type        = string
  default     = "192.168.0.10"
}

variable "switch_mac" {
  description = "MAC Address of the actual switch."
  type        = string
  default     = "00:00:00:00:00:00"
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
