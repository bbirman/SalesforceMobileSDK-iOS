//
//  EncryptDecryptStreamTests.swift
//  SmartStore
//
//  Created by Brianna Birman on 9/7/21.
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

class EncryptDecryptStreamTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        try encryptDecryptString("123456789", length: 9)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    
    func encryptDecryptString(_ string: String, length: Int) throws {
        let key = try KeyGenerator.symmetricKey(for: "EncryptDecryptStreamTest")
        let encryptStream = EncryptStream.init(toMemory: ())
        encryptStream.setupKey(key: key)
        encryptStream.open()
        
        let data = try XCTUnwrap(string.data(using: .utf8))
        encryptStream.write([UInt8](data), maxLength: length)
        encryptStream.close()
        
        let encryptedInMemoryResult = try XCTUnwrap(encryptStream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? Data)
        
        // Decrypt data direcly to verify
        let decryptedData = try Encryptor.decrypt(data: encryptedInMemoryResult, using: key)
        XCTAssertEqual(data, decryptedData)
        
        // Decrypt using stream
        let decryptStream = DecryptStream.init(data: encryptedInMemoryResult)
        decryptStream.setupKey(key: key)
        decryptStream.open()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: string.count)
        var resultData: Data
        while decryptStream.hasBytesAvailable {
            let result1 = decryptStream.read(buffer, maxLength: string.count)
        }
        
        
//        let result = decryptStream.read(buffer, maxLength: string.count)
//
//        print("result: \(result)")
//        let decryptStreamData = Data(bytes: buffer, count: result)
//        let string1 = String(decoding: decryptStreamData, as: UTF8.self)
//        let result1 = decryptStream.read(buffer, maxLength: string.count)
        
//        let decryptStreamData2 = Data(bytes: buffer, count: result1)
//        let string2 = String(decoding: decryptStreamData2, as: UTF8.self)
        decryptStream.close()

        
     //   XCTAssertEqual(data, decryptStreamData)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
