# `flake.modules.homeManager.colima` — Docker engine on macOS without
# Docker Desktop. A Colima VM on Apple's Virtualization.framework (vz)
# with Rosetta and virtiofs runs the Docker daemon; the `docker` CLI on
# the host talks to it through the `colima` docker context. darwin-only
# feature (launchd + vz), imported by the bryan-darwin profile.
#
# Research and the option comparison: nixspace BPH-23 and
# `mem:research/macos-container-runtime-options`. Kept deliberately
# separate from the nix-rosetta-builder VM (no host mounts there, and
# docker access would be root inside the Nix builder).
#
# Single-writer notes (`mem:style/one-writer-per-file`):
# - ~/.colima/default/colima.yaml is rendered by home-manager from
#   `settings` below (a read-only store symlink), so the agent runs
#   `--save-config=false` and resizing means editing THIS file, never
#   `colima start --cpu N`.
# - ~/.docker/config.json stays tool-owned (docker/colima write
#   currentContext and credential helpers into it); programs.docker-cli
#   is deliberately left off.
{
  flake.modules.homeManager.colima = {
    config,
    lib,
    pkgs,
    ...
  }: let
    colima = lib.getExe config.services.colima.package;

    # `colima start` alone cannot keep the daemon up under launchd. Two
    # failure modes (measured by another operator, 2026-08, and matching
    # colima's documented behaviour):
    #
    # 1. After sleep or a crash lima's VM process outlives the host
    #    agent; every later start fails with "vz driver is running but
    #    host agent is not" and only `colima stop --force` clears it.
    # 2. `colima start` on an already-running instance logs "already
    #    running" and exits 0 immediately, so launchd supervises nothing
    #    (seen on every darwin-rebuild that replaces the agent).
    #
    # Upstream home-manager's KeepAlive.SuccessfulExit = true fixes
    # neither, hence the wrapper: stop whatever is up so the foreground
    # start always owns the VM, and force-stop after a failed start so
    # the KeepAlive retry begins from a clean instance. No `exec`: the
    # wrapper must outlive the start to do that cleanup.
    startColima = pkgs.writeShellScript "colima-start-supervised" ''
      if ${colima} status default >/dev/null 2>&1; then
        echo "colima: a VM is up that this agent does not own; restarting it"
        ${colima} stop default || ${colima} stop default --force || true
      fi

      if ${colima} start default -f --activate=true --save-config=false; then
        exit 0
      fi

      echo "colima: start failed; forcing a stop so the retry is not wedged"
      ${colima} stop default --force || true
      exit 1
    '';
  in {
    # The docker CLI itself comes from the darwin system profile
    # (docker-client); docker-compose from shell-packages. buildx is only
    # useful with an engine, so it lives here.
    home.packages = [pkgs.docker-buildx];

    # `docker compose` / `docker buildx` (the subcommand forms) discover
    # plugins under ~/.docker/cli-plugins. Docker Desktop used to own this
    # directory; these two are now the Nix binaries.
    home.file = {
      ".docker/cli-plugins/docker-compose".source = "${pkgs.docker-compose}/bin/docker-compose";
      ".docker/cli-plugins/docker-buildx".source = "${pkgs.docker-buildx}/bin/docker-buildx";
    };

    services.colima = {
      enable = true;

      profiles.default = {
        isService = true;
        # `docker context use colima` on start. The context resolves the
        # socket, so DOCKER_HOST is not exported as a second source of
        # truth (it would also override any other context).
        isActive = true;
        setDockerHost = false;

        # launchd refuses to start a job whose log directory is missing;
        # ~/Library/Logs always exists (and Console.app reads it).
        logFile = "${config.home.homeDirectory}/Library/Logs/colima.log";

        # Full colima.yaml, every key. With --save-config=false this file
        # IS the config: an omitted key reaches colima as a zero value, so
        # a partial spec would silently boot a 0-CPU VM. Key set from
        # `colima template` of the packaged version.
        settings = {
          # Host is an 18-core / 64 GiB M5 Pro that also lends 32 GiB to the
          # on-demand rosetta-builder. Disk is a sparse image, so 100 is a
          # ceiling, not a reservation.
          cpu = 6;
          disk = 100;
          memory = 12;
          arch = "aarch64";
          runtime = "docker";
          modelRunner = "";
          hostname = "colima";
          kubernetes = {
            enabled = false;
            version = "v1.31.2+k3s1";
            k3sArgs = ["--disable=traefik"];
            port = 0;
          };
          autoActivate = true;
          network = {
            # No routable VM address: ports reach the host through the
            # ssh port forwarder like Docker Desktop did.
            address = false;
            mode = "";
            interface = "";
            preferredRoute = false;
            dns = [];
            # Docker Desktop's well-known name for "the host".
            dnsHosts = {"host.docker.internal" = "host.lima.internal";};
            hostAddresses = false;
            gatewayAddress = null;
          };
          forwardAgent = false;
          docker = {};
          # vz + virtiofs are the fast path on Apple silicon; rosetta lets
          # linux/amd64 images run without qemu user emulation. Do not fall
          # back to qemu/sshfs without measuring.
          vmType = "vz";
          portForwarder = "ssh";
          rosetta = true;
          binfmt = true;
          nestedVirtualization = false;
          mountType = "virtiofs";
          # Propagate host file changes into the guest for dev servers.
          mountInotify = true;
          cpuType = "";
          provision = [];
          sshConfig = true;
          sshPort = 0;
          # Default mounts: $HOME and /tmp/colima.
          mounts = [];
          diskImage = "";
          rootDisk = 20;
          env = {};
        };
      };
    };

    # Supervision only; PATH, COLIMA_HOME and the log paths are upstream's.
    launchd.agents.colima-default.config = {
      ProgramArguments = lib.mkForce [(toString startColima)];
      KeepAlive = lib.mkForce {SuccessfulExit = false;};
      # launchd's 10 s default retry floods the log when a start keeps
      # failing (a wedged vz instance); a minute is plenty.
      ThrottleInterval = 60;
    };
  };
}
