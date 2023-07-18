import ResourceHolder from "../contracts/ResourceHolder.cdc"

pub fun main(ethAddress: String): [UInt64] {
    return ResourceHolder.getItemIDsForETHAddress(claimerETHAddress : ethAddress)
}