import path from "path"
import {
  init,
  emulator,
  executeScript,
  sendTransaction,
  getAccountAddress,
  deployContractByName
} from "@onflow/flow-js-testing"

describe("MetaMask Integration Test Suite", () => {

  beforeEach(async () => {
    const basePath = path.resolve(__dirname, '../');
    await init(basePath);
    await emulator.start(false);
    return new Promise((resolve) => setTimeout(resolve, 1000));
  });

  // Stop emulator, so it could be restarted
  afterEach(async () => {
    await emulator.stop();
    return new Promise((resolve) => setTimeout(resolve, 1000));
  });

  test("ExampleNFT Test Suite", async () => {
    const admin = await getAccountAddress("Admin");
    await deployContractByName({ to: admin, name: "NonFungibleToken" });
    await deployContractByName({ to: admin, name: "MetadataViews" });
    await deployContractByName({ to: admin, name: "ViewResolver" });

    let [result, error] = await deployContractByName({ to: admin, name: "ExampleNFT" });
    expect(error).toBe(null);

    const nftHolderOne = await getAccountAddress("NFTHolderOne");
    [result, error] = await sendTransaction({ name: "init_examplenft_collection", signers: [nftHolderOne] })
    expect(error).toBe(null);

    [result, error] = await sendTransaction({ name: "mint_examplenft", args: [nftHolderOne], signers: [admin] })
    expect(error).toBe(null);

    [result, error] = await executeScript({ name: "get_examplenft_metadata", args: [nftHolderOne, "0"] });
    expect(result.name).toBe("Example NFT #0");
    expect(error).toBe(null);

    [result, error] = await executeScript({ name: "get_examplenft_metadata", args: [admin, "0"] });
    expect(error).not.toBe(null);
  })

  test("ResourceHolder Test Suite", async () => {
    const admin = await getAccountAddress("Admin");
    
    await deployContractByName({ to: admin, name: "NonFungibleToken" });
    await deployContractByName({ to: admin, name: "MetadataViews" });
    await deployContractByName({ to: admin, name: "ViewResolver" });
    await deployContractByName({ to: admin, name: "ExampleNFT" });
    
    let [result, error] = await deployContractByName({ to: admin, name: "ResourceHolder" });
    expect(error).toBe(null);

    const nftHolderOne = await getAccountAddress("NFTHolderOne");
    await sendTransaction({ name: "init_examplenft_collection", signers: [nftHolderOne] });
    await sendTransaction({ name: "mint_examplenft", args: [nftHolderOne], signers: [admin] });

    [result, error] = await sendTransaction({ name: "mint_examplenft", args: [nftHolderOne], signers: [admin] });
    expect(error).toBe(null);

    const TEST_ETH_ADDRESS = "0x97514895ee81704cb2cc6f08d65a90a420e9ff20";

    [result, error] = await sendTransaction({ name: "send_examplenft_to_eth_address", args: ["0",TEST_ETH_ADDRESS], signers: [nftHolderOne] });
    expect(error).toBe(null);

    [result, error] = await executeScript({ name: "get_item_ids_for_eth_address", args: [TEST_ETH_ADDRESS] });
    expect(result.length).toBe(1)
    expect(error).toBe(null);

    const ethWalletsFlowAccount = await getAccountAddress("ETHUser");

    [result, error] = await sendTransaction({ name: "claim_nft_from_eth_address", args: ["invalidPublicKey", "invalidSig", TEST_ETH_ADDRESS, result[0], "99999999999999"], signers: [ethWalletsFlowAccount] });
    expect(result).toBe(null);
    expect(error).not.toBe(null);
  })
})