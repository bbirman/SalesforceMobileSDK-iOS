//
//  BriefcaseSyncDownTests.swift
//  MobileSync
//
//  Created by Brianna Birman on 4/6/22.
//  Copyright (c) 2022-present, salesforce.com, inc. All rights reserved.
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
@testable import MobileSync
import SmartStore

class BriefcaseSyncDownTests: SyncManagerTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    
    func testAllIds() throws {
//        for i in 0..<1000 {
//            let request = RestClient.shared.requestForCreate(withObjectType: "Account", fields: ["Name": "BB \(Date.timeIntervalSinceReferenceDate)"], apiVersion: nil)
//            RestClient.shared.send(request: request) { result in
//                switch result {
//                case .success(let response):
//                    print("success \(i)")
//                case .failure(let error):
//                    print("failure \(i), \(error)")
//                }
//            }
//        }
        
//
//
        let expectation = expectation(description: "test")
        let info = BriefcaseObjectInfo(soupName: "Accounts", sobjectType: "Account", fieldlist: ["Name", "Description"], idFieldName: nil, modificationDateFieldName: nil)
        let target = BriefcaseSyncDownTarget(infos: [info])

        let records = target.getAllIdsFromBriefcases(syncManager: syncManager, relayToken: nil, maxTimeStamp: 1) { result in
            switch result {
            case .success((let records, let relayToken)):
                print(records)
                print(records["Account"]?.count)
                print(relayToken)
                expectation.fulfill()
                break
            case .failure(let error):
                XCTFail("Fetch failed with error \(error)")
            }
        }

        waitForExpectations(timeout: 120)
    }

    func testStartFetch() throws {
//        let store = SmartStore.sharedGlobal(withName: "test")
//        let syncManager = try XCTUnwrap(SyncManager.sharedInstance(store: store))
        let expectation = expectation(description: "test")
        let info = BriefcaseObjectInfo(soupName: "Accounts", sobjectType: "Account", fieldlist: ["Name", "Description"], idFieldName: nil, modificationDateFieldName: nil)
        let target = BriefcaseSyncDownTarget(infos: [info])
        
        let records = target.startFetch(syncManager: syncManager, maxTimeStamp: 0) { error in
            print(error)
            XCTFail("Fetch failed with error \(error)")
        } onComplete: { result in
            print(result)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1200)
        
//        BriefcaseSyncDownTarget target = new BriefcaseSyncDownTarget(
//                    Arrays.asList(new BriefcaseObjectInfo(
//                        ACCOUNTS_SOUP,
//                        Constants.ACCOUNT,
//                        Arrays.asList(Constants.NAME, Constants.DESCRIPTION)
//                    ))
//                );
//
//                JSONArray records = target.startFetch(syncManager, 0);
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
