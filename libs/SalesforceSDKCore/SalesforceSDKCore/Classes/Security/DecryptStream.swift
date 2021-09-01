//
//  DecryptStream.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 8/24/21.
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
import CryptoKit


@objc(SFSDKDecryptStream)
public class DecryptStream: InputStream {
    private var key: SymmetricKey?
    private let stream: InputStream
    private var remainders = [UInt8]()
    
    override public var hasBytesAvailable: Bool {
        return stream.hasBytesAvailable || !remainders.isEmpty
    }
    
    override public init(data: Data) {
        stream = InputStream(data: data)
        super.init()
    }
    
    override public init?(url: URL) {
        guard let stream = InputStream(url: url) else {
            return nil
        }
        self.stream = stream
        super.init()
    }
    
    @objc @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public func setupKey(key: Data) {
        self.key = SymmetricKey(data: key)
    }

    func setupKey(key: SymmetricKey) {
        self.key = key
    }
   
    override public func open() {
        assert(key != nil, "EncryptStream - you must call setupKey first")
        // TODO Log
        stream.open()
    }
    
    override public func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        guard let key = key else {
            return -1
        }
        
        let numberOfBlocks = len < CryptStream.blockSize ? 1 : len / CryptStream.blockSize
        let encryptedBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: CryptStream.sealedBoxSize)
        var readCount = 0
        for _ in 1...numberOfBlocks {
            let bytesRead = stream.read(encryptedBuffer, maxLength: CryptStream.sealedBoxSize)
            if bytesRead == 0 { break } // Backing stream is empty, don't attempt decrypt
            
            do {
                let data = Data(bytes: encryptedBuffer, count: bytesRead)
                let decryptedData = try Encryptor.decrypt(data: data, using: key)
                decryptedData.copyBytes(to: buffer.advanced(by: readCount), count: decryptedData.count)
                readCount += decryptedData.count
            } catch {
                SalesforceLogger.e(DecryptStream.self, message: "Error decrypting data to stream: \(error)")
                return readCount == 0 ? -1 : readCount
            }
        }
        return readCount
    }
    
    override public func property(forKey key: Stream.PropertyKey) -> Any? {
        return self.stream.property(forKey: key)
    }
   
    override public func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    override public func close() {
        stream.close()
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}


// let numberOfBlocks = len < encryptBlockSize ? 1 : len / encryptBlockSize
//        for _ in 1...numberOfBlocks {
//            let encryptedBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: readLength)
//            let result = stream.read(encryptedBuffer, maxLength: readLength)
//            let data = Data(bytes: encryptedBuffer, count: result)
//            do {
//                let decryptedData = try Encryptor.decrypt(data: data, using: key)
//                memcpy(buffer.advanced(by: readCount), [UInt8](decryptedData), decryptedData.count)
//                readCount += decryptedData.count
//            } catch {
//
//            }
//
//        }
//        return readCount
        
        
        // ----
//        let numberOfBlocks = len < encryptBlockSize ? 1 : len / encryptBlockSize
//        let readLength = (encryptBlockSize + tagCipherSize) * numberOfBlocks
//        var readBuffer = [UInt8](Data(bytes: buffer, count: readLength)) // How should empty buffer be created?
//        let result = stream.read(&readBuffer, maxLength: readLength)
//        let resultBuffer = Array(readBuffer.dropLast(readLength - result))
//
//        let chunks = resultBuffer.chunked(into: encryptBlockSize + tagCipherSize)
//
//        let counts = chunks.map { chunk -> Int in
//            let data = Data(chunk)
//            do {
//
//                let decryptedData = try Encryptor.decrypt(data: data, using: key!)
//               // dataToBuffer.append(decryptedData)
//                memcpy(buffer, ([UInt8](decryptedData)), decryptedData.count)
//                return decryptedData.count
//            } catch {
//                print("error: \(error)")
//                return 0 // TODO
//            }
//        }
//
//        return counts.reduce(0, +)
        // -----
        
//        for chunk in chunks {
//            let data = Data(chunk)
//            do {
//
//                let decryptedData = try Encryptor.decrypt(data: data, using: key!)
//               // dataToBuffer.append(decryptedData)
//                memcpy(buffer, ([UInt8](decryptedData)), decryptedData.count)
//            } catch {
//                print("error: \(error)")
//                return 0 // TODO
//            }
//        }
//
//        //buffer.initialize(from: [UInt8](dataToBuffer), count: dataToBuffer.count)
//        return

        
        // read amount into temporary buffer,
        // prepend remainders
        // decrypt
        // put into buffer?
        
        
        // Get data
        // Check remainders
        // Decrypt it
        // Check remainders to be
        
//
//        let remainderLength = remainders.count
//        let readLength = len - remainderLength + tagCipherSize
//        var readBuffer = [UInt8](Data(bytes: buffer, count: readLength)) // How should empty buffer be created?
//        stream.read(&readBuffer, maxLength: readLength)
//        let chunks = (remainders + readBuffer).chunked(into: encryptBlockSize + tagCipherSize)
//
//
//        var dataToBuffer: Data = Data()
//        for chunk in chunks {
//            if chunk.count == encryptBlockSize + tagCipherSize || (chunk.count < 60 && !stream.hasBytesAvailable) {
//                let data = Data(chunk)
//                do {
//                    let decryptedData = try Encryptor.decrypt(data: data, using: key!)
//                    dataToBuffer.append(decryptedData)
//                } catch {
//                    return 0 // TODO
//                }
//            } else {
//                remainders = chunk
//            }
//        }
//        buffer.initialize(from: [UInt8](dataToBuffer), count: dataToBuffer.count)
//        return dataToBuffer.count
