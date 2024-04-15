/*
 * Routines common to dgping and dgpingd.
 * TODO assertions all over
 */

#define _GNU_SOURCE

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>
#include <time.h>

#include "common.h"

#if defined(__GNU_LIBRARY__) || defined(__GLIBC__) || defined(__sun)
# undef  HAVE_SALEN
#elif defined(__sun)
# undef  HAVE_SALEN
#elif defined(__EMSCRIPTEN__)
# undef  HAVE_SALEN
#else
# define HAVE_SALEN
#endif

/* TODO strip unneccessary headers from *.c */

/*
 * Calculate the 8-bit Fletcher checksum for a string treated as a
 * sequence of octets. The algorithim is defined in RFC1146 Appendix I:
 * http://tools.ietf.org/html/rfc1146#appendix-I
 */
static uint8_t
fletcher8(const void *buf)
{
	const uint8_t *d = buf;
	uint16_t a = 0;
	uint16_t b = 0;
	size_t i;

	for(i = 0; i < strlen(buf); i++) {
		a += d[i];
		b += a;

		a = (a & 0xff) + (a > 8);
		b = (b & 0xff) + (b > 8);
	}

	return (b << 8) | a;
}

/*
 * sprintf() prefixed with an eight-bit fletcher checksum.
 * Requires two bytes to prefix the checkum as hex.
 */
static int
ckvsprintf(char *buf, const char *fmt, ...)
{
	int n;

	/* Format string */
	{
		va_list ap;

		va_start(ap, fmt);
		n = vsprintf(buf + 2, fmt, ap);
		va_end(ap);
	}

	/* Prepend checksum */
	{
		uint8_t cksum;
		char c = buf[2];

		cksum = fletcher8(buf + 2);
		sprintf(buf, "%02X", cksum);
		buf[2] = c;
	}

	return n + 2;
}

/* 1425 ASCII printable chars */
const char extra_payload_str[] = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

/* See common.h */
const char *
mkping(uint16_t seq, int extra_payload, int no_checksum)
{
	static char buf[DEFAULT_PAYLOAD + MAX_EXTRA_PAYLOAD];
	time_t t;
	int i;

	t = time(NULL);
	if ((time_t) -1 == t) {
		perror("time");
		exit(EXIT_FAILURE);
	}

	if (extra_payload > MAX_EXTRA_PAYLOAD) {
		extra_payload = MAX_EXTRA_PAYLOAD;
	}

	/*
	 * The time formatted here is not actually used; it is for human reference
	 * only.
	 *
	 * TODO mention fletcher needs a few bytes for entropy?
	 */
	/* TODO: strftime %z */
	if (no_checksum) {
		sprintf(buf, "00 %04X %.24s\n%.*s", seq, ctime(&t), extra_payload, extra_payload_str);
	} else {
		ckvsprintf(buf, " %04X %.24s\n%.*s", seq, ctime(&t), extra_payload, extra_payload_str);
	}

	return buf;
}

/* See common.h */
int
validate(const char *in, uint16_t *seq, int no_checksum)
{
	unsigned int tck;
	unsigned int n;
	uint8_t ock;

	if (2 != sscanf(in, "%02X %04X ", &tck, &n)) {
		fprintf(stderr, "disregarding: unrecognised format\n");
		return 0;
	}

	if (!no_checksum) {
		ock = fletcher8(in + 2);
		if (ock != tck) {
			fprintf(stderr, "disregarding: checksum mismatch: %X != %X\n", ock, tck);
			return 0;
		}
	}

	*seq = n;
	return 1;
}

/* See common.h */
int
getaddr(const char *addr, const char *port, struct sockaddr_in *sin,
	int type, int protocol)
{
	in_addr_t a;
	in_port_t p;
	int s;

	/* Port */
	{
		long int l;
		char *ep;

		l = strtol(port, &ep, 10);
		if (*ep) {
			fprintf(stderr, "invalid port\n");
			return -1;
		}

		if (l < 0 || (unsigned long int) l > UINT16_MAX) {
			fprintf(stderr, "port out of range\n");
			return -1;
		}

		p = l;
	}

	/* Address */
	{
		a = inet_addr(addr);
		if (INADDR_NONE == a) {
			fprintf(stderr, "malformed address\n");
			return -1;
		}

		memset(sin, 0, sizeof *sin);
		sin->sin_family = AF_INET;
		sin->sin_port = htons(p);
		sin->sin_addr.s_addr = a;
#ifdef HAVE_SALEN
		sin->sin_len = sizeof (*sin);
#endif
	}

	/* Socket */
	s = socket(PF_INET,  type, protocol);
	if (-1 == s) {
		perror("socket");
		return -1;
	}

	return s;
}

