// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


@import XCTest;

#import "ZMPersistentCookieStorage.h"



@interface ZMPersistentCookieStorageTests : XCTestCase

@property (nonatomic) ZMPersistentCookieStorage *sut;

@end



@implementation ZMPersistentCookieStorageTests

- (BOOL)shouldUseRealKeychain;
{
    return (TARGET_IPHONE_SIMULATOR) || !(TARGET_OS_IPHONE);
}

- (void)setUp
{
    [super setUp];
    self.sut = [ZMPersistentCookieStorage storageForServerName:@"1.example.com"];
    
}

- (void)tearDown
{
    [super tearDown];
    [self.sut deleteUserKeychainItems];
    self.sut = nil;
}

- (void)testThatItDoesNotHaveACookie;
{
    XCTAssertNil(self.sut.authenticationCookieData);
}

- (void)testThatItStoresTheCookie;
{
    XCTAssertNil(self.sut.authenticationCookieData);
    NSData *data = [NSData dataWithBytes:(char []){'a'} length:1];
    [self.sut setAuthenticationCookieData:data];
    XCTAssertNotNil(self.sut.authenticationCookieData);
    XCTAssertEqualObjects(self.sut.authenticationCookieData, data);
}

- (void)testThatItUpdatesTheCookie;
{
    XCTAssertNil(self.sut.authenticationCookieData);

    NSData *data1 = [NSData dataWithBytes:(char []){'a'} length:1];
    [self.sut setAuthenticationCookieData:data1];
    XCTAssertEqualObjects(self.sut.authenticationCookieData, data1);
    
    NSData *data2 = [NSData dataWithBytes:(char []){'B'} length:1];
    [self.sut setAuthenticationCookieData:data2];
    XCTAssertEqualObjects(self.sut.authenticationCookieData, data2);
}

- (void)testThatItIsUniqueForServerName;
{
    ZMPersistentCookieStorage *sut1 = self.sut;
    ZMPersistentCookieStorage *sut2 = [ZMPersistentCookieStorage storageForServerName:@"2.example.com"];
    XCTAssertNil([sut1 authenticationCookieData]);
    XCTAssertNil([sut2 authenticationCookieData]);
    
    NSData *data1 = [NSData dataWithBytes:(char []){'a'} length:1];
    [sut1 setAuthenticationCookieData:data1];
    NSData *data2 = [NSData dataWithBytes:(char []){'b'} length:1];
    [sut2 setAuthenticationCookieData:data2];
    
    XCTAssertEqualObjects([sut1 authenticationCookieData], data1);
    XCTAssertEqualObjects([sut2 authenticationCookieData], data2);
    [sut2 deleteUserKeychainItems];
}

- (void)testThatItCanDeleteCookies;
{
    XCTAssertNil(self.sut.authenticationCookieData);
    
    NSData *data = [NSData dataWithBytes:(char []){'a'} length:1];
    [self.sut setAuthenticationCookieData:data];
    XCTAssertNotNil(self.sut.authenticationCookieData);
    [self.sut setAuthenticationCookieData:nil];
    XCTAssertNil(self.sut.authenticationCookieData);
}

- (void)testThatItPersistsCookies;
{
    NSData *data = [NSData dataWithBytes:(char []){'a'} length:1];
    @autoreleasepool {
        ZMPersistentCookieStorage *sut1 = self.sut;
        [sut1 setAuthenticationCookieData:data];
    }
    {
        ZMPersistentCookieStorage *sut2 = self.sut;
        XCTAssertEqualObjects([sut2 authenticationCookieData], data);
    }
}

- (void)testThatItCanDeleteAllCookies
{
    // given
    ZMPersistentCookieStorage *sut1 = [ZMPersistentCookieStorage storageForServerName:@"z1.example.com"];
    ZMPersistentCookieStorage *sut2 = [ZMPersistentCookieStorage storageForServerName:@"z2.example.com"];
    NSData *data = [@"This is cookie data" dataUsingEncoding:NSUTF8StringEncoding];
    [sut1 setAuthenticationCookieData:data];
    XCTAssertNotNil(sut1.authenticationCookieData);
    [sut2 setAuthenticationCookieData:data];
    XCTAssertNotNil(sut2.authenticationCookieData);
    
    // when
    [sut1 deleteUserKeychainItems];
    [sut2 deleteUserKeychainItems];
    
    // then
    XCTAssertEqualObjects(sut1.authenticationCookieData, nil);
    XCTAssertEqualObjects(sut2.authenticationCookieData, nil);
}

@end



@implementation ZMPersistentCookieStorageTests (HTTPCookie)

