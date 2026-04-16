//
//  AppAttestation.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 1/5/26.
//  Copyright (c) 2026-present, salesforce.com, inc. All rights reserved.
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

import CryptoKit
import DeviceCheck


//func runAttestation() async {
//    let service = DCAppAttestService.shared
//    do {
//        // Step 1 must finish before Step 2 starts
//        let newKeyId = try await service.generateKey()
//
//        let challenge = "your_hardcoded_string"
//        let hash = Data(SHA256.hash(data: challenge.data(using: .utf8)!))
//
//        // Step 2: This is where your console error is happening
//        let attestation = try await service.attestKey(newKeyId, clientDataHash: hash)
//        print("Success!")
//    } catch {
//        print("Error: \(error)")
//    }
//}



@objc(SFSDKAppAttestation)
public class AppAttestation: NSObject {
    struct AttestationObject: Codable {
        let attestationId: String
        let attestationData: String // Base-6 encoded
    }
    
    
    static let shared = AppAttestation()
    
    static let appAttestKeyName = "AppAttestKey"

    
    
    @objc static func attestationObject(for domain: String, consumerKey: String) async throws -> String {
        // TODO check for my domain
        
        let attestationId = "bvbtest1"

        let keyId = try await preregisterKey(attestationId: attestationId, domain: domain, consumerKey: consumerKey)
        
        let challenge = try await requestChallenge(domain: domain, consumerKey: consumerKey, attestationId: attestationId)
        let challengeData = challenge.data(using: .utf8)! // TODO: force unwrap
        let hash = Data(SHA256.hash(data: challengeData))
       
        do {
            let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: hash)
            let assertionString = assertion.base64EncodedString()
            
            let attestationObject = AttestationObject(attestationId: attestationId, attestationData: assertionString)
            let jsonData = try JSONEncoder().encode(attestationObject)
            return jsonData.base64EncodedString()
        }   catch let error as DCError {
            switch error.code {
            case .featureUnsupported:
            print("feature unsupported")
            case .invalidInput:
            print("invalid input")
            case .invalidKey:
            print("invalid key")
            case .serverUnavailable:
                print("server unavailable")
            case .unknownSystemFailure:
                print("unknown system failure")
            default:
                print("default")
            }
            throw error
    
        } catch {
            print("Error generating key: \(error.localizedDescription)")
            throw error
        }
    }
    
    
    static func generateAttestation(keyId: String, challenge: String) async throws -> String {
        let challengeData = challenge.data(using: .utf8)! // TODO: force unwrap
        let hash = Data(SHA256.hash(data: challengeData))
        
        
        do {
            let attestation = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: hash)
            return attestation.base64EncodedString()
        }  catch let error as DCError {
            switch error.code {
            case .featureUnsupported:
            print("feature unsupported")
            case .invalidInput:
            print("invalid input")
            case .invalidKey:
            print("invalid key")
            case .serverUnavailable:
                print("server unavailable")
            case .unknownSystemFailure:
                print("unknown system failure")
            default:
                print("default")
            }
            throw error
    
        } catch {
            print("Error generating key: \(error.localizedDescription)")
            throw error
        }
       
        
    }
    
//    1. Client creates a key pair
//    2. Client makes request to get challenge  - /mobile/attest/challenge
//    3. Client creates an Apple attestation object with obtained challenge
//    4. Client makes request to pre-register public key - /mobile/attest/registerkey
    static func preregisterKey(attestationId: String, domain: String, consumerKey: String) async throws -> String {
       // let removeResult = KeychainHelper.remove(service: appAttestKeyName, account: nil)
        
        let attestKeyQuery = KeychainHelper.read(service: appAttestKeyName, account: nil) // TODO: User account
        if let attestKeyData = attestKeyQuery.data {
            // Key already exists, skip registration & attestation
            // TODO: Guards on migration / app deletion / etc
            return  String(data: attestKeyData, encoding: .utf8)! // BB TODO encoding?
        }
               
       
        

       

        
        
        do {
            let keyId = try await DCAppAttestService.shared.generateKey()
            print("KeyId: \(keyId)")
            if let keyIdData = keyId.data(using: .utf8) {
                
                let keychainResult = KeychainHelper.write(service: appAttestKeyName, data: keyIdData, account: nil)
                // TODO: error handling
            }
           
            let challenge = try await requestChallenge(domain: domain, consumerKey: consumerKey, attestationId: attestationId)
            let attestation = try await generateAttestation(keyId: keyId, challenge: challenge)
            print("Attestation: \(attestation)")
            
            try await registerKey(keyId: keyId, consumerKey: consumerKey, attestationId: attestationId, attestationObject: attestation, domain: domain)
            
            return keyId
           
        }  catch let error as DCError {
            switch error.code {
            case .featureUnsupported:
            print("feature unsupported")
            case .invalidInput:
            print("invalid input")
            case .invalidKey:
            print("invalid key")
            case .serverUnavailable:
                print("server unavailable")
            case .unknownSystemFailure:
                print("unknown system failure")
            default:
                print("default")
            }
            throw error
    
        } catch {
            print("Error generating key: \(error.localizedDescription)")
            throw error
        }
        
        
       
    }

