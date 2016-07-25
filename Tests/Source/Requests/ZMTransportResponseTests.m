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


@import ZMTransport;
@import XCTest;
@import ZMTesting;

#import "XCTestCase+Images.h"

@interface ZMTransportResponseTests : ZMTBaseTest
@end



@implementation ZMTransportResponseTests

- (void)testThatItReturnFailureOnHTTPError
{
    [self performIgnoringZMLogError:^{
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:@[] HTTPstatus:0 transportSessionError:nil];
        XCTAssertNotEqual(response.result, ZMTransportResponseStatusSuccess);
    }];
    for(int status = 1; status < 99; ++status) {
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:@[] HTTPstatus:status transportSessionError:nil];
        XCTAssertNotEqual(response.result, ZMTransportResponseStatusSuccess);
    }
    for(int status = 300; status < 999; ++status) {
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:@[] HTTPstatus:status transportSessionError:nil];
        XCTAssertNotEqual(response.result, ZMTransportResponseStatusSuccess);
    }
}

- (void)testThatItReturnFailureOnNetworkError
{
    [self performIgnoringZMLogError:^{
        NSError *error = [NSError errorWithDomain:@"foo" code:123 userInfo:nil];
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:@[] HTTPstatus:200 transportSessionError:error];
        XCTAssertNotEqual(response.result, ZMTransportResponseStatusSuccess);
    }];
}

- (void)testThatItReturnSuccess
{
    for(int status = 200; status < 300; ++status) {
        ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:@[] HTTPstatus:status transportSessionError:nil];
        XCTAssertEqual(response.result, ZMTransportResponseStatusSuccess);
    }
}

- (void)testThatItReturnsATimeout
{
    NSError *error = [NSError errorWithDomain:ZMTransportSessionErrorDomain code:ZMTransportSessionErrorCodeRequestExpired userInfo:nil];
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:nil HTTPstatus:0 transportSessionError:error];
    XCTAssertEqual(response.result, ZMTransportResponseStatusExpired);
}

- (void)testThatItReturnsAPayload
{
    NSDictionary *payload = @{@"foo": @"bar", @"baz": @"quux"};
    NSInteger statusCode = 432;
    NSError *error = [NSError errorWithDomain:ZMTransportSessionErrorDomain code:ZMTransportSessionErrorCodeTryAgainLater userInfo:@{@"errortest": @"foo-bar"}];
    
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPstatus:statusCode transportSessionError:error];
    
    XCTAssertNil(response.imageData);
    XCTAssertEqualObjects(response.payload, payload);
    XCTAssertEqual(response.HTTPStatus, statusCode);
    XCTAssertEqualObjects(response.transportSessionError, error);
}

- (void)testThatItReturnsImageData
{
    NSData *imageData = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
    NSInteger statusCode = 432;
    NSError *error = [NSError errorWithDomain:ZMTransportSessionErrorDomain code:ZMTransportSessionErrorCodeRequestExpired userInfo:@{@"errortest": @"foo-bar"}];
    
    ZMTransportResponse *response = [[ZMTransportResponse alloc ] initWithImageData:imageData HTTPstatus:statusCode transportSessionError:error headers:nil];
    
    XCTAssertNil(response.payload);
    XCTAssertEqualObjects(response.imageData, imageData);
    XCTAssertEqual(response.HTTPStatus, statusCode);
    XCTAssertEqualObjects(response.transportSessionError, error);
}

- (void)testThatAnHTTPErrorLowerThan500DoesNotSetsAnError
{
    for(NSInteger i = 100; i < 500; ++i) {
        ZMTransportResponse *imageResponse = [[ZMTransportResponse alloc] initWithImageData:[NSData data] HTTPstatus:i transportSessionError:nil headers:nil];
        ZMTransportResponse *payloadResponse = [[ZMTransportResponse alloc] initWithPayload:@{} HTTPstatus:i transportSessionError:nil headers:nil];
        XCTAssertNil(imageResponse.transportSessionError);
        XCTAssertNil(payloadResponse.transportSessionError);
        XCTAssertNotEqual(imageResponse.result, ZMTransportResponseStatusTemporaryError);
        XCTAssertNotEqual(payloadResponse.result, ZMTransportResponseStatusTemporaryError);
    }
}

- (void)testThatAnHTTPErrorInThe400sReturnsPermanentError
{
    for(NSInteger i = 400; i < 500; ++i) {
        if(i == 408) { // 408 is a timeout
            continue;
        }
        ZMTransportResponse *imageResponse = [[ZMTransportResponse alloc] initWithImageData:[NSData data] HTTPstatus:i transportSessionError:nil headers:nil];
        ZMTransportResponse *payloadResponse = [[ZMTransportResponse alloc] initWithPayload:@{} HTTPstatus:i transportSessionError:nil headers:nil];
        XCTAssertEqual(imageResponse.result, ZMTransportResponseStatusPermanentError);
        XCTAssertEqual(payloadResponse.result, ZMTransportResponseStatusPermanentError);
    }
}

- (void)testThatAnHTTPErrorOf408IsATryAgainLater
{
    ZMTransportResponse *imageResponse = [[ZMTransportResponse alloc] initWithImageData:[NSData data] HTTPstatus:408 transportSessionError:nil headers:nil];
    ZMTransportResponse *payloadResponse = [[ZMTransportResponse alloc] initWithPayload:@{} HTTPstatus:408 transportSessionError:nil headers:nil];
    XCTAssertEqual(imageResponse.result, ZMTransportResponseStatusTryAgainLater);
    XCTAssertEqual(payloadResponse.result, ZMTransportResponseStatusTryAgainLater);
}

