// 
//  AppDelegate.swift
//  MobileSyncExplorer
//
//  Created by Brianna Birman on 9/10/25.
//  Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.
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

import UIKit
import SalesforceSDKCore
import MobileSync
import MobileSyncExplorerCommon
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    override init() {
        super.init()
        
        let config = MobileSyncExplorerConfig.sharedInstance()
        SFSDKDatasharingHelper.sharedInstance().appGroupName = config.appGroupName
        SFSDKDatasharingHelper.sharedInstance().appGroupEnabled = config.appGroupsEnabled
        
        MobileSyncSDKManager.initializeSDK()
        
        // Uncomment following lines to enable IDP Login flow. Set scheme of idpAppp & display name (optional)
        // MobileSyncSDKManager.shared().idpAppURIScheme = "sampleidpapp"
        // MobileSyncSDKManager.shared().appDisplayName = "SampleAppOne"
    }
    
    // MARK: - UIApplicationDelegate
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    // MARK: - Push notifications
    
    func registerForRemotePushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    SFPushNotificationManager.sharedInstance().registerForRemoteNotifications()
                }
            } else {
                SFLogger.d(AppDelegate.self, message: "Push notification authorization denied")
            }
            
            if let error = error {
                SFLogger.e(AppDelegate.self, message: "Push notification authorization error: \(error)")
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Uncomment the code below to register your device token with the push notification manager
        // didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }
    
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        SFPushNotificationManager.sharedInstance().didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
        if SFUserAccountManager.sharedInstance().currentUser?.credentials.accessToken != nil {
            SFPushNotificationManager.sharedInstance().registerSalesforceNotifications(completionBlock: nil, failBlock: nil)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Respond to any push notification registration errors here.
    }
    
    // MARK: - Handling URLs
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Uncomment following line to enable IDP Login flow
        // return SFUserAccountManager.sharedInstance().handleIdentityProviderResponse(from: url, with: options)
        return false
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
