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

#import <MacTypes.h>  /* for OSStatus */

/* For mono applications, pass a NULL as the right callback, and I replicate
   the output of left callback to both channels */
OSStatus audio_start (void (*left_callback)(SInt8 *data, int data_size, void *obj),
                      void (*right_callback)(SInt8 *data, int data_size, void *obj),
                      void *obj);
OSStatus audio_stop (void);


/* stock callbacks */
/* does nothing; the effect is that input passes to output without modification. useful for testing */
void null_callback(SInt8 *data, int data_size, void *dummy);
void silent_callback(SInt8 *data, int data_size, void *dummy);