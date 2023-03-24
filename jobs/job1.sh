#!/bin/bash
TEST_CT_NAME='test'
PROD_CT_NAME='prod'
ROLLBACK_CT_NAME='rollback'

GIT_REPO='https://github.com/sonny-ipssi/rendu-ci-cd'

WORKSPACE='/var/www/html/'

# Création des containers
lxc init ubuntu:22.04 $TEST_CT_NAME
sleep 2

# attachement du conteneur à la carte réseau
lxc network attach lxdbr0 $TEST_CT_NAME
sleep 2

# demarrage du container
lxc start $TEST_CT_NAME
sleep 2

# configuration du réseau
lxc exec $TEST_CT_NAME -- sed -i 's|#DNS=|DNS=1.1.1.1|g' /etc/systemd/resolved.conf
lxc exec $TEST_CT_NAME -- systemctl restart systemd-resolved
lxc exec $TEST_CT_NAME -- bash -c 'echo -e "[Match]\nName=*\n\n[Network]\nDHCP=ipv4" > /etc/systemd/network/10-all.network'
lxc exec $TEST_CT_NAME -- systemctl restart systemd-networkd
sleep 2

# installation des packages
lxc exec $TEST_CT_NAME -- apt update
lxc exec $TEST_CT_NAME -- apt install apache2 -y
lxc exec $TEST_CT_NAME -- apt install php -y
lxc exec $TEST_CT_NAME -- apt install git -y
sleep 2

# On se déplace dans notre espace de travail ($WORKSPACE)
cd $WORKSPACE

# suppresion de index.html
lxc exec $TEST_CT_NAME -- rm ./index.html

# récupération du répertoire git
lxc exec $TEST_CT_NAME -- git clone $GIT_REPO ./
sleep 2

# récupération de l'adresse ip du conteneur dev
CT_IP=$(lxc ls $TEST_CT_NAME -f csv -c 4 | cut -d ' ' -f1)

# on récupère tous les fichiers de test dans le dossier "test"
$TEST_FILES=$(ls test | cut -d ' ' -f1)

# On test tous les fichiers PHP 
$ARE_TESTS_OK=$(true)
for test_file in $TEST_FILES
do
    REQUEST=$(curl $CT_IP/$test_file)
    if [ "$REQUEST" != true ]
    then
        $ARE_TESTS_OK = false
    fi
done

# On vérifie que tous les tests sont passés
if [ $ARE_TESTS_OK == true ]
then
    # On récupère le container de prod
    $prod = $(lxc list -f csv -c n | grep -x $PROD_CT_NAME)

    # si prod existe alors on l'arrête et on le renomme $ROLLBACK_CT_NAME
    if [ $prod -eq 0 ]
    then
        lxc stop $PROD_CT_NAME
        lxc rename $PROD_CT_NAME $ROLLBACK_CT_NAME
        sleep 2
    fi 

    # On renomme le container de $TEST_CT_NAME en $PROD_CT_NAME
    lxc rename $TEST_CT_NAME $PROD_CT_NAME
    rm -rf test
else
    # Sinon on arrête le container $TEST_CT_NAME, on le supprime et on fait échouter le script (exit 1)
    lxc stop $TEST_CT_NAME
    lxc delete $TEST_CT_NAME
    exit 1
fi
