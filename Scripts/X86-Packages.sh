#!/bin/bash
# Extra package sources required by the requested X86 image.
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git clone --depth=1 --single-branch --branch main https://github.com/animegasan/luci-app-wolplus.git "$work/wolplus"
test -f "$work/wolplus/Makefile"
# Remove only this package's old feed link, not unrelated packages.
find package/feeds -type l -name luci-app-wolplus -delete
rm -rf package/luci-app-wolplus
cp -a "$work/wolplus" package/luci-app-wolplus
rm -rf package/luci-app-wolplus/.git
if [[ -d package/luci-app-wolplus/po/zh-cn && ! -d package/luci-app-wolplus/po/zh_Hans ]]; then
  mv package/luci-app-wolplus/po/zh-cn package/luci-app-wolplus/po/zh_Hans
fi

git clone --depth=1 --filter=blob:none --sparse --single-branch --branch openwrt-24.10 https://github.com/immortalwrt/luci.git "$work/luci"
git -C "$work/luci" sparse-checkout set applications/luci-app-haproxy-tcp
test -f "$work/luci/applications/luci-app-haproxy-tcp/Makefile"
find package/feeds -type l -name luci-app-haproxy-tcp -delete
rm -rf package/luci-app-haproxy-tcp
cp -a "$work/luci/applications/luci-app-haproxy-tcp" package/luci-app-haproxy-tcp
python3 - <<'PY'
from pathlib import Path
p=Path('package/luci-app-haproxy-tcp/Makefile')
s=p.read_text().replace('include ../../luci.mk','include $(TOPDIR)/feeds/luci/luci.mk')
needle='define Package/$(PKG_NAME)/postinst\n#!/bin/sh\n'
if needle not in s:
    raise SystemExit('Unexpected haproxy-tcp postinst layout; review before build')
s=s.replace(needle, needle+'[ -n "$$IPKG_INSTROOT" ] && exit 0\n',1)
p.write_text(s)
po=p.parent/'po'
if (po/'zh-cn').is_dir() and not (po/'zh_Hans').exists():
    (po/'zh-cn').rename(po/'zh_Hans')
PY

git clone --depth=1 --single-branch --branch master https://github.com/lisaac/luci-lib-docker.git "$work/docker"
test -f "$work/docker/collections/luci-lib-docker/Makefile"
find package/feeds -type l -name luci-lib-docker -delete
rm -rf package/luci-lib-docker
cp -a "$work/docker/collections/luci-lib-docker" package/luci-lib-docker

# Legacy upstream uses a tag-style version; APK requires a numeric version.
# Scope this normalization to luci-lib-docker, leaving other packages untouched.
sed -i -E 's/^(PKG_VERSION:=)v([0-9])/\1\2/' package/luci-lib-docker/Makefile
