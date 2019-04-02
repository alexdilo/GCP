#!/bin/bash
#IFS=$'\n'
#set -x 
clear
#install 
if ! which dialog &>/dev/null ; then
 
    echo "you need to install dialog"
exit 
fi
   
list_service () { 

listing
for a in ${projects[@]}
   do
       service_account email $a
    done
}

 
key_list () {

	gcloud iam service-accounts keys list --iam-account=$1 --project=$2  --filter="validBeforeTime.date('%Y-%m-%d', Z)>'$date +%F'" --managed-by user   2> /dev/null
}




exp_key () {

	gcloud iam service-accounts keys list --iam-account=$1 --project=$2  --filter="validBeforeTime.date('%Y-%m-%d', Z)<'$date +%F'" --managed-by user   2> /dev/null
}




owner_finder () {

for k in `echo "$list" | awk '{print $1}' | tail -n +2` 
 do 
       	gcloud beta logging read "resource.type=service_account AND protoPayload.response.name=projects/$1/serviceAccounts/$2/keys/$k" --freshness=400d --project=$1  | grep principalEmail | awk '{print $2}'
  done	
}


service_account_with_key () {

listing
service_list=/tmp/service-account-list
ans=yes
clear
if [  -f /tmp/service-account-list ]; then
 cat /tmp/service-account-list
 echo 
 echo 
 read -p  "service-account list already in cache,do you want to regenarate?(yes/no)" ans
fi

if [ $ans == yes ] ; then 
echo  -e "\033[33;5;7mPlease wait...listing serivce-account with key \033[0m"
 for a in ${projects[@]}
  do
    for s in `service_account email $a`
    do
    list=`key_list $s $a`
      if  [ ! -z "$list" ]
       then
       echo $s 
      fi
    done
   done | sort > $service_list
fi 
}

service_account () {

gcloud iam service-accounts list --format="value($1)" --project "$2"

}


listing () {
if [ ! -f /tmp/project-list ]; then
clear
echo "                                                                         LISTING GOOGLE CLOUD PROJECT PROCESS"
echo  -e "\033[33;5;7mPlease wait...searching projects that you have access to.This might take a few minute \033[0m"
token=$(gcloud auth print-access-token)
cmd=(dialog --separate-output --checklist "Select your projects:" 22  76 16)
list=("$(for i in $(gcloud projects list --format="value(projectId)") ; do curl -X POST  -H "Authorization:Bearer $token"  https://cloudresourcemanager.googleapis.com/v1/projects/$i:testIamPermissions -H'content-type:application/json' -d'{"permissions":["iam.serviceAccounts.list"]}' 2> /dev/null | grep -q permission && echo $i && sleep 0.5  & done)")
options1=(`number=0 ; for i in $list ; do (( number ++)); echo "$i $number off" ; done `)
projects=$("${cmd[@]}" "${options1[@]}" 2>&1 >/dev/tty)
echo $projects > /tmp/project-list
fi
projects=`cat /tmp/project-list`
clear
}

role () {
gcloud projects get-iam-policy $1  --flatten="bindings[].members" --format='table(bindings.role)' --filter="bindings.members:$2"
}

api_call () {

ID=`gcloud iam service-accounts list --filter="email=($1)" --format="value(uniqueId)" --project $2`

if [ "`curl "https://monitoring.clients6.google.com/v3/projects/$2/timeSeries?aggregation.alignmentPeriod=2592000s&aggregation.crossSeriesReducer=REDUCE_SUM&aggregation.groupByFields=resource.labels.service&aggregation.perSeriesAligner=ALIGN_SUM&filter=resource.type=%22consumed_api%22%20AND%20metric.type=%22serviceruntime.googleapis.com/api/request_count%22%20AND%20resource.labels.credential_id=%22serviceaccount:$ID%22&interval.endTime=$(date +%FT%T)Z&interval.startTime=2018-01-07T16:55:50.340Z"  -H "Content-Type: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2> /dev/null`" == {} ]
                      then echo -e "[$1] has not been used in the last month(0 API call)"
fi
}


options=("Inventory" "List-service-account-Keys-with-creator-SLOW" "List-service-account-Keys-without-creator-FAST" "List-unused-Service-account" "List-services-account" "Rotate-key" "Delete-cache" "Quit")


select case in "${options[@]}"

do 
 
   case $case in 


Delete-cache)

rm /tmp/project-list
;;


Inventory)
service_account_with_key

