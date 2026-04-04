#!/bin/bash
#DIAGV2.0
clear

# ── Couleurs ──────────────────────────────────────────────
RST='\e[0m'; BLD='\e[1m'; DIM='\e[2m'
GRN='\e[32m'; RED='\e[31m'; YEL='\e[33m'; CYN='\e[36m'

# ── Barre de progression ── $1=pourcentage $2=largeur ─────
bar() {
    local p=$1 w=${2:-20} f
    f=$((p * w / 100)); [ $f -gt $w ] && f=$w
    local c=$GRN; [ $p -ge 70 ] && c=$YEL; [ $p -ge 90 ] && c=$RED
    printf '%b' "$c"
    [ $f -gt 0 ] && printf '%*s' $f | tr ' ' '#'
    printf '%b' "$DIM"
    [ $((w - f)) -gt 0 ] && printf '%*s' $((w - f)) | tr ' ' '-'
    printf '%b' "$RST"
}

# ── Ligne horizontale (compatible multi-octets) ──────────
hrule() {
    local n=$1 i
    for ((i=0; i<n; i++)); do printf '─'; done
}

# ── Titre de section ─────────────────────────────────────
sec() {
    printf " %b├── %s " "$CYN" "$1"
    hrule $((67 - ${#1}))
    printf "%b\n" "$RST"
}

# ── Collecte des donnees ─────────────────────────────────
_host=$(hostname)
_dist=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
_kern=$(uname -r 2>/dev/null)
_last=$(last -i "$(whoami)" 2>/dev/null | grep "$(whoami)" | grep -v "still" | head -1 | awk '{print $4,$5,$6,$7}')
[ -z "$_last" ] && _last="N/A"

_if=$(ip route 2>/dev/null | awk '/default/{print $5;exit}')
_ipf=$(ip -o -f inet addr show "$_if" 2>/dev/null | awk '{print $4}')
_ip=${_ipf%%/*}; _mk=${_ipf##*/}
_gw=$(ip route 2>/dev/null | awk '/default/{print $3;exit}')
_pub=$(curl -s --connect-timeout 2 --max-time 3 ifconfig.me 2>/dev/null)
[ -z "$_pub" ] && _pub="N/A"

if grep -q "$_if" /etc/network/interfaces 2>/dev/null && grep -q "dhcp" /etc/network/interfaces 2>/dev/null; then
    _ipt="DHCP"
else
    _ipt="Statique"
fi

# Connexions VPN (port 1194)
# TCP : ss state established
_vpn_t=$(ss -H -tn state established '( sport = :1194 )' 2>/dev/null | wc -l)
# UDP : conntrack (seule methode fiable, couvre Docker/NAT)
_vpn_u=$(awk '/dport=1194/{n++} END{print n+0}' /proc/net/nf_conntrack 2>/dev/null)
_vpn=$((_vpn_t + _vpn_u))

_sp=$(grep -i '^Port' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
[ -z "$_sp" ] && _sp=22
_ssh=$(ss -H -tn state established "( sport = :$_sp )" 2>/dev/null | wc -l)

ping -c1 -W1 8.8.8.8 &>/dev/null && _net="${GRN}OK${RST}" || _net="${RED}KO${RST}"
getent hosts google.com &>/dev/null && _dns="${GRN}OK${RST}" || _dns="${RED}KO${RST}"

# ── Services ──────────────────────────────────────────────
_ovpn="${RED}Inactif${RST}"
if systemctl is-active --quiet openvpn 2>/dev/null; then
    _ovpn="${GRN}Actif${RST}"
elif /etc/init.d/openvpn status 2>&1 | grep -qi "running"; then
    _ovpn="${GRN}Actif${RST}"
elif ss -lntu 2>/dev/null | grep -q ':1194 '; then
    _ovpn="${GRN}Actif${RST} (port)"
fi

_dkr="${RED}Inactif${RST}"
if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
    _dkr_count=$(docker ps -q 2>/dev/null | wc -l)
    _dkr="${GRN}Actif${RST} ($_dkr_count cont.)"
fi

_svc_fail=$(systemctl --failed --no-legend --no-pager 2>/dev/null | wc -l)

# ── Systeme ───────────────────────────────────────────────
_up=$(awk '{d=int($1/86400);h=int($1%86400/3600);m=int($1%3600/60)
    if(d>0)printf "%dj %dh %dm",d,h,m
    else if(h>0)printf "%dh %dm",h,m
    else printf "%dm",m}' /proc/uptime 2>/dev/null)
_ld=$(awk '{printf "%s %s %s",$1,$2,$3}' /proc/loadavg 2>/dev/null)
_cpus=$(nproc 2>/dev/null || echo 1)
_ld1=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
_cpu_pct=$(awk -v l="$_ld1" -v c="$_cpus" 'BEGIN{p=int(l/c*100);if(p>100)p=100;print p}')

_procs=$(ls -1d /proc/[0-9]* 2>/dev/null | wc -l)
_zombies=$(ps -eo stat 2>/dev/null | grep -c '^Z')

# ── Memoire ───────────────────────────────────────────────
_mu=$(free -m | awk '/^Mem:/{print $3}')
_mt=$(free -m | awk '/^Mem:/{print $2}')
_mp=$((_mu * 100 / _mt))
_mh=$(free -h | awk '/^Mem:/{print $3"/"$2}')

_su=$(free -m | awk '/^Swap:/{print $3+0}')
_st=$(free -m | awk '/^Swap:/{print $2+0}')
_has_swap=0
if [ "$_st" -gt 0 ] 2>/dev/null; then
    _has_swap=1
    _spp=$((_su * 100 / _st))
    _sh=$(free -h | awk '/^Swap:/{print $3"/"$2}')
fi

# ── Disques ───────────────────────────────────────────────
_nd=$(lsblk -dn -o TYPE 2>/dev/null | grep -c disk)
_logsize=$(du -sh /var/log 2>/dev/null | awk '{print $1}')

# ── Securite ──────────────────────────────────────────────
_fail=$(journalctl _SYSTEMD_UNIT=ssh.service --since today --no-pager 2>/dev/null \
    | grep -ci "failed\|invalid" || true)
[ -z "$_fail" ] && _fail=0
_upd=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)
[ -z "$_upd" ] && _upd=0

# ══════════════════════════════════════════════════════════
#                      AFFICHAGE
# ══════════════════════════════════════════════════════════
L=" ${CYN}│${RST}"

printf " ${CYN}┌"; hrule 71; printf "${RST}\n"
printf "${L}  ${BLD}%-30s${RST}${DIM}%s${RST}\n" "$_host" "$_dist"
printf "${L}  Connexion prec. : ${DIM}%-22s${RST}Noyau : ${DIM}%s${RST}\n" "$_last" "$_kern"

sec "Reseau"
_pad=$((28 - ${#_ip} - ${#_mk} - ${#_ipt}))
[ $_pad -lt 1 ] && _pad=1
printf "${L}  IP : %s/%s (${YEL}%s${RST})%*sPasserelle : %s\n" \
    "$_ip" "$_mk" "$_ipt" "$_pad" "" "$_gw"
printf "${L}  VPN : %-4s(1194)   SSH : %-4s(%s)      Internet : " "$_vpn" "$_ssh" "$_sp"
echo -e "$_net   DNS : $_dns"
printf "${L}  IP publique : ${DIM}%s${RST}\n" "$_pub"

sec "Services"
echo -e "${L}  OpenVPN : $_ovpn                    Docker : $_dkr"
if [ "$_svc_fail" -gt 0 ]; then
    _sfd="${RED}$_svc_fail${RST}"
else
    _sfd="${GRN}0${RST}"
fi
echo -e "${L}  Services en echec : $_sfd"

sec "Systeme"
printf "${L}  Uptime : %-28sCharge : %s\n" "$_up" "$_ld"
printf "${L}  CPU   %-14s[" "$_ld1/$_cpus"
bar $_cpu_pct
printf "] %3d%%\n" "$_cpu_pct"
printf "${L}  RAM   %-14s[" "$_mh"
bar $_mp
printf "] %3d%%\n" "$_mp"
if [ "$_has_swap" -eq 1 ]; then
    printf "${L}  Swap  %-14s[" "$_sh"
    bar $_spp
    printf "] %3d%%\n" "$_spp"
fi
if [ "$_zombies" -gt 0 ]; then
    _zd="${RED}$_zombies${RST}"
else
    _zd="${GRN}0${RST}"
fi
echo -e "${L}  Processus : $_procs        Zombies : $_zd               Logs : $_logsize"

sec "Disques ($_nd)"
_seen=""
for _m in / /home /var; do
    _dev=$(df "$_m" 2>/dev/null | awk 'NR==2{print $1}')
    echo "$_seen" | grep -q "$_dev" && continue
    _seen="$_seen $_dev"
    _di=$(df -h "$_m" 2>/dev/null | awk 'NR==2{print $3"/"$2,$5}')
    _ds=$(echo "$_di" | awk '{print $1}')
    _dp=$(echo "$_di" | awk '{gsub(/%/,"");print $2}')
    [ -z "$_dp" ] && continue
    printf "${L}  %-7s%-14s[" "$_m" "$_ds"
    bar "$_dp"
    printf "] %3d%%\n" "$_dp"
done

sec "Securite"
[ "$_fail" -gt 0 ] 2>/dev/null && _fd="${YEL}$_fail${RST}" || _fd="${GRN}0${RST}"
[ "$_upd" -gt 0 ] 2>/dev/null && _ud="${YEL}$_upd${RST}" || _ud="${GRN}0${RST}"
echo -e "${L}  Echecs SSH (24h) : $_fd                 Mises a jour : $_ud"

printf " ${CYN}└"; hrule 71; printf "${RST}\n"
