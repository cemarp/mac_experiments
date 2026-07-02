#ifndef SMC_h
#define SMC_h

#include <IOKit/IOKitLib.h>

typedef struct {
    unsigned char major;
    unsigned char minor;
    unsigned char build;
    unsigned char reserved;
    unsigned short release;
} SMCVersion;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCPLimitData;

typedef struct {
    IOByteCount dataSize;
    uint32_t dataType;
    uint8_t dataAttributes;
} SMCKeyInfoData;

#pragma pack(push, 1)
typedef struct {
    uint32_t key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfoData keyInfo;
    uint8_t result;
    uint8_t status;
    uint8_t data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCParamStruct;
#pragma pack(pop)

#endif /* SMC_h */
