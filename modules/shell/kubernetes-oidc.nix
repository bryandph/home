{
  # Operator kubectl through Authentik (nixspace BPH-36, design K4). kubelogin
  # (`kubectl oidc-login`) runs authorization code + PKCE against the public
  # `kubernetes` client and hands kubectl the ID token; the API server maps it
  # to `oidc:bryan` in `oidc:k8s-admin` (cluster-admin). Tokens are cached
  # under ~/.kube/cache/oidc-login and refreshed for up to 12 hours.
  #
  # The kubeconfig is a separate file, so the existing ~/.kube/config (the k3s
  # admin certificate, which becomes break-glass) is left untouched:
  #
  #   kubectl --kubeconfig ~/.kube/k8s-bph-oidc.yaml get nodes
  #   KUBECONFIG=~/.kube/k8s-bph-oidc.yaml:~/.kube/config kubectx k8s.bph-oidc
  #
  # Making this the default context is an operator step after the API server
  # rollout (runbook: nixspace k8s/docs/operations/kubernetes-oidc.md).
  flake.modules.homeManager.kubernetes-oidc = {pkgs, ...}: let
    cluster = "k8s.bph-oidc";
    serverCa = ''
      -----BEGIN CERTIFICATE-----
      MIIBdjCCAR2gAwIBAgIBADAKBggqhkjOPQQDAjAjMSEwHwYDVQQDDBhrM3Mtc2Vy
      dmVyLWNhQDE3MzQ3NTY3NzMwHhcNMjQxMjIxMDQ1MjUzWhcNMzQxMjE5MDQ1MjUz
      WjAjMSEwHwYDVQQDDBhrM3Mtc2VydmVyLWNhQDE3MzQ3NTY3NzMwWTATBgcqhkjO
      PQIBBggqhkjOPQMBBwNCAAQ9O89/WYf1HckW5o3S4W4y5ebq5aLColKPn64lFEo7
      mIsI/bIaBjMuIF+Ug5pREswYCzFJ1kQXNNclAY3I+RMDo0IwQDAOBgNVHQ8BAf8E
      BAMCAqQwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU5uPyZxIAemrlyDsyWf15
      87uFq/4wCgYIKoZIzj0EAwIDRwAwRAIgR8b3Gl+bB3ykJP4Pgmk+t9c6pFZ9m8zO
      Z4iJ6O78IoACIG2A7dfkddngkOq2oWe0nehDiljWLagAIDTDFZb7kmno
      -----END CERTIFICATE-----
    '';
    kubeconfig = {
      apiVersion = "v1";
      kind = "Config";
      clusters = [
        {
          name = cluster;
          cluster = {
            server = "https://k8s.bph:6443";
            # k3s server CA (public; kube-root-ca.crt), valid until 2034-12-19.
            certificate-authority = "${pkgs.writeText "k3s-server-ca.crt" serverCa}";
          };
        }
      ];
      users = [
        {
          name = "oidc-bryan";
          user.exec = {
            apiVersion = "client.authentication.k8s.io/v1";
            command = "kubectl-oidc_login";
            args = [
              "get-token"
              "--oidc-issuer-url=https://auth.k8s.bph/application/o/kubernetes/"
              "--oidc-client-id=kubernetes"
              "--oidc-extra-scope=profile"
              "--oidc-extra-scope=k8s"
              "--oidc-extra-scope=offline_access"
              "--oidc-pkce-method=S256"
            ];
            interactiveMode = "IfAvailable";
            provideClusterInfo = false;
          };
        }
      ];
      contexts = [
        {
          name = cluster;
          context = {
            inherit cluster;
            user = "oidc-bryan";
          };
        }
      ];
      current-context = cluster;
    };
  in {
    home = {
      packages = [pkgs.kubelogin-oidc];
      file.".kube/k8s-bph-oidc.yaml".text = builtins.toJSON kubeconfig;
    };
  };
}
