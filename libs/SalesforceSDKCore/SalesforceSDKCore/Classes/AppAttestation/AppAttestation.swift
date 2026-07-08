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
    enum AppAttestationError: Error {
        case challengeEncodingFailed
    }

    struct AttestationObject: Codable {
        let attestationId: String
        let attestationData: String // Base-64 encoded
    }
    
    static let appAttestKeyName = "AppAttestKey"

    
    @objc static func attestationObject(for domain: String, consumerKey: String) async throws -> String {
        let attestationId = SalesforceManager.shared.deviceId()

        let keyId = try await keyId(for: attestationId, domain: domain, consumerKey: consumerKey)

        let challenge = try await requestChallengeFromSalesforce(domain: domain, consumerKey: consumerKey, attestationId: attestationId)
        guard let challengeData = challenge.data(using: .utf8) else {
            throw AppAttestationError.challengeEncodingFailed
        }
        let hash = Data(SHA256.hash(data: challengeData))

        let assertion = try await performAppAttestOperation {
            try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: hash)
        }
        let assertionString = assertion.base64EncodedString()

        let attestationObject = AttestationObject(attestationId: attestationId, attestationData: assertionString)
        let jsonData = try JSONEncoder().encode(attestationObject)
        return jsonData.base64EncodedString()
    }


    static func generateAttestation(keyId: String, challenge: String) async throws -> String {
        guard let challengeData = challenge.data(using: .utf8) else {
            throw AppAttestationError.challengeEncodingFailed
        }
        let hash = Data(SHA256.hash(data: challengeData))

        let attestation = try await performAppAttestOperation {
            try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: hash)
        }
        return attestation.base64EncodedString()
    }

//    1. Client creates a key pair
//    2. Client makes request to get challenge  - /mobile/attest/challenge
//    3. Client creates an Apple attestation object with obtained challenge
//    4. Client makes request to pre-register public key - /mobile/attest/registerkey
    static func keyId(for attestationId: String, domain: String, consumerKey: String) async throws -> String {
        // TODO: Remove - temporarily clearing keychain for development/testing
        // let removeResult = KeychainHelper.remove(service: appAttestKeyName, account: nil)

        let attestKeyQuery = KeychainHelper.read(service: appAttestKeyName, account: nil)
        if let attestKeyData = attestKeyQuery.data,
            let keyId = String(data: attestKeyData, encoding: .utf8) {
            // Key already exists, skip registration & attestation
            // TODO: Guards on migration / app deletion / etc
            return keyId
        }

        let keyId = try await performAppAttestOperation {
            try await DCAppAttestService.shared.generateKey()
        }

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

        try await registerKeyWithSalesforce(keyId: keyId, consumerKey: consumerKey, attestationId: attestationId, attestationObject: attestation, domain: domain)

        return keyId
    }

    private static func performAppAttestOperation<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as DCError {
            SFSDKCoreLogger.log(AppAttestation.self, level: .error, message: "App Attest error: \(error.code.rawValue)")
            throw error
        }
    }

    
    // Requests a challenge from https://<domain>/mobile/attest/challenge
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
        let requestBody = "consumerKey=\(consumerKey.sfsdk_stringByURLEncoding())&attestationId=\(attestationId.sfsdk_stringByURLEncoding())&keyIdentifier=\(keyId.sfsdk_stringByURLEncoding())&attestationObject=\(attestationObject.sfsdk_stringByURLEncoding())"
        let request = RestRequest(method: .POST, baseURL: "https://\(domain)", path: "/mobile/attest/registerkey", queryParams: nil)
        request.endpoint = ""
        request.requiresAuthentication = false
        request.setCustomRequestBodyString(requestBody, contentType: kHttpPostContentType)
        
        let response = try await RestClient.sharedGlobal.send(request: request)
        print(response)
    }
}
