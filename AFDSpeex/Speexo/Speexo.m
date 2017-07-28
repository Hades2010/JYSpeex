
#import "Speexo.h"

static int codec_open = 0;

static int dec_frame_size;
static int enc_frame_size;

static SpeexBits ebits, dbits;
static void *enc_state;
static void *dec_state;

static float agc_level;

static SpeexPreprocessState *prep_state;
static SpeexEchoState *echo_state;

#ifdef DEBUG_AUIDO_DATA_SAVE_TO_FILE
char mDecodePCMfile[128] = {0};
#endif

static int speexo_open(int compression) {
	int tmp;
    
	if (codec_open++ != 0)
		return 0;
    
	speex_bits_init(&ebits);
	speex_bits_init(&dbits);
    
	enc_state = speex_encoder_init(&speex_nb_mode); 
	dec_state = speex_decoder_init(&speex_nb_mode); 
	
	tmp = compression;
	speex_encoder_ctl(enc_state, SPEEX_SET_QUALITY, &tmp);	
	speex_encoder_ctl(enc_state, SPEEX_GET_FRAME_SIZE, &enc_frame_size);
	
	tmp = 1;
	speex_decoder_ctl(dec_state, SPEEX_SET_ENH, &tmp);
	speex_decoder_ctl(dec_state, SPEEX_GET_FRAME_SIZE, &dec_frame_size);
	
	prep_state = speex_preprocess_state_init(enc_frame_size, 8000);
	echo_state = speex_echo_state_init(enc_frame_size, enc_frame_size*15);
	
	tmp = 8000;
	speex_echo_ctl(echo_state, SPEEX_ECHO_SET_SAMPLING_RATE, &tmp);
	
	tmp = 0;
	speex_preprocess_ctl(prep_state, SPEEX_PREPROCESS_SET_DENOISE, &tmp);
	tmp = 0;
	speex_preprocess_ctl(prep_state, SPEEX_PREPROCESS_SET_AGC, &tmp);
	tmp = 0;
	speex_preprocess_ctl(prep_state, SPEEX_PREPROCESS_SET_DEREVERB, &tmp);
	agc_level = 32000;
	speex_preprocess_ctl(prep_state, SPEEX_PREPROCESS_SET_AGC_LEVEL,&agc_level);
	tmp = 0;
	speex_preprocess_ctl(prep_state, SPEEX_PREPROCESS_SET_VAD, &tmp);
	
	speex_preprocess_ctl(prep_state, SPEEX_PREPROCESS_SET_ECHO_STATE, echo_state);
    
    #ifdef DEBUG_AUIDO_DATA_SAVE_TO_FILE
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    snprintf(mDecodePCMfile, sizeof(mDecodePCMfile) - 1, "%s/NewDecode.pcm", [documentsDirectory cStringUsingEncoding:NSASCIIStringEncoding]);
    #endif
    
	return 0;
}

static int speexo_encode(const void *in_bytes, void *out_bytes, int size) 
{
	if (!codec_open)
		return 0;
    
	int return_value;
    
	speex_bits_reset(&ebits);
	
	//speex_echo_capture(echo_state, (short*)in_bytes, (short*)in_bytes);
	
	//speex_preprocess_run(prep_state, (short*)in_bytes);
    
#ifdef DEBUG_AUIDO_DATA_SAVE_TO_FILE
    FILE *fp = fopen(mDecodePCMfile, "a+");
    if(NULL != fp)
    {
        fwrite(in_bytes, 1, size, fp);
        fclose(fp);
    }
#endif
	
	speex_encode_int(enc_state, (short*)in_bytes, &ebits);
	if(speex_bits_nbytes(&ebits) >= (int)size) {
		return_value = 0;
	}
	else {
		return_value = (int)speex_bits_write(&ebits, (char*)out_bytes, size);
	}
	
	return return_value;
}

static int speexo_decode(const void *in_bytes, int in_len, void *out_bytes) 
{
	if (!codec_open)
		return 0;
    
	int return_value;
    
	speex_bits_reset(&dbits);
	speex_bits_read_from(&dbits, (char *)in_bytes, in_len);
	if (0 != speex_decode_int(dec_state, &dbits, (short*)out_bytes)) {
		return_value = 0;
	}
	else {
		return_value = dec_frame_size*2;
	}
    
	return return_value;
}

static int speexo_lost_frame(void *out_bytes)
{
    if (!codec_open) 
        return 0;
    
    int return_value;
    
    if (0 != speex_decode_int(dec_state, NULL, (short*)out_bytes)) {
        return_value = 0;
    }
    else {
        return_value = dec_frame_size*2;
    }
    
    return return_value;
}

static int speexo_getEncFrameSize()
{
	if (!codec_open)
		return 0;
    
	return enc_frame_size;
}

static int speexo_getDecFrameSize()
{
	if (!codec_open)
		return 0;
	
    return dec_frame_size;
}

