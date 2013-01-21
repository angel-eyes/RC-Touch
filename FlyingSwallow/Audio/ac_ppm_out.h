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

#define PPM_MAX_CHANNLES 8

enum ppmPolarity {
    PPM_POLARITY_POSITIVE,
    PPM_POLARITY_NEGATIVE
};

OSStatus ppm_audio_out_start(int num_channels, enum ppmPolarity polarity);
void ppm_audio_out_set_polarity(enum ppmPolarity polarity);
OSStatus ppm_audio_out_stop(void);

void ppm_audio_out_set_value_to_transmit(int channel, float value);