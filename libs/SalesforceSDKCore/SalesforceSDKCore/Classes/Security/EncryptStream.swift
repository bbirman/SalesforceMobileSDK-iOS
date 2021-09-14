//
//  EncryptStream.swift
//  SalesforceSDKCore
//
//  Created by Brianna Birman on 8/31/21.
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

enum CryptStream {
    static let chunkSize = 512
    static let sealedBoxSize = chunkSize + 28 // Overhead for each block: 12 byte nonce + 16 byte authentication tag
}

@objc(SFSDKEncryptStream)
public class EncryptStream: OutputStream {
    private var key: SymmetricKey?
    private let stream: OutputStream
    private var remainders = [UInt8]() // TODO
    private var remainder: Data?

    override public var hasSpaceAvailable: Bool {
        return stream.hasSpaceAvailable
    }

    override public init(toMemory: ()) {
        stream = OutputStream.init(toMemory: toMemory)
        super.init()
    }

    override public init(toBuffer buffer: UnsafeMutablePointer<UInt8>, capacity: Int) {
        stream = OutputStream.init(toBuffer: buffer, capacity: capacity)
        super.init()
    }

    override public init?(url: URL, append shouldAppend: Bool) {
        guard let outputStream = OutputStream.init(url: url, append: shouldAppend) else {
            return nil
        }
        self.stream = outputStream
        super.init()
    }

    @objc @available(swift, obsoleted: 1.0) // Objective-c only wrapper
    public func setupKey(key: Data) {
        self.key = SymmetricKey(data: key)
    }

    func setupKey(key: SymmetricKey) {
        self.key = key
    }

    override public func property(forKey key: Stream.PropertyKey) -> Any? {
        return self.stream.property(forKey: key)
    }
    
    override public func open () {
        assert(key != nil, "EncryptStream - you must call setupKey first")
        self.stream.open()
    }

    override public func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        guard let key = key else { return -1 }
        
        var bufferSlice = UnsafeBufferPointer<UInt8>(start: buffer, count: len).prefix(len)
        while (!bufferSlice.isEmpty) {
            let dataBlock: Data
            let sliceSize: Int
            if let remainder = remainder {
                let slice = bufferSlice.prefix(CryptStream.chunkSize - remainder.count)
                sliceSize = slice.count
                dataBlock = remainder + Data(slice)
                self.remainder = nil
            } else {
                let slice = bufferSlice.prefix(CryptStream.chunkSize)
                sliceSize = slice.count
                dataBlock = Data(slice)
            }

            if dataBlock.count == CryptStream.chunkSize {
                do {
                    let encryptedData = try Encryptor.encrypt(data: dataBlock, using: key)
                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
                    bufferSlice = bufferSlice.dropFirst(sliceSize)
                } catch {
                    // TODO: Log
                    return -1
                }
            } else {
                remainder = dataBlock
                break
            }
        }
        return len
//
        
//        
//        let bufferPointer = UnsafeBufferPointer<UInt8>(start: buffer, count: len)
//        var bufferIndex = 0
//        while (bufferIndex < len) {
//            let dataBlock: Data
//            if let remainder = remainder {
//                let slice = bufferPointer[bufferIndex..<Swift.min(bufferIndex + CryptStream.chunkSize - remainder.count, len)]
//                bufferIndex += slice.count
//                dataBlock = remainder + Data(slice)
//                self.remainder = nil
//            } else {
//                let slice = bufferPointer[bufferIndex..<Swift.min(bufferIndex + CryptStream.chunkSize, len)]
//                bufferIndex += slice.count
//                dataBlock = Data(slice)
//            }
//
//            if dataBlock.count == CryptStream.chunkSize {
//                do {
//                    let encryptedData = try Encryptor.encrypt(data: dataBlock, using: key)
//                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
//                } catch {
//                    return -1
//                }
//            } else {
//                remainder = dataBlock
//                break
//            }
//        }
//
//        return len
        
