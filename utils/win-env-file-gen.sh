#!/bin/bash

vmname=$1
if [[ -z "$vmname" ]]; then
	echo "[win-envf:WARN] Usage: $0 <vmname>";
	exit 1;
else
	vmstat=$(vm stat -- "$vmname")
	statrc=$?
	echo "[win-envf:INFO] vm($vmname) stat $vmstat"
	if [[ "$statrc" != 0 ]]; then
		echo "[win-envf:ERROR] seems vm '$vmname' not ready";
		exit 1;
	fi
	vm exec -v $vmname -- echo "hello kiss-vm"
fi

WIN_ENV_FILE=/tmp/$vmname.env
dos2unixf() { for f; do vi -c ":set nobomb" -c ":set ff=unix" -c ":wq" -- "$f"; done; }
dos2unixf() { LANG=C LC_ALL=C sed -i -e '1s/^\xef\xbb\xbf//' -e 's/\r$//' -- "$@"; }


echo "[win-envf:INFO] generating windows env file: $WIN_ENV_FILE"

# Get install and ipconfig log
WIN_DATA=/tmp/$vmname-data
rm -fr $WIN_DATA && mkdir -p $WIN_DATA && chmod a+rwx $WIN_DATA
if ! vm homedir $vmname|grep -E -iq '(win|windows)-?7'; then
	vm cpfrom $vmname C:/postinstall_logs/* $WIN_DATA
	iconv -f UTF-16LE -t UTF-8 $WIN_DATA/postinstall.log -o $WIN_DATA/postinstall.log
else
	vm exec $vmname ipconfig </dev/null >$WIN_DATA/ipconfig.log
	vm exec $vmname cat C:/win.env </dev/null >$WIN_DATA/win.env
fi
dos2unixf $WIN_DATA/*
chmod a+rw $WIN_DATA/*

# Save relative variables into a log file
VM_INT_IP=$(awk '/^ *IPv4 Address/ {if ($NF ~ /^192\.168\.12[234]/) print $NF}' $WIN_DATA/ipconfig.log)
VM_EXT_IP=$(awk '/^ *IPv4 Address/ {if ($NF !~ /^192\.168\.12[234]/) print $NF}' $WIN_DATA/ipconfig.log)
VM_EXT_IP6=$(awk '/^ *IPv6 Address/ {printf("%s,", $NF)}'  $WIN_DATA/ipconfig.log)

rm -f $WIN_ENV_FILE
cat $WIN_DATA/win.env - <<-EOF | grep -v '^#' | tee $WIN_ENV_FILE

	VM_INT_IP=$VM_INT_IP
	VM_EXT_IP=$VM_EXT_IP
	VM_EXT_IP6=$VM_EXT_IP6
EOF
chmod a+rw $WIN_ENV_FILE
