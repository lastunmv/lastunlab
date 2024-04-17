#!/bin/bash

#Скрипт для подготовки ВМ 

#Выход из скрипта при возврате отличным от 0
set -e 

#Проверка запуска скрипта с правами root
if [ "$UID" -ne 0 ]
then 
	echo "Run the script with root rights"
	exit 1
fi

#Переменная для имени пользователя
username=${HOSTNAME}admin

#Назначение порта для SSH и проверка корректности имени хоста
if [ $HOSTNAME == 'prometheus' -o $HOSTNAME == 'vpn' ]; then
	sshport=22
elif [ $HOSTNAME == 'ca' ]; then
	sshport=23
else
	echo "The hostname must be vpn, ca or prometheus"
	exit 1
fi

#Функция добавления правил iptables
add_rule() {
	if ! iptables -C $* &>/dev/null; then
		iptables -A $*
	fi
}

#Функция добавления правил nat iptables
add_nat() {
	if ! iptables -t nat -C $* &>/dev/null; then
		iptables -t nat -A $*
	fi
}

#Настройка часового пояса 
echo "Setting timezone"
timedatectl set-timezone Europe/Moscow
timedatectl status

#Создадим имя пользователя администратора
if ! grep $username /etc/passwd &>/dev/null; then
	read -s -r -p "Будет создан пользователь $username. Введите пароль для пользователя: " password
	useradd -p $(openssl passwd $password) -d /home/$username -m -s /bin/bash -G sudo $username
fi

#Копируем ssh ключи ключи для нового пользователя
cp -r /home/yc-user/.ssh/ /home/$username/ && chown -R $username:$username /home/$username/.ssh

#Установка общих пакетов
apt-get update
apt-get install -y iptables
apt-get install -y iptables-persistent
apt-get install -y prometheus-node-exporter
#Установка для ыервера prometheus
if [ $HOSTNAME == 'prometheus' ]; then
       apt-get install prometheus-blackbox-exporter
fi       

#Правки в конфиг ssh
sed -i "s/^#\?\(Port\s*\).*$/\1$sshport/"  /etc/ssh/sshd_config
sed -i 's/^#\?\(PermitRootLogin\s\).*$/\1no/'  /etc/ssh/sshd_config
sed -i 's/^#\?\(PubkeyAuthentication\s\).*$/\1yes/'  /etc/ssh/sshd_config
sed -i 's/^#\?\(PermitEmptyPasswords\s\).*$/\1no/'  /etc/ssh/sshd_config
sed -i 's/^#\?\(PasswordAuthentication\s\).*$/\1no/'  /etc/ssh/sshd_config
systemctl restart sshd
echo "SSH has been restarted"

#Настройки iptables 
echo "Now the session will be terminated, connect again as user $username to port shh - $sshport"
add_rule INPUT -p tcp --dport $sshport -j ACCEPT
add_rule INPUT -p icmp -j ACCEPT
add_rule OUTPUT -p icmp -j ACCEPT
add_rule OUTPUT -p tcp --dport 53 -j ACCEPT
add_rule OUTPUT -p udp --dport 53 -j ACCEPT
add_rule OUTPUT -p udp --dport 123 -j ACCEPT 
add_rule OUTPUT -p tcp -m multiport --dports 80,8080,443 -j ACCEPT
add_rule INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
add_rule OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
add_rule INPUT -i lo -j ACCEPT
add_rule OUTPUT -o lo -j ACCEPT

#Настройка iptables для определенного сервера
if [ $HOSTNAME == 'vpn' ]; then
	#Правила для сервера vpn
        #Проброс порта на сервер сертификатов через сервер vpn
	sysctl -w net.ipv4.ip_forward=1
        sed -i "s/^#\?\(net.ipv4.ip_forward=1\).*$/\1/"  /etc/sysctl.conf
        add_rule INPUT -p tcp --dport 23 -j ACCEPT -m comment --comment ssh_to_ca
        add_rule FORWARD -p tcp --dport 23 -d 192.168.0.3 -j ACCEPT -m comment --comment ssh_to_ca
        add_rule FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT 
        add_nat PREROUTING -p tcp --dport 23 -j DNAT --to-destination 192.168.0.3 -m comment --comment ssh_to_ca
        add_nat POSTROUTING -d 192.168.0.3 -p tcp --dport 23 -j SNAT --to-source 192.168.0.4 -m comment --comment ssh_to_ca
        #Правила iptables для сервера VPN
        add_rule INPUT -p udp -m state --state NEW --dport 1194 -j ACCEPT -m comment --comment openvpn
        add_rule INPUT -i tun+ -j ACCEPT -m comment --comment openvpn
        add_rule FORWARD -i tun+ -j ACCEPT -m comment --comment openvpn
        add_nat POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE -m comment --comment openvpn
	#Правило iptables для node_exporter и openvpn_exporter
	add_rule INPUT -p tcp -s 192.168.0.5/32 --dport 9100 -j ACCEPT -m comment --comment node_exporter
	add_rule INPUT -p tcp -s 192.168.0.5/32 --dport 9176 -j ACCEPT -m comment --comment openvpn_exporter
elif [ $HOSTNAME == 'prometheus' ]; then 
 	#Правила для сервера prometheus
	add_rule OUTPUT -p tcp -d 192.168.0.3/32 --dport 9100 -j ACCEPT -m comment --comment node_exporter_ca
	add_rule OUTPUT -p tcp -d 192.168.0.4/32 --dport 9100 -j ACCEPT -m comment --comment node_exporter_vpn
	add_rule OUTPUT -p tcp -d 192.168.0.4/32 --dport 9176 -j ACCEPT -m comment --comment openvpn_exporter
	add_rule OUTPUT -p tcp --dport 465 -j ACCEPT -m comment --comment SMTP
	add_rule INPUT -p tcp --dport 3000 -j ACCEPT -m comment --comment grafana
elif [ $HOSTNAME == 'ca' ]; then
	#Правила для сервера ca
	#Правило iptables для node_exporter
	add_rule INPUT -p tcp -s 192.168.0.5/32 --dport 9100 -j ACCEPT -m comment --comment node_exporter
	#Правило для передачи файлов на другие сервера по ssh
	add_rule OUTPUT -p tcp -d 192.168.0.0/24 --dport 22 -j ACCEPT -m comment --comment SSH
fi

#Блокировка остального трафика 
iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP

#Сохраним iptables 
netfilter-persistent save

#Блокировка пользователя yc-user
usermod -L -s /sbin/nologin yc-user
deluser yc-user sudo

if [ $HOSTNAME == 'ca' ]; then
        echo "Reconnect 158.160.2.252 as user $username to port shh - $sshport"
else
        echo "Reconnect as user $username to port shh - $sshport"
fi

