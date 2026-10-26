# SPDX-License-Identifier: GPL-3.0-only
# Mask tile reconstruction adapted from WolvenKit contributors' MlmaskTools.cs.
# See licenses/WolvenKit-GPL-3.0.txt. Other CyberMac components keep their own licenses.
"""Portable, bounded XBM/MLMASK preview decoding using Pillow and NumPy.

The mask tile layout follows WolvenKit's MlmaskTools.cs (GPL-3.0).
https://github.com/WolvenKit/WolvenKit/blob/main/WolvenKit.Modkit/RED4/Tools/MlmaskTools.cs
No DirectX runtime or game modification is involved. Only the top mip is needed
for the 256-pixel icons; exported images are bounded to 1024 pixels per side.
"""
import base64
import json
from pathlib import Path
import numpy as np
from PIL import Image
from prepare_lucy_assets import require


def buffer_bytes(buffer):
    return base64.b64decode(buffer['Bytes'], validate=True)


def decode_bc(data, width, height, number):
    require(0 < width <= 8192 and 0 < height <= 8192, 'Invalid preview texture dimensions')
    blocksize = 8 if number in [1, 4] else 16
    size = ((width + 3)//4)*((height + 3)//4)*blocksize
    require(len(data) >= size, 'Truncated BC texture')
    return Image.frombytes({1:'RGBA', 3:'RGBA', 4:'L', 5:'RGB', 7:'RGBA'}[number],
                           (width, height), data[:size], 'bcn', number)


def decode_xbm(root):
    blob = root['renderTextureResource']['renderResourceBlobPC']['Data']
    header = blob['header']; w=header['sizeInfo']['width']; h=header['sizeInfo']['height']
    require(0 < w <= 8192 and 0 < h <= 8192, 'Invalid XBM size')
    data = buffer_bytes(blob['textureData'])
    placement = header['mipMapInfo'][0]['placement']
    data = data[placement['offset']:placement['offset']+placement['size']]
    compression = root['setup']['compression']
    formats = {'TCM_DXTNoAlpha':1, 'TCM_DXTAlpha':3, 'TCM_QualityR':4,
               'TCM_Alpha':4, 'TCM_Normals':5, 'TCM_Normalmap':5, 'TCM_NormalsHigh':5,
               'TCM_NormalsGloss':5, 'TCM_QualityColor':7}
    if compression in formats:
        return decode_bc(data, w, h, formats[compression])
    require(compression == 'TCM_None', 'Unsupported preview compression: ' + compression)
    pitch = header['mipMapInfo'][0]['layout']['rowPitch']
    raw = root['setup']['rawFormat']
    mode = {'TRF_Grayscale':'L', 'TRF_TrueColor':'RGBA'}.get(raw)
    require(mode is not None, 'Unsupported raw preview texture: '+raw)
    require(len(data) >= pitch*h, 'Truncated raw texture')
    return Image.frombytes(mode, (w,h), data, 'raw', mode, pitch)


def mask_layers(root):
    """Yield full-resolution grayscale masks, one layer at a time.

    The image orientation matches the texture's UV coordinates; PNG stores its
    first source row at the top, as does the BC texture decoder.
    """
    blob = root['renderResourceBlob']['renderResourceBlobPC']['Data']
    hd=blob['header'];w=hd['maskWidth'];h=hd['maskHeight'];tile=hd['maskTileSize']
    require(0 < w <= 8192 and 0 < h <= 8192 and 0 < tile <= 256 and 0 < hd['numLayers'] <= 32,
            'Invalid multilayer mask dimensions')
    atlas = np.asarray(decode_bc(buffer_bytes(blob['atlasData']),hd['atlasWidth'],hd['atlasHeight'],4)).ravel()
    tiles = np.frombuffer(buffer_bytes(blob['tilesData']), dtype='<u4')
    require(len(tiles)>=2, 'Truncated multilayer mask tile table')
    full_w=(w+tile-1)//tile; full_h=(h+tile-1)//tile
    small_scale=1 if hd['maskWidthLow']==0 or w<hd['maskWidthLow'] else w//hd['maskWidthLow']
    for layer in range(hd['numLayers']):
        result=np.zeros((h,w),dtype=np.uint8)
        for start in range(0,h,128):
            yy,xx=np.mgrid[start:min(start+128,h),0:w]
            decoded=np.zeros(xx.shape,dtype=bool)
            for offset,scale,tw in [(0,1,full_w),(full_w*full_h,small_scale,(w//small_scale+tile-1)//tile)]:
                indices=2*(tw*(yy//tile//scale)+xx//tile//scale+offset)
                valid=(indices+1<len(tiles)) & ~decoded
                safe=np.minimum(indices,len(tiles)-2)
                bits=tiles[safe+1];base=tiles[safe]
                valid &= (bits & (1<<layer))!=0
                lower=bits & ((1<<layer)-1)
                # NumPy's bitwise_count is only present in NumPy 2; this small
                # vectorised loop supports the bundled NumPy 1 and 2 decoders.
                count=np.zeros(lower.shape,dtype=np.uint32)
                for bit in range(layer):count+=(lower>>bit)&1
                at=base+count;valid &= at<len(tiles)
                decl=tiles[np.minimum(at,len(tiles)-1)]
                ux=((xx>>(decl>>20&15))%tile)+1+(decl&1023)*(tile+2)
                uy=((yy>>(decl>>24&15))%tile)+1+(decl>>10&1023)*(tile+2)
                ai=ux+uy*hd['atlasWidth'];valid &= ai<len(atlas)
                view=result[start:start+len(xx)]
                view[valid]=atlas[ai[valid]];decoded|=valid
        yield Image.fromarray(result)


def export_images(manifest):
    info=json.loads(Path(manifest).read_text());depot=Path(info['depot']);count=0
    for path in info['resources']:
        root=json.loads((depot/(path+'.json')).read_text())['Data']['RootChunk']
        dest=depot/path
        if dest.suffix=='.xbm':
            image=decode_xbm(root);image.thumbnail((1024,1024),Image.Resampling.LANCZOS)
            image.save(dest.with_suffix('.png'));count+=1
        elif dest.suffix=='.mlmask':
            folder=dest.with_name(dest.stem+'_layers');folder.mkdir()
            for i,image in enumerate(mask_layers(root)):
                image.thumbnail((1024,1024),Image.Resampling.LANCZOS)
                image.save(folder/(dest.stem+f'_{i}.png'));count+=1
    print('CYBERMAC_MATERIAL_IMAGES',count,flush=True)
    return count


if __name__=='__main__':
    import sys
    export_images(sys.argv[1])
