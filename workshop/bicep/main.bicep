param location string = resourceGroup().location
param vnetName string
param vnetAddressPrefix string = '10.224.0.0/12'
param subnetName string
param subnetPrefix string = '10.224.0.0/16'
param aksClusterName string
param acrName string
param aksNodeCount int = 1
param aksNodeSize string = 'Standard_DS2_v2'
param aksAdminUsername string = 'azureuser'
param sshPublicKey string
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
