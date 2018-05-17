// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
#import "NBMRequest+Private.h"

#import "NBMJSONRPCConstants.h"
#import "NBMJSONRPCUtilities.h"
#import <stdlib.h>


@implementation NBMRequest

@synthesize requestId, method, parameters;

#pragma mark - Public

+ (instancetype)requestWithMethod:(NSString *)method {
    return [NBMRequest requestWithMethod:method parameters:nil];
}

+ (instancetype)requestWithMethod:(NSString *)method
                       parameters:(id)parameters
{
    return [NBMRequest requestWithMethod:method parameters:parameters requestId:nil];
}

#pragma mark - Private

+ (instancetype)requestWithMethod:(NSString *)method
                       parameters:(id)parameters
                        requestId:(NSNumber *)requestId
{
    NSParameterAssert(method);
    if (parameters) {
        NSAssert([parameters isKindOfClass:[NSDictionary class]] || [parameters isKindOfClass:[NSArray class]], @"Expect NSArray or NSDictionary in JSON-RPC parameters");
    }
    
    NBMRequest *request = [[NBMRequest alloc] init];
    request.method = method;
    request.parameters = parameters;
    request.requestId = requestId;
    
    return request;
}

+ (instancetype)requestWithJSONDicitonary:(NSDictionary *)json
{
    NSString *method = json[NBMJSONRPCMethodKey];
    id params = json[NBMJSONRPCParamsKey];
    NSNumber *requestId = json[NBMJSONRPCIdKey];
    
    return [NBMRequest requestWithMethod:method parameters:params requestId:requestId];
}

- (BOOL)isEqualToRequest:(NBMRequest *)request
{
    if (!request) {
        return NO;
    }
    
    BOOL hasEqualMethods = (!self.method && !request.method) || ([self.method isEqualToString:request.method]);
    BOOL hasEqualParams = (!self.parameters && !request.parameters) || ([self.parameters isEqualToDictionary:request.parameters]);
    BOOL hasEqualRequestIds = (!self.requestId && !request.requestId) || ([self.requestId isEqualToNumber:request.requestId]);
    
    return hasEqualMethods && hasEqualParams && hasEqualRequestIds;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return  YES;
    }
    if (![object isKindOfClass:[NBMRequest class]]) {
        return NO;
    }
    
    return [self isEqualToRequest:(NBMRequest *)object];
}

- (NSUInteger)hash
{
    return [self.method hash] ^ [self.parameters hash] ^ [self.requestId hash];
}

- (NSString *)description {
    return self.debugDescription;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"[method: %@, params: %@ id: %@]",
            self.method, self.parameters, self.requestId];
}

#pragma mark - Message

- (NSDictionary *)toJSONDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    [json setObject:NBMJSONRPCVersion forKey:NBMJSONRPCKey];
    [json setObject:self.method forKey:NBMJSONRPCMethodKey];
    if (self.parameters) {
        [json setObject:self.parameters forKey:NBMJSONRPCParamsKey];
    }
    if (self.requestId) {
        [json setObject:self.requestId forKey:NBMJSONRPCIdKey];
    }
    
    return [json copy];
}

- (NSString *)toJSONString {
    return [NSString nbm_stringFromJSONDictionary:[self toJSONDictionary]];
}

#pragma mark - JSON-PRC Converter

static NSMutableDictionary * idsMapping;
static NSString *localPeer;

+(NSNumber*)findRequestIDMethod:(NSString*)method sender:(NSString*)sender{
    __block NSNumber *reqID;
    
    [idsMapping[method] enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        reqID=[obj valueForKey:sender];
        
        if(reqID){
            *stop=YES;
        }
    }];
    
    return reqID;
}


