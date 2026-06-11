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


@objc(SFSDKAppAttestation)
public class AppAttestation: NSObject {
    struct AttestationObject: Codable {
        let attestationId: String
        let attestationData: String // Base-64 encoded
    }
    
    static let appAttestKeyName = "AppAttestKey"

    
    @objc static func attestationObject(for domain: String, consumerKey: String) async throws -> String {
        // TODO check for my domain
        
        let attestationId = "bvbtest1"  // TODO: real id

        let keyId = try await keyId(for: attestationId, domain: domain, consumerKey: consumerKey)
        
        let challenge = try await requestChallengeFromSalesforce(domain: domain, consumerKey: consumerKey, attestationId: attestationId)
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
    static func keyId(for attestationId: String, domain: String, consumerKey: String) async throws -> String {
        let removeResult = KeychainHelper.remove(service: appAttestKeyName, account: nil)
        
        let attestKeyQuery = KeychainHelper.read(service: appAttestKeyName, account: nil) // TODO: User account
        if let attestKeyData = attestKeyQuery.data,
            let keyId = String(data: attestKeyData, encoding: .utf8) {
            // Key already exists, skip registration & attestation
            // TODO: Guards on migration / app deletion / etc
            return  keyId
        }
        
        do {
            let keyId = try await DCAppAttestService.shared.generateKey()
            print("KeyId: \(keyId)")
            if let keyIdData = keyId.data(using: .utf8) {
                
                let keychainResult = KeychainHelper.write(service: appAttestKeyName, data: keyIdData, account: nil)
                if !keychainResult.success {
                    var message = "Unable to write attestation keyId to keychain"
                    
                    if let error = keychainResult.error {
                        message += ": \(error.localizedDescription)"
                    }

                    SFSDKCoreLogger.log(AppAttestation.self, level: .error, message: message)
                }
            }
           
            let challenge = try await requestChallengeFromSalesforce(domain: domain, consumerKey: consumerKey, attestationId: attestationId)
            let attestation = try await generateAttestation(keyId: keyId, challenge: challenge)
            print("Attestation: \(attestation)")
            
            try await registerKeyWithSalesforce(keyId: keyId, consumerKey: consumerKey, attestationId: attestationId, attestationObject: attestation, domain: domain)
            
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

    
    // 2. Client makes request to get challenge - /mobile/attest/challenge
    // https://msdkappattestationtestorg.test1.my.pc-rnd.salesforce.com/mobile/attest/challenge?consumerKey=3MVG9.AgwtoIvERQAaXavOqevMWM.dGcHogkREX3wZnckV7FTqdLvsJVC4z3sLMtSuxqbjWMilFuwxFyc00A_&attestationId=sashatest
    static func requestChallengeFromSalesforce(domain: String, consumerKey: String, attestationId: String) async throws -> String {
        let params = ["consumerKey": consumerKey, "attestationId": attestationId]
        let request = RestRequest(method: .GET, baseURL: "https://\(domain)", path: "/mobile/attest/challenge", queryParams: params)
        request.endpoint = ""
        request.requiresAuthentication = false
        let response = try await RestClient.sharedGlobal.send(request: request)
        print(response)
        print("Challenge string: \(response.asString())")
        return response.asString()
    }
    
    static func registerKeyWithSalesforce(keyId: String, consumerKey: String, attestationId: String, attestationObject: String, domain: String) async throws {
        let requestBody = "consumerKey=\(consumerKey)&attestationId=\(attestationId)&keyIdentifier=\(keyId)&attestationObject=\(attestationObject.sfsdk_stringByURLEncoding())" // TODO: do other components need URL encoding?
        let request = RestRequest(method: .POST, baseURL: "https://\(domain)", path: "/mobile/attest/registerkey", queryParams: nil)
        request.endpoint = ""
        request.requiresAuthentication = false
        request.setCustomRequestBodyString(requestBody, contentType: kHttpPostContentType)
        
        let response = try await RestClient.sharedGlobal.send(request: request)
        print(response)
    }
}
