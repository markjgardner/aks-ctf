param location string = resourceGroup().location

/**
 * The name of the virtual network to be created.
 * Example: 'myVnet'
 */
param vnetName string // The name of the virtual network to be created.

param vnetAddressPrefix string = '10.224.0.0/12'

/**
 * The name of the subnet to be created within the virtual network.
 * Example: 'mySubnet'
 */
param subnetName string // The name of the subnet to be created within the virtual network.

/** 
 * The IP address prefix for the subnet in CIDR notation.
 * Example: '10.224.0.0/16'
 */
param subnetPrefix string = '10.224.0.0/16'

/**
 * The name of the Azure Kubernetes Service (AKS) cluster to be created.
 * Example: 'myAksCluster'
 */
param aksClusterName string // The name of the Azure Kubernetes Service (AKS) cluster to be created.

/**
 * The name of the Azure Container Registry (ACR) to be created.
 * Example: 'myAcr'
 */
param acrName string // The name of the Azure Container Registry (ACR) to be created.

/**
 * The number of nodes in the AKS cluster.
 * Example: 3
 */
param aksNodeCount int = 1 // The number of nodes in the AKS cluster.

/**
 * The size of the virtual machines used for the AKS nodes.
 * Example: 'Standard_DS3_v2'
 */
param aksNodeSize string = 'Standard_DS2_v2' // The size of the virtual machines used for the AKS nodes.

/**
 * The administrator username for the AKS cluster.
 * Example: 'adminUser'
 */
param aksAdminUsername string = 'azureuser' // The administrator username for the AKS cluster.

/**
 * The SSH public key for accessing the AKS nodes.
 * Example: 'ssh-rsa AAAAB3...'
 */
param sshPublicKey string // The SSH public key for accessing the AKS nodes.

/**
 * The IP address of the user for network security group (NSG) rules.
 * Example: '192.168.1.1'
 */
param userIP string

module nsg './nsg.bicep' = {
  name: 'nsg'
  params: {
    userIP: userIP
  }
}

module vnet './vnet.bicep' = {
  name: 'vnet'
  params: {
    vnetName: vnetName
    location: location
    vnetAddressPrefix: vnetAddressPrefix
    subnetName: subnetName
    subnetPrefix: subnetPrefix
    subnetNsgId: nsg.outputs.nsgId
  }
}

module acr './acr.bicep' = {
  name: 'acr'
  params: {
    acrName: acrName
    location: location
  }
}

module logAnalyticsWorkspace './loganalyticsworkspace.bicep' = {
  name: 'logAnalyticsWorkspace'
  params: {
    location: location
  }
}

module aks './aks.bicep' = {
  name: 'aks'
  params: {
    location: location
    aksClusterName: aksClusterName
    aksNodeCount: aksNodeCount
    aksNodeSize: aksNodeSize
    subnetId: vnet.outputs.subnetId
    aksAdminUsername: aksAdminUsername
    sshPublicKey: sshPublicKey
    workspaceId: logAnalyticsWorkspace.outputs.workspaceId
  }
}

output acrLoginServer string = acr.outputs.acrLoginServer
output aksClusterName string = aks.name
