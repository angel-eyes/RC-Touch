/*
 Audio Comm: Serial communications over audio
 
 Copyright (C) 2010-2011 Ari Krupnik & Associates
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License V2
 as published by the Free Software Foundation.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
/*
 *  Many thanks to Michael Tyson of /A Tasty Pixel/ for his post on RemoteIO:
 *  http://atastypixel.com/blog/using-remoteio-audio-unit/
 *
 *  Everything in this file assumes 8-bit, mono, signed samples. In particular,
 *  this assumption supports the equality between number of bytes in a buffer
 *  and number of samples that these bytes represent.
 *
 */

#include <stdio.h>

#include "ac_ppm_out.h"
#include "ac_util.h"


#define kOutputBus 0
#define kInputBus 1

static int8_t MARK = 127;
static int8_t SPACE = -128;


#define AUDIO_SAMPLES_PER_S 44100
#define AUDIO_SAMPLES_PER_US (AUDIO_SAMPLES_PER_S / 1000.0 / 1000.0)
#define PPM_MARK_WIDTH_US 400
#define PPM_MARK_WIDTH_SAMPLES lround(AUDIO_SAMPLES_PER_US * PPM_MARK_WIDTH_US)

static int num_channels;
//static 
float channel_values_f[PPM_MAX_CHANNLES];  //通道数据
int enableOutputPPM = 1;

static AudioComponentInstance audioUnit;


/* housekeeping */

static void channel_values_f_init(int nc) {
	num_channels = nc;
	for(int i=0; i<PPM_MAX_CHANNLES; i++) {
		channel_values_f[i]=0.0;
	}
	channel_values_f[2] = -1.0;  // special case for throttle  // throttle can now map to any channel
}


/* PPM buffering */

// buffers a mark
//
static SInt8 *buffer_mark(SInt8 *bp) {
	for(SInt8 *end=bp+PPM_MARK_WIDTH_SAMPLES; bp<end; bp++) {
		*bp = MARK;
	}
	return bp;
}

//填充单个发送通道的缓存
// buffers a mark, then remaining time as space; assumes `channel' is between -1.0 and 1.0
static SInt8 *buffer_channel(float channel, SInt8 *bp) {
	bp = buffer_mark(bp);
	/* There appear to some sort of rounding issue where +1.0 goes all the way to the right but
	   -1.0 isn't deflecting all the way to the left. The line below seems like it produces the
       right result, but the physical output is different for right and left */
	float pulse_length_us = 1500 + 500 * channel;
	//int fudge_a=-180; int fudge_m=50;
	//float pulse_length_us = 1500 +fudge_a + (500+fudge_m) * clip(channel, -1.0, 1.0);
	int space_length_samples = AUDIO_SAMPLES_PER_US * pulse_length_us - PPM_MARK_WIDTH_SAMPLES;
	for(SInt8 *end=bp+space_length_samples; bp<end; bp++) {
		*bp = SPACE; //有效信号
	}
	return bp;
}

static void fill_with_silence(AudioBuffer buff) {
	SInt8 *bp = (SInt8 *)buff.mData;
	for(SInt8 *end=bp+buff.mDataByteSize; bp<end; bp++) {
		*bp = 0; //0就是silence
	}
}


//填充所有发送通道的缓存
//下降缘来临时，表明有信号要发送，
static void buffer_channels(float channels[], int num_channels, AudioBuffer buff) {
	if (!audio_outputs_to_wire()) {
		return fill_with_silence(buff);
	}
	SInt8 *samples = (SInt8 *)buff.mData;
	SInt8 *bp = samples;
	
	/* add channel pulses */
	for(int c=0; c<num_channels; c++) {
		bp = buffer_channel(channels[c], bp);
	}
	
	/* add trailing mark */
	bp = buffer_mark(bp);
	
	/* pad the packet with silence */
	for(SInt8 *buffer_end=samples+buff.mDataByteSize; bp<buffer_end; bp++) {
		*bp = SPACE;
	}
}

//缓存的长度为ioData->mBuffers  0.02秒
static OSStatus rio_callback(void *inRefCon, 
							 AudioUnitRenderActionFlags *ioActionFlags, 
							 const AudioTimeStamp *inTimeStamp, 
							 UInt32 inBusNumber, 
							 UInt32 inNumberFrames, 
							 AudioBufferList *ioData) {	
	buffer_channels(channel_values_f, num_channels, ioData->mBuffers[0]);
	return noErr;
}

