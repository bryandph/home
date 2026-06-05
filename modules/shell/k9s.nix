{
  flake.modules.homeManager.k9s = {pkgs, ...}: {
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
          scopes = ["helmreleases"];
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
          scopes = ["kustomizations"];
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
          scopes = ["gitrepositories"];
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
          scopes = ["helmreleases"];
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
          scopes = ["helmrepositories"];
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
          scopes = ["ocirepositories"];
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
          scopes = ["kustomizations"];
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
          scopes = ["imagerepositories"];
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
          scopes = ["imageupdateautomations"];
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
          scopes = ["resourcesets"];
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
          scopes = ["resourcesetinputprovider"];
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
          scopes = ["resourcesets"];
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
          scopes = ["resources"];
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
          scopes = ["fluxinstances"];
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
          scopes = ["all"];
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
          scopes = ["helmrelease"];
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
          scopes = ["kustomizations"];
          command = "sh";
          background = false;
          args = [
            "-c"
            ''kubectl get --context $CONTEXT --all-namespaces kustomizations.kustomize.toolkit.fluxcd.io -o json | jq -r '.items[] | select(.spec.suspend==true) | [.metadata.name,.spec.suspend] | @tsv' | less -K''
          ];
        };

        # ── cert-manager (cmctl via k8s-cli) — upstream cert-manager.yaml ──
        cert-status = {
          shortCut = "Shift-S";
          confirm = false;
          description = "Certificate status";
          scopes = ["certificates"];
          command = "bash";
          background = false;
          args = [
            "-c"
            ''cmctl status certificate --context $CONTEXT -n $NAMESPACE $NAME |& less''
          ];
        };
        cert-renew = {
          shortCut = "Shift-R";
          confirm = false;
          description = "Certificate renew";
          scopes = ["certificates"];
          command = "bash";
          background = false;
          args = [
            "-c"
            ''cmctl renew --context $CONTEXT -n $NAMESPACE $NAME |& less''
          ];
        };
        secret-inspect = {
          shortCut = "Shift-I";
          confirm = false;
          description = "Inspect secret";
          scopes = ["secrets"];
          command = "bash";
          background = false;
          args = [
            "-c"
            ''cmctl inspect secret --context $CONTEXT -n $NAMESPACE $NAME |& less''
          ];
        };

        # ── TLS secret inspection — upstream openssl.yaml ──
        secret-openssl-ca = {
          shortCut = "Ctrl-O";
          confirm = false;
          description = "Openssl ca.crt";
          scopes = ["secrets"];
          command = "bash";
          background = false;
          args = [
            "-c"
            ''kubectl get secret --context $CONTEXT -n $NAMESPACE $NAME -o jsonpath='{.data.ca\.crt}' | base64 -d | openssl storeutl -noout -text -certs /dev/stdin |& less''
          ];
        };
        secret-openssl-tls = {
          shortCut = "Shift-O";
          confirm = false;
          description = "Openssl tls.crt";
          scopes = ["secrets"];
          command = "bash";
          background = false;
          args = [
            "-c"
            ''kubectl get secret --context $CONTEXT -n $NAMESPACE $NAME -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl storeutl -noout -text -certs /dev/stdin |& less''
          ];
        };

        # ── helm — upstream helm-values / helm-default-values / helm-diff.yaml
        # (helm-diff needs the helm-diff plugin: helm is wrapped with it in both
        # k8s-cli and home packages) ──
        helm-values = {
          shortCut = "v";
          confirm = false;
          description = "Values";
          scopes = ["helm"];
          command = "sh";
          background = false;
          args = [
            "-c"
            ''helm get values $COL-NAME -n $NAMESPACE --kube-context $CONTEXT | less -K''
          ];
        };
        helm-default-values = {
          shortCut = "Shift-V";
          confirm = false;
          description = "Chart Default Values";
          scopes = ["helm"];
          command = "sh";
          background = false;
          args = [
            "-c"
            ''revision=$(helm history -n $NAMESPACE --kube-context $CONTEXT $COL-NAME | grep deployed | cut -d$'\t' -f1 | tr -d ' \t'); kubectl get secrets --context $CONTEXT -n $NAMESPACE sh.helm.release.v1.$COL-NAME.v$revision -o yaml | yq e '.data.release' - | base64 -d | base64 -d | gunzip | jq -r '.chart.values' | yq -P | less -K''
          ];
        };
        helm-diff-previous = {
          shortCut = "Shift-D";
          confirm = false;
          description = "Diff with Previous Revision";
          scopes = ["helm"];
          command = "bash";
          background = false;
          args = [
            "-c"
            ''LAST_REVISION=$(($COL-REVISION-1)); helm diff revision $COL-NAME $COL-REVISION $LAST_REVISION --kube-context $CONTEXT --namespace $NAMESPACE --color | less -RK''
          ];
        };
        helm-diff-current = {
          shortCut = "Shift-Q";
          confirm = false;
          description = "Diff with Current Revision";
          scopes = ["history"];
          command = "bash";
          background = false;
          args = [
            "-c"
            ''RELEASE_NAME=$(echo $NAME | cut -d':' -f1); LATEST_REVISION=$(helm history -n $NAMESPACE --kube-context $CONTEXT $RELEASE_NAME | grep deployed | cut -d$'\t' -f1 | tr -d ' \t'); helm diff revision $RELEASE_NAME $LATEST_REVISION $COL-REVISION --kube-context $CONTEXT --namespace $NAMESPACE --color | less -RK''
          ];
        };

        # ── logs — upstream log-stern.yaml (stern via home packages) ──
        stern = {
          shortCut = "Ctrl-Y";
          confirm = false;
          description = "Logs <Stern>";
          scopes = ["pods"];
          command = "stern";
          background = false;
          args = [
            "--tail"
            50
            "$FILTER"
            "-n"
            "$NAMESPACE"
            "--context"
            "$CONTEXT"
          ];
        };

        # ── debugging — upstream debug-container.yaml / dive.yaml ──
        debug = {
          shortCut = "Shift-D";
          description = "Add debug container";
          dangerous = true;
          scopes = ["containers"];
          command = "bash";
          background = false;
          confirm = true;
          inputs = [
            {
              name = "image";
              label = "Debug image";
              type = "dropdown";
              required = true;
              default = "nicolaka/netshoot:v0.15";
              options = [
                "nicolaka/netshoot:v0.15"
                "busybox:1.37"
                "alpine:3.23"
                "ubuntu:26.04"
              ];
            }
            {
              name = "profile";
              label = "Debug profile";
              type = "dropdown";
              required = true;
              default = "sysadmin";
              options = [
                "general"
                "baseline"
                "restricted"
                "netadmin"
                "sysadmin"
                "legacy"
              ];
            }
            {
              name = "share_processes";
              label = "Share processes";
              type = "bool";
              required = true;
              default = true;
            }
          ];
          args = [
            "-c"
            ''kubectl debug -it --context $CONTEXT -n=$NAMESPACE $POD --target=$NAME --image=$INPUT_IMAGE --profile=$INPUT_PROFILE $([ "$INPUT_SHARE_PROCESSES" = "true" ] && echo "--share-processes") -- sh''
          ];
        };
        dive = {
          shortCut = "d";
          confirm = false;
          description = "Dive image";
          scopes = ["containers"];
          command = "dive";
          background = false;
          args = ["$COL-IMAGE"];
        };

        # ── storage — upstream pvc-debug-container.yaml / pvc-resize.yaml ──
        pvc-shell = {
          shortCut = "s";
          description = "Shell on PVC";
          scopes = ["pvc"];
          command = "sh";
          background = false;
          confirm = false;
          inputs = [
            {
              name = "podname";
              label = "POD name";
              type = "string";
              required = true;
              default = "pvc-shell";
            }
            {
              name = "image";
              label = "Image";
              type = "dropdown";
              required = true;
              default = "nicolaka/netshoot:v0.15";
              options = [
                "nicolaka/netshoot:v0.15"
                "ubuntu:26.04"
              ];
            }
            {
              name = "mountpath";
              label = "Mount path";
              type = "string";
              required = true;
              default = "/mnt/data";
            }
          ];
          args = [
            "-c"
            ''
              NODE=$(kubectl --context $CONTEXT -n $NAMESPACE get pods \
                -o jsonpath='{range .items[?(@.spec.volumes[*].persistentVolumeClaim.claimName=="'"$NAME"'")]}{.spec.nodeName}{"\n"}{end}' | head -n1)

              if [ -n "$NODE" ]; then
                NODE_LINE="nodeName: $NODE"
              else
                NODE_LINE=""
              fi

              echo "Starting a shell pod with PVC - $NAME mounted at $INPUT_MOUNTPATH"

              {
              cat <<EOF
              apiVersion: v1
              kind: Pod
              metadata:
                name: $INPUT_PODNAME
                namespace: $NAMESPACE
              spec:
                $NODE_LINE
                restartPolicy: Never
                tolerations:
                  - operator: Exists
                containers:
                  - name: shell
                    image: $INPUT_IMAGE
                    command: ["sh"]
                    stdin: true
                    tty: true
                    volumeMounts:
                      - name: vol
                        mountPath: $INPUT_MOUNTPATH
                volumes:
                  - name: vol
                    persistentVolumeClaim:
                      claimName: $NAME
              EOF
              } | kubectl --context $CONTEXT apply -f - >/dev/null 2>&1

              echo "Waiting for pod to be ready."
              if ! kubectl --context $CONTEXT -n $NAMESPACE wait --for=condition=Ready pod/$INPUT_PODNAME --timeout=60s; then
                echo "Pod did not become Ready. Likely a ReadWriteOnce conflict."
                echo "Press Enter to return to k9s."
                read dummy
                kubectl --context $CONTEXT -n $NAMESPACE delete pod $INPUT_PODNAME --ignore-not-found --grace-period=0 --force >/dev/null 2>&1
                exit 0
              fi

              kubectl --context $CONTEXT -n $NAMESPACE exec -it $INPUT_PODNAME -- bash || echo "Could not exec into pod."

              echo "Cleaning up pod."
              kubectl --context $CONTEXT -n $NAMESPACE delete pod $INPUT_PODNAME --ignore-not-found --grace-period=0 --force >/dev/null 2>&1
            ''
          ];
        };
        resize-pvc = {
          shortCut = "r";
          description = "Resize PVC";
          scopes = ["pvc"];
          command = "kubectl";
          confirm = true;
          dangerous = true;
          inputs = [
            {
              name = "size";
              label = "New size (e.g. 10Gi)";
              type = "string";
              required = true;
            }
          ];
          args = [
            "patch"
            "pvc"
            "$NAME"
            "-n"
            "$NAMESPACE"
            "--context"
            "$CONTEXT"
            "-p"
            ''{"spec":{"resources":{"requests":{"storage":"$INPUT_SIZE"}}}}''
          ];
        };

        # ── generic — upstream watch-events.yaml / remove-finalizers.yaml ──
        watch-events = {
          shortCut = "Shift-E";
          confirm = false;
          description = "Get Events";
          scopes = ["all"];
          command = "sh";
          background = false;
          # deviates from upstream, whose expansion is broken (emits the literal
          # text `.RESOURCE_GROUP`); this appends `.<group>` only for CRDs.
          args = [
            "-c"
            ''kubectl events --context $CONTEXT --namespace $NAMESPACE --for $RESOURCE_NAME''${RESOURCE_GROUP:+.$RESOURCE_GROUP}/$NAME --watch''
          ];
        };
        remove_finalizers = {
          shortCut = "Ctrl-F";
          confirm = true;
          dangerous = true;
          scopes = ["all"];
          description = ''
            Removes all finalizers from selected resource. Be careful when using it,
            it may leave dangling resources or delete them
          '';
          command = "kubectl";
          background = true;
          args = [
            "patch"
            "--context"
            "$CONTEXT"
            "--namespace"
            "$NAMESPACE"
            "$RESOURCE_NAME.$RESOURCE_GROUP"
            "$NAME"
            "-p"
            ''{"metadata":{"finalizers":null}}''
            "--type"
            "merge"
          ];
        };
      };
    };
  };
}
