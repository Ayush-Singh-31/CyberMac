/*
 * Compiles the bcdec.h header-only library and exposes the BC7 entry point
 * used by CyberMac. bcdec.h itself is vendored under include/bcdec.h, MIT /
 * Unlicense dual-licensed by Sergii "iOrange" Kudlai (see header for full
 * notice and also THIRD_PARTY_NOTICES.md at the repo root).
 *
 * BCDECDEF is forced to `extern` so the implementation's symbols have external
 * linkage and the wrapper below can call them.
 */

#define BCDECDEF extern
#define BCDEC_IMPLEMENTATION
#include "bcdec.h"

#include "CyberMacBC7Decoder.h"

void cybermac_bc7_decode_block(const void *compressed_block,
                               void *destination,
                               int destination_pitch) {
    bcdec_bc7(compressed_block, destination, destination_pitch);
}
