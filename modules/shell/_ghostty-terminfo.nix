{
  lib,
  runCommand,
  ghostty,
  ncurses,
  zig_0_15,
}:
runCommand "ghostty-terminfo-${ghostty.version}" {
  nativeBuildInputs = [ncurses zig_0_15];
  meta = {
    description = "Ghostty terminal descriptions without the terminal application";
    inherit (ghostty.meta) homepage license;
    platforms = lib.platforms.all;
  };
} ''
  # Upstream maintains its terminfo in Zig. Compile only its standalone
  # encoder and definitions; the application and its dependencies are unused.
  cp ${ghostty.src}/src/terminfo/{ghostty,Source}.zig .
  cat > main.zig <<'EOF'
  const std = @import("std");
  pub fn main() !void {
      var writer = std.Io.Writer.Allocating.init(std.heap.page_allocator);
      defer writer.deinit();
      try @import("ghostty.zig").ghostty.encode(&writer.writer);
      try std.fs.cwd().writeFile(.{
          .sub_path = "ghostty.terminfo",
          .data = writer.written(),
      });
  }
  EOF
  export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-cache"
  zig build-exe main.zig -O ReleaseSafe -femit-bin=generate-terminfo
  ./generate-terminfo
  mkdir -p "$out/share/terminfo"
  tic -x -o "$out/share/terminfo" ghostty.terminfo
  install -Dm644 ghostty.terminfo "$out/share/terminfo/ghostty.terminfo"

  infocmp -x -A "$out/share/terminfo" xterm-ghostty > /dev/null
  infocmp -x -A "$out/share/terminfo" ghostty > /dev/null
''
