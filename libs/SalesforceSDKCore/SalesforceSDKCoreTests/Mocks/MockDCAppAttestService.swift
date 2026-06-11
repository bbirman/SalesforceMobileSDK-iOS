//
//  MockDCAppAttestService.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 4/17/26.
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

import Foundation
import DeviceCheck

/// Mock implementation of DCAppAttestService for testing
/// Note: This is a documentation reference for future refactoring.
/// DCAppAttestService cannot be directly mocked in the current implementation
/// because it's a concrete class from Apple's DeviceCheck framework.
///
/// To make AppAttestation testable, consider:
/// 1. Creating a protocol that wraps DCAppAttestService functionality
/// 2. Using dependency injection to provide mock implementations in tests
/// 3. Moving the actual DCAppAttestService calls to a separate service layer
///
/// Example protocol:
///
/// ```swift
/// protocol AppAttestServiceProtocol {
///     func generateKey() async throws -> String
///     func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data
///     func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data
///     var isSupported: Bool { get }
/// }
///
/// class DCAppAttestServiceWrapper: AppAttestServiceProtocol {
///     private let service = DCAppAttestService.shared
///
///     func generateKey() async throws -> String {
///         return try await service.generateKey()
///     }
///
///     func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
///         return try await service.attestKey(keyId, clientDataHash: clientDataHash)
///     }
///
///     func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
///         return try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
///     }
///
///     var isSupported: Bool {
///         return DCAppAttestService.shared.isSupported
///     }
/// }
///
/// class MockAppAttestService: AppAttestServiceProtocol {
///     var mockKeyId: String = "mockKeyId123"
///     var mockAttestationData: Data = Data([0x01, 0x02, 0x03])
///     var mockAssertionData: Data = Data([0x04, 0x05, 0x06])
///     var mockError: Error?
///     var generateKeyCallCount = 0
///     var attestKeyCallCount = 0
///     var generateAssertionCallCount = 0
///
///     func generateKey() async throws -> String {
///         generateKeyCallCount += 1
///         if let error = mockError {
///             throw error
///         }
///         return mockKeyId
///     }
///
///     func attestKey(_ keyId: String, clientDataHash: Data) async throws -> Data {
///         attestKeyCallCount += 1
///         if let error = mockError {
///             throw error
///         }
///         return mockAttestationData
///     }
///
///     func generateAssertion(_ keyId: String, clientDataHash: Data) async throws -> Data {
///         generateAssertionCallCount += 1
///         if let error = mockError {
///             throw error
///         }
///         return mockAssertionData
///     }
///
///     var isSupported: Bool {
///         return true
///     }
/// }
/// ```
///
/// This would allow testing the full AppAttestation flow with:
/// - Successful key generation
/// - Successful attestation
/// - Successful assertion generation
/// - Various DCError scenarios (featureUnsupported, invalidKey, serverUnavailable, etc.)
/// - Edge cases like concurrent operations, key rotation, etc.

// Mark: This file serves as documentation for future test improvements
// The actual AppAttestation class needs refactoring to support dependency injection
// before full integration tests can be written.
