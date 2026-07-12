/* libFuzzer harness for the blurhash C decoder.
 *
 * Treats the input as a blurhash string (as the upstream blurhash_decoder
 * CLI does with argv[1]) and decodes it to a small RGBA pixel buffer,
 * exercising isValidBlurhash(), decode() and decodeToArray().
 */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "../C/decode.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
	if (size == 0 || size > 4096) return 0;

	char *hash = malloc(size + 1);
	if (!hash) return 0;
	memcpy(hash, data, size);
	hash[size] = '\0';

	const int width = 32, height = 32, punch = 1, nChannels = 4;

	uint8_t *pixels = decode(hash, width, height, punch, nChannels);
	if (pixels) {
		uint8_t out[32 * 32 * 4];
		decodeToArray(hash, width, height, punch, nChannels, out);
		freePixelArray(pixels);
	}

	free(hash);
	return 0;
}
