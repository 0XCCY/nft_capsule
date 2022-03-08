//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/// @title A contract that temporary stores NFTs used to create Capsules.
/// @author CY

contract NFTVault is Ownable, IERC721Receiver, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    uint64 s_subscriptionId;

    // Rinkeby coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

    // Rinkeby LINK token contract. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address link = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash =
        0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 1;

    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;

    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _nftCounter;
    Counters.Counter private _capCounter;
    Counters.Counter private _requestCounter;

    struct NFT {
        address tokenAddress;
        address owner;
        address winner;
        uint256 tokenId;
        uint256 capId;
    }

    struct Capsule {
        address owner;
        string name;
        uint256 capId;
        uint256 size;
        uint256 sold;
        uint256 price;
        bool active;
    }

    struct DrawResult {
        address owner;
        uint256 seed;
        uint256 requestId;
    }

    struct requestInfo {
        uint256 capsuleId;
        uint256 drawNo;
    }

    // nftId => NFT list in vault
    mapping(uint256 => NFT) public nftList;

    // tokenAddress => tokenId => nftId
    mapping(address => mapping(uint256 => uint256)) public token2nftId;

    // owner => nftId
    mapping(address => uint256[]) public ownedNFT;

    // capId => Capsule list
    mapping(uint256 => Capsule) public capsuleList;

    // capsuleId => nftId[]
    mapping(uint256 => uint256[]) public nftByCapsuleID;

    // capsuleId => drawNo => DrawResult
    mapping(uint256 => mapping(uint256 => DrawResult)) public capsuleDrawResult;

    // requestId => DrawResult
    mapping(uint256 => DrawResult) public requestId2Draw;

    // requestId => seed
    mapping(uint256 => uint256) public drawSeed;

    // requestId => requestInfo
    mapping(uint256 => requestInfo) public request2info;

    // owner => draws[]
    mapping(address => uint256[]) public drawOwner;

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        _nftCounter.increment();
        _capCounter.increment();
        _requestCounter.increment();

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;

        Capsule memory capsule;
        capsule.owner = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        capsule.name = "test";
        capsule.capId = 1;
        capsule.size = 5;
        capsule.sold = 0;
        capsule.price = 1;
        capsule.active = true;
        capsuleList[1] = capsule;

        NFT memory nft;
        nft.tokenAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.owner = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.tokenId = 0;
        nft.capId = 1;

        NFT memory nft2;
        nft.tokenAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.owner = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.tokenId = 1;
        nft.capId = 1;

        NFT memory nft3;
        nft.tokenAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.owner = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.tokenId = 2;
        nft.capId = 1;

        NFT memory nft4;
        nft.tokenAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.owner = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.tokenId = 2;
        nft.capId = 1;

        NFT memory nft5;
        nft.tokenAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.owner = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        nft.tokenId = 2;
        nft.capId = 1;

        nftList[1] = nft;
        nftList[2] = nft2;
        nftList[3] = nft3;
        nftList[4] = nft4;
        nftList[5] = nft5;

        nftByCapsuleID[1].push(1);
        nftByCapsuleID[1].push(2);
        nftByCapsuleID[1].push(3);
        nftByCapsuleID[1].push(4);
        nftByCapsuleID[1].push(5);
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandom(
        uint256 _capsuleId,
        uint256 _drawNo,
        address _owner
    ) private {
        // Will revert if subscription is not set and funded.

        // Excluded for testing environment
        // uint256 requestId = COORDINATOR.requestRandomWords(
        //     keyHash,
        //     s_subscriptionId,
        //     requestConfirmations,
        //     callbackGasLimit,
        //     numWords
        // );
        uint256 requestId = psuedoRandomness();
        capsuleDrawResult[_capsuleId][_drawNo].owner = _owner;
        capsuleDrawResult[_capsuleId][_drawNo].requestId = requestId;
        capsuleDrawResult[_capsuleId][_drawNo].seed = 0;
        request2info[requestId].capsuleId = _capsuleId;
        request2info[requestId].drawNo = _drawNo;
        drawOwner[_owner].push(_drawNo);

        uint256[] memory seed = new uint256[](1);
        seed[0] = psuedoRandomness();

        //added for testing, remove in production
        fulfillRandomWords(requestId, seed);
    }

    function psuedoRandomness() public view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp +
                            block.difficulty +
                            ((
                                uint256(
                                    keccak256(abi.encodePacked(block.coinbase))
                                )
                            ) / (block.timestamp)) +
                            block.gaslimit +
                            ((
                                uint256(
                                    keccak256(abi.encodePacked(_msgSender()))
                                )
                            ) / (block.timestamp)) +
                            block.number
                    )
                )
            );
    }

    function fulfillRandomWords(
        uint256 requestId, /* requestId */
        uint256[] memory randomSeed
    ) internal override {
        drawSeed[requestId] = randomSeed[0];
        uint256 capId = request2info[requestId].capsuleId;
        uint256 drawNo = request2info[requestId].drawNo;
        capsuleDrawResult[capId][drawNo].seed = randomSeed[0];
    }

    function getRandomResult(uint256 _requestId)
        external
        view
        returns (uint256[] memory)
    {
        uint256 requestNumber = s_requestIdToRequestIndex[_requestId];
        return s_requestIndexToRandomWords[requestNumber];
    }

    function depositNFT(address _tokenAddress, uint256 _tokenId)
        external
        returns (uint256)
    {
        IERC721(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        NFT memory nft;
        uint256 nftId;

        nft.tokenAddress = _tokenAddress;
        nft.tokenId = _tokenId;
        nft.owner = msg.sender;
        nft.winner = address(0);
        nft.capId = 0;

        if (token2nftId[_tokenAddress][_tokenId] > 0) {
            nftId = token2nftId[_tokenAddress][_tokenId];
        } else {
            nftId = _nftCounter.current();
            token2nftId[_tokenAddress][_tokenId] = nftId;
            _nftCounter.increment();
        }

        nftList[nftId] = nft;
        ownedNFT[msg.sender].push(nftId);
        return nftId;
    }

    function addToCapsule(uint256 _nftId, uint256 _capId) external {
        require(
            nftList[_nftId].owner == msg.sender,
            "Only NFT owner can add to capsule."
        );

        Capsule storage capsule = capsuleList[_capId];

        require(
            capsule.owner == msg.sender,
            "Only Capsule owner can add NFTs."
        );

        require(
            nftList[_nftId].capId == 0,
            "NFT is already in another Capsule."
        );

        nftList[_nftId].capId = _capId;
        nftByCapsuleID[_capId].push(_nftId);

        capsule.size = capsule.size.add(1);

        console.log(
            "The capsule now contains this NFT:",
            nftByCapsuleID[_capId][nftByCapsuleID[_capId].length - 1]
        );
    }

    function removeFromCapsule(uint256 _capId, uint256 _nftId) external {
        require(
            nftList[_nftId].owner == msg.sender,
            "Only NFT owner can add to capsule."
        );

        Capsule storage capsule = capsuleList[_capId];

        require(
            capsule.owner == msg.sender,
            "Only Capsule owner can add NFTs."
        );

        require(nftList[_nftId].capId > 0, "NFT is not in any Capsule.");

        require(
            capsule.active == false,
            "This Capsule is On Sale and cannot be changed!"
        );

        nftList[_nftId].capId = 0;

        nftByCapsuleID[_capId][_nftId] = nftByCapsuleID[_capId][
            nftByCapsuleID[_capId].length.sub(1)
        ];
        nftByCapsuleID[_capId].pop();

        capsule.size = capsule.size.sub(1);
    }

    function getNFTinCapsule(uint256 _capId)
        external
        view
        returns (uint256[] memory)
    {
        return nftByCapsuleID[_capId];
    }

    function createCapsule(string calldata _name, uint256 _price) external {
        Capsule memory capsule;
        capsule.owner = msg.sender;
        capsule.name = _name;
        capsule.capId = _capCounter.current();
        capsule.active = false;
        capsule.price = _price.mul(1e18);
        capsule.size = 0;
        capsule.sold = 0;
        capsuleList[_capCounter.current()] = capsule;

        _capCounter.increment();

        console.log(
            "Capsule created with name: ",
            capsule.name,
            " price: ",
            capsule.price
        );
    }

    function startCapsule(uint256 _capId) external {
        require(
            capsuleList[_capId].owner == msg.sender,
            "Only Capsule owner can start the sale."
        );
        capsuleList[_capId].active = true;
    }

    function drawCapsule(uint256 _capId) external {
        Capsule storage capsule = capsuleList[_capId];
        require(capsule.active == true, "Capsule sale has not started yet!");

        require(capsule.sold < capsule.size, "Ops, ran out of capsules.");

        requestRandom(_capId, capsule.sold.add(1), msg.sender);

        capsule.sold = capsule.sold.add(1);
    }

    function getWinInCollectionByOwner(uint256 _capId, address _owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256[] memory drawsToCheck = drawOwner[_owner];
        uint256 lastIndex = drawsToCheck[drawsToCheck.length.sub(1)].add(1);
        uint256[] memory allNftinCollection = nftByCapsuleID[_capId];
        uint256 remaining = allNftinCollection.length;
        uint256[] memory wins = new uint256[](drawsToCheck.length);

        uint256 loop = 0;
        uint256 checks = 0;
        uint256 winNFT;
        uint256 seed;

        for (uint256 i = 1; i < lastIndex; i++) {
            seed = capsuleDrawResult[_capId][i].seed;
            if (remaining == 1) {
                wins[checks] = allNftinCollection[0];
                break;
            } else if (seed > 0) {
                uint256 randomRange = remaining.sub(1);
                uint256 _win = seed.mod(randomRange);
                winNFT = allNftinCollection[_win];

                if (_win == randomRange) {
                    remaining = remaining.sub(1);
                } else {
                    for (uint256 j = _win; j < randomRange; j++) {
                        allNftinCollection[j] = allNftinCollection[j + 1];
                    }
                    remaining = remaining.sub(1);
                }

                if (i == drawsToCheck[checks]) {
                    wins[checks] = winNFT;
                    checks = checks.add(1);
                }
            } else {
                break;
            }
            loop = loop.add(1);
        }

        //require(loop == lastIndex, "Draw Result not ready yet!");

        return wins;
    }

    function getWinnerInCollection(uint256 _capId) public {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
