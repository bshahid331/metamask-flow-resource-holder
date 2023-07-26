import MetadataViews from "../contracts/MetadataViews.cdc"
import ExampleNFT from "../contracts/ExampleNFT.cdc"
import ResourceHolder from "../contracts/ResourceHolder.cdc"

transaction(nftId: UInt64, ethAddress: String) {

    let withdrawRef: &ExampleNFT.Collection

    prepare(acct: AuthAccount) {
         self.withdrawRef = acct
            .borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath)
            ?? panic("Account does not store an object at the specified path")
    }

    execute {
         let nft <- self.withdrawRef.withdraw(withdrawID: nftId)
         let displayView = nft.resolveView(Type<MetadataViews.Display>()) as! MetadataViews.Display?

         ResourceHolder.deposit(claimerETHAddress: ethAddress, resource: <-nft, display: displayView)
    }

}