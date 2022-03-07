const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const simpleNFTFactory = await hre.ethers.getContractFactory("simpleNFT");
  const simpleNFT = await simpleNFTFactory.deploy();

  await simpleNFT.deployed();

  console.log("simpleNFT deployed to:", simpleNFT.address);

  let txn = await simpleNFT.simpleMint();

  txn = await simpleNFT.simpleMint();
  txn = await simpleNFT.simpleMint();
  txn = await simpleNFT.simpleMint();
  txn = await simpleNFT.simpleMint();

  const NFTVaultFactory = await hre.ethers.getContractFactory("NFTVault");
  const NFTVault = await NFTVaultFactory.deploy(process.env.CL_SUBSCRPTION_ID);

  await NFTVault.deployed();

  console.log("NFTVault deployed to:", NFTVault.address);
  txn = await NFTVault.requestRandomWords();

  // txn = await simpleNFT.setApprovalForAll(NFTVault.address, true);

  // txn = await NFTVault.depositNFT(simpleNFT.address, 0);
  // txn = await NFTVault.depositNFT(simpleNFT.address, 1);
  // txn = await NFTVault.depositNFT(simpleNFT.address, 2);
  // txn = await NFTVault.depositNFT(simpleNFT.address, 3);

  // let x = await NFTVault.ownedNFT("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", 1);
  // console.log(x);

  // txn = await NFTVault.createCapsule("The best Capsule ever!", 10);
  // txn = await NFTVault.addToCapsule(1, 1);
  // txn = await NFTVault.addToCapsule(2, 1);
  // txn = await NFTVault.addToCapsule(3, 1);


  // console.log(await NFTVault.callStatic.getNFTinCapsule(1));

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });