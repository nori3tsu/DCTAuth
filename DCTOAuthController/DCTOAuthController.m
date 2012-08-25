//
//  DTOAuthController.m
//  DTOAuthController
//
//  Created by Daniel Tull on 09.07.2010.
//  Copyright 2010 Daniel Tull. All rights reserved.
//

#import "DCTOAuthController.h"
#import "DCTOAuthURLProtocol.h"
#import "DCTOAuthSignature.h"
#import "DCTOAuthRequest.h"
#import <UIKit/UIKit.h>

NSString * const DCTOAuthMethodString[] = {
	@"GET",
	@"POST"
};

@implementation DCTOAuthController {
	__strong DCTOAuthSignature *_signature;
}

- (id)initWithRequestTokenURL:(NSURL *)requestTokenURL
				 authorizeURL:(NSURL *)authorizeURL
				  callbackURL:(NSURL *)callbackURL
			   accessTokenURL:(NSURL *)accessTokenURL
				  consumerKey:(NSString *)consumerKey
			   consumerSecret:(NSString *)consumerSecret {
	
	self = [super init];
	if (!self) return nil;
	
	_requestTokenURL = [requestTokenURL copy];
	_accessTokenURL = [accessTokenURL copy];
	_authorizeURL = [authorizeURL copy];
	_callbackURL = [callbackURL copy];
	_consumerKey = [consumerKey copy];
	_consumerSecret = [consumerSecret copy];
	
	return self;
}

- (void)performAuthenticationWithCompletion:(void(^)(NSDictionary *returnedValues))completion {
	
	NSMutableDictionary *returnedValues = [NSMutableDictionary new];
	
	void (^sharedCompletion)(NSDictionary *) = ^(NSDictionary *dictionary) {
		[returnedValues addEntriesFromDictionary:dictionary];
		[self _setValuesFromOAuthDictionary:dictionary];
	};
	
	void (^requestTokenCompletion)(NSDictionary *) = ^(NSDictionary *dictionary) {
		sharedCompletion(dictionary);
		if (completion != NULL) completion([returnedValues copy]);
	};
	
	void (^authorizeCompletion)(NSDictionary *) = ^(NSDictionary *dictionary) {
		sharedCompletion(dictionary);
		[self fetchRequestTokenWithParameters:dictionary completion:requestTokenCompletion];
	};
	
	void (^accessTokenCompletion)(NSDictionary *) = nil;
	
	if (self.authorizeURL) {
		accessTokenCompletion = ^(NSDictionary *dictionary) {
			sharedCompletion(dictionary);
			[self authorizeWithParameters:dictionary completion:authorizeCompletion];
		};
	} else {
		accessTokenCompletion = ^(NSDictionary *dictionary) {
			sharedCompletion(dictionary);
			[self fetchRequestTokenWithParameters:dictionary completion:requestTokenCompletion];
		};
	}
	
	[self fetchAccessTokenWithParameters:nil completion:accessTokenCompletion];
}

- (void)fetchAccessTokenWithParameters:(NSDictionary *)userParameters completion:(void(^)(NSDictionary *returnedValues))completion {
	
	NSMutableDictionary *parameters = [NSMutableDictionary new];
	[parameters addEntriesFromDictionary:userParameters];
	if (self.callbackURL) [parameters setObject:[self.callbackURL absoluteString] forKey:@"oauth_callback"];
	
	NSURLRequest *request = [self _URLRequestWithURL:self.requestTokenURL
									   requestMethod:DCTOAuthRequestMethodGET
										  parameters:parameters];
	
	[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *reaponse, NSData *data, NSError *error) {
		
		NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSDictionary *dictionary = [self _dictionaryFromString:string];
		completion(dictionary);
	}];
}

- (void)fetchRequestTokenWithParameters:(NSDictionary *)parameters completion:(void(^)(NSDictionary *returnedValues))completion {
	
	NSURLRequest *request = [self _URLRequestWithURL:self.accessTokenURL
									   requestMethod:DCTOAuthRequestMethodGET
										  parameters:parameters];
	
	[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *reaponse, NSData *data, NSError *error) {
		
		NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSDictionary *dictionary = [self _dictionaryFromString:string];
		completion(dictionary);
	}];
}


- (void)authorizeWithParameters:(NSDictionary *)inputParameters completion:(void(^)(NSDictionary *returnedValues))completion {
	
	NSMutableDictionary *parameters = [NSMutableDictionary new];
	[parameters addEntriesFromDictionary:inputParameters];
	if (self.callbackURL) [parameters setObject:[self.callbackURL absoluteString] forKey:@"oauth_callback"];
	
	NSMutableArray *keyValues = [NSMutableArray new];
	[parameters enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
		[keyValues addObject:[NSString stringWithFormat:@"%@=%@", key, [self _URLEncodedString:value]]];
	}];
	
	NSString *authorizeURLString = [NSString stringWithFormat:@"%@?%@", [self.authorizeURL absoluteString], [keyValues componentsJoinedByString:@"&"]];
	NSURL *authorizeURL = [NSURL URLWithString:authorizeURLString];
	
	[DCTOAuthURLProtocol registerForCallbackURL:self.callbackURL handler:^(NSURL *URL) {
		[DCTOAuthURLProtocol unregisterForCallbackURL:self.callbackURL];
		
		NSDictionary *dictionary = [self _dictionaryFromString:[URL query]];
		completion(dictionary);
	}];
	[[UIApplication sharedApplication] openURL:authorizeURL];
}

- (void)_setValuesFromOAuthDictionary:(NSDictionary *)dictionary {
	
	[dictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
		
		if ([key isEqualToString:@"oauth_token"])
			_oauthToken = value;
		
		else if ([key isEqualToString:@"oauth_token_secret"])
			_oauthTokenSecret = value;
		
		else if ([key isEqualToString:@"oauth_verifier"])
			_oauthVerifier = value;
	}];
}

- (NSDictionary *)_dictionaryFromString:(NSString *)string {
	NSArray *components = [string componentsSeparatedByString:@"&"];
	NSMutableDictionary *dictionary = [NSMutableDictionary new];
	[components enumerateObjectsUsingBlock:^(NSString *keyValueString, NSUInteger idx, BOOL *stop) {
		NSArray *keyValueArray = [keyValueString componentsSeparatedByString:@"="];
		if ([keyValueArray count] != 2) return;
		[dictionary setObject:[keyValueArray objectAtIndex:1] forKey:[keyValueArray objectAtIndex:0]];
	}];
	return [dictionary copy];
}

- (NSURLRequest *)_URLRequestWithURL:(NSURL *)URL requestMethod:(DCTOAuthRequestMethod)requestMethod parameters:(NSDictionary *)parameters {
	
	DCTOAuthSignature *signature = [[DCTOAuthSignature alloc] initWithURL:URL
															requestMethod:requestMethod
															  consumerKey:self.consumerKey
														   consumerSecret:self.consumerSecret
																	token:self.oauthToken
															  secretToken:self.oauthTokenSecret
															   parameters:parameters];
	
	DCTOAuthRequest *request = [[DCTOAuthRequest alloc] initWithURL:URL
															 method:requestMethod
														  signature:signature];
	return [request signedRequest];
}

- (NSString *)_URLEncodedString:(NSString *)string {
	
	return (__bridge_transfer NSString *) CFURLCreateStringByAddingPercentEscapes(NULL,
																				  (CFStringRef)objc_unretainedPointer(string),
																				  NULL,
																				  (CFStringRef)@"!*'();:@&=+$,/?%#[]",
																				  kCFStringEncodingUTF8);
}

@end
