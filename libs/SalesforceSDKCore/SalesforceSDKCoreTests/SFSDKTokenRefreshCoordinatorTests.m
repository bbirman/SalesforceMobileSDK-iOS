/*
 Copyright (c) 2025-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import "SFSDKTokenRefreshCoordinator.h"
#import "SalesforceSDKConstants.h"
SFSDK_USE_DEPRECATED_BEGIN
#import "SFOAuthSessionRefresher+Internal.h"
SFSDK_USE_DEPRECATED_END
#import "SFOAuthCredentials+Internal.h"
#import "SFUserAccountManager.h"
#import "SFSDKOAuth2.h"

// Suppress deprecation warnings throughout this test file — tests legitimately
// subclass and instantiate SFOAuthSessionRefresher for mock injection.
SFSDK_USE_DEPRECATED_BEGIN

// Delay to allow the coordinator's serial queue to process dispatched blocks
// before test assertions run. The 0.1s value is generous for work that takes
// microseconds — it simply needs to exceed one main-queue run-loop tick.
#define kDispatchDelay (int64_t)(0.1 * NSEC_PER_SEC)

// Expose internal initializer for test use
@interface SFSDKOAuthTokenEndpointResponse (TestInit)
- (instancetype)initWithDictionary:(NSDictionary *)dict parseAdditionalFields:(NSArray<NSString *> *)additionalFields;
@end

#pragma mark - Mock Session Refresher

/**
 * A mock SFOAuthSessionRefresher that captures the refresh call and allows
 * tests to manually trigger success or failure. Simulates credential mutation
 * and notification posting like the real implementation.
 */
@interface MockSessionRefresher : SFOAuthSessionRefresher

@property (atomic, assign) NSInteger refreshCallCount;
@property (nonatomic, copy) void (^capturedCompletion)(SFOAuthCredentials *);
@property (nonatomic, copy) void (^capturedError)(NSError *);
@property (nonatomic, copy, nullable) NSString *simulatedNewAccessToken;
@property (nonatomic, copy, nullable) NSString *simulatedNewRefreshToken;

- (void)simulateSuccessWithNewAccessToken:(NSString *)accessToken refreshToken:(nullable NSString *)refreshToken;
- (void)simulateSuccess;
- (void)simulateFailureWithError:(NSError *)error;

@end

@implementation MockSessionRefresher

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)refreshSessionWithCompletion:(void (^)(SFOAuthCredentials *))completionBlock error:(void (^)(NSError *))errorBlock {
    self.refreshCallCount++;
    self.capturedCompletion = completionBlock;
    self.capturedError = errorBlock;
}
#pragma clang diagnostic pop

- (void)simulateSuccessWithNewAccessToken:(NSString *)accessToken refreshToken:(nullable NSString *)refreshToken {
    // Mutate credentials in-place, like the real SFOAuthSessionRefresher does
    self.credentials.accessToken = accessToken;
    if (refreshToken) {
        self.credentials.refreshToken = refreshToken;
    }

    // Post the notification like the real implementation
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    [[NSNotificationCenter defaultCenter] postNotificationName:kSFNotificationUserDidRefreshToken
                                                        object:self
                                                      userInfo:userInfo];

    if (self.capturedCompletion) {
        self.capturedCompletion(self.credentials);
    }
}

- (void)simulateSuccess {
    [self simulateSuccessWithNewAccessToken:@"new_access_token" refreshToken:@"new_refresh_token"];
}

- (void)simulateFailureWithError:(NSError *)error {
    if (self.capturedError) {
        self.capturedError(error);
    }
}

@end

#pragma mark - Mock OAuth Protocol (for integration tests)

@interface MockAuthClient : NSObject <SFSDKOAuthProtocol>
@property (atomic, assign) NSInteger accessTokenForRefreshCallCount;
@property (nonatomic, copy, nullable) NSDictionary *responseDict;
@end

@implementation MockAuthClient

- (void)accessTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {
    self.accessTokenForRefreshCallCount++;

    // Build a minimal success response dictionary
    NSDictionary *dict = self.responseDict ?: @{
        @"access_token": @"integration_new_access_token",
        @"refresh_token": @"integration_new_refresh_token",
        @"instance_url": @"https://test.salesforce.com",
        @"id": @"https://test.salesforce.com/id/orgId/userId",
        @"issued_at": @"1234567890"
    };
    SFSDKOAuthTokenEndpointResponse *response = [[SFSDKOAuthTokenEndpointResponse alloc] initWithDictionary:dict parseAdditionalFields:@[]];
    completionBlock(response);
}

- (void)accessTokenForApprovalCode:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(SFSDKOAuthTokenEndpointResponse *))completionBlock {
    // Not needed for these tests
}