- (void)testThatAnHTTPErrorOutsideThe400sDoesNotReturnsPermanentError
{
    for(NSInteger i = 100; i < 600; ++i) {
        if(i >= 300 && i < 500) {
            continue;
        }
        ZMTransportResponse *imageResponse = [[ZMTransportResponse alloc] initWithImageData:[NSData data] HTTPstatus:i transportSessionError:nil headers:nil];
        ZMTransportResponse *payloadResponse = [[ZMTransportResponse alloc] initWithPayload:@{} HTTPstatus:i transportSessionError:nil headers:nil];
        XCTAssertNotEqual(imageResponse.result, ZMTransportResponseStatusPermanentError);
        XCTAssertNotEqual(payloadResponse.result, ZMTransportResponseStatusPermanentError);
    }
}

- (void)testThatItCanBeCreatedFromAnHTTPResponseWithoutABody;
{
    // given
    NSURL *URL = [NSURL URLWithString:@"http://www.example.com/"];
    NSDictionary *headerFields = @{@"Connection": @"keep-alive",
                                   @"Content-Length": @"0",
                                   @"Date": @"Thu, 07 Aug 2014 13:29:08 GMT",
                                   @"Server": @"nginx"};
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];
    
    // when
    ZMTransportResponse *sut = [[ZMTransportResponse alloc] initWithHTTPURLResponse:response data:[NSData data] error:nil];
    
    // then
    XCTAssertNotNil(sut);
    XCTAssertEqual(sut.result, ZMTransportResponseStatusSuccess);
}

- (void)testThatItCanBeCreatedFromAnHTTPResponseWithoutContentTypeAndWithData
{
    // given
    NSString *content = @"{\"foo\":\"bar\"}";
    NSData *contentData = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *URL = [NSURL URLWithString:@"http://www.example.com/"];
    NSDictionary *headerFields = @{@"Connection": @"keep-alive",
                                   @"Content-Length": [NSString stringWithFormat:@"%lu", (unsigned long) contentData.length],
                                   @"Date": @"Thu, 07 Aug 2014 13:29:08 GMT",
                                   @"Server": @"nginx"};
    
    // when
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];
    ZMTransportResponse *zmResponse = [[ZMTransportResponse alloc] initWithHTTPURLResponse:response data:contentData error:nil];
    
    // then
    XCTAssertNotNil(zmResponse);
    XCTAssertEqual(zmResponse.HTTPStatus, 200);
    XCTAssertEqualObjects(zmResponse.payload, nil);
}

@end



@implementation ZMTransportResponseTests (ContentType)

- (void)testThatItDetectsContentTypeFromMIME;
{
    NSHTTPURLResponse *(^responseForType)(NSString *) = ^(NSString *type){
        NSURL *URL = [NSURL URLWithString:@"http://www.example.com/"];
        return [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": type}];
    };
    
    NSData *nonEmptyData = [NSData dataWithBytes:"foo" length:3];
    
    XCTAssertEqual([responseForType(@"image/jpeg") zmContentTypeForBodyData:nonEmptyData], ZMTransportResponseContentTypeImage);
    XCTAssertEqual([responseForType(@"image/gif") zmContentTypeForBodyData:nonEmptyData], ZMTransportResponseContentTypeImage);

    XCTAssertEqual([responseForType(@"application/json") zmContentTypeForBodyData:nonEmptyData], ZMTransportResponseContentTypeJSON);
    XCTAssertEqual([responseForType(@"text/x-json") zmContentTypeForBodyData:nonEmptyData], ZMTransportResponseContentTypeJSON);
    XCTAssertEqual([responseForType(@"application/json; charset=UTF-8") zmContentTypeForBodyData:nonEmptyData], ZMTransportResponseContentTypeJSON);
}

- (void)testThatItDetectsImageContentTypeFromData;
{
    NSHTTPURLResponse *(^responseForType)(NSString *) = ^(NSString *type){
        NSURL *URL = [NSURL URLWithString:@"http://www.example.com/"];
        return [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": type}];
    };
    
    XCTAssertEqual([responseForType(@"application/binary") zmContentTypeForBodyData:[self verySmallJPEGData]], ZMTransportResponseContentTypeImage);
}

- (void)testThatItDetectsAnEmptyResponseAsSuch;
{
    // given
    NSURL *URL = [NSURL URLWithString:@"http://www.example.com/"];
    NSDictionary *headerFields = @{@"Connection": @"keep-alive",
                                   @"Content-Length": @"0",
                                   @"Date": @"Thu, 07 Aug 2014 13:29:08 GMT",
                                   @"Server": @"nginx"};
    
    // when
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];
    ZMTransportResponse *zmResponse = [[ZMTransportResponse alloc] initWithHTTPURLResponse:response data:nil error:nil];
    
    // then
    XCTAssertEqual([response zmContentTypeForBodyData:[NSData data]], ZMTransportResponseContentTypeEmpty);
    XCTAssertNotNil(zmResponse);
}

- (void)testThatItDetectsAnInvalidResponseAsSuch
{
    // given
    NSString *content = @"{\"foo\":\"bar\"}";
    NSData *contentData = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *URL = [NSURL URLWithString:@"http://www.example.com/"];
    NSDictionary *headerFields = @{@"Connection": @"keep-alive",
                                   @"Content-Length": [NSString stringWithFormat:@"%lu", (unsigned long) contentData.length],
                                   @"Date": @"Thu, 07 Aug 2014 13:29:08 GMT",
                                   @"Server": @"nginx"};
    
    // when
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:headerFields];
    
    // then
    XCTAssertEqual([response zmContentTypeForBodyData:contentData], ZMTransportResponseContentTypeInvalid);
}

@end