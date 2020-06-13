//
//  KeyValueEncryptedFileStore.swift
//  SmartStore
//
//  Created by Brianna Birman on 6/9/20.
//  Copyright (c) 2020-present, salesforce.com, inc. All rights reserved.
// 
//  Redistribution and use of this software in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//  * Redistributions of source code must retain the above copyright notice, this list of conditions
//  and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials provided
//  with the distribution.
//  * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission of salesforce.com, inc.
// 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
//  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
//  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import SalesforceSDKCore

@objc(SFSDKKeyValueEncryptedFileStore)
public class KeyValueEncryptedFileStore : NSObject {
    @objc(storePath) public let path: URL
    @objc(storeName) public let name: String
    @objc public static let maxStoreNameLength = 96
    
    private var encryptionKey: EncryptionKey
    private static var userStores = [String : [String : KeyValueEncryptedFileStore]]()
    private static var globalStores = [String : KeyValueEncryptedFileStore]()
    
    @objc(sharedStoreWithName:)
    public class func shared(withName name: String) -> KeyValueEncryptedFileStore? {
        return KeyValueEncryptedFileStore.shared(withName: name, forUserAccount: UserAccountManager.shared.currentUserAccount)
    }
    
    @objc(sharedStoreWithName:user:)
    public class func shared(withName name: String, forUserAccount user: UserAccount?) -> KeyValueEncryptedFileStore? {
        guard let user = user else {
            return nil
        }
        let userKey = Utils.userKey(forUser:user)
        if userStores[userKey] == nil {
            userStores[userKey] = [String : KeyValueEncryptedFileStore]()
        }
        
        if let store = userStores[userKey]?[name] {
            return store
        } else {
            guard let directory = SFDirectoryManager.shared().directory(forUser: user, type: .documentDirectory, components: ["keyvaluestores"]) else {
                return nil
            }
            let store = KeyValueEncryptedFileStore(parentDirectory: directory, name: name, encryptionKey: SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: "testlabel", autoCreate: true))
            userStores[userKey]?[name] = store
            return store
        }
    }
    
    @objc(sharedGlobalStoreWithName:)
    public class func sharedGlobal(withName name: String) -> KeyValueEncryptedFileStore? {
        if let store = globalStores[name] {
            return store
        } else {
            guard let directory = SFDirectoryManager.shared().globalDirectory(ofType: .documentDirectory, components: ["keyvaluestores"]) else {
                return nil
            }
            let store = KeyValueEncryptedFileStore(parentDirectory: directory, name: name, encryptionKey: SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: "testlabel", autoCreate: true))
            globalStores[name] = store
            return store
        }
    }
    
    @objc
    public class func allStoreNames() -> [String] {
        return [String]()
    }
    
    @objc
    public class func allGlobalStoreNames() -> [String] {
        return [String]()
    }
    
    @objc(removeSharedStoreWithName:)
    public static func removeStore(withName name: String) {
        //SmartStore.remove
    }
    
    @objc(removeSharedStoreWithName:forUser:)
    public class func removeStore(withName name: String, forUserAccount user: UserAccount?) {
        
    }
    
    @objc(removeSharedGlobalStoreWithName:)
    public class func removeSharedGlobal(withName name: String) {
        
    }
    
    @objc(removeAllStores)
    public class func removeAllForCurrentUser() {
        
    }
    
    @objc(removeAllStoresForUser:)
    public class func removeAll(forUserAccount user: UserAccount?) {
        
    }
    
    @objc(removeAllGlobalStores)
    public class func removeAllGlobal() {
        
    }
    
    @objc
    init?(parentDirectory: String, name: String, encryptionKey: EncryptionKey) {
        let fullPath = (parentDirectory as NSString).appendingPathComponent(name)
        do {
            try SFDirectoryManager.ensureDirectoryExists(fullPath)
        } catch {
            // Log error
            return nil
        }
        self.name = name
        self.path = URL(fileURLWithPath: fullPath)
        self.encryptionKey = encryptionKey
    }

    @objc(isValidStoreName:)
    public class func isValidName(_ name: String) -> Bool {
        return name.count <= maxStoreNameLength
    }

    @objc
    public func changeEncryptionKey(_ encryptionKey: EncryptionKey) -> Bool {
        self.encryptionKey = encryptionKey
        return true
    }
    
    @objc
    public override func setValue(_ value: Any?, forKey key: String) {
        <#code#>
    }
    
    public override class func value(forKey key: String) -> Any? {
        <#code#>
    }
    
    public func saveValue(_ value: String, forKey key: String) -> Bool {
        // Check for non-empty key
        
        // Encrypt data
        // Write to file
        guard let data = value.data(using: .utf8) else {
            // Log message
            return false
        }
        guard let encryptedData = encryptionKey.encryptData(data) else {
            //Log message
            return false
        }
        
        let fileUrl = path.appendingPathComponent(hashedKey(key: key))
        do {
            try encryptedData.write(to: fileUrl) // Need any options?
        } catch {
            // Log error
            return false
        }
        
        return true
    }
    
    @objc
    public func getValue(forKey key: String) -> String? { // TODO better alternate rename?
        let fileUrl = path.appendingPathComponent(hashedKey(key: key))
        // Need to check file exists?
        
        do {
            let encryptedData = try Data(contentsOf: fileUrl)
            guard let decryptedData = encryptionKey.decryptData(encryptedData) else {
                // Log message
                return nil
            }
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            // Log error
            
        }
        return nil
    }
    
    @objc
    public func removeValue(forKey key: String) -> Bool {
        return true
    }
    
    @objc
    public func removeAll() {
        
    }
    
    @objc
    public func count() -> Int { // is that right kind of int?
//        do {
//            // What happens if directory doesn't exist?
//            let files = try FileManager.default.contentsOfDirectory(atPath: self.storeDirectory)
//            return files.count
//        } catch {
//            // Log erroe
//        }
       
        return 0
    }
    
    
    @objc
    public func isEmpty() -> Bool {
        return true
    }
    
    private func hashedKey(key: String) -> String {
      return key
    }
    
}




