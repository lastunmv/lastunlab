#Выход из скрипта при возврате отличным от 0
set -e

#Проверка аргументов скрипта
if [ $# -ne 1 ]; then
	echo "Необходимо указать имя клиента без пробелов!"
	exit 1
fi

#Сегенерируем запрос 
./easyrsa gen-req $1 nopass
#Подпишем запрос
./easyrsa sign-req client $1

#Отправим ключ и сертификат на сервер OpenVPN для создания клентского файла конфигурации
key_path=/home/caadmin/easy-rsa/pki/privet/$1.key
crt_path=/home/caadmin/easy-rsa/pki/issued/$1.crt
scp -i ~/id_rsa $key_path vpnadmin@192.168.0.4:/home/vpnadmin/clients/keys
scp -i ~/id_rsa $crt_path vpnadmin@192.168.0.4:/home/vpnadmin/clients/keys

exit 0
