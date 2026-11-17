variable "switch_ip" {
  description = "Management IP address of the TP-Link TL-SG108E switch"
  type        = string
  default     = "10.0.0.3" # Change this to 10.0.10.3 when we go full VLAN!
}

variable "switch_user" {
  description = "Switch admin username"
  type        = string
  default     = "admin"
}

variable "switch_password" {
  description = "Switch admin password"
  type        = string
  sensitive   = true
}
