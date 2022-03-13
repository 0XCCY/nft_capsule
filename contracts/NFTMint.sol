//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract NFTMint is Ownable, ERC721, VRFConsumerBaseV2 {
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

    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _nftCounter;
    Counters.Counter private _capsuleCounter;

    // capsuleId to chance;
    mapping(string => uint256[]) public capsule2chance;
    mapping(string => string) public capsule2base;

    address admin = 0xCBC061bc5bD8793a1Dc737554331ddd075C7bA3F;

    struct RequestInfo{
        address owner;
        string capsuleId;
        uint256 tokenId;
    }

    mapping(uint256 => RequestInfo) public request2info;

    struct TokenInfo{
        string capsuleId;
        uint256 no;
    }

    mapping(uint256 => TokenInfo) public tokenID2result;


    mapping(string => mapping(uint256 => bool)) public usedClaim;

    mapping(string => mapping(uint256 => uint256)) public capcount2token;

    address s_owner;

    constructor(uint64 subscriptionId)
        ERC721("Capsule", "CAP")
        VRFConsumerBaseV2(vrfCoordinator)
    {

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;

        _nftCounter.increment();
        _capsuleCounter.increment();

        capsule2base["test"] = "QmVyf7nU2o6gLU6FGyAjN1uqWjJSxHqwJkDbjqk6omwmCP/metadata/";
        capsule2chance["test"] = [50,50];
    }

    function _draw(string memory _capId, uint256 _count) private onlyOwner returns(uint256){
        
        uint256 tokenId = _nftCounter.current();
        _nftCounter.increment();
        capcount2token[_capId][_count] = tokenId;

        requestRandom(msg.sender,_capId, tokenId);
        return tokenId;
    }

    function increaseGasLimit(uint32 gas) external onlyOwner {
        callbackGasLimit = gas;
    }

    function createCapsule(string memory _baseURI, uint256[] memory _chance, string memory _capID)
        external
        onlyOwner
    {
        
        capsule2base[_capID] = _baseURI;
        capsule2chance[_capID] = _chance;

        // _capsuleCounter.increment();
    }

        // Assumes the subscription is funded sufficiently.
    function requestRandom(
        address _owner,
        string memory _capsuleId,
        uint256 _tokenId
    ) private {
        // Will revert if subscription is not set and funded.

        //Excluded for testing environment
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        //uint256 requestId = psuedoRandomness();

        RequestInfo memory requestInfo;
        requestInfo.capsuleId = _capsuleId;
        requestInfo.owner = _owner;
        requestInfo.tokenId = _tokenId;

        request2info[requestId] = requestInfo; 

        //added for testing, remove in production
        // uint256[] memory seed = new uint256[](1);
        // seed[0] = psuedoRandomness();
        
        // fulfillRandomWords(requestId, seed);
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
        requestId = requestId;
        RequestInfo memory reqInfo = request2info[requestId];
        // string memory eventURI = capsule2base[reqInfo.capsuleId];
        uint256[] memory chance = capsule2chance[reqInfo.capsuleId];
        uint256 result = randomSeed[0].mod(100);
        uint256 j = 0;
        uint256 threshold = chance[j];
        TokenInfo memory tokeninfo;
        for(uint64 i=0;i<=100;i++){
            if(i==result){
                tokeninfo.capsuleId = reqInfo.capsuleId;
                tokeninfo.no = j;
                tokenID2result[reqInfo.tokenId] = tokeninfo;             
                break;
            }else{
                if(i>threshold){
                    j += 1;
                    threshold = threshold + chance[j];
                }
            }
        }
        _safeMint(reqInfo.owner, reqInfo.tokenId);
        
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        return  concatenate("ipfs//",capsule2base[tokenID2result[_tokenId].capsuleId] ,"/metadata/",Strings.toString(tokenID2result[_tokenId].no));
    }

    function concatenate(string memory a,string memory b,string memory c, string memory d) public pure returns (string memory){
        return string(abi.encodePacked(a,b,c,d));
    } 

    function splitSignature(bytes memory sig)
    internal
    pure
    returns (uint8, bytes32, bytes32)
{
    require(sig.length == 65);

    bytes32 r;
    bytes32 s;
    uint8 v;

    assembly {
        // first 32 bytes, after the length prefix
        r := mload(add(sig, 32))
        // second 32 bytes
        s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
        v := byte(0, mload(add(sig, 96)))
    }

    return (v, r, s);
}

// Builds a prefixed hash to mimic the behavior of eth_sign.
function prefixed(bytes32 hash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
}

function claimCoupon(string memory capsuleId, uint256 count, bytes memory sig) public{
    require(!usedClaim[capsuleId][count]);
    usedClaim[capsuleId][count] = true;


    // This recreates the message that was signed on the client.
    bytes32 message = prefixed(keccak256(abi.encodePacked(capsuleId, count, address(this))));


    address signer = recoverSigner(message, sig);
    console.log(signer);

    require(signer == admin);
    _draw(capsuleId,count);


    
}

function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
{
    uint8 v;
    bytes32 r;
    bytes32 s;

    (v, r, s) = splitSignature(sig);

    return ecrecover(message, v, r, s);
}
}