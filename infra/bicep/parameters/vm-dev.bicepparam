using '../vm.bicep'

param environment       = 'dev'
param location          = 'eastus'
param appName           = 'product-catalog'
param vmSize            = 'Standard_B1s'
param vmAdminPassword   = ''  // Set via --parameters flag at deploy time
