#!/bin/bash

#--------Etape 1---------

echo "Configuration du Routeur :"
read -p "Etape 1 - Interface Réseau : DHCP ou STATIC ? (d/s) : " iface_type

if [[ "$iface_type" == "d" ]]; then
	read -p "Donnez le nom de la carte réseau : " interfaceDHCP_name
	echo "
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto $interfaceDHCP_name
iface $interfaceDHCP_name inet dhcp" > /etc/network/interfaces
	systemctl restart networking.service
fi

read -p "Interface Réseau : DHCP ou STATIC ? (d/s) : " iface_type
if [[ "$iface_type" == "s" ]]; then
	read -p "Quel est le nombre de carte avec une ip static ? : " nbCarte_static
	for((i = 1; i <= nbCarte_static; i++)); do
		read -p "Quel est le nom de la carte réseau (static) N°$i : " interface_name
		read -p "Quelle est l'addresse ip de la carte réseau ? " ip_static
		read -p "Quelle est le masque pour ce réseau ? (0-32) " netmask
		echo "
# The static net
auto $interface_name
iface $interface_name inet static
	address $ip_static/$netmask" >> /etc/network/interfaces
	done
fi
systemctl restart networking.service

echo "fin de la l'Etape 1 : Interface Réseau !"
cat /etc/network/interfaces


#--------Etape 2---------
# Activation du routage
# echo 1 > /proc/sys/net/ipv4/ip_forward
read -p "Etape 2 - Routage : Voulez-vous activer le routage ? (y/n) [y]: " boolRoutage
if [[ "$boolRoutage" == "y" || "$boolRoutage" == "" ]]; then
	sed -i "28{s/^#//g}" /etc/sysctl.conf
	sysctl -p
	echo "Le routage est activé !"
fi

echo "fin de l'Etape 2 : Routage !"

#--------Etape 3---------
# Les règles nat de base avec nftables
read -p "Etape 3 - Nat : Voulez-vous activer les règles nat de base ? (y/n) [y]: " boolNat
if [[ "$boolNat" == "y" || "$boolNat" == "" ]]; then
	nft flush ruleset
	nft add table ip NAT-PAT
	nft add chain NAT-PAT nat "{ type nat hook postrouting priority srcnat;}"
	nft add rule NAT-PAT nat oifname $interfaceDHCP_name masquerade
	nft list ruleset >> /etc/nftables.conf
	cat /etc/nftables.conf
fi

systemctl restart nftables.service

echo "fin de l'Etape 3 : Nat !"

read -p "Voulez-vous redemarrer le router ? (cela corrigera les erreurs du service networking) (y/n) [y]: " redemarrer

if [[ "$redemarrer" == "y" || "$redemarrer" == "" ]]; then
	init 6
fi
