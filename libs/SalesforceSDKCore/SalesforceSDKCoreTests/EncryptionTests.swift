//
//  EncryptionTests.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 2/9/21.
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

import XCTest
@testable import SalesforceSDKCore
import CryptoKit

class EncryptionTests: XCTestCase {

    override func setUpWithError() throws {
        _ = KeychainHelper.removeAll()
    }
    
    func testVanillaStream() throws {
        let stream = OutputStream(toMemory: ())
        stream.open()
        let string = "1"
        let data1 = [UInt8](string.utf8)
        let output = stream.write(data1, maxLength: 1)
        print("BBOUTPUT \(output)")
    }
    
    func testStreamMisc() throws {
        let key = try KeyGenerator.symmetricKey(for: "bbtest1")
        let stream = EncryptStream.init(toMemory: ())
        stream.setupKey(key: key)
        stream.open()
        
        let string = String(repeating: "abcdef", count: 1)
        let data = try XCTUnwrap(string.data(using: .utf8))
     
        stream.write([UInt8](data), maxLength: 4) // 1000000 = 9.325, 9.608, 9.380.
        stream.write([UInt8](data[4...]), maxLength: 2)
        stream.close()
        
        let encryptedInMemoryResult = try XCTUnwrap(stream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? Data)
        let decryptedData = try Encryptor.decrypt(data: encryptedInMemoryResult, using: key)
        let decryptedString = String(decoding: decryptedData, as: UTF8.self)
        XCTAssertEqual(string, decryptedString)
    }
    
    
    // TODO:
    // - Test opening + closing
    // - Test length of buffer is shorter than data to read out into it
    
    func testStream() throws {
        let key = try KeyGenerator.symmetricKey(for: "bbtest1")
        //let stream1 = OutputStream.toMemory()
        let stream = EncryptStream.init(toMemory: ())
        stream.setupKey(key: key)
        stream.open()
        let string = String(repeating: "abcdefghijklmnopqrstuvwxyz123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ!@#$%^&*()", count: 1000000)
        let data = string.data(using: .utf8)

        let data1 = [UInt8](string.utf8)
        self.measure {
            stream.write(data1, maxLength: data1.count) // 1000000 = 9.325, 9.608, 9.380.
            stream.close()
        }
        //stream.write(UnsafePointer<UInt8>(data1.bytes), maxLength: data1.length)
        
       // stream.write(thingy, maxLength: data!.count)
        
        
        let encryptedInMemoryResult = stream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? Data

        let decryptStream = DecryptStream.init(data: encryptedInMemoryResult!)
        decryptStream.setupKey(key: key)
        decryptStream.open()
        var buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: string.count)
        let result = decryptStream.read(buffer, maxLength: string.count)
        
        print("result: \(result)")
        let decryptStreamData = Data(bytes: buffer, count: result)
        let string1 = String(decoding: decryptStreamData, as: UTF8.self)
        let result1 = decryptStream.read(buffer, maxLength: string.count)
        
        let decryptStreamData2 = Data(bytes: buffer, count: result1)
        let string2 = String(decoding: decryptStreamData2, as: UTF8.self)
        decryptStream.close()

        
        XCTAssertEqual(data, decryptStreamData + decryptStreamData2)
    }
    
    func testSealedBox() throws {
        // 12 byte nonce
        // 16 byte tag
    }
    
    
    func testEncryptDecrypt() throws {
        let key = try KeyGenerator.encryptionKey(for: "test1")
        XCTAssertNotNil(key)
        let sensitiveInfo = ""
        let sensitiveData = try XCTUnwrap(sensitiveInfo.data(using: .utf8))
        let encryptedData = try Encryptor.encrypt(data: sensitiveData, using: key)
        XCTAssertNotEqual(sensitiveData, encryptedData)
        
        let keyAgain = try KeyGenerator.encryptionKey(for: "test1")
        XCTAssertEqual(key, keyAgain)
        
        let decryptedData = try Encryptor.decrypt(data: encryptedData, using: keyAgain)
        let decryptedString = String(data: decryptedData, encoding: .utf8)
        
        XCTAssertEqual(decryptedString, sensitiveInfo)
    }
    
    func testEncryptDecryptWrongKey() throws {
        let key = try KeyGenerator.encryptionKey(for: "test1")
        XCTAssertNotNil(key)
        let sensitiveInfo = "My sensitive info"
        let sensitiveData = try XCTUnwrap(sensitiveInfo.data(using: .utf8))
        let encryptedData = try Encryptor.encrypt(data: sensitiveData, using: key)
        XCTAssertNotEqual(sensitiveData, encryptedData)
        
        let differentKey = try KeyGenerator.encryptionKey(for: "test2")
        XCTAssertNotEqual(key, differentKey)
        
        XCTAssertThrowsError(try Encryptor.decrypt(data: encryptedData, using: differentKey))
    }
    
    func testKeyRetrieval() throws {
        let key = try KeyGenerator.encryptionKey(for: "test1")
        XCTAssertNotNil(key)
        let keyAgain = try KeyGenerator.encryptionKey(for: "test1")
        XCTAssertEqual(key, keyAgain)
        
        let differentKey = try KeyGenerator.encryptionKey(for: "test2")
        XCTAssertNotNil(differentKey)
        XCTAssertNotEqual(key, differentKey)
    }
}
