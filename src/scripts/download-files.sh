: "${NAMESPACE:=default}"
if [ $# -eq 2 ]; then
    echo "Missing arguments"
    echo "format ./download.sh <image> <dest-dir>  <source-pvc>"
    echo "example ./download.sh 192.168.0.99/alpine-rsync ./distro  haiti-distro-pvc"
    exit 1
fi
name=pvc-mounter
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Pod
metadata:
  name: $name
  labels:
    app: $name
spec:
  volumes:
      - name: $3
        persistentVolumeClaim:
          claimName: $3
  containers:
  - image: $1
    command:
      - "sleep"
      - "604800"
    volumeMounts:
        - name: $3
          mountPath: /$3
    imagePullPolicy: IfNotPresent
    name: $name
  restartPolicy: Always
EOF

DIR="$(cd "$(dirname "$0")" && pwd)"
POD_NAME=$(kubectl get pod -l app=$name -o jsonpath="{.items[0].metadata.name}" -n $NAMESPACE)
kubectl wait --for=condition=ready --timeout=60s pod $POD_NAME -n $NAMESPACE
n=0
until [ "$n" -ge 5 ]
do
   $DIR/krsync -av --progress --stats $POD_NAME@$NAMESPACE:/$3/ $2 && break  # substitute your command here
   n=$((n+1)) 
   sleep 15
done
kubectl delete pod $POD_NAME --grace-period=0 --force -n $NAMESPACE