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

#include <AudioToolbox/AudioToolbox.h>
#include <stdio.h>

#include "ac_audio.h"


static AudioUnit rioUnit;
static AudioStreamBasicDescription asbd;
static AURenderCallbackStruct inputProc;
static void (*left_callback)(SInt8 *data, int data_size, void *obj) = NULL;
static void (*right_callback)(SInt8 *data, int data_size, void *obj) = NULL;
void *ac_callback_target = NULL;

OSStatus SetupRemoteIO (AudioUnit* inRemoteIOUnit, AURenderCallbackStruct inRenderProc, AudioStreamBasicDescription* outFormat);

#pragma mark -Audio Session Interruption Listener

// originally from aurioTouchAppDelegate.mm
static void rioInterruptionListener(void *inClientData, UInt32 inInterruption) {
	if (inInterruption == kAudioSessionEndInterruption) {
		// make sure I am again the active session
		AudioSessionSetActive(true);
		AudioOutputUnitStart(rioUnit);
	}
	
	if (inInterruption == kAudioSessionBeginInterruption) {
		AudioOutputUnitStop(rioUnit);
    }
}


#pragma mark -Audio Session Property Listener

// originally from aurioTouchAppDelegate.mm
static void propListener(void *                  inClientData,
				  AudioSessionPropertyID	inID,
				  UInt32                  inDataSize,
				  const void *            inData) {
	OSStatus s;
	if (inID == kAudioSessionProperty_AudioRouteChange) {
		// if there was a route change, I need to dispose of the current rio unit and create a new one
		s = AudioComponentInstanceDispose(rioUnit);
		if (s)
			printf("couldn't dispose of remote i/o unit\n");
		
		SetupRemoteIO(&rioUnit, inputProc, &asbd);
		
		s = AudioOutputUnitStart(rioUnit);
		if (s)
			printf("couldn't start unit\n");
	}
}

#pragma mark -RIO Render Callback

// originally from aurioTouchAppDelegate.mm
static OSStatus	PerformThru(void						*inRefCon, 
							AudioUnitRenderActionFlags 	*ioActionFlags, 
							const AudioTimeStamp 		*inTimeStamp, 
							UInt32 						inBusNumber, 
							UInt32 						inNumberFrames, 
							AudioBufferList 			*ioData) {
	OSStatus err = AudioUnitRender(rioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
	if (err) {
		printf("PerformThru: error %d\n", (int)err);
	} else {
		for(int i = 0; i < ioData->mNumberBuffers; ++i) {
			SInt8 *data = (SInt8 *) ioData->mBuffers[i].mData;
            static int samples_cnt=0;
            static SInt8 *left_buffer=NULL;
            static SInt8 *right_buffer=NULL;
            if (samples_cnt<ioData->mBuffers[i].mDataByteSize/2) {
                samples_cnt=ioData->mBuffers[i].mDataByteSize/2;
                free(left_buffer);
                free(right_buffer);
                left_buffer=malloc(samples_cnt);
                right_buffer=malloc(samples_cnt);
            }
            // split stereo stream into two mono streams
            for (int b=0; b<samples_cnt; b++) {
                left_buffer[b]=data[b*2];
                right_buffer[b]=data[b*2+1];
            }
            
            // perform actual callbacks
            left_callback (left_buffer, samples_cnt, ac_callback_target);
            if (right_callback) {
                right_callback (right_buffer, samples_cnt, ac_callback_target);
            }
            
            // interleave two mono streams back into one stereo steram
            if (right_callback) {
                for (int b=0; b<samples_cnt; b++) {
                    data[b*2]=left_buffer[b];
                    data[b*2+1]=right_buffer[b];
                }
            } else {
                for (int b=0; b<samples_cnt; b++) {
                    data[b*2]=left_buffer[b];
                    data[b*2+1]=left_buffer[b];
                }
            }
		}
	}
	return err;
}

// originally from aurio_helper.cpp
OSStatus SetupRemoteIO (AudioUnit* inRemoteIOUnit, AURenderCallbackStruct inRenderProc, AudioStreamBasicDescription* outFormat) {
	OSStatus s;
	
	// Open the output unit
	AudioComponentDescription desc;
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_RemoteIO;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	
	AudioComponent comp = AudioComponentFindNext(NULL, &desc);
	
	s = AudioComponentInstanceNew(comp, inRemoteIOUnit);
	
	UInt32 one = 1;
	s = AudioUnitSetProperty(*inRemoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
	
	s = AudioUnitSetProperty(*inRemoteIOUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inRenderProc, sizeof(inRenderProc));
	
	// Describe format
	asbd.mSampleRate        = 44100;
	asbd.mFormatID			= kAudioFormatLinearPCM;
	asbd.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	asbd.mFramesPerPacket	= 1;
	asbd.mChannelsPerFrame	= 2;
	asbd.mBitsPerChannel	= 8;
	//asbd.mBitsPerChannel	= 16;
	asbd.mBytesPerFrame		= asbd.mChannelsPerFrame * asbd.mBitsPerChannel / 8;
	asbd.mBytesPerPacket	= asbd.mFramesPerPacket * asbd.mBytesPerFrame;
	
	s = AudioUnitSetProperty(*inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, sizeof(*outFormat));
	s = AudioUnitSetProperty(*inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, sizeof(*outFormat));
	
	s = AudioUnitInitialize(*inRemoteIOUnit);
	
	return s;
}

// originally from aurioTouchAppDelegate.mm#applicationDidFinishLaunching
static OSStatus audio_start_common(void) {
	OSStatus s;
	
	// Initialize our remote i/o unit
	
	inputProc.inputProc = PerformThru;
	inputProc.inputProcRefCon = NULL;
	
	// Initialize and configure the audio session
	s = AudioSessionInitialize(NULL, NULL, rioInterruptionListener, NULL);
	s = AudioSessionSetActive(true);
	
	UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
	s = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory);
	s = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, NULL);
	
	//Float32 preferredBufferSize = .005;
	Float32 preferredBufferSize = .05;
	s = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize);
	
	UInt32 size = sizeof(asbd);
	s = AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, &size);
	s = SetupRemoteIO(&rioUnit, inputProc, &asbd);
	s = AudioOutputUnitStart(rioUnit);
	
	size = sizeof(asbd);
	s = AudioUnitGetProperty(rioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, &size);
	return s;    
}


/* public interface */

OSStatus audio_start(void (*l_callback)(SInt8 *data, int data_size, void *obj),
                     void (*r_callback)(SInt8 *data, int data_size, void *obj),
                     void *callback_target) {
	left_callback=l_callback;
	right_callback=r_callback;
    ac_callback_target = callback_target;
    return audio_start_common();
}

OSStatus audio_stop (void) {
	AudioSessionSetActive(0);
	return AudioUnitUninitialize(rioUnit);
}


/* stock callbacks */
void null_callback(SInt8 *data, int data_size, void *dummy) {
}

void silent_callback(SInt8 *data, int data_size, void *dummy) {
    for (int i=0; i<data_size; i++) {
        data[i]=0;
    }
}
