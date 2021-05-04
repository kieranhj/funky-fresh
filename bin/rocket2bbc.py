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
        return f"[{self._track} {self._type} {self._time} {self._value}]"

    def calc_delta(self, next_key):
        self._delta_time = next_key._time - self._time
        self._delta_value = next_key._value - self._value

    def write_bbc(self, data):
        if self._type == KeyType.KEY_STEP:
            # Use top bit to indicate a stepped key type.
            data.extend(struct.pack('B', self._track | 0x80))
        else:
            data.extend(struct.pack('B', self._track))

        bbc_value = int(self._value * 256)
        data.extend(struct.pack('h', bbc_value)) # signed short

        if self._type == KeyType.KEY_LINEAR:
            assert(self._delta_time != 0)
            float_delta = 256 * self._delta_value / self._delta_time
            # TODO: WARNING when not enough accuracy.
            bbc_delta = int(float_delta)
            data.extend(struct.pack('h', bbc_delta)) # signed short
        elif self._type != KeyType.KEY_STEP:
            print(f"ERROR: Key type '{self._type}' not supported!")


def make_track_from_file(file, track_no):
    num_keys = struct.unpack('i', file.read(4))[0]
    track = []

    print(track_no, num_keys)

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
    args = parser.parse_args()

    src = args.input
    # check for missing files
    if not os.path.isfile(src):
        print(f"ERROR: File '{src}' not found")
        sys.exit()

    dst = args.output
    if dst == None:
        dst = args.prefix + ".bin"

    # Read track list from file.
    track_list = open(src, 'r')
    track_names = track_list.read().splitlines()
    track_list.close()

    print(track_names)

    tracks = []
    track_no = 0

    # Read track data from each file.
    for track_name in track_names:
        track_file_name = os.path.join(args.path, args.prefix + "_" + track_name + ".track")
        if not os.path.isfile(track_file_name):
            print(f"ERROR: File '{track_file_name}' not found")
            sys.exit()

        track_file = open(track_file_name, 'rb')
        tracks.append(make_track_from_file(track_file, track_no))
        track_file.close()
        track_no+=1

    # Convert to BBC data format.
    bbc_data = []
    write_tracks_to_bbc_data(tracks, bbc_data)
    print(bbc_data)

    # Output BBC format file.
    bbc_file = open(dst, 'wb')
    bbc_file.write(bytearray(bbc_data))
    bbc_file.close()

    print(f"Wrote {len(bbc_data)} bytes of BBC data.")
