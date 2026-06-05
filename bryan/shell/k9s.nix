{ pkgs, ... }:
{
  # k9s is installed globally here (programs.k9s.package) and also rides along in
  # the k8s flake's `k8s-cli` buildEnv inside the devenv; this module manages the
  # personal config — a Flux control surface + cluster-health hotkeys. The
  # home-manager module writes to
  # ~/.config/k9s (linux) or ~/Library/Application Support/k9s (darwin).
  #
  # plugins.yaml / hotkeys.yaml are read-only config k9s never rewrites, so
  # symlinking them from the store is safe. We deliberately leave `settings`
  # unset so k9s keeps managing its own writable config.yaml (active context,
  # skin, view state).
  programs.k9s = {
    enable = true;

    # Install k9s globally so it's on the PATH in plain shells too (e.g.
    # tmux-resurrect), not only inside the k8s devenv where k8s-cli provides it.
    package = pkgs.k9s;

    # Cluster health summary — surface the built-in views as one-key hotkeys.
    #   Shift-0 → :pulse  (per-resource healthy/unhealthy counts + cluster CPU/mem; needs metrics-server)
    #   Shift-9 → :popeye (bundled cluster sanitizer: probes, limits, RBAC, naked pods, …)
    # Also available by command: `:pulse`, `:popeye`, `:xray <resource>`.
    hotKeys = {
      shift-0 = {
        shortCut = "Shift-0";
        description = "Pulses (cluster health)";
        command = "pulses";
      };
      shift-9 = {
        shortCut = "Shift-9";
        description = "Popeye (sanitizer)";
        command = "popeye";
      };
    };

    # Flux control surface — verbatim from derailed/k9s plugins/flux.yaml.
    #   Shift-R  reconcile (sources, kustomizations, helmreleases, image repos/automations)
    #   Shift-T  toggle suspend/resume (helmreleases, kustomizations)
    #   Shift-S  list suspended (helmreleases, kustomizations)
    #   Shift-Z  reconcile helm/oci source repos
    #   Shift-Q  flux trace any resource back to its Flux source
    # Shells out to `flux` + `kubectl` (k8s-cli) and `jq` (home). The
    # ResourceSet/InputProvider/FluxInstance plugins call a separate
    # `flux-operator` CLI that isn't packaged and whose CRDs aren't in this
    # cluster — they stay inert until flux-operator is adopted.
    plugins = {
      toggle-helmrelease = {
        shortCut = "Shift-T";
        confirm = true;
        scopes = [ "helmreleases" ];
        description = "Toggle to suspend or resume a HelmRelease";
        command = "bash";
        background = false;
        args = [
          "-c"
          ''suspended=$(kubectl --context $CONTEXT get helmreleases -n $NAMESPACE $NAME -o=custom-columns=TYPE:.spec.suspend | tail -1); verb=$([ $suspended = "true" ] && echo "resume" || echo "suspend"); flux $verb helmrelease --context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      toggle-kustomization = {
        shortCut = "Shift-T";
        confirm = true;
        scopes = [ "kustomizations" ];
        description = "Toggle to suspend or resume a Kustomization";
        command = "bash";
        background = false;
        args = [
          "-c"
          ''suspended=$(kubectl --context $CONTEXT get kustomizations -n $NAMESPACE $NAME -o=custom-columns=TYPE:.spec.suspend | tail -1); verb=$([ $suspended = "true" ] && echo "resume" || echo "suspend"); flux $verb kustomization --context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-git = {
        shortCut = "Shift-R";
        confirm = false;
        description = "Flux reconcile";
        scopes = [ "gitrepositories" ];
        command = "bash";
        background = false;
        args = [
          "-c"
          ''flux reconcile source git --context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-hr = {
        shortCut = "Shift-R";
        confirm = false;
        description = "Flux reconcile";
        scopes = [ "helmreleases" ];
        command = "bash";
        background = false;
        args = [
          "-c"
          ''flux reconcile helmrelease --context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-helm-repo = {
        shortCut = "Shift-Z";
        description = "Flux reconcile";
        scopes = [ "helmrepositories" ];
        command = "bash";
        background = false;
        confirm = false;
        args = [
          "-c"
          ''flux reconcile source helm --context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-oci-repo = {
        shortCut = "Shift-Z";
        description = "Flux reconcile";
        scopes = [ "ocirepositories" ];
        command = "bash";
        background = false;
        confirm = false;
        args = [
          "-c"
          ''flux reconcile source oci --context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-ks = {
        shortCut = "Shift-R";
        confirm = false;
        description = "Flux reconcile";
        scopes = [ "kustomizations" ];
        command = "bash";
        background = false;
        args = [
          "-c"
          ''flux reconcile kustomization --context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-ir = {
        shortCut = "Shift-R";
        confirm = false;
        description = "Flux reconcile";
        scopes = [ "imagerepositories" ];
        command = "sh";
        background = false;
        args = [
          "-c"
          ''flux reconcile image repository --context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-iua = {
        shortCut = "Shift-R";
        confirm = false;
        description = "Flux reconcile";
        scopes = [ "imageupdateautomations" ];
        command = "sh";
        background = false;
        args = [
          "-c"
          ''flux reconcile image update --context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      toggle-rset = {
        shortCut = "Shift-T";
        confirm = false;
        scopes = [ "resourcesets" ];
        description = "Toggle to suspend or resume a ResourceSet";
        command = "bash";
        background = false;
        args = [
          "-c"
          ''reconcile=$(kubectl --context $CONTEXT get resourceset -n $NAMESPACE $NAME -o=custom-columns='TYPE:.metadata.annotations.fluxcd\.controlplane\.io/reconcile' | tail -1); verb=$([ $reconcile = "disabled" ] && echo "resume" || echo "suspend"); flux-operator $verb rset --kube-context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      toggle-inputprovider = {
        shortCut = "Shift-T";
        confirm = false;
        scopes = [ "resourcesetinputprovider" ];
        description = "Toggle to suspend or resume an InputProvider";
        command = "bash";
        background = false;
        args = [
          "-c"
          ''reconcile=$(kubectl --context $CONTEXT get resourcesetinputprovider -n $NAMESPACE $NAME -o=custom-columns='TYPE:.metadata.annotations.fluxcd\.controlplane\.io/reconcile' | tail -1); verb=$([ $reconcile = "disabled" ] && echo "resume" || echo "suspend"); flux-operator $verb inputprovider --kube-context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-rset = {
        shortCut = "Shift-R";
        confirm = false;
        description = "Flux reconcile";
        scopes = [ "resourcesets" ];
        command = "bash";
        background = false;
        args = [
          "-c"
          ''flux-operator reconcile rset --kube-context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-inputprovider = {
        shortCut = "Shift-R";
        confirm = false;
        description = "Flux reconcile";
        scopes = [ "resources" ];
        command = "bash";
        background = false;
        args = [
          "-c"
          ''flux-operator reconcile inputprovider --kube-context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      reconcile-fluxinstance = {
        shortCut = "Shift-R";
        confirm = false;
        description = "Flux reconcile";
        scopes = [ "fluxinstances" ];
        command = "bash";
        background = false;
        args = [
          "-c"
          ''flux-operator reconcile instance --kube-context $CONTEXT -n $NAMESPACE $NAME | less -K''
        ];
      };
      trace = {
        shortCut = "Shift-Q";
        confirm = false;
        description = "Flux trace";
        scopes = [ "all" ];
        command = "bash";
        background = false;
        args = [
          "-c"
          ''if [ -n "$RESOURCE_GROUP" ]; then api_endpoint="/apis/$RESOURCE_GROUP/$RESOURCE_VERSION"; else api_endpoint="/api/$RESOURCE_VERSION"; fi; api_resource=$(kubectl get --raw "''${api_endpoint}" | jq -r ".resources[] | select(.name==\"$RESOURCE_NAME\")"); kind=$(echo ''${api_resource} | jq -r '.kind'); namespace_arg=$(echo ''${api_resource} | jq -r "if .namespaced == true then \"--namespace $NAMESPACE\" else \"\" end"); [ -n "$RESOURCE_GROUP" ] && api_version=$RESOURCE_GROUP/; api_version=''${api_version}$RESOURCE_VERSION; flux trace --context $CONTEXT --kind ''${kind} --api-version ''${api_version} ''${namespace_arg} $NAME |& less -K''
        ];
      };
      get-suspended-helmreleases = {
        shortCut = "Shift-S";
        confirm = false;
        description = "Suspended Helm Releases";
        scopes = [ "helmrelease" ];
        command = "sh";
        background = false;
        args = [
          "-c"
          ''kubectl get --context $CONTEXT --all-namespaces helmreleases.helm.toolkit.fluxcd.io -o json | jq -r '.items[] | select(.spec.suspend==true) | [.metadata.namespace,.metadata.name,.spec.suspend] | @tsv' | less -K''
        ];
      };
      get-suspended-kustomizations = {
        shortCut = "Shift-S";
        confirm = false;
        description = "Suspended Kustomizations";
        scopes = [ "kustomizations" ];
        command = "sh";
        background = false;
        args = [
          "-c"
          ''kubectl get --context $CONTEXT --all-namespaces kustomizations.kustomize.toolkit.fluxcd.io -o json | jq -r '.items[] | select(.spec.suspend==true) | [.metadata.name,.spec.suspend] | @tsv' | less -K''
        ];
      };
    };
  };
}
