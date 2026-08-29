# Nalej Service Registry web-service fixture

This public Helm chart is the acceptance fixture for deploying an immutable GitHub revision through the Nalej Service Registry.

The Service Registry sets the Helm release name to `service-registry-<entry-name>`. The chart derives the entry name from `.Release.Name` and deliberately renders only:

- a Deployment whose pod carries `app: <entry-name>`; and
- a same-named Service on port `3000`.

The chart does not request node placement, tolerations, cloud resources, credentials, ingress, or Istio resources. Those responsibilities remain with the platform. In particular, the live Kyverno mutation must place the resulting pod on the tenant `userapps` node group.

The container is the exact digest already serving the prod Nalej landing page, pinned through the prod Harbor route. The chart overrides its entry point with a tiny Node HTTP server that returns a unique, self-contained acceptance page and health endpoints. The page has no asset or navigation requests that could escape the Service Registry's assigned `/byo/<entry>/` route after Istio strips the prefix.

Run `scripts/verify.sh` to verify the chart's render contract.
