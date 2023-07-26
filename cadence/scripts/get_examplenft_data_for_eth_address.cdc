import ResourceHolder from "../contracts/ResourceHolder.cdc"

pub fun main(ethAddress: String, itemId: UInt64): AnyStruct {
    let display = ResourceHolder.getItemNFTDisplay(claimerETHAddress: ethAddress, itemId: itemId)
    return display
}