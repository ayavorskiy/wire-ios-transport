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



#import <Foundation/Foundation.h>
#import <ZMCSystem/ZMCSystem.h>

@class ZMTransportResponse;
@protocol ZMTransportData;
@protocol ZMSGroupQueue;
@class ZMTaskIdentifier;
@class ZMURLSession;

typedef void(^ZMTaskCreatedBlock)(ZMTaskIdentifier *);
typedef void(^ZMCompletionHandlerBlock)(ZMTransportResponse *);
typedef void(^ZMAccessTokenHandlerBlock)(NSString *token, NSString *type);
typedef void(^ZMProgressHandlerBlock)(float);

extern const NSTimeInterval ZMTransportRequestDefaultExpirationInterval;

@interface ZMCompletionHandler : NSObject

+ (instancetype)handlerOnGroupQueue:(id<ZMSGroupQueue>)groupQueue block:(ZMCompletionHandlerBlock)block ZM_NON_NULL(1,2);
@property (nonatomic, readonly) id<ZMSGroupQueue> groupQueue;

@end;

@interface ZMTaskCreatedHandler : NSObject

+ (instancetype)handlerOnGroupQueue:(id<ZMSGroupQueue>)groupQueue block:(ZMTaskCreatedBlock)block ZM_NON_NULL(1,2);
@property (nonatomic, readonly) id<ZMSGroupQueue> groupQueue;

@end

@interface ZMTaskProgressHandler : NSObject

+ (instancetype)handlerOnGroupQueue:(id<ZMSGroupQueue>)groupQueue block:(ZMProgressHandlerBlock)block ZM_NON_NULL(1,2);
@property (nonatomic, readonly) id<ZMSGroupQueue> groupQueue;

@end

typedef NS_ENUM(uint8_t, ZMTransportRequestMethod) {
    ZMMethodGET,
    ZMMethodDELETE,
    ZMMethodPUT,
    ZMMethodPOST,
    ZMMethodHEAD
};

typedef NS_ENUM(uint8_t, ZMTransportRequestAuth) {
    ZMTransportRequestAuthNone, ///< Does not needs an access token and does not generate one
    ZMTransportRequestAuthNeedsAccess, ///< Needs an access token
    ZMTransportRequestAuthCreatesCookieAndAccessToken, ///< Does not need an access token, but the response will contain one
};

typedef NS_ENUM(int8_t, ZMTransportAccept) {
    ZMTransportAcceptAnything, ///< Maps to "Accept: */*" HTTP header
    ZMTransportAcceptTransportData, ///< Maps to "Accept: application/json" HTTP header
    ZMTransportAcceptImage, ///< Maps to "Accept: image/*" HTTP header
};


@interface ZMTransportRequest : NSObject

+ (NSString *)stringForMethod:(ZMTransportRequestMethod)method;
+ (ZMTransportRequestMethod)methodFromString:(NSString *)string;

/// Returns a request that needs authentication, ie. @c ZMTransportRequestAuthNeedsAccess
- (instancetype)initWithPath:(NSString *)path method:(ZMTransportRequestMethod)method payload:(id <ZMTransportData>)payload;
- (instancetype)initWithPath:(NSString *)path method:(ZMTransportRequestMethod)method payload:(id <ZMTransportData>)payload authentication:(ZMTransportRequestAuth)authentication;

+ (instancetype)requestWithPath:(NSString *)path method:(ZMTransportRequestMethod)method payload:(id <ZMTransportData>)payload;
+ (instancetype)requestWithPath:(NSString *)path method:(ZMTransportRequestMethod)method payload:(id <ZMTransportData>)payload shouldCompress:(BOOL)shouldCompress;

+ (instancetype)requestGetFromPath:(NSString *)path;
+ (instancetype)compressedGetFromPath:(NSString *)path;
+ (instancetype)uploadRequestWithFileURL:(NSURL *)url path:(NSString *)path contentType:(NSString *)contentType;

+ (instancetype)emptyPutRequestWithPath:(NSString *)path;
+ (instancetype)imageGetRequestFromPath:(NSString *)path;

