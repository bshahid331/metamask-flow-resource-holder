import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"
import ExampleNFT from "../contracts/ExampleNFT.cdc"
import ResourceHolder from "../contracts/ResourceHolder.cdc"

transaction(publicKey: String, signature: String, ethAddress: String, itemId: UInt64, expiration: UInt64) {
    let receiver: Capability<&{NonFungibleToken.CollectionPublic}>
    
    prepare(acct: AuthAccount) {
        if acct.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) == nil {
            // Create a new empty collection
            let collection <- ExampleNFT.createEmptyCollection()

            // save it to the account
            acct.save(<-collection, to: ExampleNFT.CollectionStoragePath)

            // create a public capability for the collection
            acct.link<&{NonFungibleToken.CollectionPublic, ExampleNFT.ExampleNFTCollectionPublic, MetadataViews.ResolverCollection}>(
                ExampleNFT.CollectionPublicPath,
                target: ExampleNFT.CollectionStoragePath
            )
        }
        self.receiver = acct.getCapability<&AnyResource{NonFungibleToken.CollectionPublic}>(ExampleNFT.CollectionPublicPath)
        assert(self.receiver.check(), message: "receiver not configured correctly!")
    }

    execute {
        let data =  ResourceHolder.SignedData(claimerETHAddress: ethAddress, destination: self.receiver.address, itemId: itemId, expiration: expiration)
         ResourceHolder.claim(receiver: self.receiver, publicKey: publicKey, signature: signature, data: data)
    }

}