#!/bin/bash
#IFS=$'\n'
#set -x 
clear 
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
list=("$(for i in $(gcloud projects list --format="value(projectId)") ; do curl -X POST  -H "Authorization:Bearer $token"  https://cloudresourcemanager.googleapis.com/v1/projects/$i:testIamPermissions -H'content-type:application/json' -d'{"permissions":["iam.serviceAccounts.list"]}' 2> /dev/null | grep -q permission && echo $i && sleep 0.1  & done)")
#list=$(for access in `gcloud projects list --format="value(projectId)"` ; do gcloud  iam service-accounts list  --project "$access"  > /dev/null 2>&1 &&  echo  $access ; done)
options1=(`number=0 ; for i in $list ; do (( number ++)); echo "$i $number off" ; done `)
projects=$("${cmd[@]}" "${options1[@]}" 2>&1 >/dev/tty)
echo $projects > /tmp/project-list
fi
projects=`cat /tmp/project-list`
clear
}

options=("List-service-account-Keys-with-creator-SLOW" "List-service-account-Keys-without-creator-FAST" "List-unused-Service-account" "List-services-account" "Rotate-key" "Delete-cache" "Quit")


select case in "${options[@]}"

do 
 
   case $case in 


Delete-cache)

rm /tmp/project-list
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
	for pro in ${projects[@]}

	 do  
              for  idmail in "`gcloud iam service-accounts list --format="value(uniqueId,email)" --project "$pro"`"
	      do 
		      echo "$idmail"  | 
		      
		      while  read id email ; do   
	 		    if [ "`curl "https://monitoring.clients6.google.com/v3/projects/$pro/timeSeries?aggregation.alignmentPeriod=2592000s&aggregation.crossSeriesReducer=REDUCE_SUM&aggregation.groupByFields=resource.labels.service&aggregation.perSeriesAligner=ALIGN_SUM&filter=resource.type=%22consumed_api%22%20AND%20metric.type=%22serviceruntime.googleapis.com/api/request_count%22%20AND%20resource.labels.credential_id=%22serviceaccount:$id%22&interval.endTime=$(date +%FT%T)Z&interval.startTime=2018-01-07T16:55:50.340Z"  -H "Content-Type: application/json" -H "Authorization: Bearer $(gcloud auth print-access-token)" 2> /dev/null`" == {} ] 
		      then echo -e "\n [$email] has not been used in the last month(0 API call)"
		      fi
	            done 
              done

	done

	;;

List-services-account)
listing
for a in ${projects[@]}
   do 
        for i in `service_account email $a` 
       do  echo -e "$i" 
       done
    done ;; 

Quit)

exit 1

;; 

Rotate-key)
listing
clear 
for a in ${projects[@]}
   do
        for i in `service_account email $a`
       do
           list=`key_list $i $a`
            if  [ ! -z "$list" ]
               then
                 echo "                                                                         ROTATING SERVICE ACCOUNT'S KEY PROCESS"
                 echo -e "\n*************************************************************************************"
                 echo -e "PROJECT:   [$a]\nEMAIL_ID:  [$i]\n$list"   
                 for b in `owner_finder $a $i` ; do echo -e CREATOR $b ; done 
                 echo       "************************************************************************************"              
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
                            sleep 2 
                           fi
                          done
                       done
                  clear
                 fi
            fi
       done
       clear  
   done
;;
    esac

   done  
