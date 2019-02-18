#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo -e "\033[44;37mPlease execute this script on the machine which contains kubeconfig file!\033[0m"
echo -n "please enter the kubeconfig absolute path ->"
read KC

datename=$(date +%Y%m%d-%H%M%S)

step(){
echo -e "\033[47;30m$1\033[0m"
}

checkreturn(){
if [ $? -ne 0 ]; then
echo -e "`date +%H:%M:%S` \033[31mThe step failed and you need to get the cluster status back manually e.g switch back to previous user!!! \033[0m"
exit 1
fi
}

if [ ! -f ${KC} ];then
echo -e "`date +%H:%M:%S` \033[31mThe kubeconfig file doesn't exit \033[0m"
exit 1
fi

step "Step 1: check whether oc client exits"
which "oc" > /dev/null
if [ $? -eq 0 ]
then
echo -e "`date +%H:%M:%S` \033[32m oc command is exist \033[0m"
else
echo -e "`date +%H:%M:%S` \033[31m oc command not exist,you should install the oc client on master \033[0m"
exit 1
fi

step "Step 2: switch to cluster-admin user"
CC=`oc config current-context --config="${KC}"`
oc login -u system:admin --config="${KC}" > /dev/null
checkreturn


step "Step 3: config 4.0 oauthconfig"

#cluster_url="$(oc whoami --show-server | cut -f 2 -d ':' | cut -f 3 -d '/' | sed 's/-api././')"
cluster_url="$(oc whoami --show-server | cut -f 2 -d ':' | cut -f 3 -d '/' | sed 's/api.//')"
hostname="o.apps.${cluster_url}"


if [ "${#hostname}" -ge 63 ]; then
  echo "cluster url ${cluster_url} is too long to use with lets encrypt"
  exit 1
fi


oc apply -fhttps://raw.githubusercontent.com/tnozicka/openshift-acme/master/deploy/letsencrypt-live/single-namespace/{role,serviceaccount,imagestream,deployment}.yaml -n openshift-authentication
oc create rolebinding openshift-acme --role=openshift-acme --serviceaccount=openshift-authentication:openshift-acme -n openshift-authentication --dry-run -o yaml | oc auth reconcile -f -


oc apply -f - <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  annotations:
    kubernetes.io/tls-acme: "true"
  name: openshift-authentication
  namespace: openshift-authentication
spec:
  host: ${hostname}
  port:
    targetPort: 6443
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: reencrypt
  to:
    kind: Service
    name: openshift-authentication
    weight: 100
  wildcardPolicy: None
EOF


oc patch authentication.operator cluster --type=merge -p "{\"spec\":{\"managementState\": \"Managed\"}}"


until
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3
do
  echo "waiting for well-known"
  sleep 60
done


oc delete pods -n openshift-console --all --force --grace-period=0
oc delete pods -n openshift-monitoring --all --force --grace-period=0


oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: htpass-secret
  namespace: openshift-config
