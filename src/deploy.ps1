$grp = "DaprContainerAppDemo"
$loc = "westeurope"
$environment = "cne-dpr"
$STORAGE_ACCOUNT = "daprcontainerappatl"

# creating resource group
az group create --name $grp `
                --location $loc

# creating storage account
az storage account create --name $STORAGE_ACCOUNT `
                --resource-group $grp `
                --location $loc `
                --sku Standard_RAGRS `
                --kind StorageV2

$storageKey = (az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $grp --output json --query "[0].value")
(Get-Content "components\statestore.yml") -Replace '"STORAGE_ACCOUNT_KEY"', $storageKey | Set-Content "components\statestore.yml"
(Get-Content "components\statestore.yml") -Replace 'STORAGE_NAME', $STORAGE_ACCOUNT | Set-Content "components\statestore.yml"

# creating environment
az containerapp env create --name $environment `
                           --resource-group $grp `
                           --internal-only false `
                           --location $loc

# setting dapr state store
az containerapp env dapr-component set `
--name $environment --resource-group $grp `
--dapr-component-name statestore `
--yaml '.\components\statestore.yml'

az containerapp env dapr-component list --resource-group $grp --name $environment --output json

# rebuild images
docker build -t antoontuijl/todoappbackend -f 'TodoApp.Backend\Dockerfile' .
docker push antoontuijl/todoappbackend

docker build -t antoontuijl/todoappfrontend -f 'TodoApp.Frontend\Dockerfile' .
docker push antoontuijl/todoappfrontend

# creating the backend via ARM
az deployment group create --resource-group $grp `
                           --template-file 'backend.json'

# creating the frontend via ARM
az deployment group create --resource-group $grp `
                           --template-file 'frontend.json'

# create container registry
az acr create --resource-group $grp --name todoappacr --sku Basic
# login into container registry
az acr login --name todoappacr 
# push image to container registry
docker tag antoontuijl/todoappbackend todoappacr.azurecr.io/todoappbackend:v1
docker push todoappacr.azurecr.io/todoappbackend:v1
# Remove
#docker rmi todoappacr.azurecr.io/todoappbackend:v1
# List
az acr repository list --name todoappacr.azurecr.io --output table
# Run container image in ACR
docker run -p 8080:80 todoappacr.azurecr.io/todoappbackend:v1


# creating the backend
az containerapp create `
  --name todo-back `
  --resource-group $grp `
  --environment $environment `
  --image antoontuijl/todoappbackend:latest `
  --target-port 8080 `
  --ingress 'internal' `
  --min-replicas 1 `
  --max-replicas 5 `
  --enable-dapr `
  --env-vars ASPNETCORE_ENVIRONMENT="Development" `
  --dapr-app-port 8080 `
  --dapr-app-id todo-back

# creating the frontend
az containerapp create `
  --name todo-front `
  --resource-group $grp `
  --environment $environment `
  --image antoontuijl/todoappfrontend:latest `
  --target-port 8080 `
  --ingress 'external' `
  --min-replicas 0 `
  --max-replicas 5 `
  --enable-dapr `
  --env-vars ASPNETCORE_ENVIRONMENT="Development" `
  --dapr-app-port 8080 `
  --dapr-app-id todo-front


