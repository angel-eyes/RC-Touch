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

// different strokes for different devices

/* iPhone 2G (original iPhone) iverts audio coming out of the audio jack */
int device_inverts_audio(void);

/* iPods have the audio jack on bottom; I rotate all views 180 degrees to fit in the case */
int device_has_audio_jack_on_bottom(void);

// I want to output waveforms only if they can concievably go to some useful destination
// Mostly, I'm trying to avoid playing audio through the built-in speaker
int audio_outputs_to_wire(void);


/* AudioSession Properties */
Float64 ac_sample_rate(void);
Float32 ac_output_volume(void);

