# k8s legacy tokens

https://cloud.ibm.com/docs/containers?topic=containers-cs_versions_129

https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#legacy-serviceaccount-token-cleaner

https://github.com/kubernetes/enhancements/blob/master/keps/sig-auth/2799-reduction-of-secret-based-service-account-token/README.md


https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/

!!! https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#create-token

Caution:
Do not reference manually created Secrets in the secrets field of a ServiceAccount. Or the manually created Secrets will be cleaned if it is not used for a long time. Please refer to auto-generated legacy ServiceAccount token clean up.



- TokenRequest API and the projected volume are used to create short-lived service account tokens. This is the recommended way to obtain a service account token.
- This mechanism   an earlier mechanism that added a volume based on a Secret, where the Secret represented the ServiceAccount for the Pod, but did not expire.
- In more recent versions, including Kubernetes v1.33, API credentials are obtained directly using the TokenRequest API, and are mounted into Pods using a projected volume.


- You can still manually create a Secret to hold a service account token; for example, if you need a token that never expires.
- Once you manually create a Secret and link it to a ServiceAccount, the Kubernetes control plane automatically populates the token into that Secret.
- Although the manual mechanism for creating a long-lived ServiceAccount token exists, using TokenRequest to obtain short-lived API access tokens is recommended instead.

[Auto-generated legacy ServiceAccount token clean up](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/#auto-generated-legacy-serviceaccount-token-clean-up)

- To distinguish between automatically generated tokens and manually created ones, Kubernetes checks for a reference from the ServiceAccount's secrets field. If the Secret is referenced in the secrets field, it is considered an auto-generated legacy token.
- Otherwise, it is considered a manually created legacy token.



## plan to remove

- both onprem and gcp
- get list of legacy tokens

kubectl get secrets -A -l kubernetes.io/legacy-token-last-used -L kubernetes.io/legacy-token-last-used

- get list of invalid tokens

kubectl get secrets -A -l kubernetes.io/legacy-token-invalid-since -L kubernetes.io/legacy-token-invalid-since

kubectl get pod -n cbdp-system -o custom-columns=NAME:.metadata.name,SERVICEACCOUNT:.spec.serviceAccountName

kubectl get secrets -A -l kubernetes.io/legacy-token-last-used -L kubernetes.io/legacy-token-last-used

