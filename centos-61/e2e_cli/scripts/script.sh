#!/bin/bash
# Copyright London Stock Exchange Group All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
echo
echo " ____    _____      _      ____    _____           _____   ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|         | ____| |___ \  | ____|"
echo "\___ \    | |     / _ \   | |_) |   | |    _____  |  _|     __) | |  _|  "
echo " ___) |   | |    / ___ \  |  _ <    | |   |_____| | |___   / __/  | |___ "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|           |_____| |_____| |_____|"
echo

CHANNEL_NAME="$1"
: ${CHANNEL_NAME:="tfichannel"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/local/orderers/dev-orderer.local/msp/tlscacerts/tlsca.local-cert.pem

echo "Channel name : "$CHANNEL_NAME
CHANNEL_TX_FILE="$CHANNEL_NAME".tx
echo "Channel Tx file name: " $CHANNEL_TX_FILE
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
		echo
   		exit 1
	fi
}

setGlobals () {

	if [ $1 -eq 0 ] ; then
		CORE_PEER_LOCALMSPID="OrgTFIMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/orgtfi.local/peers/dev-peer0.orgtfi.local/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/orgtfi.local/users/Admin@orgtfi.local/msp
		# if [ $1 -eq 0 ]; then
		CORE_PEER_ADDRESS=dev-peer0.orgtfi.local:7051
		#else
		#	CORE_PEER_ADDRESS=peer1.org1.lychee.com:7051
		#fi
	elif [ $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="OrgOpenskyMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/orgopensky.local/peers/dev-peer0.orgopensky.local/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/orgopensky.local/users/Admin@orgopensky.local/msp
		# if [ $1 -eq 2 ]; then
		CORE_PEER_ADDRESS=dev-peer0.orgopensky.local:7051
		# else
		# 	CORE_PEER_ADDRESS=peer1.org2.lychee.com:7051
		# fi
	else
		CORE_PEER_LOCALMSPID="OrgCandyMSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/orgcandy.local/peers/dev-peer2.orgcandy.local/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/orgcandy.local/users/Admin@orgcandy.local/msp
		# if [ $1 -eq 2 ]; then
		CORE_PEER_ADDRESS=dev-peer2.orgcandy.local:7051
	fi

	env |grep CORE
}

createChannel() {
	setGlobals 0

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o dev-orderer.local:7050 -c $CHANNEL_NAME -f ./channel-artifacts/$CHANNEL_TX_FILE >&log.txt
	else
		peer channel create -o dev-orderer.local:7050 -c $CHANNEL_NAME -f ./channel-artifacts/$CHANNEL_TX_FILE --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

updateAnchorPeers() {
    PEER=$1
    setGlobals $PEER

    if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update -o dev-orderer.local:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	else
		peer channel update -o dev-orderer.local:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	sleep 5
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep 2
		joinWithRetry $1
	else
		COUNTER=1
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	for ch in 0 1 2; do
		setGlobals $ch
		joinWithRetry $ch
		echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep 2
		echo
	done
}

# installChaincode () {
# 	PEER=$1
# 	setGlobals $PEER
# 	peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric/tfi/chaincode/go/chaincode_lychee02 >&log.txt
# 	res=$?
# 	cat log.txt
#         verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
# 	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
# 	echo
# }

# instantiateChaincode () {
# 	PEER=$1
# 	setGlobals $PEER
# 	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
# 	# lets supply it directly as we know it using the "-o" option
# 	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
# 		peer chaincode instantiate -o orderer2.lychee.com:7050 -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('Org1MSP.member','Org2MSP.member')" >&log.txt
# 	else
# 		peer chaincode instantiate -o orderer2.lychee.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('Org1MSP.member','Org2MSP.member')" >&log.txt
# 	fi
# 	res=$?
# 	cat log.txt
# 	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
# 	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
# 	echo
# }

# chaincodeQuery () {
#   PEER=$1
#   echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
#   setGlobals $PEER
#   local rc=1
#   local starttime=$(date +%s)

#   # continue to poll
#   # we either get a successful response, or reach TIMEOUT
#   while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
#   do
#      sleep 3
#      echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
#      peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >&log.txt
#      test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
#      test "$VALUE" = "$2" && let rc=0
#   done
#   echo
#   cat log.txt
#   if test $rc -eq 0 ; then
# 	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
#   else
# 	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
#         echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
# 	echo
# 	exit 1
#   fi
# }

# chaincodeInvoke () {
# 	PEER=$1
# 	setGlobals $PEER
# 	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
# 	# lets supply it directly as we know it using the "-o" option
# 	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
# 		peer chaincode invoke -o orderer2.lychee.com:7050 -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
# 	else
# 		peer chaincode invoke -o orderer2.lychee.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
# 	fi
# 	res=$?
# 	cat log.txt
# 	verifyResult $res "Invoke execution on PEER$PEER failed "
# 	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
# 	echo
# }

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org tfi..."
updateAnchorPeers 0
echo "Updating anchor peers for org opensky..."
updateAnchorPeers 1
echo "Updating anchor peers for org candy..."
updateAnchorPeers 2

## Install chaincode on Peer0/Org1 and Peer2/Org2
# echo "Installing chaincode on org1/peer0..."
# installChaincode 0
# echo "Install chaincode on org2/peer2..."
# installChaincode 2

#Instantiate chaincode on Peer2/Org2
# echo "Instantiating chaincode on org2/peer2..."
# instantiateChaincode 2

#Query on chaincode on Peer0/Org1
# echo "Querying chaincode on org1/peer0..."
# chaincodeQuery 0 100

#Invoke on chaincode on Peer0/Org1
# echo "Sending invoke transaction on org1/peer0..."
# chaincodeInvoke 0

## Install chaincode on Peer3/Org2
# echo "Installing chaincode on org2/peer3..."
# installChaincode 3

#Query on chaincode on Peer3/Org2, check if the result is 90
# echo "Querying chaincode on org2/peer3..."
# chaincodeQuery 3 90

echo
echo "===================== All GOOD, End-2-End execution completed ===================== "
echo

echo
echo " _____   _   _   ____            _____   ____    _____ "
echo "| ____| | \ | | |  _ \          | ____| |___ \  | ____|"
echo "|  _|   |  \| | | | | |  _____  |  _|     __) | |  _|  "
echo "| |___  | |\  | | |_| | |_____| | |___   / __/  | |___ "
echo "|_____| |_| \_| |____/          |_____| |_____| |_____|"
echo

exit 0
