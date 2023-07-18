import FungibleToken from "./FungibleToken.cdc"
import NonFungibleToken from "./NonFungibleToken.cdc"

// WIP

pub contract ResourceHolder {
    pub let BagManagerPublicPath: PublicPath
    pub let BagManagerStoragePath: StoragePath

    pub struct SignedData {
        pub let claimerETHAddress: String
        pub let destination: Address
        pub let itemId: UInt64
        pub let expiration: UInt64 // unix timestamp

        init(claimerETHAddress: String, destination: Address, itemId: UInt64, expiration: UInt64){
            self.claimerETHAddress = claimerETHAddress
            self.destination = destination
            self.itemId = itemId
            self.expiration = expiration
        }

        pub fun toString(): String {
            return self.claimerETHAddress.concat(":").concat(self.destination.toString()).concat(":").concat(self.itemId.toString()).concat(":").concat(self.expiration.toString())
        }
    }

    pub resource BagManager {
        access(self) let bags: @{String : Bag}  // ETH Address -> Bag of Items

        init() {
            self.bags <- {}
        }

        pub fun deposit(
            claimerETHAddress: String,
            resource: @AnyResource
        ) {
            if !self.bags.containsKey(claimerETHAddress) {
                let bag <- create Bag(claimerETHAddress: claimerETHAddress)
                let oldValue <- self.bags.insert(key: claimerETHAddress, <-bag)
                destroy oldValue
            }
            let bagRef = (&self.bags[claimerETHAddress] as &ResourceHolder.Bag?)!
            let item <- create Item(resource: <-resource, claimer: claimerETHAddress)
            bagRef.deposit(item: <-item)
        }

        pub fun borrowBag(claimerETHAddress: String): &ResourceHolder.Bag? {
            return &self.bags[claimerETHAddress] as &ResourceHolder.Bag?
        }

        destroy () {
            destroy <-self.bags
        }
    }

    pub resource Bag {
        access(self) let claimerETHAddress : String
        access(self) let items: @{UInt64 : Item} // Mapping of item uuid -> Item

        init (claimerETHAddress: String) {
            self.claimerETHAddress = claimerETHAddress
            self.items <- {}
        }

        pub fun borrowItem(id: UInt64): &ResourceHolder.Item? {
            return &self.items[id] as &ResourceHolder.Item?
        }

        pub fun getItemIDs(): [UInt64] {
            return self.items.keys
        }

        access(contract) fun deposit(item: @Item) {
            let oldValue <- self.items[item.uuid] <- item
            destroy oldValue
        }

        access(contract) fun withdrawItem(id: UInt64): @ResourceHolder.Item {
            let item <- self.items.remove(key: id)
            return <- item!
        }


        destroy () {
            destroy <-self.items
        }
    }

    pub resource Item {
        access(contract) var resource: @AnyResource?
        pub let claimer: String

        init(
            resource: @AnyResource,
            claimer: String

        ) {
            self.resource <- resource
            self.claimer = claimer
        }

        pub fun withdraw(receiver: Capability, publicKey: String, signature: String, data: SignedData) {
            pre {
                self.uuid == data.itemId : "invalid item being claimed"
                self.resource != nil : "No resource to withdraw"
                receiver.address == data.destination
                data.expiration >= UInt64(getCurrentBlock().timestamp): "expired signature"
                self.verifyWithdrawSignature(publicKey: publicKey, signature: signature, data: data): "invalid signature for data"
            }

            var claimableItem <- self.resource <- nil
            
            let cap = receiver.borrow<&AnyResource>()!
            
            if cap.isInstance(Type<@NonFungibleToken.Collection>()) {
                let target = receiver.borrow<&AnyResource{NonFungibleToken.CollectionPublic}>()!
                let token <- claimableItem  as! @NonFungibleToken.NFT?
                target.deposit(token: <- token!)
            } else if cap.isInstance(Type<@FungibleToken.Vault>()) {
                let target = receiver.borrow<&AnyResource{FungibleToken.Receiver}>()!
                let token <- claimableItem as! @FungibleToken.Vault?
                target.deposit(from: <- token!)
                return
            } else {
                panic("cannot claim resource to receiver")
            }
        }

        access(self) fun verifyWithdrawSignature(publicKey: String, signature: String, data: SignedData): Bool {
            let publicKeyBytes = publicKey.decodeHex()
            let signatureBytes = signature.decodeHex()
            
            let message = data.toString()
            let ethereumMessagePrefix: String = "\u{0019}Ethereum Signed Message:\n".concat(message.length.toString())
            let fullMessage: String = ethereumMessagePrefix.concat(message)

            let publicKey = PublicKey(
                publicKey: publicKeyBytes,
                signatureAlgorithm: SignatureAlgorithm.ECDSA_secp256k1
            )

            let isValid = publicKey.verify(
                signature: signatureBytes,
                signedData: fullMessage.utf8,
                domainSeparationTag: "",
                hashAlgorithm: HashAlgorithm.KECCAK_256
            )

            // Get ETH Public address from key
            let digest = HashAlgorithm.KECCAK_256.hash(publicKeyBytes)
            let hexDigest = String.encodeHex(digest)
            let ethAddress = "0x".concat(hexDigest.slice(from: hexDigest.length-40, upTo: hexDigest.length))
            
            if ethAddress != self.claimer {
                return false
            }

            if(ethAddress != data.claimerETHAddress) {
                return false
            }

            return isValid
        }

        destroy () {
            pre {
                self.resource == nil : "Can't destroy underlying resource"
            }
            destroy <-self.resource
        }
    }

    pub fun claim(receiver: Capability, publicKey: String, signature: String, data: SignedData) {
        let bagManagerRef = ResourceHolder.borrowBagManager()
        let bag = bagManagerRef.borrowBag(claimerETHAddress: data.claimerETHAddress)!
        let item <- bag.withdrawItem(id: data.itemId)
        item.withdraw(receiver: receiver, publicKey: publicKey, signature: signature, data: data)
        destroy item
    }

    pub fun deposit(
        claimerETHAddress: String,
        resource: @AnyResource
    ) {
        let bagManagerRef = ResourceHolder.borrowBagManager()
        bagManagerRef.deposit(claimerETHAddress: claimerETHAddress, resource: <-resource)
    }

    pub fun getItemIDsForETHAddress(claimerETHAddress : String) : [UInt64] {
        let bagManagerRef = ResourceHolder.borrowBagManager()
        let bagRef = bagManagerRef.borrowBag(claimerETHAddress: claimerETHAddress)

        if bagRef == nil {
            return []
        }

        return bagRef!.getItemIDs()
    }

    access(contract) fun borrowBagManager(): &BagManager {
        return self.account.getCapability<&ResourceHolder.BagManager>(ResourceHolder.BagManagerPublicPath).borrow()!
    }

    init() {
        self.BagManagerPublicPath = /public/bagManager
        self.BagManagerStoragePath = /storage/bagManager

        let manager <- create BagManager()
        self.account.save(<-manager, to: self.BagManagerStoragePath)
        self.account.link<&ResourceHolder.BagManager>(self.BagManagerPublicPath, target: self.BagManagerStoragePath)
    }

}