- (void)openIDTokenForRefresh:(SFSDKOAuthTokenEndpointRequest *)endpointReq completion:(void (^)(NSString *))completionBlock {
    // Not needed for these tests
}

- (void)revokeRefreshToken:(SFOAuthCredentials *)credentials reason:(SFLogoutReason)reason {
    // Not needed for these tests
}

@end

#pragma mark - Tests

@interface SFSDKTokenRefreshCoordinatorTests : XCTestCase

@property (nonatomic, strong) SFSDKTokenRefreshCoordinator *coordinator;
@property (nonatomic, strong) MockSessionRefresher *mockRefresher;
@property (nonatomic, strong) SFOAuthCredentials *credentials;

@end

@implementation SFSDKTokenRefreshCoordinatorTests

- (void)setUp {
    [super setUp];
    self.coordinator = [[SFSDKTokenRefreshCoordinator alloc] init];

    NSString *identifier = [NSString stringWithFormat:@"TestCreds_%u", arc4random()];
    self.credentials = [[SFOAuthCredentials alloc] initWithIdentifier:identifier clientId:@"TestClientId" encrypted:YES];
    self.credentials.refreshToken = @"test_refresh_token";
    self.credentials.accessToken = @"test_access_token";
    self.credentials.instanceUrl = [NSURL URLWithString:@"https://test.salesforce.com"];
    self.credentials.redirectUri = @"testapp://callback";

    __weak typeof(self) weakSelf = self;
    self.coordinator.refresherFactory = ^SFOAuthSessionRefresher *(SFOAuthCredentials *creds) {
        weakSelf.mockRefresher = [[MockSessionRefresher alloc] initWithCredentials:creds];
        return weakSelf.mockRefresher;
    };
}

- (void)tearDown {
    self.coordinator.refresherFactory = nil;
    self.coordinator = nil;
    self.mockRefresher = nil;
    [self.credentials revoke];
    self.credentials = nil;
    [super tearDown];
}

#pragma mark - Basic Refresh Tests

- (void)testSingleCallerSuccess {
    XCTestExpectation *completionExp = [self expectationWithDescription:@"Completion called"];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        XCTAssertNotNil(updated);
        XCTAssertEqualObjects(updated.accessToken, @"new_access_token");
        [completionExp fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Should not receive error");
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
        XCTAssertEqual(self.mockRefresher.refreshCallCount, 1);
        [self.mockRefresher simulateSuccess];
    });

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testSingleCallerFailure {
    XCTestExpectation *errorExp = [self expectationWithDescription:@"Error called"];
    NSError *expectedError = [NSError errorWithDomain:@"test" code:42 userInfo:nil];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        XCTFail(@"Should not receive completion");
    } error:^(NSError *error) {
        XCTAssertEqual(error.code, 42);
        [errorExp fulfill];
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
        [self.mockRefresher simulateFailureWithError:expectedError];
    });

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

#pragma mark - Credential Mutation Tests

- (void)testAllWaitersReceiveUpdatedCredentials {
    NSString *expectedAccessToken = @"rotated_access_token";
    NSString *expectedRefreshToken = @"rotated_refresh_token";

    XCTestExpectation *completion1 = [self expectationWithDescription:@"Completion 1"];
    XCTestExpectation *completion2 = [self expectationWithDescription:@"Completion 2"];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        XCTAssertEqualObjects(updated.accessToken, expectedAccessToken);
        XCTAssertEqualObjects(updated.refreshToken, expectedRefreshToken);
        [completion1 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #1: %@", error.localizedDescription);
    }];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        XCTAssertEqualObjects(updated.accessToken, expectedAccessToken);
        XCTAssertEqualObjects(updated.refreshToken, expectedRefreshToken);
        [completion2 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #2: %@", error.localizedDescription);
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
        [self.mockRefresher simulateSuccessWithNewAccessToken:expectedAccessToken
                                                refreshToken:expectedRefreshToken];
    });

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

#pragma mark - Notification Tests

- (void)testNotificationPostedExactlyOnceForCoalescedRefresh {
    __block NSInteger notificationCount = 0;
    id observer = [[NSNotificationCenter defaultCenter]
                   addObserverForName:kSFNotificationUserDidRefreshToken
                   object:nil
                   queue:[NSOperationQueue mainQueue]
                   usingBlock:^(NSNotification *note) {
        notificationCount++;
    }];

    XCTestExpectation *completion1 = [self expectationWithDescription:@"Completion 1"];
    XCTestExpectation *completion2 = [self expectationWithDescription:@"Completion 2"];
    XCTestExpectation *completion3 = [self expectationWithDescription:@"Completion 3"];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        [completion1 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #1: %@", error.localizedDescription);
    }];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        [completion2 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #2: %@", error.localizedDescription);
    }];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        [completion3 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #3: %@", error.localizedDescription);
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
        [self.mockRefresher simulateSuccess];
    });

    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    // Give run loop a tick to deliver any additional notifications
    XCTestExpectation *drain = [self expectationWithDescription:@"Drain runloop"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
        XCTAssertEqual(notificationCount, 1, @"Notification should fire exactly once for one refresh, regardless of waiter count");
        [drain fulfill];
    });
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

