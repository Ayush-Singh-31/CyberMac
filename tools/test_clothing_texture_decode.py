import base64
import struct
import unittest
import numpy as np
from clothing_texture_decode import decode_bc, decode_xbm, mask_layers


def buf(data):
    return {'Bytes':base64.b64encode(data).decode()}


class TextureDecodingTests(unittest.TestCase):
    def test_bc4_endpoint_and_interpolation_modes(self):
        for a,b,expected in [(255,0,[255,0,218,182,145,109,72,36]),
                             (0,255,[0,255,51,102,153,204,0,255])]:
            bits=sum((i%8)<<(3*i) for i in range(16))
            image=decode_bc(bytes([a,b])+bits.to_bytes(6,'little'),4,4,4)
            self.assertEqual(np.array(image).ravel().tolist(),expected*2)

    def test_bc5_preserves_both_channels(self):
        image=decode_bc(bytes([80,0])+bytes(6)+bytes([170,0])+bytes(6),4,4,5)
        self.assertEqual(image.getpixel((0,0))[:2],(80,170))

    def test_top_mip_offset_is_respected(self):
        block=struct.pack('<HHI',0xf800,0,0)
        root={'setup':{'compression':'TCM_DXTNoAlpha'},'renderTextureResource':{
            'renderResourceBlobPC':{'Data':{'header':{'sizeInfo':{'width':4,'height':4},
              'mipMapInfo':[{'placement':{'offset':8,'size':8}}]},'textureData':buf(bytes(8)+block)}}}}
        self.assertEqual(decode_xbm(root).getpixel((0,0)),(255,0,0,255))

    def test_truncated_and_oversized_textures_fail(self):
        with self.assertRaisesRegex(ValueError,'Truncated'):decode_bc(bytes(7),4,4,4)
        with self.assertRaisesRegex(ValueError,'dimensions'):decode_bc(bytes(8),8193,4,4)

    def test_raw_truecolor_retains_alpha_and_row_padding(self):
        root={'setup':{'compression':'TCM_None','rawFormat':'TRF_TrueColor'},'renderTextureResource':{
            'renderResourceBlobPC':{'Data':{'header':{'sizeInfo':{'width':1,'height':2},
              'mipMapInfo':[{'placement':{'offset':0,'size':16},'layout':{'rowPitch':8}}]},
              'textureData':buf(bytes([10,20,30,40,0,0,0,0,50,60,70,80,0,0,0,0]))}}}}
        self.assertEqual(np.array(decode_xbm(root)).tolist(),[[[10,20,30,40]],[[50,60,70,80]]])

    def test_mask_uses_high_resolution_then_low_resolution_fallback(self):
        # Two atlas tiles: white at x=0 and grey at x=1. High-res layer0
        # covers the first two columns; low-res layer1 covers the entire image.
        atlas=b''.join(bytes([v,0])+bytes(6) for v in [255,80])
        tiles=[12,1,0,0,0,0,0,0,13,2,0,0,0,1]
        root={'renderResourceBlob':{'renderResourceBlobPC':{'Data':{
            'header':{'atlasWidth':8,'atlasHeight':4,'maskWidth':4,'maskHeight':4,
                      'maskWidthLow':2,'maskHeightLow':2,'maskTileSize':2,'numLayers':3},
            'atlasData':buf(atlas),'tilesData':buf(struct.pack('<14I',*tiles))}}}}
        images=list(mask_layers(root))
        self.assertEqual(np.array(images[0]).tolist(),[[255,255,0,0],[255,255,0,0],[0,0,0,0],[0,0,0,0]])
        self.assertEqual(np.array(images[1]).tolist(),[[80]*4]*4)
        self.assertEqual(np.array(images[2]).sum(),0)


if __name__=='__main__':unittest.main()