+(NSInteger)requestIDFor:(NBMRequest*)request{
    if (localPeer == nil){
        if ([request.method isEqualToString:@"joinRoom"]){
            localPeer = request.parameters[@"name"];
        }
    }
    
    if(!idsMapping){
        idsMapping=[NSMutableDictionary new];
    }
    
    NSLog(@"cufo request: %@", request);
    
    NSString* method=[request method];
    
    NSString * sender;
    if (request.parameters[@"name"]){
        sender = request.parameters[@"name"];
    }else if (request.parameters[@"endpointName"]) {
        sender = request.parameters[@"endpointName"];
    }else if (request.parameters[@"sender"]) {
        sender = request.parameters[@"sender"];
    }else if ([method isEqualToString:@"publishVideo"]){
        sender = localPeer;
    }else{
        sender = @"sender";
    }
    
    sender=[sender stringByReplacingOccurrencesOfString:@"_webcam" withString:@""];
    //clean _webcam
    
    
    
    NSMutableArray * array = idsMapping[method];
    
    if(!array){
        array=[NSMutableArray new];
        idsMapping[method]=array;
    }
    __block NSNumber * requestID;
    
    [array enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSNumber * number = [obj objectForKey:sender];
        if(number){
            requestID=number;
            *stop=YES;
        }
        
    }];
    
    if(requestID){
        NSLog(@"request method: %@ sender: %@ id: %@", method,sender,requestID);
        return [requestID integerValue];
    }
    
    requestID=[NSNumber numberWithInteger:(rand() % 5000)];
    [array addObject:@{
                       sender:requestID
                       }];
    
    NSLog(@"request method: %@ sender: %@ id: %@", method,sender,requestID);
    
    return [requestID integerValue];
}


+(BOOL)canConvertRequest:(NBMRequest *)request{
    
    if([[request method] isEqualToString:@"joinRoom"]){
        return true;
    }
    
    if([[request method] isEqualToString:@"publishVideo"]){
        return true;
    }
    
    if([[request method] isEqualToString:@"onIceCandidate"]){
        return true;
    }
    
    if([[request method] isEqualToString:@"receiveVideoFrom"]){
        return true;
    }
    
    if([[request method] isEqualToString:@"participantJoined"]){
        return true;
    }
    
    if([[request method] isEqualToString:@"participantLeft"]){
        return true;
    }
    
    return false;
}



+(NSString *)convertRequest:(NBMRequest *)request{
    
    if([[request method] isEqualToString:@"joinRoom"]){
        //        {"id":"joinRoom","name":"ddd","room":"r"}      {"jsonrpc":"2.0","method":"joinRoom","id":0,"params":{"id":"joinRoom","dataChannels":true,"name":"r","room":"jus","user":"r"}}
        
        NSString * converted=[NSString nbm_stringFromJSONDictionary:request.parameters];
        NSLog(@"Convert Request join room:  %@",converted);
        return converted;
    }
    
    
    // Publish Video
    if([[request method] isEqualToString:@"publishVideo"]){
        NSMutableDictionary * mutableDictionary=[[NSMutableDictionary alloc] init];
        [mutableDictionary setObject:request.parameters[@"sdpOffer"] forKey:@"sdpOffer"];
        [mutableDictionary setObject:@"receiveVideoFrom" forKey:@"id"];
        NSString * sender=request.parameters[@"sender"] ?: localPeer;
        [mutableDictionary setObject:sender forKey:@"sender"];
        NSString * converted=[NSString nbm_stringFromJSONDictionary:mutableDictionary];
        return converted;
        
    }
    
    if([[request method] isEqualToString:@"receiveVideoFrom"]){
        //        {"id":"joinRoom","name":"ddd","room":"r"}      {"jsonrpc":"2.0","method":"joinRoom","id":0,"params":{"id":"joinRoom","dataChannels":true,"name":"r","room":"jus","user":"r"}}
        NSMutableDictionary * mutableDictionary=[[NSMutableDictionary alloc] init];
        [mutableDictionary setObject:request.parameters[@"sdpOffer"] forKey:@"sdpOffer"];
        [mutableDictionary setObject:@"receiveVideoFrom" forKey:@"id"];
        NSString * sender=request.parameters[@"sender"] ?: localPeer;
        sender=[[sender componentsSeparatedByString:@"_"] objectAtIndex:0];
        [mutableDictionary setObject:sender forKey:@"sender"];
        
        NSString * converted=[NSString nbm_stringFromJSONDictionary:mutableDictionary];
        return converted;
        
    }
    
    
    
    
    if([[request method] isEqualToString:@"onIceCandidate"]){
        //        {"id":"onIceCandidate","candidate":{"candidate":"candidate:4031766709 1 udp 2113937151 192.168.88.66 54531 typ host generation 0 ufrag P9td network-cost 50","sdpMid":"audio","sdpMLineIndex":0,"usernameFragment":"P9td"},"name":"jusuf"}
        NSDictionary * dictonary=@{
                                   @"id":@"onIceCandidate",
                                   @"candidate":request.parameters,
                                   @"name" : localPeer
                                   };
        NSString * converted=[NSString nbm_stringFromJSONDictionary:dictonary];
        return converted;
    }
    
    
    if([[request method] isEqualToString:@"participantJoined"]){
        //        {"id":"joinRoom","name":"ddd","room":"r"}      {"jsonrpc":"2.0","method":"joinRoom","id":0,"params":{"id":"joinRoom","dataChannels":true,"name":"r","room":"jus","user":"r"}}
        NSString * converted=[NSString nbm_stringFromJSONDictionary:request.parameters];
        NSLog(@"Convert Request join room:  %@",converted);
        return converted;
    }
    
    
    if([[request method] isEqualToString:@"participantLeft"]){
        NSString * converted=[NSString nbm_stringFromJSONDictionary:request.parameters];
        NSLog(@"Convert Request participant left:  %@",converted);
        return converted;
    }
    
    
    return nil;
}




