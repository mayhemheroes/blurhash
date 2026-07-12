/* libFuzzer harness for the blurhash C encoder.
 *
 * Drives the same code path as the upstream blurhash_encoder CLI
 * (C/encode_stb.c): decode an image with stb_image, then encode the
 * pixels with blurHashForPixels(). In-process so the target is
 * sanitizer/coverage instrumented.
 */
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include "../C/encode.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
	if (size < 2) return 0;

	int xComponents = (data[0] % 8) + 1;
	int yComponents = (data[1] % 8) + 1;
	data += 2;
	size -= 2;

	int width, height, channels;
	unsigned char *pixels =
	    stbi_load_from_memory(data, (int)size, &width, &height, &channels, 3);
	if (!pixels) return 0;

	/* Bound the work per input; stb can decode huge images from tiny files. */
	if (width > 0 && height > 0 && (int64_t)width * height <= 1 << 20)
		blurHashForPixels(xComponents, yComponents, width, height, pixels,
		                  (size_t)width * 3);

	stbi_image_free(pixels);
	return 0;
}
