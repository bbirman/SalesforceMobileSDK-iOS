Pod::Spec.new do |s|

  s.name         = "SalesforceSDKCommon"
  s.version      = "10.2.0"
  s.summary      = "Salesforce Mobile SDK for iOS"
  s.homepage     = "https://github.com/forcedotcom/SalesforceMobileSDK-iOS"

  s.license      = { :type => "Salesforce.com Mobile SDK License", :file => "LICENSE.md" }
  s.author       = { "Raj Rao" => "rao.r@salesforce.com" }

  s.platform     = :ios, "14.0"
  s.swift_versions = ['5.0']

  s.source       = { :git => "https://github.com/forcedotcom/SalesforceMobileSDK-iOS.git",
                     :tag => "v#{s.version}",
                     :submodules => true }

  s.requires_arc = true
  s.default_subspec  = 'SalesforceSDKCommon'

  s.subspec 'SalesforceSDKCommon' do |sdkcommon|
      sdkcommon.source_files = 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/**/*.{h,m,swift}', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/SalesforceSDKCommon.h'
      sdkcommon.public_header_files = 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/NSUserDefaults+SFAdditions.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFDefaultLogger.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFFileProtectionHelper.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFJsonUtils.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFLogger.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFPathUtil.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFSDKDatasharingHelper.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFSDKReachability.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFSDKSafeMutableArray.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFSDKSafeMutableDictionary.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFSDKSafeMutableSet.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFSwiftDetectUtil.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/Classes/Public/SFTestContext.h', 'libs/SalesforceSDKCommon/SalesforceSDKCommon/SalesforceSDKCommon.h'
      sdkcommon.prefix_header_contents = ''
      sdkcommon.requires_arc = true

  end

end
