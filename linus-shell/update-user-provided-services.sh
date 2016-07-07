#!/bin/bash
# 2016-06-27
# This shell used to update user provided service under special org & space
#
# -a api endpoint: api.sys.pcf.mkc.io
# -u cf login username: admin
# -p cf login password: a2a986db827a30637b7f
# -o cf login org
# -s user-provided-service
# -d is debug mode. When value equal 0, run the code really. When value equal 1, Output the action, nothing will be influence.
# -l syslog drain url. When update user provided service, the syslog drain url must be provoded.


# $1= app name
function fgetappstatus()
{
        app_status=$(cf app $1 | awk 'END {print }')
        if [ "$app_status" == "There are no running instances of this app." ]; then
               app_status="N/A"
        else
               app_status=$(cf app $1 | awk 'END {print ''$2''}')
        fi
        echo $app_status
}

$cf_login_api_endpoint
$cf_login_username
$cf_login_password
$cf_login_org
$user_provided_service
$is_debug_mode
$syslog_drain_url

while getopts :a:u:p:o:s:l:d: opt
do
        case "$opt" in
                a ) cf_login_api_endpoint=$OPTARG;;
                u ) cf_login_username=$OPTARG;;
                p ) cf_login_password=$OPTARG;;
                o ) cf_login_org=$OPTARG;;
                s ) user_provided_service=$OPTARG;;
                l ) syslog_drain_url=$OPTARG;;
                d ) is_debug_mode=$OPTARG;;
                * ) echo "unknown option : $opt"
        esac
done

cf login -a $cf_login_api_endpoint -u $cf_login_username -p $cf_login_password --skip-ssl-validation -o $cf_login_org -s get_an_unexisting_space >>/dev/null

space_list=$(cf spaces)
space_list_value_can_get=0
need_to_check=1
for space in $space_list
do
        if [[  $space_list_value_can_get -eq 1 ]]; then
                cf target -s $space >>/dev/null
                echo "[Space] $space";
                service=$(cf services |grep -w $user_provided_service  | awk '{print $2}' | cut -d ' ' -f1)
                if [[ "$service" == "user-provided" ]]; then
                        app_bound_list=$(cf services |grep -w $user_provided_service  | sed 's/, /,/g' |tr -s ' ' ' ' | awk '{print $3}')
                        if [[ "$app_bound_list" == "" ]]; then
                                echo "[Action] Update service only"
                        else
                                echo "[Action] Update service"
                        fi

                        if [[ $is_debug_mode -eq 0 ]]; then
                                cf update-user-provided-service $user_provided_service -l $syslog_drain_url >> /dev/null
                                echo "         Update $user_provided_service successfully."
                        fi

                        app_list=${app_bound_list//,/ }
                        for app in $app_list
                        do
                                before_app_status=$(fgetappstatus $app)
                                echo "[Action] Restage app: $app, current app status: $before_app_status"
                                if [[ $is_debug_mode -eq 0 ]]; then
                                      cf restage $app >> /dev/null
                                      after_app_status=$(fgetappstatus $app)
                                      if [ "$before_app_status" == "$after_app_status" ]; then
                                                echo "         Restage app successfully."
                                      else
                                                echo "         Warning, app status change from $before_app_status to $after_app_status."
                                      fi
                                fi
                        done

                else
                        echo "[Action] Nothing to do"
                fi
                echo -e "";
        fi

        if [ $need_to_check -eq 1 ]; then
                if [ $space == "name" ]; then
                        space_list_value_can_get=1;
                        need_to_check=0;
                fi
        fi
done