//    
//    static func keyId(for userAccount: UserAccount?) async throws -> String {
//        let account = userAccount?.idData.userId
//        
//        // TODO Store key and make sure it's only attested once
////        let attestKeyQuery = KeychainHelper.read(service: appAttestKeyName, account: account)
////        if let attestKeyData = attestKeyQuery.data {
////            return attestKeyData.base64EncodedString() // BB TODO encoding?
////        }
////        
//        
//        let keyId = try await DCAppAttestService.shared.generateKey()
//        if let keyIdData = keyId.data(using: .utf8) {
//                  
//            let keychainResult = KeychainHelper.write(service: appAttestKeyName, data: keyIdData, account: nil)
//            
//            
//            let attestKeyQuery = KeychainHelper.read(service: appAttestKeyName, account: nil)
//            if let attestKeyData = attestKeyQuery.data {
//                String(data: attestKeyData, encoding: .utf8) // BB TODO encoding?
//           }
//        } else {
//            
//        }
//        
//        return keyId
//        
//        
//        //KeychainHelper.createIfNotPresent(service: appAttestKeyName, account: account)
//    }
    
    // 2. Client makes request to get challenge - /mobile/attest/challenge
    // https://msdkappattestationtestorg.test1.my.pc-rnd.salesforce.com/mobile/attest/challenge?consumerKey=3MVG9.AgwtoIvERQAaXavOqevMWM.dGcHogkREX3wZnckV7FTqdLvsJVC4z3sLMtSuxqbjWMilFuwxFyc00A_&attestationId=sashatest
    static func requestChallenge(domain: String, consumerKey: String, attestationId: String) async throws -> String {
       // RestClient.sharedGlobal.send(request: <#T##RestRequest#>)
        let params = ["consumerKey": consumerKey, "attestationId": attestationId]
        let request = RestRequest(method: .GET, baseURL: "https://\(domain)", path: "/mobile/attest/challenge", queryParams: params)
        request.endpoint = ""
        request.requiresAuthentication = false
        let response = try await RestClient.sharedGlobal.send(request: request)
        print(response)
        print("Challenge string: \(response.asString())")
        return response.asString()

    }
    
    static func registerKey(keyId: String, consumerKey: String, attestationId: String, attestationObject: String, domain: String) async throws {
        // Create the access token request.
        
        let requestBody = "consumerKey=\(consumerKey)&attestationId=\(attestationId)&keyIdentifier=\(keyId)&attestationObject=\(attestationObject.sfsdk_stringByURLEncoding())"
        let request = RestRequest(method: .POST, baseURL: "https://\(domain)", path: "/mobile/attest/registerkey", queryParams: nil)
        request.endpoint = ""
        request.requiresAuthentication = false
        request.setCustomRequestBodyString(requestBody, contentType: kHttpPostContentType)
        
        let response = try await RestClient.sharedGlobal.send(request: request)
        print(response)
    }
//
//    func runAttestation() async {
//        let service = DCAppAttestService.shared
//        do {
//            // Step 1 must finish before Step 2 starts
//            let newKeyId = try await service.generateKey()
//
//            let challenge = "your_hardcoded_string"
//            let hash = Data(SHA256.hash(data: challenge.data(using: .utf8)!))
//
//            // Step 2: This is where your console error is happening
//            let attestation = try await service.attestKey(newKeyId, clientDataHash: hash)
//            print("Success!")
//        } catch {
//            print("Error: \(error)")
//        }
//    }
    
    func attest() async {
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            print("Service not supported")
            return
        }
        
        
        do {
            let keyId = try await service.generateKey()
            //let keyId = "L2AWUcguPlrlcAj8PNv8Li3sS5DxBj6afWneJfjzEF0="
            print("Generated keyId: \(keyId)")
            
            
            let challengeData = "a3KUezgbvT2MjzPXfzmL6H7U7DJ01PQBu96SwujX_pKVx4hH".data(using: .utf8)!
            let hash = Data(SHA256.hash(data: challengeData))
            
//            let attestation = try await service.attestKey(keyId, clientDataHash: hash)
//            let attestationString = attestation.base64EncodedString()
//            print("Attestation:")
//            print(attestationString)
            
            let assertion = try await service.generateAssertion(keyId, clientDataHash: hash)
            let assertionString = assertion.base64EncodedString()
            print("Assertion:")
            print(assertionString)
            
        }  catch let error as DCError {
            switch error.code {
            case .featureUnsupported:
            print("feature unsupported")
            case .invalidInput:
            print("invalid input")
            case .invalidKey:
            print("invalid key")
            case .serverUnavailable:
                print("server unavailable")
            case .unknownSystemFailure:
                print("unknown system failure")
            default:
                print("default")
            }
        
        } catch {
            print("Error generating key: \(error.localizedDescription)")
        }
        
    }
    
    
//    func generateAssertion() async {
//        let service = DCAppAttestService.shared
//        let challenge = "my_hardcoded_test_string"
//        let challengeData = challenge.data(using: .utf8)!
//
//        // Use CryptoKit to create a SHA256 hash
//        let hashed = SHA256.hash(data: challengeData)
//
//        // Check the count - it must be 32
//        let finalHash = Data(hashed)
//        print("Hash byte count: \(finalHash.count)") // Should be 32
//
//        do {
//            let assertion = try await service.attestKey(self.keyId!, clientDataHash: finalHash)
//            print("Assertion: \(assertion)")
//            let base64Assertion = assertion.base64EncodedString()
//            print("Base 64 encoded assertion: \(base64Assertion)")
//        } catch {
//            if let dcError = error as? DCError {
//                switch dcError.code {
//                case .featureUnsupported:
//                print("feature unsupported")
//                case .invalidInput:
//                print("invalid input")
//                case .invalidKey:
//                print("invalid key")
//                case .serverUnavailable:
//                    print("server unavailable")
//                case .unknownSystemFailure:
//                    print("unknown system failure")
//                default:
//                    print("default")
//                }
//
//
//
//
//                print(dcError)
//                print(dcError.code)
//
//            }
//
//            print("Assertion error: \(error.localizedDescription)")
//        }
//
//    }
   
}
