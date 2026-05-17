#ifndef CYBERMAC_BC7_DECODER_H
#define CYBERMAC_BC7_DECODER_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Block size for BC7 in bytes (16 bytes per 4x4 block, decompresses to 64 RGBA8 bytes).
 */
#define CYBERMAC_BC7_BLOCK_BYTE_SIZE 16

/*
 * Decode a single 4x4 BC7 block (16 bytes of compressed data) into RGBA8.
 *
 * destination must point to the top-left pixel of the 4x4 region inside a larger
 * RGBA8 image buffer. destination_pitch is the row stride of that image in bytes
 * (typically image_width * 4). The decoder writes 4 rows of 16 bytes each.
 */
void cybermac_bc7_decode_block(const void *compressed_block,
                               void *destination,
                               int destination_pitch);

#ifdef __cplusplus
}
#endif

#endif /* CYBERMAC_BC7_DECODER_H */
