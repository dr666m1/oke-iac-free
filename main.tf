terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

#===== variables =====
variable "parent_compartment" {
  description = "OIDC of the compartment"
  type        = string
}

variable "region" {
  description = "region identifier (e.g. us-phoenix-1)"
  type        = string
  default     = null
}

provider "oci" {
  region = var.region
}

#===== network =====
resource "oci_identity_compartment" "oke" {
  compartment_id = var.parent_compartment
  description    = "created by terraform"
  name           = "oke"
  enable_delete  = true
}

resource "oci_core_vcn" "internal" {
  dns_label      = "oci"
  cidr_block     = "10.0.0.0/16"
  compartment_id = oci_identity_compartment.oke.id
  display_name   = "My internal VCN"
}

resource "oci_core_subnet" "endpoint_subnet" {
  # TODO make public
  cidr_block     = "10.0.0.0/28"
  compartment_id = oci_identity_compartment.oke.id
  vcn_id         = oci_core_vcn.internal.id
}

resource "oci_core_subnet" "node_subnet" {
  # TODO make private
  cidr_block     = "10.0.10.0/24"
  compartment_id = oci_identity_compartment.oke.id
  vcn_id         = oci_core_vcn.internal.id
}

#===== kubernetes =====
resource "oci_containerengine_cluster" "oke-cluster" {
  compartment_id     = oci_identity_compartment.oke.id
  kubernetes_version = "v1.22.5"
  name               = "oke-free"
  vcn_id             = oci_core_vcn.internal.id
}

resource "oci_containerengine_node_pool" "oke-node-pool" {
  # TODO specify endpoint subnet
  cluster_id         = oci_containerengine_cluster.oke-cluster.id
  compartment_id     = oci_identity_compartment.oke.id
  kubernetes_version = "v1.22.5"
  name               = "oci_pool"
  node_config_details {
    # TODO specify spec
    placement_configs {
      # TODO auto generate
      availability_domain = "ljSu:PHX-AD-1"
      subnet_id           = oci_core_subnet.node_subnet.id
    }
    size = 2
  }
  node_shape = "VM.Standard.A1.Flex"
  node_source_details {
    # TODO auto generate by region
    # See https://docs.oracle.com/en-us/iaas/images/image/bc845dcb-269b-47f6-bda9-04741976118a/
    image_id    = "ocid1.image.oc1.phx.aaaaaaaam7fvzjfiyyn7zcs7aytuskugnk7iimzsvpnektoqgwsvvhdrewga"
    source_type = "image"
  }
}