#pragma mark - Coalescing Tests

- (void)testMultipleCallersCoalesceIntoSingleRefresh {
    XCTestExpectation *completion1 = [self expectationWithDescription:@"Completion 1"];
    XCTestExpectation *completion2 = [self expectationWithDescription:@"Completion 2"];
    XCTestExpectation *completion3 = [self expectationWithDescription:@"Completion 3"];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        [completion1 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #1: %@", error.localizedDescription);
    }];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        [completion2 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #2: %@", error.localizedDescription);
    }];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        [completion3 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #3: %@", error.localizedDescription);
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
        XCTAssertEqual(self.mockRefresher.refreshCallCount, 1);
        [self.mockRefresher simulateSuccess];
    });

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testMultipleCallersAllReceiveError {
    XCTestExpectation *error1 = [self expectationWithDescription:@"Error 1"];
    XCTestExpectation *error2 = [self expectationWithDescription:@"Error 2"];
    NSError *expectedError = [NSError errorWithDomain:@"test" code:99 userInfo:nil];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        XCTFail(@"Completion 1");
    } error:^(NSError *error) {
        XCTAssertEqual(error.code, 99);
        [error1 fulfill];
    }];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        XCTFail(@"Completion 2");
    } error:^(NSError *error) {
        XCTAssertEqual(error.code, 99);
        [error2 fulfill];
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
        [self.mockRefresher simulateFailureWithError:expectedError];
    });

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

#pragma mark - Independent Credentials Tests

- (void)testDifferentCredentialsRefreshIndependently {
    NSString *identifier2 = [NSString stringWithFormat:@"TestCreds2_%u", arc4random()];
    SFOAuthCredentials *credentials2 = [[SFOAuthCredentials alloc] initWithIdentifier:identifier2 clientId:@"TestClient2" encrypted:YES];
    credentials2.refreshToken = @"refresh_token_2";
    credentials2.accessToken = @"access_token_2";
    credentials2.instanceUrl = [NSURL URLWithString:@"https://test2.salesforce.com"];
    credentials2.redirectUri = @"testapp2://callback";

    __block NSInteger factoryCallCount = 0;
    __block MockSessionRefresher *refresher1 = nil;
    __block MockSessionRefresher *refresher2 = nil;

    self.coordinator.refresherFactory = ^SFOAuthSessionRefresher *(SFOAuthCredentials *creds) {
        factoryCallCount++;
        MockSessionRefresher *refresher = [[MockSessionRefresher alloc] initWithCredentials:creds];
        if (factoryCallCount == 1) {
            refresher1 = refresher;
        } else {
            refresher2 = refresher;
        }
        return refresher;
    };

    XCTestExpectation *comp1 = [self expectationWithDescription:@"Completion for creds 1"];
    XCTestExpectation *comp2 = [self expectationWithDescription:@"Completion for creds 2"];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        [comp1 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #1: %@", error.localizedDescription);
    }];

    [self.coordinator refreshSessionForCredentials:credentials2
                                        completion:^(SFOAuthCredentials *updated) {
        [comp2 fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #2: %@", error.localizedDescription);
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
        XCTAssertEqual(factoryCallCount, 2);
        XCTAssertEqual(refresher1.refreshCallCount, 1);
        XCTAssertEqual(refresher2.refreshCallCount, 1);
        [refresher1 simulateSuccess];
        [refresher2 simulateSuccess];
    });

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
    [credentials2 revoke];
}

- (void)testNewCallAfterCompletionStartsFreshRefresh {
    XCTestExpectation *firstCompletion = [self expectationWithDescription:@"First completion"];
    XCTestExpectation *secondCompletion = [self expectationWithDescription:@"Second completion"];

    [self.coordinator refreshSessionForCredentials:self.credentials
                                        completion:^(SFOAuthCredentials *updated) {
        [firstCompletion fulfill];
    } error:^(NSError *error) {
        XCTFail(@"Error on refresh #1: %@", error.localizedDescription);
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
        XCTAssertEqual(self.mockRefresher.refreshCallCount, 1);
        [self.mockRefresher simulateSuccess];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
            [self.coordinator refreshSessionForCredentials:self.credentials
                                                completion:^(SFOAuthCredentials *updated) {
                [secondCompletion fulfill];
            } error:^(NSError *error) {
                XCTFail(@"Error on refresh #2: %@", error.localizedDescription);
            }];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kDispatchDelay), dispatch_get_main_queue(), ^{
                // A NEW refresher was created (count is 1 on the new instance)
                XCTAssertEqual(self.mockRefresher.refreshCallCount, 1);
                [self.mockRefresher simulateSuccess];
            });
        });
    });

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Thread Safety Stress Test