    //======
//        let bufferPointer = UnsafeBufferPointer<UInt8>(start: buffer, count: len)
//        var bufferIndex = 0
//        while (bufferIndex < len) {
//            let dataBlock: Data
//            if let remainder = remainder {
//                let slice = bufferPointer[bufferIndex..<Swift.min(bufferIndex + CryptStream.chunkSize - remainder.count, len)]
//                bufferIndex += slice.count
//                dataBlock = remainder + Data(slice)
//                self.remainder = nil
//            } else {
//                let slice = bufferPointer[bufferIndex..<Swift.min(bufferIndex + CryptStream.chunkSize, len)]
//                bufferIndex += slice.count
//                dataBlock = Data(slice)
//            }
//
//            if dataBlock.count == CryptStream.chunkSize {
//                do {
//                    let encryptedData = try Encryptor.encrypt(data: dataBlock, using: key)
//                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
//                } catch {
//                    return -1
//                }
//            } else {
//                remainder = dataBlock
//                break
//            }
//        }
//
//        return len
       //=======
        
//        
//        let bufferP = UnsafeBufferPointer<UInt8>(start: buffer, count: len)
//        var bufferIndex = 0
//        var bufferBytesConsumed = 0
//        
//         var bufferReadSize: Int
//        
//        if let remainder = remainder {
//            bufferReadSize = Swift.min(bufferIndex + CryptStream.blockSize - remainder.count, len) - bufferIndex
//            let slice = bufferP[bufferIndex..<Swift.min(bufferIndex + CryptStream.blockSize - remainder.count, len)]
//            let dataBlock = remainder + Data(slice)
//            self.remainder = nil
//            
//            if dataBlock.count == CryptStream.blockSize {
//                do {
//                    let encryptedData = try Encryptor.encrypt(data: dataBlock, using: key)
//                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
//                    bufferBytesConsumed += bufferReadSize
//                } catch {
//                    return bufferBytesConsumed == 0 ? -1 : bufferBytesConsumed
//                }
//            } else {
//                self.remainder = dataBlock
//                return bufferReadSize
//            }
//            bufferIndex = bufferReadSize
//        }
//        
//        
//        while (bufferIndex < len) {
//            let dataBlock: Data
//            let bufferReadSize = Swift.min(bufferIndex + CryptStream.blockSize, len) - bufferIndex
//            let slice = bufferP[bufferIndex..<Swift.min(bufferIndex + CryptStream.blockSize, len)]
//            dataBlock = Data(slice)
//            bufferIndex += bufferReadSize
//
//            if dataBlock.count == CryptStream.blockSize {
//                do {
//                    let encryptedData = try Encryptor.encrypt(data: dataBlock, using: key)
//                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
//                    bufferBytesConsumed += bufferReadSize
//                } catch {
//                    return bufferBytesConsumed == 0 ? -1 : bufferBytesConsumed
//                }
//            } else {
//                remainder = dataBlock
//                break
//            }
//        }
//
//        return bufferBytesConsumed
        
//        let bufferP = UnsafeBufferPointer<UInt8>(start: buffer, count: len)
//        var bufferIndex = 0
//        var bufferBytesConsumed = 0
//        while (bufferIndex < len) {
//            let dataBlock: Data
//            let bufferReadSize: Int
//            if let remainder = remainder {
//                let sliceMaxIndex = Swift.min(bufferIndex + CryptStream.chunkSize - remainder.count, len)
//                let slice = bufferP[bufferIndex..<sliceMaxIndex]
//                bufferReadSize = sliceMaxIndex - bufferIndex
//                dataBlock = remainder + Data(slice)
//                self.remainder = nil
//            } else {
//                bufferReadSize = Swift.min(bufferIndex + CryptStream.chunkSize, len) - bufferIndex
//                let slice = bufferP[bufferIndex..<Swift.min(bufferIndex + CryptStream.chunkSize, len)]
//                dataBlock = Data(slice)
//            }
//            bufferIndex += bufferReadSize
//
//            if dataBlock.count == CryptStream.chunkSize {
//                do {
//                    let encryptedData = try Encryptor.encrypt(data: dataBlock, using: key)
//                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
//                    bufferBytesConsumed += bufferReadSize
//                } catch {
//                    return bufferBytesConsumed == 0 ? -1 : bufferBytesConsumed
//                }
//            } else {
//                remainder = dataBlock
//                break
//            }
//        }
//
//        return bufferBytesConsumed
        

        
        