data:
  htpasswd: dGVzdDokYXByMSRqSGNNb0dmciRpSnl4bVNXb0VSbjhNcUZNUWF2clIwCnBtMTokYXByMSRCejdoLkQzbCQwSXVlSlplSngvYjM1VUg2TFBqNVcuCnBtMjokYXByMSRrcmZJSllQYiRObFIxaDVCYWxVVGpNSjlXOEVJcGEuCnBtMzokYXByMSRFUlgwMG44biRXRjQ2SjM4MU1jbWhOTGdBS3NqejUwCnBtNDokYXByMSRHaVpwR3NMZSRlWHVSYW9PY0lrOHNtMzRoRklwZWIwCnBtNTokYXByMSRUM0wzUlRnNyRRVmx3SnZCVzVZQjhWa1V5aTBRYnUuCnBtNjokYXByMSRZUlZDY25wRiRLc01ncU5LdkJpQU91ZXgzZDkxOC8wCmdlbGl1MTokYXByMSRMUjJpaEo3aiQ5czlaWFk0aTg2YW42NUtHSS4xcWYxCmdlbGl1MjokYXByMSR4U2JMUFA0MSRoc1d0amFGSTdQc3RpRHVHOFJWWU4wCmdlbGl1MzokYXByMSRGSzQzTU9ldSRodFlCN3h2VmR6M0l5VHRRemdoeFovCndlaGU6JGFwcjEkL0FBcjY2c2YkMnk0N09WVDcwc3RRUHlCU0xWa1NOMApjaGVoYW5nOiRhcHIxJFM5M1kzdVBTJG1Qb2J5emdjZGQ5czIyUnZRY0dsUC4KamlhemhhOiRhcHIxJFdpeVdRSnQ2JHRYVGtCUnpqaU56VXZhVlBYc256Yi8Keml0YW5nOiRhcHIxJGRheFdSb1VOJGgwTGtzaWZrU2ZsbUs2bHUxLklTaC4KamZhbjokYXByMSQxZDNTM2pFZiRudjAuNnFnSU1sZzU3amhBcjJlVnkvCmR5YW46JGFwcjEkS1U0UWl5bEskenNkeUpCTEprN0w1aUlTYjNUL1VtMQpjaGFveWFuZzokYXByMSRDSXdqaE1VciR6c3NyYklQNEJhVXByOTBZOGRiY0cuCmx4aWE6JGFwcjEkeDlwL0IwV0UkQlB1YjZ0OUMuR3F0clo1M2NFZWpTMQpzdG9yYWdlMTokYXByMSRQNFY3M3dxbSQ4cy8yUmRGdUdCUi5ZQUU1WldDZFAvCnN0b3JhZ2UyOiRhcHIxJHcubEh5d1VXJEFRQWt1ZVd6U25XSHMvY0RCY2RqejEKc3RvcmFnZTM6JGFwcjEkVXRrcDFCTngkQ0U2TXpzNjcwNjU5VGtySXZHV1hnLgpob25nbGk6JGFwcjEkLmdTTHRXbGgkQkVCY0tMcWV4Y0ZvcjRvN1cyb1daMApob25nbGkxOiRhcHIxJFJtOWZJUURMJFBpeUNJL3ZrdHBJeldTWkMwclExaTAKaG9uZ2xpMjokYXByMSRORlQyQW5uQiRGSXVJekY3dTBaTlN0c0Q2cGZNbFMwCnhpdXdhbmc6JGFwcjEkUS5GaGhMQXIkUVJoOWpxVTFaN0pqZGY2Qk0vQUVnLgp4aXV3YW5nMTokYXByMSRsWi9HTEZDVSRBV1VNekwwbFMzd3paakhXL2s2WmwuCnhpdXdhbmcyOiRhcHIxJEdVRUhSTS96JFpJMDcybU5paTJrZXNRVEpwVWMweTEKd21lbmc6JGFwcjEkSndPY2lWQTkkaGZaQ2FXNjYzMVM2N3l1UzV0Y0x1MAp3bWVuZzE6JGFwcjEkUndlQUNlcngkUTljRVF3RnZzWVJLTG5RVTJiaWJvMAp3bWVuZzI6JGFwcjEkYzBkRGRuS1IkemNhaDJ1VGlOZ3hDeDc1WGtmT0xMMAp3ZWlubGl1MTokYXByMSRSa2p3OWFaSCQ2QktaRGx2V1ZMTjZXQ0JrMTlYdGEvCndlaW5saXUyOiRhcHIxJHZrWFQ0aDkzJEloUTBxSFRvNkN1d0VNR09GaEQ4LjEKd2VpbmxpdTM6JGFwcjEkaWd6c0c3VUUkakxaOHp0WDhEMWtXN1dIVTBWM1JnLgpibWVuZzokYXByMSQxUTNJZDdENCQzckZGVmRoL0hJM1V5Z1FkdVhURXQuCmpob3U6JGFwcjEkSDhMdnlKelckeS9ra1FCdXo4cG4xQjkwSS55OWpzMQpqaG91MTokYXByMSRpNWsybDRuVCRBbjR5cmNyeDFGZmlZWUp5cjRRRU8wCnp6aGFvOiRhcHIxJHJMaHloSktqJDZPQUN3WUlpOS9ndUVtdC5BbWE3VTEKenpoYW8xOiRhcHIxJFlleGt1UHUwJGExQzU0RW1HdGZ3YzNYNEVrVW5VNDEKenpoYW8yOiRhcHIxJERrazFjNU5aJFpzQVNwUXlkWFA4aFZJbzhrNHhvYzAKd3N1bjokYXByMSRYQUFoQmRpUiRSeU56bm5DeEtCMWZPYmwxUTU0OTAwCmhhc2hhMTokYXByMSQ3d0c3YWk1RiR3MHFyeWt6YzVVdEZyZlB2dGlGQVIvCmhhc2hhMjokYXByMSRpSTNicUFkQSRKUlBsSGkveXJPUjI5QzJaTXV5L3MxCmhhc2hhMzokYXByMSRHR3FjcFdhcCRBbEdYMUxabXNKUlNOeGJaUW5KSk4wCnhpYW9jd2FuMTokYXByMSRsbFltei5ZYSQxQnduTmJOSXdUQ2ZRd1ZpUWN4MVcvCnhpYW9jd2FuMjokYXByMSQvQWpPMWF6OCQ5OHpSd3JiMnRPc1RMNkdLU1QyQUUvCnhpYW9jd2FuMzokYXByMSRuTzF2RjdiYyRRczgwZWJYbGlGaWljcksxckpRVkkvCmtha2ExOiRhcHIxJEhiVHNyYmhOJG56dlNJdC4yd0tLa0dsLjZGVFMwUy8Ka2FrYTI6JGFwcjEkLmdIYnpYV1MkZXhha3RSUEEzRnNHZlo1cER6ZmVTMQprYWthMzokYXByMSRleGc2dVZWLiR2V2JBQ1daTHVUMkxuYzdQMWhLM2YxCnpob3V5MTokYXByMSRrTjM3T2tDQiR1MS9ZV1pLN1NlSXZLZktqWTBmRHcuCnpob3V5MjokYXByMSRscHMxNVdwRyR0WDhUTUJaM2lDRFNSekxmbW45V00xCnpob3V5MzokYXByMSQuUVlVS3YxbyQxUzQwWmlMMmljNUtWU1NSS2o4YVExCnh4aWExOiRhcHIxJDlvNnU2RlRRJG12V2ZBYlMuc0ZhenpHbDRzZEt1VTAKeHhpYTI6JGFwcjEkd1M5VnJNelAkR1BXTmwuU21yN215TEViWHFVMkdNMAp4eGlhMzokYXByMSRleWVzQW84YiQzc01rdTlPaDdqbDdSVjVBZzBMb1UxCmFubGkxOiRhcHIxJEpPTy9BMW1mJHlENjFzWkZ5V3paRFp0RDlsRWw1VC8KYW5saTI6JGFwcjEkcFR2aFo1SGokZkRlTDZrbmtCZ1J6SHZiRHE1SkhaMQpxaXRhbmcxOiRhcHIxJHo1TXptSldTJE9pMllRS3JiVFJoaDRjUThNdUgyUi8KcWl0YW5nMjokYXByMSRWRm5mSlZ2YiRRSW5GVEh2LnZtNWRXTS9mS0I1aWovCmp1emhhbzE6JGFwcjEkN2phdzlYaUEkYWZrZ3ZMSzZiOTNYRFJSL0gxWlBmLgpqdXpoYW8yOiRhcHIxJGFlaXBZS1dSJFBNYXMyeTVpa0lYY2hwMmNXYmJnaC4KeWFwZWkxOiRhcHIxJEZsdi43c1dCJHdBOFpHNHRGM3NDdFl3N3ptNXhxSi8KeWFwZWkyOiRhcHIxJGVOTHpqRGdhJGl3Nk9KMk9MQTg5TXFMMjJmZkdHSy8KdWkxOiRhcHIxJDQ4eDRoQmxGJGNMbHNCT0EyVDFFRWthSjRnS2pyZzEKdWkyOiRhcHIxJHFaZU5hdEgvJC9vdUU2cHdseEoxcks4Q2x5ZmhBTzAKdWkzOiRhcHIxJEczQ0RKY1BZJE1EQi54M1VleFRrdVBLbG81d2pHVC8KcGlxaW46JGFwcjEkcElJc0RsZW4kZDk1LlIzaGkuRG5yZ2dvLmY4VS9LMApwaXFpbjE6JGFwcjEkUkh4bG9QS3ckNEd4VFZFTGxlRjZwSXF4ZnFkbC5xMQpwaXFpbjI6JGFwcjEkd0tqQmZESVQkSUVXMEtLM2dvd1prRHhERUlzdHIwLgp3ZXdhbmc6JGFwcjEkdVZLNFVVdU8kWjNLRFM4QjZaNkNldFlXQ29HRjFVLwp3ZXdhbmcxOiRhcHIxJDlHbjZ6aHpEJEMwRWU1UkNhNHVEL3hnTUptM1RlcjEKd2V3YW5nMjokYXByMSRpVXJQdTcwRyRDLk1vTmN2bEhJSVV3Z25lLk5TeVkvCnpoc3VuOiRhcHIxJG12ZnM1N1B3JG1oN3NRTWtYc20zVmZHcXE0RDRwUTEKbWlubWxpOiRhcHIxJHJJWW50c2NvJHFCMDFUTTNELzQ4YnJKRFlDQW92di4Kd3poZW5nOiRhcHIxJHd6d09sMGxYJDcvTGJNWWY4dldCL0dLck9ZSmZnei8Kd3poZW5nMTokYXByMSRvaW9PTC5ILiR1dnBvbHMvWUwwN2tiUHQ3UVZFamYvCg==
EOF


oc apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: htpassidp
    challenge: true
    login: true
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
EOF

sleep 30


step "Step 4: switch back to previous user"
oc config use-context ${CC} --config="${KC}"
checkreturn

echo -e "\033[32mAll Success\033[0m"
echo The accounts are you give chuyu before\;for someone doesnt have accounts\,I display 6 accounts for you\: pm{1,2,3,4,5,6}/redhat
