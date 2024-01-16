# zarf init w/k3s


# Install Crossplane

#download / install helm

```
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -
helm install crossplane --namespace crossplane-system crossplane-stable/crossplane
```

# Install AWS, K8s & Helm Crossplane Provider and Controller

- Apply AWS Controller Config for Provider (needed to credential workers)

`kubectl apply -f crossplane-terraform-provider.yaml`

- edit terraform provider deployment to add `hostNetwork: true`

- Apply AWS, K8s & Helm Providers (create k8s service account for AWS)
#similar to the AWS terraform registry

`kubectl apply -f crossplane-terraform-provider-config.yaml`

#wait for provider to reconcile
`watch kubectl get providers`

- Apply Provider Config configure for injected identity
`kubectl apply -f hub/provider-providerconfigs/provider-config.yaml`

`kubectl get providers.pkg.crossplane.io crossplane-provider-aws -o jsonpath="{.status.currentRevision}"`
