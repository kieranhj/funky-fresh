# Convert Rocket track files into Beeb data format.

import argparse
import binascii
import sys
import os
import struct
from enum import Enum

class KeyType(Enum):
    KEY_STEP = 0
    KEY_LINEAR = 1
    KEY_SMOOTH = 2
    KEY_RAMP = 3

class Key:
    def __init__(self, key_track, key_type, key_time, key_value):
        self._track = key_track
        self._type = key_type
        self._time = key_time
        self._value = key_value
        self._delta_time = 0
        self._delta_value = 0
    
    def __str__(self):
        if self._type == KeyType.KEY_LINEAR:
            return f"[{self._track} {self._type} time={self._time} value={self._value} delta_time={self._delta_time} delta_value={self._delta_value}]"
        else:
            return f"[{self._track} {self._type} time={self._time} value={self._value}]"

    def calc_delta(self, next_key):
        if self._type == KeyType.KEY_LINEAR:
            self._delta_time = next_key._time - self._time
            self._delta_value = next_key._value - self._value
        else:
            self._delta_time = 0
            self._delta_value = 0

    def write_bbc(self, data):
        if g_verbose:
            print(self)

        if self._type == KeyType.KEY_STEP:
            # Use top bit to indicate a stepped key type.
            data.extend(struct.pack('B', self._track | 0x80))
        else:
            data.extend(struct.pack('B', self._track))

        bbc_value = int(abs(self._value) * 256)
        if self._value < 0:
            bbc_value *= -1
        data.extend(struct.pack('H', bbc_value & 0xffff)) # unsigned short

        if self._type == KeyType.KEY_LINEAR:
            assert(self._delta_time != 0)
            float_delta = 256 * self._delta_value / self._delta_time
            bbc_delta = int(float_delta)

            bbc_error = self._delta_value - bbc_delta * self._delta_time / 256
            err_percent = bbc_error / self._delta_value

            if bbc_error > 1 or err_percent > 0.1:
                print(f"WARNING: Error of {bbc_error} ({100*err_percent}%) for key: {self}")

            if bbc_delta == 0:
                print(f"ERROR: Not enough accuracy for key: {self}")
                sys.exit(1)
                
            data.extend(struct.pack('h', bbc_delta)) # signed short
        elif self._type != KeyType.KEY_STEP:
            print(f"ERROR: Key type '{self._type}' not supported!")


def make_track_from_file(file, track_no):
    num_keys = struct.unpack('i', file.read(4))[0]
    track = []

    for i in range(num_keys):
        key_time = struct.unpack('L', file.read(4))[0]
        key_value = struct.unpack('f', file.read(4))[0]
        key_type = struct.unpack('c', file.read(1))[0]
        track.append(Key(track_no, KeyType(int.from_bytes(key_type, "little")), key_time, key_value))

    for i in range(num_keys-1):
        track[i].calc_delta(track[i+1])

    return track

def write_tracks_to_bbc_data(tracks, data):
    # Make one uber track.
    uber_track = []
    for track in tracks:
        for key in track:
            uber_track.append(key)

    # And sort it by time.
    uber_track.sort(key=lambda k: k._time)

    # Write a block per time code.
    time = -1

    for key in uber_track:
        if key._time > time:
            # End of keys.
            if time != -1:
                data.extend(struct.pack('B', 255))

            # Write new time.
            time = key._time
            data.extend(struct.pack('H', time)) # unsigned short

        # Write BBC data.
        key.write_bbc(data)

    # End of keys.
    data.extend(struct.pack('B', 255))
    # End of sequence marker.
    data.extend(struct.pack('H', 0xffff))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("prefix", help="Rocket prefix string [prefix]")
    parser.add_argument("input", help="Rocket track list file [input]")
    parser.add_argument("path", help="Path to Rocket track files [path]")
    parser.add_argument("-o", "--output", metavar="<output>", help="Write BBC data stream <output> (default is '[prefix].bin')")
    parser.add_argument("-v", "--verbose", action="store_true", help="Print key data")
    args = parser.parse_args()

    global g_verbose
    g_verbose=args.verbose

    src = args.input
    # check for missing files
    if not os.path.isfile(src):
        print(f"ERROR: File '{src}' not found")
        sys.exit(1)

    dst = args.output
    if dst == None:
        dst = args.prefix + ".bin"

    # Read track list from file.
    track_list = open(src, 'r')
    track_names = track_list.read().splitlines()
    track_list.close()

    tracks = []
    track_no = 0

    # Read track data from each file.
    for track_name in track_names:
        track_file_name = os.path.join(args.path, args.prefix + "_" + track_name + ".track")
        if not os.path.isfile(track_file_name):
            print(f"ERROR: File '{track_file_name}' not found")
            sys.exit()

        track_file = open(track_file_name, 'rb')
        track = make_track_from_file(track_file, track_no)

        print(f"Loaded track {track_no} '{track_name}' with {len(track)} keys.")

        tracks.append(track)
        track_file.close()
        track_no+=1

    # Convert to BBC data format.
    bbc_data = []
    write_tracks_to_bbc_data(tracks, bbc_data)

    if g_verbose:
        print(bbc_data)

    # Output BBC format file.
    bbc_file = open(dst, 'wb')
    bbc_file.write(bytearray(bbc_data))
    bbc_file.close()

    print(f"Wrote {len(bbc_data)} bytes of BBC data.")
