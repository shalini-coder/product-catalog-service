targetScope = 'resourceGroup'

param environment string = 'dev'
param location string = resourceGroup().location
param appName string = 'product-catalog'
param vmSize string = 'Standard_B2s'
param vmAdminUsername string = 'azureuser'
@secure()
param vmAdminPassword string

var suffix = '${appName}-${environment}'
var vmName = 'vm-${suffix}'
var nsgName = 'nsg-${suffix}'
var nicName = 'nic-${suffix}'
var pipName = 'pip-${suffix}'

// Public IP
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: pipName
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-${suffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet-default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Network Interface
resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/subnet-default'
          }
          publicIPAddress: {
            id: publicIp.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Linux VM
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
  }
}

// Custom Script Extension to install Docker and run docker-compose
resource scriptExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: vm
  name: 'InstallDocker'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
      commandToExecute: '''
        set -e
        apt-get update
        apt-get install -y docker.io docker-compose git
        usermod -aG docker azureuser
        cd /home/azureuser
        git clone https://github.com/shalini-coder/product-catalog-service.git
        cd product-catalog-service
        docker-compose up -d
      '''
    }
  }
}

output vmPublicIp string = publicIp.properties.ipAddress
output appUrl string = 'http://${publicIp.properties.ipAddress}:8080'