+(BOOL)canConvertResponse:(NSDictionary *)dictionary{
    
    if([[dictionary objectForKey:@"id"] isEqualToString:@"existingParticipants"]){
        return true;
    }
    
    if([[dictionary objectForKey:@"id"] isEqualToString:@"receiveVideoAnswer"]){
        return true;
    }
    
    if([[dictionary objectForKey:@"id"] isEqualToString:@"iceCandidate"]){
        return true;
    }
    
    if([[dictionary objectForKey:@"id"] isEqualToString:@"newParticipantArrived"]){
        return true;
    }
    
    if([[dictionary objectForKey:@"id"] isEqualToString:@"participantLeft"]){
        return true;
    }
    
    
    return false;
    
}

+(NSDictionary*)convertParticipatData:(NSArray*)participats{
    
    NSMutableArray * convertedParticipatns=[NSMutableArray new];
    
    
    for(NSString * part in participats){
        [convertedParticipatns addObject:@{
                                           @"id":part
                                           }];
    }
    
    
    
    return  @{
              @"value":convertedParticipatns
              };
    
}

+(NSDictionary*)convertParticipat:(NSString*)participat patricipantJoin:(BOOL)didJoin{
    
    NSMutableArray * convertedParticipatns=[NSMutableArray new];
    
    [convertedParticipatns addObject:@{
                                       @"id":participat
                                       }];
    
    if (didJoin){
        return  @{@"id":participat};
    }else{
        return  @{@"name":participat};
    }
}

