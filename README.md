# lastunlab
## Проект для сдачи итоговой работы курса «Старт в DevOps: системное администрирование для начинающих».
Проект предусматривает автоматизированное построение инфраструктуры для: централизованного управления учетными записями, защищенного доступа в корпоративную сеть, мониторинга всех сервисов и оповещения о проблемах.
 Сруктура развернута на облачном решении от компании Yandex, и состоит из виртальных машин на ОС Linux Ubuntu 22.04 LTS:
 1) **CA** - удостоверяющий центр сертификациии на основе открытых ключей (Easy-RSA).
 2) **VPN** - vnp сервер на базе OpenVPN для защищенного доступа в корпоративную сеть.
 3) **Prometheus** - сервер для мониторинга и оповещения о проблемах на сервисах и узлах инфраструктуры.
     
 Для создания инфраструктуры в облаке используется интерфейс командной строки Yandex Cloud (CLI). Для этого необходимо ознакомиться официальной [документацией](https://yandex.cloud/ru/docs/cli/quickstart).

**Cоздание инфраструктуры в облаке:** 
1) Развернуть виртуальную облачную сеть и подсеть: 
 ```cmd
yc vpc network create --name lab-network --description "network for my lab"
```
```cmd
yc vpc subnet create --name lab-subnet --description "subnet for my lab" --range 192.168.0.0/24 --network-name lab-network
```
2) Зарезервировать статические публичные адреса для VPN и Prometheus серверов:
```cmd
yc vpc address create --name vpn --description "open-vpn" --external-ipv4 zone=ru-central1-b
```
```cmd
yc vpc address create --name prometheus --description "prometheus" --external-ipv4 zone=ru-central1-b
```
Результат выполнения команд должен выглядеть следующим образом:
```cmd
yc vpc addresses list
```
```
+----------------------+------------+---------------+----------+-------+
|          ID          |    NAME    |    ADDRESS    | RESERVED | USED  |
+----------------------+------------+---------------+----------+-------+
| e2ldribas32p19g8o4rr | prometheus | 51.250.98.4   | true     | false |
| e2ll7i0iva200d640nvn | vpn        | 158.160.2.252 | true     | false |
+----------------------+------------+---------------+----------+-------+
```
3) Создать ВМ(ппедварительно необходимо создать пару SSH ключей, и добавить публичный ключ в команду флагом --ssh-key):
```
yc compute instance create --name open-vpn --description "open-vpn" --hostname vpn. --cores 2 --memory 2GB --core-fraction 20 --network-interface address=192.168.0.4,subnet-name=lab-subnet,nat-address=158.160.2.252 --ssh-key C:\Users\lastunmv\.ssh\lab\id_rsa.pub --create-boot-disk name=open-vpn,size=8GB,image-id=fd8hnnsnfn3v88bk0k1o --preemptible
```
```
yc compute instance create --name prometheus --description "prometheus" --hostname prometheus. --cores 2 --memory 2GB --core-fraction 20 --network-interface address=192.168.0.5,subnet-name=lab-subnet,nat-address=51.250.98.4 --ssh-key C:\Users\lastunmv\.ssh\lab\id_rsa.pub --create-boot-disk name=prometheus,size=8GB,image-id=fd8hnnsnfn3v88bk0k1o --preemptible
```
```
yc compute instance create --name ca --description "ca" --hostname ca. --cores 2 --memory 2GB --core-fraction 20 --network-interface address=192.168.0.3,subnet-name=lab-subnet,nat-ip-version=ipv4 --ssh-key C:\Users\lastunmv\.ssh\lab\id_rsa.pub --create-boot-disk name=ca,size=8GB,image-id=fd8hnnsnfn3v88bk0k1o --preemptible
```
4) Так как для сервера CA статический публичнный адрес не предусмотрен, необходимо предварительно узнать его динамический публичный адрес. Для этого посмотрите подробную информацию о вашей ВМ, адрес будет в блоке one_to_one_nat:
```
yc compute instance get my-yc-instance
```
5) Все ВМ создаются с пользователем yc-user. Используя закрытый ключ, необходимо скопировать скрипт инициализации [init_vm.sh](https://github.com/lastunmv/lastunlab/blob/c9e8c2128db5ccbbe8b9f56daa7b65665819249c/init_vm.sh) в домашнюю директорию пользователя yc-user и запустить данный скрипт из под sudo на каждой ВМ. После выполнения скрипта пользователь yc-user удаляется. Для дальнейшей работы с серверами vpn, ca и prometheus скриптом будут созданы пользователи vpnadmin, caadmin и prometheusadmin соответственно.

**Настройка серверов:**
1) ***Настройка ca серверa:***
  + Подключиться по SSH к серверу. После выполнения скрипта init_vm.sh, сервер будет доступен для SSH по порту 23 через адрес vpn сервера.
    ```cmd
    ssh -P 23 -i [путь к файлу приватного ssh ключа] caadmin@158.160.2.252
    ```
  + Развернуть удостоверяющий центр сертификациии на основе открытых ключей (Easy-RSA) установив deb пакет easy-rsa-lab_0.1-1_all.deb из данного репозитория.
  + Выпустить сертификат и ключ для серверов vpn(vpnserver.crt, vpnserver.key) и prometheus(prometheus.crt, prometheus.key) и скопировать их в домашние директории vnpadmin и prometheusadmin.
