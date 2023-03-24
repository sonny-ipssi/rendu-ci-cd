PREPROD_CT_NAME='pre-prod'
PROD_CT_NAME='prod'

GIT_REPO='https://github.com/sonny-ipssi/rendu-ci-cd'
WORKSPACE='/var/www/html/'

# Création des containers
lxc init ubuntu:22.04 $PREPROD_CT_NAME
sleep 2

# attachement du conteneur à la carte réseau
lxc network attach lxdbr0 $PREPROD_CT_NAME
sleep 2

# demarrage du container
lxc start $PREPROD_CT_NAME
sleep 2

# configuration du réseau
lxc exec $PREPROD_CT_NAME -- sed -i 's|#DNS=|DNS=1.1.1.1|g' /etc/systemd/resolved.conf
lxc exec $PREPROD_CT_NAME -- systemctl restart systemd-resolved
lxc exec $PREPROD_CT_NAME -- bash -c 'echo -e "[Match]\nName=*\n\n[Network]\nDHCP=ipv4" > /etc/systemd/network/10-all.network'
lxc exec $PREPROD_CT_NAME -- systemctl restart systemd-networkd
sleep 2

# installation des packages
lxc exec $PREPROD_CT_NAME -- apt update
lxc exec $PREPROD_CT_NAME -- apt install apache2 -y
lxc exec $PREPROD_CT_NAME -- apt install php -y
lxc exec $PREPROD_CT_NAME -- apt install git -y

# On se déplace dans notre espace de travail ($WORKSPACE)
cd $WORKSPACE

# suppresion de index.html
lxc exec $PREPROD_CT_NAME -- rm ./index.html

# récupération du répertoire git
lxc exec $PREPROD_CT_NAME -- git clone $GIT_REPO ./
sleep 2

# on supprime le dossier des TUs
rm -rf test

# Si le container de prod existe alors on l'arrête et on le supprime
$prodContainer = $(lxc list -f csv -c n | grep -x $PROD_CT_NAME)
if [ $prodContainer -eq 0 ]
then
    lxc stop $PROD_CT_NAME
    lxc delete $PROD_CT_NAME
    sleep 2
fi 

# On renomme le container $PREPROD_CT_NAME $PROD_CT_NAME
lxc rename $PREPROD_CT_NAME $PROD_CT_NAME