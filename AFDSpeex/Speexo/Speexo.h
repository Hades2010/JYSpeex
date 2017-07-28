//
//  speexo.h
//  Aifudao
//
//  Created by hua liu on 11-9-22.
//  Copyright 2011年 __MyCompanyName__. All rights reserved.
//

#ifndef Aifudao_speexo_h
#define Aifudao_speexo_h
#import <Foundation/Foundation.h>

#include <string.h>
#include <unistd.h>

#include "speex.h"
#include "speex_preprocess.h"
#include "speex_echo.h"

@interface Speexo : NSObject {
@private
    boolean_t mReady;
    
    int mEncFrameSize;
    int mEncFrameBytes;
    
#define DEFAULT_COMPRESSION 6
    
}

@property (readonly) int sourceDataBytesBaseForEncoding;

- (boolean_t)load;
- (boolean_t)getReady;
- (int)encodeFrames:(const void*)src :(int)slen encoded:(void*)dst :(int)dlen withBuffer:(void*)buffer :(int)size;
- (int)decodeFrames:(const void*)src :(int)slen decoded:(void*)dst :(int)dlen withBuffer:(void*)buffer :(int)size;
- (int)fillLostFrame:(void*)dst :(int)dlen;

@end

#endif

