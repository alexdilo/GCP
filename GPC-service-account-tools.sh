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

cmd=(dialog --separate-output --checklist "Select your projects:" 22  76 16)

options1=(`number=0 ; for i in $(gcloud projects list --format="value(projectId)") ; do (( number ++)); echo "$i $number off" ; done | sort `)
choices=$("${cmd[@]}" "${options1[@]}" 2>&1 >/dev/tty)
clear
for choice in $choices
 do
  projects=$choice
 done
}

options=("List-service-account-Keys-with-creator-SLOW" "List-service-account-Keys-without-creator-FAST" "List-unused-Service-account" "List-services-account" "Rotate-key" "Quit")


select case in "${options[@]}"

do 
 
   case $case in 

List-service-account-Keys-with-creator-SLOW)
listing

for a in "${projects[@]}"

   do 
	for i in `service_account email $a` 
       do  
          list=`key_list $i $a` 
            if  [ ! -z "$list" ] 
             then 
             echo -e "\n\nPROJECT:   [$a]\nEMAIL_ID:  [$i]\n$list"   
             for b in `owner_finder $a $i` ; do echo -e CREATOR $b ; done  
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

for a in "${projects[@]}"

   do
        for i in `service_account email $a`
       do
          list=`key_list $i $a`
            if  [ ! -z "$list" ]
             then
             echo -e "\n\nPROJECT:   [$a]\nEMAIL_ID:  [$i]\n$list"   
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
	for pro in "${projects[@]}"

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
for a in "${projects[@]}" 
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
for a in "${projects[@]}"
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
