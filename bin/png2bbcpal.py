#!/usr/bin/python
import png,argparse,sys,math,bbc

##########################################################################
##########################################################################

def save_file(data,path,options):
    if path is not None:
        with open(path,'wb') as f:
            f.write(''.join([chr(x) for x in data]))

        if options.inf:
            with open('%s.inf'%path,'wt') as f: pass

##########################################################################
##########################################################################

def main(options):
    if options.mode<0 or options.mode>6:
        print>>sys.stderr,'FATAL: invalid mode: %d'%options.mode
        sys.exit(1)

    if options.mode in [0,3,4,6]:
        palette=[0,7]
        pixels_per_byte=8
        pack=bbc.pack_1bpp
    elif options.mode in [1,5]:
        palette=[0,1,3,7]
        pixels_per_byte=4
        pack=bbc.pack_2bpp
    elif options.mode==2:
        # this palette is indeed only 8 entries...
        palette=[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
        pixels_per_byte=2
        pack=bbc.pack_4bpp
    
    if options.palette is not None:
        if len(options.palette)!=len(palette):
            print>>sys.stderr,'FATAL: invalid mode %d palette - must have %d entries'%(options.mode,n)
            sys.exit(1)

        palette=[]
        for i in range(len(options.palette)):
            if options.palette[i] not in "01234567":
                print>>sys.stderr,'FATAL: invalid BBC colour: %s'%options.palette[i]
                sys.exit(1)

            for j in range(len(options.palette)):
                if i!=j and options.palette[i]==options.palette[j]:
                    print>>sys.stderr,'FATAL: duplicate BBC colour: %s'%options.palette[i]
                    sys.exit(1)

            palette.append(int(options.palette[i]))

    image=bbc.load_png(options.input_path,
                       options.mode,
                       options._160,
                       -1 if options.transparent_output else None,
                       options.transparent_rgb,
                       not options.quiet)

    # if len(image[0])%pixels_per_byte!=0:
    #    print(f'FATAL: Mode {options.mode} image width must be a multiple of {pixels_per_byte}',file=sys.stderr)
    #    sys.exit(1)
        
    # if len(image)%8!=0:
    #    print('FATAL: image height must be a multiple of 8',file=sys.stderr)
    #    sys.exit(1)

    print('{0} x {1}'.format(len(image[0]),len(image)))

    # Convert into BBC physical indexes: 0-7, and -1 for transparent
    # (going by the alpha channel value).
    bbc_lidxs=[]
    bbc_mask=[]
    for y in range(len(image)):
        bbc_lidxs.append([])
        bbc_mask.append([])
        for x in range(len(image[y])):
            if image[y][x]==-1:
                bbc_lidxs[-1].append(options.transparent_output)
                bbc_mask[-1].append(len(palette)-1)
            else:
                try:
                    bbc_lidxs[-1].append(palette.index(image[y][x]))
                except ValueError:
                    # print>>sys.stderr,'(NOT) FATAL: (%d,%d): colour %d not in BBC palette'%(x,y,image[y][x])
                    bbc_lidxs[-1].append(0)
                    # sys.exit(1)

                bbc_mask[-1].append(0)

        assert len(bbc_lidxs[-1])==len(image[y])
        assert len(bbc_mask[-1])==len(image[y])

    assert len(bbc_lidxs)==len(image)
    assert len(bbc_mask)==len(image)
    for y in range(len(image)):
        assert len(bbc_lidxs[y])==len(image[y])
        assert y==0 or len(bbc_lidxs[y])==len(bbc_lidxs[y-1])
        assert len(bbc_mask[y])==len(image[y])

    if options.code_path is not None:
        code=open(options.code_path,'w')

    # Assume label writeptr for the address to be written to.
    # Assume all registers are free.
    pixel_data=[]
    mask_data=[]
    # prev_line=[0x05,0x15,0x25,0x35,0x45,0x55,0x65,0x75,0x85,0x95,0xa5,0xb5,0xc5,0xd5,0xe5,0xf5]
    prev_line=[0xf5,0xe5,0xd5,0xc5,0xb5,0xa5,0x95,0x85,0x75,0x65,0x55,0x45,0x35,0x25,0x15,0x05]
    assert len(bbc_lidxs)==len(bbc_mask)
    for y in range(0,len(bbc_lidxs),2):  # should be 8 to do a character row at a time!
        pal_base=0xf0
        pal_data=[]
        for x in range(1,len(bbc_lidxs[y]),2): # pixels_per_byte):
            assert len(bbc_lidxs[y])==len(bbc_mask[y])
            for line in range(1):  # should be 8 to do a character row at a time!
                assert y+line<len(bbc_lidxs)
                assert x<len(bbc_lidxs[y+line]),(x,len(bbc_lidxs[y+line]),y,line)
                xs=bbc_lidxs[y+line][x+0:x+1]
                pal_byte=pal_base + int(xs[0]) ^ 7
                pal_data.append(pal_byte)
                pixel_data.append(pal_byte)
                # print('{:02x}'.format(pal_byte),end=' ')
                pal_base-=0x10
        # print()
        if prev_line != None:
            diff_data=[]
            for i in range(0,len(pal_data)):
                if prev_line[i] != pal_data[i]:
                    diff_data.append(pal_data[i])

            if code != None:
                print(f'.frak_line{y}',file=code)
                for e in diff_data:
                    print('lda #&{:02x}:sta &fe21 ;6c'.format(e), file=code)

                if len(diff_data)<8:
                    print(f'WAIT_CYCLES {6*(8-len(diff_data))}', file=code)

                print('rts',file=code)

        prev_line = pal_data

    if code != None:
        print(f'PAGE_ALIGN_FOR_SIZE {len(bbc_lidxs)//2}',file=code)
        print(f'.frak_lines_LO',file=code)
        for y in range(0,len(bbc_lidxs),2):
            print(f'EQUB LO(frak_line{y})',file=code)

        print(f'PAGE_ALIGN_FOR_SIZE {len(bbc_lidxs)//2}',file=code)
        print(f'.frak_lines_HI',file=code)
        for y in range(0,len(bbc_lidxs),2):
            print(f'EQUB HI(frak_line{y})',file=code)

    if options.output_path is not None:
        with open(options.output_path,'wb') as f:
            f.write(bytes(pixel_data))

    # save_file(pixel_data,options.output_path,options)
    # save_file(mask_data,options.mask_output_path,options)

##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output BBC data to %(metavar)s')
    parser.add_argument('-m',dest='mask_output_path',metavar='FILE',help='output BBC destination mask data to %(metavar)s')
    parser.add_argument('-c',dest='code_path',metavar='FILE',help='output BBC code asm to %(metavar)s')
    parser.add_argument('--inf',action='store_true',help='if -o specified, also produce a 0-byte .inf file')
    parser.add_argument('--160',action='store_true',dest='_160',help='double width (Mode 5/2) aspect ratio')
    parser.add_argument('-p','--palette',help='specify BBC palette')
    parser.add_argument('--transparent-output',
                        default=None,
                        type=int,
                        help='specify output index to use for transparent PNG pixels')
    parser.add_argument('--transparent-rgb',
                        default=None,
                        type=int,
                        nargs=3,
                        help='specify opaque RGB to be interpreted as transparent')
    parser.add_argument('--fixed-16',action='store_true',dest='use_fixed_16',
                        help='use fixed palette when converting 16 colours')
    parser.add_argument('-q','--quiet',action='store_true',help='don\'t print warnings')
    parser.add_argument('input_path',metavar='FILE',help='load PNG data fro %(metavar)s')
    parser.add_argument('mode',type=int,help='screen mode')
    main(parser.parse_args())