static float speexo_getAgcLevel()
{
	if (!codec_open)
		return 0;
    
	agc_level = 0;
	speex_preprocess_ctl(prep_state, SPEEX_PREPROCESS_GET_AGC_LEVEL, &agc_level);
	
	return agc_level;
}

static void speexo_close()
{
	if (--codec_open != 0)
		return;
    
	speex_bits_destroy(&ebits);
	speex_bits_destroy(&dbits);
	speex_decoder_destroy(dec_state); 
	speex_encoder_destroy(enc_state); 
	
	speex_echo_state_destroy(echo_state);
	speex_preprocess_state_destroy(prep_state);
}

static int int_min(int i1, int i2) 
{
    return i1 < i2 ? i1 : i2;
}

@implementation Speexo

@synthesize sourceDataBytesBaseForEncoding = mEncFrameBytes;

- (id)init
{
    self = [super init];
    
    if (self) {
        if ([self load]) {
            speexo_open(DEFAULT_COMPRESSION);
            mEncFrameSize = speexo_getEncFrameSize();
            mEncFrameBytes = mEncFrameSize*2; // assume mono & 16-bit PCM
            mReady = true;
        }
        else {
            return nil;
        }
    }
    
    return self;
}

- (boolean_t)load
{
    return true;
}

- (boolean_t)getReady
{
    return mReady;
}

- (int)encodeFrames:(const void*)src :(int)slen encoded:(void*)dst :(int)dlen withBuffer:(void*)buffer :(int)size
{
    /*
    // debug
    memcpy(dst, src, slen);
    return slen;
    */
    
    if (!mReady) {
        return 0;
    }
    
    int i, samples = (slen - 1)/mEncFrameBytes + 1;
    int thisBytes;
    if (size < mEncFrameBytes*2) {
        NSLog(@"AIFUDAO:encodeFrames:Not enough buffer for use[%d < %d].", size, mEncFrameBytes*2);
        return 0;
    }
    void *sBytes = buffer;
    void *dBytes = buffer + mEncFrameBytes;
    boolean_t fatalError = false;
    int offset = 0;
    for (i = 0 ; i < samples ; i++) {
        bzero(sBytes, mEncFrameBytes);
        int thisSourceBytes = int_min(slen - i*mEncFrameBytes, mEncFrameBytes);
        memcpy(sBytes, src + i*mEncFrameBytes, thisSourceBytes);
        thisBytes = speexo_encode(sBytes, dBytes, thisSourceBytes);
        if (thisBytes <= 0) {
            fatalError = true;
            break;
        }
        if (thisBytes + 4 + offset > dlen) {
            fatalError = false;
            break;
        }
        int thisBytesInNetworkByteOrder = htonl(thisBytes);
        memcpy(dst + offset, &thisBytesInNetworkByteOrder , sizeof(int));
        offset += sizeof(int);
        memcpy(dst + offset, dBytes, thisBytes);
        offset += thisBytes;
    }
    if (fatalError) {
        return 0;
    }
    else {
        return offset;
    }
}

- (int)decodeFrames:(const void*)src :(int)slen decoded:(void*)dst :(int)dlen  withBuffer:(void*)buffer :(int)size
{
    if (!mReady) {
        return 0;
    }
    
    int thisBytes;
    if (size < mEncFrameBytes*2) {
        NSLog(@"AIFUDAO:decodeFrames:Not enough buffer for use[%d < %d].", size, mEncFrameBytes*2);
        return 0;
    }
    void *sBytes = buffer;
    void *dBytes = buffer + mEncFrameBytes;
    boolean_t fatalError = false;
    int doffset = 0;
    int soffset = 0;
    while (soffset < slen) {
        int encodedFrameBytes;
        memcpy(&encodedFrameBytes, src + soffset, 4);
        soffset += 4;
        encodedFrameBytes = ntohl(encodedFrameBytes);
        if (encodedFrameBytes != 28) {
            fatalError = false;
            break;
        }
        memcpy(sBytes, src + soffset, encodedFrameBytes);
        soffset += encodedFrameBytes;
        thisBytes = speexo_decode(sBytes, encodedFrameBytes, dBytes);
        if (thisBytes <= 0 || thisBytes != mEncFrameBytes) {
            fatalError = true;
            break;
        }
        if (thisBytes + doffset > dlen) {
            fatalError = false;
            break;
        }
        memcpy(dst + doffset, dBytes, thisBytes);
        doffset += thisBytes;
    }
    if (fatalError) {
        return 0;
    }
    else {
        return doffset;
    }
}

- (int)fillLostFrame:(void*)dst :(int)dlen
{
    if (!mReady) {
        return 0;
    }
    
    if (dlen < mEncFrameSize) {
        return 0;
    }

    int thisBytes = speexo_lost_frame(dst);
    if (thisBytes <= 0 || thisBytes != mEncFrameSize) {
        return 0;
    }
    else {
        return thisBytes;
    }
}

- (void)dealloc
{
    speexo_close();
    
}

@end