- (void)testConcurrentCallsDoNotCrashAndCoalesce {
    XCTestExpectation *allDone = [self expectationWithDescription:@"All concurrent calls completed"];
    allDone.expectedFulfillmentCount = 50;

    for (int i = 0; i < 50; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.coordinator refreshSessionForCredentials:self.credentials
                                                completion:^(SFOAuthCredentials *updated) {
                [allDone fulfill];
            } error:^(NSError *error) {
                XCTFail("Error on refresh: %@", error.localizedDescription);
            }];
        });
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // refreshCallCount is atomic, safe to read from main
        XCTAssertEqual(self.mockRefresher.refreshCallCount, 1,
                       @"Only one refresh should have been initiated despite 50 concurrent calls");
        [self.mockRefresher simulateSuccess];
    });

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

#pragma mark - Nil Identifier Test

- (void)testNilIdentifierCredentialsReturnsError {
    SFOAuthCredentials *nilIdCreds = [[SFOAuthCredentials alloc] init];

    XCTestExpectation *errorExp = [self expectationWithDescription:@"Error for nil identifier"];

    [self.coordinator refreshSessionForCredentials:nilIdCreds
                                        completion:^(SFOAuthCredentials *updated) {
        XCTFail(@"Should not succeed");
    } error:^(NSError *error) {
        XCTAssertNotNil(error);
        [errorExp fulfill];
    }];

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

#pragma mark - Integration Test (Mock at authClient level)

- (void)testIntegrationSingleNetworkCallForConcurrentRefreshes {
    // This test verifies that when multiple callers go through
    // SFUserAccountManager.refreshCredentials: concurrently,
    // only ONE network call (accessTokenForRefresh:) is made.

    // Use the real coordinator singleton for this test
    SFSDKTokenRefreshCoordinator *realCoordinator = [SFSDKTokenRefreshCoordinator sharedInstance];

    // Inject a mock authClient that counts calls
    MockAuthClient *mockClient = [[MockAuthClient alloc] init];
    SFAuthClientFactoryBlock originalFactory = [SFUserAccountManager sharedInstance].authClient;
    [SFUserAccountManager sharedInstance].authClient = ^id<SFSDKOAuthProtocol> {
        return mockClient;
    };

    // Use the real refresher (not our test mock) to exercise the full path
    realCoordinator.refresherFactory = nil;

    // Create credentials for this integration test
    NSString *integrationId = [NSString stringWithFormat:@"IntegrationCreds_%u", arc4random()];
    SFOAuthCredentials *integrationCreds = [[SFOAuthCredentials alloc] initWithIdentifier:integrationId clientId:@"IntegClientId" encrypted:YES];
    integrationCreds.refreshToken = @"integration_refresh_token";
    integrationCreds.accessToken = @"old_access_token";
    integrationCreds.instanceUrl = [NSURL URLWithString:@"https://test.salesforce.com"];
    integrationCreds.redirectUri = @"testapp://callback";

    XCTestExpectation *allDone = [self expectationWithDescription:@"All concurrent refreshes completed"];
    allDone.expectedFulfillmentCount = 5;

    // Fire 5 concurrent refreshes through the coordinator
    for (int i = 0; i < 5; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [realCoordinator refreshSessionForCredentials:integrationCreds
                                              completion:^(SFOAuthCredentials *updated) {
                XCTAssertEqualObjects(updated.accessToken, @"integration_new_access_token");
                [allDone fulfill];
            } error:^(NSError *error) {
                XCTFail(@"Integration refresh should not fail: %@", error);
                [allDone fulfill];
            }];
        });
    }

    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // THE KEY ASSERTION: Only one network call was made
    XCTAssertEqual(mockClient.accessTokenForRefreshCallCount, 1,
                   @"Only one accessTokenForRefresh: call should have been made despite 5 concurrent callers");

    // Cleanup
    [SFUserAccountManager sharedInstance].authClient = originalFactory;
    realCoordinator.refresherFactory = nil;
    [integrationCreds revoke];
}

@end

SFSDK_USE_DEPRECATED_END
