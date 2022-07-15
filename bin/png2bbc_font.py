#!/usr/bin/python
import png,argparse,sys,math,bbc

##########################################################################
##########################################################################

def save_file(header,data,path,options):
    if path is not None:
        with open(path,'wb') as f:
            if header is not None:
                f.write(''.join([chr(x) for x in header]))

            f.write(''.join([chr(x) for x in data]))

        if options.inf:
            with open('%s.inf'%path,'wt') as f: pass

##########################################################################
##########################################################################

def main(options):
    if options.mode<0 or options.mode>6:
        print>>sys.stderr,'FATAL: invalid mode: %d'%options.mode
        sys.exit(1)

    if options.glyph_dim is None:
        print>>sys.stderr,'FATAL: glyph dimensions are required'
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
                       not options.quiet,
                       options.use_fixed_16)

    src_height=len(image)
    src_width=len(image[0])
    print 'Source image width: {0} height: {1}.'.format(src_width,src_height)
    print 'Glyph dimensions width: {0} height: {1}.'.format(options.glyph_dim[0],options.glyph_dim[1])
    print 'Glyph grid top left corner: {0}.'.format(options.glyph_start)

    if options.glyph_grid is None:
        glyphs_across=src_width/options.glyph_dim[0]
        glyphs_down=src_height/options.glyph_dim[1]
    else:
        glyphs_across=options.glyph_grid[0]
        glyphs_down=options.glyph_grid[1]

    print 'Grid has maximum of {0} glyphs across and {1} glyphs down.'.format(glyphs_across,glyphs_down)

    if options.max_glyphs is not None and options.max_glyphs > glyphs_across * glyphs_down:
        print 'WARNING: Max glyphs option is larger than glyph grid size.'

    #if len(image[0])%pixels_per_byte!=0:
    #    print>>sys.stderr,'FATAL: Mode %d image width must be a multiple of %d'%(options.mode,pixels_per_byte)
    #    sys.exit(1)
        
    #if len(image)%8!=0:
    #    print>>sys.stderr,'FATAL: image height must be a multiple of 8'
    #    sys.exit(1)

    # print '%d x %d'%(len(image[0]),len(image))

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

    glyph_size=options.glyph_dim[0]*options.glyph_dim[1]/pixels_per_byte

    pixel_data=[]
    num_glyphs=0
    assert len(bbc_lidxs)==len(bbc_mask)

    glyph_bottom=options.glyph_start[1] + glyphs_down*options.glyph_dim[1]
    glyph_right=options.glyph_start[0] + glyphs_across*options.glyph_dim[0]

    print 'Glyph grid bottom right corner: [{0}, {1}].'.format(glyph_right,glyph_bottom)

    # Assume this is a standard grid of glyphs.
    for glyph_top in range(options.glyph_start[1],glyph_bottom,options.glyph_dim[1]):
        for glyph_left in range(options.glyph_start[0],glyph_right,options.glyph_dim[0]):

            if options.max_glyphs is not None and num_glyphs>=options.max_glyphs:
                break

            # One glyph.
            if options.column is True:
                # Store data by column:
                for x in range(0,options.glyph_dim[0],pixels_per_byte):
                    for y in range(0,options.glyph_dim[1]):
                        row=image[glyph_top+y]
                        assert(len(row)==src_width)
                        xs=[]
                        for p in range(0,pixels_per_byte):
                            xs.append(row[glyph_left+x+p])
                        assert len(xs)==pixels_per_byte
                        pixel_data.append(pack(xs))
                
            else:
                # Store data by row.
                for y in range(0,options.glyph_dim[1]):
                    row=image[glyph_top+y]
                    assert(len(row)==src_width)
                    for x in range(0,options.glyph_dim[0],pixels_per_byte):
                        xs=[]
                        for p in range(0,pixels_per_byte):
                            xs.append(row[glyph_left+x+p])
                        assert len(xs)==pixels_per_byte
                        pixel_data.append(pack(xs))
            
            num_glyphs+=1
            
    assert(len(pixel_data)==num_glyphs*glyph_size)
    save_file(None, pixel_data,options.output_path, options)
    print 'Wrote {0} glyphs at {1} bytes per glyph for a total of {2} bytes of Beeb data in MODE {3}.'.format(num_glyphs, glyph_size, len(pixel_data),options.mode)


##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output BBC data to %(metavar)s')
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
    parser.add_argument('--glyph-dim',
                        default=None,
                        type=int,
                        nargs=2,
                        help='specify dimensions of a single glyph')
    parser.add_argument('--glyph-start',
                        default=[0, 0],
                        type=int,
                        nargs=2,
                        help='top left corner of first glyph in the grid')
    parser.add_argument('--glyph-grid',
                        default=None,
                        type=int,
                        nargs=2,
                        help='shape of glyph grid (otherwise assume span full image) ')
    parser.add_argument('--max-glyphs',
                        default=None,
                        type=int,
                        help='maximum number of glyphs to save')
    parser.add_argument('--column',action='store_true',help='store data in column order (for scrolltexts)')
    parser.add_argument('-q','--quiet',action='store_true',help='don\'t print warnings')
    parser.add_argument('input_path',metavar='FILE',help='load PNG data fro %(metavar)s')
    parser.add_argument('mode',type=int,help='screen mode')
    main(parser.parse_args())