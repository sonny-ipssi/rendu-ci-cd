$PROD_CT_NAME='prod'
ROLLBACK_CT_NAME='rollback'

$prodContainer = $(lxc list -f csv -c n | grep -x $PROD_CT_NAME)
if [ $prodContainer -eq 0 ]
then
    lxc stop $PROD_CT_NAME
    lxc delete $PROD_CT_NAME
    sleep 2
fi 

$rollabackContainer = $(lxc list -f csv -c n | grep -x $ROLLBACK_CT_NAME)
if [ $rollabackContainer -eq 0 ]
then
    lxc rename $ROLLBACK_CT_NAME $PROD_CT_NAME
    lxc start $PROD_CT_NAME
fi 