static OSStatus rio_start (void) {
	// Describe audio component
	AudioComponentDescription desc;
	desc.componentType         = kAudioUnitType_Output;
	desc.componentSubType      = kAudioUnitSubType_RemoteIO;
	desc.componentFlags        = 0;
	desc.componentFlagsMask    = 0;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	
	// Get component
	AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
	
	// Get audio unit
	AudioComponentInstanceNew(inputComponent, &audioUnit);
	
	// Enable IO for playback
	UInt32 flag = 1;
	AudioUnitSetProperty(audioUnit, 
						 kAudioOutputUnitProperty_EnableIO, 
						 kAudioUnitScope_Output, 
						 kOutputBus,
						 &flag, 
						 sizeof(flag));
	
	// Describe format
	AudioStreamBasicDescription asbd;
	asbd.mSampleRate        = AUDIO_SAMPLES_PER_S;
	asbd.mFormatID			= kAudioFormatLinearPCM;
	asbd.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	asbd.mFramesPerPacket	= 1;
	asbd.mChannelsPerFrame	= 1;
	asbd.mBitsPerChannel	= 8;
	asbd.mBytesPerPacket	= 1;
	asbd.mBytesPerFrame		= 1;
	
	// Apply format
	AudioUnitSetProperty(audioUnit, 
						 kAudioUnitProperty_StreamFormat, 
						 kAudioUnitScope_Input, 
						 kOutputBus, 
						 &asbd, 
						 sizeof(asbd));
	
	// Set output callback
	AURenderCallbackStruct callbackStruct;
	callbackStruct.inputProc       = rio_callback;
	callbackStruct.inputProcRefCon = NULL;
	AudioUnitSetProperty(audioUnit, 
						 kAudioUnitProperty_SetRenderCallback, 
						 kAudioUnitScope_Global, 
						 kOutputBus,
						 &callbackStruct, 
						 sizeof(callbackStruct));	
	
	// Initialise
	AudioUnitInitialize(audioUnit);
	
	// Start
	return AudioOutputUnitStart(audioUnit);
}


/* audio session configuration */

// if user ignores incoming phonecall, make sure audio continues
static void audio_session_interruption_callback(void *inClientData, UInt32 inInterruptionState) {
	if (inInterruptionState==kAudioSessionBeginInterruption) {
		//AudioSessionSetActive(0);
		AudioOutputUnitStop(audioUnit);
	} else if (inInterruptionState==kAudioSessionEndInterruption) {
		UInt32 category = kAudioSessionCategory_MediaPlayback;
		AudioSessionSetProperty (kAudioSessionProperty_AudioCategory, sizeof (category), &category);
		AudioSessionSetActive(1);
		rio_start();
	}
}

static void audio_session_setup (void) {
	AudioSessionInitialize(NULL, NULL, audio_session_interruption_callback, NULL);
	//UInt32 category = kAudioSessionCategory_SoloAmbientSound;
	UInt32 category = kAudioSessionCategory_MediaPlayback;
	AudioSessionSetProperty (kAudioSessionProperty_AudioCategory,
							 sizeof (category),
							 &category);
	
	float aBufferLength = 0.02; // In seconds; works down to at least 0.001，将缓存的的长度设置为0.02秒，则正好时50Hz
	AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, 
							sizeof(aBufferLength),
							&aBufferLength);
	
	AudioSessionSetActive(1);
}


/* public interface */

OSStatus ppm_audio_out_start (int nc, enum ppmPolarity polarity) {
	ppm_audio_out_set_polarity(polarity);
	
	channel_values_f_init(nc);
	audio_session_setup();
	return rio_start();
}

void ppm_audio_out_set_polarity(enum ppmPolarity polarity) {
    if ((polarity==PPM_POLARITY_POSITIVE && !device_inverts_audio()) ||
        (polarity==PPM_POLARITY_NEGATIVE && device_inverts_audio())) {
        MARK = 127;
        SPACE = -128;
    } else {
		MARK = -128;
        SPACE = 127;
    }
}

OSStatus ppm_audio_out_stop (void) {
	AudioSessionSetActive(0);
	return AudioUnitUninitialize(audioUnit);
}

void ppm_audio_out_set_value_to_transmit(int channel, float value) {
	if(channel<PPM_MAX_CHANNLES) {
		channel_values_f[channel] = value;
	}
}