if [ ! -s $service_list ] ; then 
 echo "service account list is empty"
 exit
 else
   select c in `cat $service_list`
     do
       anse=yes
       if [ -f $c.json ] ; then
        clear 
        echo "the service account $c is already reigistered"
        echo
        cat  $c.json | jq .
        echo 
        read -p "do you want to update it?(yes/no)" anse
       fi 

       if [ $anse == yes ] ; then
        how="specify how the service account is implemented: Secret? Hardcoded?" 
        what="specify for what the service account is used for "
        where='specify whith details where the service account is stored,example gitlab project url ? vault? ect ..'
        app="specify in wich app/service the service account key is used therefore where should be change"
    	severity="specify what impact might have while rotate the key (LOW,MED,HIGH)"
        clear
    	echo -e ">>>>>>>>>>>>>>>>>SERVICE ACCOUNT KEY INVENTORY<<<<<<<<<<<<<<<<<<"
    	echo   "*********************$c*********************"
     	for o in how what where app severity 
          do
             read  -p "`echo "${!o}"` `echo $'\n> '`" $o
             echo
          done
          echo {'"'service-account'"': '"'$c'"', '"'how'"': '"'$how'"',  '"'what'"': '"'$what'"',  '"'where'"': '"'$where'"', '"'app'"': '"'$app'"', '"'severity'"': '"'$severity'"' } > $c.json
          echo -e  "A json file has been created for service account $c  $(realpath $c.json)\n"
          sleep 4
          clear
      fi
    done
fi
;;
List-service-account-Keys-with-creator-SLOW)
listing
             echo "                                                                         LISTING SERVICE ACCOUNT'S KEY PROCESS"
for a in ${projects[@]}

   do
	for i in `service_account email $a` 
       do  
          list=`key_list $i $a` 
            if  [ ! -z "$list" ] 
             then
             echo -e "\n\n*************************************************************************************"
             echo -e "PROJECT:   [$a]\nEMAIL_ID:  [$i]\n$list" 
             echo -e "`role $a $i`"
             for b in `owner_finder $a $i` ; do echo -e CREATOR $b ; done 
             echo       "************************************************************************************"              
           fi
       done
           exp=`exp_key $i $a`
            if  [ ! -z "$exp" ]
             then
             echo -e "\n************************Expired Keys***********************"
             echo -e "$exp\n"
            fi
    done ;; 


List-service-account-Keys-without-creator-FAST)
listing
             echo "                                                                        LISTING SERVICE ACCOUNT'S KEY PROCESS"

for a in ${projects[@]}

   do
        for i in `service_account email $a`
       do
          list=`key_list $i $a`
            if  [ ! -z "$list" ]
             then
             echo -e "\n\n*************************************************************************************"
             echo -e "PROJECT:   [$a]\nEMAIL_ID:  [$i]\n$list"   
             echo       "************************************************************************************"              
           fi
       done
           exp=`exp_key $i $a`
            if  [ ! -z "$exp" ]
             then
             echo -e "\n************************Expired Keys***********************"
             echo -e "$exp\n"
            fi
    done ;;


List-unused-Service-account)
listing

for b in  $projects
 do
  for i in  `service_account email $b`
    do
       list=`key_list $i $b`
        if  [ ! -z "$list" ]
        then
        api_call $i $b
        fi 
      done 
    done
	;;

List-services-account)
listing
for b in  $projects
 do
  for i in  `service_account email $b`
    do
       list=`key_list $i $b`
        if  [ ! -z "$list" ]
        then
        echo $i
        fi
      done 
    done ;; 

Quit)

exit 1

;;

Quit)

exit 1

;;
 

Rotate-key)
listing
clear 
select a in ${projects[@]}
   do
      clear
        select i in `service_account email $a`
       do
        clear
           list=`key_list $i $a`
            if  [ ! -z "$list" ]
               then
                 echo "                                                                         ROTATING SERVICE ACCOUNT'S KEY PROCESS"
                 echo -e "\n*************************************************************************************"
                 echo -e "PROJECT:   [$a]\nEMAIL_ID:  [$i]\n$list"   
                 for b in `owner_finder $a $i` ; do echo -e CREATOR $b ; done 
                 api_call $i $a 
                 echo       "************************************************************************************"             
                 cat $i.json | jq . 
                 echo -ne "Do you want to remove/rotate any of the above key (y/n)\r"
                 read -s answer 
                 if [ "$answer" == y ] 
                   then 
                     for idkey in `echo "$list" | awk '{print $1}' | tail -n +2`
                       do  
                         for keys in $idkey 
                          do echo -ne "Do you want to delete the key $idkey (y/n)\r"
                           read -s answer                          
                           if [ "$answer" == y ]
                            then echo -ne  'deleting key...\r'
                            echo $idkey >> /tmp/deleteKey
                            sleep 2 
                           fi
                          done
                       done
                  clear
                 fi
              clear
            fi
       done
       clear  
   done
;;
    esac

   done  
