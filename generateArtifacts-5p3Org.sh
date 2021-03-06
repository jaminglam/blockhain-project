#!/bin/bash +x
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#


#set -e

CHANNEL_NAME=$1
: ${CHANNEL_NAME:="tfichannel"}
echo $CHANNEL_NAME

export FABRIC_ROOT=$PWD/../..
export FABRIC_CFG_PATH=$PWD
echo

OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

## Using docker-compose template replace private key file names with constants
# function replacePrivateKey () {
#     ARCH=`uname -s | grep Darwin`
#     if [ "$ARCH" == "Darwin" ]; then
#         OPTS="-it"
#     else
#         OPTS="-i"
#     fi

# ##    cp docker-compose-e2e-template.yaml docker-compose-e2e.yaml

#     CURRENT_DIR=$PWD
#     cd crypto-config/peerOrganizations/org1.lychee.com/ca/
#     PRIV_KEY=$(ls *_sk)
#     cd $CURRENT_DIR
#     sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
#     cd crypto-config/peerOrganizations/org2.lychee.com/ca/
#     PRIV_KEY=$(ls *_sk)
#     cd $CURRENT_DIR
#     sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
# }

# Generates Org certs using cryptogen tool
function generateCerts (){
    CRYPTOGEN=$FABRIC_ROOT/release/$OS_ARCH/bin/cryptogen

    if [ -f "$CRYPTOGEN" ]; then
            echo "Using cryptogen -> $CRYPTOGEN"
    else
        echo "Building cryptogen"
        make -C $FABRIC_ROOT release
    fi

    echo
    echo "##########################################################"
    echo "##### Generate certificates using cryptogen tool #########"
    echo "##########################################################"
    $CRYPTOGEN generate --config=./crypto-config-5p3org.yaml
    echo
}

## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function generateChannelArtifacts() {
	CONFIGTXGEN=/home/bcdev/bin/configtxgen
    #CONFIGTXGEN=$FABRIC_ROOT/release/$OS_ARCH/bin/configtxgen
    # if [ -f "$CONFIGTXGEN" ]; then
    #         echo "Using configtxgen -> $CONFIGTXGEN"
    # else
    #     echo "Building configtxgen"
    #     make -C $FABRIC_ROOT release
    # fi

    echo "##########################################################"
    echo "#########  Generating Orderer Genesis block ##############"
    echo "##########################################################"
    # Note: For some unknown reason (at least for now) the block file can't be
    # named orderer.genesis.block or the orderer will fail to launch!
    #$CONFIGTXGEN -profile TwoOrgsOrdererGenesis2 -outputBlock ./channel-artifacts/genesis.block
    $CONFIGTXGEN -profile TFIOrdererGenesis -outputBlock ./channel-artifacts/genesis.block
    echo
    echo "#################################################################"
    echo "### Generating channel configuration transaction 'channel.tx' ###"
    echo "#################################################################"
    TXNAME="$CHANNEL_NAME".tx
    $CONFIGTXGEN -profile TFIChannel -outputCreateChannelTx ./channel-artifacts/$TXNAME -channelID $CHANNEL_NAME

    echo
    echo "#################################################################"
    echo "#######    Generating anchor peer update for OrgTFI   ##########"
    echo "#################################################################"
    $CONFIGTXGEN -profile TFIChannel -outputAnchorPeersUpdate ./channel-artifacts/OrgTFIMSPanchors.tx -channelID $CHANNEL_NAME -asOrg OrgTFI

    echo
    echo "#################################################################"
    echo "#######    Generating anchor peer update for OrgOpensky   ##########"
    echo "#################################################################"
    $CONFIGTXGEN -profile TFIChannel -outputAnchorPeersUpdate ./channel-artifacts/OrgOpenskyMSPanchors.tx -channelID $CHANNEL_NAME -asOrg OrgOpensky
    echo


    echo
    echo "#################################################################"
    echo "#######    Generating anchor peer update for OrgCandy   ##########"
    echo "#################################################################"
    $CONFIGTXGEN -profile TFIChannel -outputAnchorPeersUpdate ./channel-artifacts/OrgCandyMSPanchors.tx -channelID $CHANNEL_NAME -asOrg OrgCandy
    echo
}

#generateCerts
#replacePrivateKey
generateChannelArtifacts

