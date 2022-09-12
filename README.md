# crossplane-hub-spoke-demo
Demo for using GitOps with Flux to deploy "spoke" EKS clusters from a "hub" cluster

## Instructions

1. Get an empty Kubernetes cluster
1. Install Flux (see [HERE](https://fluxcd.io/flux/get-started/) if you need instructions)
1. Install Crossplane, the "crossplane-config-aws" configuration, and apply AWS credentials. (see [HERE](https://github.com/defenseunicorns/crossplane-config-aws#getting-started) if you need instructions)
1. Apply the "hub" manifests by running `kubectl apply -f hub/flux-start.yaml`. This will set up Flux to watch the repository and automatically provision whatever spoke clusters are defined in the "spoke" kustomization directory.