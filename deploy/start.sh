#!/usr/bin/env bash
# 一键启动 SIP 后端栈（MySQL + Go API + FreeSWITCH）。
#
# 存在的理由：FreeSWITCH 的 external_rtp_ip 必须是宿主机当前局域网地址，
# 客户端按它回送 RTP。这台机器换网/重新拿 DHCP 租约后地址会变，而 vars.xml
# 里是写死的——不同步就表现为「信令能通、通话能接、但完全没有声音」，
# 且 15s 后被 ICE 超时挂断，很难一眼看出根因。此脚本每次启动自动对齐。
set -uo pipefail

cd "$(dirname "$0")"
VARS="freeswitch/conf/etc/vars.xml"

# 取宿主真实局域网 IPv4：排除回环、link-local，以及 docker/WSL 的虚拟网段
host_ip() {
  powershell.exe -NoProfile -Command '
    Get-NetIPAddress -AddressFamily IPv4 |
      Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.InterfaceAlias -notlike "*vEthernet*" -and
        $_.InterfaceAlias -notlike "*Loopback*" -and
        $_.InterfaceAlias -notlike "*singbox*" -and
        $_.InterfaceAlias -notlike "*docker*"
      } |
      Sort-Object -Property InterfaceMetric |
      Select-Object -First 1 -ExpandProperty IPAddress
  ' 2>/dev/null | tr -d '\r\n '
}

IP="$(host_ip)"
if [[ ! "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "!! 无法探测宿主局域网 IP，请手动检查 vars.xml 的 external_rtp_ip" >&2
  exit 1
fi
echo "宿主局域网 IP: $IP"

CUR="$(grep -oE 'external_rtp_ip=[0-9.]+' "$VARS" | head -1 | cut -d= -f2)"
FS_NEEDS_RESTART=0
if [[ "$CUR" != "$IP" ]]; then
  echo "更新 external_rtp_ip/external_sip_ip: $CUR -> $IP"
  python -c "
import io, re, sys
p = r'$VARS'
s = io.open(p, encoding='utf-8').read()
s = re.sub(r'(external_rtp_ip=)[0-9.]+', r'\g<1>$IP', s)
s = re.sub(r'(external_sip_ip=)[0-9.]+', r'\g<1>$IP', s)
io.open(p, 'w', encoding='utf-8', newline='').write(s)
" || exit 1
  FS_NEEDS_RESTART=1
else
  echo "external_rtp_ip 已是最新，无需改动"
fi

# MySQL 是外部既有容器（不由本 compose 管理），API 依赖它先就绪
if [[ "$(docker inspect -f '{{.State.Running}}' mymysql 2>/dev/null)" != "true" ]]; then
  echo "启动 mymysql ..."
  docker start mymysql >/dev/null
fi
for _ in $(seq 1 30); do
  docker exec mymysql mysqladmin -uroot -proot ping >/dev/null 2>&1 && break
  sleep 2
done

echo "启动 go-api / freeswitch ..."
docker compose up -d >/dev/null
[[ "$FS_NEEDS_RESTART" == "1" ]] && docker restart sip-fs >/dev/null

for _ in $(seq 1 36); do
  [[ "$(docker inspect -f '{{.State.Health.Status}}' sip-fs 2>/dev/null)" == "healthy" ]] && break
  sleep 5
done

echo
echo "---- 状态 ----"
docker ps --filter name=sip-api --filter name=sip-fs --filter name=mymysql \
  --format "  {{.Names}}\t{{.Status}}"
printf "  API /healthz: %s\n" "$(curl -s -m 5 "http://localhost:8080/healthz" || echo '无响应')"
docker exec sip-fs fs_cli -x "sofia status profile internal" 2>/dev/null |
  grep -iE "Ext-RTP-IP|Ext-SIP-IP" | sed 's/^/  /'
echo
echo "---- 客户端连接参数 ----"
echo "  手机 App 服务器地址: $IP"
echo "  SIP 硬件/ATA:        $IP:5060 (UDP), 编解码 PCMU"
echo "  分机与密码见 users / sip_accounts 表，或调用 /api/v1/auth/register 新开"
