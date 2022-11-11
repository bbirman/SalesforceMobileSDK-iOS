// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SalesforceMobileSDK",
    platforms: [
        .iOS(.v14),
        //.watchOS(.v5)
    ],
    products: [
        .library(
            name: "SalesforceAnalyticsLib",
            targets: ["SalesforceAnalytics"]
        ),
        .library(
            name: "SalesforceSDKCommonLib",
            targets: ["SalesforceSDKCommon", "SalesforceSDKCommonSwift"]),
        
            
        .library(
            name: "SalesforceSDKCoreLib",
            targets: ["SalesforceSDKCore", "SalesforceSDKCoreSwiftBase", "SalesforceSDKCoreManager"]
        ),
//        .library(
//            name: "SmartStore",
//            targets: ["SmartStore"]
//        ),
//        .library(
//            name: "MobileSync",
//            targets: ["MobileSync"]
//        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SalesforceAnalytics",
            dependencies: ["SalesforceSDKCommon"],
            path: "libs/SalesforceAnalytics/SalesforceAnalytics",
//            sources: ["Classes/Model", "Classes/Manager", "Classes/Store", "Classes/Transform", "Classes/Util"],
           
            publicHeadersPath: "Public",
            
            cSettings: [
                  .headerSearchPath("Internal"),
                  //.headerSearchPath("include"),
                  .headerSearchPath("Public")
               ]
        ),
        .target(
            name: "SalesforceSDKCommonSwift",
            dependencies: ["SalesforceSDKCommon"],
            path: "libs/SalesforceSDKCommon/SalesforceSDKCommonSwift"
        ),
        
        .target(
            name: "SalesforceSDKCommon",
            dependencies: [],
            path: "libs/SalesforceSDKCommon/SalesforceSDKCommon",
            publicHeadersPath: "Public"

        ),
        
        .target(
            name: "SalesforceSDKCoreManager",
            dependencies: ["SalesforceSDKCommon", "SalesforceSDKCoreSwiftBase", "SalesforceSDKCoreSwift", "SalesforceSDKCommonSwift", "SalesforceAnalytics", "SalesforceSDKCore"],
            path: "libs/SalesforceSDKCore/SalesforceSDKManager",
            publicHeadersPath: "Public",
            cSettings: [
                  .headerSearchPath("Internal"),
                  .headerSearchPath("Public")
               ]
        ),
        
        
        .target(
            name: "SalesforceSDKCoreSwift",
            dependencies: ["SalesforceSDKCommon", "SalesforceSDKCommonSwift", "SalesforceSDKCoreSwiftBase", "SalesforceSDKCore"],
            path: "libs/SalesforceSDKCore/SalesforceSDKCoreSwift"
        ),
        

        
        .target(
            name: "SalesforceSDKCore",
            dependencies: ["SalesforceSDKCommon", "SalesforceSDKCoreSwiftBase", "SalesforceSDKCommonSwift", "SalesforceAnalytics"],
            path: "libs/SalesforceSDKCore/SalesforceSDKCore",
           // sources: ["."],
            publicHeadersPath: "Public",
            cSettings: [
                  .headerSearchPath("Internal"),
                  //.headerSearchPath("include"),
                  .headerSearchPath("Public")
               ]
           //exclude: ["Classes/Extensions/RestClient.swift"]
        ),
        .target(
            name: "SalesforceSDKCoreSwiftBase",
            dependencies: ["SalesforceSDKCommon", "SalesforceSDKCommonSwift"],
            path: "libs/SalesforceSDKCore/SalesforceSDKCoreSwiftBase"
        )
//        .target(
//            name: "SmartStore",
//            dependencies: ["SalesforceSDKCore"],
//            path: "libs/SmartStore/SmartStore",
//            exclude: ["Classes/Extensions/SmartStore.swift"]
//        ),
//        .target(
//            name: "MobileSync",
//            dependencies: ["SmartStore"],
//            path: "libs/MobileSync/MobileSync",
//            exclude: ["Classes/Extensions/MobileSync.swift"]
//        )
    ],
    swiftLanguageVersions: [.v5]
)
