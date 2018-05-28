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
CHAINCODE_NAME="$2"
CHAINCODE_VERSION=$3
: ${CHANNEL_NAME:="tfichannel"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/local/orderers/dev-orderer.local/msp/tlscacerts/tlsca.local-cert.pem

echo "Channel name : "$CHANNEL_NAME
echo "Chaincode name: "$CHAINCODE_NAME
echo "Chaincode version: "$CHAINCODE_VERSION

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


installChaincode () {
	PEER=$1
	setGlobals $PEER
	peer chaincode install -n $CHAINCODE_NAME -v $CHAINCODE_VERSION -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02 >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}

instantiateChaincode () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	peer chaincode instantiate -o dev-orderer.local:7050 --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('OrgTFIMSP.peer','OrgOpenskyMSP.peer','OrgCandyMSP.peer')" >&log.txt
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

echo "Installing chaincode on OrgTFI..."
installChaincode 0
echo "Install chaincode on OrgOpensky..."
installChaincode 1
echo "Install chaincode on OrgCandy..."
installChaincode 2


echo "Instantiating chaincode on org candy..."
instantiateChaincode 2