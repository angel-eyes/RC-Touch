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

#include "ac_util.h"
#include <sys/utsname.h>
#include <string.h>

int device_inverts_audio(void) {
	struct utsname systemInfo;
    uname(&systemInfo);
	return !strcmp("iPhone1,1", systemInfo.machine);
}

int device_has_audio_jack_on_bottom(void) {
	struct utsname systemInfo;
    uname(&systemInfo);
	char *c="iPod";
	return !strncmp(c, systemInfo.machine, strlen(c));
}

#import <stdio.h>

//检测音频输出是否是接到发射器端
int audio_outputs_to_wire(void) {
	static CFStringRef SPEAKER_PREFIX = CFSTR("Speaker");
    static CFStringRef RECEIVER_PREFIX = CFSTR("Receiver");
	CFStringRef route=NULL;
	UInt32 propertySize = sizeof(CFStringRef);
	OSStatus s = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route);
	int result = s==noErr &&  // I know what the route is and it is
                CFStringGetLength(route) &&  // not null (mute switch on)
                !CFStringHasPrefix(route, SPEAKER_PREFIX) &&  // nor the speaker
                !CFStringHasPrefix(route, RECEIVER_PREFIX);  // nor the receiver
    if (s!=kAudioSessionUnsupportedPropertyError) {
		// simulator doesn't support audio routes, so returns nothing and nothing to free
        if (route) {
            // CFRelease explicitly prohibits NULL arguments
            CFRelease(route);
            route=NULL;
        }
	}
	return result;
}

/* AudioSession Properties */
Float64 ac_sample_rate(void) {
    Float64 result = -1.0;
	UInt32 size = sizeof(result);
	AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &result);
    return result;
}

Float32 ac_output_volume(void) {
    Float32 result = -1.0;
	UInt32 size = sizeof(result);
	AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputVolume, &size, &result);
    return result;
}

