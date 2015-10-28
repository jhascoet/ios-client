//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "ClientManager.h"
#import "LDUserBuilder.h"
#import "LDClient.h"
#import <OCMock.h>
#import "RequestManager.h"
#import "DataManager.h"
#import "Event.h"
#import <Blockskit.h>

@interface ClientManagerTest : DarklyXCTestCase
@property (nonatomic) NSData *jsonData;
@property (nonatomic) id requestManagerMock;
@end


@implementation ClientManagerTest
@synthesize jsonData;
@synthesize requestManagerMock;

- (void)setUp {
    [super setUp];
    User *user = [[User alloc] init];
    user.key = @"jeff@test.com";
    user.os = @"80400";
    user.device = @"iPhone";
    
    Event *event = [[Event alloc] init];
    [event featureEventWithKey:@"blah" keyValue:NO defaultKeyValue:NO];
    
    NSArray *eventArray = @[event];
    NSArray *eventJsonDictArray = [eventArray bk_map:^id(Event *event) {
        return [MTLJSONAdapter JSONDictionaryFromModel:event error: nil];
    }];
    
    jsonData = [NSJSONSerialization dataWithJSONObject:eventJsonDictArray
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    
    OCMStub([self.dataManagerMock allEventsJsonData]).andReturn(jsonData);
    [self.dataManagerMock saveContext];
    
    id ldClientMock = OCMClassMock([LDClient class]);
    OCMStub(ClassMethod([ldClientMock sharedInstance])).andReturn(ldClientMock);
    OCMStub([ldClientMock user]).andReturn(user);
    
    requestManagerMock = OCMClassMock([RequestManager class]);
    OCMStub(ClassMethod([requestManagerMock sharedInstance])).andReturn(requestManagerMock);
    OCMStub([requestManagerMock performFeatureFlagRequest:[OCMArg isKindOfClass:[NSString class]]]);
    OCMStub([requestManagerMock performEventRequest:[OCMArg any]]);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSyncWithServerForConfig {
    // {"lastName":null, "firstName":null, "anonymous":false, "key":"jeff@test.com", "avatar":null,
    //        "os":"80400", "ip":null, "custom":null, "config":null, "country":null, "email":null,
    //    "device":"iPhone"}
    NSString *encodedUserString = @"eyJsYXN0TmFtZSI6bnVsbCwiZmlyc3ROYW1lIjpudWxsLCJhbm9ueW1vdXMiOmZhbHNlLCJrZXkiOiJqZWZmQHRlc3QuY29tIiwiYXZhdGFyIjpudWxsLCJvcyI6IjgwNDAwIiwiaXAiOm51bGwsImN1c3RvbSI6bnVsbCwiY29uZmlnIjpudWxsLCJjb3VudHJ5IjpudWxsLCJlbWFpbCI6bnVsbCwiZGV2aWNlIjoiaVBob25lIn0=";
    
    ClientManager *clientManager = [ClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    [clientManager syncWithServerForConfig];

    OCMVerify([requestManagerMock performFeatureFlagRequest:[OCMArg isEqual:encodedUserString]]);
    
    [requestManagerMock stopMocking];
    
}

- (void)testSyncWithServerForEvents {
    ClientManager *clientManager = [ClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    
    OCMStub([self.dataManagerMock allEventsJsonData]).andReturn(jsonData);
    
    [clientManager syncWithServerForEvents];
    
    OCMVerify([requestManagerMock performFeatureFlagRequest:[OCMArg isEqual:jsonData]]);
    
    [requestManagerMock stopMocking];
}

- (void)testSyncWithServerForConfigNotProcessedWhenOffline {
    // {"lastName":null, "firstName":null, "anonymous":false, "key":"jeff@test.com", "avatar":null,
    //        "os":"80400", "ip":null, "custom":null, "config":null, "country":null, "email":null,
    //    "device":"iPhone"}
    NSString *encodedUserString = @"eyJsYXN0TmFtZSI6bnVsbCwiZmlyc3ROYW1lIjpudWxsLCJhbm9ueW1vdXMiOmZhbHNlLCJrZXkiOiJqZWZmQHRlc3QuY29tIiwiYXZhdGFyIjpudWxsLCJvcyI6IjgwNDAwIiwiaXAiOm51bGwsImN1c3RvbSI6bnVsbCwiY29uZmlnIjpudWxsLCJjb3VudHJ5IjpudWxsLCJlbWFpbCI6bnVsbCwiZGV2aWNlIjoiaVBob25lIn0=";
    
    ClientManager *clientManager = [ClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];
    
    [clientManager syncWithServerForConfig];
    
    [requestManagerMock verify];
    [requestManagerMock stopMocking];
}


- (void)testSyncWithServerForEventsNotProcessedWhenOffline {
    ClientManager *clientManager = [ClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];    
    [clientManager syncWithServerForEvents];
    
    [requestManagerMock verify];
    [requestManagerMock stopMocking];
}

- (void)testSyncWithServerForEventsWhenFlushCalled {
    ClientManager *clientManager = [ClientManager sharedInstance];
    [clientManager setOfflineEnabled:NO];
    [clientManager flushEvents];
    
    OCMVerify([requestManagerMock performEventRequest:[OCMArg isEqual:jsonData]]);
    
    [requestManagerMock stopMocking];
}

- (void)testSyncWithServerForEventsNotProcessedWhenOfflineWhenFlushCalled {
    ClientManager *clientManager = [ClientManager sharedInstance];
    [clientManager setOfflineEnabled:YES];
    
    [[requestManagerMock reject] performEventRequest:[OCMArg isKindOfClass:[NSData class]]];
    
    [clientManager flushEvents];
    
    [requestManagerMock verify];
    [requestManagerMock stopMocking];
}
@end
