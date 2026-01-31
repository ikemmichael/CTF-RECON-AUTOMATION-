#!/usr/bin/env bash

# ===============================
# CTF AUTO RECON SCRIPT
# ===============================

if [ -z "$1" ]; then
  echo "Usage: $0 <target-ip>"
  exit 1
fi

TARGET=$1
OUTDIR="recon_$TARGET"
WORDLIST="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"

mkdir -p $OUTDIR/{nmap,web,smb,nfs,snmp}

echo "[+] Target: $TARGET"
echo "[+] Output directory: $OUTDIR"
echo

# -------------------------------
# 1. FAST PORT SCAN
# -------------------------------
echo "[+] Running fast full port scan..."
nmap -Pn -T4 --min-rate 5000 -p- $TARGET -oA $OUTDIR/nmap/all_ports

OPEN_PORTS=$(grep open $OUTDIR/nmap/all_ports.gnmap | cut -d' ' -f4 | tr '\n' ',' | sed 's/,$//')

echo "[+] Open ports: $OPEN_PORTS"
echo

# -------------------------------
# 2. VERSION + DEFAULT SCRIPTS
# -------------------------------
echo "[+] Running version and default scripts..."
nmap -Pn -sC -sV -p $OPEN_PORTS $TARGET -oA $OUTDIR/nmap/services

# -------------------------------
# 3. WEB ENUMERATION
# -------------------------------
if echo "$OPEN_PORTS" | grep -Eq "80|443|8080|8180|8000"; then
  echo "[+] Web service detected. Running web enumeration..."

  for PORT in 80 443 8080 8180 8000; do
    if echo "$OPEN_PORTS" | grep -q "$PORT"; then
      URL="http://$TARGET:$PORT"
      [ "$PORT" == "443" ] && URL="https://$TARGET"

      echo "[+] whatweb on $URL"
      whatweb $URL | tee $OUTDIR/web/whatweb_$PORT.txt

      echo "[+] ffuf on $URL"
      ffuf -u $URL/FUZZ -w $WORDLIST -mc 200,301,302 -of csv \
        -o $OUTDIR/web/ffuf_$PORT.csv
    fi
  done
fi

# -------------------------------
# 4. SMB ENUM
# -------------------------------
if echo "$OPEN_PORTS" | grep -Eq "139|445"; then
  echo "[+] SMB detected. Running enum4linux-ng..."
  enum4linux-ng $TARGET | tee $OUTDIR/smb/enum4linux.txt
fi

# -------------------------------
# 5. NFS ENUM
# -------------------------------
if echo "$OPEN_PORTS" | grep -q "2049"; then
  echo "[+] NFS detected. Checking exports..."
  showmount -e $TARGET | tee $OUTDIR/nfs/exports.txt
fi

# -------------------------------
# 6. SNMP ENUM
# -------------------------------
if echo "$OPEN_PORTS" | grep -q "161"; then
  echo "[+] SNMP detected. Running snmpwalk..."
  snmpwalk -v2c -c public $TARGET | tee $OUTDIR/snmp/snmpwalk.txt
fi

echo
echo "[+] Recon completed."
echo "[+] Review findings in: $OUTDIR"