+(NSDictionary *)convertResponse:(NSDictionary *)response{
    
    if([[response objectForKey:@"id"] isEqualToString:@"existingParticipants"]){
        
        NSMutableDictionary * dictionary=[[NSMutableDictionary alloc] init];
        [dictionary setObject:NBMJSONRPCVersion forKey:NBMJSONRPCKey]; //version
        [dictionary setObject:@"participantJoined" forKey:NBMJSONRPCMethodKey];
        
        NSDictionary * value=[self convertParticipatData:response[NBMJSONRPCDataKey]];
        [dictionary setObject:value forKey:NBMJSONRPCResultKey];
        [dictionary setObject:value forKey:NBMJSONRPCParamsKey];
        
        NSString * sender=response[@"name"] ?: localPeer;
        NSNumber* reqID=[NBMRequest findRequestIDMethod:@"joinRoom" sender:sender] ?: [NSNumber numberWithInteger:99997];
        [dictionary setObject:reqID forKey:NBMJSONRPCIdKey];
        return [dictionary copy];
    }
    
    
    if([[response objectForKey:@"id"] isEqualToString:@"receiveVideoAnswer"]){
        
        NSMutableDictionary * dictionary=[[NSMutableDictionary alloc] init];
        [dictionary setObject:NBMJSONRPCVersion forKey:NBMJSONRPCKey]; //version
        [dictionary setObject:@"participantPublished" forKey:NBMJSONRPCMethodKey];
        
        NSString * sender=response[@"name"] ?: @"sender";
        NSNumber* reqID;
        
        if ([sender isEqualToString:localPeer]){
            reqID=[NBMRequest findRequestIDMethod:@"publishVideo" sender:sender] ?: [NSNumber numberWithInteger:99997];
        }else{
            reqID=[NBMRequest findRequestIDMethod:@"receiveVideoFrom" sender:sender] ?: [NSNumber numberWithInteger:99997];
        }
        
        [dictionary setObject:reqID forKey:NBMJSONRPCIdKey];
        NSDictionary * json=@{@"sdpAnswer":response[@"sdpAnswer"]};
        [dictionary setObject:json forKey:NBMJSONRPCResultKey];
        return [dictionary copy];
        
    }
    
    
    if([[response objectForKey:@"id"] isEqualToString:@"iceCandidate"]){
        
        NSMutableDictionary * dictionary=[[NSMutableDictionary alloc] init];
        NSMutableDictionary *d = [[NSMutableDictionary alloc]initWithDictionary:response[@"candidate"]];
        [d setObject:response[@"name"] forKey:@"endpointName"];
        [dictionary setObject:NBMJSONRPCVersion forKey:NBMJSONRPCKey]; //version
        [dictionary setObject:@"iceCandidate" forKey:NBMJSONRPCMethodKey];
        [dictionary setObject:d forKey:NBMJSONRPCParamsKey];
        [dictionary setObject:[NSNumber numberWithInt:999999] forKey:NBMJSONRPCIdKey];
        
        //        [dictionary setObject:response[@"candidate"] forKey:NBMJSONRPCParamsKey];
        //        NSString * sender=response[@"name"] ?: @"sender";
        //        NSNumber* reqID =[NBMRequest findRequestIDMethod:@"onIceCandidate" sender:sender] ?: [NSNumber numberWithInteger:99999];
        //        [dictionary setObject:reqID forKey:NBMJSONRPCIdKey];
        
        return [dictionary copy];
    }
    
    
    
    
    if([[response objectForKey:@"id"] isEqualToString:@"newParticipantArrived"]){
        NSMutableDictionary * dictionary=[[NSMutableDictionary alloc] init];
        [dictionary setObject:NBMJSONRPCVersion forKey:NBMJSONRPCKey]; //version
        [dictionary setObject:@"participantJoined" forKey:NBMJSONRPCMethodKey];
        //        [dictionary setObject:@"participantPublished" forKey:NBMJSONRPCMethodKey]; // kjo e thirr funksionin generateOffer
        NSDictionary * value=[self convertParticipat:response[@"name"] patricipantJoin:YES];
        [dictionary setObject:value forKey:NBMJSONRPCResultKey];
        [dictionary setObject:value forKey:NBMJSONRPCParamsKey];
        return [dictionary copy];
    }
    
    
    
    if([[response objectForKey:@"id"] isEqualToString:@"participantLeft"]){
        NSMutableDictionary * dictionary=[[NSMutableDictionary alloc] init];
        [dictionary setObject:NBMJSONRPCVersion forKey:NBMJSONRPCKey]; //version
        [dictionary setObject:@"participantLeft" forKey:NBMJSONRPCMethodKey];
        NSDictionary * value=[self convertParticipat:response[@"name"] patricipantJoin:NO];
        [dictionary setObject:value forKey:NBMJSONRPCResultKey];
        [dictionary setObject:value forKey:NBMJSONRPCParamsKey];
        return [dictionary copy];
    }
    
    return nil;
}


@end
