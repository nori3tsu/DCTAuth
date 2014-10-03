//
//  DCTOAuth1Credential.h
//  DCTAuth
//
//  Created by Daniel Tull on 22/02/2013.
//  Copyright (c) 2013 Daniel Tull. All rights reserved.
//

#import "DCTAuthAccountCredential.h"

@interface DCTOAuth1Credential : NSObject <DCTAuthAccountCredential>

- (instancetype)initWithConsumerKey:(NSString *)consumerKey
		   consumerSecret:(NSString *)consumerSecret
			   oauthToken:(NSString *)oauthToken
		 oauthTokenSecret:(NSString *)oauthTokenSecret;

@property (nonatomic, readonly) NSString *consumerKey;
@property (nonatomic, readonly) NSString *consumerSecret;
@property (nonatomic, readonly) NSString *oauthToken;
@property (nonatomic, readonly) NSString *oauthTokenSecret;

@end