/// Creates a request with the given @c binary data for the body and the given @c type to be used as the content type.
/// @c type is a (Uniform Type Identifier) UTI.
/// @link https://en.wikipedia.org/wiki/Uniform_Type_Identifier @/link
/// @link https://developer.apple.com/library/ios/documentation/General/Conceptual/DevPedia-CocoaCore/UniformTypeIdentifier.html @/link
- (instancetype)initWithPath:(NSString *)path method:(ZMTransportRequestMethod)method binaryData:(NSData *)data type:(NSString *)type contentDisposition:(NSDictionary *)contentDisposition;
- (instancetype)initWithPath:(NSString *)path method:(ZMTransportRequestMethod)method binaryData:(NSData *)data type:(NSString *)type contentDisposition:(NSDictionary *)contentDisposition shouldCompress:(BOOL)shouldCompress;


@property (nonatomic, readonly) NSString *methodAsString;
@property (nonatomic, readonly, copy) id<ZMTransportData> payload;
@property (nonatomic, readonly, copy) NSString *path;
@property (nonatomic, readonly) ZMTransportRequestMethod method;
@property (nonatomic, readonly, copy) NSData *binaryData;
@property (nonatomic, readonly) NSURL *fileUploadURL;
@property (nonatomic, readonly, copy) NSString *binaryDataType; ///< Uniform type identifier (UTI) of the binary data
@property (nonatomic, readonly) BOOL needsAuthentication;
@property (nonatomic, readonly) BOOL responseWillContainAccessToken;
@property (nonatomic, readonly) BOOL responseWillContainCookie;
@property (nonatomic, readonly) NSDate *expirationDate;
@property (nonatomic, readonly) BOOL shouldCompress;
@property (nonatomic) BOOL shouldFailInsteadOfRetry;
@property (nonatomic) BOOL doesNotFollowRedirects;

/// If true, the request should only be sent through background session
@property (nonatomic, readonly) BOOL shouldUseOnlyBackgroundSession;
@property (nonatomic, readonly) BOOL shouldUseVoipSession;

@property (nonatomic, readonly, copy) NSDictionary *contentDisposition; ///< C.f. <https://tools.ietf.org/html/rfc2183>

- (void)addTaskCreatedHandler:(ZMTaskCreatedHandler *)taskCreatedHandler;
- (void)addCompletionHandler:(ZMCompletionHandler *)completionHandler;
- (void)addProgressHandler:(ZMTaskProgressHandler *)progressHandler;
- (void)callTaskCreationHandlersWithIdentifier:(NSUInteger)identifier sessionIdentifier:(NSString *)sessionIdentifier;
- (void)completeWithResponse:(ZMTransportResponse *)response;
- (void)updateProgress:(float)progress;
- (BOOL)isEqualToRequest:(ZMTransportRequest *)request;
- (void)addValue:(NSString *)value forAdditionalHeaderField:(NSString *)headerField;
- (void)expireAfterInterval:(NSTimeInterval)interval;
- (void)expireAtDate:(NSDate *)date;

- (BOOL)hasRequiredPayload;

/// If this is called, the request is going to be executed only on a background session
- (void)forceToBackgroundSession;

/// If this is called, the request is going to be executed on the voip session only
- (void)forceToVoipSession;

@property (nonatomic, readonly) ZMTransportAccept acceptedResponseMediaTypes; ///< C.f. RFC 7231 section 5.3.2 <http://tools.ietf.org/html/rfc7231#section-5.3.2>

@end


@interface ZMTransportRequest (ImageUpload)

+ (instancetype)postRequestWithPath:(NSString *)path imageData:(NSData *)data contentDisposition:(NSDictionary *)contentDisposition;

+ (instancetype)multipartRequestWithPath:(NSString *)path imageData:(NSData *)data metaData:(NSDictionary *)metaData;
+ (instancetype)multipartRequestWithPath:(NSString *)path imageData:(NSData *)data metaData:(NSDictionary *)metaData mediaContentType:(NSString *)mediaContentType;

+ (instancetype)multipartRequestWithPath:(NSString *)path
                               imageData:(NSData *)data
                                metaData:(NSData *)metaData
                     metaDataContentType:(NSString *)metaDataContentType
                        mediaContentType:(NSString *)mediaContentType;

- (NSArray *)multipartBodyItems;

@end


@class ZMObjectStrategy;
@protocol ZMObjectStrategy;
@class ZMSyncState;
@interface ZMTransportRequest (Debugging)

@property (nonatomic, readonly) NSDate *startOfUploadTimestamp;

- (void)setDebugInformationTranscoder:(NSObject *)transcoder;
- (void)setDebugInformationState:(ZMSyncState *)state;
- (void)appendDebugInformation:(NSString *)debugInformation;
/// Marks the start of the upload time point
- (void)markStartOfUploadTimestamp;

@end