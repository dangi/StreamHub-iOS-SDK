//
//  LFSBaseClient.m
//  LFSClient
//
//  Created by Eugene Scherba on 8/27/13.
//  Copyright (c) 2013 Adobe. All rights reserved.
//

#import <AFNetworking/AFURLRequestSerialization.h>
#import "LFSBaseClient.h"
#import "LFSJSONResponseSerializer.h"

NSDictionary* createRequestSerializerMap() {
    // Map AFN-v1 encoding parameters to serializer objects
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:[AFHTTPRequestSerializer serializer]
             forKey:[NSNumber numberWithInteger:AFFormURLParameterEncoding]];
    [dict setObject:[AFJSONRequestSerializer serializer]
             forKey:[NSNumber numberWithInteger:AFJSONParameterEncoding]];
    [dict setObject:[AFPropertyListRequestSerializer serializer]
             forKey:[NSNumber numberWithInteger:AFPropertyListParameterEncoding]];
    return [dict copy];
}

@implementation LFSBaseClient

@synthesize lfEnvironment = _lfEnvironment;
@synthesize lfNetwork = _lfNetwork;
@synthesize requestSerializers = _requestSerializers;
@synthesize responseSerializer = _responseSerializer;

@dynamic subdomain; // implemented by subclass

#pragma mark - Initialization

+ (instancetype)clientWithNetwork:(NSString*)network
                      environment:(NSString *)environment
{
    return [[self alloc] initWithNetwork:network environment:environment];
}

- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"%@ Failed to call designated initializer. Invoke `initWithEnvironment:network:` instead.", NSStringFromClass([self class])]
                                 userInfo:nil];
}

-(NSObject<AFURLRequestSerialization>*)requestSerializerWithEncoding:(AFHTTPClientParameterEncoding)encoding
{
    NSNumber *key = [NSNumber numberWithInteger:encoding];
    return [_requestSerializers objectForKey:key];
}

// this is the designated initializer
- (id)initWithNetwork:(NSString *)network
          environment:(NSString *)environment
{
    NSParameterAssert(network != nil);
    self = [super init];
    if (self) {
        _lfEnvironment = environment;
        _lfNetwork = network;
        _requestSerializers = createRequestSerializerMap();
        _responseSerializer = [LFSJSONResponseSerializer serializer];
 
        NSString *shortNetworkName = [[network componentsSeparatedByString:@"."] firstObject];
        NSString *networkDomain = [network stringByReplacingOccurrencesOfString:[shortNetworkName stringByAppendingString:@"."] withString:@""];
        NSString *hostname = [NSString stringWithFormat:@"%@.%@.%@", shortNetworkName, [self subdomain], networkDomain];

        NSURL *baseURL = [[NSURL alloc] initWithScheme:LFSScheme
                                                  host:hostname
                                                  path:@"/"];
        _reqOpManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseURL];
        _reqOpManager.securityPolicy.allowInvalidCertificates = YES;
        _reqOpManager.securityPolicy.validatesDomainName = NO;
        _reqOpManager.responseSerializer = _responseSerializer;
    }
    return self;
}

- (id)initWithBaseURL:(NSURL *)baseURL
{
    self = [super init];
    if (self) {
        
        
        // cache passed parameters into readonly properties
        _requestSerializers = createRequestSerializerMap();
        _responseSerializer = [AFHTTPResponseSerializer serializer];
        _reqOpManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseURL];
        _reqOpManager.securityPolicy.allowInvalidCertificates = YES;
        _reqOpManager.securityPolicy.validatesDomainName = NO;
        _reqOpManager.responseSerializer = _responseSerializer;
    }
    return self;
}

+ (instancetype)clientWithBaseURL:(NSURL *)baseURL
{
    return [[self alloc] initWithBaseURL:baseURL];
}

- (void)postPath:(NSString *)path
      parameters:(NSDictionary *)parameters
parameterEncoding:(AFHTTPClientParameterEncoding)parameterEncoding
         success:(AFSuccessBlock)success
         failure:(AFFailureBlock)failure
{
    AFHTTPRequestSerializer* requestSerializer =
    [self.requestSerializers objectForKey:[NSNumber numberWithInteger:parameterEncoding]];
    
    NSURLRequest *request = [requestSerializer
                             requestWithMethod:@"POST"
                             URLString:[[self.reqOpManager.baseURL URLByAppendingPathComponent:path] absoluteString]
                             parameters:parameters error:nil];
    
    AFHTTPRequestOperation *operation = [self.reqOpManager HTTPRequestOperationWithRequest:request
                                                                                   success:success
                                                                                   failure:failure];
    operation.responseSerializer = self.responseSerializer;
    [self.reqOpManager.operationQueue addOperation:operation];
}

- (void)getPath:(NSString *)path
      parameters:(NSDictionary *)parameters
parameterEncoding:(AFHTTPClientParameterEncoding)parameterEncoding
         success:(AFSuccessBlock)success
         failure:(AFFailureBlock)failure
{
    
    AFHTTPRequestSerializer* requestSerializer =
    [self.requestSerializers objectForKey:[NSNumber numberWithInteger:parameterEncoding]];
    
    NSURLRequest *request = [requestSerializer
                             requestWithMethod:@"GET"
                             URLString:[[self.reqOpManager.baseURL URLByAppendingPathComponent:path] absoluteString]
                             parameters:parameters error:nil];
    
    AFHTTPRequestOperation *operation = [self.reqOpManager HTTPRequestOperationWithRequest:request
                                                                                   success:success
                                                                                   failure:failure];
    operation.responseSerializer = self.responseSerializer;
    [self.reqOpManager.operationQueue addOperation:operation];
}

- (void)postURL:(NSURL *)url
     parameters:(NSDictionary *)parameters
parameterEncoding:(AFHTTPClientParameterEncoding)parameterEncoding
        success:(AFSuccessBlock)success
        failure:(AFFailureBlock)failure
{
    AFHTTPRequestSerializer* requestSerializer =
    [self.requestSerializers objectForKey:[NSNumber numberWithInteger:parameterEncoding]];
    
    NSURLRequest *request = [requestSerializer
                             requestWithMethod:@"POST"
                             URLString:[url absoluteString]
                             parameters:parameters error:nil];
    
    AFHTTPRequestOperation *operation = [self.reqOpManager HTTPRequestOperationWithRequest:request
                                                                                   success:success
                                                                                   failure:failure];
    operation.responseSerializer = self.responseSerializer;
    [self.reqOpManager.operationQueue addOperation:operation];
}


@end