2) ***Настройка сервера vpn:***
  + Подключиться по SSH.
    ```cmd
    ssh -i [путь к файлу приватного ssh ключа] vpnadmin@158.160.2.252
    ```
  + Установить OpenVPN из deb пакета openvpn-lab_2.5.9_amd64.deb.
  + Установить OpenVPN-exporter из deb пакета openvpn-exporter-lab_0.1-1_all.deb.
3) ***Настройка сервера prometheus:***
  + Подключиться по SSH.
    ```cmd
    ssh -i [путь к файлу приватного ssh ключа] prometheusadmin@51.250.98.4
    ```
  + Установить Prometheus из deb пакета prometheus-lab_2.31.2_amd64.deb.
  + Установить Prometheus-alertmanager из deb пакета prometheus-alertmanager-lab_0.23.0_amd64.deb.
  + Установить Grafana из deb пакета grafana-enterprise_10.4.2_amd64.deb.

**Схема готовой инфраструктуры:**
![инфраструктура и потоки данных](https://github.com/lastunmv/lastunlab/blob/ffdc6e4a0921fcd551e43f234fbedf6a49ecea6b/%D0%98%D0%BD%D1%80%D0%B0%D1%81%D1%82%D1%80%D1%83%D0%BA%D1%82%D1%83%D1%80%D0%B0%20%D0%B8%20%D0%BF%D0%BE%D1%82%D0%BE%D0%BA%D0%B8%20%D0%B4%D0%B0%D0%BD%D0%BD%D1%8B%D1%85.png)

**Генерация конфигурационного файла клиента для подключения к VPN**
1) Скопировать [скрипт](client_keygen.sh) для выпуска клиентского сертификата и ключа на сервер ***ca*** в рабочую деректорию /easy-rsa, назначить владельца и дать права на исполнение:
   ```console
   cd easy-rsa
   ```
   ```console
   sudo chown caadmin:caadmin client_keygen.sh
   ```
   ```console
   sudo chmod 500 client_keygen.sh
   ```
2) Сгенерировать сертификат и ключ для клиента запустив скрипт:
   ```console
   ./client_keygen.sh [имя клиента]
   ```
   Скрипт автоматически скопирует файлы в рабочую директорию сервера ***vpn***
3) На сервере ***vpn*** перейти в директорию /home/vpnadmin/cliets сгенерировать конфигурационный файл:
   ```console
   ./make_config.sh [имя клиента]
   ```
   файл конфигурации будет находится в директории /home/vpnadmin/cliets/files. Далее его необходимо передать клиенту для подключения к VPN.
