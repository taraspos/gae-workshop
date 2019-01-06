# https://coreos.com/os/docs/latest/generate-self-signed-certificates.html
mkdir cfssl
cd cfssl

EXPIRY=${EXPIRY:=43800h}
if [ -z "$SERVER_IP" ]
then
      echo "Please set SERVER_IP variable"
      exit 1
fi


echo "Setting certificate expiration to $EXPIRY"

echo '{"CN":"CA","key":{"algo":"rsa","size":2048}}' | cfssl gencert -initca - | cfssljson -bare ca -
echo '{"signing":{"default":{"expiry":"'$EXPIRY'","usages":["signing","key encipherment","server auth","client auth"]}}}' > ca-config.json
export ADDRESS=$SERVER_IP,127.0.0.1
export NAME=server
echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -config=ca-config.json -ca=ca.pem -ca-key=ca-key.pem -hostname="$ADDRESS" - | cfssljson -bare $NAME
export ADDRESS=
export NAME=client
echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -config=ca-config.json -ca=ca.pem -ca-key=ca-key.pem -hostname="$ADDRESS" - | cfssljson -bare $NAME