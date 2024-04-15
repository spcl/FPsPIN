/*
 * Routines common to dgping and dgpingd.
 */

#ifndef DG_COMMON_H
#define DG_COMMON_H

#include <stdint.h>

/*
 * Maximum length of the extra payload (to mkping).
 */
#define DEFAULT_PAYLOAD (3 + 5 + 24 + 2)
#define MAX_EXTRA_PAYLOAD 1400

/*
 * Format a string to the given sequence number. A pointer to a static
 * string is returned.
 *
 * In case extra_payload != 0, that number of bytes are filled with a
 * sweep of ASCII printable bytes.
 *
 * Checksum generation is disabled if no_checksum == 1.
 */
const char *
mkping(uint16_t seq, int extra_payload, int no_checksum);

/*
 * Validate an expected frame format. Return true on success.
 *
 * Checksum validation is disabled if no_checksum == 1.
 */
int
validate(const char *in, uint16_t *seq, int no_checksum);

/*
 * Parse out strings giving a PF port and address to the given sockaddr struct;
 * a newly-created socket is returned, or -1 on error.
 */
int
getaddr(const char *addr, const char *port, struct sockaddr_in *sin,
	int type, int protocol);

#endif

