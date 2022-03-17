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

/// @title A ERC721 compliant contract that allows user to draw NFTs with coupons.
/// @author CY
/// @dev Encapsulation of data is still needed, most data and functions are exposed as Public for testing purposes.
/// @custom:alpha This is an alpha release
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

    // Ultlities for counters and math
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _nftCounter;
    Counters.Counter private _capsuleCounter;

    // capsuleId to chance;
    mapping(string => uint256[]) public capsule2chance;

    // capsuleId to baseURI;
    mapping(string => string) public capsule2base;

    // Admin address used to generate coupon and sign message.
    address admin = 0xCBC061bc5bD8793a1Dc737554331ddd075C7bA3F;

    // Stores request info to be used after receiving the random seed.
    struct RequestInfo {
        address owner;
        string capsuleId;
        uint256 tokenId;
    }

    // Request Id to Request Info
    mapping(uint256 => RequestInfo) public request2info;

    // Stores info about token for each capsule.
    struct TokenInfo {
        string capsuleId;
        uint256 no;
    }

    // Mapping tokenID of Smart contract to Capsule and the draw number.
    mapping(uint256 => TokenInfo) public tokenID2result;

    // Stores information of used coupon to prevent double claim.
    mapping(string => mapping(uint256 => bool)) public usedClaim;

    // Mapping of Capsule and the draw number to token ID
    mapping(string => mapping(uint256 => uint256)) public capcount2token;

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

        capsule2base[
            "test"
        ] = "QmVyf7nU2o6gLU6FGyAjN1uqWjJSxHqwJkDbjqk6omwmCP/metadata/";
        capsule2chance["test"] = [50, 50];
    }

    /// @notice Draw your NFT!
    /// @dev Do not call this directly, do the coupon ID check first!
    /// @param _capId Capsule ID
    /// @param _count The draw number (incremental)
    /// @return tokenId The NFT Token ID
    function _draw(string memory _capId, uint256 _count)
        private
        onlyOwner
        returns (uint256)
    {
        uint256 tokenId = _nftCounter.current();
        _nftCounter.increment();
        capcount2token[_capId][_count] = tokenId;

        requestRandom(msg.sender, _capId, tokenId);
        return tokenId;
    }

    /// @dev Use this to adjust Chain Link VRF callback gas limit to prevent over/under spend - safe gas limit around 200000 for this contract.
    /// @param gas amount of gas in wei
    function increaseGasLimit(uint32 gas) external onlyOwner {
        callbackGasLimit = gas;
    }

    /// @dev Use this to create a capsule from backend.
    /// @param _baseURI the token baseURI (One for each capsule).
    /// @param _chance the array of chance for each token, e.g. [10,10,20,20,40].
    /// @param _capID the capsule ID to create, must match with backend.
    function createCapsule(
        string memory _baseURI,
        uint256[] memory _chance,
        string memory _capID
    ) external onlyOwner {
        capsule2base[_capID] = _baseURI;
        capsule2chance[_capID] = _chance;
    }

    /// @dev Custom function to request for random seed from Chainlink's VRF
    /// @param _owner the owner of the capsule.
    /// @param _capsuleId the capsule Id to draw from.
    /// @param _tokenId the NFT tokenId to bind the result to
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

        // Save data to request info so that the result can be bounded to the corresponding request Id and token Id.
        RequestInfo memory requestInfo;
        requestInfo.capsuleId = _capsuleId;
        requestInfo.owner = _owner;
        requestInfo.tokenId = _tokenId;

        request2info[requestId] = requestInfo;
    }

    /// @dev This is for generating randomness during testing.
    /// @return not_so_random_seed a predictable random seed only for testing!
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

    /// @dev This is called by VRF Coorindator to return the result of randomess.
    /// @param requestId The request ID.
    /// @param randomSeed The random seed array.
    function fulfillRandomWords(
        uint256 requestId, /* requestId */
        uint256[] memory randomSeed
    ) internal override {
        requestId = requestId;
        RequestInfo memory reqInfo = request2info[requestId];
        uint256[] memory chance = capsule2chance[reqInfo.capsuleId];
        uint256 result = randomSeed[0].mod(100);
        uint256 j = 0;
        uint256 threshold = chance[j];
        TokenInfo memory tokeninfo;

        // Lookup chance array of capsule for the prize from the random seed.
        for (uint64 i = 0; i <= 100; i++) {
            if (i == result) {
                tokeninfo.capsuleId = reqInfo.capsuleId;
                tokeninfo.no = j;
                tokenID2result[reqInfo.tokenId] = tokeninfo;
                break;
            } else {
                if (i > threshold) {
                    j += 1;
                    threshold = threshold + chance[j];
                }
            }
        }
        _safeMint(reqInfo.owner, reqInfo.tokenId);
    }

    /// @notice returns the metadata URI of the tokenId
    /// @param _tokenId tokenId to lookup
    /// @return tokenURI the URI for the metadata of the tokenId
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return
            concatenate(
                "ipfs//",
                capsule2base[tokenID2result[_tokenId].capsuleId],
                "/metadata/",
                Strings.toString(tokenID2result[_tokenId].no)
            );
    }

    /// @dev ultility function to join strings for metadata URI
    function concatenate(
        string memory a,
        string memory b,
        string memory c,
        string memory d
    ) pure prviate returns (string memory) {
        return string(abi.encodePacked(a, b, c, d));
    }

    /// @dev split signature of signed message into r, s, v that is used to recover the signing address
    /// @param sig the signature to split
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
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

    /// @dev adds the prefix for non-transaction message signed.
    /// @param hash the hash of the rebuilt message
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    /// @notice claim your coupon here with the capsuleId, count and signature.
    /// @dev to simplify things, the user only knows the coupon Id that points to the specific capsuleId, count and signature.
    /// @param capsuleId the capsule Id that the coupon is signed.
    /// @param count the number of draw of that capsule Id.
    /// @param sig the signature of the signed message.
    function claimCoupon(
        string memory capsuleId,
        uint256 count,
        bytes memory sig
    ) public {
        // Check if claimed
        require(!usedClaim[capsuleId][count]);
        // Set to claimed
        usedClaim[capsuleId][count] = true;

        // This recreates the message that was signed on the client.
        bytes32 message = prefixed(
            keccak256(abi.encodePacked(capsuleId, count, address(this)))
        );

        address signer = recoverSigner(message, sig);
        console.log(signer);

        require(signer == admin);
        _draw(capsuleId, count);
    }

    /// @dev encapsulate the ecrecover function and split signature
    /// @param message the prefixed message built from capsule Id, draw number and this contract address
    /// @param sig the signature of the message
    /// @return signer the address of the one who signs the message
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