        ///
//        var iterator = UnsafeBufferPointer<UInt8>(start: buffer, count: len).makeIterator()
//        var encryptBlock = remainders
//        var bytesWritten = 0
//        while let item = iterator.next() {
//            encryptBlock.append(item)
//            if encryptBlock.count == CryptStream.blockSize {
//                let data = Data(encryptBlock)
//                do {
//                    let encryptedData = try Encryptor.encrypt(data: data, using: key)
//                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
//                    encryptBlock.removeAll()
//                    bytesWritten += CryptStream.blockSize
//                } catch {
//                    return bytesWritten == 0 ? -1 : (bytesWritten - remainders.count)
//                }
//            }
//        }
//
//        if encryptBlock.count > 0 {
//            remainders = encryptBlock
//        }
//        return len
        
        ////

//        var iterator = UnsafeBufferPointer<UInt8>(start: buffer, count: len).makeIterator()
//        var writeBlock = remainders
//        var bytesRead = 0
//
//        while let item = iterator.next() {
//            writeBlock.append(item)
//            bytesRead += 1
//
//            if writeBlock.count == CryptStream.blockSize {
//                let data = Data(writeBlock)
//                do {
//                    let encryptedData = try Encryptor.encrypt(data: data, using: key)
//                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
//                    writeBlock.removeAll()
//                } catch {
//                    return bytesRead == 0 ? -1 : bytesRead // This doesn't account for last block failing -- bytesRead - blockSize?
//                }
//            }
//        }
//
//
//        if writeBlock.count > 0 {
//            remainders = writeBlock
//        }
//        return bytesRead
    
        
        //////
//        let bufferP = UnsafeBufferPointer<UInt8>(start: buffer, count: len)
//        let numberOfBlocks = len < CryptStream.blockSize ? 1 : len / CryptStream.blockSize
//        var writeCount = 0
//        for i in 0..<numberOfBlocks {
//            let slice = bufferP[i*CryptStream.blockSize..<i*CryptStream.blockSize + CryptStream.blockSize]
//            let data = Data(slice)
//            do {
//                let encryptedData = try Encryptor.encrypt(data: data, using: key)
//                stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
//                writeCount += data.count
//            } catch {
//                return writeCount == 0 ? -1 : writeCount
//            }
//        }
//        return writeCount
        /////
        
        
//        let bufferData = Data.init(bytes: buffer, count: len) // TODO: Can clean up?
//        let bufferArray = [UInt8](bufferData)
//
//        let toWrite: [UInt8]
//        if remainders.count > 0 {
//            toWrite = remainders + bufferArray
//        } else {
//            toWrite = bufferArray
//        }
//
//        let chunks = toWrite.chunked(into: CryptStream.blockSize)
//        var writeCount = 0
//        for chunk in chunks {
//            if chunk.count == CryptStream.blockSize {
//                do {
//                    let data = Data(chunk)
//                    let encryptedData = try Encryptor.encrypt(data: data, using: key)
//
//                    stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
//                    writeCount += data.count
//                } catch {
//                    // TODO: Log
//                    return writeCount == 0 ? -1 : writeCount
//                }
//            } else {
//                remainders = chunk
//            }
//        }
//        return writeCount
    }

    override public func close() {
        defer { stream.close() }
        guard let key = key else { return }

        do {
            if let remainder = remainder {
                let encryptedData = try Encryptor.encrypt(data: remainder, using: key)
                stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
            }
//            let data = Data(remainders)
//            let encryptedData = try Encryptor.encrypt(data: data, using: key)
//            stream.write([UInt8](encryptedData), maxLength: encryptedData.count)
        } catch {
            SalesforceLogger.e(EncryptStream.self, message: "Error encrypting data to stream: \(error)")
        }
    }
}
