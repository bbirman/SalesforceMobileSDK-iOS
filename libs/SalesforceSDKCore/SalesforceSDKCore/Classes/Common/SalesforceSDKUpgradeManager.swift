//
//  SalesforceSDKUpgradeManager.swift
//  
//
//  Created by Brianna Birman on 9/13/21.
//  Copyright (c) 2021-present, salesforce.com, inc. All rights reserved.
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

@objc class SalesforceSDKUpgradeManager: NSObject {
    static let versionKey = "com.salesforce.mobilesdk.salesforcesdkmanager.version"
    
    static var lastVersion: String? {
        get {
            return UserDefaults.msdk().string(forKey: versionKey)
           
        }
        set(newVersion) {
            UserDefaults.msdk().setValue(newVersion, forKey: versionKey)
        }
    }
    
    static var currentVersion: String? {
        Bundle(for: SalesforceSDKUpgradeManager.self).infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    @objc static func upgrade() {
        if lastVersion == currentVersion {
            return;
        }

        if let lastVersionNum = Double(lastVersion ?? "0"), lastVersionNum < 9.2 {
            upgradeUserDirectories()
            upgradeUserPhotos()
            upgradeUserAccountFiles()
        }
        lastVersion = currentVersion
    }
    
    static func upgradeUserDirectories() {
        
//        let rootDirectory = SFDirectoryManager.shared().directory(forOrg: nil, user: nil, community: nil, type: .libraryDirectory, components: nil)
//        let fileManager =  FileManager.default
//        guard let rootDirectory = rootDirectory, fileManager.fileExists(atPath: rootDirectory) else { return }
//
//        do {
//            let rootContents = try fileManager.contentsOfDirectory(atPath: rootDirectory)
//            let orgDirectories: [String] = rootContents.filter { $0.hasPrefix("00D") }
//            let userDirectoryContents: [String] = try orgDirectories.compactMap { orgDirectory in
//                let orgPath = rootDirectory + "/\(orgDirectory)"
//                let orgContents = try fileManager.contentsOfDirectory(atPath: orgPath)
//                return orgContents.filter{ $0.hasPrefix("005") }
////                userDirectories.map { userDirectory in
////                    let userPath = "\(orgPath)/\(userDirectory)"
////                    let userContents = try fileManager.contentsOfDirectory(atPath: userPath)
////
////                }
//
//
//            }.flatMap { $0 }
//
//
//
//            print(orgDirectories)
//        } catch {
//
//        }
        
       
       
        
    }
    
    static func upgradeUserPhotos() {
        
    }
    
    static func upgradeUserAccountFiles() {
        
    }
}