@objc(SFSDKKeyValueEncryptedFileStoreManager)
public class KeyValueEncryptedFileStoreManager : NSObject {
    @objc public static let sharedGlobalManager = KeyValueEncryptedFileStoreManager()
    private static let encryptionKeyLabel = "com.salesforce.keyValueStores.encryptionKey";
    private static var sharedManagers = [String : KeyValueEncryptedFileStoreManager]()
    private let user: UserAccount?
    private let isGlobalManager: Bool

    
    @objc
    public class func sharedManager() -> KeyValueEncryptedFileStoreManager? {
        return KeyValueEncryptedFileStoreManager.sharedManagerForUser(UserAccountManager.shared.currentUserAccount)
    }
    
    @objc
    public class func sharedManagerForUser(_ user: UserAccount?) -> KeyValueEncryptedFileStoreManager? {
        guard let user = user else {
            return nil
        }
        let userKey = Utils.userKey(forUser:user)
        if let manager = sharedManagers[userKey] {
            return manager
        } else {
            let manager = KeyValueEncryptedFileStoreManager(user: user)
            sharedManagers[userKey] = manager
            return manager
        }
    }
    
    class func encryptionKey() -> EncryptionKey {
        return SFKeyStoreManager.sharedInstance().retrieveKey(withLabel: encryptionKeyLabel, autoCreate: true)
       // [[SFKeyStoreManager sharedInstance] retrieveKeyWithLabel:kURLCacheEncryptionKeyLabel autoCreate:YES];
    }

    override init() { // Does init need to be public?
        self.user = nil
        self.isGlobalManager = true
    }
    
    init(user: UserAccount) {
        self.user = user
        self.isGlobalManager = false
    }
    
    @objc
    public class func removeSharedManagerForUser(_ user: UserAccount) {
        let userKey = Utils.userKey(forUser:user)
        sharedManagers.removeValue(forKey: userKey)
    }
    
    @objc
    public func createKeyValueStore(name: String) -> KeyValueEncryptedFileStore? {
        guard let rootDirectory = rootDirectory() else {
            // Log error
            return nil
        }
        return KeyValueEncryptedFileStore(parentDirectory: rootDirectory, name: name, encryptionKey: KeyValueEncryptedFileStoreManager.encryptionKey())
    }
    
    @objc
    public func removeKeyValueStore(name: String) -> Bool {
        let storePath = "\(String(describing: rootDirectory()))/\(name)"
        do {
            try FileManager.default.removeItem(atPath: storePath)
        } catch {
            
        }
       return true
    }
    
    @objc
    public func removeAllKeyValueStores() {
        
        
    }
    
    private func rootDirectory() -> String? {
        var rootDirectory: String?
        if user == nil || isGlobalManager {
            rootDirectory = SFDirectoryManager.shared().globalDirectory(ofType: .documentDirectory, components: ["keyvaluestores"])
        } else {
            rootDirectory = SFDirectoryManager.shared().directory(forUser: user, type: .documentDirectory, components: ["keyvaluestores"])
        }
        return rootDirectory
    }
    
    
//    - (NSString *)rootStoreDirectory {
//        NSString *rootStoreDir;
//        if (self.user == nil || self.isGlobalManager) {
//            rootStoreDir = [[SFDirectoryManager sharedManager] globalDirectoryOfType:NSDocumentDirectory components:@[ kStoresDirectory ]];
//        } else {
//            rootStoreDir = [[SFDirectoryManager sharedManager] directoryForUser:self.user type:NSDocumentDirectory components:@[ kStoresDirectory ]];
//        }
//        return rootStoreDir;
//    }
    
   //  getting/deleting/listing global / user kv stores

}

