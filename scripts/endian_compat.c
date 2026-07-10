/* Apple libc has no <endian.h> be/le conversion fns; LibreSSL references them. */
#include <libkern/OSByteOrder.h>
uint16_t htobe16(uint16_t x){return OSSwapHostToBigInt16(x);}
uint16_t htole16(uint16_t x){return OSSwapHostToLittleInt16(x);}
uint16_t be16toh(uint16_t x){return OSSwapBigToHostInt16(x);}
uint16_t le16toh(uint16_t x){return OSSwapLittleToHostInt16(x);}
uint32_t htobe32(uint32_t x){return OSSwapHostToBigInt32(x);}
uint32_t htole32(uint32_t x){return OSSwapHostToLittleInt32(x);}
uint32_t be32toh(uint32_t x){return OSSwapBigToHostInt32(x);}
uint32_t le32toh(uint32_t x){return OSSwapLittleToHostInt32(x);}
uint64_t htobe64(uint64_t x){return OSSwapHostToBigInt64(x);}
uint64_t htole64(uint64_t x){return OSSwapHostToLittleInt64(x);}
uint64_t be64toh(uint64_t x){return OSSwapBigToHostInt64(x);}
uint64_t le64toh(uint64_t x){return OSSwapLittleToHostInt64(x);}