- (void)testThatWeCanRetrieveTheCookie;
{
    // given
    XCTAssertNil(self.sut.authenticationCookieData);
    
    NSDictionary *headerFields = @{@"Date": @"Thu, 24 Jul 2014 09:06:45 GMT",
                                   @"Content-Encoding": @"gzip",
                                   @"Server": @"nginx",
                                   @"Content-Type": @"application/json",
                                   @"Access-Control-Allow-Origin": @"file://",
                                   @"Connection": @"keep-alive",
                                   @"Set-Cookie": @"zuid=wjCWn1Y1pBgYrFCwuU7WK2eHpAVY8Ocu-rUAWIpSzOcvDVmYVc9Xd6Ovyy-PktFkamLushbfKgBlIWJh6ZtbAA==.1721442805.u.7eaaa023.08326f5e-3c0f-4247-a235-2b4d93f921a4; Expires=Sun, 21-Jul-2024 09:06:45 GMT; Domain=wire.com; HttpOnly; Secure",
                                   @"Content-Length": @"214"};
    NSURL *URL = [NSURL URLWithString:@"http://zeta.example.com/login"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];
    [self.sut setCookieDataFromResponse:response forURL:URL];
    XCTAssertNotNil(self.sut.authenticationCookieData);
    
    // when
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:URL];
    [self.sut setRequestHeaderFieldsOnRequest:request];
    
    // then
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Cookie"],
                          @"zuid=wjCWn1Y1pBgYrFCwuU7WK2eHpAVY8Ocu-rUAWIpSzOcvDVmYVc9Xd6Ovyy-PktFkamLushbfKgBlIWJh6ZtbAA==.1721442805.u.7eaaa023.08326f5e-3c0f-4247-a235-2b4d93f921a4");
}



- (void)testThatItDoesNotSetACookieDataIfNewCookieIsInvalid;
{
    // given
    XCTAssertNil(self.sut.authenticationCookieData);
    self.sut.authenticationCookieData = [@"previous-cookie" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *headerFields = @{@"Date": @"Thu, 24 Jul 2014 09:06:45 GMT",
                                   @"Content-Encoding": @"gzip",
                                   @"Server": @"nginx",
                                   @"Content-Type": @"application/json",
                                   @"Access-Control-Allow-Origin": @"file://",
                                   @"Connection": @"keep-alive",
                                   @"Set-Cookie": @"UTTER GARBAGE",
                                   @"Content-Length": @"214"};
    NSURL *URL = [NSURL URLWithString:@"http://zeta.example.com/login"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];
    
    // when
    [self.sut setCookieDataFromResponse:response forURL:URL];
    
    // then
    XCTAssertNotNil(self.sut.authenticationCookieData);
}

- (void)testThatItDoesNotStoreNotAuthCookies
{
    // given
    XCTAssertNil(self.sut.authenticationCookieData);
    
    NSDictionary *headerFields = @{@"Date": @"Thu, 24 Jul 2014 09:06:45 GMT",
                                   @"Content-Encoding": @"gzip",
                                   @"Server": @"nginx",
                                   @"Content-Type": @"application/json",
                                   @"Access-Control-Allow-Origin": @"file://",
                                   @"Connection": @"keep-alive",
                                   @"Set-Cookie": @"zuid.challenge=wjCWn1Y1pBgYrFCwuU7WK2eHpAVY8Ocu-rUAWIpSzOcvDVmYVc9Xd6Ovyy-PktFkamLushbfKgBlIWJh6ZtbAA==.1721442805.u.7eaaa023.08326f5e-3c0f-4247-a235-2b4d93f921a4; Expires=Sun, 21-Jul-2024 09:06:45 GMT; Domain=wire.com; HttpOnly; Secure",
                                   @"Content-Length": @"214"};
    NSURL *URL = [NSURL URLWithString:@"http://zeta.example.com/login"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];

    // when
    [self.sut setCookieDataFromResponse:response forURL:URL];

    // then
    XCTAssertNil(self.sut.authenticationCookieData);
}

- (void)testThatItStoresAuthCookies
{
    // given
    XCTAssertNil(self.sut.authenticationCookieData);
    
    NSDictionary *headerFields = @{@"Date": @"Thu, 24 Jul 2014 09:06:45 GMT",
                                   @"Content-Encoding": @"gzip",
                                   @"Server": @"nginx",
                                   @"Content-Type": @"application/json",
                                   @"Access-Control-Allow-Origin": @"file://",
                                   @"Connection": @"keep-alive",
                                   @"Set-Cookie": @"zuid=wjCWn1Y1pBgYrFCwuU7WK2eHpAVY8Ocu-rUAWIpSzOcvDVmYVc9Xd6Ovyy-PktFkamLushbfKgBlIWJh6ZtbAA==.1721442805.u.7eaaa023.08326f5e-3c0f-4247-a235-2b4d93f921a4; Expires=Sun, 21-Jul-2024 09:06:45 GMT; Domain=wire.com; HttpOnly; Secure",
                                   @"Content-Length": @"214"};
    NSURL *URL = [NSURL URLWithString:@"http://zeta.example.com/login"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];
    
    // when
    [self.sut setCookieDataFromResponse:response forURL:URL];
    
    // then
    XCTAssertNotNil(self.sut.authenticationCookieData);
}

@end
