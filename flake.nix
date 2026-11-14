{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; overlays = [ rust-overlay.overlays.default ]; };
      # liest rust-toolchain.toml (stable + rustfmt + clippy)
      toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
      libs = with pkgs; [
        wayland libxkbcommon libGL vulkan-loader
        xorg.libX11 xorg.libXcursor xorg.libXi xorg.libXrandr xorg.libxcb
      ];
    in {
      devShells.${system} = {
      default = pkgs.mkShell {
        nativeBuildInputs = [ toolchain pkgs.rust-analyzer pkgs.cargo-deny pkgs.pkg-config ];
        buildInputs = libs;
        # eframe lädt Wayland/X11/GL/Vulkan zur Laufzeit per dlopen
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath libs;
      };

      # Cross-build for Windows and run the tests under the system's Wine:
      #   nix develop ../rick-devshell#windows -c cargo test -p ext-zfs --target x86_64-pc-windows-gnu
      windows =
        let
          mingw = pkgs.pkgsCross.mingwW64;
          wintoolchain = toolchain.override { targets = [ "x86_64-pc-windows-gnu" ]; };
        in
        pkgs.mkShell {
          nativeBuildInputs = [ wintoolchain mingw.stdenv.cc pkgs.pkg-config ];
          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER = "${mingw.stdenv.cc}/bin/x86_64-w64-mingw32-gcc";
          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS = "-L native=${mingw.windows.pthreads}/lib";
          CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUNNER = "/usr/bin/wine";
          CARGO_TARGET_DIR = "target/windows";
          WINEDEBUG = "-all";
          # The test binaries link std and libgcc dynamically: Wine finds the DLLs here.
          WINEPATH = "${wintoolchain}/lib/rustlib/x86_64-pc-windows-gnu/lib;${mingw.stdenv.cc.cc.lib}/x86_64-w64-mingw32/lib;${mingw.windows.pthreads}/bin;${mingw.windows.mcfgthreads}/bin";
        };
      };
    };
}
