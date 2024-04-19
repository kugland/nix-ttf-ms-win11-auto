{
  pkgs,
  lib ? pkgs.lib,
  pkgName,
  version,
  iso,
  archive,
  parentDir,
  files,
  outputHash ? "",
  ...
}:
pkgs.vmTools.runInLinuxVM
(pkgs.runCommand "${pkgName}-${version}" {
    pname = pkgName;
    inherit version;
    meta = with pkgs.lib; {
      description = "${pkgName}: automatically-extracted Microsoft";
      license = licenses.unfree;
      maintainers = [maintainers.kugland];
      platforms = platforms.all;
    };
    buildInputs = with pkgs; [cacert dhcpcd busybox httpdirfs p7zip fuse3 udftools];
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    inherit outputHash;
    QEMU_OPTS = "-nic user,model=virtio";
  } ''
    # Set up networking
    ${pkgs.kmod}/bin/modprobe virtio_net
    ip link set dev lo up
    ip link set dev eth0 up
    dhcpcd eth0

    mkdir -p mnt/http
    httpdirfs --single-file-mode ${lib.escapeShellArgs [iso]} mnt/http

    # Mount the ISO
    ${pkgs.kmod}/bin/modprobe udf
    mknod /dev/loop0 b 7 0
    mkdir -p mnt/iso
    mount -o loop mnt/http/*.iso mnt/iso
    ARCHIVE_PATH="$(pwd)/mnt/iso/${archive}"

    # Extract fonts from the WIM
    mkdir -p $out/share/fonts/truetype
    cd $out/share/fonts/truetype
    7z e -aoa "$ARCHIVE_PATH" ${lib.escapeShellArgs (map (file: "${parentDir}${file}") files)}
  '')
