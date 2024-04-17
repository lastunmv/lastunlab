# lastunlab
 Проект для сдачи итоговой работы курса «Старт в DevOps: системное администрирование для начинающих».
Проект предусматривает автоматизированное построение инфраструктуры для: централизованного управления учетными записями, защищенного доступа в корпоративную сеть, мониторинга всех сервисов и оповещения о проблемах.
 Сруктура развернута на облачном решении от компании Yandex, и состоит из виртальных машин на ОС Linux Ubuntu 22.04 LTS:
 1) CA - удостоверяющий центр сертификациии на основе открытых ключей (Easy-RSA)
 2) VPN - vnp сервер на базе OpenVPN для защищенного доступа в корпоративную сеть
 3) Prometheus - сервер для мониторинга и оповещения о проблемах на сервисах и узлах инфраструктуры
 Для создания инфраструктуры в облаке используется интерфейс командной строки Yandex Cloud (CLI). Для этого необходимо ознакомиться официальной документацией - https://yandex.cloud/ru/docs/cli/quickstart. Далее по пунктам:
1) Развернуть виртуальную облачную сеть и подсеть: 
 yc vpc network create --name lab-network --description "network for my lab"
 yc vpc subnet create --name lab-subnet --description "subnet for my lab" --range 192.168.0.0/24 --network-name lab-network
2) Зарезервировать статические публичные адреса для VPN и Prometheus серверов:
 yc vpc address create --name vpn --description "open-vpn" --external-ipv4 zone=ru-central1-b
 yc vpc address create --name prometheus --description "prometheus" --external-ipv4 zone=ru-central1-b
 Результат выполнения команд должен выглядеть следующим образом
 C:\Users\lastunmv>yc vpc addresses list
+----------------------+------------+---------------+----------+-------+
|          ID          |    NAME    |    ADDRESS    | RESERVED | USED  |
+----------------------+------------+---------------+----------+-------+
| e2ldribas32p19g8o4rr | prometheus | 51.250.98.4   | true     | false |
| e2ll7i0iva200d640nvn | vpn        | 158.160.2.252 | true     | false |
+----------------------+------------+---------------+----------+-------+ 
3) Создать ВМ(ппедварительно необходимо создать пару SSH ключей, и добавить публичный ключ в команду флагом --ssh-key):
 yc compute instance create --name open-vpn --description "open-vpn" --hostname vpn. --cores 2 --memory 2GB --core-fraction 20 --network-interface address=192.168.0.4,subnet-name=lab-subnet,nat-address=158.160.2.252 --ssh-key C:\Users\lastunmv\.ssh\lab\id_rsa.pub --create-boot-disk name=open-vpn,size=8GB,image-id=fd8hnnsnfn3v88bk0k1o --preemptible
 
 yc compute instance create --name prometheus --description "prometheus" --hostname prometheus. --cores 2 --memory 2GB --core-fraction 20 --network-interface address=192.168.0.5,subnet-name=lab-subnet,nat-address=51.250.98.4 --ssh-key C:\Users\lastunmv\.ssh\lab\id_rsa.pub --create-boot-disk name=prometheus,size=8GB,image-id=fd8hnnsnfn3v88bk0k1o --preemptible
 
 yc compute instance create --name ca --description "ca" --hostname ca. --cores 2 --memory 2GB --core-fraction 20 --network-interface address=192.168.0.3,subnet-name=lab-subnet,nat-ip-version=ipv4 --ssh-key C:\Users\lastunmv\.ssh\lab\id_rsa.pub --create-boot-disk name=ca,size=8GB,image-id=fd8hnnsnfn3v88bk0k1o --preemptible
4) Так как для сервера CA статический публичнный адрес не предусмотрен, необходимо предварительно узнать его динамический публичный адрес. Для этого посмотрите подробную информацию о вашей ВМ, адрес будет в блоке one_to_one_nat:
 yc compute instance get my-yc-instance
5) Все ВМ создаются с пользователем yc-user. Используя закрытый ключ, необходимо скопировать скрипт инициализации init_vm.sh в домашнюю директорию пользователя yc-user и запустить данный скрипт из под sudo на каждой ВМ. После выполнения скрипта пользователь yc-user удаляется. Для дальнейшей работы с серверами vpn, ca и prometheus скриптом будут созданы пользователи vpnadmin, caadmin и prometheusadmin соответственно. 

Превым выполняется настройка ca сервера.
Настройка ca серверa:
1) После выполнения скрипта init_vm.sh, сервер будет доступен для SSH по порту 23 через адрес vpn сервера(158.160.2.252:23).
2) Развернуть удостоверяющий центр сертификациии на основе открытых ключей (Easy-RSA) установив deb пакет easy-rsa-lab_0.1-1_all.deb из данного репозитория.
3) Выпустить сертификат и ключ для серверов vpn(vpnserver.crt, vpnserver.key) и prometheus(prometheus.crt, prometheus.key) и скопировать их в домашние директории vnpadmin и prometheusadmin.
Настройка сервера vpn:
1) Установить OpenVPN из deb пакета openvpn-lab_2.5.9_amd64.deb
2) Установить OpenVPN-exporter из deb пакета openvpn-exporter-lab_0.1-1_all.deb
Настройка сервера prometheus:
1) Установить Prometheus из deb пакета prometheus-lab_2.31.2_amd64.deb
2) Установить Prometheus-alertmanager из deb пакета prometheus-alertmanager-lab_0.23.0_amd64.deb
3) Установить Grafana из deb пакета grafana-enterprise_10.4.2_amd64.deb

Готово, инфраструктура готова к работе!

