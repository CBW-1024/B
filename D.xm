






#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-but-set-variable"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wunused-const-variable"
#pragma clang diagnostic ignored "-Wunused-value"
#pragma clang diagnostic ignored "-Wunused-label"
#pragma clang diagnostic ignored "-Wsign-compare"
#pragma clang diagnostic ignored "-Wsign-conversion"
#pragma clang diagnostic ignored "-Wtype-limits"
#pragma clang diagnostic ignored "-Wtautological-compare"
#pragma clang diagnostic ignored "-Wtautological-constant-out-of-range-compare"
#pragma clang diagnostic ignored "-Wparentheses"
#pragma clang diagnostic ignored "-Wlogical-op-parentheses"
#pragma clang diagnostic ignored "-Wbitwise-op-parentheses"
#pragma clang diagnostic ignored "-Wshift-op-parentheses"
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#pragma clang diagnostic ignored "-Wconditional-uninitialized"
#pragma clang diagnostic ignored "-Wunreachable-code"
#pragma clang diagnostic ignored "-Wunreachable-code-loop-increment"
#pragma clang diagnostic ignored "-Wstrict-prototypes"
#pragma clang diagnostic ignored "-Wmissing-prototypes"
#pragma clang diagnostic ignored "-Wmissing-field-initializers"
#pragma clang diagnostic ignored "-Wmissing-braces"
#pragma clang diagnostic ignored "-Wmissing-variable-declarations"
#pragma clang diagnostic ignored "-Wold-style-definition"
#pragma clang diagnostic ignored "-Wcomma"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wformat"
#pragma clang diagnostic ignored "-Wformat-security"
#pragma clang diagnostic ignored "-Wpointer-sign"
#pragma clang diagnostic ignored "-Wint-conversion"
#pragma clang diagnostic ignored "-Wenum-conversion"
#pragma clang diagnostic ignored "-Wabsolute-value"
#pragma clang diagnostic ignored "-Wsizeof-array-argument"
#pragma clang diagnostic ignored "-Wsizeof-pointer-memaccess"
#pragma clang diagnostic ignored "-Warray-bounds"
#pragma clang diagnostic ignored "-Wcast-align"
#pragma clang diagnostic ignored "-Wcast-qual"
#pragma clang diagnostic ignored "-Wchar-subscripts"
#pragma clang diagnostic ignored "-Wcomment"
#pragma clang diagnostic ignored "-Wempty-body"
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wfloat-conversion"
#pragma clang diagnostic ignored "-Wdouble-promotion"
#pragma clang diagnostic ignored "-Wimplicit-int"
#pragma clang diagnostic ignored "-Wmain-return-type"
#pragma clang diagnostic ignored "-Wmultichar"
#pragma clang diagnostic ignored "-Wnested-externs"
#pragma clang diagnostic ignored "-Wnewline-eof"
#pragma clang diagnostic ignored "-Wnullability"
#pragma clang diagnostic ignored "-Wnullability-completeness"
#pragma clang diagnostic ignored "-Wpedantic"
#pragma clang diagnostic ignored "-Wpointer-arith"
#pragma clang diagnostic ignored "-Wredundant-decls"
#pragma clang diagnostic ignored "-Wreturn-type"
#pragma clang diagnostic ignored "-Wsequence-point"
#pragma clang diagnostic ignored "-Wswitch"
#pragma clang diagnostic ignored "-Wswitch-enum"
#pragma clang diagnostic ignored "-Wtrigraphs"
#pragma clang diagnostic ignored "-Wundef"
#pragma clang diagnostic ignored "-Wvarargs"
#pragma clang diagnostic ignored "-Wwrite-strings"
#pragma clang diagnostic ignored "-Wshadow"
#pragma clang diagnostic ignored "-Wpadded"
#pragma clang diagnostic ignored "-Wdocumentation"
#pragma clang diagnostic ignored "-Wextra"
#pragma clang diagnostic ignored "-Wimplicit-fallthrough"
#pragma clang diagnostic ignored "-Wdollar-in-identifier-extension"
#pragma clang diagnostic ignored "-Wbackslash-newline-extension"
#pragma clang diagnostic ignored "-Wembedded-directive"
#pragma clang diagnostic ignored "-Wunknown-pragmas"
#pragma clang diagnostic ignored "-Wunused-macros"
#pragma clang diagnostic ignored "-Wreserved-id-macro"
#pragma clang diagnostic ignored "-Wbad-function-cast"
#pragma clang diagnostic ignored "-Wtraditional-conversion"
#pragma clang diagnostic ignored "-Wdeclaration-after-statement"
#pragma clang diagnostic ignored "-Wunsafe-buffer-usage"
#ifdef __cplusplus
extern "C" {
#endif












#ifndef _SKP_SILK_SIGPROC_FIX_H_
#define _SKP_SILK_SIGPROC_FIX_H_

#ifdef  __cplusplus
extern "C"
{
#endif

#define SKP_Silk_MAX_ORDER_LPC            16                    
#define SKP_Silk_MAX_CORRELATION_LENGTH   640                   



#ifndef _SKP_SILK_API_TYPDEF_H_
#define _SKP_SILK_API_TYPDEF_H_

#ifndef SKP_USE_DOUBLE_PRECISION_FLOATS
#define SKP_USE_DOUBLE_PRECISION_FLOATS		0
#endif

#include <float.h>
#if defined( __GNUC__ )
#include <stdint.h>
#endif

#define SKP_int         int                     
#ifdef __GNUC__
# define SKP_int64      int64_t
#else
# define SKP_int64      long long
#endif
#define SKP_int32       int
#define SKP_int16       short
#define SKP_int8        signed char

#define SKP_uint        unsigned int            
#ifdef __GNUC__
# define SKP_uint64     uint64_t
#else
# define SKP_uint64     unsigned long long
#endif
#define SKP_uint32      unsigned int
#define SKP_uint16      unsigned short
#define SKP_uint8       unsigned char

#define SKP_int_ptr_size intptr_t

#if SKP_USE_DOUBLE_PRECISION_FLOATS
# define SKP_float      double
# define SKP_float_MAX  DBL_MAX
#else
# define SKP_float      float
# define SKP_float_MAX  FLT_MAX
#endif

#define SKP_INLINE      static __inline

#ifdef _WIN32
# define SKP_STR_CASEINSENSITIVE_COMPARE(x, y) _stricmp(x, y)
#else
# define SKP_STR_CASEINSENSITIVE_COMPARE(x, y) strcasecmp(x, y)
#endif 

#define	SKP_int64_MAX	((SKP_int64)0x7FFFFFFFFFFFFFFFLL)	
#define SKP_int64_MIN	((SKP_int64)0x8000000000000000LL)	
#define	SKP_int32_MAX	0x7FFFFFFF							
#define SKP_int32_MIN	((SKP_int32)0x80000000)				
#define	SKP_int16_MAX	0x7FFF								
#define SKP_int16_MIN	((SKP_int16)0x8000)					
#define	SKP_int8_MAX	0x7F								
#define SKP_int8_MIN	((SKP_int8)0x80)					

#define SKP_uint32_MAX	0xFFFFFFFF	
#define SKP_uint32_MIN	0x00000000
#define SKP_uint16_MAX	0xFFFF		
#define SKP_uint16_MIN	0x0000
#define SKP_uint8_MAX	0xFF		
#define SKP_uint8_MIN	0x00

#define SKP_TRUE		1
#define SKP_FALSE		0


#if (defined _WIN32 && !defined _WINCE && !defined(__GNUC__) && !defined(NO_ASSERTS))
# ifndef SKP_assert
#  include <crtdbg.h>      
#  define SKP_assert(COND)   _ASSERTE(COND)
# endif
#else
# define SKP_assert(COND)
#endif

#endif
#include <string.h>
#include <stdlib.h>                                            





#ifndef SKP_Silk_RESAMPLER_STRUCTS_H
#define SKP_Silk_RESAMPLER_STRUCTS_H

#ifdef __cplusplus
extern "C" {
#endif


#define RESAMPLER_SUPPORT_ABOVE_48KHZ                   1

#define SKP_Silk_RESAMPLER_MAX_FIR_ORDER                 16
#define SKP_Silk_RESAMPLER_MAX_IIR_ORDER                 6


typedef struct _SKP_Silk_resampler_state_struct{
	SKP_int32       sIIR[ SKP_Silk_RESAMPLER_MAX_IIR_ORDER ];        
	SKP_int32       sFIR[ SKP_Silk_RESAMPLER_MAX_FIR_ORDER ];
	SKP_int32       sDown2[ 2 ];
	void            (*resampler_function)( void *, SKP_int16 *, const SKP_int16 *, SKP_int32 );
	void            (*up2_function)(  SKP_int32 *, SKP_int16 *, const SKP_int16 *, SKP_int32 );
    SKP_int32       batchSize;
	SKP_int32       invRatio_Q16;
	SKP_int32       FIR_Fracs;
    SKP_int32       input2x;
	const SKP_int16	*Coefs;
#if RESAMPLER_SUPPORT_ABOVE_48KHZ
	SKP_int32       sDownPre[ 2 ];
	SKP_int32       sUpPost[ 2 ];
	void            (*down_pre_function)( SKP_int32 *, SKP_int16 *, const SKP_int16 *, SKP_int32 );
	void            (*up_post_function)(  SKP_int32 *, SKP_int16 *, const SKP_int16 *, SKP_int32 );
	SKP_int32       batchSizePrePost;
	SKP_int32       ratio_Q16;
	SKP_int32       nPreDownsamplers;
	SKP_int32       nPostUpsamplers;
#endif
	SKP_int32 magic_number;
} SKP_Silk_resampler_state_struct;

#ifdef __cplusplus
}
#endif
#endif 


#ifndef NO_ASM
#	if defined (__ARM_ARCH_4__) || defined (__ARM_ARCH_4T__) || defined (__ARM_ARCH_5__) || defined (__ARM_ARCH_5T__)
#		define EMBEDDED_ARM 4
#		define EMBEDDED_ARMv4



#ifndef _SKP_SILK_API_ARM_H_
#define _SKP_SILK_API_ARM_H_



#if EMBEDDED_ARM==4
extern SKP_int32 SKP_Silk_CLZ16(SKP_int16 in16);
extern SKP_int32 SKP_Silk_CLZ32(SKP_int32 in32);


#define SKP_SMULWB(a32, b32)			((((a32) >> 16) * (SKP_int32)((SKP_int16)(b32))) + ((((a32) & 0x0000FFFF) * (SKP_int32)((SKP_int16)(b32))) >> 16))


#define SKP_SMLAWB(a32, b32, c32)		((a32) + ((((b32) >> 16) * (SKP_int32)((SKP_int16)(c32))) + ((((b32) & 0x0000FFFF) * (SKP_int32)((SKP_int16)(c32))) >> 16)))




#define SKP_SMULWT(a32, b32)			(((a32) >> 16) * ((b32) >> 16) + ((((a32) & 0x0000FFFF) * ((b32) >> 16)) >> 16))


#define SKP_SMLAWT(a32, b32, c32)		((a32) + (((b32) >> 16) * ((c32) >> 16)) + ((((b32) & 0x0000FFFF) * ((c32) >> 16)) >> 16))


#define SKP_SMULBB(a32, b32)			((SKP_int32)((SKP_int16)(a32)) * (SKP_int32)((SKP_int16)(b32)))


#define SKP_SMLABB(a32, b32, c32)		((a32) + ((SKP_int32)((SKP_int16)(b32))) * (SKP_int32)((SKP_int16)(c32)))


#define SKP_SMLABB_ovflw(a32, b32, c32)	((a32) + ((SKP_int32)((SKP_int16)(b32))) * (SKP_int32)((SKP_int16)(c32)))


#define SKP_SMULBT(a32, b32)			((SKP_int32)((SKP_int16)(a32)) * ((b32) >> 16))


#define SKP_SMLABT(a32, b32, c32)		((a32) + ((SKP_int32)((SKP_int16)(b32))) * ((c32) >> 16))

SKP_INLINE SKP_int64 SKP_SMLAL(SKP_int64 a64, SKP_int32 b32, SKP_int32 c32)
{
#ifdef IPHONE
    
    a64 = (SKP_int64)b32 * c32;
    return(a64);
#else
	__asm__ __volatile__ ("smlal %Q0, %R0, %2, %3" : "=r" (a64) : "0" (a64), "r" (b32), "r" (c32));	
	return(a64);
#endif    
}


#define SKP_SMULWW(a32, b32)			SKP_MLA(SKP_SMULWB((a32), (b32)), (a32), SKP_RSHIFT_ROUND((b32), 16))


#define SKP_SMLAWW(a32, b32, c32)		SKP_MLA(SKP_SMLAWB((a32), (b32), (c32)), (b32), SKP_RSHIFT_ROUND((c32), 16))


#define SKP_ADD_SAT32(a, b)				((((a) + (b)) & 0x80000000) == 0 ?								\
										((((a) & (b)) & 0x80000000) != 0 ? SKP_int32_MIN : (a)+(b)) :	\
										((((a) | (b)) & 0x80000000) == 0 ? SKP_int32_MAX : (a)+(b)) )

#define SKP_SUB_SAT32(a, b)				((((a)-(b)) & 0x80000000) == 0 ?										\
										(( (a) & ((b)^0x80000000) & 0x80000000) ? SKP_int32_MIN : (a)-(b)) :	\
										((((a)^0x80000000) & (b)  & 0x80000000) ? SKP_int32_MAX : (a)-(b)) )

#define SKP_SMMUL(a32, b32)				(SKP_int32)SKP_RSHIFT64(SKP_SMULL((a32), (b32)), 32)


#else
SKP_INLINE SKP_int32 SKP_SMULWB(SKP_int32 a32, SKP_int32 b32) {
	SKP_int32 out32;
	__asm__ __volatile__ ("smulwb %0, %1, %2" : "=r" (out32) : "r" (a32), "r" (b32));	
	return(out32);
}


SKP_INLINE SKP_int32 SKP_SMLAWB(SKP_int32 a32, SKP_int32 b32, SKP_int32 c32) {
	SKP_int32 out32;
	__asm__ __volatile__ ("smlawb %0, %2, %3, %1" : "=r" (out32) : "r" (a32), "r" (b32), "r" (c32));	
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SMULWT(SKP_int32 a32, SKP_int32 b32)
{
	SKP_int32 out32;
	__asm__ __volatile__ ("smulwt %0, %1, %2" : "=r" (out32) : "r" (a32), "r" (b32));
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SMLAWT(SKP_int32 a32, SKP_int32 b32, SKP_int32 c32)
{
	SKP_int32 out32;
	__asm__ __volatile__ ("smlawt %0, %2, %3, %1" : "=r" (out32) : "r" (a32), "r" (b32), "r" (c32));
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SMULBB(SKP_int32 a32, SKP_int32 b32) {
	SKP_int32 out32;
	__asm__ __volatile__ ("smulbb %0, %1, %2" : "=r" (out32) : "r" (a32), "r" (b32));	
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SMLABB(SKP_int32 a32, SKP_int32 b32, SKP_int32 c32) {
	SKP_int32 out32;
	__asm__ __volatile__ ("smlabb %0, %2, %3, %1" : "=r" (out32) : "r" (a32), "r" (b32), "r" (c32));	
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SMLABB_ovflw(SKP_int32 a32, SKP_int32 b32, SKP_int32 c32) {
	SKP_int32 out32;
	__asm__ __volatile__ ("smlabb %0, %2, %3, %1" : "=r" (out32) : "r" (a32), "r" (b32), "r" (c32));	
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SMULBT(SKP_int32 a32, SKP_int32 b32) {
	SKP_int32 out32;
	__asm__ __volatile__ ("smulbt %0, %1, %2" : "=r" (out32) : "r" (a32), "r" (b32));	
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SMLABT(SKP_int32 a32, SKP_int32 b32, SKP_int32 c32) {
	SKP_int32 out32;
	__asm__ __volatile__ ("smlabt %0, %2, %3, %1" : "=r" (out32) : "r" (a32), "r" (b32), "r" (c32));	
	return(out32);
}

SKP_INLINE SKP_int64 SKP_SMLAL(SKP_int64 a64, SKP_int32 b32, SKP_int32 c32)
{
#ifdef IPHONE
    
    a64 = (SKP_int64)b32 * c32;
    return(a64);
#else
	__asm__ __volatile__ ("smlal %Q0, %R0, %2, %3" : "=r" (a64) : "0" (a64), "r" (b32), "r" (c32));	
	return(a64);
#endif    
}

#define SKP_SMULWW(a32, b32)			SKP_MLA(SKP_SMULWB((a32), (b32)), (a32), SKP_RSHIFT_ROUND((b32), 16))


#define SKP_SMLAWW(a32, b32, c32)		SKP_MLA(SKP_SMLAWB((a32), (b32), (c32)), (b32), SKP_RSHIFT_ROUND((c32), 16))


SKP_INLINE SKP_int32 SKP_ADD_SAT32(SKP_int32 a32, SKP_int32 b32) {
	SKP_int32 out32;
	__asm__ __volatile__ ("qadd %0, %1, %2" : "=r" (out32) : "r" (a32), "r" (b32));	
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SUB_SAT32(SKP_int32 a32, SKP_int32 b32) {
	SKP_int32 out32;
	__asm__ __volatile__ ("qsub %0, %1, %2" : "=r" (out32) : "r" (a32), "r" (b32));	
	return(out32);
}

SKP_INLINE SKP_int32 SKP_Silk_CLZ16(SKP_int16 in16)
{
	SKP_int32 out32;
	__asm__ __volatile__ ("movs %0, %1, lsl #16 
	clz %0, %0 
	 it eq 
	 moveq %0, #16" : "=r" (out32) : "r" (in16) : "cc");	
	return(out32);
}

SKP_INLINE SKP_int32 SKP_Silk_CLZ32(SKP_int32 in32)
{
	SKP_int32 out32;
	__asm__ __volatile__ ("clz %0, %1" : "=r" (out32) : "r" (in32));	
	return(out32);
}
#if EMBEDDED_ARM < 6
#define SKP_SMMUL(a32, b32)				(SKP_int32)SKP_RSHIFT64(SKP_SMULL((a32), (b32)), 32)
#endif
#endif



#if EMBEDDED_ARM>=6

SKP_INLINE SKP_int32 SKP_SMMUL(SKP_int32 a32, SKP_int32 b32){			
	SKP_int32 out32;
	__asm__ __volatile__ ("smmul %0, %1, %2" : "=r" (out32) : "r" (a32), "r" (b32));	
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SMUAD(SKP_int32 a32, SKP_int32 b32)
{
	SKP_int32 out32;
	__asm__ __volatile__ ("smuad %0, %1, %2" : "=r" (out32) : "r" (a32), "r" (b32));
	return(out32);
}

SKP_INLINE SKP_int32 SKP_SMLAD(SKP_int32 a32, SKP_int32 b32, SKP_int32 c32)
{
	SKP_int32 out32;
	__asm__ __volatile__ ("smlad %0, %2, %3, %1" : "=r" (out32) : "r" (a32), "r" (b32), "r" (c32));
	return(out32);
}

#endif

#endif 



#	elif defined (__ARM_ARCH_5TE__) || defined (__ARM_ARCH_5TEJ__)
#		define EMBEDDED_ARM 5
#		define EMBEDDED_ARMv5

#	elif defined (__ARM_ARCH_6__) ||defined (__ARM_ARCH_6J__) || defined (__ARM_ARCH_6Z__) || defined (__ARM_ARCH_6K__) || defined(__ARM_ARCH_6ZK__) || defined(__ARM_ARCH_6T2__)
#		define EMBEDDED_ARM 6
#		define EMBEDDED_ARMv6

#	elif defined (__ARM_ARCH_7A__) && defined (__ARM_NEON__)
#		define EMBEDDED_ARM 7
#		define EMBEDDED_ARMv6

#	elif defined (__ARM_ARCH_7A__)
#		define EMBEDDED_ARM 6
#		define EMBEDDED_ARMv6

#	else



#ifndef _SKP_SILK_API_C_H_
#define _SKP_SILK_API_C_H_




#define SKP_SMULWB(a32, b32)            ((((a32) >> 16) * (SKP_int32)((SKP_int16)(b32))) + ((((a32) & 0x0000FFFF) * (SKP_int32)((SKP_int16)(b32))) >> 16))


#define SKP_SMLAWB(a32, b32, c32)       ((a32) + ((((b32) >> 16) * (SKP_int32)((SKP_int16)(c32))) + ((((b32) & 0x0000FFFF) * (SKP_int32)((SKP_int16)(c32))) >> 16)))


#define SKP_SMULWT(a32, b32)            (((a32) >> 16) * ((b32) >> 16) + ((((a32) & 0x0000FFFF) * ((b32) >> 16)) >> 16))


#define SKP_SMLAWT(a32, b32, c32)       ((a32) + (((b32) >> 16) * ((c32) >> 16)) + ((((b32) & 0x0000FFFF) * ((c32) >> 16)) >> 16))


#define SKP_SMULBB(a32, b32)            ((SKP_int32)((SKP_int16)(a32)) * (SKP_int32)((SKP_int16)(b32)))


#define SKP_SMLABB(a32, b32, c32)       ((a32) + ((SKP_int32)((SKP_int16)(b32))) * (SKP_int32)((SKP_int16)(c32)))


#define SKP_SMULBT(a32, b32)            ((SKP_int32)((SKP_int16)(a32)) * ((b32) >> 16))


#define SKP_SMLABT(a32, b32, c32)       ((a32) + ((SKP_int32)((SKP_int16)(b32))) * ((c32) >> 16))


#define SKP_SMLAL(a64, b32, c32)        (SKP_ADD64((a64), ((SKP_int64)(b32) * (SKP_int64)(c32))))


#define SKP_SMULWW(a32, b32)            SKP_MLA(SKP_SMULWB((a32), (b32)), (a32), SKP_RSHIFT_ROUND((b32), 16))


#define SKP_SMLAWW(a32, b32, c32)       SKP_MLA(SKP_SMLAWB((a32), (b32), (c32)), (b32), SKP_RSHIFT_ROUND((c32), 16))


#define SKP_SMMUL(a32, b32)             (SKP_int32)SKP_RSHIFT64(SKP_SMULL((a32), (b32)), 32)


#define SKP_ADD_SAT32(a, b)             ((((a) + (b)) & 0x80000000) == 0 ?                              \
                                        ((((a) & (b)) & 0x80000000) != 0 ? SKP_int32_MIN : (a)+(b)) :   \
                                        ((((a) | (b)) & 0x80000000) == 0 ? SKP_int32_MAX : (a)+(b)) )

#define SKP_SUB_SAT32(a, b)             ((((a)-(b)) & 0x80000000) == 0 ?                                        \
                                        (( (a) & ((b)^0x80000000) & 0x80000000) ? SKP_int32_MIN : (a)-(b)) :    \
                                        ((((a)^0x80000000) & (b)  & 0x80000000) ? SKP_int32_MAX : (a)-(b)) )
    
SKP_INLINE SKP_int32 SKP_Silk_CLZ16(SKP_int16 in16)
{
    SKP_int32 out32 = 0;
    if( in16 == 0 ) {
        return 16;
    }
    
    if( in16 & 0xFF00 ) {
        if( in16 & 0xF000 ) {
            in16 >>= 12;
        } else {
            out32 += 4;
            in16 >>= 8;
        }
    } else {
        if( in16 & 0xFFF0 ) {
            out32 += 8;
            in16 >>= 4;
        } else {
            out32 += 12;
        }
    }
    
    if( in16 & 0xC ) {
        if( in16 & 0x8 )
            return out32 + 0;
        else
            return out32 + 1;
    } else {
        if( in16 & 0xE )
            return out32 + 2;
        else
            return out32 + 3;
    }
}

SKP_INLINE SKP_int32 SKP_Silk_CLZ32(SKP_int32 in32)
{
    
    if( in32 & 0xFFFF0000 ) {
        return SKP_Silk_CLZ16((SKP_int16)(in32 >> 16));
    } else {
        return SKP_Silk_CLZ16((SKP_int16)in32) + 16;
    }
}

#endif 

#	endif
#else
#	define EMBEDDED_ARM 0

#endif








SKP_int SKP_Silk_resampler_init( 
	SKP_Silk_resampler_state_struct	*S,		    
	SKP_int32							Fs_Hz_in,	
	SKP_int32							Fs_Hz_out	
);



SKP_int SKP_Silk_resampler_clear( 
	SKP_Silk_resampler_state_struct	*S		    
);


SKP_int SKP_Silk_resampler( 
	SKP_Silk_resampler_state_struct	*S,		    
	SKP_int16							out[],	    
	const SKP_int16						in[],	    
	SKP_int32							inLen	    
);


void SKP_Silk_resampler_up2(
    SKP_int32                           *S,         
    SKP_int16                           *out,       
    const SKP_int16                     *in,        
    SKP_int32                           len         
);


void SKP_Silk_resampler_down2(
    SKP_int32                           *S,         
    SKP_int16                           *out,       
    const SKP_int16                     *in,        
    SKP_int32                           inLen       
);



void SKP_Silk_resampler_down2_3(
    SKP_int32                           *S,         
    SKP_int16                           *out,       
    const SKP_int16                     *in,        
    SKP_int32                           inLen       
);


void SKP_Silk_resampler_down3(
    SKP_int32                           *S,         
    SKP_int16                           *out,       
    const SKP_int16                     *in,        
    SKP_int32                           inLen       
);


void SKP_Silk_biquad(
    const SKP_int16      *in,          
    const SKP_int16      *B,           
    const SKP_int16      *A,           
          SKP_int32      *S,           
          SKP_int16      *out,         
    const SKP_int32      len           
);

void SKP_Silk_biquad_alt(
    const SKP_int16     *in,           
    const SKP_int32     *B_Q28,        
    const SKP_int32     *A_Q28,        
    SKP_int32           *S,            
    SKP_int16           *out,          
    const SKP_int32     len            
);


void SKP_Silk_MA_Prediction(
    const SKP_int16      *in,          
    const SKP_int16      *B,           
    SKP_int32            *S,           
    SKP_int16            *out,         
    const SKP_int32      len,          
    const SKP_int32      order         
);


void SKP_Silk_LPC_synthesis_order16(
    const SKP_int16      *in,          
    const SKP_int16      *A_Q12,       
    const SKP_int32      Gain_Q26,     
          SKP_int32      *S,           
          SKP_int16      *out,         
    const SKP_int32      len           
);



void SKP_Silk_LPC_analysis_filter(
    const SKP_int16      *in,          
    const SKP_int16      *B,           
    SKP_int16            *S,           
    SKP_int16            *out,         
    const SKP_int32      len,          
    const SKP_int32      Order         
);


void SKP_Silk_LPC_synthesis_filter(
    const SKP_int16      *in,          
    const SKP_int16      *A_Q12,       
    const SKP_int32      Gain_Q26,     
    SKP_int32            *S,           
    SKP_int16            *out,         
    const SKP_int32      len,          
    const SKP_int        Order         
);


void SKP_Silk_bwexpander( 
    SKP_int16            *ar,          
    const SKP_int        d,            
    SKP_int32            chirp_Q16     
);


void SKP_Silk_bwexpander_32( 
    SKP_int32            *ar,          
    const SKP_int        d,            
    SKP_int32            chirp_Q16     
);



SKP_int SKP_Silk_LPC_inverse_pred_gain( 
    SKP_int32            *invGain_Q30,  
    const SKP_int16      *A_Q12,        
    const SKP_int        order          
);

SKP_int SKP_Silk_LPC_inverse_pred_gain_Q24( 
    SKP_int32           *invGain_Q30,   
    const SKP_int32     *A_Q24,         
    const SKP_int       order           
);


void SKP_Silk_ana_filt_bank_1(
    const SKP_int16      *in,           
    SKP_int32            *S,            
    SKP_int16            *outL,         
    SKP_int16            *outH,         
    SKP_int32            *scratch,      
    const SKP_int32      N              
);







SKP_int32 SKP_Silk_lin2log(const SKP_int32 inLin);        


SKP_int SKP_Silk_sigm_Q15(SKP_int in_Q5);


 
SKP_int32 SKP_Silk_log2lin(const SKP_int32 inLog_Q7);     


SKP_int16 SKP_Silk_int16_array_maxabs(  
    const SKP_int16     *vec,            
    const SKP_int32     len             
);



void SKP_Silk_sum_sqr_shift(
    SKP_int32           *energy,        
    SKP_int             *shift,         
    const SKP_int16     *x,             
    SKP_int             len             
);



 
SKP_int32 SKP_Silk_schur(               
    SKP_int16            *rc_Q15,       
    const SKP_int32      *c,            
    const SKP_int32      order          
);




SKP_int32 SKP_Silk_schur64(             
    SKP_int32           rc_Q16[],       
    const SKP_int32     c[],            
    SKP_int32           order           
);


void SKP_Silk_k2a(
    SKP_int32           *A_Q24,         
    const SKP_int16     *rc_Q15,        
    const SKP_int32     order           
);


void SKP_Silk_k2a_Q16(
    SKP_int32           *A_Q24,         
    const SKP_int32     *rc_Q16,        
    const SKP_int32     order           
);






void SKP_Silk_apply_sine_window(
    SKP_int16                        px_win[],            
    const SKP_int16                  px[],                
    const SKP_int                    win_type,            
    const SKP_int                    length               
);


void SKP_Silk_autocorr( 
    SKP_int32           *results,       
    SKP_int             *scale,         
    const SKP_int16     *inputData,     
    const SKP_int       inputDataSize,  
    const SKP_int       correlationCount 
);


#define SKP_Silk_PITCH_EST_MIN_COMPLEX        0
#define SKP_Silk_PITCH_EST_MID_COMPLEX        1
#define SKP_Silk_PITCH_EST_MAX_COMPLEX        2

void SKP_Silk_decode_pitch(
    SKP_int            lagIndex,        
    SKP_int            contourIndex,    
    SKP_int            pitch_lags[],    
    SKP_int            Fs_kHz           
);

SKP_int SKP_Silk_pitch_analysis_core(    
    const SKP_int16  *signal,            
    SKP_int          *pitch_out,         
    SKP_int          *lagIndex,          
    SKP_int          *contourIndex,      
    SKP_int          *LTPCorr_Q15,       
    SKP_int          prevLag,            
    const SKP_int32  search_thres1_Q16,  
    const SKP_int    search_thres2_Q15,  
    const SKP_int    Fs_kHz,             
    const SKP_int    complexity,         
	const SKP_int	 forLJC			     
);




#define LSF_COS_TAB_SZ_FIX      128

extern const SKP_int SKP_Silk_LSFCosTab_FIX_Q12[ LSF_COS_TAB_SZ_FIX + 1 ];



void SKP_Silk_A2NLSF(
    SKP_int            *NLSF,            
    SKP_int32          *a_Q16,           
    const SKP_int      d                 
);


void SKP_Silk_NLSF2A(
    SKP_int16          *a,               
    const SKP_int      *NLSF,            
    const SKP_int      d                 
);

void SKP_Silk_insertion_sort_increasing(
    SKP_int32            *a,            
    SKP_int              *index,        
    const SKP_int        L,             
    const SKP_int        K              
);

void SKP_Silk_insertion_sort_decreasing_int16(
    SKP_int16            *a,            
    SKP_int              *index,        
    const SKP_int        L,             
    const SKP_int        K              
);

void SKP_Silk_insertion_sort_increasing_all_values(
     SKP_int             *a,            
     const SKP_int       L              
);


void SKP_Silk_NLSF_stabilize(
          SKP_int        *NLSF_Q15,      
    const SKP_int        *NDeltaMin_Q15, 
    const SKP_int        L               
);


void SKP_Silk_NLSF_VQ_weights_laroia(
    SKP_int              *pNLSFW_Q6,     
    const SKP_int        *pNLSF_Q15,     
    const SKP_int        D               
);


void SKP_Silk_burg_modified(        
    SKP_int32            *res_nrg,           
    SKP_int              *res_nrgQ,          
    SKP_int32            A_Q16[],            
    const SKP_int16      x[],                
    const SKP_int        subfr_length,       
    const SKP_int        nb_subfr,           
    const SKP_int32      WhiteNoiseFrac_Q32, 
    const SKP_int        D                   
);


void SKP_Silk_scale_copy_vector16( 
    SKP_int16            *data_out, 
    const SKP_int16      *data_in, 
    SKP_int32            gain_Q16,           
    const SKP_int        dataSize            
);


void SKP_Silk_scale_vector32_Q26_lshift_18( 
    SKP_int32            *data1,             
    SKP_int32            gain_Q26,           
    SKP_int              dataSize            
);







SKP_int32 SKP_Silk_inner_prod_aligned(
    const SKP_int16* const inVec1,            
    const SKP_int16* const inVec2,           
    const SKP_int          len               
);

SKP_int64 SKP_Silk_inner_prod16_aligned_64(
    const SKP_int16        *inVec1,          
    const SKP_int16        *inVec2,          
    const SKP_int          len               
);





#if defined(EMBEDDED_MIPS)

SKP_INLINE SKP_int32 SKP_ROR32(SKP_int32 a32, SKP_int rot)
{
    SKP_uint32 _x = (SKP_uint32) a32;
    SKP_uint32 _r = (SKP_uint32) rot;
    return (SKP_int32) ((_x << (32 - _r)) | (_x >> _r));
}
#else

SKP_INLINE SKP_int32 SKP_ROR32( SKP_int32 a32, SKP_int rot )
{
    SKP_uint32 x = (SKP_uint32) a32;
    SKP_uint32 r = (SKP_uint32) rot;
    SKP_uint32 m = (SKP_uint32) -rot;
    if(rot <= 0)
        return (SKP_int32) ((x << m) | (x >> (32 - m)));
    else
        return (SKP_int32) ((x << (32 - r)) | (x >> r));
}
#endif


#if EMBEDDED_ARM
#if defined(_WIN32) && defined(_M_ARM)
#define SKP_DWORD_ALIGN __declspec(align(4))
#else
#define SKP_DWORD_ALIGN __attribute__((aligned(4)))
#endif
#else
#define SKP_DWORD_ALIGN
#endif


#define SKP_memcpy(a, b, c)                memcpy((a), (b), (c))    
#define SKP_memset(a, b, c)                memset((a), (b), (c))    
#define SKP_memmove(a, b, c)               memmove((a), (b), (c))    



#define SKP_MUL(a32, b32)                  ((a32) * (b32))


#define SKP_MUL_uint(a32, b32)             SKP_MUL(a32, b32)


#define SKP_MLA(a32, b32, c32)             SKP_ADD32((a32),((b32) * (c32)))


#define SKP_SMULTT(a32, b32)			(((a32) >> 16) * ((b32) >> 16))


#define SKP_SMLATT(a32, b32, c32)          SKP_ADD32((a32),((b32) >> 16) * ((c32) >> 16))

#define SKP_SMLALBB(a64, b16, c16)         SKP_ADD64((a64),(SKP_int64)((SKP_int32)(b16) * (SKP_int32)(c16)))


#define SKP_SMULL(a32, b32)                ((SKP_int64)(a32) * (b32))


#define SKP_ADD32_ovflw(a, b)               ((SKP_int32)((SKP_uint32)(a) + (SKP_uint32)(b)))

#define SKP_SUB32_ovflw(a, b)               ((SKP_int32)((SKP_uint32)(a) - (SKP_uint32)(b)))


#define SKP_MLA_ovflw(a32, b32, c32)        SKP_ADD32_ovflw((a32), (SKP_uint32)(b32) * (SKP_uint32)(c32))
#ifndef SKP_SMLABB_ovflw
 #define SKP_SMLABB_ovflw(a32, b32, c32)    SKP_ADD32_ovflw((a32), SKP_SMULBB((b32),(c32)))
#endif
#define SKP_SMLATT_ovflw(a32, b32, c32) 	SKP_ADD32_ovflw((a32), SKP_SMULTT((b32),(c32)))
#define SKP_SMLAWB_ovflw(a32, b32, c32)	    SKP_ADD32_ovflw((a32), SKP_SMULWB((b32),(c32)))
#define SKP_SMLAWT_ovflw(a32, b32, c32)	    SKP_ADD32_ovflw((a32), SKP_SMULWT((b32),(c32)))
#define SKP_DIV32_16(a32, b16)             ((SKP_int32)((a32) / (b16)))
#define SKP_DIV32(a32, b32)                ((SKP_int32)((a32) / (b32)))

#define SKP_ADD32(a, b)                    ((a) + (b))
#define SKP_ADD64(a, b)                    ((a) + (b))

#define SKP_SUB32(a, b)                    ((a) - (b))

#define SKP_SAT16(a)                       ((a) > SKP_int16_MAX ? SKP_int16_MAX : \
                                           ((a) < SKP_int16_MIN ? SKP_int16_MIN : (a)))
#define SKP_SAT32(a)                       ((a) > SKP_int32_MAX ? SKP_int32_MAX : \
                                           ((a) < SKP_int32_MIN ? SKP_int32_MIN : (a)))

#define SKP_CHECK_FIT16(a)                 (a)
#define SKP_CHECK_FIT32(a)                 (a)

#define SKP_ADD_SAT16(a, b)                (SKP_int16)SKP_SAT16( SKP_ADD32( (SKP_int32)(a), (b) ) )

 
#define SKP_ADD_POS_SAT32(a, b)            ((((a)+(b)) & 0x80000000)           ? SKP_int32_MAX : ((a)+(b)))

#define SKP_LSHIFT32(a, shift)             ((a)<<(shift))                
#define SKP_LSHIFT64(a, shift)             ((a)<<(shift))                
#define SKP_LSHIFT(a, shift)               SKP_LSHIFT32(a, shift)        

#define SKP_RSHIFT32(a, shift)             ((a)>>(shift))                
#define SKP_RSHIFT64(a, shift)             ((a)>>(shift))                
#define SKP_RSHIFT(a, shift)               SKP_RSHIFT32(a, shift)        


#define SKP_LSHIFT_SAT32(a, shift)         (SKP_LSHIFT32( SKP_LIMIT_32( (a), SKP_RSHIFT32( SKP_int32_MIN, (shift) ),    \
                                                                          SKP_RSHIFT32( SKP_int32_MAX, (shift) ) ), (shift) ))

#define SKP_LSHIFT_ovflw(a, shift)        ((a)<<(shift))        
#define SKP_LSHIFT_uint(a, shift)         ((a)<<(shift))        
#define SKP_RSHIFT_uint(a, shift)         ((a)>>(shift))        

#define SKP_ADD_LSHIFT(a, b, shift)       ((a) + SKP_LSHIFT((b), (shift)))            
#define SKP_ADD_LSHIFT32(a, b, shift)     SKP_ADD32((a), SKP_LSHIFT32((b), (shift)))    
#define SKP_ADD_RSHIFT(a, b, shift)       ((a) + SKP_RSHIFT((b), (shift)))            
#define SKP_ADD_RSHIFT32(a, b, shift)     SKP_ADD32((a), SKP_RSHIFT32((b), (shift)))    
#define SKP_ADD_RSHIFT_uint(a, b, shift)  ((a) + SKP_RSHIFT_uint((b), (shift)))        
#define SKP_SUB_LSHIFT32(a, b, shift)     SKP_SUB32((a), SKP_LSHIFT32((b), (shift)))    
#define SKP_SUB_RSHIFT32(a, b, shift)     SKP_SUB32((a), SKP_RSHIFT32((b), (shift)))    


#define SKP_RSHIFT_ROUND(a, shift)        ((shift) == 1 ? ((a) >> 1) + ((a) & 1) : (((a) >> ((shift) - 1)) + 1) >> 1)
#define SKP_RSHIFT_ROUND64(a, shift)      ((shift) == 1 ? ((a) >> 1) + ((a) & 1) : (((a) >> ((shift) - 1)) + 1) >> 1)


#define SKP_NSHIFT_MUL_32_32(a, b)        ( -(31- (32-SKP_Silk_CLZ32(SKP_abs(a)) + (32-SKP_Silk_CLZ32(SKP_abs(b))))) )

#define SKP_min(a, b)                     (((a) < (b)) ? (a) : (b)) 
#define SKP_max(a, b)                     (((a) > (b)) ? (a) : (b))


#define SKP_FIX_CONST( C, Q )           ((SKP_int32)((C) * ((SKP_int64)1 << (Q)) + 0.5))


SKP_INLINE SKP_int SKP_min_int(SKP_int a, SKP_int b)
{
    return (((a) < (b)) ? (a) : (b));
}

SKP_INLINE SKP_int32 SKP_min_32(SKP_int32 a, SKP_int32 b)
{
    return (((a) < (b)) ? (a) : (b));
}


SKP_INLINE SKP_int SKP_max_int(SKP_int a, SKP_int b)
{
    return (((a) > (b)) ? (a) : (b));
}
SKP_INLINE SKP_int16 SKP_max_16(SKP_int16 a, SKP_int16 b)
{
    return (((a) > (b)) ? (a) : (b));
}
SKP_INLINE SKP_int32 SKP_max_32(SKP_int32 a, SKP_int32 b)
{
    return (((a) > (b)) ? (a) : (b));
}

#define SKP_LIMIT( a, limit1, limit2)    ((limit1) > (limit2) ? ((a) > (limit1) ? (limit1) : ((a) < (limit2) ? (limit2) : (a))) \
                                                             : ((a) > (limit2) ? (limit2) : ((a) < (limit1) ? (limit1) : (a))))

#define SKP_LIMIT_int SKP_LIMIT
#define SKP_LIMIT_32 SKP_LIMIT



#define SKP_abs(a)                       (((a) >  0)  ? (a) : -(a))            
#define SKP_abs_int32(a)                 (((a) ^ ((a) >> 31)) - ((a) >> 31))






#define SKP_RAND(seed)                   (SKP_MLA_ovflw(907633515, (seed), 196314165))















#ifndef _SKP_SILK_FIX_INLINES_H_
#define _SKP_SILK_FIX_INLINES_H_

#include <assert.h>

#ifdef  __cplusplus
extern "C"
{
#endif


SKP_INLINE SKP_int32 SKP_Silk_CLZ64(SKP_int64 in)
{
    SKP_int32 in_upper;

    in_upper = (SKP_int32)SKP_RSHIFT64(in, 32);
    if (in_upper == 0) {
        
        return 32 + SKP_Silk_CLZ32( (SKP_int32) in );
    } else {
        
        return SKP_Silk_CLZ32( in_upper );
    }
}


SKP_INLINE void SKP_Silk_CLZ_FRAC(SKP_int32 in,            
                                    SKP_int32 *lz,           
                                    SKP_int32 *frac_Q7)      
{
    SKP_int32 lzeros = SKP_Silk_CLZ32(in);

    * lz = lzeros;
    * frac_Q7 = SKP_ROR32(in, 24 - lzeros) & 0x7f;
}




SKP_INLINE SKP_int32 SKP_Silk_SQRT_APPROX(SKP_int32 x)
{
    SKP_int32 y, lz, frac_Q7;

    if( x <= 0 ) {
        return 0;
    }

    SKP_Silk_CLZ_FRAC(x, &lz, &frac_Q7);

    if( lz & 1 ) {
        y = 32768;
    } else {
        y = 46214;        
    }

    
    y >>= SKP_RSHIFT(lz, 1);

    
    y = SKP_SMLAWB(y, y, SKP_SMULBB(213, frac_Q7));

    return y;
}


SKP_INLINE SKP_int32 SKP_Silk_norm16(SKP_int16 a) {

  SKP_int32 a32;

  
  if ((a << 1) == 0) return(0);

  a32 = a;
  
  a32 ^= SKP_RSHIFT(a32, 31);

  return SKP_Silk_CLZ32(a32) - 17;
}


SKP_INLINE SKP_int32 SKP_Silk_norm32(SKP_int32 a) {
  
  
  if ((a << 1) == 0) return(0);

  
  a ^= SKP_RSHIFT(a, 31);

  return SKP_Silk_CLZ32(a) - 1;
}


SKP_INLINE SKP_int32 SKP_DIV32_varQ(    
    const SKP_int32     a32,            
    const SKP_int32     b32,            
    const SKP_int       Qres            
)
{
    SKP_int   a_headrm, b_headrm, lshift;
    SKP_int32 b32_inv, a32_nrm, b32_nrm, result;

    SKP_assert( b32 != 0 );
    SKP_assert( Qres >= 0 );

    
    a_headrm = SKP_Silk_CLZ32( SKP_abs(a32) ) - 1;
    a32_nrm = SKP_LSHIFT(a32, a_headrm);                                    
    b_headrm = SKP_Silk_CLZ32( SKP_abs(b32) ) - 1;
    b32_nrm = SKP_LSHIFT(b32, b_headrm);                                    

    
    b32_inv = SKP_DIV32_16( SKP_int32_MAX >> 2, SKP_RSHIFT(b32_nrm, 16) );  

    
    result = SKP_SMULWB(a32_nrm, b32_inv);                                  

    
    a32_nrm -= SKP_LSHIFT_ovflw( SKP_SMMUL(b32_nrm, result), 3 );           

    
    result = SKP_SMLAWB(result, a32_nrm, b32_inv);                          

    
    lshift = 29 + a_headrm - b_headrm - Qres;
    if( lshift <= 0 ) {
        return SKP_LSHIFT_SAT32(result, -lshift);
    } else {
        if( lshift < 32){
            return SKP_RSHIFT(result, lshift);
        } else {
            
            return 0;
        }
    }
}


SKP_INLINE SKP_int32 SKP_INVERSE32_varQ(    
    const SKP_int32     b32,                
    const SKP_int       Qres                
)
{
    SKP_int   b_headrm, lshift;
    SKP_int32 b32_inv, b32_nrm, err_Q32, result;

    SKP_assert( b32 != 0 );
    SKP_assert( b32 != SKP_int32_MIN ); 
    SKP_assert( Qres > 0 );

    
    b_headrm = SKP_Silk_CLZ32( SKP_abs(b32) ) - 1;
    b32_nrm = SKP_LSHIFT(b32, b_headrm);                                    

    
    b32_inv = SKP_DIV32_16( SKP_int32_MAX >> 2, SKP_RSHIFT(b32_nrm, 16) );  

    
    result = SKP_LSHIFT(b32_inv, 16);                                       

    
    err_Q32 = SKP_LSHIFT_ovflw( -SKP_SMULWB(b32_nrm, b32_inv), 3 );         

    
    result = SKP_SMLAWW(result, err_Q32, b32_inv);                          

    
    lshift = 61 - b_headrm - Qres;
    if( lshift <= 0 ) {
        return SKP_LSHIFT_SAT32(result, -lshift);
    } else {
        if( lshift < 32){
            return SKP_RSHIFT(result, lshift);
        }else{
            
            return 0;
        }
    }
}

#define SKP_SIN_APPROX_CONST0       (1073735400)
#define SKP_SIN_APPROX_CONST1        (-82778932)
#define SKP_SIN_APPROX_CONST2          (1059577)
#define SKP_SIN_APPROX_CONST3            (-5013)




SKP_INLINE SKP_int32 SKP_Silk_SIN_APPROX_Q24(        
    SKP_int32        x
)
{
    SKP_int y_Q30;

    
    x &= 65535;

    
    if( x <= 32768 ) {
        if( x < 16384 ) {
            
            x = 16384 - x;
        } else {
            
            x -= 16384;
        }
        if( x < 1100 ) {
            
            return SKP_SMLAWB( 1 << 24, SKP_MUL( x, x ), -5053 );
        }
        x = SKP_SMULWB( SKP_LSHIFT( x, 8 ), x );        
        y_Q30 = SKP_SMLAWB( SKP_SIN_APPROX_CONST2, x, SKP_SIN_APPROX_CONST3 );
        y_Q30 = SKP_SMLAWW( SKP_SIN_APPROX_CONST1, x, y_Q30 );
        y_Q30 = SKP_SMLAWW( SKP_SIN_APPROX_CONST0 + 66, x, y_Q30 );
    } else {
        if( x < 49152 ) {
            
            x = 49152 - x;
        } else {
            
            x -= 49152;
        }
        if( x < 1100 ) {
            
            return SKP_SMLAWB( -(1 << 24), SKP_MUL( x, x ), 5053 );
        }
        x = SKP_SMULWB( SKP_LSHIFT( x, 8 ), x );        
        y_Q30 = SKP_SMLAWB( -SKP_SIN_APPROX_CONST2, x, -SKP_SIN_APPROX_CONST3 );
        y_Q30 = SKP_SMLAWW( -SKP_SIN_APPROX_CONST1, x, y_Q30 );
        y_Q30 = SKP_SMLAWW( -SKP_SIN_APPROX_CONST0, x, y_Q30 );
    }
    return SKP_RSHIFT_ROUND( y_Q30, 6 );
}



SKP_INLINE SKP_int32 SKP_Silk_COS_APPROX_Q24(        
    SKP_int32        x
)
{
    return SKP_Silk_SIN_APPROX_Q24( x + 16384 );
}

#ifdef  __cplusplus
}
#endif

#endif 

#ifdef  __cplusplus
}
#endif

#endif


#define BIN_DIV_STEPS_A2NLSF_FIX      3 
#define QPoly                        16
#define MAX_ITERATIONS_A2NLSF_FIX    30


#define OVERSAMPLE_COSINE_TABLE       0



SKP_INLINE void SKP_Silk_A2NLSF_trans_poly(
    SKP_int32        *p,    
    const SKP_int    dd     
)
{
    SKP_int k, n;
    
    for( k = 2; k <= dd; k++ ) {
        for( n = dd; n > k; n-- ) {
            p[ n - 2 ] -= p[ n ];
        }
        p[ k - 2 ] -= SKP_LSHIFT( p[ k ], 1 );
    }
}    
#if EMBEDDED_ARM<6


SKP_INLINE SKP_int32 SKP_Silk_A2NLSF_eval_poly(    
    SKP_int32        *p,    
    const SKP_int32   x,    
    const SKP_int    dd     
)
{
    SKP_int   n;
    SKP_int32 x_Q16, y32;

    y32 = p[ dd ];                                    
    x_Q16 = SKP_LSHIFT( x, 4 );
    for( n = dd - 1; n >= 0; n-- ) {
        y32 = SKP_SMLAWW( p[ n ], y32, x_Q16 );       
    }
    return y32;
}
#else
SKP_int32 SKP_Silk_A2NLSF_eval_poly(    
    SKP_int32        *p,    
    const SKP_int32   x,    
    const SKP_int    dd     
);
#endif

SKP_INLINE void SKP_Silk_A2NLSF_init(
     const SKP_int32    *a_Q16,
     SKP_int32          *P, 
     SKP_int32          *Q, 
     const SKP_int      dd
) 
{
    SKP_int k;

    
    P[dd] = SKP_LSHIFT( 1, QPoly );
    Q[dd] = SKP_LSHIFT( 1, QPoly );
    for( k = 0; k < dd; k++ ) {
#if( QPoly < 16 )
        P[ k ] = SKP_RSHIFT_ROUND( -a_Q16[ dd - k - 1 ] - a_Q16[ dd + k ], 16 - QPoly ); 
        Q[ k ] = SKP_RSHIFT_ROUND( -a_Q16[ dd - k - 1 ] + a_Q16[ dd + k ], 16 - QPoly ); 
#elif( QPoly == 16 )
        P[ k ] = -a_Q16[ dd - k - 1 ] - a_Q16[ dd + k ]; 
        Q[ k ] = -a_Q16[ dd - k - 1 ] + a_Q16[ dd + k ]; 
#else
        P[ k ] = SKP_LSHIFT( -a_Q16[ dd - k - 1 ] - a_Q16[ dd + k ], QPoly - 16 ); 
        Q[ k ] = SKP_LSHIFT( -a_Q16[ dd - k - 1 ] + a_Q16[ dd + k ], QPoly - 16 ); 
#endif
    }

    
    
    
    for( k = dd; k > 0; k-- ) {
        P[ k - 1 ] -= P[ k ]; 
        Q[ k - 1 ] += Q[ k ]; 
    }

    
    SKP_Silk_A2NLSF_trans_poly( P, dd );
    SKP_Silk_A2NLSF_trans_poly( Q, dd );
}



void SKP_Silk_A2NLSF(
    SKP_int          *NLSF,                 
    SKP_int32        *a_Q16,                
    const SKP_int    d                      
)
{
    SKP_int      i, k, m, dd, root_ix, ffrac;
    SKP_int32 xlo, xhi, xmid;
    SKP_int32 ylo, yhi, ymid;
    SKP_int32 nom, den;
    SKP_int32 P[ SKP_Silk_MAX_ORDER_LPC / 2 + 1 ];
    SKP_int32 Q[ SKP_Silk_MAX_ORDER_LPC / 2 + 1 ];
    SKP_int32 *PQ[ 2 ];
    SKP_int32 *p;

    
    PQ[ 0 ] = P;
    PQ[ 1 ] = Q;

    dd = SKP_RSHIFT( d, 1 );

    SKP_Silk_A2NLSF_init( a_Q16, P, Q, dd );

    
    p = P;    
    
    xlo = SKP_Silk_LSFCosTab_FIX_Q12[ 0 ]; 
    ylo = SKP_Silk_A2NLSF_eval_poly( p, xlo, dd );

    if( ylo < 0 ) {
        
        NLSF[ 0 ] = 0;
        p = Q;                      
        ylo = SKP_Silk_A2NLSF_eval_poly( p, xlo, dd );
        root_ix = 1;                
    } else {
        root_ix = 0;                
    }
    k = 1;                          
    i = 0;                          
    while( 1 ) {
        
#if OVERSAMPLE_COSINE_TABLE
        xhi = SKP_Silk_LSFCosTab_FIX_Q12[   k       >> 1 ] +
          ( ( SKP_Silk_LSFCosTab_FIX_Q12[ ( k + 1 ) >> 1 ] - 
              SKP_Silk_LSFCosTab_FIX_Q12[   k       >> 1 ] ) >> 1 );    
#else
        xhi = SKP_Silk_LSFCosTab_FIX_Q12[ k ]; 
#endif
        yhi = SKP_Silk_A2NLSF_eval_poly( p, xhi, dd );
        
        
        if( ( ylo <= 0 && yhi >= 0 ) || ( ylo >= 0 && yhi <= 0 ) ) {
            
#if OVERSAMPLE_COSINE_TABLE
            ffrac = -128;
#else
            ffrac = -256;
#endif
            for( m = 0; m < BIN_DIV_STEPS_A2NLSF_FIX; m++ ) {
                
                xmid = SKP_RSHIFT_ROUND( xlo + xhi, 1 );
                ymid = SKP_Silk_A2NLSF_eval_poly( p, xmid, dd );

                
                if( ( ylo <= 0 && ymid >= 0 ) || ( ylo >= 0 && ymid <= 0 ) ) {
                    
                    xhi = xmid;
                    yhi = ymid;
                } else {
                    
                    xlo = xmid;
                    ylo = ymid;
#if OVERSAMPLE_COSINE_TABLE
                    ffrac = SKP_ADD_RSHIFT( ffrac,  64, m );
#else
                    ffrac = SKP_ADD_RSHIFT( ffrac, 128, m );
#endif
                }
            }
            
            
            if( SKP_abs( ylo ) < 65536 ) {
                
                den = ylo - yhi;
                nom = SKP_LSHIFT( ylo, 8 - BIN_DIV_STEPS_A2NLSF_FIX ) + SKP_RSHIFT( den, 1 );
                if( den != 0 ) {
                    ffrac += SKP_DIV32( nom, den );
                }
            } else {
                
                ffrac += SKP_DIV32( ylo, SKP_RSHIFT( ylo - yhi, 8 - BIN_DIV_STEPS_A2NLSF_FIX ) );
            }
#if OVERSAMPLE_COSINE_TABLE
            NLSF[ root_ix ] = (SKP_int)SKP_min_32( SKP_LSHIFT( (SKP_int32)k, 7 ) + ffrac, SKP_int16_MAX ); 
#else
            NLSF[ root_ix ] = (SKP_int)SKP_min_32( SKP_LSHIFT( (SKP_int32)k, 8 ) + ffrac, SKP_int16_MAX ); 
#endif

            SKP_assert( NLSF[ root_ix ] >=     0 );
            SKP_assert( NLSF[ root_ix ] <= 32767 );

            root_ix++;        
            if( root_ix >= d ) {
                
                break;
            }
            
            p = PQ[ root_ix & 1 ];
            
            
#if OVERSAMPLE_COSINE_TABLE
            xlo = SKP_Silk_LSFCosTab_FIX_Q12[ ( k - 1 ) >> 1 ] +
              ( ( SKP_Silk_LSFCosTab_FIX_Q12[   k       >> 1 ] - 
                  SKP_Silk_LSFCosTab_FIX_Q12[ ( k - 1 ) >> 1 ] ) >> 1 ); 
#else
            xlo = SKP_Silk_LSFCosTab_FIX_Q12[ k - 1 ]; 
#endif
            ylo = SKP_LSHIFT( 1 - ( root_ix & 2 ), 12 );
        } else {
            
            k++;
            xlo    = xhi;
            ylo    = yhi;
            
#if OVERSAMPLE_COSINE_TABLE
            if( k > 2 * LSF_COS_TAB_SZ_FIX ) {
#else
            if( k > LSF_COS_TAB_SZ_FIX ) {
#endif
                i++;
                if( i > MAX_ITERATIONS_A2NLSF_FIX ) {
                    
                    NLSF[ 0 ] = SKP_DIV32_16( 1 << 15, d + 1 );
                    for( k = 1; k < d; k++ ) {
                        NLSF[ k ] = SKP_SMULBB( k + 1, NLSF[ 0 ] );
                    }
                    return;
                }

                
                SKP_Silk_bwexpander_32( a_Q16, d, 65536 - SKP_SMULBB( 10 + i, i ) ); 

                SKP_Silk_A2NLSF_init( a_Q16, P, Q, dd );
                p = P;                            
                xlo = SKP_Silk_LSFCosTab_FIX_Q12[ 0 ]; 
                ylo = SKP_Silk_A2NLSF_eval_poly( p, xlo, dd );
                if( ylo < 0 ) {
                    
                    NLSF[ 0 ] = 0;
                    p = Q;                        
                    ylo = SKP_Silk_A2NLSF_eval_poly( p, xlo, dd );
                    root_ix = 1;                  
                } else {
                    root_ix = 0;                  
                }
                k = 1;                            
            }
        }
    }
}







#ifndef SKP_SILK_MAIN_H
#define SKP_SILK_MAIN_H



#ifdef __cplusplus
extern "C"
{
#endif




#ifndef SKP_SILK_DEFINE_H
#define SKP_SILK_DEFINE_H




#ifndef SKP_SILK_ERRORS_H
#define SKP_SILK_ERRORS_H

#ifdef __cplusplus
extern "C"
{
#endif




#define SKP_SILK_NO_ERROR                               0






#define SKP_SILK_ENC_INPUT_INVALID_NO_OF_SAMPLES        -1


#define SKP_SILK_ENC_FS_NOT_SUPPORTED                   -2


#define SKP_SILK_ENC_PACKET_SIZE_NOT_SUPPORTED          -3


#define SKP_SILK_ENC_PAYLOAD_BUF_TOO_SHORT              -4


#define SKP_SILK_ENC_INVALID_LOSS_RATE                  -5


#define SKP_SILK_ENC_INVALID_COMPLEXITY_SETTING         -6


#define SKP_SILK_ENC_INVALID_INBAND_FEC_SETTING         -7


#define SKP_SILK_ENC_INVALID_DTX_SETTING                -8


#define SKP_SILK_ENC_INTERNAL_ERROR                     -9






#define SKP_SILK_DEC_INVALID_SAMPLING_FREQUENCY         -10


#define SKP_SILK_DEC_PAYLOAD_TOO_LARGE                  -11


#define SKP_SILK_DEC_PAYLOAD_ERROR                      -12

#ifdef __cplusplus
}
#endif

#endif


#ifdef __cplusplus
extern "C"
{
#endif


#define MAX_FRAMES_PER_PACKET                   5




#define MIN_TARGET_RATE_BPS                     5000
#define MAX_TARGET_RATE_BPS                     100000


#define SWB2WB_BITRATE_BPS                      25000
#define WB2SWB_BITRATE_BPS                      30000
#define WB2MB_BITRATE_BPS                       14000
#define MB2WB_BITRATE_BPS                       18000
#define MB2NB_BITRATE_BPS                       10000
#define NB2MB_BITRATE_BPS                       14000



#define ACCUM_BITS_DIFF_THRESHOLD               30000000 
#define TARGET_RATE_TAB_SZ                      8


#define NO_SPEECH_FRAMES_BEFORE_DTX             5       
#define MAX_CONSECUTIVE_DTX                     20      

#define USE_LBRR                                1


#define NO_LBRR_THRES                           10


#define MAX_LBRR_DELAY                          2
#define LBRR_IDX_MASK                           1

#define INBAND_FEC_MIN_RATE_BPS                 18000  
#define LBRR_LOSS_THRES                         1   


#define SKP_SILK_NO_LBRR                        0   
#define SKP_SILK_ADD_LBRR_TO_PLUS1              1   
#define SKP_SILK_ADD_LBRR_TO_PLUS2              2   


#define SKP_SILK_LAST_FRAME                     0   
#define SKP_SILK_MORE_FRAMES                    1   
#define SKP_SILK_LBRR_VER1                      2   
#define SKP_SILK_LBRR_VER2                      3   
#define SKP_SILK_EXT_LAYER                      4   


#define NB_SOS                                  3
#define HP_8_KHZ_THRES                          10          
#define CONCEC_SWB_SMPLS_THRES                  480 * 15    
#define WB_DETECT_ACTIVE_SPEECH_MS_THRES        15000       


#define LOW_COMPLEXITY_ONLY                     0


#define SWITCH_TRANSITION_FILTERING             1


#define DEC_HP_ORDER                            2


#define MAX_FS_KHZ                              24 
#define MAX_API_FS_KHZ                          48


#define SIG_TYPE_VOICED                         0
#define SIG_TYPE_UNVOICED                       1


#define NO_VOICE_ACTIVITY                       0
#define VOICE_ACTIVITY                          1

 
#define FRAME_LENGTH_MS                         20
#define MAX_FRAME_LENGTH                        ( FRAME_LENGTH_MS * MAX_FS_KHZ )


#define LA_PITCH_MS                             2
#define LA_PITCH_MAX                            ( LA_PITCH_MS * MAX_FS_KHZ )


#define FIND_PITCH_LPC_WIN_MS                   ( 20 + (LA_PITCH_MS << 1) )
#define FIND_PITCH_LPC_WIN_MAX                  ( FIND_PITCH_LPC_WIN_MS * MAX_FS_KHZ )


#define MAX_FIND_PITCH_LPC_ORDER                16

#define PITCH_EST_COMPLEXITY_HC_MODE            SKP_Silk_PITCH_EST_MAX_COMPLEX
#define PITCH_EST_COMPLEXITY_MC_MODE            SKP_Silk_PITCH_EST_MID_COMPLEX
#define PITCH_EST_COMPLEXITY_LC_MODE            SKP_Silk_PITCH_EST_MIN_COMPLEX


#define LA_SHAPE_MS                             5
#define LA_SHAPE_MAX                            ( LA_SHAPE_MS * MAX_FS_KHZ )


#define SHAPE_LPC_WIN_MAX                       ( 15 * MAX_FS_KHZ )


#define MAX_ARITHM_BYTES                        1024

#define RANGE_CODER_WRITE_BEYOND_BUFFER         -1
#define RANGE_CODER_CDF_OUT_OF_RANGE            -2
#define RANGE_CODER_NORMALIZATION_FAILED        -3
#define RANGE_CODER_ZERO_INTERVAL_WIDTH         -4
#define RANGE_CODER_DECODER_CHECK_FAILED        -5
#define RANGE_CODER_READ_BEYOND_BUFFER          -6
#define RANGE_CODER_ILLEGAL_SAMPLING_RATE       -7
#define RANGE_CODER_DEC_PAYLOAD_TOO_LONG        -8


#define MIN_QGAIN_DB                            6

#define MAX_QGAIN_DB                            86

#define N_LEVELS_QGAIN                          64

#define MAX_DELTA_GAIN_QUANT                    40

#define MIN_DELTA_GAIN_QUANT                    -4


#define OFFSET_VL_Q10                           32
#define OFFSET_VH_Q10                           100
#define OFFSET_UVL_Q10                          100
#define OFFSET_UVH_Q10                          256


#define MAX_LPC_STABILIZE_ITERATIONS            20

#define MAX_LPC_ORDER                           16
#define MIN_LPC_ORDER                           10


#define LTP_ORDER                               5


#define NB_LTP_CBKS                             3


#define NB_SUBFR                                4


#define USE_HARM_SHAPING                        1


#define MAX_SHAPE_LPC_ORDER                     16

#define HARM_SHAPE_FIR_TAPS                     3


#define MAX_DEL_DEC_STATES                      4

#define LTP_BUF_LENGTH                          512
#define LTP_MASK                                (LTP_BUF_LENGTH - 1)

#define DECISION_DELAY                          32
#define DECISION_DELAY_MASK                     (DECISION_DELAY - 1)


#define SHELL_CODEC_FRAME_LENGTH                16
#define MAX_NB_SHELL_BLOCKS                     (MAX_FRAME_LENGTH / SHELL_CODEC_FRAME_LENGTH)


#define N_RATE_LEVELS                           10


#define MAX_PULSES                              18

#define MAX_MATRIX_SIZE                         MAX_LPC_ORDER 

#if( MAX_LPC_ORDER > DECISION_DELAY )
# define NSQ_LPC_BUF_LENGTH                     MAX_LPC_ORDER
#else
# define NSQ_LPC_BUF_LENGTH                     DECISION_DELAY
#endif




#define HIGH_PASS_INPUT                         1




#define VAD_N_BANDS                             4

#define VAD_INTERNAL_SUBFRAMES_LOG2             2
#define VAD_INTERNAL_SUBFRAMES                  (1 << VAD_INTERNAL_SUBFRAMES_LOG2)
    
#define VAD_NOISE_LEVEL_SMOOTH_COEF_Q16         1024    
#define VAD_NOISE_LEVELS_BIAS                   50 


#define VAD_NEGATIVE_OFFSET_Q5                  128     
#define VAD_SNR_FACTOR_Q16                      45000 


#define VAD_SNR_SMOOTH_COEF_Q18                 4096




#   define NLSF_MSVQ_MAX_CB_STAGES                      10  
#   define NLSF_MSVQ_MAX_VECTORS_IN_STAGE               128 
#   define NLSF_MSVQ_MAX_VECTORS_IN_STAGE_TWO_TO_END    16  

#define NLSF_MSVQ_FLUCTUATION_REDUCTION         1
#define MAX_NLSF_MSVQ_SURVIVORS                 16
#define MAX_NLSF_MSVQ_SURVIVORS_LC_MODE         2
#define MAX_NLSF_MSVQ_SURVIVORS_MC_MODE         4


#if( NLSF_MSVQ_MAX_VECTORS_IN_STAGE > ( MAX_NLSF_MSVQ_SURVIVORS_LC_MODE * NLSF_MSVQ_MAX_VECTORS_IN_STAGE_TWO_TO_END ) )
#   define NLSF_MSVQ_TREE_SEARCH_MAX_VECTORS_EVALUATED_LC_MODE  NLSF_MSVQ_MAX_VECTORS_IN_STAGE
#else
#   define NLSF_MSVQ_TREE_SEARCH_MAX_VECTORS_EVALUATED_LC_MODE  MAX_NLSF_MSVQ_SURVIVORS_LC_MODE * NLSF_MSVQ_MAX_VECTORS_IN_STAGE_TWO_TO_END
#endif

#if( NLSF_MSVQ_MAX_VECTORS_IN_STAGE > ( MAX_NLSF_MSVQ_SURVIVORS * NLSF_MSVQ_MAX_VECTORS_IN_STAGE_TWO_TO_END ) )
#   define NLSF_MSVQ_TREE_SEARCH_MAX_VECTORS_EVALUATED  NLSF_MSVQ_MAX_VECTORS_IN_STAGE
#else
#   define NLSF_MSVQ_TREE_SEARCH_MAX_VECTORS_EVALUATED  MAX_NLSF_MSVQ_SURVIVORS * NLSF_MSVQ_MAX_VECTORS_IN_STAGE_TWO_TO_END
#endif

#define NLSF_MSVQ_SURV_MAX_REL_RD               0.1f    


#if SWITCH_TRANSITION_FILTERING
#  define TRANSITION_TIME_UP_MS                 5120 
#  define TRANSITION_TIME_DOWN_MS               2560 
#  define TRANSITION_NB                         3 
#  define TRANSITION_NA                         2 
#  define TRANSITION_INT_NUM                    5 
#  define TRANSITION_FRAMES_UP                  ( TRANSITION_TIME_UP_MS   / FRAME_LENGTH_MS )
#  define TRANSITION_FRAMES_DOWN                ( TRANSITION_TIME_DOWN_MS / FRAME_LENGTH_MS )
#  define TRANSITION_INT_STEPS_UP               ( TRANSITION_FRAMES_UP    / ( TRANSITION_INT_NUM - 1 )  )
#  define TRANSITION_INT_STEPS_DOWN             ( TRANSITION_FRAMES_DOWN  / ( TRANSITION_INT_NUM - 1 )  )
#endif


#define matrix_ptr(Matrix_base_adr, row, column, N)         *(Matrix_base_adr + ((row)*(N)+(column)))
#define matrix_adr(Matrix_base_adr, row, column, N)          (Matrix_base_adr + ((row)*(N)+(column)))


#ifndef matrix_c_ptr
#   define matrix_c_ptr(Matrix_base_adr, row, column, M)    *(Matrix_base_adr + ((row)+(M)*(column)))
#endif
#define matrix_c_adr(Matrix_base_adr, row, column, M)        (Matrix_base_adr + ((row)+(M)*(column)))


#define BWE_AFTER_LOSS_Q16                      63570


#define CNG_BUF_MASK_MAX                        255             
#define CNG_GAIN_SMTH_Q16                       4634            
#define CNG_NLSF_SMTH_Q16                       16348           

#ifdef __cplusplus
}
#endif

#endif



#ifndef SKP_SILK_STRUCTS_H
#define SKP_SILK_STRUCTS_H





#ifdef __cplusplus
extern "C"
{
#endif





typedef struct {
    SKP_int16   xq[           2 * MAX_FRAME_LENGTH ]; 
    SKP_int32   sLTP_shp_Q10[ 2 * MAX_FRAME_LENGTH ];
    SKP_int32   sLPC_Q14[ MAX_FRAME_LENGTH / NB_SUBFR + NSQ_LPC_BUF_LENGTH ];
    SKP_int32   sAR2_Q14[ MAX_SHAPE_LPC_ORDER ];
    SKP_int32   sLF_AR_shp_Q12;
    SKP_int     lagPrev;
    SKP_int     sLTP_buf_idx;
    SKP_int     sLTP_shp_buf_idx;
    SKP_int32   rand_seed;
    SKP_int32   prev_inv_gain_Q16;
    SKP_int     rewhite_flag;
} SKP_Silk_nsq_state; 


typedef struct {
    SKP_uint8   payload[ MAX_ARITHM_BYTES ];    
    SKP_int     nBytes;                         
    SKP_int     usage;                          
} SKP_SILK_LBRR_struct;




typedef struct {
    SKP_int32   AnaState[ 2 ];                  
    SKP_int32   AnaState1[ 2 ];                 
    SKP_int32   AnaState2[ 2 ];                 
    SKP_int32   XnrgSubfr[ VAD_N_BANDS ];       
    SKP_int32   NrgRatioSmth_Q8[ VAD_N_BANDS ]; 
    SKP_int16   HPstate;                        
    SKP_int32   NL[ VAD_N_BANDS ];              
    SKP_int32   inv_NL[ VAD_N_BANDS ];          
    SKP_int32   NoiseLevelBias[ VAD_N_BANDS ];  
    SKP_int32   counter;                        
} SKP_Silk_VAD_state;




typedef struct {
    SKP_int32   bufferLength;
    SKP_int32   bufferIx;
    SKP_uint32  base_Q32;
    SKP_uint32  range_Q16;
    SKP_int32   error;
    SKP_uint8   buffer[ MAX_ARITHM_BYTES ];     
} SKP_Silk_range_coder_state;


typedef struct {
    SKP_int32                   S_HP_8_kHz[ NB_SOS ][ 2 ];  
    SKP_int32                   ConsecSmplsAboveThres;
    SKP_int32                   ActiveSpeech_ms;            
    SKP_int                     SWB_detected;               
    SKP_int                     WB_detected;                
} SKP_Silk_detect_SWB_state;

#if SWITCH_TRANSITION_FILTERING

typedef struct {
    SKP_int32                   In_LP_State[ 2 ];           
    SKP_int32                   transition_frame_no;        
    SKP_int                     mode;                       
} SKP_Silk_LP_state;
#endif


typedef struct {
    const SKP_int32             nVectors;
    const SKP_int16             *CB_NLSF_Q15;
    const SKP_int16             *Rates_Q5;
} SKP_Silk_NLSF_CBS;


typedef struct {
    const SKP_int32             nStages;

    
    const SKP_Silk_NLSF_CBS     *CBStages;
    const SKP_int               *NDeltaMin_Q15;

    
    const SKP_uint16            *CDF;
    const SKP_uint16 * const    *StartPtr;
    const SKP_int               *MiddleIx;
} SKP_Silk_NLSF_CB_struct;




typedef struct {
    SKP_Silk_range_coder_state      sRC;                            
    SKP_Silk_range_coder_state      sRC_LBRR;                       
    SKP_Silk_nsq_state              sNSQ;                           
    SKP_Silk_nsq_state              sNSQ_LBRR;                      

#if HIGH_PASS_INPUT
    SKP_int32                       In_HP_State[ 2 ];               
#endif
#if SWITCH_TRANSITION_FILTERING
    SKP_Silk_LP_state               sLP;                            
#endif
    SKP_Silk_VAD_state              sVAD;                           

    SKP_int                         LBRRprevLastGainIndex;
    SKP_int                         prev_sigtype;
    SKP_int                         typeOffsetPrev;                 
    SKP_int                         prevLag;
    SKP_int                         prev_lagIndex;
    SKP_int32                       API_fs_Hz;                      
    SKP_int32                       prev_API_fs_Hz;                 
    SKP_int                         maxInternal_fs_kHz;             
    SKP_int                         fs_kHz;                         
    SKP_int                         fs_kHz_changed;                 
    SKP_int                         frame_length;                   
    SKP_int                         subfr_length;                   
    SKP_int                         la_pitch;                       
    SKP_int                         la_shape;                       
    SKP_int                         shapeWinLength;                 
    SKP_int32                       TargetRate_bps;                 
    SKP_int                         PacketSize_ms;                  
    SKP_int                         PacketLoss_perc;                
    SKP_int32                       frameCounter;
    SKP_int                         Complexity;                     
    SKP_int                         nStatesDelayedDecision;         
    SKP_int                         useInterpolatedNLSFs;           
    SKP_int                         shapingLPCOrder;                
    SKP_int                         predictLPCOrder;                
    SKP_int                         pitchEstimationComplexity;      
    SKP_int                         pitchEstimationLPCOrder;        
    SKP_int32                       pitchEstimationThreshold_Q16;   
    SKP_int                         LTPQuantLowComplexity;          
    SKP_int                         NLSF_MSVQ_Survivors;            
    SKP_int                         first_frame_after_reset;        
    SKP_int                         controlled_since_last_payload;  
	SKP_int                         warping_Q16;                    

    
    SKP_int16                       inputBuf[ MAX_FRAME_LENGTH ];   
    SKP_int                         inputBufIx;
    SKP_int                         nFramesInPayloadBuf;            
    SKP_int                         nBytesInPayloadBuf;             

    
    SKP_int                         frames_since_onset;

    const SKP_Silk_NLSF_CB_struct   *psNLSF_CB[ 2 ];                

     
    SKP_SILK_LBRR_struct            LBRR_buffer[ MAX_LBRR_DELAY ];
    SKP_int                         oldest_LBRR_idx;
    SKP_int                         useInBandFEC;                   
    SKP_int                         LBRR_enabled;
    SKP_int                         LBRR_GainIncreases;             

    
    SKP_int32                       bitrateDiff;                    
    SKP_int32                       bitrate_threshold_up;           
    SKP_int32                       bitrate_threshold_down;         

    SKP_Silk_resampler_state_struct  resampler_state;

    
    SKP_int                         noSpeechCounter;                
    SKP_int                         useDTX;                         
    SKP_int                         inDTX;                          
    SKP_int                         vadFlag;                        

    
    SKP_Silk_detect_SWB_state       sSWBdetect;


    
    SKP_int8                        q[ MAX_FRAME_LENGTH ];      
    SKP_int8                        q_LBRR[ MAX_FRAME_LENGTH ]; 

} SKP_Silk_encoder_state;





typedef struct {
    
    SKP_int     lagIndex;
    SKP_int     contourIndex;
    SKP_int     PERIndex;
    SKP_int     LTPIndex[ NB_SUBFR ];
    SKP_int     NLSFIndices[ NLSF_MSVQ_MAX_CB_STAGES ];  
    SKP_int     NLSFInterpCoef_Q2;
    SKP_int     GainsIndices[ NB_SUBFR ];
    SKP_int32   Seed;
    SKP_int     LTP_scaleIndex;
    SKP_int     RateLevelIndex;
    SKP_int     QuantOffsetType;
    SKP_int     sigtype;

    
    SKP_int     pitchL[ NB_SUBFR ];

    SKP_int     LBRR_usage;                     
} SKP_Silk_encoder_control;


typedef struct {
    SKP_int32   pitchL_Q8;                      
    SKP_int16   LTPCoef_Q14[ LTP_ORDER ];       
    SKP_int16   prevLPC_Q12[ MAX_LPC_ORDER ];
    SKP_int     last_frame_lost;                
    SKP_int32   rand_seed;                      
    SKP_int16   randScale_Q14;                  
    SKP_int32   conc_energy;
    SKP_int     conc_energy_shift;
    SKP_int16   prevLTP_scale_Q14;
    SKP_int32   prevGain_Q16[ NB_SUBFR ];
    SKP_int     fs_kHz;
} SKP_Silk_PLC_struct;


typedef struct {
    SKP_int32   CNG_exc_buf_Q10[ MAX_FRAME_LENGTH ];
    SKP_int     CNG_smth_NLSF_Q15[ MAX_LPC_ORDER ];
    SKP_int32   CNG_synth_state[ MAX_LPC_ORDER ];
    SKP_int32   CNG_smth_Gain_Q16;
    SKP_int32   rand_seed;
    SKP_int     fs_kHz;
} SKP_Silk_CNG_struct;




typedef struct {
    SKP_Silk_range_coder_state  sRC;                            
    SKP_int32       prev_inv_gain_Q16;
    SKP_int32       sLTP_Q16[ 2 * MAX_FRAME_LENGTH ];
    SKP_int32       sLPC_Q14[ MAX_FRAME_LENGTH / NB_SUBFR + MAX_LPC_ORDER ];
    SKP_int32       exc_Q10[ MAX_FRAME_LENGTH ];
    SKP_int32       res_Q10[ MAX_FRAME_LENGTH ];
    SKP_int16       outBuf[ 2 * MAX_FRAME_LENGTH ];             
    SKP_int         lagPrev;                                    
    SKP_int         LastGainIndex;                              
    SKP_int         LastGainIndex_EnhLayer;                     
    SKP_int         typeOffsetPrev;                             
    SKP_int32       HPState[ DEC_HP_ORDER ];                    
    const SKP_int16 *HP_A;                                      
    const SKP_int16 *HP_B;                                      
    SKP_int         fs_kHz;                                     
    SKP_int32       prev_API_sampleRate;                        
    SKP_int         frame_length;                               
    SKP_int         subfr_length;                               
    SKP_int         LPC_order;                                  
    SKP_int         prevNLSF_Q15[ MAX_LPC_ORDER ];              
    SKP_int         first_frame_after_reset;                    

    
    SKP_int         nBytesLeft;
    SKP_int         nFramesDecoded;
    SKP_int         nFramesInPacket;
    SKP_int         moreInternalDecoderFrames;
    SKP_int         FrameTermination;

    SKP_Silk_resampler_state_struct  resampler_state;

    const SKP_Silk_NLSF_CB_struct *psNLSF_CB[ 2 ];      

    
    SKP_int         vadFlag;
    SKP_int         no_FEC_counter;                             
    SKP_int         inband_FEC_offset;                           

    
    SKP_Silk_CNG_struct sCNG;

    
    SKP_int         lossCnt;
    SKP_int         prev_sigtype;                               

    SKP_Silk_PLC_struct sPLC;



} SKP_Silk_decoder_state;




typedef struct {
    
    SKP_int             pitchL[ NB_SUBFR ];
    SKP_int32           Gains_Q16[ NB_SUBFR ];
    SKP_int32           Seed;
    
    SKP_DWORD_ALIGN SKP_int16 PredCoef_Q12[ 2 ][ MAX_LPC_ORDER ];
    SKP_int16           LTPCoef_Q14[ LTP_ORDER * NB_SUBFR ];
    SKP_int             LTP_scale_Q14;

    
    SKP_int             PERIndex;
    SKP_int             RateLevelIndex;
    SKP_int             QuantOffsetType;
    SKP_int             sigtype;
    SKP_int             NLSFInterpCoef_Q2;
} SKP_Silk_decoder_control;

#ifdef __cplusplus
}
#endif

#endif



#ifndef SKP_SILK_TABLES_H
#define SKP_SILK_TABLES_H




#define PITCH_EST_MAX_LAG_MS                18          
#define PITCH_EST_MIN_LAG_MS                2           

#ifdef __cplusplus
extern "C"
{
#endif


extern const SKP_uint16 SKP_Silk_type_offset_CDF[ 5 ];                                              
extern const SKP_uint16 SKP_Silk_type_offset_joint_CDF[ 4 ][ 5 ];                                   
extern const SKP_int    SKP_Silk_type_offset_CDF_offset;

extern const SKP_uint16 SKP_Silk_gain_CDF[ 2 ][ N_LEVELS_QGAIN + 1 ];                               
extern const SKP_int    SKP_Silk_gain_CDF_offset;
extern const SKP_uint16 SKP_Silk_delta_gain_CDF[ MAX_DELTA_GAIN_QUANT - MIN_DELTA_GAIN_QUANT + 2 ]; 
extern const SKP_int    SKP_Silk_delta_gain_CDF_offset;

extern const SKP_uint16 SKP_Silk_pitch_lag_NB_CDF[ 8 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) + 2 ];   
extern const SKP_int    SKP_Silk_pitch_lag_NB_CDF_offset;
extern const SKP_uint16 SKP_Silk_pitch_lag_MB_CDF[ 12 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) + 2 ];  
extern const SKP_int    SKP_Silk_pitch_lag_MB_CDF_offset;
extern const SKP_uint16 SKP_Silk_pitch_lag_WB_CDF[ 16 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) + 2 ];  
extern const SKP_int    SKP_Silk_pitch_lag_WB_CDF_offset;
extern const SKP_uint16 SKP_Silk_pitch_lag_SWB_CDF[ 24 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) + 2 ]; 
extern const SKP_int    SKP_Silk_pitch_lag_SWB_CDF_offset;

extern const SKP_uint16 SKP_Silk_pitch_contour_CDF[ 35 ];                                           
extern const SKP_int    SKP_Silk_pitch_contour_CDF_offset;
extern const SKP_uint16 SKP_Silk_pitch_contour_NB_CDF[ 12 ];                                        
extern const SKP_int    SKP_Silk_pitch_contour_NB_CDF_offset;
extern const SKP_uint16 SKP_Silk_pitch_delta_CDF[23];                                               
extern const SKP_int    SKP_Silk_pitch_delta_CDF_offset;

extern const SKP_uint16 SKP_Silk_pulses_per_block_CDF[ N_RATE_LEVELS ][ MAX_PULSES + 3 ];           
extern const SKP_int    SKP_Silk_pulses_per_block_CDF_offset;
extern const SKP_int16  SKP_Silk_pulses_per_block_BITS_Q6[ N_RATE_LEVELS - 1 ][ MAX_PULSES + 2 ];   

extern const SKP_uint16 SKP_Silk_rate_levels_CDF[ 2 ][ N_RATE_LEVELS ];                             
extern const SKP_int    SKP_Silk_rate_levels_CDF_offset;
extern const SKP_int16  SKP_Silk_rate_levels_BITS_Q6[ 2 ][ N_RATE_LEVELS - 1 ];                     

extern const SKP_int    SKP_Silk_max_pulses_table[ 4 ];                                             

extern const SKP_uint16 SKP_Silk_shell_code_table0[  33 ];                                          
extern const SKP_uint16 SKP_Silk_shell_code_table1[  52 ];                                          
extern const SKP_uint16 SKP_Silk_shell_code_table2[ 102 ];                                          
extern const SKP_uint16 SKP_Silk_shell_code_table3[ 207 ];                                          
extern const SKP_uint16 SKP_Silk_shell_code_table_offsets[ 19 ];                                    

extern const SKP_uint16 SKP_Silk_lsb_CDF[ 3 ];                                                      

extern const SKP_uint16 SKP_Silk_sign_CDF[ 36 ];                                                    

extern const SKP_uint16 SKP_Silk_LTP_per_index_CDF[ 4 ];                                            
extern const SKP_int    SKP_Silk_LTP_per_index_CDF_offset;
extern const SKP_int16  * const SKP_Silk_LTP_gain_BITS_Q6_ptrs[ NB_LTP_CBKS ];                      
extern const SKP_uint16 * const SKP_Silk_LTP_gain_CDF_ptrs[ NB_LTP_CBKS ];                          
extern const SKP_int    SKP_Silk_LTP_gain_CDF_offsets[ NB_LTP_CBKS ];                               
extern const SKP_int32  SKP_Silk_LTP_gain_middle_avg_RD_Q14;
extern const SKP_uint16 SKP_Silk_LTPscale_CDF[ 4 ];                                                 
extern const SKP_int    SKP_Silk_LTPscale_offset;


extern const SKP_int16  SKP_Silk_LTPScales_table_Q14[ 3 ];

extern const SKP_uint16 SKP_Silk_vadflag_CDF[ 3 ];                                                  
extern const SKP_int    SKP_Silk_vadflag_offset;

extern const SKP_int    SKP_Silk_SamplingRates_table[ 4 ];                                          
extern const SKP_uint16 SKP_Silk_SamplingRates_CDF[ 5 ];                                            
extern const SKP_int    SKP_Silk_SamplingRates_offset;

extern const SKP_uint16 SKP_Silk_NLSF_interpolation_factor_CDF[ 6 ];
extern const SKP_int    SKP_Silk_NLSF_interpolation_factor_offset;


extern const SKP_Silk_NLSF_CB_struct SKP_Silk_NLSF_CB0_16, SKP_Silk_NLSF_CB1_16;
extern const SKP_Silk_NLSF_CB_struct SKP_Silk_NLSF_CB0_10, SKP_Silk_NLSF_CB1_10;


extern const SKP_int16 * const SKP_Silk_LTP_vq_ptrs_Q14[ NB_LTP_CBKS ];                             
extern const SKP_int    SKP_Silk_LTP_vq_sizes[ NB_LTP_CBKS ];                                       


extern const SKP_int32  TargetRate_table_NB[  TARGET_RATE_TAB_SZ ];
extern const SKP_int32  TargetRate_table_MB[  TARGET_RATE_TAB_SZ ];
extern const SKP_int32  TargetRate_table_WB[  TARGET_RATE_TAB_SZ ];
extern const SKP_int32  TargetRate_table_SWB[ TARGET_RATE_TAB_SZ ];
extern const SKP_int32  SNR_table_Q1[         TARGET_RATE_TAB_SZ ];

extern const SKP_int32  SNR_table_one_bit_per_sample_Q7[ 4 ];


extern const SKP_int16  SKP_Silk_SWB_detect_B_HP_Q13[ NB_SOS ][ 3 ];
extern const SKP_int16  SKP_Silk_SWB_detect_A_HP_Q13[ NB_SOS ][ 2 ];


extern const SKP_int16  SKP_Silk_Dec_A_HP_24[ DEC_HP_ORDER ];                                       
extern const SKP_int16  SKP_Silk_Dec_B_HP_24[ DEC_HP_ORDER + 1 ];                                   


extern const SKP_int16  SKP_Silk_Dec_A_HP_16[ DEC_HP_ORDER ];                                       
extern const SKP_int16  SKP_Silk_Dec_B_HP_16[ DEC_HP_ORDER + 1 ];                                   


extern const SKP_int16  SKP_Silk_Dec_A_HP_12[ DEC_HP_ORDER ];                                       
extern const SKP_int16  SKP_Silk_Dec_B_HP_12[ DEC_HP_ORDER + 1 ];                                   


extern const SKP_int16  SKP_Silk_Dec_A_HP_8[ DEC_HP_ORDER ];                                        
extern const SKP_int16  SKP_Silk_Dec_B_HP_8[ DEC_HP_ORDER + 1 ];                                    


extern const SKP_uint16 SKP_Silk_FrameTermination_CDF[ 5 ];
extern const SKP_int    SKP_Silk_FrameTermination_offset;


extern const SKP_uint16 SKP_Silk_Seed_CDF[ 5 ];
extern const SKP_int    SKP_Silk_Seed_offset;


extern const SKP_int16  SKP_Silk_Quantization_Offsets_Q10[ 2 ][ 2 ];

#if SWITCH_TRANSITION_FILTERING

extern const SKP_int32 SKP_Silk_Transition_LP_B_Q28[ TRANSITION_INT_NUM ][ TRANSITION_NB ];
extern const SKP_int32 SKP_Silk_Transition_LP_A_Q28[ TRANSITION_INT_NUM ][ TRANSITION_NA ];
#endif

#ifdef __cplusplus
}
#endif

#endif



#ifndef SKP_SILK_PLC_FIX_H
#define SKP_SILK_PLC_FIX_H



#define BWE_COEF_Q16                    64880           
#define V_PITCH_GAIN_START_MIN_Q14      11469           
#define V_PITCH_GAIN_START_MAX_Q14      15565           
#define MAX_PITCH_LAG_MS                18
#define SA_THRES_Q8                     50
#define USE_SINGLE_TAP                  1
#define RAND_BUF_SIZE                   128
#define RAND_BUF_MASK                   (RAND_BUF_SIZE - 1)
#define LOG2_INV_LPC_GAIN_HIGH_THRES    3               
#define LOG2_INV_LPC_GAIN_LOW_THRES     8               
#define PITCH_DRIFT_FAC_Q16             655             

void SKP_Silk_PLC_Reset(
    SKP_Silk_decoder_state      *psDec              
);

void SKP_Silk_PLC(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],           
    SKP_int                     length,             
    SKP_int                     lost                
);

void SKP_Silk_PLC_update(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],
    SKP_int                     length
);

void SKP_Silk_PLC_conceal(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],           
    SKP_int                     length              
);

void SKP_Silk_PLC_glue_frames(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],           
    SKP_int                     length              
);

#endif




void SKP_Silk_encode_signs(
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_int8              q[],                
    const SKP_int               length,             
    const SKP_int               sigtype,            
    const SKP_int               QuantOffsetType,    
    const SKP_int               RateLevelIndex      
);


void SKP_Silk_decode_signs(
    SKP_Silk_range_coder_state  *psRC,              
    SKP_int                     q[],                
    const SKP_int               length,             
    const SKP_int               sigtype,            
    const SKP_int               QuantOffsetType,    
    const SKP_int               RateLevelIndex      
);


SKP_int SKP_Silk_control_audio_bandwidth(
    SKP_Silk_encoder_state      *psEncC,            
    const SKP_int32             TargetRate_bps      
);






void SKP_Silk_encode_pulses(
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_int               sigtype,            
    const SKP_int               QuantOffsetType,    
    const SKP_int8              q[],                
    const SKP_int               frame_length        
);


void SKP_Silk_shell_encoder(
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_int               *pulses0            
);


void SKP_Silk_shell_decoder(
    SKP_int                     *pulses0,           
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_int               pulses4             
);





void SKP_Silk_range_encoder(
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_int               data,               
    const SKP_uint16            prob[]              
);
    

void SKP_Silk_range_encoder_multi(
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_int               data[],             
    const SKP_uint16 * const    prob[],             
    const SKP_int               nSymbols            
);


void SKP_Silk_range_decoder(
    SKP_int                     data[],             
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_uint16            prob[],             
    SKP_int                     probIx              
);


void SKP_Silk_range_decoder_multi(
    SKP_int                     data[],             
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_uint16 * const    prob[],             
    const SKP_int               probStartIx[],      
    const SKP_int               nSymbols            
);


void SKP_Silk_range_enc_init(
    SKP_Silk_range_coder_state  *psRC               
);


void SKP_Silk_range_dec_init(
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_uint8             buffer[],           
    const SKP_int32             bufferLength        
);


SKP_int SKP_Silk_range_coder_get_length(            
    const SKP_Silk_range_coder_state    *psRC,      
    SKP_int                             *nBytes     
);


void SKP_Silk_range_enc_wrap_up(
    SKP_Silk_range_coder_state  *psRC               
);


void SKP_Silk_range_coder_check_after_decoding(
    SKP_Silk_range_coder_state  *psRC               
);


void SKP_Silk_gains_quant(
    SKP_int                     ind[ NB_SUBFR ],        
    SKP_int32                   gain_Q16[ NB_SUBFR ],   
    SKP_int                     *prev_ind,              
    const SKP_int               conditional             
);


void SKP_Silk_gains_dequant(
    SKP_int32                   gain_Q16[ NB_SUBFR ],   
    const SKP_int               ind[ NB_SUBFR ],        
    SKP_int                     *prev_ind,              
    const SKP_int               conditional             
);


void SKP_Silk_NLSF2A_stable(
    SKP_int16                   pAR_Q12[ MAX_LPC_ORDER ],    
    const SKP_int               pNLSF[ MAX_LPC_ORDER ],     
    const SKP_int               LPC_order                   
);


void SKP_Silk_interpolate(
    SKP_int                     xi[ MAX_LPC_ORDER ],    
    const SKP_int               x0[ MAX_LPC_ORDER ],    
    const SKP_int               x1[ MAX_LPC_ORDER ],    
    const SKP_int               ifact_Q2,               
    const SKP_int               d                       
);




void SKP_Silk_NSQ(
    SKP_Silk_encoder_state          *psEncC,                                    
    SKP_Silk_encoder_control        *psEncCtrlC,                                
    SKP_Silk_nsq_state              *NSQ,                                       
    const SKP_int16                 x[],                                        
    SKP_int8                        q[],                                        
    const SKP_int                   LSFInterpFactor_Q2,                         
    const SKP_int16                 PredCoef_Q12[ 2 * MAX_LPC_ORDER ],          
    const SKP_int16                 LTPCoef_Q14[ LTP_ORDER * NB_SUBFR ],        
    const SKP_int16                 AR2_Q13[ NB_SUBFR * MAX_SHAPE_LPC_ORDER ],  
    const SKP_int                   HarmShapeGain_Q14[ NB_SUBFR ],              
    const SKP_int                   Tilt_Q14[ NB_SUBFR ],                       
    const SKP_int32                 LF_shp_Q14[ NB_SUBFR ],                     
    const SKP_int32                 Gains_Q16[ NB_SUBFR ],                      
    const SKP_int                   Lambda_Q10,                                 
    const SKP_int                   LTP_scale_Q14                               
);


void SKP_Silk_NSQ_del_dec(
    SKP_Silk_encoder_state          *psEncC,                                    
    SKP_Silk_encoder_control        *psEncCtrlC,                                
    SKP_Silk_nsq_state              *NSQ,                                       
    const SKP_int16                 x[],                                        
    SKP_int8                        q[],                                        
    const SKP_int                   LSFInterpFactor_Q2,                         
    const SKP_int16                 PredCoef_Q12[ 2 * MAX_LPC_ORDER ],          
    const SKP_int16                 LTPCoef_Q14[ LTP_ORDER * NB_SUBFR ],        
    const SKP_int16                 AR2_Q13[ NB_SUBFR * MAX_SHAPE_LPC_ORDER ],  
    const SKP_int                   HarmShapeGain_Q14[ NB_SUBFR ],              
    const SKP_int                   Tilt_Q14[ NB_SUBFR ],                       
    const SKP_int32                 LF_shp_Q14[ NB_SUBFR ],                     
    const SKP_int32                 Gains_Q16[ NB_SUBFR ],                      
    const SKP_int                   Lambda_Q10,                                 
    const SKP_int                   LTP_scale_Q14                               
);





SKP_int SKP_Silk_VAD_Init(                           
    SKP_Silk_VAD_state          *psSilk_VAD          
); 


void SKP_Silk_VAD_GetNoiseLevels(
    const SKP_int32             pX[ VAD_N_BANDS ],  
    SKP_Silk_VAD_state          *psSilk_VAD          
);


SKP_int SKP_Silk_VAD_GetSA_Q8(                                  
    SKP_Silk_VAD_state          *psSilk_VAD,                    
    SKP_int                     *pSA_Q8,                        
    SKP_int                     *pSNR_dB_Q7,                    
    SKP_int                     pQuality_Q15[ VAD_N_BANDS ],    
    SKP_int                     *pTilt_Q15,                     
    const SKP_int16             pIn[],                          
    const SKP_int               framelength                     
);


void SKP_Silk_detect_SWB_input(
    SKP_Silk_detect_SWB_state   *psSWBdetect,       
    const SKP_int16             samplesIn[],        
    SKP_int                     nSamplesIn          
);

#if SWITCH_TRANSITION_FILTERING



void SKP_Silk_LP_variable_cutoff(
    SKP_Silk_LP_state           *psLP,              
    SKP_int16                   *out,               
    const SKP_int16             *in,                
    const SKP_int               frame_length        
);
#endif




SKP_int SKP_Silk_create_decoder(
    SKP_Silk_decoder_state      **ppsDec            
);

SKP_int SKP_Silk_free_decoder(
    SKP_Silk_decoder_state      *psDec              
);

SKP_int SKP_Silk_init_decoder(
    SKP_Silk_decoder_state      *psDec              
);


void SKP_Silk_decoder_set_fs(
    SKP_Silk_decoder_state      *psDec,             
    SKP_int                     fs_kHz              
);




SKP_int SKP_Silk_decode_frame(
    SKP_Silk_decoder_state      *psDec,             
    SKP_int16                   pOut[],             
    SKP_int16                   *pN,                
    const SKP_uint8             pCode[],            
    const SKP_int               nBytes,             
    SKP_int                     action,             
    SKP_int                     *decBytes           
);


void SKP_Silk_decode_parameters(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int                     q[],                
    const SKP_int               fullDecoding        
);


void SKP_Silk_decode_core(
    SKP_Silk_decoder_state      *psDec,                             
    SKP_Silk_decoder_control    *psDecCtrl,                         
    SKP_int16                   xq[],                               
    const SKP_int               q[ MAX_FRAME_LENGTH ]               
);


void SKP_Silk_NLSF_MSVQ_decode(
    SKP_int                         *pNLSF_Q15,     
    const SKP_Silk_NLSF_CB_struct   *psNLSF_CB,     
    const SKP_int                   *NLSFIndices,   
    const SKP_int                   LPC_order       
);






void SKP_Silk_decode_pulses(
    SKP_Silk_range_coder_state  *psRC,              
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int                     q[],                
    const SKP_int               frame_length        
);






void SKP_Silk_CNG_Reset(
    SKP_Silk_decoder_state      *psDec              
);


void SKP_Silk_CNG(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],           
    SKP_int                     length              
);


void SKP_Silk_encode_parameters(
    SKP_Silk_encoder_state      *psEncC,            
    SKP_Silk_encoder_control    *psEncCtrlC,        
    SKP_Silk_range_coder_state  *psRC,              
    const SKP_int8               *q                 
);


void SKP_Silk_get_low_layer_internal(
    const SKP_uint8             *indata,            
    const SKP_int16             nBytesIn,           
    SKP_uint8                   *Layer0data,        
    SKP_int16                   *nLayer0Bytes       
);


void SKP_Silk_LBRR_reset( 
    SKP_Silk_encoder_state      *psEncC             
);


#ifdef __cplusplus
}
#endif

#endif


SKP_INLINE void SKP_Silk_CNG_exc(
    SKP_int16                       residual[],         
    SKP_int32                       exc_buf_Q10[],      
    SKP_int32                       Gain_Q16,           
    SKP_int                         length,             
    SKP_int32                       *rand_seed          
)
{
    SKP_int32 seed;
    SKP_int   i, idx, exc_mask;

    exc_mask = CNG_BUF_MASK_MAX;
    while( exc_mask > length ) {
        exc_mask = SKP_RSHIFT( exc_mask, 1 );
    }

    seed = *rand_seed;
    for( i = 0; i < length; i++ ) {
        seed = SKP_RAND( seed );
        idx = ( SKP_int )( SKP_RSHIFT( seed, 24 ) & exc_mask );
        SKP_assert( idx >= 0 );
        SKP_assert( idx <= CNG_BUF_MASK_MAX );
        residual[ i ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( SKP_SMULWW( exc_buf_Q10[ idx ], Gain_Q16 ), 10 ) );
    }
    *rand_seed = seed;
}

void SKP_Silk_CNG_Reset(
    SKP_Silk_decoder_state      *psDec              
)
{
    SKP_int i, NLSF_step_Q15, NLSF_acc_Q15;

    NLSF_step_Q15 = SKP_DIV32_16( SKP_int16_MAX, psDec->LPC_order + 1 );
    NLSF_acc_Q15 = 0;
    for( i = 0; i < psDec->LPC_order; i++ ) {
        NLSF_acc_Q15 += NLSF_step_Q15;
        psDec->sCNG.CNG_smth_NLSF_Q15[ i ] = NLSF_acc_Q15;
    }
    psDec->sCNG.CNG_smth_Gain_Q16 = 0;
    psDec->sCNG.rand_seed = 3176576;
}


void SKP_Silk_CNG(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],           
    SKP_int                     length              
)
{
    SKP_int   i, subfr;
    SKP_int32 tmp_32, Gain_Q26, max_Gain_Q16;
    SKP_int16 LPC_buf[ MAX_LPC_ORDER ];
    SKP_int16 CNG_sig[ MAX_FRAME_LENGTH ];
    SKP_Silk_CNG_struct *psCNG;
    psCNG = &psDec->sCNG;

    if( psDec->fs_kHz != psCNG->fs_kHz ) {
        
        SKP_Silk_CNG_Reset( psDec );

        psCNG->fs_kHz = psDec->fs_kHz;
    }
    if( psDec->lossCnt == 0 && psDec->vadFlag == NO_VOICE_ACTIVITY ) {
        

        
        for( i = 0; i < psDec->LPC_order; i++ ) {
            psCNG->CNG_smth_NLSF_Q15[ i ] += SKP_SMULWB( psDec->prevNLSF_Q15[ i ] - psCNG->CNG_smth_NLSF_Q15[ i ], CNG_NLSF_SMTH_Q16 );
        }
        
        max_Gain_Q16 = 0;
        subfr        = 0;
        for( i = 0; i < NB_SUBFR; i++ ) {
            if( psDecCtrl->Gains_Q16[ i ] > max_Gain_Q16 ) {
                max_Gain_Q16 = psDecCtrl->Gains_Q16[ i ];
                subfr        = i;
            }
        }
        
        SKP_memmove( &psCNG->CNG_exc_buf_Q10[ psDec->subfr_length ], psCNG->CNG_exc_buf_Q10, ( NB_SUBFR - 1 ) * psDec->subfr_length * sizeof( SKP_int32 ) );
        SKP_memcpy(   psCNG->CNG_exc_buf_Q10, &psDec->exc_Q10[ subfr * psDec->subfr_length ], psDec->subfr_length * sizeof( SKP_int32 ) );

        
        for( i = 0; i < NB_SUBFR; i++ ) {
            psCNG->CNG_smth_Gain_Q16 += SKP_SMULWB( psDecCtrl->Gains_Q16[ i ] - psCNG->CNG_smth_Gain_Q16, CNG_GAIN_SMTH_Q16 );
        }
    }

    
    if( psDec->lossCnt ) {

        
        SKP_Silk_CNG_exc( CNG_sig, psCNG->CNG_exc_buf_Q10, 
                psCNG->CNG_smth_Gain_Q16, length, &psCNG->rand_seed );

        
        SKP_Silk_NLSF2A_stable( LPC_buf, psCNG->CNG_smth_NLSF_Q15, psDec->LPC_order );

        Gain_Q26 = ( SKP_int32 )1 << 26; 
        
        
        if( psDec->LPC_order == 16 ) {
            SKP_Silk_LPC_synthesis_order16( CNG_sig, LPC_buf, 
                Gain_Q26, psCNG->CNG_synth_state, CNG_sig, length );
        } else {
            SKP_Silk_LPC_synthesis_filter( CNG_sig, LPC_buf, 
                Gain_Q26, psCNG->CNG_synth_state, CNG_sig, length, psDec->LPC_order );
        }
        
        for( i = 0; i < length; i++ ) {
            tmp_32 = signal[ i ] + CNG_sig[ i ];
            signal[ i ] = SKP_SAT16( tmp_32 );
        }
    } else {
        SKP_memset( psCNG->CNG_synth_state, 0, psDec->LPC_order *  sizeof( SKP_int32 ) );
    }
}







#ifndef SKP_SILK_MAIN_FIX_H
#define SKP_SILK_MAIN_FIX_H

#include <stdlib.h>




#ifndef SKP_SILK_STRUCTS_FIX_H
#define SKP_SILK_STRUCTS_FIX_H






#ifdef __cplusplus
extern "C"
{
#endif




typedef struct {
    SKP_int     LastGainIndex;
    SKP_int32   HarmBoost_smth_Q16;
    SKP_int32   HarmShapeGain_smth_Q16;
    SKP_int32   Tilt_smth_Q16;
} SKP_Silk_shape_state_FIX;




typedef struct {
    SKP_int16   sLTP_shp[ LTP_BUF_LENGTH ];
    SKP_int32   sAR_shp[ MAX_SHAPE_LPC_ORDER + 1 ]; 
    SKP_int     sLTP_shp_buf_idx;
    SKP_int32   sLF_AR_shp_Q12;
    SKP_int32   sLF_MA_shp_Q12;
    SKP_int     sHarmHP;
    SKP_int32   rand_seed;
    SKP_int     lagPrev;
} SKP_Silk_prefilter_state_FIX;




typedef struct {
    SKP_int   pitch_LPC_win_length;
    SKP_int   min_pitch_lag;                                        
    SKP_int   max_pitch_lag;                                        
    SKP_int   prev_NLSFq_Q15[ MAX_LPC_ORDER ];                      
} SKP_Silk_predict_state_FIX;





typedef struct {
    SKP_Silk_encoder_state          sCmn;                           

#if HIGH_PASS_INPUT
    SKP_int32                       variable_HP_smth1_Q15;          
    SKP_int32                       variable_HP_smth2_Q15;          
#endif
    SKP_Silk_shape_state_FIX        sShape;                         
    SKP_Silk_prefilter_state_FIX    sPrefilt;                       
    SKP_Silk_predict_state_FIX      sPred;                          

    
    SKP_DWORD_ALIGN SKP_int16 x_buf[ 2 * MAX_FRAME_LENGTH + LA_SHAPE_MAX ];
    SKP_int                         LTPCorr_Q15;                    
    SKP_int                         mu_LTP_Q8;                      
    SKP_int32                       SNR_dB_Q7;                      
    SKP_int32                       avgGain_Q16;                    
    SKP_int32                       avgGain_Q16_one_bit_per_sample; 
    SKP_int                         BufferedInChannel_ms;           
    SKP_int                         speech_activity_Q8;             

    
    SKP_int                         prevLTPredCodGain_Q7;
    SKP_int                         HPLTPredCodGain_Q7;

    SKP_int32                       inBandFEC_SNR_comp_Q8;          

} SKP_Silk_encoder_state_FIX;




typedef struct {
    SKP_Silk_encoder_control        sCmn;                           

    
    SKP_int32                   Gains_Q16[ NB_SUBFR ];
    SKP_DWORD_ALIGN SKP_int16   PredCoef_Q12[ 2 ][ MAX_LPC_ORDER ];
    SKP_int16                   LTPCoef_Q14[ LTP_ORDER * NB_SUBFR ];
    SKP_int                     LTP_scale_Q14;

    
    
    SKP_DWORD_ALIGN SKP_int16 AR1_Q13[ NB_SUBFR * MAX_SHAPE_LPC_ORDER ];
    SKP_DWORD_ALIGN SKP_int16 AR2_Q13[ NB_SUBFR * MAX_SHAPE_LPC_ORDER ];
    SKP_int32   LF_shp_Q14[        NB_SUBFR ];          
    SKP_int     GainsPre_Q14[      NB_SUBFR ];
    SKP_int     HarmBoost_Q14[     NB_SUBFR ];
    SKP_int     Tilt_Q14[          NB_SUBFR ];
    SKP_int     HarmShapeGain_Q14[ NB_SUBFR ];
    SKP_int     Lambda_Q10;
    SKP_int     input_quality_Q14;
    SKP_int     coding_quality_Q14;
    SKP_int32   pitch_freq_low_Hz;
    SKP_int     current_SNR_dB_Q7;

    
    SKP_int     sparseness_Q8;
    SKP_int32   predGain_Q16;
    SKP_int     LTPredCodGain_Q7;
    SKP_int     input_quality_bands_Q15[ VAD_N_BANDS ];
    SKP_int     input_tilt_Q15;
    SKP_int32   ResNrg[ NB_SUBFR ];             
    SKP_int     ResNrgQ[ NB_SUBFR ];            
    
} SKP_Silk_encoder_control_FIX;


#ifdef __cplusplus
}
#endif

#endif


#define TIC(TAG_NAME)
#define TOC(TAG_NAME)

#ifndef FORCE_CPP_BUILD
#ifdef __cplusplus
extern "C"
{
#endif
#endif






SKP_int SKP_Silk_init_encoder_FIX(
    SKP_Silk_encoder_state_FIX  *psEnc                  
);


SKP_int SKP_Silk_control_encoder_FIX( 
    SKP_Silk_encoder_state_FIX  *psEnc,                 
    const SKP_int               PacketSize_ms,          
    const SKP_int32             TargetRate_bps,         
    const SKP_int               PacketLoss_perc,        
    const SKP_int               DTX_enabled,            
    const SKP_int               Complexity              
);


SKP_int SKP_Silk_encode_frame_FIX( 
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_uint8                       *pCode,             
    SKP_int16                       *pnBytesOut,        
                                                        
    const SKP_int16                 *pIn                
);


void SKP_Silk_LBRR_encode_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl,     
    SKP_uint8                       *pCode,         
    SKP_int16                       *pnBytesOut,    
    SKP_int16                       xfw[]           
);


void SKP_Silk_HP_variable_cutoff_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl,     
    SKP_int16                       *out,           
    const SKP_int16                 *in             
);




void SKP_Silk_prefilter_FIX(
    SKP_Silk_encoder_state_FIX          *psEnc,         
    const SKP_Silk_encoder_control_FIX  *psEncCtrl,     
    SKP_int16                           xw[],           
    const SKP_int16                     x[]             
);




void SKP_Silk_noise_shape_analysis_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl,     
    const SKP_int16                 *pitch_res,     
    const SKP_int16                 *x              
);


void SKP_Silk_warped_autocorrelation_FIX(
          SKP_int32                 *corr,              
          SKP_int                   *scale,             
    const SKP_int16                 *input,             
    const SKP_int16                 warping_Q16,        
    const SKP_int                   length,             
    const SKP_int                   order               
);


void SKP_Silk_process_gains_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl      
);


void SKP_Silk_LBRR_ctrl_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control        *psEncCtrlC     
);


void SKP_Silk_LTP_scale_ctrl_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl      
);






void SKP_Silk_find_pitch_lags_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl,     
    SKP_int16                       res[],          
    const SKP_int16                 x[]             
);

void SKP_Silk_find_pred_coefs_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl,     
    const SKP_int16                 res_pitch[]     
);

void SKP_Silk_find_LPC_FIX(
    SKP_int             NLSF_Q15[],             
    SKP_int             *interpIndex,           
    const SKP_int       prev_NLSFq_Q15[],       
    const SKP_int       useInterpolatedLSFs,    
    const SKP_int       LPC_order,              
    const SKP_int16     x[],                    
    const SKP_int       subfr_length            
);

void SKP_Silk_warped_LPC_analysis_filter_FIX(
          SKP_int32                 state[],            
          SKP_int16                 res[],              
    const SKP_int16                 coef_Q13[],         
    const SKP_int16                 input[],            
    const SKP_int16                 lambda_Q16,         
    const SKP_int                   length,             
    const SKP_int                   order               
);

void SKP_Silk_LTP_analysis_filter_FIX(
    SKP_int16       *LTP_res,                           
    const SKP_int16 *x,                                 
    const SKP_int16 LTPCoef_Q14[ LTP_ORDER * NB_SUBFR ],
    const SKP_int   pitchL[ NB_SUBFR ],                 
    const SKP_int32 invGains_Q16[ NB_SUBFR ],           
    const SKP_int   subfr_length,                       
    const SKP_int   pre_length                          
);


void SKP_Silk_find_LTP_FIX(
    SKP_int16           b_Q14[ NB_SUBFR * LTP_ORDER ],              
    SKP_int32           WLTP[ NB_SUBFR * LTP_ORDER * LTP_ORDER ],   
    SKP_int             *LTPredCodGain_Q7,                          
    const SKP_int16     r_first[],                                  
    const SKP_int16     r_last[],                                   
    const SKP_int       lag[ NB_SUBFR ],                            
    const SKP_int32     Wght_Q15[ NB_SUBFR ],                       
    const SKP_int       subfr_length,                               
    const SKP_int       mem_offset,                                 
    SKP_int             corr_rshifts[ NB_SUBFR ]                    
);


void SKP_Silk_quant_LTP_gains_FIX(
    SKP_int16               B_Q14[],                
    SKP_int                 cbk_index[],            
    SKP_int                 *periodicity_index,     
    const SKP_int32         W_Q18[],                
    SKP_int                 mu_Q8,                  
    SKP_int                 lowComplexity           
);





 
void SKP_Silk_process_NLSFs_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,     
    SKP_Silk_encoder_control_FIX    *psEncCtrl, 
    SKP_int                         *pNLSF_Q15  
);


void SKP_Silk_NLSF_MSVQ_encode_FIX(
          SKP_int                   *NLSFIndices,           
          SKP_int                   *pNLSF_Q15,             
    const SKP_Silk_NLSF_CB_struct   *psNLSF_CB,             
    const SKP_int                   *pNLSF_q_Q15_prev,      
    const SKP_int                   *pW_Q6,                 
    const SKP_int                   NLSF_mu_Q15,            
    const SKP_int                   NLSF_mu_fluc_red_Q16,   
    const SKP_int                   NLSF_MSVQ_Survivors,    
    const SKP_int                   LPC_order,              
    const SKP_int                   deactivate_fluc_red     
);


void SKP_Silk_NLSF_VQ_rate_distortion_FIX(
    SKP_int32                       *pRD_Q20,           
    const SKP_Silk_NLSF_CBS         *psNLSF_CBS,        
    const SKP_int                   *in_Q15,            
    const SKP_int                   *w_Q6,              
    const SKP_int32                 *rate_acc_Q5,       
    const SKP_int                   mu_Q15,             
    const SKP_int                   N,                  
    const SKP_int                   LPC_order           
);


void SKP_Silk_NLSF_VQ_sum_error_FIX(
    SKP_int32                       *err_Q20,           
    const SKP_int                   *in_Q15,            
    const SKP_int                   *w_Q6,              
    const SKP_int16                 *pCB_Q15,           
    const SKP_int                   N,                  
    const SKP_int                   K,                  
    const SKP_int                   LPC_order           
);


void SKP_Silk_VQ_WMat_EC_FIX(
    SKP_int                         *ind,               
    SKP_int32                       *rate_dist_Q14,     
    const SKP_int16                 *in_Q14,            
    const SKP_int32                 *W_Q18,             
    const SKP_int16                 *cb_Q14,            
    const SKP_int16                 *cl_Q6,             
    const SKP_int                   mu_Q8,              
    SKP_int                         L                   
);






void SKP_Silk_corrMatrix_FIX(
    const SKP_int16                 *x,         
    const SKP_int                   L,          
    const SKP_int                   order,      
    const SKP_int                   head_room,  
    SKP_int32                       *XX,        
    SKP_int                         *rshifts    
);


void SKP_Silk_corrVector_FIX(
    const SKP_int16                 *x,         
    const SKP_int16                 *t,         
    const SKP_int                   L,          
    const SKP_int                   order,      
    SKP_int32                       *Xt,        
    const SKP_int                   rshifts     
);


void SKP_Silk_regularize_correlations_FIX(
    SKP_int32                       *XX,                
    SKP_int32                       *xx,                
    SKP_int32                       noise,              
    SKP_int                         D                   
);


void SKP_Silk_solve_LDL_FIX(
    SKP_int32                       *A,                 
    SKP_int                         M,                  
    const SKP_int32                 *b,                 
    SKP_int32                       *x_Q16              
);


SKP_int32 SKP_Silk_residual_energy16_covar_FIX(
    const SKP_int16                 *c,                 
    const SKP_int32                 *wXX,               
    const SKP_int32                 *wXx,               
    SKP_int32                       wxx,                
    SKP_int                         D,                  
    SKP_int                         cQ                  
);



void SKP_Silk_residual_energy_FIX(
          SKP_int32 nrgs[ NB_SUBFR ],           
          SKP_int   nrgsQ[ NB_SUBFR ],          
    const SKP_int16 x[],                        
          SKP_int16 a_Q12[ 2 ][ MAX_LPC_ORDER ],
    const SKP_int32 gains[ NB_SUBFR ],          
    const SKP_int   subfr_length,               
    const SKP_int   LPC_order                   
);

#ifndef FORCE_CPP_BUILD
#ifdef __cplusplus
}
#endif 
#endif 
#endif 



#ifndef SKP_SILK_TUNING_PARAMETERS_H
#define SKP_SILK_TUNING_PARAMETERS_H

#ifdef __cplusplus
extern "C"
{
#endif






#define FIND_PITCH_WHITE_NOISE_FRACTION                 1e-3f


#define FIND_PITCH_BANDWITH_EXPANSION                   0.99f


#define FIND_PITCH_CORRELATION_THRESHOLD_HC_MODE        0.7f
#define FIND_PITCH_CORRELATION_THRESHOLD_MC_MODE        0.75f
#define FIND_PITCH_CORRELATION_THRESHOLD_LC_MODE        0.8f






#define FIND_LPC_COND_FAC                               2.5e-5f
#define FIND_LPC_CHIRP                                  0.99995f


#define FIND_LTP_COND_FAC                               1e-5f
#define LTP_DAMPING                                     0.01f
#define LTP_SMOOTHING                                   0.1f


#define MU_LTP_QUANT_NB                                 0.03f
#define MU_LTP_QUANT_MB                                 0.025f
#define MU_LTP_QUANT_WB                                 0.02f
#define MU_LTP_QUANT_SWB                                0.016f






#define VARIABLE_HP_SMTH_COEF1                          0.1f
#define VARIABLE_HP_SMTH_COEF2                          0.015f


#define VARIABLE_HP_MIN_FREQ                            80.0f
#define VARIABLE_HP_MAX_FREQ                            150.0f


#define VARIABLE_HP_MAX_DELTA_FREQ                      0.4f






#define WB_DETECT_ACTIVE_SPEECH_LEVEL_THRES             0.7f        

#define SPEECH_ACTIVITY_DTX_THRES                       0.1f


#define LBRR_SPEECH_ACTIVITY_THRES                      0.5f        






#define BG_SNR_DECR_dB                                  4.0f


#define HARM_SNR_INCR_dB                                2.0f


#define SPARSE_SNR_INCR_dB                              2.0f


#define SPARSENESS_THRESHOLD_QNT_OFFSET                 0.75f


#define WARPING_MULTIPLIER                              0.015f


#define SHAPE_WHITE_NOISE_FRACTION                      1e-5f


#define BANDWIDTH_EXPANSION                             0.95f


#define LOW_RATE_BANDWIDTH_EXPANSION_DELTA              0.01f


#define DE_ESSER_COEF_SWB_dB                            2.0f
#define DE_ESSER_COEF_WB_dB                             1.0f


#define LOW_RATE_HARMONIC_BOOST                         0.1f


#define LOW_INPUT_QUALITY_HARMONIC_BOOST                0.1f


#define HARMONIC_SHAPING                                0.3f


#define HIGH_RATE_OR_LOW_QUALITY_HARMONIC_SHAPING       0.2f


#define HP_NOISE_COEF                                   0.3f


#define HARM_HP_NOISE_COEF                              0.35f


#define INPUT_TILT                                      0.05f


#define HIGH_RATE_INPUT_TILT                            0.1f


#define LOW_FREQ_SHAPING                                3.0f


#define LOW_QUALITY_LOW_FREQ_SHAPING_DECR               0.5f


#define NOISE_FLOOR_dB                                  4.0f


#define RELATIVE_MIN_GAIN_dB                            -50.0f


#define GAIN_SMOOTHING_COEF                             1e-3f


#define SUBFR_SMTH_COEF                                 0.4f


#define LAMBDA_OFFSET                                   1.2f
#define LAMBDA_SPEECH_ACT                               -0.3f
#define LAMBDA_DELAYED_DECISIONS                        -0.05f
#define LAMBDA_INPUT_QUALITY                            -0.2f
#define LAMBDA_CODING_QUALITY                           -0.1f
#define LAMBDA_QUANT_OFFSET                             1.5f

#ifdef __cplusplus
}
#endif

#endif 

#if HIGH_PASS_INPUT

#define SKP_RADIANS_CONSTANT_Q19            1482    
#define SKP_LOG2_VARIABLE_HP_MIN_FREQ_Q7    809     


void SKP_Silk_HP_variable_cutoff_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_Silk_encoder_control_FIX    *psEncCtrl,         
    SKP_int16                       *out,               
    const SKP_int16                 *in                 
)
{
    SKP_int   quality_Q15;
    SKP_int32 B_Q28[ 3 ], A_Q28[ 2 ];
    SKP_int32 Fc_Q19, r_Q28, r_Q22;
    SKP_int32 pitch_freq_Hz_Q16, pitch_freq_log_Q7, delta_freq_Q7;

    
    
    
    if( psEnc->sCmn.prev_sigtype == SIG_TYPE_VOICED ) {
        
        pitch_freq_Hz_Q16 = SKP_DIV32_16( SKP_LSHIFT( SKP_MUL( psEnc->sCmn.fs_kHz, 1000 ), 16 ), psEnc->sCmn.prevLag );
        pitch_freq_log_Q7 = SKP_Silk_lin2log( pitch_freq_Hz_Q16 ) - ( 16 << 7 ); 

        
        quality_Q15 = psEncCtrl->input_quality_bands_Q15[ 0 ];
        pitch_freq_log_Q7 = SKP_SUB32( pitch_freq_log_Q7, SKP_SMULWB( SKP_SMULWB( SKP_LSHIFT( quality_Q15, 2 ), quality_Q15 ), 
            pitch_freq_log_Q7 - SKP_LOG2_VARIABLE_HP_MIN_FREQ_Q7 ) );
        pitch_freq_log_Q7 = SKP_ADD32( pitch_freq_log_Q7, SKP_RSHIFT( SKP_FIX_CONST( 0.6, 15 ) - quality_Q15, 9 ) );

        
        delta_freq_Q7 = pitch_freq_log_Q7 - SKP_RSHIFT( psEnc->variable_HP_smth1_Q15, 8 );
        if( delta_freq_Q7 < 0 ) {
            
            delta_freq_Q7 = SKP_MUL( delta_freq_Q7, 3 );
        }

        
        delta_freq_Q7 = SKP_LIMIT_32( delta_freq_Q7, -SKP_FIX_CONST( VARIABLE_HP_MAX_DELTA_FREQ, 7 ), SKP_FIX_CONST( VARIABLE_HP_MAX_DELTA_FREQ, 7 ) );

        
        psEnc->variable_HP_smth1_Q15 = SKP_SMLAWB( psEnc->variable_HP_smth1_Q15, 
            SKP_MUL( SKP_LSHIFT( psEnc->speech_activity_Q8, 1 ), delta_freq_Q7 ), SKP_FIX_CONST( VARIABLE_HP_SMTH_COEF1, 16 ) );
    }
    
    psEnc->variable_HP_smth2_Q15 = SKP_SMLAWB( psEnc->variable_HP_smth2_Q15, 
        psEnc->variable_HP_smth1_Q15 - psEnc->variable_HP_smth2_Q15, SKP_FIX_CONST( VARIABLE_HP_SMTH_COEF2, 16 ) );

    
    psEncCtrl->pitch_freq_low_Hz = SKP_Silk_log2lin( SKP_RSHIFT( psEnc->variable_HP_smth2_Q15, 8 ) );

    
    psEncCtrl->pitch_freq_low_Hz = SKP_LIMIT_32( psEncCtrl->pitch_freq_low_Hz, 
        SKP_FIX_CONST( VARIABLE_HP_MIN_FREQ, 0 ), SKP_FIX_CONST( VARIABLE_HP_MAX_FREQ, 0 ) );

    
    
    
    
    
    
    SKP_assert( psEncCtrl->pitch_freq_low_Hz <= SKP_int32_MAX / SKP_RADIANS_CONSTANT_Q19 );
    Fc_Q19 = SKP_DIV32_16( SKP_SMULBB( SKP_RADIANS_CONSTANT_Q19, psEncCtrl->pitch_freq_low_Hz ), psEnc->sCmn.fs_kHz ); 
    SKP_assert( Fc_Q19 >=  3704 );
    SKP_assert( Fc_Q19 <= 27787 );

    r_Q28 = SKP_FIX_CONST( 1.0, 28 ) - SKP_MUL( SKP_FIX_CONST( 0.92, 9 ), Fc_Q19 );
    SKP_assert( r_Q28 >= 255347779 );
    SKP_assert( r_Q28 <= 266690872 );

    
    
    B_Q28[ 0 ] = r_Q28;
    B_Q28[ 1 ] = SKP_LSHIFT( -r_Q28, 1 );
    B_Q28[ 2 ] = r_Q28;
    
    
    r_Q22  = SKP_RSHIFT( r_Q28, 6 );
    A_Q28[ 0 ] = SKP_SMULWW( r_Q22, SKP_SMULWW( Fc_Q19, Fc_Q19 ) - SKP_FIX_CONST( 2.0,  22 ) );
    A_Q28[ 1 ] = SKP_SMULWW( r_Q22, r_Q22 );

    
    
    
    SKP_Silk_biquad_alt( in, B_Q28, A_Q28, psEnc->sCmn.In_HP_State, out, psEnc->sCmn.frame_length );
}

#endif 







void SKP_Silk_LBRR_reset( 
    SKP_Silk_encoder_state      *psEncC             
)
{
    SKP_int i;

    for( i = 0; i < MAX_LBRR_DELAY; i++ ) {
        psEncC->LBRR_buffer[ i ].usage = SKP_SILK_NO_LBRR;
    }
}







#define QA          16
#define A_LIMIT     SKP_FIX_CONST( 0.99975, QA )



static SKP_int LPC_inverse_pred_gain_QA(        
    SKP_int32           *invGain_Q30,           
    SKP_int32           A_QA[ 2 ][ SKP_Silk_MAX_ORDER_LPC ],         
                                                
    const SKP_int       order                   
)
{
    SKP_int   k, n, headrm;
    SKP_int32 rc_Q31, rc_mult1_Q30, rc_mult2_Q16, tmp_QA;
    SKP_int32 *Aold_QA, *Anew_QA;

    Anew_QA = A_QA[ order & 1 ];

    *invGain_Q30 = ( 1 << 30 );
    for( k = order - 1; k > 0; k-- ) {
        
        if( ( Anew_QA[ k ] > A_LIMIT ) || ( Anew_QA[ k ] < -A_LIMIT ) ) {
            return 1;
        }

        
        rc_Q31 = -SKP_LSHIFT( Anew_QA[ k ], 31 - QA );
        
        
        rc_mult1_Q30 = ( SKP_int32_MAX >> 1 ) - SKP_SMMUL( rc_Q31, rc_Q31 );
        SKP_assert( rc_mult1_Q30 > ( 1 << 15 ) );                   
        SKP_assert( rc_mult1_Q30 < ( 1 << 30 ) );

        
        rc_mult2_Q16 = SKP_INVERSE32_varQ( rc_mult1_Q30, 46 );      

        
        
        *invGain_Q30 = SKP_LSHIFT( SKP_SMMUL( *invGain_Q30, rc_mult1_Q30 ), 2 );
        SKP_assert( *invGain_Q30 >= 0           );
        SKP_assert( *invGain_Q30 <= ( 1 << 30 ) );

        
        Aold_QA = Anew_QA;
        Anew_QA = A_QA[ k & 1 ];
        
        
        headrm = SKP_Silk_CLZ32( rc_mult2_Q16 ) - 1;
        rc_mult2_Q16 = SKP_LSHIFT( rc_mult2_Q16, headrm );          
        for( n = 0; n < k; n++ ) {
            tmp_QA = Aold_QA[ n ] - SKP_LSHIFT( SKP_SMMUL( Aold_QA[ k - n - 1 ], rc_Q31 ), 1 );
            Anew_QA[ n ] = SKP_LSHIFT( SKP_SMMUL( tmp_QA, rc_mult2_Q16 ), 16 - headrm );
        }
    }

    
    if( ( Anew_QA[ 0 ] > A_LIMIT ) || ( Anew_QA[ 0 ] < -A_LIMIT ) ) {
        return 1;
    }

    
    rc_Q31 = -SKP_LSHIFT( Anew_QA[ 0 ], 31 - QA );

    
    rc_mult1_Q30 = ( SKP_int32_MAX >> 1 ) - SKP_SMMUL( rc_Q31, rc_Q31 );

    
    
    *invGain_Q30 = SKP_LSHIFT( SKP_SMMUL( *invGain_Q30, rc_mult1_Q30 ), 2 );
    SKP_assert( *invGain_Q30 >= 0     );
    SKP_assert( *invGain_Q30 <= 1<<30 );

    return 0;
}

SKP_int SKP_Silk_LPC_inverse_pred_gain(       
    SKP_int32           *invGain_Q30,           
    const SKP_int16     *A_Q12,                 
    const SKP_int       order                   
)
{
    SKP_int   k;
    SKP_int32 Atmp_QA[ 2 ][ SKP_Silk_MAX_ORDER_LPC ];
    SKP_int32 *Anew_QA;

    Anew_QA = Atmp_QA[ order & 1 ];

    
    for( k = 0; k < order; k++ ) {
        Anew_QA[ k ] = SKP_LSHIFT( (SKP_int32)A_Q12[ k ], QA - 12 );
    }

    return LPC_inverse_pred_gain_QA( invGain_Q30, Atmp_QA, order );
}


SKP_int SKP_Silk_LPC_inverse_pred_gain_Q24(   
    SKP_int32           *invGain_Q30,           
    const SKP_int32     *A_Q24,                 
    const SKP_int       order                   
)
{
    SKP_int   k;
    SKP_int32 Atmp_QA[ 2 ][ SKP_Silk_MAX_ORDER_LPC ];
    SKP_int32 *Anew_QA;

    Anew_QA = Atmp_QA[ order & 1 ];

    
    for( k = 0; k < order; k++ ) {
        Anew_QA[ k ] = SKP_RSHIFT_ROUND( A_Q24[ k ], 24 - QA );
    }

    return LPC_inverse_pred_gain_QA( invGain_Q30, Atmp_QA, order );
}









void SKP_Silk_LPC_synthesis_filter(
    const SKP_int16 *in,        
    const SKP_int16 *A_Q12,     
    const SKP_int32 Gain_Q26,   
    SKP_int32 *S,               
    SKP_int16 *out,             
    const SKP_int32 len,        
    const SKP_int Order         
)
{
    SKP_int   k, j, idx, Order_half = SKP_RSHIFT( Order, 1 );
    SKP_int32 SA, SB, out32_Q10, out32;
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
    SKP_int32 Atmp, A_align_Q12[ SKP_Silk_MAX_ORDER_LPC >> 1 ];

    
    for( k = 0; k < Order_half; k++ ) {
        idx = SKP_SMULBB( 2, k );
        A_align_Q12[ k ] = ( ( ( SKP_int32 )A_Q12[ idx ] ) & 0x0000ffff ) | SKP_LSHIFT( ( SKP_int32 )A_Q12[ idx + 1 ], 16 );
    }
#endif

    
    SKP_assert( 2 * Order_half == Order );

    
    for( k = 0; k < len; k++ ) {
        SA = S[ Order - 1 ];
        out32_Q10 = 0;
        for( j = 0; j < ( Order_half - 1 ); j++ ) {
            idx = SKP_SMULBB( 2, j ) + 1;
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
            
            
            
            
            
            Atmp = A_align_Q12[ j ];
            SB = S[ Order - 1 - idx ];
            S[ Order - 1 - idx ] = SA;
            out32_Q10 = SKP_SMLAWB( out32_Q10, SA, Atmp );
            out32_Q10 = SKP_SMLAWT( out32_Q10, SB, Atmp );
            SA = S[ Order - 2 - idx ];
            S[ Order - 2 - idx ] = SB;
#else
            SB = S[ Order - 1 - idx ];
            S[ Order - 1 - idx ] = SA;
            out32_Q10 = SKP_SMLAWB( out32_Q10, SA, A_Q12[ ( j << 1 ) ] );
            out32_Q10 = SKP_SMLAWB( out32_Q10, SB, A_Q12[ ( j << 1 ) + 1 ] );
            SA = S[ Order - 2 - idx ];
            S[ Order - 2 - idx ] = SB;
#endif
        }

#if !defined(_SYSTEM_IS_BIG_ENDIAN)
        
        Atmp = A_align_Q12[ Order_half - 1 ];
        SB = S[ 0 ];
        S[ 0 ] = SA;
        out32_Q10 = SKP_SMLAWB( out32_Q10, SA, Atmp );
        out32_Q10 = SKP_SMLAWT( out32_Q10, SB, Atmp );
#else
        
        SB = S[ 0 ];
        S[ 0 ] = SA;
        out32_Q10 = SKP_SMLAWB( out32_Q10, SA, A_Q12[ Order - 2 ] );
        out32_Q10 = SKP_SMLAWB( out32_Q10, SB, A_Q12[ Order - 1 ] );
#endif
        
        out32_Q10 = SKP_ADD_SAT32( out32_Q10, SKP_SMULWB( Gain_Q26, in[ k ] ) );

        
        out32 = SKP_RSHIFT_ROUND( out32_Q10, 10 );

        
        out[ k ] = ( SKP_int16 )SKP_SAT16( out32 );

        
        S[ Order - 1 ] = SKP_LSHIFT_SAT32( out32_Q10, 4 );
    }
}








void SKP_Silk_LPC_synthesis_order16(const SKP_int16 *in,          
                                      const SKP_int16 *A_Q12,       
                                      const SKP_int32 Gain_Q26,     
                                      SKP_int32 *S,                 
                                      SKP_int16 *out,               
                                      const SKP_int32 len           
)
{
    SKP_int   k;
    SKP_int32 SA, SB, out32_Q10, out32;
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
    SKP_int32 Atmp, A_align_Q12[ 8 ];
    
    for( k = 0; k < 8; k++ ) {
        A_align_Q12[ k ] = ( ( ( SKP_int32 )A_Q12[ 2 * k ] ) & 0x0000ffff ) | SKP_LSHIFT( ( SKP_int32 )A_Q12[ 2 * k + 1 ], 16 );
    }
    
    
    
    
    
    for( k = 0; k < len; k++ ) {
        
        
        SA = S[ 15 ];
        Atmp = A_align_Q12[ 0 ];
        SB = S[ 14 ];
        S[ 14 ] = SA;
        out32_Q10 = SKP_SMULWB(                  SA, Atmp );
        out32_Q10 = SKP_SMLAWT_ovflw( out32_Q10, SB, Atmp );
        SA = S[ 13 ];
        S[ 13 ] = SB;

        
        Atmp = A_align_Q12[ 1 ];
        SB = S[ 12 ];
        S[ 12 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, Atmp );
        out32_Q10 = SKP_SMLAWT_ovflw( out32_Q10, SB, Atmp );
        SA = S[ 11 ];
        S[ 11 ] = SB;

        Atmp = A_align_Q12[ 2 ];
        SB = S[ 10 ];
        S[ 10 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, Atmp );
        out32_Q10 = SKP_SMLAWT_ovflw( out32_Q10, SB, Atmp );
        SA = S[ 9 ];
        S[ 9 ] = SB;

        Atmp = A_align_Q12[ 3 ];
        SB = S[ 8 ];
        S[ 8 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, Atmp );
        out32_Q10 = SKP_SMLAWT_ovflw( out32_Q10, SB, Atmp );
        SA = S[ 7 ];
        S[ 7 ] = SB;

        Atmp = A_align_Q12[ 4 ];
        SB = S[ 6 ];
        S[ 6 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, Atmp );
        out32_Q10 = SKP_SMLAWT_ovflw( out32_Q10, SB, Atmp );
        SA = S[ 5 ];
        S[ 5 ] = SB;

        Atmp = A_align_Q12[ 5 ];
        SB = S[ 4 ];
        S[ 4 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, Atmp );
        out32_Q10 = SKP_SMLAWT_ovflw( out32_Q10, SB, Atmp );
        SA = S[ 3 ];
        S[ 3 ] = SB;

        Atmp = A_align_Q12[ 6 ];
        SB = S[ 2 ];
        S[ 2 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, Atmp );
        out32_Q10 = SKP_SMLAWT_ovflw( out32_Q10, SB, Atmp );
        SA = S[ 1 ];
        S[ 1 ] = SB;

        
        Atmp = A_align_Q12[ 7 ];
        SB = S[ 0 ];
        S[ 0 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, Atmp );
        out32_Q10 = SKP_SMLAWT_ovflw( out32_Q10, SB, Atmp );

        
        
        out32_Q10 = SKP_ADD_SAT32( out32_Q10, SKP_SMULWB( Gain_Q26, in[ k ] ) );

        
        out32 = SKP_RSHIFT_ROUND( out32_Q10, 10 );

        
        out[ k ] = ( SKP_int16 )SKP_SAT16( out32 );

        
        S[ 15 ] = SKP_LSHIFT_SAT32( out32_Q10, 4 );
    }
#else
    for( k = 0; k < len; k++ ) {
        
        
        SA = S[ 15 ];
        SB = S[ 14 ];
        S[ 14 ] = SA;
        out32_Q10 = SKP_SMULWB(                  SA, A_Q12[ 0 ] );
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SB, A_Q12[ 1 ] );
        SA = S[ 13 ];
        S[ 13 ] = SB;

        
        SB = S[ 12 ];
        S[ 12 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, A_Q12[ 2 ] );
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SB, A_Q12[ 3 ] );
        SA = S[ 11 ];
        S[ 11 ] = SB;

        SB = S[ 10 ];
        S[ 10 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, A_Q12[ 4 ] );
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SB, A_Q12[ 5 ] );
        SA = S[ 9 ];
        S[ 9 ] = SB;

        SB = S[ 8 ];
        S[ 8 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, A_Q12[ 6 ] );
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SB, A_Q12[ 7 ] );
        SA = S[ 7 ];
        S[ 7 ] = SB;

        SB = S[ 6 ];
        S[ 6 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, A_Q12[ 8 ] );
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SB, A_Q12[ 9 ] );
        SA = S[ 5 ];
        S[ 5 ] = SB;

        SB = S[ 4 ];
        S[ 4 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, A_Q12[ 10 ] );
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SB, A_Q12[ 11 ] );
        SA = S[ 3 ];
        S[ 3 ] = SB;

        SB = S[ 2 ];
        S[ 2 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, A_Q12[ 12 ] );
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SB, A_Q12[ 13 ] );
        SA = S[ 1 ];
        S[ 1 ] = SB;

        
        SB = S[ 0 ];
        S[ 0 ] = SA;
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SA, A_Q12[ 14 ] );
        out32_Q10 = SKP_SMLAWB_ovflw( out32_Q10, SB, A_Q12[ 15 ] );

        
        
        out32_Q10 = SKP_ADD_SAT32( out32_Q10, SKP_SMULWB( Gain_Q26, in[ k ] ) );

        
        out32 = SKP_RSHIFT_ROUND( out32_Q10, 10 );

        
        out[ k ] = ( SKP_int16 )SKP_SAT16( out32 );

        
        S[ 15 ] = SKP_LSHIFT_SAT32( out32_Q10, 4 );
    }
#endif
}









#if SWITCH_TRANSITION_FILTERING


SKP_INLINE void SKP_Silk_LP_interpolate_filter_taps( 
    SKP_int32           B_Q28[ TRANSITION_NB ], 
    SKP_int32           A_Q28[ TRANSITION_NA ],
    const SKP_int       ind,
    const SKP_int32     fac_Q16
)
{
    SKP_int nb, na;

    if( ind < TRANSITION_INT_NUM - 1 ) {
        if( fac_Q16 > 0 ) {
            if( fac_Q16 == SKP_SAT16( fac_Q16 ) ) { 
                
                for( nb = 0; nb < TRANSITION_NB; nb++ ) {
                    B_Q28[ nb ] = SKP_SMLAWB(
                        SKP_Silk_Transition_LP_B_Q28[ ind     ][ nb ],
                        SKP_Silk_Transition_LP_B_Q28[ ind + 1 ][ nb ] -
                        SKP_Silk_Transition_LP_B_Q28[ ind     ][ nb ],
                        fac_Q16 );
                }
                for( na = 0; na < TRANSITION_NA; na++ ) {
                    A_Q28[ na ] = SKP_SMLAWB(
                        SKP_Silk_Transition_LP_A_Q28[ ind     ][ na ],
                        SKP_Silk_Transition_LP_A_Q28[ ind + 1 ][ na ] -
                        SKP_Silk_Transition_LP_A_Q28[ ind     ][ na ],
                        fac_Q16 );
                }
            } else if( fac_Q16 == ( 1 << 15 ) ) { 

                
                for( nb = 0; nb < TRANSITION_NB; nb++ ) {
                    B_Q28[ nb ] = SKP_RSHIFT( 
                        SKP_Silk_Transition_LP_B_Q28[ ind     ][ nb ] +
                        SKP_Silk_Transition_LP_B_Q28[ ind + 1 ][ nb ],
                        1 );
                }
                for( na = 0; na < TRANSITION_NA; na++ ) {
                    A_Q28[ na ] = SKP_RSHIFT( 
                        SKP_Silk_Transition_LP_A_Q28[ ind     ][ na ] + 
                        SKP_Silk_Transition_LP_A_Q28[ ind + 1 ][ na ], 
                        1 );
                }
            } else { 
                
                SKP_assert( ( ( 1 << 16 ) - fac_Q16 ) == SKP_SAT16( ( ( 1 << 16 ) - fac_Q16) ) );
                
                for( nb = 0; nb < TRANSITION_NB; nb++ ) {
                    B_Q28[ nb ] = SKP_SMLAWB(
                        SKP_Silk_Transition_LP_B_Q28[ ind + 1 ][ nb ],
                        SKP_Silk_Transition_LP_B_Q28[ ind     ][ nb ] -
                        SKP_Silk_Transition_LP_B_Q28[ ind + 1 ][ nb ],
                        ( 1 << 16 ) - fac_Q16 );
                }
                for( na = 0; na < TRANSITION_NA; na++ ) {
                    A_Q28[ na ] = SKP_SMLAWB(
                        SKP_Silk_Transition_LP_A_Q28[ ind + 1 ][ na ],
                        SKP_Silk_Transition_LP_A_Q28[ ind     ][ na ] -
                        SKP_Silk_Transition_LP_A_Q28[ ind + 1 ][ na ],
                        ( 1 << 16 ) - fac_Q16 );
                }
            }
        } else {
            SKP_memcpy( B_Q28, SKP_Silk_Transition_LP_B_Q28[ ind ], TRANSITION_NB * sizeof( SKP_int32 ) );
            SKP_memcpy( A_Q28, SKP_Silk_Transition_LP_A_Q28[ ind ], TRANSITION_NA * sizeof( SKP_int32 ) );
        }
    } else {
        SKP_memcpy( B_Q28, SKP_Silk_Transition_LP_B_Q28[ TRANSITION_INT_NUM - 1 ], TRANSITION_NB * sizeof( SKP_int32 ) );
        SKP_memcpy( A_Q28, SKP_Silk_Transition_LP_A_Q28[ TRANSITION_INT_NUM - 1 ], TRANSITION_NA * sizeof( SKP_int32 ) );
    }
}





void SKP_Silk_LP_variable_cutoff(
    SKP_Silk_LP_state               *psLP,          
    SKP_int16                       *out,           
    const SKP_int16                 *in,            
    const SKP_int                   frame_length    
)
{
    SKP_int32   B_Q28[ TRANSITION_NB ], A_Q28[ TRANSITION_NA ], fac_Q16 = 0;
    SKP_int     ind = 0;

    SKP_assert( psLP->transition_frame_no >= 0 );
    SKP_assert( ( ( ( psLP->transition_frame_no <= TRANSITION_FRAMES_DOWN ) && ( psLP->mode == 0 ) ) || 
                  ( ( psLP->transition_frame_no <= TRANSITION_FRAMES_UP   ) && ( psLP->mode == 1 ) ) ) );

    
    if( psLP->transition_frame_no > 0 ) {
        if( psLP->mode == 0 ) {
            if( psLP->transition_frame_no < TRANSITION_FRAMES_DOWN ) {
                
#if( TRANSITION_INT_STEPS_DOWN == 32 )
                fac_Q16 = SKP_LSHIFT( psLP->transition_frame_no, 16 - 5 );
#else
                fac_Q16 = SKP_DIV32_16( SKP_LSHIFT( psLP->transition_frame_no, 16 ), TRANSITION_INT_STEPS_DOWN );
#endif
                ind      = SKP_RSHIFT( fac_Q16, 16 );
                fac_Q16 -= SKP_LSHIFT( ind, 16 );

                SKP_assert( ind >= 0 );
                SKP_assert( ind < TRANSITION_INT_NUM );

                
                SKP_Silk_LP_interpolate_filter_taps( B_Q28, A_Q28, ind, fac_Q16 );

                
                psLP->transition_frame_no++;

            } else {
                SKP_assert( psLP->transition_frame_no == TRANSITION_FRAMES_DOWN );
                
                SKP_Silk_LP_interpolate_filter_taps( B_Q28, A_Q28, TRANSITION_INT_NUM - 1, 0 );
            }
        } else {
            SKP_assert( psLP->mode == 1 );
            if( psLP->transition_frame_no < TRANSITION_FRAMES_UP ) {
                
#if( TRANSITION_INT_STEPS_UP == 64 )
                fac_Q16 = SKP_LSHIFT( TRANSITION_FRAMES_UP - psLP->transition_frame_no, 16 - 6 );
#else
                fac_Q16 = SKP_DIV32_16( SKP_LSHIFT( TRANSITION_FRAMES_UP - psLP->transition_frame_no, 16 ), TRANSITION_INT_STEPS_UP );
#endif
                ind      = SKP_RSHIFT( fac_Q16, 16 );
                fac_Q16 -= SKP_LSHIFT( ind, 16 );

                SKP_assert( ind >= 0 );
                SKP_assert( ind < TRANSITION_INT_NUM );

                
                SKP_Silk_LP_interpolate_filter_taps( B_Q28, A_Q28, ind, fac_Q16 );

                
                psLP->transition_frame_no++;
            
            } else {
                SKP_assert( psLP->transition_frame_no == TRANSITION_FRAMES_UP );
                
                SKP_Silk_LP_interpolate_filter_taps( B_Q28, A_Q28, 0, 0 );
            }
        }
    } 
    
    if( psLP->transition_frame_no > 0 ) {
        
        SKP_assert( TRANSITION_NB == 3 && TRANSITION_NA == 2 );
        SKP_Silk_biquad_alt( in, B_Q28, A_Q28, psLP->In_LP_State, out, frame_length );
    } else {
        
        SKP_memcpy( out, in, frame_length * sizeof( SKP_int16 ) );
    }
}
#endif







const SKP_int SKP_Silk_LSFCosTab_FIX_Q12[LSF_COS_TAB_SZ_FIX + 1] = {
            8192,             8190,             8182,             8170,     
            8152,             8130,             8104,             8072,     
            8034,             7994,             7946,             7896,     
            7840,             7778,             7714,             7644,     
            7568,             7490,             7406,             7318,     
            7226,             7128,             7026,             6922,     
            6812,             6698,             6580,             6458,     
            6332,             6204,             6070,             5934,     
            5792,             5648,             5502,             5352,     
            5198,             5040,             4880,             4718,     
            4552,             4382,             4212,             4038,     
            3862,             3684,             3502,             3320,     
            3136,             2948,             2760,             2570,     
            2378,             2186,             1990,             1794,     
            1598,             1400,             1202,             1002,     
             802,              602,              402,              202,     
               0,             -202,             -402,             -602,     
            -802,            -1002,            -1202,            -1400,     
           -1598,            -1794,            -1990,            -2186,     
           -2378,            -2570,            -2760,            -2948,     
           -3136,            -3320,            -3502,            -3684,     
           -3862,            -4038,            -4212,            -4382,     
           -4552,            -4718,            -4880,            -5040,     
           -5198,            -5352,            -5502,            -5648,     
           -5792,            -5934,            -6070,            -6204,     
           -6332,            -6458,            -6580,            -6698,     
           -6812,            -6922,            -7026,            -7128,     
           -7226,            -7318,            -7406,            -7490,     
           -7568,            -7644,            -7714,            -7778,     
           -7840,            -7896,            -7946,            -7994,     
           -8034,            -8072,            -8104,            -8130,     
           -8152,            -8170,            -8182,            -8190,     
           -8192
};






void SKP_Silk_LTP_analysis_filter_FIX(
    SKP_int16       *LTP_res,                           
    const SKP_int16 *x,                                 
    const SKP_int16 LTPCoef_Q14[ LTP_ORDER * NB_SUBFR ],
    const SKP_int   pitchL[ NB_SUBFR ],                 
    const SKP_int32 invGains_Q16[ NB_SUBFR ],           
    const SKP_int   subfr_length,                       
    const SKP_int   pre_length                          
)
{
    const SKP_int16 *x_ptr, *x_lag_ptr;
    SKP_int16   Btmp_Q14[ LTP_ORDER ];
    SKP_int16   *LTP_res_ptr;
    SKP_int     k, i, j;
    SKP_int32   LTP_est;

    x_ptr = x;
    LTP_res_ptr = LTP_res;
    for( k = 0; k < NB_SUBFR; k++ ) {

        x_lag_ptr = x_ptr - pitchL[ k ];
        for( i = 0; i < LTP_ORDER; i++ ) {
            Btmp_Q14[ i ] = LTPCoef_Q14[ k * LTP_ORDER + i ];
        }

        
        for( i = 0; i < subfr_length + pre_length; i++ ) {
            LTP_res_ptr[ i ] = x_ptr[ i ];
            
            
            LTP_est = SKP_SMULBB( x_lag_ptr[ LTP_ORDER / 2 ], Btmp_Q14[ 0 ] );
            for( j = 1; j < LTP_ORDER; j++ ) {
                LTP_est = SKP_SMLABB_ovflw( LTP_est, x_lag_ptr[ LTP_ORDER / 2 - j ], Btmp_Q14[ j ] );
			}
            LTP_est = SKP_RSHIFT_ROUND( LTP_est, 14 ); 

            
            LTP_res_ptr[ i ] = ( SKP_int16 )SKP_SAT16( ( SKP_int32 )x_ptr[ i ] - LTP_est );

            
            LTP_res_ptr[ i ] = SKP_SMULWB( invGains_Q16[ k ], LTP_res_ptr[ i ] );

            x_lag_ptr++;
        }

        
        LTP_res_ptr += subfr_length + pre_length; 
        x_ptr       += subfr_length;
    }
}







#define NB_THRESHOLDS           11


static const SKP_int16 LTPScaleThresholds_Q15[ NB_THRESHOLDS ] = 
{
    31129, 26214, 16384, 13107, 9830, 6554,
     4915,  3276,  2621,  2458,    0
};

void SKP_Silk_LTP_scale_ctrl_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,     
    SKP_Silk_encoder_control_FIX    *psEncCtrl  
)
{
    SKP_int round_loss, frames_per_packet;
    SKP_int g_out_Q5, g_limit_Q15, thrld1_Q15, thrld2_Q15;

    
    psEnc->HPLTPredCodGain_Q7 = SKP_max_int( psEncCtrl->LTPredCodGain_Q7 - psEnc->prevLTPredCodGain_Q7, 0 ) 
        + SKP_RSHIFT_ROUND( psEnc->HPLTPredCodGain_Q7, 1 );
    
    psEnc->prevLTPredCodGain_Q7 = psEncCtrl->LTPredCodGain_Q7;

    
    g_out_Q5    = SKP_RSHIFT_ROUND( SKP_RSHIFT( psEncCtrl->LTPredCodGain_Q7, 1 ) + SKP_RSHIFT( psEnc->HPLTPredCodGain_Q7, 1 ), 3 );
    g_limit_Q15 = SKP_Silk_sigm_Q15( g_out_Q5 - ( 3 << 5 ) );
            
    
    psEncCtrl->sCmn.LTP_scaleIndex = 0;

    
    round_loss = ( SKP_int )psEnc->sCmn.PacketLoss_perc;

    
    if( psEnc->sCmn.nFramesInPayloadBuf == 0 ) {
        
        frames_per_packet = SKP_DIV32_16( psEnc->sCmn.PacketSize_ms, FRAME_LENGTH_MS );

        round_loss += frames_per_packet - 1;
        thrld1_Q15 = LTPScaleThresholds_Q15[ SKP_min_int( round_loss,     NB_THRESHOLDS - 1 ) ];
        thrld2_Q15 = LTPScaleThresholds_Q15[ SKP_min_int( round_loss + 1, NB_THRESHOLDS - 1 ) ];
    
        if( g_limit_Q15 > thrld1_Q15 ) {
            
            psEncCtrl->sCmn.LTP_scaleIndex = 2;
        } else if( g_limit_Q15 > thrld2_Q15 ) {
            
            psEncCtrl->sCmn.LTP_scaleIndex = 1;
        }
    }
    psEncCtrl->LTP_scale_Q14 = SKP_Silk_LTPScales_table_Q14[ psEncCtrl->sCmn.LTP_scaleIndex ];
}







#if EMBEDDED_ARM<5

void SKP_Silk_MA_Prediction(
    const SKP_int16      *in,            
    const SKP_int16      *B,             
    SKP_int32            *S,             
    SKP_int16            *out,           
    const SKP_int32      len,            
    const SKP_int32      order           
)
{
    SKP_int   k, d, in16;
    SKP_int32 out32;

    for( k = 0; k < len; k++ ) {
        in16 = in[ k ];
        out32 = SKP_LSHIFT( in16, 12 ) - S[ 0 ];
        out32 = SKP_RSHIFT_ROUND( out32, 12 );
        
        for( d = 0; d < order - 1; d++ ) {
            S[ d ] = SKP_SMLABB_ovflw( S[ d + 1 ], in16, B[ d ] );
        }
        S[ order - 1 ] = SKP_SMULBB( in16, B[ order - 1 ] );

        
        out[ k ] = (SKP_int16)SKP_SAT16( out32 );
    }
}
#endif

#if EMBEDDED_ARM<5

void SKP_Silk_LPC_analysis_filter(
    const SKP_int16      *in,            
    const SKP_int16      *B,             
    SKP_int16            *S,             
    SKP_int16            *out,           
    const SKP_int32      len,            
    const SKP_int32      Order           
)
{
    SKP_int   k, j, idx, Order_half = SKP_RSHIFT( Order, 1 );
    SKP_int32 out32_Q12, out32;
    SKP_int16 SA, SB;
    
    SKP_assert( 2 * Order_half == Order );

    
    for( k = 0; k < len; k++ ) {
        SA = S[ 0 ];
        out32_Q12 = 0;
        for( j = 0; j < ( Order_half - 1 ); j++ ) {
            idx = SKP_SMULBB( 2, j ) + 1;
            
            SB = S[ idx ];
            S[ idx ] = SA;
            out32_Q12 = SKP_SMLABB( out32_Q12, SA, B[ idx - 1 ] );
            out32_Q12 = SKP_SMLABB( out32_Q12, SB, B[ idx ] );
            SA = S[ idx + 1 ];
            S[ idx + 1 ] = SB;
        }

        
        SB = S[ Order - 1 ];
        S[ Order - 1 ] = SA;
        out32_Q12 = SKP_SMLABB( out32_Q12, SA, B[ Order - 2 ] );
        out32_Q12 = SKP_SMLABB( out32_Q12, SB, B[ Order - 1 ] );

        
        out32_Q12 = SKP_SUB_SAT32( SKP_LSHIFT( (SKP_int32)in[ k ], 12 ), out32_Q12 );

        
        out32 = SKP_RSHIFT_ROUND( out32_Q12, 12 );

        
        out[ k ] = ( SKP_int16 )SKP_SAT16( out32 );

        
        S[ 0 ] = in[ k ];
    }
}
#endif














SKP_INLINE void SKP_Silk_NLSF2A_find_poly(
    SKP_int32        *out,        
    const SKP_int32    *cLSF,     
    SKP_int            dd         
)
{
    SKP_int        k, n;
    SKP_int32    ftmp;

    out[0] = SKP_LSHIFT( 1, 20 );
    out[1] = -cLSF[0];
    for( k = 1; k < dd; k++ ) {
        ftmp = cLSF[2*k];            
        out[k+1] = SKP_LSHIFT( out[k-1], 1 ) - (SKP_int32)SKP_RSHIFT_ROUND64( SKP_SMULL( ftmp, out[k] ), 20 );
        for( n = k; n > 1; n-- ) {
            out[n] += out[n-2] - (SKP_int32)SKP_RSHIFT_ROUND64( SKP_SMULL( ftmp, out[n-1] ), 20 );
        }
        out[1] -= ftmp;
    }
}


void SKP_Silk_NLSF2A(
    SKP_int16       *a,               
    const SKP_int    *NLSF,           
    const SKP_int    d                
)
{
    SKP_int k, i, dd;
    SKP_int32 cos_LSF_Q20[SKP_Silk_MAX_ORDER_LPC];
    SKP_int32 P[SKP_Silk_MAX_ORDER_LPC/2+1], Q[SKP_Silk_MAX_ORDER_LPC/2+1];
    SKP_int32 Ptmp, Qtmp;
    SKP_int32 f_int;
    SKP_int32 f_frac;
    SKP_int32 cos_val, delta;
    SKP_int32 a_int32[SKP_Silk_MAX_ORDER_LPC];
    SKP_int32 maxabs, absval, idx=0, sc_Q16; 

    SKP_assert(LSF_COS_TAB_SZ_FIX == 128);

    
    for( k = 0; k < d; k++ ) {
        SKP_assert(NLSF[k] >= 0 );
        SKP_assert(NLSF[k] <= 32767 );

        
        f_int = SKP_RSHIFT( NLSF[k], 15 - 7 ); 
        
        
        f_frac = NLSF[k] - SKP_LSHIFT( f_int, 15 - 7 ); 

        SKP_assert(f_int >= 0);
        SKP_assert(f_int < LSF_COS_TAB_SZ_FIX );

        
        cos_val = SKP_Silk_LSFCosTab_FIX_Q12[ f_int ];                
        delta   = SKP_Silk_LSFCosTab_FIX_Q12[ f_int + 1 ] - cos_val;  

        
        cos_LSF_Q20[k] = SKP_LSHIFT( cos_val, 8 ) + SKP_MUL( delta, f_frac ); 
    }
    
    dd = SKP_RSHIFT( d, 1 );

    
    SKP_Silk_NLSF2A_find_poly( P, &cos_LSF_Q20[0], dd );
    SKP_Silk_NLSF2A_find_poly( Q, &cos_LSF_Q20[1], dd );

    
    for( k = 0; k < dd; k++ ) {
        Ptmp = P[k+1] + P[k];
        Qtmp = Q[k+1] - Q[k];

        

        a_int32[k]     = -SKP_RSHIFT_ROUND( Ptmp + Qtmp, 9 ); 
        a_int32[d-k-1] =  SKP_RSHIFT_ROUND( Qtmp - Ptmp, 9 ); 
    }

    
    for( i = 0; i < 10; i++ ) {
        
        maxabs = 0;
        for( k = 0; k < d; k++ ) {
            absval = SKP_abs( a_int32[k] );
            if( absval > maxabs ) {
                maxabs = absval;
                idx       = k;
            }    
        }
    
        if( maxabs > SKP_int16_MAX ) {    
            
            maxabs = SKP_min( maxabs, 98369 ); 
            sc_Q16 = 65470 - SKP_DIV32( SKP_MUL( 65470 >> 2, maxabs - SKP_int16_MAX ), 
                                        SKP_RSHIFT32( SKP_MUL( maxabs, idx + 1), 2 ) );
            SKP_Silk_bwexpander_32( a_int32, d, sc_Q16 );
        } else {
            break;
        }
    }    

    
    if( i == 10 ) {
        SKP_assert(0);
        for( k = 0; k < d; k++ ) {
            a_int32[k] = SKP_SAT16( a_int32[k] ); 
        }
    }

    
    for( k = 0; k < d; k++ ) {
        a[k] = (SKP_int16)a_int32[k];
    }
}







void SKP_Silk_NLSF2A_stable(
    SKP_int16                       pAR_Q12[ MAX_LPC_ORDER ],    
    const SKP_int                   pNLSF[ MAX_LPC_ORDER ],     
    const SKP_int                   LPC_order                   
)
{
    SKP_int   i;
    SKP_int32 invGain_Q30;

    SKP_Silk_NLSF2A( pAR_Q12, pNLSF, LPC_order );

    
    for( i = 0; i < MAX_LPC_STABILIZE_ITERATIONS; i++ ) {
        if( SKP_Silk_LPC_inverse_pred_gain( &invGain_Q30, pAR_Q12, LPC_order ) == 1 ) {
            SKP_Silk_bwexpander( pAR_Q12, LPC_order, 65536 - SKP_SMULBB( 10 + i, i ) );		
        } else {
            break;
        }
    }

    
    if( i == MAX_LPC_STABILIZE_ITERATIONS ) {
        SKP_assert( 0 );
        for( i = 0; i < LPC_order; i++ ) {
            pAR_Q12[ i ] = 0;
        }
    }
}







void SKP_Silk_NLSF_MSVQ_decode(
    SKP_int                         *pNLSF_Q15,     
    const SKP_Silk_NLSF_CB_struct   *psNLSF_CB,     
    const SKP_int                   *NLSFIndices,   
    const SKP_int                   LPC_order       
) 
{
    const SKP_int16 *pCB_element;
          SKP_int    s;
          SKP_int    i;

    
    SKP_assert( 0 <= NLSFIndices[ 0 ] && NLSFIndices[ 0 ] < psNLSF_CB->CBStages[ 0 ].nVectors );

    
    pCB_element = &psNLSF_CB->CBStages[ 0 ].CB_NLSF_Q15[ SKP_MUL( NLSFIndices[ 0 ], LPC_order ) ];

    
    for( i = 0; i < LPC_order; i++ ) {
        pNLSF_Q15[ i ] = ( SKP_int )pCB_element[ i ];
    }
          
    for( s = 1; s < psNLSF_CB->nStages; s++ ) {
        
        SKP_assert( 0 <= NLSFIndices[ s ] && NLSFIndices[ s ] < psNLSF_CB->CBStages[ s ].nVectors );

        if( LPC_order == 16 ) {
            
            pCB_element = &psNLSF_CB->CBStages[ s ].CB_NLSF_Q15[ SKP_LSHIFT( NLSFIndices[ s ], 4 ) ];

            
            pNLSF_Q15[  0 ] += pCB_element[  0 ];
            pNLSF_Q15[  1 ] += pCB_element[  1 ];
            pNLSF_Q15[  2 ] += pCB_element[  2 ];
            pNLSF_Q15[  3 ] += pCB_element[  3 ];
            pNLSF_Q15[  4 ] += pCB_element[  4 ];
            pNLSF_Q15[  5 ] += pCB_element[  5 ];
            pNLSF_Q15[  6 ] += pCB_element[  6 ];
            pNLSF_Q15[  7 ] += pCB_element[  7 ];
            pNLSF_Q15[  8 ] += pCB_element[  8 ];
            pNLSF_Q15[  9 ] += pCB_element[  9 ];
            pNLSF_Q15[ 10 ] += pCB_element[ 10 ];
            pNLSF_Q15[ 11 ] += pCB_element[ 11 ];
            pNLSF_Q15[ 12 ] += pCB_element[ 12 ];
            pNLSF_Q15[ 13 ] += pCB_element[ 13 ];
            pNLSF_Q15[ 14 ] += pCB_element[ 14 ];
            pNLSF_Q15[ 15 ] += pCB_element[ 15 ];
        } else {
            
            pCB_element = &psNLSF_CB->CBStages[ s ].CB_NLSF_Q15[ SKP_SMULBB( NLSFIndices[ s ], LPC_order ) ];

            
            for( i = 0; i < LPC_order; i++ ) {
                pNLSF_Q15[ i ] += pCB_element[ i ];
            }
        }
    }

    
    SKP_Silk_NLSF_stabilize( pNLSF_Q15, psNLSF_CB->NDeltaMin_Q15, LPC_order );
}









void SKP_Silk_NLSF_MSVQ_encode_FIX(
          SKP_int                   *NLSFIndices,           
          SKP_int                   *pNLSF_Q15,             
    const SKP_Silk_NLSF_CB_struct   *psNLSF_CB,             
    const SKP_int                   *pNLSF_q_Q15_prev,      
    const SKP_int                   *pW_Q6,                 
    const SKP_int                   NLSF_mu_Q15,            
    const SKP_int                   NLSF_mu_fluc_red_Q16,   
    const SKP_int                   NLSF_MSVQ_Survivors,    
    const SKP_int                   LPC_order,              
    const SKP_int                   deactivate_fluc_red     
)
{
    SKP_int     i, s, k, cur_survivors = 0, prev_survivors, min_survivors, input_index, cb_index, bestIndex;
    SKP_int32   rateDistThreshold_Q18;
#if( NLSF_MSVQ_FLUCTUATION_REDUCTION == 1 )
    SKP_int32   se_Q15, wsse_Q20, bestRateDist_Q20;
#endif

#if( LOW_COMPLEXITY_ONLY == 1 )
    SKP_int32   pRateDist_Q18[  NLSF_MSVQ_TREE_SEARCH_MAX_VECTORS_EVALUATED_LC_MODE ];
    SKP_int32   pRate_Q5[       MAX_NLSF_MSVQ_SURVIVORS_LC_MODE ];
    SKP_int32   pRate_new_Q5[   MAX_NLSF_MSVQ_SURVIVORS_LC_MODE ];
    SKP_int     pTempIndices[   MAX_NLSF_MSVQ_SURVIVORS_LC_MODE ];
    SKP_int     pPath[          MAX_NLSF_MSVQ_SURVIVORS_LC_MODE * NLSF_MSVQ_MAX_CB_STAGES ];
    SKP_int     pPath_new[      MAX_NLSF_MSVQ_SURVIVORS_LC_MODE * NLSF_MSVQ_MAX_CB_STAGES ];
    SKP_int     pRes_Q15[       MAX_NLSF_MSVQ_SURVIVORS_LC_MODE * MAX_LPC_ORDER ];
    SKP_int     pRes_new_Q15[   MAX_NLSF_MSVQ_SURVIVORS_LC_MODE * MAX_LPC_ORDER ];
#else
    SKP_int32   pRateDist_Q18[  NLSF_MSVQ_TREE_SEARCH_MAX_VECTORS_EVALUATED ];
    SKP_int32   pRate_Q5[       MAX_NLSF_MSVQ_SURVIVORS ];
    SKP_int32   pRate_new_Q5[   MAX_NLSF_MSVQ_SURVIVORS ];
    SKP_int     pTempIndices[   MAX_NLSF_MSVQ_SURVIVORS ];
    SKP_int     pPath[          MAX_NLSF_MSVQ_SURVIVORS * NLSF_MSVQ_MAX_CB_STAGES ];
    SKP_int     pPath_new[      MAX_NLSF_MSVQ_SURVIVORS * NLSF_MSVQ_MAX_CB_STAGES ];
    SKP_int     pRes_Q15[       MAX_NLSF_MSVQ_SURVIVORS * MAX_LPC_ORDER ];
    SKP_int     pRes_new_Q15[   MAX_NLSF_MSVQ_SURVIVORS * MAX_LPC_ORDER ];
#endif

    const SKP_int   *pConstInt;
          SKP_int   *pInt;
    const SKP_int16 *pCB_element;
    const SKP_Silk_NLSF_CBS *pCurrentCBStage;

#ifdef USE_UNQUANTIZED_LSFS
    SKP_int NLSF_orig[ MAX_LPC_ORDER ];
    SKP_memcpy( NLSF_orig, pNLSF_Q15, LPC_order * sizeof( SKP_int ) );
#endif

    SKP_assert( NLSF_MSVQ_Survivors <= MAX_NLSF_MSVQ_SURVIVORS );
    SKP_assert( ( LOW_COMPLEXITY_ONLY == 0 ) || ( NLSF_MSVQ_Survivors <= MAX_NLSF_MSVQ_SURVIVORS_LC_MODE ) );


    
    
    

    
    SKP_memset( pRate_Q5, 0, NLSF_MSVQ_Survivors * sizeof( SKP_int32 ) );
    
    
    for( i = 0; i < LPC_order; i++ ) {
        pRes_Q15[ i ] = pNLSF_Q15[ i ];
    }

    
    prev_survivors = 1;

    
    min_survivors = NLSF_MSVQ_Survivors / 2;

    
    for( s = 0; s < psNLSF_CB->nStages; s++ ) {

        
        pCurrentCBStage = &psNLSF_CB->CBStages[ s ];

        
        cur_survivors = SKP_min_32( NLSF_MSVQ_Survivors, SKP_SMULBB( prev_survivors, pCurrentCBStage->nVectors ) );

#if( NLSF_MSVQ_FLUCTUATION_REDUCTION == 0 )
        
        
        if( s == psNLSF_CB->nStages - 1 ) {
            cur_survivors = 1;
        }
#endif

        
        SKP_Silk_NLSF_VQ_rate_distortion_FIX( pRateDist_Q18, pCurrentCBStage, pRes_Q15, pW_Q6, 
            pRate_Q5, NLSF_mu_Q15, prev_survivors, LPC_order );

        
        SKP_Silk_insertion_sort_increasing( pRateDist_Q18, pTempIndices, 
            prev_survivors * pCurrentCBStage->nVectors, cur_survivors );

        
        if( pRateDist_Q18[ 0 ] < SKP_int32_MAX / MAX_NLSF_MSVQ_SURVIVORS ) {
            rateDistThreshold_Q18 = SKP_SMLAWB( pRateDist_Q18[ 0 ], 
                SKP_MUL( NLSF_MSVQ_Survivors, pRateDist_Q18[ 0 ] ), SKP_FIX_CONST( NLSF_MSVQ_SURV_MAX_REL_RD, 16 ) );
            while( pRateDist_Q18[ cur_survivors - 1 ] > rateDistThreshold_Q18 && cur_survivors > min_survivors ) {
                cur_survivors--;
            }
        }
        
        for( k = 0; k < cur_survivors; k++ ) { 
            if( s > 0 ) {
                
                if( pCurrentCBStage->nVectors == 8 ) {
                    input_index = SKP_RSHIFT( pTempIndices[ k ], 3 );
                    cb_index    = pTempIndices[ k ] & 7;
                } else {
                    input_index = SKP_DIV32_16( pTempIndices[ k ], pCurrentCBStage->nVectors );  
                    cb_index    = pTempIndices[ k ] - SKP_SMULBB( input_index, pCurrentCBStage->nVectors );
                }
            } else {
                
                input_index = 0;
                cb_index    = pTempIndices[ k ];
            }

            
            pConstInt   = &pRes_Q15[ SKP_SMULBB( input_index, LPC_order ) ];
            pCB_element = &pCurrentCBStage->CB_NLSF_Q15[ SKP_SMULBB( cb_index, LPC_order ) ];
            pInt        = &pRes_new_Q15[ SKP_SMULBB( k, LPC_order ) ];
            for( i = 0; i < LPC_order; i++ ) {
                pInt[ i ] = pConstInt[ i ] - ( SKP_int )pCB_element[ i ];
            }

            
            pRate_new_Q5[ k ] = pRate_Q5[ input_index ] + pCurrentCBStage->Rates_Q5[ cb_index ];

            
            pConstInt = &pPath[ SKP_SMULBB( input_index, psNLSF_CB->nStages ) ];
            pInt      = &pPath_new[ SKP_SMULBB( k, psNLSF_CB->nStages ) ];
            for( i = 0; i < s; i++ ) {
                pInt[ i ] = pConstInt[ i ];
            }
            
            pInt[ s ] = cb_index;
        }

        if( s < psNLSF_CB->nStages - 1 ) {
            
            SKP_memcpy( pRes_Q15, pRes_new_Q15, SKP_SMULBB( cur_survivors, LPC_order ) * sizeof( SKP_int ) );

            
            SKP_memcpy( pRate_Q5, pRate_new_Q5, cur_survivors * sizeof( SKP_int32 ) );

            
            SKP_memcpy( pPath, pPath_new, SKP_SMULBB( cur_survivors, psNLSF_CB->nStages ) * sizeof( SKP_int ) );
        }

        prev_survivors = cur_survivors;
    }

    
    bestIndex = 0;

#if( NLSF_MSVQ_FLUCTUATION_REDUCTION == 1 )
    
    
    
    if( deactivate_fluc_red != 1 ) {
    
        
        bestRateDist_Q20 = SKP_int32_MAX;
        for( s = 0; s < cur_survivors; s++ ) {
            
            SKP_Silk_NLSF_MSVQ_decode( pNLSF_Q15, psNLSF_CB, &pPath_new[ SKP_SMULBB( s, psNLSF_CB->nStages ) ], LPC_order );

             
            wsse_Q20 = 0;
            for( i = 0; i < LPC_order; i += 2 ) {
                
                se_Q15 = pNLSF_Q15[ i ] - pNLSF_q_Q15_prev[ i ]; 
                wsse_Q20 = SKP_SMLAWB( wsse_Q20, SKP_SMULBB( se_Q15, se_Q15 ), pW_Q6[ i ] );

                
                se_Q15 = pNLSF_Q15[ i + 1 ] - pNLSF_q_Q15_prev[ i + 1 ]; 
                wsse_Q20 = SKP_SMLAWB( wsse_Q20, SKP_SMULBB( se_Q15, se_Q15 ), pW_Q6[ i + 1 ] );
            }
            SKP_assert( wsse_Q20 >= 0 );

            
            wsse_Q20 = SKP_ADD_POS_SAT32( pRateDist_Q18[ s ], SKP_SMULWB( wsse_Q20, NLSF_mu_fluc_red_Q16 ) );

            
            if( wsse_Q20 < bestRateDist_Q20 ) {
                bestRateDist_Q20 = wsse_Q20;
                bestIndex = s;
            }
        }
    }
#endif

    
    SKP_memcpy( NLSFIndices, &pPath_new[ SKP_SMULBB( bestIndex, psNLSF_CB->nStages ) ], psNLSF_CB->nStages * sizeof( SKP_int ) );

    
    SKP_Silk_NLSF_MSVQ_decode( pNLSF_Q15, psNLSF_CB, NLSFIndices, LPC_order );

#ifdef USE_UNQUANTIZED_LSFS
    SKP_memcpy( pNLSF_Q15, NLSF_orig, LPC_order * sizeof( SKP_int ) );
#endif

}







void SKP_Silk_NLSF_VQ_rate_distortion_FIX(
    SKP_int32                       *pRD_Q20,           
    const SKP_Silk_NLSF_CBS         *psNLSF_CBS,        
    const SKP_int                   *in_Q15,            
    const SKP_int                   *w_Q6,              
    const SKP_int32                 *rate_acc_Q5,       
    const SKP_int                   mu_Q15,             
    const SKP_int                   N,                  
    const SKP_int                   LPC_order           
)
{
    SKP_int   i, n;
    SKP_int32 *pRD_vec_Q20;

    
    SKP_Silk_NLSF_VQ_sum_error_FIX( pRD_Q20, in_Q15, w_Q6, psNLSF_CBS->CB_NLSF_Q15, 
        N, psNLSF_CBS->nVectors, LPC_order );

    
    pRD_vec_Q20 = pRD_Q20;
    for( n = 0; n < N; n++ ) {
        
        for( i = 0; i < psNLSF_CBS->nVectors; i++ ) {
            SKP_assert( rate_acc_Q5[ n ] + psNLSF_CBS->Rates_Q5[ i ] >= 0 );
            SKP_assert( rate_acc_Q5[ n ] + psNLSF_CBS->Rates_Q5[ i ] <= SKP_int16_MAX );
            pRD_vec_Q20[ i ] = SKP_SMLABB( pRD_vec_Q20[ i ], rate_acc_Q5[ n ] + psNLSF_CBS->Rates_Q5[ i ], mu_Q15 );
            SKP_assert( pRD_vec_Q20[ i ] >= 0 );
        }
        pRD_vec_Q20 += psNLSF_CBS->nVectors;
    }
}






#if (!defined(__mips__)) && (EMBEDDED_ARM < 6)


void SKP_Silk_NLSF_VQ_sum_error_FIX(
    SKP_int32                       *err_Q20,           
    const SKP_int                   *in_Q15,            
    const SKP_int                   *w_Q6,              
    const SKP_int16                 *pCB_Q15,           
    const SKP_int                   N,                  
    const SKP_int                   K,                  
    const SKP_int                   LPC_order           
)
{
    SKP_int         i, n, m;
    SKP_int32       diff_Q15, sum_error, Wtmp_Q6;
    SKP_int32       Wcpy_Q6[ MAX_LPC_ORDER / 2 ];
    const SKP_int16 *cb_vec_Q15;

    SKP_assert( LPC_order <= 16 );
    SKP_assert( ( LPC_order & 1 ) == 0 );

    
    for( m = 0; m < SKP_RSHIFT( LPC_order, 1 ); m++ ) {
        Wcpy_Q6[ m ] = w_Q6[ 2 * m ] | SKP_LSHIFT( ( SKP_int32 )w_Q6[ 2 * m + 1 ], 16 );
    }

    
    for( n = 0; n < N; n++ ) {
        
        cb_vec_Q15 = pCB_Q15;
        for( i = 0; i < K; i++ ) {
            sum_error = 0;
            for( m = 0; m < LPC_order; m += 2 ) {
                
                Wtmp_Q6 = Wcpy_Q6[ SKP_RSHIFT( m, 1 ) ];

                
                diff_Q15 = in_Q15[ m ] - *cb_vec_Q15++; 
                sum_error = SKP_SMLAWB( sum_error, SKP_SMULBB( diff_Q15, diff_Q15 ), Wtmp_Q6 );

                
                diff_Q15 = in_Q15[m + 1] - *cb_vec_Q15++; 
                sum_error = SKP_SMLAWT( sum_error, SKP_SMULBB( diff_Q15, diff_Q15 ), Wtmp_Q6 );
            }
            SKP_assert( sum_error >= 0 );
            err_Q20[ i ] = sum_error;
        }
        err_Q20 += K;
        in_Q15 += LPC_order;
    }
}

#endif









#define Q_OUT                       6
#define MIN_NDELTA                  3


void SKP_Silk_NLSF_VQ_weights_laroia(
    SKP_int             *pNLSFW_Q6,         
    const SKP_int       *pNLSF_Q15,          
    const SKP_int       D                   
)
{
    SKP_int   k;
    SKP_int32 tmp1_int, tmp2_int;
    
    
    SKP_assert( D > 0 );
    SKP_assert( ( D & 1 ) == 0 );
    
    
    tmp1_int = SKP_max_int( pNLSF_Q15[ 0 ], MIN_NDELTA );
    tmp1_int = SKP_DIV32_16( 1 << ( 15 + Q_OUT ), tmp1_int );
    tmp2_int = SKP_max_int( pNLSF_Q15[ 1 ] - pNLSF_Q15[ 0 ], MIN_NDELTA );
    tmp2_int = SKP_DIV32_16( 1 << ( 15 + Q_OUT ), tmp2_int );
    pNLSFW_Q6[ 0 ] = (SKP_int)SKP_min_int( tmp1_int + tmp2_int, SKP_int16_MAX );
    SKP_assert( pNLSFW_Q6[ 0 ] > 0 );
    
    
    for( k = 1; k < D - 1; k += 2 ) {
        tmp1_int = SKP_max_int( pNLSF_Q15[ k + 1 ] - pNLSF_Q15[ k ], MIN_NDELTA );
        tmp1_int = SKP_DIV32_16( 1 << ( 15 + Q_OUT ), tmp1_int );
        pNLSFW_Q6[ k ] = (SKP_int)SKP_min_int( tmp1_int + tmp2_int, SKP_int16_MAX );
        SKP_assert( pNLSFW_Q6[ k ] > 0 );

        tmp2_int = SKP_max_int( pNLSF_Q15[ k + 2 ] - pNLSF_Q15[ k + 1 ], MIN_NDELTA );
        tmp2_int = SKP_DIV32_16( 1 << ( 15 + Q_OUT ), tmp2_int );
        pNLSFW_Q6[ k + 1 ] = (SKP_int)SKP_min_int( tmp1_int + tmp2_int, SKP_int16_MAX );
        SKP_assert( pNLSFW_Q6[ k + 1 ] > 0 );
    }
    
    
    tmp1_int = SKP_max_int( ( 1 << 15 ) - pNLSF_Q15[ D - 1 ], MIN_NDELTA );
    tmp1_int = SKP_DIV32_16( 1 << ( 15 + Q_OUT ), tmp1_int );
    pNLSFW_Q6[ D - 1 ] = (SKP_int)SKP_min_int( tmp1_int + tmp2_int, SKP_int16_MAX );
    SKP_assert( pNLSFW_Q6[ D - 1 ] > 0 );
}















#define MAX_LOOPS        20


void SKP_Silk_NLSF_stabilize(
          SKP_int    *NLSF_Q15,            
    const SKP_int    *NDeltaMin_Q15,       
    const SKP_int     L                    
)
{
    SKP_int        center_freq_Q15, diff_Q15, min_center_Q15, max_center_Q15;
    SKP_int32    min_diff_Q15;
    SKP_int        loops;
    SKP_int        i, I=0, k;

    
    SKP_assert( NDeltaMin_Q15[L] >= 1 );

    for( loops = 0; loops < MAX_LOOPS; loops++ ) {
        
        
        
        
        min_diff_Q15 = NLSF_Q15[0] - NDeltaMin_Q15[0];
        I = 0;
        
        for( i = 1; i <= L-1; i++ ) {
            diff_Q15 = NLSF_Q15[i] - ( NLSF_Q15[i-1] + NDeltaMin_Q15[i] );
            if( diff_Q15 < min_diff_Q15 ) {
                min_diff_Q15 = diff_Q15;
                I = i;
            }
        }
        
        diff_Q15 = (1<<15) - ( NLSF_Q15[L-1] + NDeltaMin_Q15[L] );
        if( diff_Q15 < min_diff_Q15 ) {
            min_diff_Q15 = diff_Q15;
            I = L;
        }

        
        
        
        if (min_diff_Q15 >= 0) {
            return;
        }

        if( I == 0 ) {
            
            NLSF_Q15[0] = NDeltaMin_Q15[0];
        
        } else if( I == L) {
            
            NLSF_Q15[L-1] = (1<<15) - NDeltaMin_Q15[L];
        
        } else {
             
            min_center_Q15 = 0;
            for( k = 0; k < I; k++ ) {
                min_center_Q15 += NDeltaMin_Q15[k];
            }
            min_center_Q15 += SKP_RSHIFT( NDeltaMin_Q15[I], 1 );

            
            max_center_Q15 = (1<<15);
            for( k = L; k > I; k-- ) {
                max_center_Q15 -= NDeltaMin_Q15[k];
            }
            max_center_Q15 -= ( NDeltaMin_Q15[I] - SKP_RSHIFT( NDeltaMin_Q15[I], 1 ) );

            
            center_freq_Q15 = SKP_LIMIT_32( SKP_RSHIFT_ROUND( (SKP_int32)NLSF_Q15[I-1] + (SKP_int32)NLSF_Q15[I], 1 ),
                min_center_Q15, max_center_Q15 );
            NLSF_Q15[I-1] = center_freq_Q15 - SKP_RSHIFT( NDeltaMin_Q15[I], 1 );
            NLSF_Q15[I] = NLSF_Q15[I-1] + NDeltaMin_Q15[I];
        }
    }

    
    if( loops == MAX_LOOPS )
    {
        
        
        
        SKP_Silk_insertion_sort_increasing_all_values(&NLSF_Q15[0], L);
            
        
        NLSF_Q15[0] = SKP_max_int( NLSF_Q15[0], NDeltaMin_Q15[0] );
        
        
        for( i = 1; i < L; i++ )
            NLSF_Q15[i] = SKP_max_int( NLSF_Q15[i], NLSF_Q15[i-1] + NDeltaMin_Q15[i] );

        
        NLSF_Q15[L-1] = SKP_min_int( NLSF_Q15[L-1], (1<<15) - NDeltaMin_Q15[L] );

        
        for( i = L-2; i >= 0; i-- ) 
            NLSF_Q15[i] = SKP_min_int( NLSF_Q15[i], NLSF_Q15[i+1] - NDeltaMin_Q15[i+1] );
    }
}







SKP_INLINE void SKP_Silk_nsq_scale_states(
    SKP_Silk_nsq_state  *NSQ,               
    const SKP_int16     x[],                
    SKP_int32           x_sc_Q10[],         
    SKP_int             subfr_length,       
    const SKP_int16     sLTP[],             
    SKP_int32           sLTP_Q16[],         
    SKP_int             subfr,              
    const SKP_int       LTP_scale_Q14,      
    const SKP_int32     Gains_Q16[ NB_SUBFR ], 
    const SKP_int       pitchL[ NB_SUBFR ]  
);

SKP_INLINE void SKP_Silk_noise_shape_quantizer(
    SKP_Silk_nsq_state  *NSQ,               
    SKP_int             sigtype,            
    const SKP_int32     x_sc_Q10[],         
    SKP_int8            q[],                
    SKP_int16           xq[],               
    SKP_int32           sLTP_Q16[],         
    const SKP_int16     a_Q12[],            
    const SKP_int16     b_Q14[],            
    const SKP_int16     AR_shp_Q13[],       
    SKP_int             lag,                
    SKP_int32           HarmShapeFIRPacked_Q14, 
    SKP_int             Tilt_Q14,           
    SKP_int32           LF_shp_Q14,         
    SKP_int32           Gain_Q16,           
    SKP_int             Lambda_Q10,         
    SKP_int             offset_Q10,         
    SKP_int             length,             
    SKP_int             shapingLPCOrder,    
    SKP_int             predictLPCOrder     
);

void SKP_Silk_NSQ(
    SKP_Silk_encoder_state          *psEncC,                                    
    SKP_Silk_encoder_control        *psEncCtrlC,                                
    SKP_Silk_nsq_state              *NSQ,                                       
    const SKP_int16                 x[],                                        
    SKP_int8                        q[],                                        
    const SKP_int                   LSFInterpFactor_Q2,                         
    const SKP_int16                 PredCoef_Q12[ 2 * MAX_LPC_ORDER ],          
    const SKP_int16                 LTPCoef_Q14[ LTP_ORDER * NB_SUBFR ],        
    const SKP_int16                 AR2_Q13[ NB_SUBFR * MAX_SHAPE_LPC_ORDER ],  
    const SKP_int                   HarmShapeGain_Q14[ NB_SUBFR ],              
    const SKP_int                   Tilt_Q14[ NB_SUBFR ],                       
    const SKP_int32                 LF_shp_Q14[ NB_SUBFR ],                     
    const SKP_int32                 Gains_Q16[ NB_SUBFR ],                      
    const SKP_int                   Lambda_Q10,                                 
    const SKP_int                   LTP_scale_Q14                               
)
{
    SKP_int     k, lag, start_idx, LSF_interpolation_flag;
    const SKP_int16 *A_Q12, *B_Q14, *AR_shp_Q13;
    SKP_int16   *pxq;
    SKP_int32   sLTP_Q16[ 2 * MAX_FRAME_LENGTH ];
    SKP_int16   sLTP[     2 * MAX_FRAME_LENGTH ];
    SKP_int32   HarmShapeFIRPacked_Q14;
    SKP_int     offset_Q10;
    SKP_int32   FiltState[ MAX_LPC_ORDER ];
    SKP_int32   x_sc_Q10[ MAX_FRAME_LENGTH / NB_SUBFR ];

    NSQ->rand_seed  =  psEncCtrlC->Seed;
    
    lag             = NSQ->lagPrev;

    SKP_assert( NSQ->prev_inv_gain_Q16 != 0 );

    offset_Q10 = SKP_Silk_Quantization_Offsets_Q10[ psEncCtrlC->sigtype ][ psEncCtrlC->QuantOffsetType ];

    if( LSFInterpFactor_Q2 == ( 1 << 2 ) ) {
        LSF_interpolation_flag = 0;
    } else {
        LSF_interpolation_flag = 1;
    }

    
    NSQ->sLTP_shp_buf_idx = psEncC->frame_length;
    NSQ->sLTP_buf_idx     = psEncC->frame_length;
    pxq                   = &NSQ->xq[ psEncC->frame_length ];
    for( k = 0; k < NB_SUBFR; k++ ) {
        A_Q12      = &PredCoef_Q12[ (( k >> 1 ) | ( 1 - LSF_interpolation_flag )) * MAX_LPC_ORDER ];
        B_Q14      = &LTPCoef_Q14[ k * LTP_ORDER ];
        AR_shp_Q13 = &AR2_Q13[     k * MAX_SHAPE_LPC_ORDER ];

        
        SKP_assert( HarmShapeGain_Q14[ k ] >= 0 );
        HarmShapeFIRPacked_Q14  =                          SKP_RSHIFT( HarmShapeGain_Q14[ k ], 2 );
        HarmShapeFIRPacked_Q14 |= SKP_LSHIFT( ( SKP_int32 )SKP_RSHIFT( HarmShapeGain_Q14[ k ], 1 ), 16 );

        NSQ->rewhite_flag = 0;
        if( psEncCtrlC->sigtype == SIG_TYPE_VOICED ) {
            
            lag = psEncCtrlC->pitchL[ k ];

            
            if( ( k & ( 3 - SKP_LSHIFT( LSF_interpolation_flag, 1 ) ) ) == 0 ) {

                
                start_idx = psEncC->frame_length - lag - psEncC->predictLPCOrder - LTP_ORDER / 2;
                SKP_assert( start_idx >= 0 );
                SKP_assert( start_idx <= psEncC->frame_length - psEncC->predictLPCOrder );

                SKP_memset( FiltState, 0, psEncC->predictLPCOrder * sizeof( SKP_int32 ) );
                SKP_Silk_MA_Prediction( &NSQ->xq[ start_idx + k * ( psEncC->frame_length >> 2 ) ], 
                    A_Q12, FiltState, sLTP + start_idx, psEncC->frame_length - start_idx, psEncC->predictLPCOrder );

                NSQ->rewhite_flag = 1;
                NSQ->sLTP_buf_idx = psEncC->frame_length;
            }
        }
        
        SKP_Silk_nsq_scale_states( NSQ, x, x_sc_Q10, psEncC->subfr_length, sLTP, 
            sLTP_Q16, k, LTP_scale_Q14, Gains_Q16, psEncCtrlC->pitchL );

        SKP_Silk_noise_shape_quantizer( NSQ, psEncCtrlC->sigtype, x_sc_Q10, q, pxq, sLTP_Q16, A_Q12, B_Q14, 
            AR_shp_Q13, lag, HarmShapeFIRPacked_Q14, Tilt_Q14[ k ], LF_shp_Q14[ k ], Gains_Q16[ k ], Lambda_Q10, 
            offset_Q10, psEncC->subfr_length, psEncC->shapingLPCOrder, psEncC->predictLPCOrder
        );

        x          += psEncC->subfr_length;
        q          += psEncC->subfr_length;
        pxq        += psEncC->subfr_length;
    }

    
    NSQ->lagPrev = psEncCtrlC->pitchL[ NB_SUBFR - 1 ];

    
    SKP_memcpy( NSQ->xq,           &NSQ->xq[           psEncC->frame_length ], psEncC->frame_length * sizeof( SKP_int16 ) );
    SKP_memcpy( NSQ->sLTP_shp_Q10, &NSQ->sLTP_shp_Q10[ psEncC->frame_length ], psEncC->frame_length * sizeof( SKP_int32 ) );

#ifdef USE_UNQUANTIZED_LSFS
    DEBUG_STORE_DATA( xq_unq_lsfs.pcm, NSQ->xq, psEncC->frame_length * sizeof( SKP_int16 ) );
#endif

}




SKP_INLINE void SKP_Silk_noise_shape_quantizer(
    SKP_Silk_nsq_state  *NSQ,               
    SKP_int             sigtype,            
    const SKP_int32     x_sc_Q10[],         
    SKP_int8            q[],                
    SKP_int16           xq[],               
    SKP_int32           sLTP_Q16[],         
    const SKP_int16     a_Q12[],            
    const SKP_int16     b_Q14[],            
    const SKP_int16     AR_shp_Q13[],       
    SKP_int             lag,                
    SKP_int32           HarmShapeFIRPacked_Q14, 
    SKP_int             Tilt_Q14,           
    SKP_int32           LF_shp_Q14,         
    SKP_int32           Gain_Q16,           
    SKP_int             Lambda_Q10,         
    SKP_int             offset_Q10,         
    SKP_int             length,             
    SKP_int             shapingLPCOrder,    
    SKP_int             predictLPCOrder     
)
{
    SKP_int     i, j;
    SKP_int32   LTP_pred_Q14, LPC_pred_Q10, n_AR_Q10, n_LTP_Q14;
    SKP_int32   n_LF_Q10, r_Q10, q_Q0, q_Q10;
    SKP_int32   thr1_Q10, thr2_Q10, thr3_Q10;
    SKP_int32   dither, exc_Q10, LPC_exc_Q10, xq_Q10;
    SKP_int32   tmp1, tmp2, sLF_AR_shp_Q10;
    SKP_int32   *psLPC_Q14, *shp_lag_ptr, *pred_lag_ptr;
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
    SKP_int32   a_Q12_tmp[ MAX_LPC_ORDER / 2 ], Atmp;
    
    SKP_memcpy( a_Q12_tmp, a_Q12, predictLPCOrder * sizeof( SKP_int16 ) );
#endif

    shp_lag_ptr  = &NSQ->sLTP_shp_Q10[ NSQ->sLTP_shp_buf_idx - lag + HARM_SHAPE_FIR_TAPS / 2 ];
    pred_lag_ptr = &sLTP_Q16[ NSQ->sLTP_buf_idx - lag + LTP_ORDER / 2 ];
    
    
    psLPC_Q14 = &NSQ->sLPC_Q14[ NSQ_LPC_BUF_LENGTH - 1 ];

    
    thr1_Q10 = SKP_SUB_RSHIFT32( -1536, Lambda_Q10, 1 );
    thr2_Q10 = SKP_SUB_RSHIFT32(  -512, Lambda_Q10, 1 );
    thr2_Q10 = SKP_ADD_RSHIFT32( thr2_Q10, SKP_SMULBB( offset_Q10, Lambda_Q10 ), 10 );
    thr3_Q10 = SKP_ADD_RSHIFT32(   512, Lambda_Q10, 1 );

    for( i = 0; i < length; i++ ) {
        
        NSQ->rand_seed = SKP_RAND( NSQ->rand_seed );

        
        dither = SKP_RSHIFT( NSQ->rand_seed, 31 );
                
        
        SKP_assert( ( predictLPCOrder  & 1 ) == 0 );    
        
        SKP_assert( ( ( SKP_int64 )( ( SKP_int8* )a_Q12 - ( SKP_int8* )0 ) & 3 ) == 0 );
        SKP_assert( predictLPCOrder >= 10 );            
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
        
        
        
        
        
        Atmp = a_Q12_tmp[ 0 ];      
        LPC_pred_Q10 = SKP_SMULWB(               psLPC_Q14[  0 ], Atmp );
        LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -1 ], Atmp );
        Atmp = a_Q12_tmp[ 1 ];
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -2 ], Atmp );
        LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -3 ], Atmp );
        Atmp = a_Q12_tmp[ 2 ];
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -4 ], Atmp );
        LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -5 ], Atmp );
        Atmp = a_Q12_tmp[ 3 ];
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -6 ], Atmp );
        LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -7 ], Atmp );
        Atmp = a_Q12_tmp[ 4 ];
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -8 ], Atmp );
        LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -9 ], Atmp );
        for( j = 10; j < predictLPCOrder; j += 2 ) {
            Atmp = a_Q12_tmp[ j >> 1 ];     
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -j     ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -j - 1 ], Atmp );
        }
#else
        
        LPC_pred_Q10 = SKP_SMULWB(               psLPC_Q14[  0 ], a_Q12[ 0 ] );
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -1 ], a_Q12[ 1 ] );
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -2 ], a_Q12[ 2 ] );
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -3 ], a_Q12[ 3 ] );
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -4 ], a_Q12[ 4 ] );
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -5 ], a_Q12[ 5 ] );
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -6 ], a_Q12[ 6 ] );
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -7 ], a_Q12[ 7 ] );
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -8 ], a_Q12[ 8 ] );
        LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -9 ], a_Q12[ 9 ] );
        for( j = 10; j < predictLPCOrder; j ++ ) {
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -j ], a_Q12[ j ] );
        }
#endif
        
        if( sigtype == SIG_TYPE_VOICED ) {
            
            LTP_pred_Q14 = SKP_SMULWB(               pred_lag_ptr[  0 ], b_Q14[ 0 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -1 ], b_Q14[ 1 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -2 ], b_Q14[ 2 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -3 ], b_Q14[ 3 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -4 ], b_Q14[ 4 ] );
            pred_lag_ptr++;
        } else {
            LTP_pred_Q14 = 0;
        }

        
        SKP_assert( ( shapingLPCOrder & 1 ) == 0 );   
        tmp2 = psLPC_Q14[ 0 ];
        tmp1 = NSQ->sAR2_Q14[ 0 ];
        NSQ->sAR2_Q14[ 0 ] = tmp2;
        n_AR_Q10 = SKP_SMULWB( tmp2, AR_shp_Q13[ 0 ] );
        for( j = 2; j < shapingLPCOrder; j += 2 ) {
            tmp2 = NSQ->sAR2_Q14[ j - 1 ];
            NSQ->sAR2_Q14[ j - 1 ] = tmp1;
            n_AR_Q10 = SKP_SMLAWB( n_AR_Q10, tmp1, AR_shp_Q13[ j - 1 ] );
            tmp1 = NSQ->sAR2_Q14[ j + 0 ];
            NSQ->sAR2_Q14[ j + 0 ] = tmp2;
            n_AR_Q10 = SKP_SMLAWB( n_AR_Q10, tmp2, AR_shp_Q13[ j ] );
        }
        NSQ->sAR2_Q14[ shapingLPCOrder - 1 ] = tmp1;
        n_AR_Q10 = SKP_SMLAWB( n_AR_Q10, tmp1, AR_shp_Q13[ shapingLPCOrder - 1 ] );

        n_AR_Q10 = SKP_RSHIFT( n_AR_Q10, 1 );   
        n_AR_Q10 = SKP_SMLAWB( n_AR_Q10, NSQ->sLF_AR_shp_Q12, Tilt_Q14 );

        n_LF_Q10 = SKP_LSHIFT( SKP_SMULWB( NSQ->sLTP_shp_Q10[ NSQ->sLTP_shp_buf_idx - 1 ], LF_shp_Q14 ), 2 ); 
        n_LF_Q10 = SKP_SMLAWT( n_LF_Q10, NSQ->sLF_AR_shp_Q12, LF_shp_Q14 );

        SKP_assert( lag > 0 || sigtype == SIG_TYPE_UNVOICED );

        
        if( lag > 0 ) {
            
            n_LTP_Q14 = SKP_SMULWB( SKP_ADD32( shp_lag_ptr[ 0 ], shp_lag_ptr[ -2 ] ), HarmShapeFIRPacked_Q14 );
            n_LTP_Q14 = SKP_SMLAWT( n_LTP_Q14, shp_lag_ptr[ -1 ],                     HarmShapeFIRPacked_Q14 );
            n_LTP_Q14 = SKP_LSHIFT( n_LTP_Q14, 6 );
            shp_lag_ptr++;
        } else {
            n_LTP_Q14 = 0;
        }

        
        
        tmp1  = SKP_SUB32( LTP_pred_Q14, n_LTP_Q14 );                       
        tmp1  = SKP_RSHIFT( tmp1, 4 );                                      
        tmp1  = SKP_ADD32( tmp1, LPC_pred_Q10 );                             
        tmp1  = SKP_SUB32( tmp1, n_AR_Q10 );                                 
        tmp1  = SKP_SUB32( tmp1, n_LF_Q10 );                                 
        r_Q10 = SKP_SUB32( x_sc_Q10[ i ], tmp1 );

        
        r_Q10 = ( r_Q10 ^ dither ) - dither;
        r_Q10 = SKP_SUB32( r_Q10, offset_Q10 );
        r_Q10 = SKP_LIMIT_32( r_Q10, -(64 << 10), 64 << 10 );

        
        q_Q0 = 0;
        q_Q10 = 0;
        if( r_Q10 < thr2_Q10 ) {
            if( r_Q10 < thr1_Q10 ) {
                q_Q0 = SKP_RSHIFT_ROUND( SKP_ADD_RSHIFT32( r_Q10, Lambda_Q10, 1 ), 10 );
                q_Q10 = SKP_LSHIFT( q_Q0, 10 );
            } else {
                q_Q0 = -1;
                q_Q10 = -1024;
            }
        } else {
            if( r_Q10 > thr3_Q10 ) {
                q_Q0 = SKP_RSHIFT_ROUND( SKP_SUB_RSHIFT32( r_Q10, Lambda_Q10, 1 ), 10 );
                q_Q10 = SKP_LSHIFT( q_Q0, 10 );
            }
        }
        q[ i ] = ( SKP_int8 )q_Q0; 

        
        exc_Q10 = SKP_ADD32( q_Q10, offset_Q10 );
        exc_Q10 = ( exc_Q10 ^ dither ) - dither;

        
        LPC_exc_Q10 = SKP_ADD32( exc_Q10, SKP_RSHIFT_ROUND( LTP_pred_Q14, 4 ) );
        xq_Q10      = SKP_ADD32( LPC_exc_Q10, LPC_pred_Q10 );
        
        
        xq[ i ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( SKP_SMULWW( xq_Q10, Gain_Q16 ), 10 ) );
        
        
        
        psLPC_Q14++;
        *psLPC_Q14 = SKP_LSHIFT( xq_Q10, 4 );
        sLF_AR_shp_Q10 = SKP_SUB32( xq_Q10, n_AR_Q10 );
        NSQ->sLF_AR_shp_Q12 = SKP_LSHIFT( sLF_AR_shp_Q10, 2 );

        NSQ->sLTP_shp_Q10[ NSQ->sLTP_shp_buf_idx ] = SKP_SUB32( sLF_AR_shp_Q10, n_LF_Q10 );
        sLTP_Q16[ NSQ->sLTP_buf_idx ] = SKP_LSHIFT( LPC_exc_Q10, 6 );
        NSQ->sLTP_shp_buf_idx++;
        NSQ->sLTP_buf_idx++;

        
        NSQ->rand_seed += q[ i ];
    }

    
    SKP_memcpy( NSQ->sLPC_Q14, &NSQ->sLPC_Q14[ length ], NSQ_LPC_BUF_LENGTH * sizeof( SKP_int32 ) );
}

SKP_INLINE void SKP_Silk_nsq_scale_states(
    SKP_Silk_nsq_state  *NSQ,               
    const SKP_int16     x[],                
    SKP_int32           x_sc_Q10[],         
    SKP_int             subfr_length,       
    const SKP_int16     sLTP[],             
    SKP_int32           sLTP_Q16[],         
    SKP_int             subfr,              
    const SKP_int       LTP_scale_Q14,      
    const SKP_int32     Gains_Q16[ NB_SUBFR ], 
    const SKP_int       pitchL[ NB_SUBFR ]  
)
{
    SKP_int   i, lag;
    SKP_int32 inv_gain_Q16, gain_adj_Q16, inv_gain_Q32;

    inv_gain_Q16 = SKP_INVERSE32_varQ( SKP_max( Gains_Q16[ subfr ], 1 ), 32 );
    inv_gain_Q16 = SKP_min( inv_gain_Q16, SKP_int16_MAX );
    lag          = pitchL[ subfr ];

    
    if( NSQ->rewhite_flag ) {
        inv_gain_Q32 = SKP_LSHIFT( inv_gain_Q16, 16 );
        if( subfr == 0 ) {
            
            inv_gain_Q32 = SKP_LSHIFT( SKP_SMULWB( inv_gain_Q32, LTP_scale_Q14 ), 2 );
        }
        for( i = NSQ->sLTP_buf_idx - lag - LTP_ORDER / 2; i < NSQ->sLTP_buf_idx; i++ ) {
            SKP_assert( i < MAX_FRAME_LENGTH );
            sLTP_Q16[ i ] = SKP_SMULWB( inv_gain_Q32, sLTP[ i ] );
        }
    }

    
    if( inv_gain_Q16 != NSQ->prev_inv_gain_Q16 ) {
        gain_adj_Q16 = SKP_DIV32_varQ( inv_gain_Q16, NSQ->prev_inv_gain_Q16, 16 );

        
        for( i = NSQ->sLTP_shp_buf_idx - subfr_length * NB_SUBFR; i < NSQ->sLTP_shp_buf_idx; i++ ) {
            NSQ->sLTP_shp_Q10[ i ] = SKP_SMULWW( gain_adj_Q16, NSQ->sLTP_shp_Q10[ i ] );
        }

        
        if( NSQ->rewhite_flag == 0 ) {
            for( i = NSQ->sLTP_buf_idx - lag - LTP_ORDER / 2; i < NSQ->sLTP_buf_idx; i++ ) {
                sLTP_Q16[ i ] = SKP_SMULWW( gain_adj_Q16, sLTP_Q16[ i ] );
            }
        }

        NSQ->sLF_AR_shp_Q12 = SKP_SMULWW( gain_adj_Q16, NSQ->sLF_AR_shp_Q12 );

        
        for( i = 0; i < NSQ_LPC_BUF_LENGTH; i++ ) {
            NSQ->sLPC_Q14[ i ] = SKP_SMULWW( gain_adj_Q16, NSQ->sLPC_Q14[ i ] );
        }
        for( i = 0; i < MAX_SHAPE_LPC_ORDER; i++ ) {
            NSQ->sAR2_Q14[ i ] = SKP_SMULWW( gain_adj_Q16, NSQ->sAR2_Q14[ i ] );
        }
    }

    
    for( i = 0; i < subfr_length; i++ ) {
        x_sc_Q10[ i ] = SKP_RSHIFT( SKP_SMULBB( x[ i ], ( SKP_int16 )inv_gain_Q16 ), 6 );
    }

    
    SKP_assert( inv_gain_Q16 != 0 );
    NSQ->prev_inv_gain_Q16 = inv_gain_Q16;
}






typedef struct {
    SKP_int32 RandState[ DECISION_DELAY ];
    SKP_int32 Q_Q10[     DECISION_DELAY ];
    SKP_int32 Xq_Q10[    DECISION_DELAY ];
    SKP_int32 Pred_Q16[  DECISION_DELAY ];
    SKP_int32 Shape_Q10[ DECISION_DELAY ];
    SKP_int32 Gain_Q16[  DECISION_DELAY ];
    SKP_int32 sAR2_Q14[ MAX_SHAPE_LPC_ORDER ];
    SKP_int32 sLPC_Q14[ MAX_FRAME_LENGTH / NB_SUBFR + NSQ_LPC_BUF_LENGTH ];
    SKP_int32 LF_AR_Q12;
    SKP_int32 Seed;
    SKP_int32 SeedInit;
    SKP_int32 RD_Q10;
} NSQ_del_dec_struct;

typedef struct {
    SKP_int32 Q_Q10;
    SKP_int32 RD_Q10;
    SKP_int32 xq_Q14;
    SKP_int32 LF_AR_Q12;
    SKP_int32 sLTP_shp_Q10;
    SKP_int32 LPC_exc_Q16;
} NSQ_sample_struct;

SKP_INLINE void SKP_Silk_copy_del_dec_state(
    NSQ_del_dec_struct  *DD_dst,                
    NSQ_del_dec_struct  *DD_src,                
    SKP_int             LPC_state_idx           
);

SKP_INLINE void SKP_Silk_nsq_del_dec_scale_states(
    SKP_Silk_nsq_state  *NSQ,                   
    NSQ_del_dec_struct  psDelDec[],             
    const SKP_int16     x[],                    
    SKP_int32           x_sc_Q10[],             
    SKP_int             subfr_length,           
    const SKP_int16     sLTP[],                 
    SKP_int32           sLTP_Q16[],             
    SKP_int             subfr,                  
    SKP_int             nStatesDelayedDecision, 
    SKP_int             smpl_buf_idx,           
    const SKP_int       LTP_scale_Q14,          
    const SKP_int32     Gains_Q16[ NB_SUBFR ],  
    const SKP_int       pitchL[ NB_SUBFR ]      
);




SKP_INLINE void SKP_Silk_noise_shape_quantizer_del_dec(
    SKP_Silk_nsq_state  *NSQ,                   
    NSQ_del_dec_struct  psDelDec[],             
    SKP_int             sigtype,                
    const SKP_int32     x_Q10[],                
    SKP_int8            q[],                    
    SKP_int16           xq[],                   
    SKP_int32           sLTP_Q16[],             
    const SKP_int16     a_Q12[],                
    const SKP_int16     b_Q14[],                
    const SKP_int16     AR_shp_Q13[],           
    SKP_int             lag,                    
    SKP_int32           HarmShapeFIRPacked_Q14, 
    SKP_int             Tilt_Q14,               
    SKP_int32           LF_shp_Q14,             
    SKP_int32           Gain_Q16,               
    SKP_int             Lambda_Q10,             
    SKP_int             offset_Q10,             
    SKP_int             length,                 
    SKP_int             subfr,                  
    SKP_int             shapingLPCOrder,        
    SKP_int             predictLPCOrder,        
    SKP_int             warping_Q16,            
    SKP_int             nStatesDelayedDecision, 
    SKP_int             *smpl_buf_idx,          
    SKP_int             decisionDelay           
);

void SKP_Silk_NSQ_del_dec(
    SKP_Silk_encoder_state          *psEncC,                                    
    SKP_Silk_encoder_control        *psEncCtrlC,                                
    SKP_Silk_nsq_state              *NSQ,                                       
    const SKP_int16                 x[],                                        
    SKP_int8                        q[],                                        
    const SKP_int                   LSFInterpFactor_Q2,                         
    const SKP_int16                 PredCoef_Q12[ 2 * MAX_LPC_ORDER ],          
    const SKP_int16                 LTPCoef_Q14[ LTP_ORDER * NB_SUBFR ],        
    const SKP_int16                 AR2_Q13[ NB_SUBFR * MAX_SHAPE_LPC_ORDER ],  
    const SKP_int                   HarmShapeGain_Q14[ NB_SUBFR ],              
    const SKP_int                   Tilt_Q14[ NB_SUBFR ],                       
    const SKP_int32                 LF_shp_Q14[ NB_SUBFR ],                     
    const SKP_int32                 Gains_Q16[ NB_SUBFR ],                      
    const SKP_int                   Lambda_Q10,                                 
    const SKP_int                   LTP_scale_Q14                               
)
{
    SKP_int     i, k, lag, start_idx, LSF_interpolation_flag, Winner_ind, subfr;
    SKP_int     last_smple_idx, smpl_buf_idx, decisionDelay, subfr_length;
    const SKP_int16 *A_Q12, *B_Q14, *AR_shp_Q13;
    SKP_int16   *pxq;
    SKP_int32   sLTP_Q16[ 2 * MAX_FRAME_LENGTH ];
    SKP_int16   sLTP[     2 * MAX_FRAME_LENGTH ];
    SKP_int32   HarmShapeFIRPacked_Q14;
    SKP_int     offset_Q10;
    SKP_int32   FiltState[ MAX_LPC_ORDER ], RDmin_Q10;
    SKP_int32   x_sc_Q10[ MAX_FRAME_LENGTH / NB_SUBFR ];
    NSQ_del_dec_struct psDelDec[ MAX_DEL_DEC_STATES ];
    NSQ_del_dec_struct *psDD;

    subfr_length = psEncC->frame_length / NB_SUBFR;

    
    lag = NSQ->lagPrev;

    SKP_assert( NSQ->prev_inv_gain_Q16 != 0 );

    
    SKP_memset( psDelDec, 0, psEncC->nStatesDelayedDecision * sizeof( NSQ_del_dec_struct ) );
    for( k = 0; k < psEncC->nStatesDelayedDecision; k++ ) {
        psDD                 = &psDelDec[ k ];
        psDD->Seed           = ( k + psEncCtrlC->Seed ) & 3;
        psDD->SeedInit       = psDD->Seed;
        psDD->RD_Q10         = 0;
        psDD->LF_AR_Q12      = NSQ->sLF_AR_shp_Q12;
        psDD->Shape_Q10[ 0 ] = NSQ->sLTP_shp_Q10[ psEncC->frame_length - 1 ];
        SKP_memcpy( psDD->sLPC_Q14, NSQ->sLPC_Q14, NSQ_LPC_BUF_LENGTH * sizeof( SKP_int32 ) );
        SKP_memcpy( psDD->sAR2_Q14, NSQ->sAR2_Q14, sizeof( NSQ->sAR2_Q14 ) );
    }

    offset_Q10   = SKP_Silk_Quantization_Offsets_Q10[ psEncCtrlC->sigtype ][ psEncCtrlC->QuantOffsetType ];
    smpl_buf_idx = 0; 

    decisionDelay = SKP_min_int( DECISION_DELAY, subfr_length );

    
    if( psEncCtrlC->sigtype == SIG_TYPE_VOICED ) {
        for( k = 0; k < NB_SUBFR; k++ ) {
            decisionDelay = SKP_min_int( decisionDelay, psEncCtrlC->pitchL[ k ] - LTP_ORDER / 2 - 1 );
        }
    } else {
        if( lag > 0 ) {
            decisionDelay = SKP_min_int( decisionDelay, lag - LTP_ORDER / 2 - 1 );
        }
    }

    if( LSFInterpFactor_Q2 == ( 1 << 2 ) ) {
        LSF_interpolation_flag = 0;
    } else {
        LSF_interpolation_flag = 1;
    }

    
    pxq                   = &NSQ->xq[ psEncC->frame_length ];
    NSQ->sLTP_shp_buf_idx = psEncC->frame_length;
    NSQ->sLTP_buf_idx     = psEncC->frame_length;
    subfr = 0;
    for( k = 0; k < NB_SUBFR; k++ ) {
        A_Q12      = &PredCoef_Q12[ ( ( k >> 1 ) | ( 1 - LSF_interpolation_flag ) ) * MAX_LPC_ORDER ];
        B_Q14      = &LTPCoef_Q14[ k * LTP_ORDER           ];
        AR_shp_Q13 = &AR2_Q13[     k * MAX_SHAPE_LPC_ORDER ];

        
        SKP_assert( HarmShapeGain_Q14[ k ] >= 0 );
        HarmShapeFIRPacked_Q14  =                          SKP_RSHIFT( HarmShapeGain_Q14[ k ], 2 );
        HarmShapeFIRPacked_Q14 |= SKP_LSHIFT( ( SKP_int32 )SKP_RSHIFT( HarmShapeGain_Q14[ k ], 1 ), 16 );

        NSQ->rewhite_flag = 0;
        if( psEncCtrlC->sigtype == SIG_TYPE_VOICED ) {
            
            lag = psEncCtrlC->pitchL[ k ];

            
            if( ( k & ( 3 - SKP_LSHIFT( LSF_interpolation_flag, 1 ) ) ) == 0 ) {
                if( k == 2 ) {
                    
                    
                    RDmin_Q10 = psDelDec[ 0 ].RD_Q10;
                    Winner_ind = 0;
                    for( i = 1; i < psEncC->nStatesDelayedDecision; i++ ) {
                        if( psDelDec[ i ].RD_Q10 < RDmin_Q10 ) {
                            RDmin_Q10 = psDelDec[ i ].RD_Q10;
                            Winner_ind = i;
                        }
                    }
                    for( i = 0; i < psEncC->nStatesDelayedDecision; i++ ) {
                        if( i != Winner_ind ) {
                            psDelDec[ i ].RD_Q10 += ( SKP_int32_MAX >> 4 );
                            SKP_assert( psDelDec[ i ].RD_Q10 >= 0 );
                        }
                    }
                    
                    
                    psDD = &psDelDec[ Winner_ind ];
                    last_smple_idx = smpl_buf_idx + decisionDelay;
                    for( i = 0; i < decisionDelay; i++ ) {
                        last_smple_idx = ( last_smple_idx - 1 ) & DECISION_DELAY_MASK;
                        q[   i - decisionDelay ] = ( SKP_int8 )SKP_RSHIFT( psDD->Q_Q10[ last_smple_idx ], 10 );
                        pxq[ i - decisionDelay ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( 
                            SKP_SMULWW( psDD->Xq_Q10[ last_smple_idx ], 
                            psDD->Gain_Q16[ last_smple_idx ] ), 10 ) );
                        NSQ->sLTP_shp_Q10[ NSQ->sLTP_shp_buf_idx - decisionDelay + i ] = psDD->Shape_Q10[ last_smple_idx ];
                    }

                    subfr = 0;
                }

                
                start_idx = psEncC->frame_length - lag - psEncC->predictLPCOrder - LTP_ORDER / 2;
                SKP_assert( start_idx >= 0 );
                SKP_assert( start_idx <= psEncC->frame_length - psEncC->predictLPCOrder );

                SKP_memset( FiltState, 0, psEncC->predictLPCOrder * sizeof( SKP_int32 ) );
                SKP_Silk_MA_Prediction( &NSQ->xq[ start_idx + k * psEncC->subfr_length ], 
                    A_Q12, FiltState, sLTP + start_idx, psEncC->frame_length - start_idx, psEncC->predictLPCOrder );

                NSQ->sLTP_buf_idx = psEncC->frame_length;
                NSQ->rewhite_flag = 1;
            }
        }

        SKP_Silk_nsq_del_dec_scale_states( NSQ, psDelDec, x, x_sc_Q10, 
            subfr_length, sLTP, sLTP_Q16, k, psEncC->nStatesDelayedDecision, smpl_buf_idx,
            LTP_scale_Q14, Gains_Q16, psEncCtrlC->pitchL );

        SKP_Silk_noise_shape_quantizer_del_dec( NSQ, psDelDec, psEncCtrlC->sigtype, x_sc_Q10, q, pxq, sLTP_Q16,
            A_Q12, B_Q14, AR_shp_Q13, lag, HarmShapeFIRPacked_Q14, Tilt_Q14[ k ], LF_shp_Q14[ k ], Gains_Q16[ k ], 
            Lambda_Q10, offset_Q10, psEncC->subfr_length, subfr++, psEncC->shapingLPCOrder, psEncC->predictLPCOrder, 
            psEncC->warping_Q16, psEncC->nStatesDelayedDecision, &smpl_buf_idx, decisionDelay );
        
        x   += psEncC->subfr_length;
        q   += psEncC->subfr_length;
        pxq += psEncC->subfr_length;
    }

    
    RDmin_Q10 = psDelDec[ 0 ].RD_Q10;
    Winner_ind = 0;
    for( k = 1; k < psEncC->nStatesDelayedDecision; k++ ) {
        if( psDelDec[ k ].RD_Q10 < RDmin_Q10 ) {
            RDmin_Q10 = psDelDec[ k ].RD_Q10;
            Winner_ind = k;
        }
    }
    
    
    psDD = &psDelDec[ Winner_ind ];
    psEncCtrlC->Seed = psDD->SeedInit;
    last_smple_idx = smpl_buf_idx + decisionDelay;
    for( i = 0; i < decisionDelay; i++ ) {
        last_smple_idx = ( last_smple_idx - 1 ) & DECISION_DELAY_MASK;
        q[   i - decisionDelay ] = ( SKP_int8 )SKP_RSHIFT( psDD->Q_Q10[ last_smple_idx ], 10 );
        pxq[ i - decisionDelay ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( 
            SKP_SMULWW( psDD->Xq_Q10[ last_smple_idx ], psDD->Gain_Q16[ last_smple_idx ] ), 10 ) );
        NSQ->sLTP_shp_Q10[ NSQ->sLTP_shp_buf_idx - decisionDelay + i ] = psDD->Shape_Q10[ last_smple_idx ];
        sLTP_Q16[          NSQ->sLTP_buf_idx     - decisionDelay + i ] = psDD->Pred_Q16[  last_smple_idx ];
    }
    SKP_memcpy( NSQ->sLPC_Q14, &psDD->sLPC_Q14[ psEncC->subfr_length ], NSQ_LPC_BUF_LENGTH * sizeof( SKP_int32 ) );
    SKP_memcpy( NSQ->sAR2_Q14, psDD->sAR2_Q14, sizeof( psDD->sAR2_Q14 ) );

    
    NSQ->sLF_AR_shp_Q12 = psDD->LF_AR_Q12;
    NSQ->lagPrev        = psEncCtrlC->pitchL[ NB_SUBFR - 1 ];

    
    SKP_memcpy( NSQ->xq,           &NSQ->xq[           psEncC->frame_length ], psEncC->frame_length * sizeof( SKP_int16 ) );
    SKP_memcpy( NSQ->sLTP_shp_Q10, &NSQ->sLTP_shp_Q10[ psEncC->frame_length ], psEncC->frame_length * sizeof( SKP_int32 ) );

#ifdef USE_UNQUANTIZED_LSFS
    DEBUG_STORE_DATA( xq_unq_lsfs.pcm, NSQ->xq, psEncC->frame_length * sizeof( SKP_int16 ) );
#endif

}




SKP_INLINE void SKP_Silk_noise_shape_quantizer_del_dec(
    SKP_Silk_nsq_state  *NSQ,                   
    NSQ_del_dec_struct  psDelDec[],             
    SKP_int             sigtype,                
    const SKP_int32     x_Q10[],                
    SKP_int8            q[],                    
    SKP_int16           xq[],                   
    SKP_int32           sLTP_Q16[],             
    const SKP_int16     a_Q12[],                
    const SKP_int16     b_Q14[],                
    const SKP_int16     AR_shp_Q13[],           
    SKP_int             lag,                    
    SKP_int32           HarmShapeFIRPacked_Q14, 
    SKP_int             Tilt_Q14,               
    SKP_int32           LF_shp_Q14,             
    SKP_int32           Gain_Q16,               
    SKP_int             Lambda_Q10,             
    SKP_int             offset_Q10,             
    SKP_int             length,                 
    SKP_int             subfr,                  
    SKP_int             shapingLPCOrder,        
    SKP_int             predictLPCOrder,        
    SKP_int             warping_Q16,            
    SKP_int             nStatesDelayedDecision, 
    SKP_int             *smpl_buf_idx,          
    SKP_int             decisionDelay           
)
{
    SKP_int     i, j, k, Winner_ind, RDmin_ind, RDmax_ind, last_smple_idx;
    SKP_int32   Winner_rand_state;
    SKP_int32   LTP_pred_Q14, LPC_pred_Q10, n_AR_Q10, n_LTP_Q14;
    SKP_int32   n_LF_Q10, r_Q10, rr_Q20, rd1_Q10, rd2_Q10, RDmin_Q10, RDmax_Q10;
    SKP_int32   q1_Q10, q2_Q10, dither, exc_Q10, LPC_exc_Q10, xq_Q10;
    SKP_int32   tmp1, tmp2, sLF_AR_shp_Q10;
    SKP_int32   *pred_lag_ptr, *shp_lag_ptr, *psLPC_Q14;
    NSQ_sample_struct  psSampleState[ MAX_DEL_DEC_STATES ][ 2 ];
    NSQ_del_dec_struct *psDD;
    NSQ_sample_struct  *psSS;
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
    SKP_int32   a_Q12_tmp[ MAX_LPC_ORDER / 2 ], Atmp;

    
    SKP_memcpy( a_Q12_tmp, a_Q12, predictLPCOrder * sizeof( SKP_int16 ) );
#endif

    shp_lag_ptr  = &NSQ->sLTP_shp_Q10[ NSQ->sLTP_shp_buf_idx - lag + HARM_SHAPE_FIR_TAPS / 2 ];
    pred_lag_ptr = &sLTP_Q16[ NSQ->sLTP_buf_idx - lag + LTP_ORDER / 2 ];

    for( i = 0; i < length; i++ ) {
        

        
        if( sigtype == SIG_TYPE_VOICED ) {
            
            LTP_pred_Q14 = SKP_SMULWB(               pred_lag_ptr[  0 ], b_Q14[ 0 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -1 ], b_Q14[ 1 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -2 ], b_Q14[ 2 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -3 ], b_Q14[ 3 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -4 ], b_Q14[ 4 ] );
            pred_lag_ptr++;
        } else {
            LTP_pred_Q14 = 0;
        }

        
        if( lag > 0 ) {
            
            n_LTP_Q14 = SKP_SMULWB( SKP_ADD32( shp_lag_ptr[ 0 ], shp_lag_ptr[ -2 ] ), HarmShapeFIRPacked_Q14 );
            n_LTP_Q14 = SKP_SMLAWT( n_LTP_Q14, shp_lag_ptr[ -1 ],                     HarmShapeFIRPacked_Q14 );
            n_LTP_Q14 = SKP_LSHIFT( n_LTP_Q14, 6 );
            shp_lag_ptr++;
        } else {
            n_LTP_Q14 = 0;
        }

        for( k = 0; k < nStatesDelayedDecision; k++ ) {
            
            psDD = &psDelDec[ k ];

            
            psSS = psSampleState[ k ];

            
            psDD->Seed = SKP_RAND( psDD->Seed );

            
            dither = SKP_RSHIFT( psDD->Seed, 31 );
            
            
            psLPC_Q14 = &psDD->sLPC_Q14[ NSQ_LPC_BUF_LENGTH - 1 + i ];
            
            SKP_assert( predictLPCOrder >= 10 );            
            SKP_assert( ( predictLPCOrder  & 1 ) == 0 );    
            SKP_assert( ( ( ( int )( ( char* )( a_Q12 ) - ( ( char* ) 0 ) ) ) & 3 ) == 0 );    
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
            
            Atmp = a_Q12_tmp[ 0 ];          
            LPC_pred_Q10 = SKP_SMULWB(               psLPC_Q14[  0 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -1 ], Atmp );
            Atmp = a_Q12_tmp[ 1 ];
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -2 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -3 ], Atmp );
            Atmp = a_Q12_tmp[ 2 ];
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -4 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -5 ], Atmp );
            Atmp = a_Q12_tmp[ 3 ];
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -6 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -7 ], Atmp );
            Atmp = a_Q12_tmp[ 4 ];
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -8 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -9 ], Atmp );
            for( j = 10; j < predictLPCOrder; j += 2 ) {
                Atmp = a_Q12_tmp[ j >> 1 ]; 
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -j     ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psLPC_Q14[ -j - 1 ], Atmp );
            }
#else
            
            LPC_pred_Q10 = SKP_SMULWB(               psLPC_Q14[  0 ], a_Q12[ 0 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -1 ], a_Q12[ 1 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -2 ], a_Q12[ 2 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -3 ], a_Q12[ 3 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -4 ], a_Q12[ 4 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -5 ], a_Q12[ 5 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -6 ], a_Q12[ 6 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -7 ], a_Q12[ 7 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -8 ], a_Q12[ 8 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -9 ], a_Q12[ 9 ] );
            for( j = 10; j < predictLPCOrder; j ++ ) {
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psLPC_Q14[ -j ], a_Q12[ j ] );
            }
#endif

            
            SKP_assert( ( shapingLPCOrder & 1 ) == 0 );   
            
            tmp2 = SKP_SMLAWB( psLPC_Q14[ 0 ], psDD->sAR2_Q14[ 0 ], warping_Q16 );
            
            tmp1 = SKP_SMLAWB( psDD->sAR2_Q14[ 0 ], psDD->sAR2_Q14[ 1 ] - tmp2, warping_Q16 );
            psDD->sAR2_Q14[ 0 ] = tmp2;
            n_AR_Q10 = SKP_SMULWB( tmp2, AR_shp_Q13[ 0 ] );
            
            for( j = 2; j < shapingLPCOrder; j += 2 ) {
                
                tmp2 = SKP_SMLAWB( psDD->sAR2_Q14[ j - 1 ], psDD->sAR2_Q14[ j + 0 ] - tmp1, warping_Q16 );
                psDD->sAR2_Q14[ j - 1 ] = tmp1;
                n_AR_Q10 = SKP_SMLAWB( n_AR_Q10, tmp1, AR_shp_Q13[ j - 1 ] );
                
                tmp1 = SKP_SMLAWB( psDD->sAR2_Q14[ j + 0 ], psDD->sAR2_Q14[ j + 1 ] - tmp2, warping_Q16 );
                psDD->sAR2_Q14[ j + 0 ] = tmp2;
                n_AR_Q10 = SKP_SMLAWB( n_AR_Q10, tmp2, AR_shp_Q13[ j ] );
            }
            psDD->sAR2_Q14[ shapingLPCOrder - 1 ] = tmp1;
            n_AR_Q10 = SKP_SMLAWB( n_AR_Q10, tmp1, AR_shp_Q13[ shapingLPCOrder - 1 ] );

            n_AR_Q10 = SKP_RSHIFT( n_AR_Q10, 1 );           
            n_AR_Q10 = SKP_SMLAWB( n_AR_Q10, psDD->LF_AR_Q12, Tilt_Q14 );

            n_LF_Q10 = SKP_LSHIFT( SKP_SMULWB( psDD->Shape_Q10[ *smpl_buf_idx ], LF_shp_Q14 ), 2 ); 
            n_LF_Q10 = SKP_SMLAWT( n_LF_Q10, psDD->LF_AR_Q12, LF_shp_Q14 );       

            
            
            tmp1  = SKP_SUB32( LTP_pred_Q14, n_LTP_Q14 );                       
            tmp1  = SKP_RSHIFT( tmp1, 4 );                                      
            tmp1  = SKP_ADD32( tmp1, LPC_pred_Q10 );                             
            tmp1  = SKP_SUB32( tmp1, n_AR_Q10 );                                 
            tmp1  = SKP_SUB32( tmp1, n_LF_Q10 );                                 
            r_Q10 = SKP_SUB32( x_Q10[ i ], tmp1 );                              
            
            
            r_Q10 = ( r_Q10 ^ dither ) - dither;
            r_Q10 = SKP_SUB32( r_Q10, offset_Q10 );
            r_Q10 = SKP_LIMIT_32( r_Q10, -(64 << 10), 64 << 10 );

            
            if( r_Q10 < -1536 ) {
                q1_Q10  = SKP_LSHIFT( SKP_RSHIFT_ROUND( r_Q10, 10 ), 10 );
                r_Q10   = SKP_SUB32( r_Q10, q1_Q10 );
                rd1_Q10 = SKP_RSHIFT( SKP_SMLABB( SKP_MUL( -SKP_ADD32( q1_Q10, offset_Q10 ), Lambda_Q10 ), r_Q10, r_Q10 ), 10 );
                rd2_Q10 = SKP_ADD32( rd1_Q10, 1024 );
                rd2_Q10 = SKP_SUB32( rd2_Q10, SKP_ADD_LSHIFT32( Lambda_Q10, r_Q10, 1 ) );
                q2_Q10  = SKP_ADD32( q1_Q10, 1024 );
            } else if( r_Q10 > 512 ) {
                q1_Q10  = SKP_LSHIFT( SKP_RSHIFT_ROUND( r_Q10, 10 ), 10 );
                r_Q10   = SKP_SUB32( r_Q10, q1_Q10 );
                rd1_Q10 = SKP_RSHIFT( SKP_SMLABB( SKP_MUL( SKP_ADD32( q1_Q10, offset_Q10 ), Lambda_Q10 ), r_Q10, r_Q10 ), 10 );
                rd2_Q10 = SKP_ADD32( rd1_Q10, 1024 );
                rd2_Q10 = SKP_SUB32( rd2_Q10, SKP_SUB_LSHIFT32( Lambda_Q10, r_Q10, 1 ) );
                q2_Q10  = SKP_SUB32( q1_Q10, 1024 );
            } else {            
                rr_Q20  = SKP_SMULBB( offset_Q10, Lambda_Q10 );
                rd2_Q10 = SKP_RSHIFT( SKP_SMLABB( rr_Q20, r_Q10, r_Q10 ), 10 );
                rd1_Q10 = SKP_ADD32( rd2_Q10, 1024 );
                rd1_Q10 = SKP_ADD32( rd1_Q10, SKP_SUB_RSHIFT32( SKP_ADD_LSHIFT32( Lambda_Q10, r_Q10, 1 ), rr_Q20, 9 ) );
                q1_Q10  = -1024;
                q2_Q10  = 0;
            }

            if( rd1_Q10 < rd2_Q10 ) {
                psSS[ 0 ].RD_Q10 = SKP_ADD32( psDD->RD_Q10, rd1_Q10 ); 
                psSS[ 1 ].RD_Q10 = SKP_ADD32( psDD->RD_Q10, rd2_Q10 );
                psSS[ 0 ].Q_Q10 = q1_Q10;
                psSS[ 1 ].Q_Q10 = q2_Q10;
            } else {
                psSS[ 0 ].RD_Q10 = SKP_ADD32( psDD->RD_Q10, rd2_Q10 );
                psSS[ 1 ].RD_Q10 = SKP_ADD32( psDD->RD_Q10, rd1_Q10 );
                psSS[ 0 ].Q_Q10 = q2_Q10;
                psSS[ 1 ].Q_Q10 = q1_Q10;
            }

            

            
            exc_Q10 = SKP_ADD32( offset_Q10, psSS[ 0 ].Q_Q10 );
            exc_Q10 = ( exc_Q10 ^ dither ) - dither;

            
            LPC_exc_Q10 = exc_Q10 + SKP_RSHIFT_ROUND( LTP_pred_Q14, 4 );
            xq_Q10      = SKP_ADD32( LPC_exc_Q10, LPC_pred_Q10 );

            
            sLF_AR_shp_Q10         = SKP_SUB32(  xq_Q10, n_AR_Q10 );
            psSS[ 0 ].sLTP_shp_Q10 = SKP_SUB32(  sLF_AR_shp_Q10, n_LF_Q10 );
            psSS[ 0 ].LF_AR_Q12    = SKP_LSHIFT( sLF_AR_shp_Q10, 2 );
            psSS[ 0 ].xq_Q14       = SKP_LSHIFT( xq_Q10,         4 );
            psSS[ 0 ].LPC_exc_Q16  = SKP_LSHIFT( LPC_exc_Q10,    6 );

            

            
            exc_Q10 = SKP_ADD32( offset_Q10, psSS[ 1 ].Q_Q10 );
            exc_Q10 = ( exc_Q10 ^ dither ) - dither;

            
            LPC_exc_Q10 = exc_Q10 + SKP_RSHIFT_ROUND( LTP_pred_Q14, 4 );
            xq_Q10      = SKP_ADD32( LPC_exc_Q10, LPC_pred_Q10 );

            
            sLF_AR_shp_Q10         = SKP_SUB32(  xq_Q10, n_AR_Q10 );
            psSS[ 1 ].sLTP_shp_Q10 = SKP_SUB32(  sLF_AR_shp_Q10, n_LF_Q10 );
            psSS[ 1 ].LF_AR_Q12    = SKP_LSHIFT( sLF_AR_shp_Q10, 2 );
            psSS[ 1 ].xq_Q14       = SKP_LSHIFT( xq_Q10,         4 );
            psSS[ 1 ].LPC_exc_Q16  = SKP_LSHIFT( LPC_exc_Q10,    6 );
        }

        *smpl_buf_idx  = ( *smpl_buf_idx - 1 ) & DECISION_DELAY_MASK;                   
        last_smple_idx = ( *smpl_buf_idx + decisionDelay ) & DECISION_DELAY_MASK;       

        
        RDmin_Q10 = psSampleState[ 0 ][ 0 ].RD_Q10;
        Winner_ind = 0;
        for( k = 1; k < nStatesDelayedDecision; k++ ) {
            if( psSampleState[ k ][ 0 ].RD_Q10 < RDmin_Q10 ) {
                RDmin_Q10   = psSampleState[ k ][ 0 ].RD_Q10;
                Winner_ind = k;
            }
        }

        
        Winner_rand_state = psDelDec[ Winner_ind ].RandState[ last_smple_idx ];
        for( k = 0; k < nStatesDelayedDecision; k++ ) {
            if( psDelDec[ k ].RandState[ last_smple_idx ] != Winner_rand_state ) {
                psSampleState[ k ][ 0 ].RD_Q10 = SKP_ADD32( psSampleState[ k ][ 0 ].RD_Q10, ( SKP_int32_MAX >> 4 ) );
                psSampleState[ k ][ 1 ].RD_Q10 = SKP_ADD32( psSampleState[ k ][ 1 ].RD_Q10, ( SKP_int32_MAX >> 4 ) );
                SKP_assert( psSampleState[ k ][ 0 ].RD_Q10 >= 0 );
            }
        }

        
        RDmax_Q10  = psSampleState[ 0 ][ 0 ].RD_Q10;
        RDmin_Q10  = psSampleState[ 0 ][ 1 ].RD_Q10;
        RDmax_ind = 0;
        RDmin_ind = 0;
        for( k = 1; k < nStatesDelayedDecision; k++ ) {
            
            if( psSampleState[ k ][ 0 ].RD_Q10 > RDmax_Q10 ) {
                RDmax_Q10  = psSampleState[ k ][ 0 ].RD_Q10;
                RDmax_ind = k;
            }
            
            if( psSampleState[ k ][ 1 ].RD_Q10 < RDmin_Q10 ) {
                RDmin_Q10  = psSampleState[ k ][ 1 ].RD_Q10;
                RDmin_ind = k;
            }
        }

        
        if( RDmin_Q10 < RDmax_Q10 ) {
            SKP_Silk_copy_del_dec_state( &psDelDec[ RDmax_ind ], &psDelDec[ RDmin_ind ], i ); 
            SKP_memcpy( &psSampleState[ RDmax_ind ][ 0 ], &psSampleState[ RDmin_ind ][ 1 ], sizeof( NSQ_sample_struct ) );
        }

        
        psDD = &psDelDec[ Winner_ind ];
        if( subfr > 0 || i >= decisionDelay ) {
            q[  i - decisionDelay ] = ( SKP_int8 )SKP_RSHIFT( psDD->Q_Q10[ last_smple_idx ], 10 );
            xq[ i - decisionDelay ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( 
                SKP_SMULWW( psDD->Xq_Q10[ last_smple_idx ], psDD->Gain_Q16[ last_smple_idx ] ), 10 ) );
            NSQ->sLTP_shp_Q10[ NSQ->sLTP_shp_buf_idx - decisionDelay ] = psDD->Shape_Q10[ last_smple_idx ];
            sLTP_Q16[          NSQ->sLTP_buf_idx     - decisionDelay ] = psDD->Pred_Q16[  last_smple_idx ];
        }
        NSQ->sLTP_shp_buf_idx++;
        NSQ->sLTP_buf_idx++;

        
        for( k = 0; k < nStatesDelayedDecision; k++ ) {
            psDD                                     = &psDelDec[ k ];
            psSS                                     = &psSampleState[ k ][ 0 ];
            psDD->LF_AR_Q12                          = psSS->LF_AR_Q12;
            psDD->sLPC_Q14[ NSQ_LPC_BUF_LENGTH + i ] = psSS->xq_Q14;
            psDD->Xq_Q10[    *smpl_buf_idx ]         = SKP_RSHIFT( psSS->xq_Q14, 4 );
            psDD->Q_Q10[     *smpl_buf_idx ]         = psSS->Q_Q10;
            psDD->Pred_Q16[  *smpl_buf_idx ]         = psSS->LPC_exc_Q16;
            psDD->Shape_Q10[ *smpl_buf_idx ]         = psSS->sLTP_shp_Q10;
            psDD->Seed                               = SKP_ADD_RSHIFT32( psDD->Seed, psSS->Q_Q10, 10 );
            psDD->RandState[ *smpl_buf_idx ]         = psDD->Seed;
            psDD->RD_Q10                             = psSS->RD_Q10;
            psDD->Gain_Q16[  *smpl_buf_idx ]         = Gain_Q16;
        }
    }
    
    for( k = 0; k < nStatesDelayedDecision; k++ ) {
        psDD = &psDelDec[ k ];
        SKP_memcpy( psDD->sLPC_Q14, &psDD->sLPC_Q14[ length ], NSQ_LPC_BUF_LENGTH * sizeof( SKP_int32 ) );
    }
}

SKP_INLINE void SKP_Silk_nsq_del_dec_scale_states(
    SKP_Silk_nsq_state  *NSQ,                   
    NSQ_del_dec_struct  psDelDec[],             
    const SKP_int16     x[],                    
    SKP_int32           x_sc_Q10[],             
    SKP_int             subfr_length,           
    const SKP_int16     sLTP[],                 
    SKP_int32           sLTP_Q16[],             
    SKP_int             subfr,                  
    SKP_int             nStatesDelayedDecision, 
    SKP_int             smpl_buf_idx,           
    const SKP_int       LTP_scale_Q14,          
    const SKP_int32     Gains_Q16[ NB_SUBFR ],  
    const SKP_int       pitchL[ NB_SUBFR ]      
)
{
    SKP_int            i, k, lag;
    SKP_int32          inv_gain_Q16, gain_adj_Q16, inv_gain_Q32;
    NSQ_del_dec_struct *psDD;

    inv_gain_Q16 = SKP_INVERSE32_varQ( SKP_max( Gains_Q16[ subfr ], 1 ), 32 );
    inv_gain_Q16 = SKP_min( inv_gain_Q16, SKP_int16_MAX );
    lag          = pitchL[ subfr ];

    
    if( NSQ->rewhite_flag ) {
        inv_gain_Q32 = SKP_LSHIFT( inv_gain_Q16, 16 );
        if( subfr == 0 ) {
            
            inv_gain_Q32 = SKP_LSHIFT( SKP_SMULWB( inv_gain_Q32, LTP_scale_Q14 ), 2 );
        }
        for( i = NSQ->sLTP_buf_idx - lag - LTP_ORDER / 2; i < NSQ->sLTP_buf_idx; i++ ) {
            SKP_assert( i < MAX_FRAME_LENGTH );
            sLTP_Q16[ i ] = SKP_SMULWB( inv_gain_Q32, sLTP[ i ] );
        }
    }

    
    if( inv_gain_Q16 != NSQ->prev_inv_gain_Q16 ) {
        gain_adj_Q16 = SKP_DIV32_varQ( inv_gain_Q16, NSQ->prev_inv_gain_Q16, 16 );

        
        for( i = NSQ->sLTP_shp_buf_idx - subfr_length * NB_SUBFR; i < NSQ->sLTP_shp_buf_idx; i++ ) {
            NSQ->sLTP_shp_Q10[ i ] = SKP_SMULWW( gain_adj_Q16, NSQ->sLTP_shp_Q10[ i ] );
        }

        
        if( NSQ->rewhite_flag == 0 ) {
            for( i = NSQ->sLTP_buf_idx - lag - LTP_ORDER / 2; i < NSQ->sLTP_buf_idx; i++ ) {
                sLTP_Q16[ i ] = SKP_SMULWW( gain_adj_Q16, sLTP_Q16[ i ] );
            }
        }

        for( k = 0; k < nStatesDelayedDecision; k++ ) {
            psDD = &psDelDec[ k ];
            
            
            psDD->LF_AR_Q12 = SKP_SMULWW( gain_adj_Q16, psDD->LF_AR_Q12 );
            
	        
            for( i = 0; i < NSQ_LPC_BUF_LENGTH; i++ ) {
                psDD->sLPC_Q14[ i ] = SKP_SMULWW( gain_adj_Q16, psDD->sLPC_Q14[ i ] );
            }
            for( i = 0; i < MAX_SHAPE_LPC_ORDER; i++ ) {
                psDD->sAR2_Q14[ i ] = SKP_SMULWW( gain_adj_Q16, psDD->sAR2_Q14[ i ] );
            }
            for( i = 0; i < DECISION_DELAY; i++ ) {
                psDD->Pred_Q16[  i ] = SKP_SMULWW( gain_adj_Q16, psDD->Pred_Q16[  i ] );
                psDD->Shape_Q10[ i ] = SKP_SMULWW( gain_adj_Q16, psDD->Shape_Q10[ i ] );
            }
        }
    }

    
    for( i = 0; i < subfr_length; i++ ) {
        x_sc_Q10[ i ] = SKP_RSHIFT( SKP_SMULBB( x[ i ], ( SKP_int16 )inv_gain_Q16 ), 6 );
    }

    
    SKP_assert( inv_gain_Q16 != 0 );
    NSQ->prev_inv_gain_Q16 = inv_gain_Q16;
}

SKP_INLINE void SKP_Silk_copy_del_dec_state(
    NSQ_del_dec_struct  *DD_dst,                
    NSQ_del_dec_struct  *DD_src,                
    SKP_int             LPC_state_idx           
)
{
    SKP_memcpy( DD_dst->RandState, DD_src->RandState, sizeof( DD_src->RandState ) );
    SKP_memcpy( DD_dst->Q_Q10,     DD_src->Q_Q10,     sizeof( DD_src->Q_Q10     ) );
    SKP_memcpy( DD_dst->Pred_Q16,  DD_src->Pred_Q16,  sizeof( DD_src->Pred_Q16  ) );
    SKP_memcpy( DD_dst->Shape_Q10, DD_src->Shape_Q10, sizeof( DD_src->Shape_Q10 ) );
    SKP_memcpy( DD_dst->Xq_Q10,    DD_src->Xq_Q10,    sizeof( DD_src->Xq_Q10    ) );
    SKP_memcpy( DD_dst->sAR2_Q14,  DD_src->sAR2_Q14,  sizeof( DD_src->sAR2_Q14  ) );
    SKP_memcpy( &DD_dst->sLPC_Q14[ LPC_state_idx ], &DD_src->sLPC_Q14[ LPC_state_idx ], NSQ_LPC_BUF_LENGTH * sizeof( SKP_int32 ) );
    DD_dst->LF_AR_Q12 = DD_src->LF_AR_Q12;
    DD_dst->Seed      = DD_src->Seed;
    DD_dst->SeedInit  = DD_src->SeedInit;
    DD_dst->RD_Q10    = DD_src->RD_Q10;
}







#define NB_ATT 2
static const SKP_int16 HARM_ATT_Q15[NB_ATT]              = { 32440, 31130 }; 
static const SKP_int16 PLC_RAND_ATTENUATE_V_Q15[NB_ATT]  = { 31130, 26214 }; 
static const SKP_int16 PLC_RAND_ATTENUATE_UV_Q15[NB_ATT] = { 32440, 29491 }; 

void SKP_Silk_PLC_Reset(
    SKP_Silk_decoder_state      *psDec              
)
{
    psDec->sPLC.pitchL_Q8 = SKP_RSHIFT( psDec->frame_length, 1 );
}

void SKP_Silk_PLC(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],           
    SKP_int                     length,             
    SKP_int                     lost                
)
{
    
    if( psDec->fs_kHz != psDec->sPLC.fs_kHz ) {
        SKP_Silk_PLC_Reset( psDec );
        psDec->sPLC.fs_kHz = psDec->fs_kHz;
    }

    if( lost ) {
        
        
        
        SKP_Silk_PLC_conceal( psDec, psDecCtrl, signal, length );

        psDec->lossCnt++;
    } else {
        
        
        
        SKP_Silk_PLC_update( psDec, psDecCtrl, signal, length );
    }
}




void SKP_Silk_PLC_update(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],
    SKP_int                     length
)
{
    SKP_int32 LTP_Gain_Q14, temp_LTP_Gain_Q14;
    SKP_int   i, j;
    SKP_Silk_PLC_struct *psPLC;

    psPLC = &psDec->sPLC;

    
    psDec->prev_sigtype = psDecCtrl->sigtype;
    LTP_Gain_Q14 = 0;
    if( psDecCtrl->sigtype == SIG_TYPE_VOICED ) {
        
        for( j = 0; j * psDec->subfr_length  < psDecCtrl->pitchL[ NB_SUBFR - 1 ]; j++ ) {
            temp_LTP_Gain_Q14 = 0;
            for( i = 0; i < LTP_ORDER; i++ ) {
                temp_LTP_Gain_Q14 += psDecCtrl->LTPCoef_Q14[ ( NB_SUBFR - 1 - j ) * LTP_ORDER  + i ];
            }
            if( temp_LTP_Gain_Q14 > LTP_Gain_Q14 ) {
                LTP_Gain_Q14 = temp_LTP_Gain_Q14;
                SKP_memcpy( psPLC->LTPCoef_Q14,
                    &psDecCtrl->LTPCoef_Q14[ SKP_SMULBB( NB_SUBFR - 1 - j, LTP_ORDER ) ],
                    LTP_ORDER * sizeof( SKP_int16 ) );

                psPLC->pitchL_Q8 = SKP_LSHIFT( psDecCtrl->pitchL[ NB_SUBFR - 1 - j ], 8 );
            }
        }

#if USE_SINGLE_TAP
        SKP_memset( psPLC->LTPCoef_Q14, 0, LTP_ORDER * sizeof( SKP_int16 ) );
        psPLC->LTPCoef_Q14[ LTP_ORDER / 2 ] = LTP_Gain_Q14;
#endif

        
        if( LTP_Gain_Q14 < V_PITCH_GAIN_START_MIN_Q14 ) {
            SKP_int   scale_Q10;
            SKP_int32 tmp;

            tmp = SKP_LSHIFT( V_PITCH_GAIN_START_MIN_Q14, 10 );
            scale_Q10 = SKP_DIV32( tmp, SKP_max( LTP_Gain_Q14, 1 ) );
            for( i = 0; i < LTP_ORDER; i++ ) {
                psPLC->LTPCoef_Q14[ i ] = SKP_RSHIFT( SKP_SMULBB( psPLC->LTPCoef_Q14[ i ], scale_Q10 ), 10 );
            }
        } else if( LTP_Gain_Q14 > V_PITCH_GAIN_START_MAX_Q14 ) {
            SKP_int   scale_Q14;
            SKP_int32 tmp;

            tmp = SKP_LSHIFT( V_PITCH_GAIN_START_MAX_Q14, 14 );
            scale_Q14 = SKP_DIV32( tmp, SKP_max( LTP_Gain_Q14, 1 ) );
            for( i = 0; i < LTP_ORDER; i++ ) {
                psPLC->LTPCoef_Q14[ i ] = SKP_RSHIFT( SKP_SMULBB( psPLC->LTPCoef_Q14[ i ], scale_Q14 ), 14 );
            }
        }
    } else {
        psPLC->pitchL_Q8 = SKP_LSHIFT( SKP_SMULBB( psDec->fs_kHz, 18 ), 8 );
        SKP_memset( psPLC->LTPCoef_Q14, 0, LTP_ORDER * sizeof( SKP_int16 ));
    }

    
    SKP_memcpy( psPLC->prevLPC_Q12, psDecCtrl->PredCoef_Q12[ 1 ], psDec->LPC_order * sizeof( SKP_int16 ) );
    psPLC->prevLTP_scale_Q14 = psDecCtrl->LTP_scale_Q14;

    
    SKP_memcpy( psPLC->prevGain_Q16, psDecCtrl->Gains_Q16, NB_SUBFR * sizeof( SKP_int32 ) );
}

void SKP_Silk_PLC_conceal(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],           
    SKP_int                     length              
)
{
    SKP_int   i, j, k;
    SKP_int16 *B_Q14, exc_buf[ MAX_FRAME_LENGTH ], *exc_buf_ptr;
    SKP_int16 rand_scale_Q14;
    union {
        SKP_int16 as_int16[ MAX_LPC_ORDER ];
        SKP_int32 as_int32[ MAX_LPC_ORDER / 2 ];
    } A_Q12_tmp;
    SKP_int32 rand_seed, harm_Gain_Q15, rand_Gain_Q15;
    SKP_int   lag, idx, sLTP_buf_idx, shift1, shift2;
    SKP_int32 energy1, energy2, *rand_ptr, *pred_lag_ptr;
    SKP_int32 sig_Q10[ MAX_FRAME_LENGTH ], *sig_Q10_ptr, LPC_exc_Q10, LPC_pred_Q10,  LTP_pred_Q14;
    SKP_Silk_PLC_struct *psPLC;
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
    SKP_int32 Atmp;
#endif
    psPLC = &psDec->sPLC;

    
    SKP_memcpy( psDec->sLTP_Q16, &psDec->sLTP_Q16[ psDec->frame_length ], psDec->frame_length * sizeof( SKP_int32 ) );

    
    SKP_Silk_bwexpander( psPLC->prevLPC_Q12, psDec->LPC_order, BWE_COEF_Q16 );

    
    
    exc_buf_ptr = exc_buf;
    for( k = ( NB_SUBFR >> 1 ); k < NB_SUBFR; k++ ) {
        for( i = 0; i < psDec->subfr_length; i++ ) {
            exc_buf_ptr[ i ] = ( SKP_int16 )SKP_RSHIFT( 
                SKP_SMULWW( psDec->exc_Q10[ i + k * psDec->subfr_length ], psPLC->prevGain_Q16[ k ] ), 10 );
        }
        exc_buf_ptr += psDec->subfr_length;
    }
     
    SKP_Silk_sum_sqr_shift( &energy1, &shift1, exc_buf,                         psDec->subfr_length );
    SKP_Silk_sum_sqr_shift( &energy2, &shift2, &exc_buf[ psDec->subfr_length ], psDec->subfr_length );
        
    if( SKP_RSHIFT( energy1, shift2 ) < SKP_RSHIFT( energy2, shift1 ) ) {
        
        rand_ptr = &psDec->exc_Q10[ SKP_max_int( 0, 3 * psDec->subfr_length - RAND_BUF_SIZE ) ];
    } else {
        
        rand_ptr = &psDec->exc_Q10[ SKP_max_int( 0, psDec->frame_length - RAND_BUF_SIZE ) ];
    }

     
    B_Q14          = psPLC->LTPCoef_Q14;
    rand_scale_Q14 = psPLC->randScale_Q14;

    
    harm_Gain_Q15 = HARM_ATT_Q15[ SKP_min_int( NB_ATT - 1, psDec->lossCnt ) ];
    if( psDec->prev_sigtype == SIG_TYPE_VOICED ) {
        rand_Gain_Q15 = PLC_RAND_ATTENUATE_V_Q15[  SKP_min_int( NB_ATT - 1, psDec->lossCnt ) ];
    } else {
        rand_Gain_Q15 = PLC_RAND_ATTENUATE_UV_Q15[ SKP_min_int( NB_ATT - 1, psDec->lossCnt ) ];
    }

    
    if( psDec->lossCnt == 0 ) {
        rand_scale_Q14 = (1 << 14 );
    
        
        if( psDec->prev_sigtype == SIG_TYPE_VOICED ) {
            for( i = 0; i < LTP_ORDER; i++ ) {
                rand_scale_Q14 -= B_Q14[ i ];
            }
            rand_scale_Q14 = SKP_max_16( 3277, rand_scale_Q14 ); 
            rand_scale_Q14 = ( SKP_int16 )SKP_RSHIFT( SKP_SMULBB( rand_scale_Q14, psPLC->prevLTP_scale_Q14 ), 14 );
        }

        
        if( psDec->prev_sigtype == SIG_TYPE_UNVOICED ) {
            SKP_int32 invGain_Q30, down_scale_Q30;
            
            SKP_Silk_LPC_inverse_pred_gain( &invGain_Q30, psPLC->prevLPC_Q12, psDec->LPC_order );
            
            down_scale_Q30 = SKP_min_32( SKP_RSHIFT( ( 1 << 30 ), LOG2_INV_LPC_GAIN_HIGH_THRES ), invGain_Q30 );
            down_scale_Q30 = SKP_max_32( SKP_RSHIFT( ( 1 << 30 ), LOG2_INV_LPC_GAIN_LOW_THRES ), down_scale_Q30 );
            down_scale_Q30 = SKP_LSHIFT( down_scale_Q30, LOG2_INV_LPC_GAIN_HIGH_THRES );
            
            rand_Gain_Q15 = SKP_RSHIFT( SKP_SMULWB( down_scale_Q30, rand_Gain_Q15 ), 14 );
        }
    }

    rand_seed    = psPLC->rand_seed;
    lag          = SKP_RSHIFT_ROUND( psPLC->pitchL_Q8, 8 );
    sLTP_buf_idx = psDec->frame_length;

    
    
    
    sig_Q10_ptr = sig_Q10;
    for( k = 0; k < NB_SUBFR; k++ ) {
        
        pred_lag_ptr = &psDec->sLTP_Q16[ sLTP_buf_idx - lag + LTP_ORDER / 2 ];
        for( i = 0; i < psDec->subfr_length; i++ ) {
            rand_seed = SKP_RAND( rand_seed );
            idx = SKP_RSHIFT( rand_seed, 25 ) & RAND_BUF_MASK;

            
            LTP_pred_Q14 = SKP_SMULWB(               pred_lag_ptr[  0 ], B_Q14[ 0 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -1 ], B_Q14[ 1 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -2 ], B_Q14[ 2 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -3 ], B_Q14[ 3 ] );
            LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -4 ], B_Q14[ 4 ] );
            pred_lag_ptr++;
            
            
            LPC_exc_Q10 = SKP_LSHIFT( SKP_SMULWB( rand_ptr[ idx ], rand_scale_Q14 ), 2 ); 
            LPC_exc_Q10 = SKP_ADD32( LPC_exc_Q10, SKP_RSHIFT_ROUND( LTP_pred_Q14, 4 ) );  
            
            
            psDec->sLTP_Q16[ sLTP_buf_idx ] = SKP_LSHIFT( LPC_exc_Q10, 6 );
            sLTP_buf_idx++;
                
            
            sig_Q10_ptr[ i ] = LPC_exc_Q10;
        }
        sig_Q10_ptr += psDec->subfr_length;
        
        for( j = 0; j < LTP_ORDER; j++ ) {
            B_Q14[ j ] = SKP_RSHIFT( SKP_SMULBB( harm_Gain_Q15, B_Q14[ j ] ), 15 );
        }
        
        rand_scale_Q14 = SKP_RSHIFT( SKP_SMULBB( rand_scale_Q14, rand_Gain_Q15 ), 15 );

        
        psPLC->pitchL_Q8 += SKP_SMULWB( psPLC->pitchL_Q8, PITCH_DRIFT_FAC_Q16 );
        psPLC->pitchL_Q8 = SKP_min_32( psPLC->pitchL_Q8, SKP_LSHIFT( SKP_SMULBB( MAX_PITCH_LAG_MS, psDec->fs_kHz ), 8 ) );
        lag = SKP_RSHIFT_ROUND( psPLC->pitchL_Q8, 8 );
    }

    
    
    
    sig_Q10_ptr = sig_Q10;
    
    SKP_memcpy( A_Q12_tmp.as_int16, psPLC->prevLPC_Q12, psDec->LPC_order * sizeof( SKP_int16 ) );
    SKP_assert( psDec->LPC_order >= 10 ); 
    for( k = 0; k < NB_SUBFR; k++ ) {
        for( i = 0; i < psDec->subfr_length; i++ ){
            
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
            
            
            
            
            Atmp = A_Q12_tmp.as_int32[ 0 ];    
            LPC_pred_Q10 = SKP_SMULWB(               psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  1 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  2 ], Atmp );
            Atmp = A_Q12_tmp.as_int32[ 1 ];
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  3 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  4 ], Atmp );
            Atmp = A_Q12_tmp.as_int32[ 2 ];
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  5 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  6 ], Atmp );
            Atmp = A_Q12_tmp.as_int32[ 3 ];
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  7 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  8 ], Atmp );
            Atmp = A_Q12_tmp.as_int32[ 4 ];
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  9 ], Atmp );
            LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i - 10 ], Atmp );
            for( j = 10 ; j < psDec->LPC_order ; j+=2 ) {
                Atmp = A_Q12_tmp.as_int32[ j / 2 ];
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  1 - j ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  2 - j ], Atmp );
            }
#else
            LPC_pred_Q10 = SKP_SMULWB(               psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  1 ], A_Q12_tmp.as_int16[ 0 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  2 ], A_Q12_tmp.as_int16[ 1 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  3 ], A_Q12_tmp.as_int16[ 2 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  4 ], A_Q12_tmp.as_int16[ 3 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  5 ], A_Q12_tmp.as_int16[ 4 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  6 ], A_Q12_tmp.as_int16[ 5 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  7 ], A_Q12_tmp.as_int16[ 6 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  8 ], A_Q12_tmp.as_int16[ 7 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i -  9 ], A_Q12_tmp.as_int16[ 8 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i - 10 ], A_Q12_tmp.as_int16[ 9 ] );

            for( j = 10; j < psDec->LPC_order; j++ ) {
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, psDec->sLPC_Q14[ MAX_LPC_ORDER + i - j - 1 ], A_Q12_tmp.as_int16[ j ] );
            }
#endif
            
            sig_Q10_ptr[ i ] = SKP_ADD32( sig_Q10_ptr[ i ], LPC_pred_Q10 );
                
            
            psDec->sLPC_Q14[ MAX_LPC_ORDER + i ] = SKP_LSHIFT( sig_Q10_ptr[ i ], 4 );
        }
        sig_Q10_ptr += psDec->subfr_length;
        
        SKP_memcpy( psDec->sLPC_Q14, &psDec->sLPC_Q14[ psDec->subfr_length ], MAX_LPC_ORDER * sizeof( SKP_int32 ) );
    }

    
    for( i = 0; i < psDec->frame_length; i++ ) {
        signal[ i ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( SKP_SMULWW( sig_Q10[ i ], psPLC->prevGain_Q16[ NB_SUBFR - 1 ] ), 10 ) );
    }

    
    
    
    psPLC->rand_seed     = rand_seed;
    psPLC->randScale_Q14 = rand_scale_Q14;
    for( i = 0; i < NB_SUBFR; i++ ) {
        psDecCtrl->pitchL[ i ] = lag;
    }
}


void SKP_Silk_PLC_glue_frames(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int16                   signal[],           
    SKP_int                     length              
)
{
    SKP_int   i, energy_shift;
    SKP_int32 energy;
    SKP_Silk_PLC_struct *psPLC;
    psPLC = &psDec->sPLC;

    if( psDec->lossCnt ) {
        
        SKP_Silk_sum_sqr_shift( &psPLC->conc_energy, &psPLC->conc_energy_shift, signal, length );
        
        psPLC->last_frame_lost = 1;
    } else {
        if( psDec->sPLC.last_frame_lost ) {
            
            SKP_Silk_sum_sqr_shift( &energy, &energy_shift, signal, length );

            
            if( energy_shift > psPLC->conc_energy_shift ) {
                psPLC->conc_energy = SKP_RSHIFT( psPLC->conc_energy, energy_shift - psPLC->conc_energy_shift );
            } else if( energy_shift < psPLC->conc_energy_shift ) {
                energy = SKP_RSHIFT( energy, psPLC->conc_energy_shift - energy_shift );
            }

            
            if( energy > psPLC->conc_energy ) {
                SKP_int32 frac_Q24, LZ;
                SKP_int32 gain_Q12, slope_Q12;

                LZ = SKP_Silk_CLZ32( psPLC->conc_energy );
                LZ = LZ - 1;
                psPLC->conc_energy = SKP_LSHIFT( psPLC->conc_energy, LZ );
                energy = SKP_RSHIFT( energy, SKP_max_32( 24 - LZ, 0 ) );
                
                frac_Q24 = SKP_DIV32( psPLC->conc_energy, SKP_max( energy, 1 ) );
                
                gain_Q12 = SKP_Silk_SQRT_APPROX( frac_Q24 );
                slope_Q12 = SKP_DIV32_16( ( 1 << 12 ) - gain_Q12, length );

                for( i = 0; i < length; i++ ) {
                    signal[ i ] = SKP_RSHIFT( SKP_MUL( gain_Q12, signal[ i ] ), 12 );
                    gain_Q12 += slope_Q12;
                    gain_Q12 = SKP_min( gain_Q12, ( 1 << 12 ) );
                }
            }
        }
        psPLC->last_frame_lost = 0;

    }
}







#include <stdlib.h>





SKP_int SKP_Silk_VAD_Init(                               
    SKP_Silk_VAD_state              *psSilk_VAD          
)
{
    SKP_int b, ret = 0;

    
    SKP_memset( psSilk_VAD, 0, sizeof( SKP_Silk_VAD_state ) );

    
    
    for( b = 0; b < VAD_N_BANDS; b++ ) {
        psSilk_VAD->NoiseLevelBias[ b ] = SKP_max_32( SKP_DIV32_16( VAD_NOISE_LEVELS_BIAS, b + 1 ), 1 );
    }

    
    for( b = 0; b < VAD_N_BANDS; b++ ) {
        psSilk_VAD->NL[ b ]     = SKP_MUL( 100, psSilk_VAD->NoiseLevelBias[ b ] );
        psSilk_VAD->inv_NL[ b ] = SKP_DIV32( SKP_int32_MAX, psSilk_VAD->NL[ b ] );
    }
    psSilk_VAD->counter = 15;

    
    for( b = 0; b < VAD_N_BANDS; b++ ) {
        psSilk_VAD->NrgRatioSmth_Q8[ b ] = 100 * 256;       
    }

    return( ret );
}


const static SKP_int32 tiltWeights[ VAD_N_BANDS ] = { 30000, 6000, -12000, -12000 };




SKP_int SKP_Silk_VAD_GetSA_Q8(                                      
    SKP_Silk_VAD_state              *psSilk_VAD,                    
    SKP_int                         *pSA_Q8,                        
    SKP_int                         *pSNR_dB_Q7,                    
    SKP_int                         pQuality_Q15[ VAD_N_BANDS ],    
    SKP_int                         *pTilt_Q15,                     
    const SKP_int16                 pIn[],                          
    const SKP_int                   framelength                     
)
{
    SKP_int   SA_Q15, input_tilt;
    SKP_int32 scratch[ 3 * MAX_FRAME_LENGTH / 2 ];
    SKP_int   decimated_framelength, dec_subframe_length, dec_subframe_offset, SNR_Q7, i, b, s;
    SKP_int32 sumSquared, smooth_coef_Q16;
    SKP_int16 HPstateTmp;

    SKP_int16 X[ VAD_N_BANDS ][ MAX_FRAME_LENGTH / 2 ];
    SKP_int32 Xnrg[ VAD_N_BANDS ];
    SKP_int32 NrgToNoiseRatio_Q8[ VAD_N_BANDS ];
    SKP_int32 speech_nrg, x_tmp;
    SKP_int   ret = 0;

    
    SKP_assert( VAD_N_BANDS == 4 );
    SKP_assert( MAX_FRAME_LENGTH >= framelength );
    SKP_assert( framelength <= 512 );

    
    
    
    
    SKP_Silk_ana_filt_bank_1( pIn,          &psSilk_VAD->AnaState[  0 ], &X[ 0 ][ 0 ], &X[ 3 ][ 0 ], &scratch[ 0 ], framelength );        
    
    
    SKP_Silk_ana_filt_bank_1( &X[ 0 ][ 0 ], &psSilk_VAD->AnaState1[ 0 ], &X[ 0 ][ 0 ], &X[ 2 ][ 0 ], &scratch[ 0 ], SKP_RSHIFT( framelength, 1 ) );
    
    
    SKP_Silk_ana_filt_bank_1( &X[ 0 ][ 0 ], &psSilk_VAD->AnaState2[ 0 ], &X[ 0 ][ 0 ], &X[ 1 ][ 0 ], &scratch[ 0 ], SKP_RSHIFT( framelength, 2 ) );

    
    
    
    decimated_framelength = SKP_RSHIFT( framelength, 3 );
    X[ 0 ][ decimated_framelength - 1 ] = SKP_RSHIFT( X[ 0 ][ decimated_framelength - 1 ], 1 );
    HPstateTmp = X[ 0 ][ decimated_framelength - 1 ];
    for( i = decimated_framelength - 1; i > 0; i-- ) {
        X[ 0 ][ i - 1 ]  = SKP_RSHIFT( X[ 0 ][ i - 1 ], 1 );
        X[ 0 ][ i ]     -= X[ 0 ][ i - 1 ];
    }
    X[ 0 ][ 0 ] -= psSilk_VAD->HPstate;
    psSilk_VAD->HPstate = HPstateTmp;

    
    
    
    for( b = 0; b < VAD_N_BANDS; b++ ) {        
        
        decimated_framelength = SKP_RSHIFT( framelength, SKP_min_int( VAD_N_BANDS - b, VAD_N_BANDS - 1 ) );

        
        dec_subframe_length = SKP_RSHIFT( decimated_framelength, VAD_INTERNAL_SUBFRAMES_LOG2 );
        dec_subframe_offset = 0;

        
        
        Xnrg[ b ] = psSilk_VAD->XnrgSubfr[ b ];
        for( s = 0; s < VAD_INTERNAL_SUBFRAMES; s++ ) {
            sumSquared = 0;
            for( i = 0; i < dec_subframe_length; i++ ) {
                
                
                x_tmp = SKP_RSHIFT( X[ b ][ i + dec_subframe_offset ], 3 );
                sumSquared = SKP_SMLABB( sumSquared, x_tmp, x_tmp );

                
                SKP_assert( sumSquared >= 0 );
            }

            
            if( s < VAD_INTERNAL_SUBFRAMES - 1 ) {
                Xnrg[ b ] = SKP_ADD_POS_SAT32( Xnrg[ b ], sumSquared );
            } else {
                
                Xnrg[ b ] = SKP_ADD_POS_SAT32( Xnrg[ b ], SKP_RSHIFT( sumSquared, 1 ) );
            }

            dec_subframe_offset += dec_subframe_length;
        }
        psSilk_VAD->XnrgSubfr[ b ] = sumSquared; 
    }

    
    
    
    SKP_Silk_VAD_GetNoiseLevels( &Xnrg[ 0 ], psSilk_VAD );

    
    
    
    sumSquared = 0;
    input_tilt = 0;
    for( b = 0; b < VAD_N_BANDS; b++ ) {
        speech_nrg = Xnrg[ b ] - psSilk_VAD->NL[ b ];
        if( speech_nrg > 0 ) {
            
            if( ( Xnrg[ b ] & 0xFF800000 ) == 0 ) {
                NrgToNoiseRatio_Q8[ b ] = SKP_DIV32( SKP_LSHIFT( Xnrg[ b ], 8 ), psSilk_VAD->NL[ b ] + 1 );
            } else {
                NrgToNoiseRatio_Q8[ b ] = SKP_DIV32( Xnrg[ b ], SKP_RSHIFT( psSilk_VAD->NL[ b ], 8 ) + 1 );
            }

            
            SNR_Q7 = SKP_Silk_lin2log( NrgToNoiseRatio_Q8[ b ] ) - 8 * 128;

            
            sumSquared = SKP_SMLABB( sumSquared, SNR_Q7, SNR_Q7 );          

            
            if( speech_nrg < ( 1 << 20 ) ) {
                
                SNR_Q7 = SKP_SMULWB( SKP_LSHIFT( SKP_Silk_SQRT_APPROX( speech_nrg ), 6 ), SNR_Q7 );
            }
            input_tilt = SKP_SMLAWB( input_tilt, tiltWeights[ b ], SNR_Q7 );
        } else {
            NrgToNoiseRatio_Q8[ b ] = 256;
        }
    }

    
    sumSquared = SKP_DIV32_16( sumSquared, VAD_N_BANDS ); 

    
    *pSNR_dB_Q7 = ( SKP_int16 )( 3 * SKP_Silk_SQRT_APPROX( sumSquared ) );  

    
    
    
    SA_Q15 = SKP_Silk_sigm_Q15( SKP_SMULWB( VAD_SNR_FACTOR_Q16, *pSNR_dB_Q7 ) - VAD_NEGATIVE_OFFSET_Q5 );

    
    
    
    *pTilt_Q15 = SKP_LSHIFT( SKP_Silk_sigm_Q15( input_tilt ) - 16384, 1 );

    
    
    
    speech_nrg = 0;
    for( b = 0; b < VAD_N_BANDS; b++ ) {
        
        speech_nrg += ( b + 1 ) * SKP_RSHIFT( Xnrg[ b ] - psSilk_VAD->NL[ b ], 4 );
    }

    
    if( speech_nrg <= 0 ) {
        SA_Q15 = SKP_RSHIFT( SA_Q15, 1 ); 
    } else if( speech_nrg < 32768 ) {
        
        speech_nrg = SKP_Silk_SQRT_APPROX( SKP_LSHIFT( speech_nrg, 15 ) );
        SA_Q15 = SKP_SMULWB( 32768 + speech_nrg, SA_Q15 ); 
    }

    
    *pSA_Q8 = SKP_min_int( SKP_RSHIFT( SA_Q15, 7 ), SKP_uint8_MAX );

    
    
    
    
    smooth_coef_Q16 = SKP_SMULWB( VAD_SNR_SMOOTH_COEF_Q18, SKP_SMULWB( SA_Q15, SA_Q15 ) );
    for( b = 0; b < VAD_N_BANDS; b++ ) {
        
        psSilk_VAD->NrgRatioSmth_Q8[ b ] = SKP_SMLAWB( psSilk_VAD->NrgRatioSmth_Q8[ b ], 
            NrgToNoiseRatio_Q8[ b ] - psSilk_VAD->NrgRatioSmth_Q8[ b ], smooth_coef_Q16 );

        
        SNR_Q7 = 3 * ( SKP_Silk_lin2log( psSilk_VAD->NrgRatioSmth_Q8[b] ) - 8 * 128 );
        
        pQuality_Q15[ b ] = SKP_Silk_sigm_Q15( SKP_RSHIFT( SNR_Q7 - 16 * 128, 4 ) );
    }

    return( ret );
}




void SKP_Silk_VAD_GetNoiseLevels(
    const SKP_int32                 pX[ VAD_N_BANDS ],  
    SKP_Silk_VAD_state              *psSilk_VAD          
)
{
    SKP_int   k;
    SKP_int32 nl, nrg, inv_nrg;
    SKP_int   coef, min_coef;

    
    if( psSilk_VAD->counter < 1000 ) { 
        min_coef = SKP_DIV32_16( SKP_int16_MAX, SKP_RSHIFT( psSilk_VAD->counter, 4 ) + 1 );  
    } else {
        min_coef = 0;
    }

    for( k = 0; k < VAD_N_BANDS; k++ ) {
        
        nl = psSilk_VAD->NL[ k ];
        SKP_assert( nl >= 0 );
        
        
        nrg = SKP_ADD_POS_SAT32( pX[ k ], psSilk_VAD->NoiseLevelBias[ k ] ); 
        SKP_assert( nrg > 0 );
        
        
        inv_nrg = SKP_DIV32( SKP_int32_MAX, nrg );
        SKP_assert( inv_nrg >= 0 );
        
        
        if( nrg > SKP_LSHIFT( nl, 3 ) ) {
            coef = VAD_NOISE_LEVEL_SMOOTH_COEF_Q16 >> 3;
        } else if( nrg < nl ) {
            coef = VAD_NOISE_LEVEL_SMOOTH_COEF_Q16;
        } else {
            coef = SKP_SMULWB( SKP_SMULWW( inv_nrg, nl ), VAD_NOISE_LEVEL_SMOOTH_COEF_Q16 << 1 );
        }

        
        coef = SKP_max_int( coef, min_coef );

        
        psSilk_VAD->inv_NL[ k ] = SKP_SMLAWB( psSilk_VAD->inv_NL[ k ], inv_nrg - psSilk_VAD->inv_NL[ k ], coef );
        SKP_assert( psSilk_VAD->inv_NL[ k ] >= 0 );

        
        nl = SKP_DIV32( SKP_int32_MAX, psSilk_VAD->inv_NL[ k ] );
        SKP_assert( nl >= 0 );

        
        nl = SKP_min( nl, 0x00FFFFFF );

        
        psSilk_VAD->NL[ k ] = nl;
    }

    
    psSilk_VAD->counter++;
}







void SKP_Silk_VQ_WMat_EC_FIX(
    SKP_int                         *ind,               
    SKP_int32                       *rate_dist_Q14,     
    const SKP_int16                 *in_Q14,            
    const SKP_int32                 *W_Q18,             
    const SKP_int16                 *cb_Q14,            
    const SKP_int16                 *cl_Q6,             
    const SKP_int                   mu_Q8,              
    SKP_int                         L                   
)
{
    SKP_int   k;
    const SKP_int16 *cb_row_Q14;
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
    SKP_int32 sum1_Q14, sum2_Q16, diff_Q14_01, diff_Q14_23, diff_Q14_4;
#else
    SKP_int16 diff_Q14[ 5 ];
    SKP_int32 sum1_Q14, sum2_Q16;
#endif

    
    *rate_dist_Q14 = SKP_int32_MAX;
    cb_row_Q14 = cb_Q14;
    for( k = 0; k < L; k++ ) {
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
        
        diff_Q14_01 = ( SKP_uint16 )( in_Q14[ 0 ] - cb_row_Q14[ 0 ] ) | SKP_LSHIFT( ( SKP_int32 )in_Q14[ 1 ] - cb_row_Q14[ 1 ], 16 );
        diff_Q14_23 = ( SKP_uint16 )( in_Q14[ 2 ] - cb_row_Q14[ 2 ] ) | SKP_LSHIFT( ( SKP_int32 )in_Q14[ 3 ] - cb_row_Q14[ 3 ], 16 );
        diff_Q14_4  = in_Q14[ 4 ] - cb_row_Q14[ 4 ];
#else
        diff_Q14[ 0 ] = in_Q14[ 0 ] - cb_row_Q14[ 0 ];
        diff_Q14[ 1 ] = in_Q14[ 1 ] - cb_row_Q14[ 1 ];
        diff_Q14[ 2 ] = in_Q14[ 2 ] - cb_row_Q14[ 2 ];
        diff_Q14[ 3 ] = in_Q14[ 3 ] - cb_row_Q14[ 3 ];
        diff_Q14[ 4 ] = in_Q14[ 4 ] - cb_row_Q14[ 4 ];
#endif

        
        sum1_Q14 = SKP_SMULBB( mu_Q8, cl_Q6[ k ] );

        SKP_assert( sum1_Q14 >= 0 );

#if !defined(_SYSTEM_IS_BIG_ENDIAN)
        
        
        
        
        
        
        sum2_Q16 = SKP_SMULWT(           W_Q18[ 1 ], diff_Q14_01 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[ 2 ], diff_Q14_23 );
        sum2_Q16 = SKP_SMLAWT( sum2_Q16, W_Q18[ 3 ], diff_Q14_23 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[ 4 ], diff_Q14_4  );
        sum2_Q16 = SKP_LSHIFT( sum2_Q16, 1 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[ 0 ], diff_Q14_01 );
        sum1_Q14 = SKP_SMLAWB( sum1_Q14, sum2_Q16,   diff_Q14_01 );

        
        sum2_Q16 = SKP_SMULWB(           W_Q18[ 7 ], diff_Q14_23 );
        sum2_Q16 = SKP_SMLAWT( sum2_Q16, W_Q18[ 8 ], diff_Q14_23 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[ 9 ], diff_Q14_4  );
        sum2_Q16 = SKP_LSHIFT( sum2_Q16, 1 );
        sum2_Q16 = SKP_SMLAWT( sum2_Q16, W_Q18[ 6 ], diff_Q14_01 );
        sum1_Q14 = SKP_SMLAWT( sum1_Q14, sum2_Q16,   diff_Q14_01 );

        
        sum2_Q16 = SKP_SMULWT(           W_Q18[ 13 ], diff_Q14_23 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[ 14 ], diff_Q14_4  );
        sum2_Q16 = SKP_LSHIFT( sum2_Q16, 1 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[ 12 ], diff_Q14_23 );
        sum1_Q14 = SKP_SMLAWB( sum1_Q14, sum2_Q16,    diff_Q14_23 );

        
        sum2_Q16 = SKP_SMULWB(           W_Q18[ 19 ], diff_Q14_4  );
        sum2_Q16 = SKP_LSHIFT( sum2_Q16, 1 );
        sum2_Q16 = SKP_SMLAWT( sum2_Q16, W_Q18[ 18 ], diff_Q14_23 );
        sum1_Q14 = SKP_SMLAWT( sum1_Q14, sum2_Q16,    diff_Q14_23 );

        
        sum2_Q16 = SKP_SMULWB(           W_Q18[ 24 ], diff_Q14_4  );
        sum1_Q14 = SKP_SMLAWB( sum1_Q14, sum2_Q16,    diff_Q14_4  );
#else
        
        sum2_Q16 = SKP_SMULWB(           W_Q18[  1 ], diff_Q14[ 1 ] );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[  2 ], diff_Q14[ 2 ] );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[  3 ], diff_Q14[ 3 ] );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[  4 ], diff_Q14[ 4 ] );
        sum2_Q16 = SKP_LSHIFT( sum2_Q16, 1 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[  0 ], diff_Q14[ 0 ] );
        sum1_Q14 = SKP_SMLAWB( sum1_Q14, sum2_Q16,    diff_Q14[ 0 ] );

        
        sum2_Q16 = SKP_SMULWB(           W_Q18[  7 ], diff_Q14[ 2 ] ); 
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[  8 ], diff_Q14[ 3 ] );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[  9 ], diff_Q14[ 4 ] );
        sum2_Q16 = SKP_LSHIFT( sum2_Q16, 1 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[  6 ], diff_Q14[ 1 ] );
        sum1_Q14 = SKP_SMLAWB( sum1_Q14, sum2_Q16,    diff_Q14[ 1 ] );

        
        sum2_Q16 = SKP_SMULWB(           W_Q18[ 13 ], diff_Q14[ 3 ] ); 
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[ 14 ], diff_Q14[ 4 ] );
        sum2_Q16 = SKP_LSHIFT( sum2_Q16, 1 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[ 12 ], diff_Q14[ 2 ] );
        sum1_Q14 = SKP_SMLAWB( sum1_Q14, sum2_Q16,    diff_Q14[ 2 ] );

        
        sum2_Q16 = SKP_SMULWB(           W_Q18[ 19 ], diff_Q14[ 4 ] ); 
        sum2_Q16 = SKP_LSHIFT( sum2_Q16, 1 );
        sum2_Q16 = SKP_SMLAWB( sum2_Q16, W_Q18[ 18 ], diff_Q14[ 3 ] );
        sum1_Q14 = SKP_SMLAWB( sum1_Q14, sum2_Q16,    diff_Q14[ 3 ] );

        
        sum2_Q16 = SKP_SMULWB(           W_Q18[ 24 ], diff_Q14[ 4 ] ); 
        sum1_Q14 = SKP_SMLAWB( sum1_Q14, sum2_Q16,    diff_Q14[ 4 ] );
#endif

        SKP_assert( sum1_Q14 >= 0 );

        
        if( sum1_Q14 < *rate_dist_Q14 ) {
            *rate_dist_Q14 = sum1_Q14;
            *ind = k;
        }

        
        cb_row_Q14 += LTP_ORDER;
    }
}







#if EMBEDDED_ARM<5


static SKP_int16 A_fb1_20[ 1 ] = {  5394 << 1 };
static SKP_int16 A_fb1_21[ 1 ] = {  (SKP_int16) (20623 << 1) };        


void SKP_Silk_ana_filt_bank_1(
    const SKP_int16      *in,        
    SKP_int32            *S,         
    SKP_int16            *outL,      
    SKP_int16            *outH,      
    SKP_int32            *scratch,      
    const SKP_int32      N           
)
{
    SKP_int      k, N2 = SKP_RSHIFT( N, 1 );
    SKP_int32    in32, X, Y, out_1, out_2;

    
    for( k = 0; k < N2; k++ ) {
        
        in32 = SKP_LSHIFT( (SKP_int32)in[ 2 * k ], 10 );

        
        Y      = SKP_SUB32( in32, S[ 0 ] );
        X      = SKP_SMLAWB( Y, Y, A_fb1_21[ 0 ] );
        out_1  = SKP_ADD32( S[ 0 ], X );
        S[ 0 ] = SKP_ADD32( in32, X );

        
        in32 = SKP_LSHIFT( (SKP_int32)in[ 2 * k + 1 ], 10 );

        
        Y      = SKP_SUB32( in32, S[ 1 ] );
        X      = SKP_SMULWB( Y, A_fb1_20[ 0 ] );
        out_2  = SKP_ADD32( S[ 1 ], X );
        S[ 1 ] = SKP_ADD32( in32, X );

        
        outL[ k ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( SKP_ADD32( out_2, out_1 ), 11 ) );
        outH[ k ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( SKP_SUB32( out_2, out_1 ), 11 ) );
    }
}
#endif














static SKP_int16 freq_table_Q16[ 27 ] = {
   12111,    9804,    8235,    7100,    6239,    5565,    5022,    4575,    4202,
    3885,    3612,    3375,    3167,    2984,    2820,    2674,    2542,    2422,
    2313,    2214,    2123,    2038,    1961,    1889,    1822,    1760,    1702,
};


void SKP_Silk_apply_sine_window(
    SKP_int16                        px_win[],            
    const SKP_int16                  px[],                
    const SKP_int                    win_type,            
    const SKP_int                    length               
)
{
    SKP_int   k, f_Q16, c_Q16;
    SKP_int32 S0_Q16, S1_Q16;
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
    SKP_int32 px32;
#endif
    SKP_assert( win_type == 1 || win_type == 2 );

    
    SKP_assert( length >= 16 && length <= 120 );
    SKP_assert( ( length & 3 ) == 0 );

    
    SKP_assert( ( ( SKP_int64 )( ( SKP_int8* )px - ( SKP_int8* )0 ) & 3 ) == 0 );

    
    k = ( length >> 2 ) - 4;
    SKP_assert( k >= 0 && k <= 26 );
    f_Q16 = (SKP_int)freq_table_Q16[ k ];

    
    c_Q16 = SKP_SMULWB( f_Q16, -f_Q16 );
    SKP_assert( c_Q16 >= -32768 );

    
    if( win_type == 1 ) {
        
        S0_Q16 = 0;
        
        S1_Q16 = f_Q16 + SKP_RSHIFT( length, 3 );
    } else {
        
        S0_Q16 = ( 1 << 16 );
        
        S1_Q16 = ( 1 << 16 ) + SKP_RSHIFT( c_Q16, 1 ) + SKP_RSHIFT( length, 4 );
    }

    
    
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
    for( k = 0; k < length; k += 4 ) {
        px32 = *( (SKP_int32 *)&px[ k ] );                        
        px_win[ k ]     = (SKP_int16)SKP_SMULWB( SKP_RSHIFT( S0_Q16 + S1_Q16, 1 ), px32 );
        px_win[ k + 1 ] = (SKP_int16)SKP_SMULWT( S1_Q16, px32 );
        S0_Q16 = SKP_SMULWB( S1_Q16, c_Q16 ) + SKP_LSHIFT( S1_Q16, 1 ) - S0_Q16 + 1;
        S0_Q16 = SKP_min( S0_Q16, ( 1 << 16 ) );

        px32 = *( (SKP_int32 *)&px[k + 2] );                      
        px_win[ k + 2 ] = (SKP_int16)SKP_SMULWB( SKP_RSHIFT( S0_Q16 + S1_Q16, 1 ), px32 );
        px_win[ k + 3 ] = (SKP_int16)SKP_SMULWT( S0_Q16, px32 );
        S1_Q16 = SKP_SMULWB( S0_Q16, c_Q16 ) + SKP_LSHIFT( S0_Q16, 1 ) - S1_Q16;
        S1_Q16 = SKP_min( S1_Q16, ( 1 << 16 ) );
    }
#else
    for( k = 0; k < length; k += 4 ) {
        px_win[ k ]     = (SKP_int16)SKP_SMULWB( SKP_RSHIFT( S0_Q16 + S1_Q16, 1 ), px[ k ] );
        px_win[ k + 1 ] = (SKP_int16)SKP_SMULWB( S1_Q16, px[ k + 1] );
        S0_Q16 = SKP_SMULWB( S1_Q16, c_Q16 ) + SKP_LSHIFT( S1_Q16, 1 ) - S0_Q16 + 1;
        S0_Q16 = SKP_min( S0_Q16, ( 1 << 16 ) );

        px_win[ k + 2 ] = (SKP_int16)SKP_SMULWB( SKP_RSHIFT( S0_Q16 + S1_Q16, 1 ), px[ k + 2] );
        px_win[ k + 3 ] = (SKP_int16)SKP_SMULWB( S0_Q16, px[ k + 3 ] );
        S1_Q16 = SKP_SMULWB( S0_Q16, c_Q16 ) + SKP_LSHIFT( S0_Q16, 1 ) - S1_Q16;
        S1_Q16 = SKP_min( S1_Q16, ( 1 << 16 ) );
    }
#endif
}









#if (EMBEDDED_ARM<4)  
SKP_int16 SKP_Silk_int16_array_maxabs(    
    const SKP_int16        *vec,            
    const SKP_int32        len              
)                    
{
    SKP_int32 max = 0, i, lvl = 0, ind;
	if( len == 0 ) return 0;

    ind = len - 1;
    max = SKP_SMULBB( vec[ ind ], vec[ ind ] );
    for( i = len - 2; i >= 0; i-- ) {
        lvl = SKP_SMULBB( vec[ i ], vec[ i ] );
        if( lvl > max ) {
            max = lvl;
            ind = i;
        }
    }

    
    if( max >= 1073676289 ) { 
        return( SKP_int16_MAX );
    } else {
        if( vec[ ind ] < 0 ) {
            return( -vec[ ind ] );
        } else {
            return(  vec[ ind ] );
        }
    }
}
#endif








void SKP_Silk_autocorr( 
    SKP_int32        *results,                   
    SKP_int          *scale,                     
    const SKP_int16  *inputData,                 
    const SKP_int    inputDataSize,              
    const SKP_int    correlationCount            
)
{
    SKP_int   i, lz, nRightShifts, corrCount;
    SKP_int64 corr64;

    corrCount = SKP_min_int( inputDataSize, correlationCount );

    
    corr64 = SKP_Silk_inner_prod16_aligned_64( inputData, inputData, inputDataSize );

    
    corr64 += 1;

    
    lz = SKP_Silk_CLZ64( corr64 );

    
    nRightShifts = 35 - lz;
    *scale = nRightShifts;

    if( nRightShifts <= 0 ) {
        results[ 0 ] = SKP_LSHIFT( (SKP_int32)SKP_CHECK_FIT32( corr64 ), -nRightShifts );

        
          for( i = 1; i < corrCount; i++ ) {
            results[ i ] = SKP_LSHIFT( SKP_Silk_inner_prod_aligned( inputData, inputData + i, inputDataSize - i ), -nRightShifts );
        }
    } else {
        results[ 0 ] = (SKP_int32)SKP_CHECK_FIT32( SKP_RSHIFT64( corr64, nRightShifts ) );

        
          for( i = 1; i < corrCount; i++ ) {
            results[ i ] =  (SKP_int32)SKP_CHECK_FIT32( SKP_RSHIFT64( SKP_Silk_inner_prod16_aligned_64( inputData, inputData + i, inputDataSize - i ), nRightShifts ) );
        }
    }
}









void SKP_Silk_biquad(
    const SKP_int16      *in,        
    const SKP_int16      *B,         
    const SKP_int16      *A,         
    SKP_int32            *S,         
    SKP_int16            *out,       
    const SKP_int32      len         
)
{
    SKP_int   k, in16;
    SKP_int32 A0_neg, A1_neg, S0, S1, out32, tmp32;

    S0 = S[ 0 ];
    S1 = S[ 1 ];
    A0_neg = -A[ 0 ];
    A1_neg = -A[ 1 ];
    for( k = 0; k < len; k++ ) {
        
        in16  = in[ k ];
        out32 = SKP_SMLABB( S0, in16, B[ 0 ] );

        S0 = SKP_SMLABB( S1, in16, B[ 1 ] );
        S0 += SKP_LSHIFT( SKP_SMULWB( out32, A0_neg ), 3 );

        S1 = SKP_LSHIFT( SKP_SMULWB( out32, A1_neg ), 3 );
        S1 = SKP_SMLABB( S1, in16, B[ 2 ] );
        tmp32    = SKP_RSHIFT_ROUND( out32, 13 ) + 1;
        out[ k ] = (SKP_int16)SKP_SAT16( tmp32 );
    }
    S[ 0 ] = S0;
    S[ 1 ] = S1;
}









void SKP_Silk_biquad_alt(
    const SKP_int16      *in,            
    const SKP_int32      *B_Q28,         
    const SKP_int32      *A_Q28,         
    SKP_int32            *S,             
    SKP_int16            *out,           
    const SKP_int32      len             
)
{
    
    SKP_int   k;
    SKP_int32 inval, A0_U_Q28, A0_L_Q28, A1_U_Q28, A1_L_Q28, out32_Q14;

    
    A0_L_Q28 = ( -A_Q28[ 0 ] ) & 0x00003FFF;        
    A0_U_Q28 = SKP_RSHIFT( -A_Q28[ 0 ], 14 );       
    A1_L_Q28 = ( -A_Q28[ 1 ] ) & 0x00003FFF;        
    A1_U_Q28 = SKP_RSHIFT( -A_Q28[ 1 ], 14 );       
    
    for( k = 0; k < len; k++ ) {
        
        inval = in[ k ];
        out32_Q14 = SKP_LSHIFT( SKP_SMLAWB( S[ 0 ], B_Q28[ 0 ], inval ), 2 );

        S[ 0 ] = S[1] + SKP_RSHIFT_ROUND( SKP_SMULWB( out32_Q14, A0_L_Q28 ), 14 );
        S[ 0 ] = SKP_SMLAWB( S[ 0 ], out32_Q14, A0_U_Q28 );
        S[ 0 ] = SKP_SMLAWB( S[ 0 ], B_Q28[ 1 ], inval);

        S[ 1 ] = SKP_RSHIFT_ROUND( SKP_SMULWB( out32_Q14, A1_L_Q28 ), 14 );
        S[ 1 ] = SKP_SMLAWB( S[ 1 ], out32_Q14, A1_U_Q28 );
        S[ 1 ] = SKP_SMLAWB( S[ 1 ], B_Q28[ 2 ], inval );

        
        out[ k ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT( out32_Q14 + (1<<14) - 1, 14 ) );
    }
}








#define MAX_FRAME_SIZE              544 
#define MAX_NB_SUBFR                4

#define QA                          25
#define N_BITS_HEAD_ROOM            2
#define MIN_RSHIFTS                 -16
#define MAX_RSHIFTS                 (32 - QA)


void SKP_Silk_burg_modified(
    SKP_int32       *res_nrg,           
    SKP_int         *res_nrg_Q,         
    SKP_int32       A_Q16[],            
    const SKP_int16 x[],                
    const SKP_int   subfr_length,       
    const SKP_int   nb_subfr,           
    const SKP_int32 WhiteNoiseFrac_Q32, 
    const SKP_int   D                   
)
{
    SKP_int         k, n, s, lz, rshifts, rshifts_extra;
    SKP_int32       C0, num, nrg, rc_Q31, Atmp_QA, Atmp1, tmp1, tmp2, x1, x2;
    const SKP_int16 *x_ptr;

    SKP_int32       C_first_row[ SKP_Silk_MAX_ORDER_LPC ];
    SKP_int32       C_last_row[  SKP_Silk_MAX_ORDER_LPC ];
    SKP_int32       Af_QA[       SKP_Silk_MAX_ORDER_LPC ];

    SKP_int32       CAf[ SKP_Silk_MAX_ORDER_LPC + 1 ];
    SKP_int32       CAb[ SKP_Silk_MAX_ORDER_LPC + 1 ];

    SKP_assert( subfr_length * nb_subfr <= MAX_FRAME_SIZE );
    SKP_assert( nb_subfr <= MAX_NB_SUBFR );


    
    SKP_Silk_sum_sqr_shift( &C0, &rshifts, x, nb_subfr * subfr_length );
    if( rshifts > MAX_RSHIFTS ) {
        C0 = SKP_LSHIFT32( C0, rshifts - MAX_RSHIFTS );
        SKP_assert( C0 > 0 );
        rshifts = MAX_RSHIFTS;
    } else {
        lz = SKP_Silk_CLZ32( C0 ) - 1;
        rshifts_extra = N_BITS_HEAD_ROOM - lz;
        if( rshifts_extra > 0 ) {
            rshifts_extra = SKP_min( rshifts_extra, MAX_RSHIFTS - rshifts );
            C0 = SKP_RSHIFT32( C0, rshifts_extra );
        } else {
            rshifts_extra = SKP_max( rshifts_extra, MIN_RSHIFTS - rshifts );
            C0 = SKP_LSHIFT32( C0, -rshifts_extra );
        }
        rshifts += rshifts_extra;
    }
    SKP_memset( C_first_row, 0, SKP_Silk_MAX_ORDER_LPC * sizeof( SKP_int32 ) );
    if( rshifts > 0 ) {
        for( s = 0; s < nb_subfr; s++ ) {
            x_ptr = x + s * subfr_length;
            for( n = 1; n < D + 1; n++ ) {
                C_first_row[ n - 1 ] += (SKP_int32)SKP_RSHIFT64( 
                    SKP_Silk_inner_prod16_aligned_64( x_ptr, x_ptr + n, subfr_length - n ), rshifts );
            }
        }
    } else {
        for( s = 0; s < nb_subfr; s++ ) {
            x_ptr = x + s * subfr_length;
            for( n = 1; n < D + 1; n++ ) {
                C_first_row[ n - 1 ] += SKP_LSHIFT32( 
                    SKP_Silk_inner_prod_aligned( x_ptr, x_ptr + n, subfr_length - n ), -rshifts );
            }
        }
    }
    SKP_memcpy( C_last_row, C_first_row, SKP_Silk_MAX_ORDER_LPC * sizeof( SKP_int32 ) );
    
    
    CAb[ 0 ] = CAf[ 0 ] = C0 + SKP_SMMUL( WhiteNoiseFrac_Q32, C0 ) + 1;         

    for( n = 0; n < D; n++ ) {
        
        
        
        
        if( rshifts > -2 ) {
            for( s = 0; s < nb_subfr; s++ ) {
                x_ptr = x + s * subfr_length;
                x1  = -SKP_LSHIFT32( (SKP_int32)x_ptr[ n ],                    16 - rshifts );      
                x2  = -SKP_LSHIFT32( (SKP_int32)x_ptr[ subfr_length - n - 1 ], 16 - rshifts );      
                tmp1 = SKP_LSHIFT32( (SKP_int32)x_ptr[ n ],                    QA - 16 );           
                tmp2 = SKP_LSHIFT32( (SKP_int32)x_ptr[ subfr_length - n - 1 ], QA - 16 );           
                for( k = 0; k < n; k++ ) {
                    C_first_row[ k ] = SKP_SMLAWB( C_first_row[ k ], x1, x_ptr[ n - k - 1 ]            ); 
                    C_last_row[ k ]  = SKP_SMLAWB( C_last_row[ k ],  x2, x_ptr[ subfr_length - n + k ] ); 
                    Atmp_QA = Af_QA[ k ];
                    tmp1 = SKP_SMLAWB( tmp1, Atmp_QA, x_ptr[ n - k - 1 ]            );              
                    tmp2 = SKP_SMLAWB( tmp2, Atmp_QA, x_ptr[ subfr_length - n + k ] );              
                }
                tmp1 = SKP_LSHIFT32( -tmp1, 32 - QA - rshifts );                                    
                tmp2 = SKP_LSHIFT32( -tmp2, 32 - QA - rshifts );                                    
                for( k = 0; k <= n; k++ ) {
                    CAf[ k ] = SKP_SMLAWB( CAf[ k ], tmp1, x_ptr[ n - k ]                    );     
                    CAb[ k ] = SKP_SMLAWB( CAb[ k ], tmp2, x_ptr[ subfr_length - n + k - 1 ] );     
                }
            }
        } else {
            for( s = 0; s < nb_subfr; s++ ) {
                x_ptr = x + s * subfr_length;
                x1  = -SKP_LSHIFT32( (SKP_int32)x_ptr[ n ],                    -rshifts );          
                x2  = -SKP_LSHIFT32( (SKP_int32)x_ptr[ subfr_length - n - 1 ], -rshifts );          
                tmp1 = SKP_LSHIFT32( (SKP_int32)x_ptr[ n ],                    17 );                
                tmp2 = SKP_LSHIFT32( (SKP_int32)x_ptr[ subfr_length - n - 1 ], 17 );                
                for( k = 0; k < n; k++ ) {
                    C_first_row[ k ] = SKP_MLA( C_first_row[ k ], x1, x_ptr[ n - k - 1 ]            ); 
                    C_last_row[ k ]  = SKP_MLA( C_last_row[ k ],  x2, x_ptr[ subfr_length - n + k ] ); 
                    Atmp1 = SKP_RSHIFT_ROUND( Af_QA[ k ], QA - 17 );                                
                    tmp1 = SKP_MLA( tmp1, x_ptr[ n - k - 1 ],            Atmp1 );                   
                    tmp2 = SKP_MLA( tmp2, x_ptr[ subfr_length - n + k ], Atmp1 );                   
                }
                tmp1 = -tmp1;                                                                       
                tmp2 = -tmp2;                                                                       
                for( k = 0; k <= n; k++ ) {
                    CAf[ k ] = SKP_SMLAWW( CAf[ k ], tmp1, 
                        SKP_LSHIFT32( (SKP_int32)x_ptr[ n - k ], -rshifts - 1 ) );                  
                    CAb[ k ] = SKP_SMLAWW( CAb[ k ], tmp2, 
                        SKP_LSHIFT32( (SKP_int32)x_ptr[ subfr_length - n + k - 1 ], -rshifts - 1 ) );
                }
            }
        }

        
        tmp1 = C_first_row[ n ];                                                            
        tmp2 = C_last_row[ n ];                                                             
        num  = 0;                                                                           
        nrg  = SKP_ADD32( CAb[ 0 ], CAf[ 0 ] );                                             
        for( k = 0; k < n; k++ ) {
            Atmp_QA = Af_QA[ k ];
            lz = SKP_Silk_CLZ32( SKP_abs( Atmp_QA ) ) - 1;
            lz = SKP_min( 32 - QA, lz );
            Atmp1 = SKP_LSHIFT32( Atmp_QA, lz );                                            

            tmp1 = SKP_ADD_LSHIFT32( tmp1, SKP_SMMUL( C_last_row[  n - k - 1 ], Atmp1 ), 32 - QA - lz );    
            tmp2 = SKP_ADD_LSHIFT32( tmp2, SKP_SMMUL( C_first_row[ n - k - 1 ], Atmp1 ), 32 - QA - lz );    
            num  = SKP_ADD_LSHIFT32( num,  SKP_SMMUL( CAb[ n - k ],             Atmp1 ), 32 - QA - lz );    
            nrg  = SKP_ADD_LSHIFT32( nrg,  SKP_SMMUL( SKP_ADD32( CAb[ k + 1 ], CAf[ k + 1 ] ), 
                                                                                Atmp1 ), 32 - QA - lz );    
        }
        CAf[ n + 1 ] = tmp1;                                                                
        CAb[ n + 1 ] = tmp2;                                                                
        num = SKP_ADD32( num, tmp2 );                                                       
        num = SKP_LSHIFT32( -num, 1 );                                                      

        
        if( SKP_abs( num ) < nrg ) {
            rc_Q31 = SKP_DIV32_varQ( num, nrg, 31 );
        } else {
            
            SKP_memset( &Af_QA[ n ], 0, ( D - n ) * sizeof( SKP_int32 ) );
            SKP_assert( 0 );
            break;
        }

        
        for( k = 0; k < (n + 1) >> 1; k++ ) {
            tmp1 = Af_QA[ k ];                                                              
            tmp2 = Af_QA[ n - k - 1 ];                                                      
            Af_QA[ k ]         = SKP_ADD_LSHIFT32( tmp1, SKP_SMMUL( tmp2, rc_Q31 ), 1 );    
            Af_QA[ n - k - 1 ] = SKP_ADD_LSHIFT32( tmp2, SKP_SMMUL( tmp1, rc_Q31 ), 1 );    
        }
        Af_QA[ n ] = SKP_RSHIFT32( rc_Q31, 31 - QA );                                       

        
        for( k = 0; k <= n + 1; k++ ) {
            tmp1 = CAf[ k ];                                                                
            tmp2 = CAb[ n - k + 1 ];                                                        
            CAf[ k ]         = SKP_ADD_LSHIFT32( tmp1, SKP_SMMUL( tmp2, rc_Q31 ), 1 );      
            CAb[ n - k + 1 ] = SKP_ADD_LSHIFT32( tmp2, SKP_SMMUL( tmp1, rc_Q31 ), 1 );      
        }
    }

    
    nrg  = CAf[ 0 ];                                                                        
    tmp1 = 1 << 16;                                                                         
    for( k = 0; k < D; k++ ) {
        Atmp1 = SKP_RSHIFT_ROUND( Af_QA[ k ], QA - 16 );                                    
        nrg  = SKP_SMLAWW( nrg, CAf[ k + 1 ], Atmp1 );                                      
        tmp1 = SKP_SMLAWW( tmp1, Atmp1, Atmp1 );                                            
        A_Q16[ k ] = -Atmp1;
    }
    *res_nrg = SKP_SMLAWW( nrg, SKP_SMMUL( WhiteNoiseFrac_Q32, C0 ), -tmp1 );               
    *res_nrg_Q = -rshifts;
}







void SKP_Silk_bwexpander( 
    SKP_int16            *ar,        
    const SKP_int        d,          
    SKP_int32            chirp_Q16   
)
{
    SKP_int   i;
    SKP_int32 chirp_minus_one_Q16;

    chirp_minus_one_Q16 = chirp_Q16 - 65536;

    
    
    for( i = 0; i < d - 1; i++ ) {
        ar[ i ]    = (SKP_int16)SKP_RSHIFT_ROUND( SKP_MUL( chirp_Q16, ar[ i ]             ), 16 );
        chirp_Q16 +=            SKP_RSHIFT_ROUND( SKP_MUL( chirp_Q16, chirp_minus_one_Q16 ), 16 );
    }
    ar[ d - 1 ] = (SKP_int16)SKP_RSHIFT_ROUND( SKP_MUL( chirp_Q16, ar[ d - 1 ] ), 16 );
}







void SKP_Silk_bwexpander_32( 
    SKP_int32        *ar,      
    const SKP_int    d,        
    SKP_int32        chirp_Q16 
)
{
    SKP_int   i;
    SKP_int32 tmp_chirp_Q16;

    tmp_chirp_Q16 = chirp_Q16;
    for( i = 0; i < d - 1; i++ ) {
        ar[ i ]       = SKP_SMULWW( ar[ i ],   tmp_chirp_Q16 );
        tmp_chirp_Q16 = SKP_SMULWW( chirp_Q16, tmp_chirp_Q16 );
    }
    ar[ d - 1 ] = SKP_SMULWW( ar[ d - 1 ], tmp_chirp_Q16 );
}









#define SKP_enc_map(a)                  ( SKP_RSHIFT( (a), 15 ) + 1 )
#define SKP_dec_map(a)                  ( SKP_LSHIFT( (a),  1 ) - 1 )


void SKP_Silk_encode_signs(
    SKP_Silk_range_coder_state      *sRC,               
    const SKP_int8                  q[],                
    const SKP_int                   length,             
    const SKP_int                   sigtype,            
    const SKP_int                   QuantOffsetType,    
    const SKP_int                   RateLevelIndex      
)
{
    SKP_int i;
    SKP_int inData;
    SKP_uint16 cdf[ 3 ];

    i = SKP_SMULBB( N_RATE_LEVELS - 1, SKP_LSHIFT( sigtype, 1 ) + QuantOffsetType ) + RateLevelIndex;
    cdf[ 0 ] = 0;
    cdf[ 1 ] = SKP_Silk_sign_CDF[ i ];
    cdf[ 2 ] = 65535;
    
    for( i = 0; i < length; i++ ) {
        if( q[ i ] != 0 ) {
            inData = SKP_enc_map( q[ i ] ); 
            SKP_Silk_range_encoder( sRC, inData, cdf );
        }
    }
}


void SKP_Silk_decode_signs(
    SKP_Silk_range_coder_state      *sRC,               
    SKP_int                         q[],                
    const SKP_int                   length,             
    const SKP_int                   sigtype,            
    const SKP_int                   QuantOffsetType,    
    const SKP_int                   RateLevelIndex      
)
{
    SKP_int i;
    SKP_int data;
    SKP_uint16 cdf[ 3 ];

    i = SKP_SMULBB( N_RATE_LEVELS - 1, SKP_LSHIFT( sigtype, 1 ) + QuantOffsetType ) + RateLevelIndex;
    cdf[ 0 ] = 0;
    cdf[ 1 ] = SKP_Silk_sign_CDF[ i ];
    cdf[ 2 ] = 65535;
    
    for( i = 0; i < length; i++ ) {
        if( q[ i ] > 0 ) {
            SKP_Silk_range_decoder( &data, sRC, cdf, 1 );
            
            
            q[ i ] *= SKP_dec_map( data );
        }
    }
}








SKP_int SKP_Silk_control_audio_bandwidth(
    SKP_Silk_encoder_state      *psEncC,            
    const SKP_int32             TargetRate_bps      
)
{
    SKP_int fs_kHz;

    fs_kHz = psEncC->fs_kHz;
    if( fs_kHz == 0 ) {
        
        if( TargetRate_bps >= SWB2WB_BITRATE_BPS ) {
            fs_kHz = 24;
        } else if( TargetRate_bps >= WB2MB_BITRATE_BPS ) {
            fs_kHz = 16;
        } else if( TargetRate_bps >= MB2NB_BITRATE_BPS ) {
            fs_kHz = 12;
        } else {
            fs_kHz = 8;
        }
        
        fs_kHz = SKP_min( fs_kHz, SKP_DIV32_16( psEncC->API_fs_Hz, 1000 ) );
        fs_kHz = SKP_min( fs_kHz, psEncC->maxInternal_fs_kHz );
    } else if( SKP_SMULBB( fs_kHz, 1000 ) > psEncC->API_fs_Hz || fs_kHz > psEncC->maxInternal_fs_kHz ) {
        
        fs_kHz = SKP_DIV32_16( psEncC->API_fs_Hz, 1000 );
        fs_kHz = SKP_min( fs_kHz, psEncC->maxInternal_fs_kHz );
    } else {
        
        if( psEncC->API_fs_Hz > 8000 ) {
            
            psEncC->bitrateDiff += SKP_MUL( psEncC->PacketSize_ms, TargetRate_bps - psEncC->bitrate_threshold_down );
            psEncC->bitrateDiff  = SKP_min( psEncC->bitrateDiff, 0 );

            if( psEncC->vadFlag == NO_VOICE_ACTIVITY ) { 
                
#if SWITCH_TRANSITION_FILTERING 
                if( ( psEncC->sLP.transition_frame_no == 0 ) &&                         
                    ( psEncC->bitrateDiff <= -ACCUM_BITS_DIFF_THRESHOLD ||              
                    ( psEncC->sSWBdetect.WB_detected * psEncC->fs_kHz == 24 ) ) ) {     
                        psEncC->sLP.transition_frame_no = 1;                            
                        psEncC->sLP.mode                = 0;                            
                } else if( 
                    ( psEncC->sLP.transition_frame_no >= TRANSITION_FRAMES_DOWN ) &&    
                    ( psEncC->sLP.mode == 0 ) ) {                                       
                        psEncC->sLP.transition_frame_no = 0;                            
#else
                if( psEncC->bitrateDiff <= -ACCUM_BITS_DIFF_THRESHOLD ) {                
#endif            
                    psEncC->bitrateDiff = 0;

                    
                    if( psEncC->fs_kHz == 24 ) {
                        fs_kHz = 16;
                    } else if( psEncC->fs_kHz == 16 ) {
                        fs_kHz = 12;
                    } else {
                        SKP_assert( psEncC->fs_kHz == 12 );
                        fs_kHz = 8;
                    }
                }

                
                if( ( ( psEncC->fs_kHz * 1000 < psEncC->API_fs_Hz ) &&
                    ( TargetRate_bps >= psEncC->bitrate_threshold_up ) && 
                    ( psEncC->sSWBdetect.WB_detected * psEncC->fs_kHz < 16 ) ) && 
                    ( ( ( psEncC->fs_kHz == 16 ) && ( psEncC->maxInternal_fs_kHz >= 24 ) ) || 
                    (   ( psEncC->fs_kHz == 12 ) && ( psEncC->maxInternal_fs_kHz >= 16 ) ) ||
                    (   ( psEncC->fs_kHz ==  8 ) && ( psEncC->maxInternal_fs_kHz >= 12 ) ) ) 
#if SWITCH_TRANSITION_FILTERING
                    && ( psEncC->sLP.transition_frame_no == 0 ) ) { 
                        psEncC->sLP.mode = 1; 
#else
                    ) {
#endif
                    psEncC->bitrateDiff = 0;

                    
                    if( psEncC->fs_kHz == 8 ) {
                        fs_kHz = 12;
                    } else if( psEncC->fs_kHz == 12 ) {
                        fs_kHz = 16;
                    } else {
                        SKP_assert( psEncC->fs_kHz == 16 );
                        fs_kHz = 24;
                    }
                }
            }
        }

#if SWITCH_TRANSITION_FILTERING
        
        if( ( psEncC->sLP.mode == 1 ) &&
            ( psEncC->sLP.transition_frame_no >= TRANSITION_FRAMES_UP ) && 
            ( psEncC->vadFlag == NO_VOICE_ACTIVITY ) ) {

                psEncC->sLP.transition_frame_no = 0;

                
                SKP_memset( psEncC->sLP.In_LP_State, 0, 2 * sizeof( SKP_int32 ) );
        }
#endif
    }



    return fs_kHz;
}











SKP_INLINE SKP_int SKP_Silk_setup_complexity(
    SKP_Silk_encoder_state          *psEncC,            
    SKP_int                         Complexity          
)
{
    SKP_int ret = SKP_SILK_NO_ERROR;

    
    if( LOW_COMPLEXITY_ONLY && Complexity != 0 ) { 
        ret = SKP_SILK_ENC_INVALID_COMPLEXITY_SETTING;
    }

    
    if( Complexity == 0 || LOW_COMPLEXITY_ONLY ) {
        
        psEncC->Complexity                      = 0;
        psEncC->pitchEstimationComplexity       = PITCH_EST_COMPLEXITY_LC_MODE;
        psEncC->pitchEstimationThreshold_Q16    = SKP_FIX_CONST( FIND_PITCH_CORRELATION_THRESHOLD_LC_MODE, 16 );
        psEncC->pitchEstimationLPCOrder         = 6;
        psEncC->shapingLPCOrder                 = 8;
        psEncC->la_shape                        = 3 * psEncC->fs_kHz;
        psEncC->nStatesDelayedDecision          = 1;
        psEncC->useInterpolatedNLSFs            = 0;
        psEncC->LTPQuantLowComplexity           = 1;
        psEncC->NLSF_MSVQ_Survivors             = MAX_NLSF_MSVQ_SURVIVORS_LC_MODE;
        psEncC->warping_Q16                     = 0;
    } else if( Complexity == 1 ) {
        
        psEncC->Complexity                      = 1;
        psEncC->pitchEstimationComplexity       = PITCH_EST_COMPLEXITY_MC_MODE;
        psEncC->pitchEstimationThreshold_Q16    = SKP_FIX_CONST( FIND_PITCH_CORRELATION_THRESHOLD_MC_MODE, 16 );
        psEncC->pitchEstimationLPCOrder         = 12;
        psEncC->shapingLPCOrder                 = 12;
        psEncC->la_shape                        = 5 * psEncC->fs_kHz;
        psEncC->nStatesDelayedDecision          = 2;
        psEncC->useInterpolatedNLSFs            = 0;
        psEncC->LTPQuantLowComplexity           = 0;
        psEncC->NLSF_MSVQ_Survivors             = MAX_NLSF_MSVQ_SURVIVORS_MC_MODE;
        psEncC->warping_Q16                     = psEncC->fs_kHz * SKP_FIX_CONST( WARPING_MULTIPLIER, 16 );
    } else if( Complexity == 2 ) {
        
        psEncC->Complexity                      = 2;
        psEncC->pitchEstimationComplexity       = PITCH_EST_COMPLEXITY_HC_MODE;
        psEncC->pitchEstimationThreshold_Q16    = SKP_FIX_CONST( FIND_PITCH_CORRELATION_THRESHOLD_HC_MODE, 16 );
        psEncC->pitchEstimationLPCOrder         = 16;
        psEncC->shapingLPCOrder                 = 16;
        psEncC->la_shape                        = 5 * psEncC->fs_kHz;
        psEncC->nStatesDelayedDecision          = MAX_DEL_DEC_STATES;
        psEncC->useInterpolatedNLSFs            = 1;
        psEncC->LTPQuantLowComplexity           = 0;
        psEncC->NLSF_MSVQ_Survivors             = MAX_NLSF_MSVQ_SURVIVORS;
        psEncC->warping_Q16                     = psEncC->fs_kHz * SKP_FIX_CONST( WARPING_MULTIPLIER, 16 );
    } else {
        ret = SKP_SILK_ENC_INVALID_COMPLEXITY_SETTING;
    }

    
    psEncC->pitchEstimationLPCOrder             = SKP_min_int( psEncC->pitchEstimationLPCOrder, psEncC->predictLPCOrder );
    psEncC->shapeWinLength                      = 5 * psEncC->fs_kHz + 2 * psEncC->la_shape;

    SKP_assert( psEncC->pitchEstimationLPCOrder <= MAX_FIND_PITCH_LPC_ORDER );
    SKP_assert( psEncC->shapingLPCOrder         <= MAX_SHAPE_LPC_ORDER      );
    SKP_assert( psEncC->nStatesDelayedDecision  <= MAX_DEL_DEC_STATES       );
    SKP_assert( psEncC->warping_Q16             <= 32767                    );
    SKP_assert( psEncC->la_shape                <= LA_SHAPE_MAX             );
    SKP_assert( psEncC->shapeWinLength          <= SHAPE_LPC_WIN_MAX        );

    return( ret );
}

SKP_INLINE SKP_int SKP_Silk_setup_resamplers_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_int                         fs_kHz              
);

SKP_INLINE SKP_int SKP_Silk_setup_packetsize_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_int                         PacketSize_ms       
);

SKP_INLINE SKP_int SKP_Silk_setup_fs_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_int                         fs_kHz              
);

SKP_INLINE SKP_int SKP_Silk_setup_rate_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_int32                       TargetRate_bps      
);

SKP_INLINE SKP_int SKP_Silk_setup_LBRR_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc              
);


SKP_int SKP_Silk_control_encoder_FIX( 
    SKP_Silk_encoder_state_FIX  *psEnc,                 
    const SKP_int               PacketSize_ms,          
    const SKP_int32             TargetRate_bps,         
    const SKP_int               PacketLoss_perc,        
    const SKP_int               DTX_enabled,            
    const SKP_int               Complexity              
)
{
    SKP_int   fs_kHz, ret = 0;

    if( psEnc->sCmn.controlled_since_last_payload != 0 ) {
        if( psEnc->sCmn.API_fs_Hz != psEnc->sCmn.prev_API_fs_Hz && psEnc->sCmn.fs_kHz > 0 ) {
            
            ret += SKP_Silk_setup_resamplers_FIX( psEnc, psEnc->sCmn.fs_kHz );
        }
        return ret;
    }

    

    
    
    
    fs_kHz = SKP_Silk_control_audio_bandwidth( &psEnc->sCmn, TargetRate_bps );

    
    
    
    ret += SKP_Silk_setup_resamplers_FIX( psEnc, fs_kHz );

    
    
    
    ret += SKP_Silk_setup_packetsize_FIX( psEnc, PacketSize_ms );

    
    
    
    ret += SKP_Silk_setup_fs_FIX( psEnc, fs_kHz );

    
    
    
    ret += SKP_Silk_setup_complexity( &psEnc->sCmn, Complexity );

    
    
    
    ret += SKP_Silk_setup_rate_FIX( psEnc, TargetRate_bps );

    
    
    
    if( ( PacketLoss_perc < 0 ) || ( PacketLoss_perc > 100 ) ) {
        ret = SKP_SILK_ENC_INVALID_LOSS_RATE;
    }
    psEnc->sCmn.PacketLoss_perc = PacketLoss_perc;

    
    
    
    ret += SKP_Silk_setup_LBRR_FIX( psEnc );

    
    
    
    if( DTX_enabled < 0 || DTX_enabled > 1 ) {
        ret = SKP_SILK_ENC_INVALID_DTX_SETTING;
    }
    psEnc->sCmn.useDTX = DTX_enabled;
    psEnc->sCmn.controlled_since_last_payload = 1;

    return ret;
}


void SKP_Silk_LBRR_ctrl_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,     
    SKP_Silk_encoder_control        *psEncCtrlC 
)
{
    SKP_int LBRR_usage;

    if( psEnc->sCmn.LBRR_enabled ) {
        

        
        
        LBRR_usage = SKP_SILK_NO_LBRR;
        if( psEnc->speech_activity_Q8 > SKP_FIX_CONST( LBRR_SPEECH_ACTIVITY_THRES, 8 ) && psEnc->sCmn.PacketLoss_perc > LBRR_LOSS_THRES ) { 
            LBRR_usage = SKP_SILK_ADD_LBRR_TO_PLUS1;
        }
        psEncCtrlC->LBRR_usage = LBRR_usage;
    } else {
        psEncCtrlC->LBRR_usage = SKP_SILK_NO_LBRR;
    }
}

SKP_INLINE SKP_int SKP_Silk_setup_resamplers_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_int                         fs_kHz              
)
{
    SKP_int ret = SKP_SILK_NO_ERROR;
    
    if( psEnc->sCmn.fs_kHz != fs_kHz || psEnc->sCmn.prev_API_fs_Hz != psEnc->sCmn.API_fs_Hz ) {

        if( psEnc->sCmn.fs_kHz == 0 ) {
            
            ret += SKP_Silk_resampler_init( &psEnc->sCmn.resampler_state, psEnc->sCmn.API_fs_Hz, fs_kHz * 1000 );
        } else {
            
            SKP_int16 x_buf_API_fs_Hz[ ( 2 * MAX_FRAME_LENGTH + LA_SHAPE_MAX ) * ( MAX_API_FS_KHZ / 8 ) ];

            SKP_int32 nSamples_temp = SKP_LSHIFT( psEnc->sCmn.frame_length, 1 ) + LA_SHAPE_MS * psEnc->sCmn.fs_kHz;

            if( SKP_SMULBB( fs_kHz, 1000 ) < psEnc->sCmn.API_fs_Hz && psEnc->sCmn.fs_kHz != 0 ) {
                

                SKP_Silk_resampler_state_struct  temp_resampler_state;

                
                ret += SKP_Silk_resampler_init( &temp_resampler_state, SKP_SMULBB( psEnc->sCmn.fs_kHz, 1000 ), psEnc->sCmn.API_fs_Hz );

                
                ret += SKP_Silk_resampler( &temp_resampler_state, x_buf_API_fs_Hz, psEnc->x_buf, nSamples_temp );

                
                nSamples_temp = SKP_DIV32_16( nSamples_temp * psEnc->sCmn.API_fs_Hz, SKP_SMULBB( psEnc->sCmn.fs_kHz, 1000 ) );

                
                ret += SKP_Silk_resampler_init( &psEnc->sCmn.resampler_state, psEnc->sCmn.API_fs_Hz, SKP_SMULBB( fs_kHz, 1000 ) );

            } else {
                
                SKP_memcpy( x_buf_API_fs_Hz, psEnc->x_buf, nSamples_temp * sizeof( SKP_int16 ) );
            }

            if( 1000 * fs_kHz != psEnc->sCmn.API_fs_Hz ) {
                
                ret += SKP_Silk_resampler( &psEnc->sCmn.resampler_state, psEnc->x_buf, x_buf_API_fs_Hz, nSamples_temp );
            }
        }
    }

    psEnc->sCmn.prev_API_fs_Hz = psEnc->sCmn.API_fs_Hz;

    return(ret);
}

SKP_INLINE SKP_int SKP_Silk_setup_packetsize_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_int                         PacketSize_ms       
)
{
    SKP_int ret = SKP_SILK_NO_ERROR;

    
    if( ( PacketSize_ms !=  20 ) && 
        ( PacketSize_ms !=  40 ) && 
        ( PacketSize_ms !=  60 ) && 
        ( PacketSize_ms !=  80 ) && 
        ( PacketSize_ms != 100 ) ) {
        ret = SKP_SILK_ENC_PACKET_SIZE_NOT_SUPPORTED;
    } else {
        if( PacketSize_ms != psEnc->sCmn.PacketSize_ms ) {
            psEnc->sCmn.PacketSize_ms = PacketSize_ms;

            
            SKP_Silk_LBRR_reset( &psEnc->sCmn );
        }
    }
    return(ret);
}

SKP_INLINE SKP_int SKP_Silk_setup_fs_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_int                         fs_kHz              
)
{
    SKP_int ret = SKP_SILK_NO_ERROR;

    
    if( psEnc->sCmn.fs_kHz != fs_kHz ) {
        
        SKP_memset( &psEnc->sShape,           0,                            sizeof( SKP_Silk_shape_state_FIX ) );
        SKP_memset( &psEnc->sPrefilt,         0,                            sizeof( SKP_Silk_prefilter_state_FIX ) );
        SKP_memset( &psEnc->sPred,            0,                            sizeof( SKP_Silk_predict_state_FIX ) );
        SKP_memset( &psEnc->sCmn.sNSQ,        0,                            sizeof( SKP_Silk_nsq_state ) );
        SKP_memset( psEnc->sCmn.sNSQ_LBRR.xq, 0, ( 2 * MAX_FRAME_LENGTH ) * sizeof( SKP_int16 ) );
        SKP_memset( psEnc->sCmn.LBRR_buffer,  0,           MAX_LBRR_DELAY * sizeof( SKP_SILK_LBRR_struct ) );
#if SWITCH_TRANSITION_FILTERING
        SKP_memset( psEnc->sCmn.sLP.In_LP_State, 0, 2 * sizeof( SKP_int32 ) );
        if( psEnc->sCmn.sLP.mode == 1 ) {
            
            psEnc->sCmn.sLP.transition_frame_no = 1;
        } else {
            
            psEnc->sCmn.sLP.transition_frame_no = 0;
        }
#endif
        psEnc->sCmn.inputBufIx          = 0;
        psEnc->sCmn.nFramesInPayloadBuf = 0;
        psEnc->sCmn.nBytesInPayloadBuf  = 0;
        psEnc->sCmn.oldest_LBRR_idx     = 0;
        psEnc->sCmn.TargetRate_bps      = 0; 

        SKP_memset( psEnc->sPred.prev_NLSFq_Q15, 0, MAX_LPC_ORDER * sizeof( SKP_int ) );

        
        psEnc->sCmn.prevLag                     = 100;
        psEnc->sCmn.prev_sigtype                = SIG_TYPE_UNVOICED;
        psEnc->sCmn.first_frame_after_reset     = 1;
        psEnc->sPrefilt.lagPrev                 = 100;
        psEnc->sShape.LastGainIndex             = 1;
        psEnc->sCmn.sNSQ.lagPrev                = 100;
        psEnc->sCmn.sNSQ.prev_inv_gain_Q16      = 65536;
        psEnc->sCmn.sNSQ_LBRR.prev_inv_gain_Q16 = 65536;

        psEnc->sCmn.fs_kHz = fs_kHz;
        if( psEnc->sCmn.fs_kHz == 8 ) {
            psEnc->sCmn.predictLPCOrder = MIN_LPC_ORDER;
            psEnc->sCmn.psNLSF_CB[ 0 ]  = &SKP_Silk_NLSF_CB0_10;
            psEnc->sCmn.psNLSF_CB[ 1 ]  = &SKP_Silk_NLSF_CB1_10;
        } else {
            psEnc->sCmn.predictLPCOrder = MAX_LPC_ORDER;
            psEnc->sCmn.psNLSF_CB[ 0 ]  = &SKP_Silk_NLSF_CB0_16;
            psEnc->sCmn.psNLSF_CB[ 1 ]  = &SKP_Silk_NLSF_CB1_16;
        }
        psEnc->sCmn.frame_length   = SKP_SMULBB( FRAME_LENGTH_MS, fs_kHz );
        psEnc->sCmn.subfr_length   = SKP_DIV32_16( psEnc->sCmn.frame_length, NB_SUBFR );
        psEnc->sCmn.la_pitch       = SKP_SMULBB( LA_PITCH_MS, fs_kHz );
        psEnc->sPred.min_pitch_lag = SKP_SMULBB(  3, fs_kHz );
        psEnc->sPred.max_pitch_lag = SKP_SMULBB( 18, fs_kHz );
        psEnc->sPred.pitch_LPC_win_length = SKP_SMULBB( FIND_PITCH_LPC_WIN_MS, fs_kHz );
        if( psEnc->sCmn.fs_kHz == 24 ) {
            psEnc->mu_LTP_Q8 = SKP_FIX_CONST( MU_LTP_QUANT_SWB, 8 );
            psEnc->sCmn.bitrate_threshold_up   = SKP_int32_MAX;
            psEnc->sCmn.bitrate_threshold_down = SWB2WB_BITRATE_BPS; 
        } else if( psEnc->sCmn.fs_kHz == 16 ) {
            psEnc->mu_LTP_Q8 = SKP_FIX_CONST( MU_LTP_QUANT_WB, 8 );
            psEnc->sCmn.bitrate_threshold_up   = WB2SWB_BITRATE_BPS;
            psEnc->sCmn.bitrate_threshold_down = WB2MB_BITRATE_BPS; 
        } else if( psEnc->sCmn.fs_kHz == 12 ) {
            psEnc->mu_LTP_Q8 = SKP_FIX_CONST( MU_LTP_QUANT_MB, 8 );
            psEnc->sCmn.bitrate_threshold_up   = MB2WB_BITRATE_BPS;
            psEnc->sCmn.bitrate_threshold_down = MB2NB_BITRATE_BPS;
        } else {
            psEnc->mu_LTP_Q8 = SKP_FIX_CONST( MU_LTP_QUANT_NB, 8 );
            psEnc->sCmn.bitrate_threshold_up   = NB2MB_BITRATE_BPS;
            psEnc->sCmn.bitrate_threshold_down = 0;
        }
        psEnc->sCmn.fs_kHz_changed = 1;

        
        SKP_assert( ( psEnc->sCmn.subfr_length * NB_SUBFR ) == psEnc->sCmn.frame_length );
    }
    return( ret );
}

SKP_INLINE SKP_int SKP_Silk_setup_rate_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_int32                       TargetRate_bps      
)
{
    SKP_int k, ret = SKP_SILK_NO_ERROR;
    SKP_int32 frac_Q6;
    const SKP_int32 *rateTable;

    
    if( TargetRate_bps != psEnc->sCmn.TargetRate_bps ) {
        psEnc->sCmn.TargetRate_bps = TargetRate_bps;

        
        if( psEnc->sCmn.fs_kHz == 8 ) {
            rateTable = TargetRate_table_NB;
        } else if( psEnc->sCmn.fs_kHz == 12 ) {
            rateTable = TargetRate_table_MB;
        } else if( psEnc->sCmn.fs_kHz == 16 ) {
            rateTable = TargetRate_table_WB;
        } else {
            rateTable = TargetRate_table_SWB;
        }
        for( k = 1; k < TARGET_RATE_TAB_SZ; k++ ) {
            
            if( TargetRate_bps <= rateTable[ k ] ) {
                frac_Q6 = SKP_DIV32( SKP_LSHIFT( TargetRate_bps - rateTable[ k - 1 ], 6 ), 
                                                 rateTable[ k ] - rateTable[ k - 1 ] );
                psEnc->SNR_dB_Q7 = SKP_LSHIFT( SNR_table_Q1[ k - 1 ], 6 ) + SKP_MUL( frac_Q6, SNR_table_Q1[ k ] - SNR_table_Q1[ k - 1 ] );
                break;
            }
        }
    }
    return( ret );
}

SKP_INLINE SKP_int SKP_Silk_setup_LBRR_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc              
)
{
    SKP_int   ret = SKP_SILK_NO_ERROR;
#if USE_LBRR
    SKP_int32 LBRRRate_thres_bps;

    if( psEnc->sCmn.useInBandFEC < 0 || psEnc->sCmn.useInBandFEC > 1 ) {
        ret = SKP_SILK_ENC_INVALID_INBAND_FEC_SETTING;
    }
    
    psEnc->sCmn.LBRR_enabled = psEnc->sCmn.useInBandFEC;
    if( psEnc->sCmn.fs_kHz == 8 ) {
        LBRRRate_thres_bps = INBAND_FEC_MIN_RATE_BPS - 9000;
    } else if( psEnc->sCmn.fs_kHz == 12 ) {
        LBRRRate_thres_bps = INBAND_FEC_MIN_RATE_BPS - 6000;;
    } else if( psEnc->sCmn.fs_kHz == 16 ) {
        LBRRRate_thres_bps = INBAND_FEC_MIN_RATE_BPS - 3000;
    } else {
        LBRRRate_thres_bps = INBAND_FEC_MIN_RATE_BPS;
    }

    if( psEnc->sCmn.TargetRate_bps >= LBRRRate_thres_bps ) {
        
        
        
        
        psEnc->sCmn.LBRR_GainIncreases = SKP_max_int( 8 - SKP_RSHIFT( psEnc->sCmn.PacketLoss_perc, 1 ), 0 );

        
        if( psEnc->sCmn.LBRR_enabled && psEnc->sCmn.PacketLoss_perc > LBRR_LOSS_THRES ) {
            
            psEnc->inBandFEC_SNR_comp_Q8 = SKP_FIX_CONST( 6.0f, 8 ) - SKP_LSHIFT( psEnc->sCmn.LBRR_GainIncreases, 7 );
        } else {
            psEnc->inBandFEC_SNR_comp_Q8 = 0;
            psEnc->sCmn.LBRR_enabled     = 0;
        }
    } else {
        psEnc->inBandFEC_SNR_comp_Q8     = 0;
        psEnc->sCmn.LBRR_enabled         = 0;
    }
#else
    if( INBandFEC_enabled != 0 ) {
        ret = SKP_SILK_ENC_INVALID_INBAND_FEC_SETTING;
    }
    psEnc->sCmn.LBRR_enabled = 0;
#endif
    return ret;
}









void SKP_Silk_corrVector_FIX(
    const SKP_int16                 *x,         
    const SKP_int16                 *t,         
    const SKP_int                   L,          
    const SKP_int                   order,      
    SKP_int32                       *Xt,        
    const SKP_int                   rshifts     
)
{
    SKP_int         lag, i;
    const SKP_int16 *ptr1, *ptr2;
    SKP_int32       inner_prod;

    ptr1 = &x[ order - 1 ]; 
    ptr2 = t;
    
    if( rshifts > 0 ) {
        
        for( lag = 0; lag < order; lag++ ) {
            inner_prod = 0;
            for( i = 0; i < L; i++ ) {
                inner_prod += SKP_RSHIFT32( SKP_SMULBB( ptr1[ i ], ptr2[i] ), rshifts );
            }
            Xt[ lag ] = inner_prod; 
            ptr1--; 
        }
    } else {
        SKP_assert( rshifts == 0 );
        for( lag = 0; lag < order; lag++ ) {
            Xt[ lag ] = SKP_Silk_inner_prod_aligned( ptr1, ptr2, L ); 
            ptr1--; 
        }
    }
}


void SKP_Silk_corrMatrix_FIX(
    const SKP_int16                 *x,         
    const SKP_int                   L,          
    const SKP_int                   order,      
    const SKP_int                   head_room,  
    SKP_int32                       *XX,        
    SKP_int                         *rshifts    
)
{
    SKP_int         i, j, lag, rshifts_local, head_room_rshifts;
    SKP_int32       energy;
    const SKP_int16 *ptr1, *ptr2;

    
    SKP_Silk_sum_sqr_shift( &energy, &rshifts_local, x, L + order - 1 );

    
    head_room_rshifts = SKP_max( head_room - SKP_Silk_CLZ32( energy ), 0 );
    
    energy = SKP_RSHIFT32( energy, head_room_rshifts );
    rshifts_local += head_room_rshifts;

    
    
    for( i = 0; i < order - 1; i++ ) {
        energy -= SKP_RSHIFT32( SKP_SMULBB( x[ i ], x[ i ] ), rshifts_local );
    }
    if( rshifts_local < *rshifts ) {
        
        energy = SKP_RSHIFT32( energy, *rshifts - rshifts_local );
        rshifts_local = *rshifts;
    }

    
    
    matrix_ptr( XX, 0, 0, order ) = energy;
    ptr1 = &x[ order - 1 ]; 
    for( j = 1; j < order; j++ ) {
        energy = SKP_SUB32( energy, SKP_RSHIFT32( SKP_SMULBB( ptr1[ L - j ], ptr1[ L - j ] ), rshifts_local ) );
        energy = SKP_ADD32( energy, SKP_RSHIFT32( SKP_SMULBB( ptr1[ -j ], ptr1[ -j ] ), rshifts_local ) );
        matrix_ptr( XX, j, j, order ) = energy;
    }

    ptr2 = &x[ order - 2 ]; 
    
    if( rshifts_local > 0 ) {
        
        for( lag = 1; lag < order; lag++ ) {
            
            energy = 0;
            for( i = 0; i < L; i++ ) {
                energy += SKP_RSHIFT32( SKP_SMULBB( ptr1[ i ], ptr2[i] ), rshifts_local );
            }
            
            matrix_ptr( XX, lag, 0, order ) = energy;
            matrix_ptr( XX, 0, lag, order ) = energy;
            for( j = 1; j < ( order - lag ); j++ ) {
                energy = SKP_SUB32( energy, SKP_RSHIFT32( SKP_SMULBB( ptr1[ L - j ], ptr2[ L - j ] ), rshifts_local ) );
                energy = SKP_ADD32( energy, SKP_RSHIFT32( SKP_SMULBB( ptr1[ -j ], ptr2[ -j ] ), rshifts_local ) );
                matrix_ptr( XX, lag + j, j, order ) = energy;
                matrix_ptr( XX, j, lag + j, order ) = energy;
            }
            ptr2--; 
        }
    } else {
        for( lag = 1; lag < order; lag++ ) {
            
            energy = SKP_Silk_inner_prod_aligned( ptr1, ptr2, L );
            matrix_ptr( XX, lag, 0, order ) = energy;
            matrix_ptr( XX, 0, lag, order ) = energy;
            
            for( j = 1; j < ( order - lag ); j++ ) {
                energy = SKP_SUB32( energy, SKP_SMULBB( ptr1[ L - j ], ptr2[ L - j ] ) );
                energy = SKP_SMLABB( energy, ptr1[ -j ], ptr2[ -j ] );
                matrix_ptr( XX, lag + j, j, order ) = energy;
                matrix_ptr( XX, j, lag + j, order ) = energy;
            }
            ptr2--;
        }
    }
    *rshifts = rshifts_local;
}











SKP_int SKP_Silk_init_decoder(
    SKP_Silk_decoder_state      *psDec              
)
{
    SKP_memset( psDec, 0, sizeof( SKP_Silk_decoder_state ) );
    
    SKP_Silk_decoder_set_fs( psDec, 24 );

    
    psDec->first_frame_after_reset = 1;
    psDec->prev_inv_gain_Q16 = 65536;

    
    SKP_Silk_CNG_Reset( psDec );

    SKP_Silk_PLC_Reset( psDec );
    
    return(0);
}








#ifndef SKP_SILK_SDK_API_H
#define SKP_SILK_SDK_API_H




#ifndef SKP_SILK_CONTROL_H
#define SKP_SILK_CONTROL_H



#ifdef __cplusplus
extern "C"
{
#endif




typedef struct {
    
    SKP_int32 API_sampleRate;

    
    SKP_int32 maxInternalSampleRate;

    
    SKP_int packetSize;

    
    SKP_int32 bitRate;                        

    
    SKP_int packetLossPercentage;
    
    
    SKP_int complexity;

    
    SKP_int useInBandFEC;

    
    SKP_int useDTX;
} SKP_SILK_SDK_EncControlStruct;




typedef struct {
    
    SKP_int32 API_sampleRate;

    
    SKP_int frameSize;

    
    SKP_int framesPerPacket;

    
    SKP_int moreInternalDecoderFrames;

    
    SKP_int inBandFECOffset;
} SKP_SILK_SDK_DecControlStruct;

#ifdef __cplusplus
}
#endif

#endif



#ifdef __cplusplus
extern "C"
{
#endif

#define SILK_MAX_FRAMES_PER_PACKET  5


typedef struct {
    SKP_int     framesInPacket;                             
    SKP_int     fs_kHz;                                     
    SKP_int     inbandLBRR;                                 
    SKP_int     corrupt;                                    
    SKP_int     vadFlags[     SILK_MAX_FRAMES_PER_PACKET ]; 
    SKP_int     sigtypeFlags[ SILK_MAX_FRAMES_PER_PACKET ]; 
} SKP_Silk_TOC_struct;








SKP_int SKP_Silk_SDK_Get_Encoder_Size( 
    SKP_int32                           *encSizeBytes   
);




SKP_int SKP_Silk_SDK_InitEncoder(
    void                                *encState,      
    SKP_SILK_SDK_EncControlStruct       *encStatus      
);




SKP_int SKP_Silk_SDK_QueryEncoder(
    const void                          *encState,      
    SKP_SILK_SDK_EncControlStruct       *encStatus      
);




SKP_int SKP_Silk_SDK_Encode( 
    void                                *encState,      
    const SKP_SILK_SDK_EncControlStruct *encControl,    
    const SKP_int16                     *samplesIn,     
    SKP_int                             nSamplesIn,     
    SKP_uint8                           *outData,       
    SKP_int16                           *nBytesOut      
);








SKP_int SKP_Silk_SDK_Get_Decoder_Size( 
    SKP_int32                           *decSizeBytes   
);




SKP_int SKP_Silk_SDK_InitDecoder( 
    void                                *decState       
);




SKP_int SKP_Silk_SDK_Decode(
    void*                               decState,       
    SKP_SILK_SDK_DecControlStruct*      decControl,     
    SKP_int                             lostFlag,       
    const SKP_uint8                     *inData,        
    const SKP_int                       nBytesIn,       
    SKP_int16                           *samplesOut,    
    SKP_int16                           *nSamplesOut    
);




void SKP_Silk_SDK_search_for_LBRR(
    const SKP_uint8                     *inData,        
    const SKP_int                       nBytesIn,       
    SKP_int                             lost_offset,    
    SKP_uint8                           *LBRRData,      
    SKP_int16                           *nLBRRBytes     
);




void SKP_Silk_SDK_get_TOC(
    const SKP_uint8                     *inData,        
    const SKP_int                       nBytesIn,       
    SKP_Silk_TOC_struct                 *Silk_TOC       
);




 
const char *SKP_Silk_SDK_get_version(void);

#ifdef __cplusplus
}
#endif

#endif






SKP_int SKP_Silk_SDK_Get_Decoder_Size( SKP_int32 *decSizeBytes ) 
{
    SKP_int ret = 0;

    *decSizeBytes = sizeof( SKP_Silk_decoder_state );

    return ret;
}


SKP_int SKP_Silk_SDK_InitDecoder(
    void* decState                                      
)
{
    SKP_int ret = 0;
    SKP_Silk_decoder_state *struc;

    struc = (SKP_Silk_decoder_state *)decState;

    ret  = SKP_Silk_init_decoder( struc );

    return ret;
}


SKP_int SKP_Silk_SDK_Decode(
    void*                               decState,       
    SKP_SILK_SDK_DecControlStruct*      decControl,     
    SKP_int                             lostFlag,       
    const SKP_uint8                     *inData,        
    const SKP_int                       nBytesIn,       
    SKP_int16                           *samplesOut,    
    SKP_int16                           *nSamplesOut    
)
{
    SKP_int ret = 0, used_bytes, prev_fs_kHz;
    SKP_Silk_decoder_state *psDec;
    SKP_int16 samplesOutInternal[ MAX_API_FS_KHZ * FRAME_LENGTH_MS ];
    SKP_int16 *pSamplesOutInternal;

    psDec = (SKP_Silk_decoder_state *)decState;

    
    pSamplesOutInternal = samplesOut;
    if( psDec->fs_kHz * 1000 > decControl->API_sampleRate ) {
        pSamplesOutInternal = samplesOutInternal;
    }

    
    
    
    if( psDec->moreInternalDecoderFrames == 0 ) {
        
        psDec->nFramesDecoded = 0;  
    }

    if( psDec->moreInternalDecoderFrames == 0 &&    
        lostFlag == 0 &&                            
        nBytesIn > MAX_ARITHM_BYTES ) {             
            
            lostFlag = 1;
            ret = SKP_SILK_DEC_PAYLOAD_TOO_LARGE;
    }
            
    
    prev_fs_kHz = psDec->fs_kHz;
    
    
    ret += SKP_Silk_decode_frame( psDec, pSamplesOutInternal, nSamplesOut, inData, nBytesIn, 
            lostFlag, &used_bytes );
    
    if( used_bytes ) { 
        if( psDec->nBytesLeft > 0 && psDec->FrameTermination == SKP_SILK_MORE_FRAMES && psDec->nFramesDecoded < 5 ) {
            
            psDec->moreInternalDecoderFrames = 1;
        } else {
            
            psDec->moreInternalDecoderFrames = 0;
            psDec->nFramesInPacket = psDec->nFramesDecoded;
        
            
            if( psDec->vadFlag == VOICE_ACTIVITY ) {
                if( psDec->FrameTermination == SKP_SILK_LAST_FRAME ) {
                    psDec->no_FEC_counter++;
                    if( psDec->no_FEC_counter > NO_LBRR_THRES ) {
                        psDec->inband_FEC_offset = 0;
                    }
                } else if( psDec->FrameTermination == SKP_SILK_LBRR_VER1 ) {
                    psDec->inband_FEC_offset = 1; 
                    psDec->no_FEC_counter    = 0;
                } else if( psDec->FrameTermination == SKP_SILK_LBRR_VER2 ) {
                    psDec->inband_FEC_offset = 2; 
                    psDec->no_FEC_counter    = 0;
                }
            }
        }
    }

    if( MAX_API_FS_KHZ * 1000 < decControl->API_sampleRate ||
        8000       > decControl->API_sampleRate ) {
        ret = SKP_SILK_DEC_INVALID_SAMPLING_FREQUENCY;
        return( ret );
    }

    
    if( psDec->fs_kHz * 1000 != decControl->API_sampleRate ) { 
        SKP_int16 samplesOut_tmp[ MAX_API_FS_KHZ * FRAME_LENGTH_MS ];
        SKP_assert( psDec->fs_kHz <= MAX_API_FS_KHZ );

        
        SKP_memcpy( samplesOut_tmp, pSamplesOutInternal, *nSamplesOut * sizeof( SKP_int16 ) );

        
        if( prev_fs_kHz != psDec->fs_kHz || psDec->prev_API_sampleRate != decControl->API_sampleRate ) {
            ret = SKP_Silk_resampler_init( &psDec->resampler_state, SKP_SMULBB( psDec->fs_kHz, 1000 ), decControl->API_sampleRate );
        }

        
        ret += SKP_Silk_resampler( &psDec->resampler_state, samplesOut, samplesOut_tmp, *nSamplesOut );

        
        *nSamplesOut = SKP_DIV32( ( SKP_int32 )*nSamplesOut * decControl->API_sampleRate, psDec->fs_kHz * 1000 );
    } else if( prev_fs_kHz * 1000 > decControl->API_sampleRate ) { 
        SKP_memcpy( samplesOut, pSamplesOutInternal, *nSamplesOut * sizeof( SKP_int16 ) );
    }

    psDec->prev_API_sampleRate = decControl->API_sampleRate;

    
    decControl->frameSize                 = (SKP_uint16)( decControl->API_sampleRate / 50 ) ;
    decControl->framesPerPacket           = ( SKP_int )psDec->nFramesInPacket;
    decControl->inBandFECOffset           = ( SKP_int )psDec->inband_FEC_offset;
    decControl->moreInternalDecoderFrames = ( SKP_int )psDec->moreInternalDecoderFrames;

    return ret;
}


void SKP_Silk_SDK_search_for_LBRR(
    const SKP_uint8                     *inData,        
    const SKP_int                       nBytesIn,       
    SKP_int                             lost_offset,    
    SKP_uint8                           *LBRRData,      
    SKP_int16                           *nLBRRBytes     
)
{
    SKP_Silk_decoder_state   sDec; 
    SKP_Silk_decoder_control sDecCtrl;
    SKP_int TempQ[ MAX_FRAME_LENGTH ];

    if( lost_offset < 1 || lost_offset > MAX_LBRR_DELAY ) {
        
        *nLBRRBytes = 0;
        return;
    }

    sDec.nFramesDecoded = 0;
    sDec.fs_kHz         = 0; 
	sDec.lossCnt        = 0; 
    SKP_memset( sDec.prevNLSF_Q15, 0, MAX_LPC_ORDER * sizeof( SKP_int ) );
    SKP_Silk_range_dec_init( &sDec.sRC, inData, ( SKP_int32 )nBytesIn );
    
    while(1) {
        SKP_Silk_decode_parameters( &sDec, &sDecCtrl, TempQ, 0 );
    
        if( sDec.sRC.error ) {
            
            *nLBRRBytes = 0;
            return;
        };
        if( ( sDec.FrameTermination - 1 ) & lost_offset && sDec.FrameTermination > 0 && sDec.nBytesLeft >= 0 ) {
            
            *nLBRRBytes = sDec.nBytesLeft;
            SKP_memcpy( LBRRData, &inData[ nBytesIn - sDec.nBytesLeft ], sDec.nBytesLeft * sizeof( SKP_uint8 ) );
            break;
        }
        if( sDec.nBytesLeft > 0 && sDec.FrameTermination == SKP_SILK_MORE_FRAMES ) {
            sDec.nFramesDecoded++;
        } else {
            LBRRData = NULL;
            *nLBRRBytes = 0;
            break;
        }
    }
}


void SKP_Silk_SDK_get_TOC(
    const SKP_uint8                     *inData,        
    const SKP_int                       nBytesIn,       
    SKP_Silk_TOC_struct                 *Silk_TOC       
)
{
    SKP_Silk_decoder_state      sDec; 
    SKP_Silk_decoder_control    sDecCtrl;
    SKP_int TempQ[ MAX_FRAME_LENGTH ];

    sDec.nFramesDecoded = 0;
    sDec.fs_kHz         = 0; 
    SKP_Silk_range_dec_init( &sDec.sRC, inData, ( SKP_int32 )nBytesIn );

    Silk_TOC->corrupt = 0;
    while( 1 ) {
        SKP_Silk_decode_parameters( &sDec, &sDecCtrl, TempQ, 0 );
        
        Silk_TOC->vadFlags[     sDec.nFramesDecoded ] = sDec.vadFlag;
        Silk_TOC->sigtypeFlags[ sDec.nFramesDecoded ] = sDecCtrl.sigtype;
    
        if( sDec.sRC.error ) {
            
            Silk_TOC->corrupt = 1;
            break;
        };
    
        if( sDec.nBytesLeft > 0 && sDec.FrameTermination == SKP_SILK_MORE_FRAMES ) {
            sDec.nFramesDecoded++;
        } else {
            break;
        }
    }
    if( Silk_TOC->corrupt || sDec.FrameTermination == SKP_SILK_MORE_FRAMES || 
        sDec.nFramesInPacket > SILK_MAX_FRAMES_PER_PACKET ) {
        
        SKP_memset( Silk_TOC, 0, sizeof( SKP_Silk_TOC_struct ) );
        Silk_TOC->corrupt = 1;
    } else {
        Silk_TOC->framesInPacket = sDec.nFramesDecoded + 1;
        Silk_TOC->fs_kHz         = sDec.fs_kHz;
        if( sDec.FrameTermination == SKP_SILK_LAST_FRAME ) {
            Silk_TOC->inbandLBRR = sDec.FrameTermination;
        } else {
            Silk_TOC->inbandLBRR = sDec.FrameTermination - 1;
        }
    }
}




 
const char *SKP_Silk_SDK_get_version()
{
    static const char version[] = "1.0.9.6";
    return version;
}







void SKP_Silk_decode_short_term_prediction(
SKP_int32	*vec_Q10,
SKP_int32	*pres_Q10,
SKP_int32	*sLPC_Q14,
SKP_int16	*A_Q12_tmp, 
SKP_int		LPC_order,
SKP_int		subfr_length
);





void SKP_Silk_decode_core(
    SKP_Silk_decoder_state      *psDec,                             
    SKP_Silk_decoder_control    *psDecCtrl,                         
    SKP_int16                   xq[],                               
    const SKP_int               q[ MAX_FRAME_LENGTH ]               
)
{
    SKP_int   i, k, lag = 0, start_idx, sLTP_buf_idx, NLSF_interpolation_flag, sigtype;
    SKP_int16 *A_Q12, *B_Q14, *pxq, A_Q12_tmp[ MAX_LPC_ORDER ];
    SKP_int16 sLTP[ MAX_FRAME_LENGTH ];
    SKP_int32 LTP_pred_Q14, Gain_Q16, inv_gain_Q16, inv_gain_Q32, gain_adj_Q16, rand_seed, offset_Q10, dither;
    SKP_int32 *pred_lag_ptr, *pexc_Q10, *pres_Q10;
    SKP_int32 vec_Q10[ MAX_FRAME_LENGTH / NB_SUBFR ];
    SKP_int32 FiltState[ MAX_LPC_ORDER ];

    SKP_assert( psDec->prev_inv_gain_Q16 != 0 );
    
    offset_Q10 = SKP_Silk_Quantization_Offsets_Q10[ psDecCtrl->sigtype ][ psDecCtrl->QuantOffsetType ];

    if( psDecCtrl->NLSFInterpCoef_Q2 < ( 1 << 2 ) ) {
        NLSF_interpolation_flag = 1;
    } else {
        NLSF_interpolation_flag = 0;
    }


    
    rand_seed = psDecCtrl->Seed;
    for( i = 0; i < psDec->frame_length; i++ ) {
        rand_seed = SKP_RAND( rand_seed );
        
        dither = SKP_RSHIFT( rand_seed, 31 );

        psDec->exc_Q10[ i ] = SKP_LSHIFT( ( SKP_int32 )q[ i ], 10 ) + offset_Q10;
        psDec->exc_Q10[ i ] = ( psDec->exc_Q10[ i ] ^ dither ) - dither;

        rand_seed += q[ i ];
    }


    pexc_Q10 = psDec->exc_Q10;
    pres_Q10 = psDec->res_Q10;
    pxq      = &psDec->outBuf[ psDec->frame_length ];
    sLTP_buf_idx = psDec->frame_length;
    
    for( k = 0; k < NB_SUBFR; k++ ) {
        A_Q12 = psDecCtrl->PredCoef_Q12[ k >> 1 ];

                
        SKP_memcpy( A_Q12_tmp, A_Q12, psDec->LPC_order * sizeof( SKP_int16 ) ); 
        B_Q14         = &psDecCtrl->LTPCoef_Q14[ k * LTP_ORDER ];
        Gain_Q16      = psDecCtrl->Gains_Q16[ k ];
        sigtype       = psDecCtrl->sigtype;

        inv_gain_Q16 = SKP_INVERSE32_varQ( SKP_max( Gain_Q16, 1 ), 32 );
        inv_gain_Q16 = SKP_min( inv_gain_Q16, SKP_int16_MAX );

        
        gain_adj_Q16 = ( SKP_int32 )1 << 16;
        if( inv_gain_Q16 != psDec->prev_inv_gain_Q16 ) {
            gain_adj_Q16 =  SKP_DIV32_varQ( inv_gain_Q16, psDec->prev_inv_gain_Q16, 16 );
        }

        
        if( psDec->lossCnt && psDec->prev_sigtype == SIG_TYPE_VOICED &&
            psDecCtrl->sigtype == SIG_TYPE_UNVOICED && k < ( NB_SUBFR >> 1 ) ) {
            
            SKP_memset( B_Q14, 0, LTP_ORDER * sizeof( SKP_int16 ) );
            B_Q14[ LTP_ORDER/2 ] = ( SKP_int16 )1 << 12; 
        
            sigtype = SIG_TYPE_VOICED;
            psDecCtrl->pitchL[ k ] = psDec->lagPrev;
        }

        if( sigtype == SIG_TYPE_VOICED ) {
            
            
            lag = psDecCtrl->pitchL[ k ];
            
            if( ( k & ( 3 - SKP_LSHIFT( NLSF_interpolation_flag, 1 ) ) ) == 0 ) {
                
                start_idx = psDec->frame_length - lag - psDec->LPC_order - LTP_ORDER / 2;
                SKP_assert( start_idx >= 0 );
                SKP_assert( start_idx <= psDec->frame_length - psDec->LPC_order );

                SKP_memset( FiltState, 0, psDec->LPC_order * sizeof( SKP_int32 ) ); 
                SKP_Silk_MA_Prediction( &psDec->outBuf[ start_idx + k * ( psDec->frame_length >> 2 ) ], 
                    A_Q12, FiltState, sLTP + start_idx, psDec->frame_length - start_idx, psDec->LPC_order );

                
                inv_gain_Q32 = SKP_LSHIFT( inv_gain_Q16, 16 );
                if( k == 0 ) {
                    
                    inv_gain_Q32 = SKP_LSHIFT( SKP_SMULWB( inv_gain_Q32, psDecCtrl->LTP_scale_Q14 ), 2 );
                }
                for( i = 0; i < (lag + LTP_ORDER/2); i++ ) {
                    psDec->sLTP_Q16[ sLTP_buf_idx - i - 1 ] = SKP_SMULWB( inv_gain_Q32, sLTP[ psDec->frame_length - i - 1 ] );
                }
            } else {
                
                if( gain_adj_Q16 != ( SKP_int32 )1 << 16 ) {
                    for( i = 0; i < ( lag + LTP_ORDER / 2 ); i++ ) {
                        psDec->sLTP_Q16[ sLTP_buf_idx - i - 1 ] = SKP_SMULWW( gain_adj_Q16, psDec->sLTP_Q16[ sLTP_buf_idx - i - 1 ] );
                    }
                }
            }
        }
        
        
        for( i = 0; i < MAX_LPC_ORDER; i++ ) {
            psDec->sLPC_Q14[ i ] = SKP_SMULWW( gain_adj_Q16, psDec->sLPC_Q14[ i ] );
        }

        
        SKP_assert( inv_gain_Q16 != 0 );
        psDec->prev_inv_gain_Q16 = inv_gain_Q16;

        
        if( sigtype == SIG_TYPE_VOICED ) {
            
            pred_lag_ptr = &psDec->sLTP_Q16[ sLTP_buf_idx - lag + LTP_ORDER / 2 ];
            for( i = 0; i < psDec->subfr_length; i++ ) {
                
                LTP_pred_Q14 = SKP_SMULWB(               pred_lag_ptr[  0 ], B_Q14[ 0 ] );
                LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -1 ], B_Q14[ 1 ] );
                LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -2 ], B_Q14[ 2 ] );
                LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -3 ], B_Q14[ 3 ] );
                LTP_pred_Q14 = SKP_SMLAWB( LTP_pred_Q14, pred_lag_ptr[ -4 ], B_Q14[ 4 ] );
                pred_lag_ptr++;
            
                 
                pres_Q10[ i ] = SKP_ADD32( pexc_Q10[ i ], SKP_RSHIFT_ROUND( LTP_pred_Q14, 4 ) );
            
                
                psDec->sLTP_Q16[ sLTP_buf_idx ] = SKP_LSHIFT( pres_Q10[ i ], 6 );
                sLTP_buf_idx++;
            }
        } else {
            SKP_memcpy( pres_Q10, pexc_Q10, psDec->subfr_length * sizeof( SKP_int32 ) );
        }

	SKP_Silk_decode_short_term_prediction(vec_Q10, pres_Q10, psDec->sLPC_Q14,A_Q12_tmp,psDec->LPC_order,psDec->subfr_length);

        
        for( i = 0; i < psDec->subfr_length; i++ ) {
            pxq[ i ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( SKP_SMULWW( vec_Q10[ i ], Gain_Q16 ), 10 ) );
        }

        
        SKP_memcpy( psDec->sLPC_Q14, &psDec->sLPC_Q14[ psDec->subfr_length ], MAX_LPC_ORDER * sizeof( SKP_int32 ) );
        pexc_Q10 += psDec->subfr_length;
        pres_Q10 += psDec->subfr_length;
        pxq      += psDec->subfr_length;
    }
    
    
    SKP_memcpy( xq, &psDec->outBuf[ psDec->frame_length ], psDec->frame_length * sizeof( SKP_int16 ) );

}

#if EMBEDDED_ARM<5 
void SKP_Silk_decode_short_term_prediction(
SKP_int32	*vec_Q10,
SKP_int32	*pres_Q10,
SKP_int32	*sLPC_Q14,
SKP_int16	*A_Q12_tmp, 
SKP_int		LPC_order,
SKP_int		subfr_length
)
{
  SKP_int	i;
  SKP_int32	LPC_pred_Q10;
  #if !defined(_SYSTEM_IS_BIG_ENDIAN)
  SKP_int32	Atmp;
        
        
        
        
        
        if( LPC_order == 16 ) {
            for( i = 0; i < subfr_length; i++ ) {
                
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 0 ] );    
                LPC_pred_Q10 = SKP_SMULWB(               sLPC_Q14[ MAX_LPC_ORDER + i -  1 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  2 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 2 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  3 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  4 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 4 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  5 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  6 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 6 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  7 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  8 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 8 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  9 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 10 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 10 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 11 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 12 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 12 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 13 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 14 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 14 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 15 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 16 ], Atmp );
                
                
                vec_Q10[ i ] = SKP_ADD32( pres_Q10[ i ], LPC_pred_Q10 );
                
                
                sLPC_Q14[ MAX_LPC_ORDER + i ] = SKP_LSHIFT_ovflw( vec_Q10[ i ], 4 );
            }
        } else {
            SKP_assert( LPC_order == 10 );
            for( i = 0; i < subfr_length; i++ ) {
                
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 0 ] );    
                LPC_pred_Q10 = SKP_SMULWB(               sLPC_Q14[ MAX_LPC_ORDER + i -  1 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  2 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 2 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  3 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  4 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 4 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  5 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  6 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 6 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  7 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  8 ], Atmp );
                Atmp = *( ( SKP_int32* )&A_Q12_tmp[ 8 ] );
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  9 ], Atmp );
                LPC_pred_Q10 = SKP_SMLAWT( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 10 ], Atmp );
                
                
                vec_Q10[ i ] = SKP_ADD32( pres_Q10[ i ], LPC_pred_Q10 );
                
                
                sLPC_Q14[ MAX_LPC_ORDER + i ] = SKP_LSHIFT_ovflw( vec_Q10[ i ], 4 );
            }
        }
#else
    SKP_int j;
        for( i = 0; i < subfr_length; i++ ) {
            
            LPC_pred_Q10 = SKP_SMULWB(               sLPC_Q14[ MAX_LPC_ORDER + i -  1 ], A_Q12_tmp[ 0 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  2 ], A_Q12_tmp[ 1 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  3 ], A_Q12_tmp[ 2 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  4 ], A_Q12_tmp[ 3 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  5 ], A_Q12_tmp[ 4 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  6 ], A_Q12_tmp[ 5 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  7 ], A_Q12_tmp[ 6 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  8 ], A_Q12_tmp[ 7 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i -  9 ], A_Q12_tmp[ 8 ] );
            LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - 10 ], A_Q12_tmp[ 9 ] );

            for( j = 10; j < LPC_order; j ++ ) {
                LPC_pred_Q10 = SKP_SMLAWB( LPC_pred_Q10, sLPC_Q14[ MAX_LPC_ORDER + i - j - 1 ], A_Q12_tmp[ j ] );
            }

            
            vec_Q10[ i ] = SKP_ADD32( pres_Q10[ i ], LPC_pred_Q10 );
            
            
            sLPC_Q14[ MAX_LPC_ORDER + i ] = SKP_LSHIFT_ovflw( vec_Q10[ i ], 4 );
        }
#endif
}
#endif














SKP_int SKP_Silk_decode_frame(
    SKP_Silk_decoder_state          *psDec,             
    SKP_int16                       pOut[],             
    SKP_int16                       *pN,                
    const SKP_uint8                 pCode[],            
    const SKP_int                   nBytes,             
    SKP_int                         action,             
    SKP_int                         *decBytes           
)
{
    SKP_Silk_decoder_control sDecCtrl;
    SKP_int         L, fs_Khz_old, ret = 0;
    SKP_int         Pulses[ MAX_FRAME_LENGTH ];


    L = psDec->frame_length;
    sDecCtrl.LTP_scale_Q14 = 0;
    
    
    SKP_assert( L > 0 && L <= MAX_FRAME_LENGTH );

    
    
    
    *decBytes = 0;
    if( action == 0 ) {
        
        
        
        fs_Khz_old    = psDec->fs_kHz;
        if( psDec->nFramesDecoded == 0 ) {
            
            SKP_Silk_range_dec_init( &psDec->sRC, pCode, nBytes );
        }

        
        
        
        SKP_Silk_decode_parameters( psDec, &sDecCtrl, Pulses, 1 );


        if( psDec->sRC.error ) {
            psDec->nBytesLeft = 0;

            action              = 1; 
            
            SKP_Silk_decoder_set_fs( psDec, fs_Khz_old );

            
            *decBytes = psDec->sRC.bufferLength;

            if( psDec->sRC.error == RANGE_CODER_DEC_PAYLOAD_TOO_LONG ) {
                ret = SKP_SILK_DEC_PAYLOAD_TOO_LARGE;
            } else {
                ret = SKP_SILK_DEC_PAYLOAD_ERROR;
            }
        } else {
            *decBytes = psDec->sRC.bufferLength - psDec->nBytesLeft;
            psDec->nFramesDecoded++;
        
            
            L = psDec->frame_length;

            
            
            
            SKP_Silk_decode_core( psDec, &sDecCtrl, pOut, Pulses );

            
            
            
            SKP_Silk_PLC( psDec, &sDecCtrl, pOut, L, action );

            psDec->lossCnt = 0;
            psDec->prev_sigtype = sDecCtrl.sigtype;

            
            psDec->first_frame_after_reset = 0;
        }
    }
    
    
    
    if( action == 1 ) {
        
        SKP_Silk_PLC( psDec, &sDecCtrl, pOut, L, action );
    }

    
    
    
    SKP_memcpy( psDec->outBuf, pOut, L * sizeof( SKP_int16 ) );

    
    
    
    SKP_Silk_PLC_glue_frames( psDec, &sDecCtrl, pOut, L );

    
    
    
    SKP_Silk_CNG( psDec, &sDecCtrl, pOut , L );

    
    
    
    SKP_assert( ( ( psDec->fs_kHz == 12 ) && ( L % 3 ) == 0 ) || 
                ( ( psDec->fs_kHz != 12 ) && ( L % 2 ) == 0 ) );
    SKP_Silk_biquad( pOut, psDec->HP_B, psDec->HP_A, psDec->HPState, pOut, L );

    
    
    
    *pN = ( SKP_int16 )L;

    
    psDec->lagPrev = sDecCtrl.pitchL[ NB_SUBFR - 1 ];


    return ret;
}







void SKP_Silk_decode_parameters(
    SKP_Silk_decoder_state      *psDec,             
    SKP_Silk_decoder_control    *psDecCtrl,         
    SKP_int                     q[],                
    const SKP_int               fullDecoding        
)
{
    SKP_int   i, k, Ix, fs_kHz_dec, nBytesUsed;
    SKP_int   Ixs[ NB_SUBFR ];
    SKP_int   GainsIndices[ NB_SUBFR ];
    SKP_int   NLSFIndices[ NLSF_MSVQ_MAX_CB_STAGES ];
    SKP_int   pNLSF_Q15[ MAX_LPC_ORDER ], pNLSF0_Q15[ MAX_LPC_ORDER ];
    const SKP_int16 *cbk_ptr_Q14;
    const SKP_Silk_NLSF_CB_struct *psNLSF_CB = NULL;
    SKP_Silk_range_coder_state  *psRC = &psDec->sRC;

    
    
    
    
    if( psDec->nFramesDecoded == 0 ) {
        SKP_Silk_range_decoder( &Ix, psRC, SKP_Silk_SamplingRates_CDF, SKP_Silk_SamplingRates_offset );

        
        if( Ix < 0 || Ix > 3 ) {
            psRC->error = RANGE_CODER_ILLEGAL_SAMPLING_RATE;
            return;
        }
        fs_kHz_dec = SKP_Silk_SamplingRates_table[ Ix ];
        SKP_Silk_decoder_set_fs( psDec, fs_kHz_dec );
    }

    
    
    
    if( psDec->nFramesDecoded == 0 ) {
        
        SKP_Silk_range_decoder( &Ix, psRC, SKP_Silk_type_offset_CDF, SKP_Silk_type_offset_CDF_offset );
    } else {
        
        SKP_Silk_range_decoder( &Ix, psRC, SKP_Silk_type_offset_joint_CDF[ psDec->typeOffsetPrev ], 
                SKP_Silk_type_offset_CDF_offset );
    }
    psDecCtrl->sigtype         = SKP_RSHIFT( Ix, 1 );
    psDecCtrl->QuantOffsetType = Ix & 1;
    psDec->typeOffsetPrev      = Ix;

    
    
    
        
    if( psDec->nFramesDecoded == 0 ) {
        
        SKP_Silk_range_decoder( &GainsIndices[ 0 ], psRC, SKP_Silk_gain_CDF[ psDecCtrl->sigtype ], SKP_Silk_gain_CDF_offset );
    } else {
        
        SKP_Silk_range_decoder( &GainsIndices[ 0 ], psRC, SKP_Silk_delta_gain_CDF, SKP_Silk_delta_gain_CDF_offset );
    }

    
    for( i = 1; i < NB_SUBFR; i++ ) {
        SKP_Silk_range_decoder( &GainsIndices[ i ], psRC, SKP_Silk_delta_gain_CDF, SKP_Silk_delta_gain_CDF_offset );
    }
    
    
    SKP_Silk_gains_dequant( psDecCtrl->Gains_Q16, GainsIndices, &psDec->LastGainIndex, psDec->nFramesDecoded );
    
    
    
    
    psNLSF_CB = psDec->psNLSF_CB[ psDecCtrl->sigtype ];

    
    SKP_Silk_range_decoder_multi( NLSFIndices, psRC, psNLSF_CB->StartPtr, psNLSF_CB->MiddleIx, psNLSF_CB->nStages );

    
    SKP_Silk_NLSF_MSVQ_decode( pNLSF_Q15, psNLSF_CB, NLSFIndices, psDec->LPC_order );

    
    
    
    SKP_Silk_range_decoder( &psDecCtrl->NLSFInterpCoef_Q2, psRC, SKP_Silk_NLSF_interpolation_factor_CDF, 
        SKP_Silk_NLSF_interpolation_factor_offset );
    
    
    
    if( psDec->first_frame_after_reset == 1 ) {
        psDecCtrl->NLSFInterpCoef_Q2 = 4;
    }

    if( fullDecoding ) {
        
        SKP_Silk_NLSF2A_stable( psDecCtrl->PredCoef_Q12[ 1 ], pNLSF_Q15, psDec->LPC_order );

        if( psDecCtrl->NLSFInterpCoef_Q2 < 4 ) {
             
            
            for( i = 0; i < psDec->LPC_order; i++ ) {
                pNLSF0_Q15[ i ] = psDec->prevNLSF_Q15[ i ] + SKP_RSHIFT( SKP_MUL( psDecCtrl->NLSFInterpCoef_Q2, 
                    ( pNLSF_Q15[ i ] - psDec->prevNLSF_Q15[ i ] ) ), 2 );
            }

            
            SKP_Silk_NLSF2A_stable( psDecCtrl->PredCoef_Q12[ 0 ], pNLSF0_Q15, psDec->LPC_order );
        } else {
            
            SKP_memcpy( psDecCtrl->PredCoef_Q12[ 0 ], psDecCtrl->PredCoef_Q12[ 1 ], 
                psDec->LPC_order * sizeof( SKP_int16 ) );
        }
    }

    SKP_memcpy( psDec->prevNLSF_Q15, pNLSF_Q15, psDec->LPC_order * sizeof( SKP_int ) );

    
    if( psDec->lossCnt ) {
        SKP_Silk_bwexpander( psDecCtrl->PredCoef_Q12[ 0 ], psDec->LPC_order, BWE_AFTER_LOSS_Q16 );
        SKP_Silk_bwexpander( psDecCtrl->PredCoef_Q12[ 1 ], psDec->LPC_order, BWE_AFTER_LOSS_Q16 );
    }

    if( psDecCtrl->sigtype == SIG_TYPE_VOICED ) {
        
        
        
        
        if( psDec->fs_kHz == 8 ) {
            SKP_Silk_range_decoder( &Ixs[ 0 ], psRC, SKP_Silk_pitch_lag_NB_CDF,  SKP_Silk_pitch_lag_NB_CDF_offset );
        } else if( psDec->fs_kHz == 12 ) {
            SKP_Silk_range_decoder( &Ixs[ 0 ], psRC, SKP_Silk_pitch_lag_MB_CDF,  SKP_Silk_pitch_lag_MB_CDF_offset );
        } else if( psDec->fs_kHz == 16 ) {
            SKP_Silk_range_decoder( &Ixs[ 0 ], psRC, SKP_Silk_pitch_lag_WB_CDF,  SKP_Silk_pitch_lag_WB_CDF_offset );
        } else {
            SKP_Silk_range_decoder( &Ixs[ 0 ], psRC, SKP_Silk_pitch_lag_SWB_CDF, SKP_Silk_pitch_lag_SWB_CDF_offset );
        }
        
        
        if( psDec->fs_kHz == 8 ) {
            
            SKP_Silk_range_decoder( &Ixs[ 1 ], psRC, SKP_Silk_pitch_contour_NB_CDF, SKP_Silk_pitch_contour_NB_CDF_offset );
        } else {
            
            SKP_Silk_range_decoder( &Ixs[ 1 ], psRC, SKP_Silk_pitch_contour_CDF, SKP_Silk_pitch_contour_CDF_offset );
        }
        
        
        SKP_Silk_decode_pitch( Ixs[ 0 ], Ixs[ 1 ], psDecCtrl->pitchL, psDec->fs_kHz );

        
        
        
        
        SKP_Silk_range_decoder( &psDecCtrl->PERIndex, psRC, SKP_Silk_LTP_per_index_CDF, 
                SKP_Silk_LTP_per_index_CDF_offset );

        
        cbk_ptr_Q14 = SKP_Silk_LTP_vq_ptrs_Q14[ psDecCtrl->PERIndex ]; 

        for( k = 0; k < NB_SUBFR; k++ ) {
            SKP_Silk_range_decoder( &Ix, psRC, SKP_Silk_LTP_gain_CDF_ptrs[ psDecCtrl->PERIndex ], 
                SKP_Silk_LTP_gain_CDF_offsets[ psDecCtrl->PERIndex ] );

            for( i = 0; i < LTP_ORDER; i++ ) {
                psDecCtrl->LTPCoef_Q14[ k * LTP_ORDER + i ] = cbk_ptr_Q14[ Ix * LTP_ORDER + i ];
            }
        }

        
        
        
        SKP_Silk_range_decoder( &Ix, psRC, SKP_Silk_LTPscale_CDF, SKP_Silk_LTPscale_offset );
        psDecCtrl->LTP_scale_Q14 = SKP_Silk_LTPScales_table_Q14[ Ix ];
    } else {
        SKP_assert( psDecCtrl->sigtype == SIG_TYPE_UNVOICED );
        SKP_memset( psDecCtrl->pitchL,      0,             NB_SUBFR * sizeof( SKP_int   ) );
        SKP_memset( psDecCtrl->LTPCoef_Q14, 0, LTP_ORDER * NB_SUBFR * sizeof( SKP_int16 ) );
        psDecCtrl->PERIndex      = 0;
        psDecCtrl->LTP_scale_Q14 = 0;
    }

    
    
    
    SKP_Silk_range_decoder( &Ix, psRC, SKP_Silk_Seed_CDF, SKP_Silk_Seed_offset );
    psDecCtrl->Seed = ( SKP_int32 )Ix;
    
    
    
    SKP_Silk_decode_pulses( psRC, psDecCtrl, q, psDec->frame_length );

    
    
    
    SKP_Silk_range_decoder( &psDec->vadFlag, psRC, SKP_Silk_vadflag_CDF, SKP_Silk_vadflag_offset );

    
    
    
    SKP_Silk_range_decoder( &psDec->FrameTermination, psRC, SKP_Silk_FrameTermination_CDF, SKP_Silk_FrameTermination_offset );

    
    
    
    SKP_Silk_range_coder_get_length( psRC, &nBytesUsed );
    psDec->nBytesLeft = psRC->bufferLength - nBytesUsed;
    if( psDec->nBytesLeft < 0 ) {
        psRC->error = RANGE_CODER_READ_BEYOND_BUFFER;
    }

    
    
    
    if( psDec->nBytesLeft == 0 ) {
        SKP_Silk_range_coder_check_after_decoding( psRC );
    }
}









#ifndef SIGPROC_COMMON_PITCH_EST_DEFINES_H
#define SIGPROC_COMMON_PITCH_EST_DEFINES_H







#define PITCH_EST_MAX_FS_KHZ                24 

#define PITCH_EST_FRAME_LENGTH_MS           40 

#define PITCH_EST_MAX_FRAME_LENGTH          (PITCH_EST_FRAME_LENGTH_MS * PITCH_EST_MAX_FS_KHZ)
#define PITCH_EST_MAX_FRAME_LENGTH_ST_1     (PITCH_EST_MAX_FRAME_LENGTH >> 2)
#define PITCH_EST_MAX_FRAME_LENGTH_ST_2     (PITCH_EST_MAX_FRAME_LENGTH >> 1)
#define PITCH_EST_MAX_SF_FRAME_LENGTH       (PITCH_EST_SUB_FRAME * PITCH_EST_MAX_FS_KHZ)

#define PITCH_EST_MAX_LAG_MS                18            
#define PITCH_EST_MIN_LAG_MS                2            
#define PITCH_EST_MAX_LAG                   (PITCH_EST_MAX_LAG_MS * PITCH_EST_MAX_FS_KHZ)
#define PITCH_EST_MIN_LAG                   (PITCH_EST_MIN_LAG_MS * PITCH_EST_MAX_FS_KHZ)

#define PITCH_EST_NB_SUBFR                  4

#define PITCH_EST_D_SRCH_LENGTH             24

#define PITCH_EST_MAX_DECIMATE_STATE_LENGTH 7

#define PITCH_EST_NB_STAGE3_LAGS            5

#define PITCH_EST_NB_CBKS_STAGE2            3
#define PITCH_EST_NB_CBKS_STAGE2_EXT        11

#define PITCH_EST_CB_mn2                    1
#define PITCH_EST_CB_mx2                    2

#define PITCH_EST_NB_CBKS_STAGE3_MAX        34
#define PITCH_EST_NB_CBKS_STAGE3_MID        24
#define PITCH_EST_NB_CBKS_STAGE3_MIN        16

extern const SKP_int16 SKP_Silk_CB_lags_stage2[PITCH_EST_NB_SUBFR][PITCH_EST_NB_CBKS_STAGE2_EXT];
extern const SKP_int16 SKP_Silk_CB_lags_stage3[PITCH_EST_NB_SUBFR][PITCH_EST_NB_CBKS_STAGE3_MAX];
extern const SKP_int16 SKP_Silk_Lag_range_stage3[ SKP_Silk_PITCH_EST_MAX_COMPLEX + 1 ] [ PITCH_EST_NB_SUBFR ][ 2 ];
extern const SKP_int16 SKP_Silk_cbk_sizes_stage3[ SKP_Silk_PITCH_EST_MAX_COMPLEX + 1 ];
extern const SKP_int16 SKP_Silk_cbk_offsets_stage3[ SKP_Silk_PITCH_EST_MAX_COMPLEX + 1 ];

#endif


void SKP_Silk_decode_pitch(
    SKP_int          lagIndex,                        
    SKP_int          contourIndex,                    
    SKP_int          pitch_lags[],                    
    SKP_int          Fs_kHz                           
)
{
    SKP_int lag, i, min_lag;

    min_lag = SKP_SMULBB( PITCH_EST_MIN_LAG_MS, Fs_kHz );

    
    lag = min_lag + lagIndex;
    if( Fs_kHz == 8 ) {
        
        for( i = 0; i < PITCH_EST_NB_SUBFR; i++ ) {
            pitch_lags[ i ] = lag + SKP_Silk_CB_lags_stage2[ i ][ contourIndex ];
        }
    } else {
        for( i = 0; i < PITCH_EST_NB_SUBFR; i++ ) {
            pitch_lags[ i ] = lag + SKP_Silk_CB_lags_stage3[ i ][ contourIndex ];
        }
    }
}









void SKP_Silk_decode_pulses(
    SKP_Silk_range_coder_state      *psRC,              
    SKP_Silk_decoder_control        *psDecCtrl,         
    SKP_int                         q[],                
    const SKP_int                   frame_length        
)
{
    SKP_int   i, j, k, iter, abs_q, nLS, bit;
    SKP_int   sum_pulses[ MAX_NB_SHELL_BLOCKS ], nLshifts[ MAX_NB_SHELL_BLOCKS ];
    SKP_int   *pulses_ptr;
    const SKP_uint16 *cdf_ptr;
    
    
    
    
    SKP_Silk_range_decoder( &psDecCtrl->RateLevelIndex, psRC, 
            SKP_Silk_rate_levels_CDF[ psDecCtrl->sigtype ], SKP_Silk_rate_levels_CDF_offset );

    
    iter = frame_length / SHELL_CODEC_FRAME_LENGTH;
    
    
    
    
    cdf_ptr = SKP_Silk_pulses_per_block_CDF[ psDecCtrl->RateLevelIndex ];
    for( i = 0; i < iter; i++ ) {
        nLshifts[ i ] = 0;
        SKP_Silk_range_decoder( &sum_pulses[ i ], psRC, cdf_ptr, SKP_Silk_pulses_per_block_CDF_offset );

        
        while( sum_pulses[ i ] == ( MAX_PULSES + 1 ) ) {
            nLshifts[ i ]++;
            SKP_Silk_range_decoder( &sum_pulses[ i ], psRC, 
                    SKP_Silk_pulses_per_block_CDF[ N_RATE_LEVELS - 1 ], SKP_Silk_pulses_per_block_CDF_offset );
        }
    }
    
    
    
    
    for( i = 0; i < iter; i++ ) {
        if( sum_pulses[ i ] > 0 ) {
            SKP_Silk_shell_decoder( &q[ SKP_SMULBB( i, SHELL_CODEC_FRAME_LENGTH ) ], psRC, sum_pulses[ i ] );
        } else {
            SKP_memset( &q[ SKP_SMULBB( i, SHELL_CODEC_FRAME_LENGTH ) ], 0, SHELL_CODEC_FRAME_LENGTH * sizeof( SKP_int ) );
        }
    }

    
    
    
    for( i = 0; i < iter; i++ ) {
        if( nLshifts[ i ] > 0 ) {
            nLS = nLshifts[ i ];
            pulses_ptr = &q[ SKP_SMULBB( i, SHELL_CODEC_FRAME_LENGTH ) ];
            for( k = 0; k < SHELL_CODEC_FRAME_LENGTH; k++ ) {
                abs_q = pulses_ptr[ k ];
                for( j = 0; j < nLS; j++ ) {
                    abs_q = SKP_LSHIFT( abs_q, 1 ); 
                    SKP_Silk_range_decoder( &bit, psRC, SKP_Silk_lsb_CDF, 1 );
                    abs_q += bit;
                }
                pulses_ptr[ k ] = abs_q;
            }
        }
    }

    
    
    
    SKP_Silk_decode_signs( psRC, q, frame_length, psDecCtrl->sigtype, 
        psDecCtrl->QuantOffsetType, psDecCtrl->RateLevelIndex);
}







void SKP_Silk_decoder_set_fs(
    SKP_Silk_decoder_state          *psDec,             
    SKP_int                         fs_kHz              
)
{
    if( psDec->fs_kHz != fs_kHz ) {
        psDec->fs_kHz  = fs_kHz;
        psDec->frame_length = SKP_SMULBB( FRAME_LENGTH_MS, fs_kHz );
        psDec->subfr_length = SKP_SMULBB( FRAME_LENGTH_MS / NB_SUBFR, fs_kHz );
        if( psDec->fs_kHz == 8 ) {
            psDec->LPC_order = MIN_LPC_ORDER;
            psDec->psNLSF_CB[ 0 ] = &SKP_Silk_NLSF_CB0_10;
            psDec->psNLSF_CB[ 1 ] = &SKP_Silk_NLSF_CB1_10;
        } else {
            psDec->LPC_order = MAX_LPC_ORDER;
            psDec->psNLSF_CB[ 0 ] = &SKP_Silk_NLSF_CB0_16;
            psDec->psNLSF_CB[ 1 ] = &SKP_Silk_NLSF_CB1_16;
        }
        
        SKP_memset( psDec->sLPC_Q14,     0, MAX_LPC_ORDER    * sizeof( SKP_int32 ) );
        SKP_memset( psDec->outBuf,       0, MAX_FRAME_LENGTH * sizeof( SKP_int16 ) );
        SKP_memset( psDec->prevNLSF_Q15, 0, MAX_LPC_ORDER    * sizeof( SKP_int )   );

        psDec->lagPrev                 = 100;
        psDec->LastGainIndex           = 1;
        psDec->prev_sigtype            = 0;
        psDec->first_frame_after_reset = 1;

        if( fs_kHz == 24 ) {
            psDec->HP_A = SKP_Silk_Dec_A_HP_24;
            psDec->HP_B = SKP_Silk_Dec_B_HP_24;
        } else if( fs_kHz == 16 ) {
            psDec->HP_A = SKP_Silk_Dec_A_HP_16;
            psDec->HP_B = SKP_Silk_Dec_B_HP_16;
        } else if( fs_kHz == 12 ) {
            psDec->HP_A = SKP_Silk_Dec_A_HP_12;
            psDec->HP_B = SKP_Silk_Dec_B_HP_12;
        } else if( fs_kHz == 8 ) {
            psDec->HP_A = SKP_Silk_Dec_A_HP_8;
            psDec->HP_B = SKP_Silk_Dec_B_HP_8;
        } else {
            
            SKP_assert( 0 );
        }
    } 

    
    SKP_assert( psDec->frame_length > 0 && psDec->frame_length <= MAX_FRAME_LENGTH );
}









void SKP_Silk_detect_SWB_input(
    SKP_Silk_detect_SWB_state   *psSWBdetect,   
    const SKP_int16             samplesIn[],    
    SKP_int                     nSamplesIn      
)
{
    SKP_int     HP_8_kHz_len, i, shift;
    SKP_int16   in_HP_8_kHz[ MAX_FRAME_LENGTH ];
    SKP_int32   energy_32;
    
    
    HP_8_kHz_len = SKP_min_int( nSamplesIn, MAX_FRAME_LENGTH );
    HP_8_kHz_len = SKP_max_int( HP_8_kHz_len, 0 );

    
    
    
    SKP_Silk_biquad( samplesIn, SKP_Silk_SWB_detect_B_HP_Q13[ 0 ], SKP_Silk_SWB_detect_A_HP_Q13[ 0 ], 
        psSWBdetect->S_HP_8_kHz[ 0 ], in_HP_8_kHz, HP_8_kHz_len );
    for( i = 1; i < NB_SOS; i++ ) {
        SKP_Silk_biquad( in_HP_8_kHz, SKP_Silk_SWB_detect_B_HP_Q13[ i ], SKP_Silk_SWB_detect_A_HP_Q13[ i ], 
            psSWBdetect->S_HP_8_kHz[ i ], in_HP_8_kHz, HP_8_kHz_len );
    }

    
    SKP_Silk_sum_sqr_shift( &energy_32, &shift, in_HP_8_kHz, HP_8_kHz_len );

    
    if( energy_32 > SKP_RSHIFT( SKP_SMULBB( HP_8_KHZ_THRES, HP_8_kHz_len ), shift ) ) {
        psSWBdetect->ConsecSmplsAboveThres += nSamplesIn;
        if( psSWBdetect->ConsecSmplsAboveThres > CONCEC_SWB_SMPLS_THRES ) {
            psSWBdetect->SWB_detected = 1;
        }
    } else {
        psSWBdetect->ConsecSmplsAboveThres -= nSamplesIn;
        psSWBdetect->ConsecSmplsAboveThres = SKP_max( psSWBdetect->ConsecSmplsAboveThres, 0 );
    }

    
    if( ( psSWBdetect->ActiveSpeech_ms > WB_DETECT_ACTIVE_SPEECH_MS_THRES ) && ( psSWBdetect->SWB_detected == 0 ) ) {
        psSWBdetect->WB_detected = 1;
    }
}






SKP_int32 SKP_DIV32_arm( SKP_int32 a32, SKP_int32 b32 ) {
	return ( ( SKP_int32 )( ( a32 ) / ( b32 ) ) );
}














#define SKP_Silk_EncodeControlStruct SKP_SILK_SDK_EncControlStruct





SKP_int SKP_Silk_SDK_Get_Encoder_Size( SKP_int32 *encSizeBytes )
{
    SKP_int ret = 0;
    
    *encSizeBytes = sizeof( SKP_Silk_encoder_state_FIX );
    
    return ret;
}





SKP_int SKP_Silk_SDK_QueryEncoder(
    const void *encState,                       
    SKP_Silk_EncodeControlStruct *encStatus     
)
{
    SKP_Silk_encoder_state_FIX *psEnc;
    SKP_int ret = 0;

    psEnc = ( SKP_Silk_encoder_state_FIX* )encState;

    encStatus->API_sampleRate        = psEnc->sCmn.API_fs_Hz;
    encStatus->maxInternalSampleRate = SKP_SMULBB( psEnc->sCmn.maxInternal_fs_kHz, 1000 );
    encStatus->packetSize            = ( SKP_int )SKP_DIV32_16( psEnc->sCmn.API_fs_Hz * psEnc->sCmn.PacketSize_ms, 1000 );  
    encStatus->bitRate               = psEnc->sCmn.TargetRate_bps;
    encStatus->packetLossPercentage  = psEnc->sCmn.PacketLoss_perc;
    encStatus->complexity            = psEnc->sCmn.Complexity;
    encStatus->useInBandFEC          = psEnc->sCmn.useInBandFEC;
    encStatus->useDTX                = psEnc->sCmn.useDTX;
    return ret;
}




SKP_int SKP_Silk_SDK_InitEncoder(
    void                            *encState,          
    SKP_Silk_EncodeControlStruct    *encStatus          
)
{
    SKP_Silk_encoder_state_FIX *psEnc;
    SKP_int ret = 0;

        
    psEnc = ( SKP_Silk_encoder_state_FIX* )encState;

    
    if( ret += SKP_Silk_init_encoder_FIX( psEnc ) ) {
        SKP_assert( 0 );
    }

    
    if( ret += SKP_Silk_SDK_QueryEncoder( encState, encStatus ) ) {
        SKP_assert( 0 );
    }


    return ret;
}




SKP_int SKP_Silk_SDK_Encode( 
    void                                *encState,      
    const SKP_Silk_EncodeControlStruct  *encControl,    
    const SKP_int16                     *samplesIn,     
    SKP_int                             nSamplesIn,     
    SKP_uint8                           *outData,       
    SKP_int16                           *nBytesOut      
)
{
    SKP_int   max_internal_fs_kHz, PacketSize_ms, PacketLoss_perc, UseInBandFEC, UseDTX, ret = 0;
    SKP_int   nSamplesToBuffer, Complexity, input_10ms, nSamplesFromInput = 0;
    SKP_int32 TargetRate_bps, API_fs_Hz;
    SKP_int16 MaxBytesOut;
    SKP_Silk_encoder_state_FIX *psEnc = ( SKP_Silk_encoder_state_FIX* )encState;

    SKP_assert( encControl != NULL );

    
    if( ( ( encControl->API_sampleRate        !=  8000 ) &&
          ( encControl->API_sampleRate        != 12000 ) &&
          ( encControl->API_sampleRate        != 16000 ) &&
          ( encControl->API_sampleRate        != 24000 ) && 
          ( encControl->API_sampleRate        != 32000 ) &&
          ( encControl->API_sampleRate        != 44100 ) &&
          ( encControl->API_sampleRate        != 48000 ) ) ||
        ( ( encControl->maxInternalSampleRate !=  8000 ) &&
          ( encControl->maxInternalSampleRate != 12000 ) &&
          ( encControl->maxInternalSampleRate != 16000 ) &&
          ( encControl->maxInternalSampleRate != 24000 ) ) ) {
        ret = SKP_SILK_ENC_FS_NOT_SUPPORTED;
        SKP_assert( 0 );
        return( ret );
    }

    
    API_fs_Hz           =                            encControl->API_sampleRate;
    max_internal_fs_kHz =                 (SKP_int)( encControl->maxInternalSampleRate >> 10 ) + 1;   
    PacketSize_ms       = SKP_DIV32( 1000 * (SKP_int)encControl->packetSize, API_fs_Hz );
    TargetRate_bps      =                            encControl->bitRate;
    PacketLoss_perc     =                            encControl->packetLossPercentage;
    UseInBandFEC        =                            encControl->useInBandFEC;
    Complexity          =                            encControl->complexity;
    UseDTX              =                            encControl->useDTX;

    
    psEnc->sCmn.API_fs_Hz          = API_fs_Hz;
    psEnc->sCmn.maxInternal_fs_kHz = max_internal_fs_kHz;
    psEnc->sCmn.useInBandFEC       = UseInBandFEC;

    
    input_10ms = SKP_DIV32( 100 * nSamplesIn, API_fs_Hz );
    if( input_10ms * API_fs_Hz != 100 * nSamplesIn || nSamplesIn < 0 ) {
        ret = SKP_SILK_ENC_INPUT_INVALID_NO_OF_SAMPLES;
        SKP_assert( 0 );
        return( ret );
    }

    TargetRate_bps = SKP_LIMIT( TargetRate_bps, MIN_TARGET_RATE_BPS, MAX_TARGET_RATE_BPS );
    if( ( ret = SKP_Silk_control_encoder_FIX( psEnc, PacketSize_ms, TargetRate_bps, 
                        PacketLoss_perc, UseDTX, Complexity) ) != 0 ) {
        SKP_assert( 0 );
        return( ret );
    }

    
    if( 1000 * (SKP_int32)nSamplesIn > psEnc->sCmn.PacketSize_ms * API_fs_Hz ) {
        ret = SKP_SILK_ENC_INPUT_INVALID_NO_OF_SAMPLES;
        SKP_assert( 0 );
        return( ret );
    }

#if MAX_FS_KHZ > 16
    
    if( SKP_min( API_fs_Hz, 1000 * max_internal_fs_kHz ) == 24000 && 
            psEnc->sCmn.sSWBdetect.SWB_detected == 0 && 
            psEnc->sCmn.sSWBdetect.WB_detected == 0 ) {
        SKP_Silk_detect_SWB_input( &psEnc->sCmn.sSWBdetect, samplesIn, ( SKP_int )nSamplesIn );
    }
#endif

    
    MaxBytesOut = 0;                    
    while( 1 ) {
        nSamplesToBuffer = psEnc->sCmn.frame_length - psEnc->sCmn.inputBufIx;
        if( API_fs_Hz == SKP_SMULBB( 1000, psEnc->sCmn.fs_kHz ) ) { 
            nSamplesToBuffer  = SKP_min_int( nSamplesToBuffer, nSamplesIn );
            nSamplesFromInput = nSamplesToBuffer;
            
            SKP_memcpy( &psEnc->sCmn.inputBuf[ psEnc->sCmn.inputBufIx ], samplesIn, nSamplesFromInput * sizeof( SKP_int16 ) );
        } else {  
            nSamplesToBuffer  = SKP_min( nSamplesToBuffer, 10 * input_10ms * psEnc->sCmn.fs_kHz );
            nSamplesFromInput = SKP_DIV32_16( nSamplesToBuffer * API_fs_Hz, psEnc->sCmn.fs_kHz * 1000 );
            
            ret += SKP_Silk_resampler( &psEnc->sCmn.resampler_state, 
                &psEnc->sCmn.inputBuf[ psEnc->sCmn.inputBufIx ], samplesIn, nSamplesFromInput );
        } 
        samplesIn              += nSamplesFromInput;
        nSamplesIn             -= nSamplesFromInput;
        psEnc->sCmn.inputBufIx += nSamplesToBuffer;

        
        if( psEnc->sCmn.inputBufIx >= psEnc->sCmn.frame_length ) {
            SKP_assert( psEnc->sCmn.inputBufIx == psEnc->sCmn.frame_length );

            
            if( MaxBytesOut == 0 ) {
                
                MaxBytesOut = *nBytesOut;
                if( ( ret = SKP_Silk_encode_frame_FIX( psEnc, outData, &MaxBytesOut, psEnc->sCmn.inputBuf ) ) != 0 ) {
                    SKP_assert( 0 );
                }
            } else {
                
                if( ( ret = SKP_Silk_encode_frame_FIX( psEnc, outData, nBytesOut, psEnc->sCmn.inputBuf ) ) != 0 ) {
                    SKP_assert( 0 );
                }
                
                SKP_assert( *nBytesOut == 0 );
            }
            psEnc->sCmn.inputBufIx = 0;
            psEnc->sCmn.controlled_since_last_payload = 0;

            if( nSamplesIn == 0 ) {
                break;
            }
        } else {
            break;
        }
    }

    *nBytesOut = MaxBytesOut;
    if( psEnc->sCmn.useDTX && psEnc->sCmn.inDTX ) {
        
        *nBytesOut = 0;
    }



    return ret;
}












SKP_int SKP_Silk_encode_frame_FIX( 
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_uint8                       *pCode,             
    SKP_int16                       *pnBytesOut,        
                                                        
    const SKP_int16                 *pIn                
)
{
    SKP_Silk_encoder_control_FIX sEncCtrl;
    SKP_int     nBytes, ret = 0;
    SKP_int16   *x_frame, *res_pitch_frame;
    SKP_int16   xfw[ MAX_FRAME_LENGTH ];
    SKP_int16   pIn_HP[ MAX_FRAME_LENGTH ];
    SKP_int16   res_pitch[ 2 * MAX_FRAME_LENGTH + LA_PITCH_MAX ];
    SKP_int     LBRR_idx, frame_terminator, SNR_dB_Q7;
    const SKP_uint16 *FrameTermination_CDF;
    
    SKP_uint8   LBRRpayload[ MAX_ARITHM_BYTES ];
    SKP_int16   nBytesLBRR;


    sEncCtrl.sCmn.Seed = psEnc->sCmn.frameCounter++ & 3;
    
    
    
    x_frame         = psEnc->x_buf + psEnc->sCmn.frame_length; 
    res_pitch_frame = res_pitch    + psEnc->sCmn.frame_length; 

    
    
    
    ret = SKP_Silk_VAD_GetSA_Q8( &psEnc->sCmn.sVAD, &psEnc->speech_activity_Q8, &SNR_dB_Q7, 
                                 sEncCtrl.input_quality_bands_Q15, &sEncCtrl.input_tilt_Q15,
                                 pIn,psEnc->sCmn.frame_length );

    
    
    
#if HIGH_PASS_INPUT
    
    SKP_Silk_HP_variable_cutoff_FIX( psEnc, &sEncCtrl, pIn_HP, pIn );
#else
    SKP_memcpy( pIn_HP, pIn, psEnc->sCmn.frame_length * sizeof( SKP_int16 ) );
#endif

#if SWITCH_TRANSITION_FILTERING
    
    SKP_Silk_LP_variable_cutoff( &psEnc->sCmn.sLP, x_frame + LA_SHAPE_MS * psEnc->sCmn.fs_kHz, pIn_HP, psEnc->sCmn.frame_length );
#else
    SKP_memcpy( x_frame + LA_SHAPE_MS * psEnc->sCmn.fs_kHz, pIn_HP,psEnc->sCmn.frame_length * sizeof( SKP_int16 ) );
#endif
    
    
    
    
    SKP_Silk_find_pitch_lags_FIX( psEnc, &sEncCtrl, res_pitch, x_frame );

    
    
    
    SKP_Silk_noise_shape_analysis_FIX( psEnc, &sEncCtrl, res_pitch_frame, x_frame );

    
    
    
    SKP_Silk_prefilter_FIX( psEnc, &sEncCtrl, xfw, x_frame );

    
    
    
    SKP_Silk_find_pred_coefs_FIX( psEnc, &sEncCtrl, res_pitch );

    
    
    
    SKP_Silk_process_gains_FIX( psEnc, &sEncCtrl );
    
    
    
    
    
    nBytesLBRR = MAX_ARITHM_BYTES;
    SKP_Silk_LBRR_encode_FIX( psEnc, &sEncCtrl, LBRRpayload, &nBytesLBRR, xfw );

    
    
    
    if( psEnc->sCmn.nStatesDelayedDecision > 1 || psEnc->sCmn.warping_Q16 > 0 ) {
        SKP_Silk_NSQ_del_dec( &psEnc->sCmn, &sEncCtrl.sCmn, &psEnc->sCmn.sNSQ, xfw,
            psEnc->sCmn.q, sEncCtrl.sCmn.NLSFInterpCoef_Q2, 
            sEncCtrl.PredCoef_Q12[ 0 ], sEncCtrl.LTPCoef_Q14, sEncCtrl.AR2_Q13, sEncCtrl.HarmShapeGain_Q14, 
            sEncCtrl.Tilt_Q14, sEncCtrl.LF_shp_Q14, sEncCtrl.Gains_Q16, sEncCtrl.Lambda_Q10, 
            sEncCtrl.LTP_scale_Q14 );
    } else {
        SKP_Silk_NSQ( &psEnc->sCmn, &sEncCtrl.sCmn, &psEnc->sCmn.sNSQ, xfw, 
            psEnc->sCmn.q, sEncCtrl.sCmn.NLSFInterpCoef_Q2, 
            sEncCtrl.PredCoef_Q12[ 0 ], sEncCtrl.LTPCoef_Q14, sEncCtrl.AR2_Q13, sEncCtrl.HarmShapeGain_Q14, 
            sEncCtrl.Tilt_Q14, sEncCtrl.LF_shp_Q14, sEncCtrl.Gains_Q16, sEncCtrl.Lambda_Q10, 
            sEncCtrl.LTP_scale_Q14 );
    }

    
    
    
    if( psEnc->speech_activity_Q8 < SKP_FIX_CONST( SPEECH_ACTIVITY_DTX_THRES, 8 ) ) {
        psEnc->sCmn.vadFlag = NO_VOICE_ACTIVITY;
        psEnc->sCmn.noSpeechCounter++;
        if( psEnc->sCmn.noSpeechCounter > NO_SPEECH_FRAMES_BEFORE_DTX ) {
            psEnc->sCmn.inDTX = 1;
        }
        if( psEnc->sCmn.noSpeechCounter > MAX_CONSECUTIVE_DTX + NO_SPEECH_FRAMES_BEFORE_DTX ) {
            psEnc->sCmn.noSpeechCounter = NO_SPEECH_FRAMES_BEFORE_DTX;
            psEnc->sCmn.inDTX           = 0;
        }
    } else {
        psEnc->sCmn.noSpeechCounter = 0;
        psEnc->sCmn.inDTX           = 0;
        psEnc->sCmn.vadFlag         = VOICE_ACTIVITY;
    }

    
    
    
    if( psEnc->sCmn.nFramesInPayloadBuf == 0 ) {
        SKP_Silk_range_enc_init( &psEnc->sCmn.sRC );
        psEnc->sCmn.nBytesInPayloadBuf = 0;
    }

    
    
    
    SKP_Silk_encode_parameters( &psEnc->sCmn, &sEncCtrl.sCmn, &psEnc->sCmn.sRC, psEnc->sCmn.q );
    FrameTermination_CDF = SKP_Silk_FrameTermination_CDF;

    
    
    
    
    SKP_memmove( psEnc->x_buf, &psEnc->x_buf[ psEnc->sCmn.frame_length ], 
        ( psEnc->sCmn.frame_length + LA_SHAPE_MS * psEnc->sCmn.fs_kHz ) * sizeof( SKP_int16 ) );
    
    
    psEnc->sCmn.prev_sigtype            = sEncCtrl.sCmn.sigtype;
    psEnc->sCmn.prevLag                 = sEncCtrl.sCmn.pitchL[ NB_SUBFR - 1];
    psEnc->sCmn.first_frame_after_reset = 0;

    if( psEnc->sCmn.sRC.error ) {
        
        psEnc->sCmn.nFramesInPayloadBuf = 0;
    } else {
        psEnc->sCmn.nFramesInPayloadBuf++;
    }

    
    
    
    if( psEnc->sCmn.nFramesInPayloadBuf * FRAME_LENGTH_MS >= psEnc->sCmn.PacketSize_ms ) {

        LBRR_idx = ( psEnc->sCmn.oldest_LBRR_idx + 1 ) & LBRR_IDX_MASK;

        
        frame_terminator = SKP_SILK_LAST_FRAME;
        if( psEnc->sCmn.LBRR_buffer[ LBRR_idx ].usage == SKP_SILK_ADD_LBRR_TO_PLUS1 ) {
            frame_terminator = SKP_SILK_LBRR_VER1;
        }
        if( psEnc->sCmn.LBRR_buffer[ psEnc->sCmn.oldest_LBRR_idx ].usage == SKP_SILK_ADD_LBRR_TO_PLUS2 ) {
            frame_terminator = SKP_SILK_LBRR_VER2;
            LBRR_idx = psEnc->sCmn.oldest_LBRR_idx;
        }

        
        SKP_Silk_range_encoder( &psEnc->sCmn.sRC, frame_terminator, FrameTermination_CDF );

        
        SKP_Silk_range_coder_get_length( &psEnc->sCmn.sRC, &nBytes );

        
        if( *pnBytesOut >= nBytes ) {
            SKP_Silk_range_enc_wrap_up( &psEnc->sCmn.sRC );
            SKP_memcpy( pCode, psEnc->sCmn.sRC.buffer, nBytes * sizeof( SKP_uint8 ) );
            
            if( frame_terminator > SKP_SILK_MORE_FRAMES && 
                    *pnBytesOut >= nBytes + psEnc->sCmn.LBRR_buffer[ LBRR_idx ].nBytes ) {
                
                SKP_memcpy( &pCode[ nBytes ],
                    psEnc->sCmn.LBRR_buffer[ LBRR_idx ].payload,
                    psEnc->sCmn.LBRR_buffer[ LBRR_idx ].nBytes * sizeof( SKP_uint8 ) );
                nBytes += psEnc->sCmn.LBRR_buffer[ LBRR_idx ].nBytes;
            }

            *pnBytesOut = nBytes;

            
            SKP_memcpy( psEnc->sCmn.LBRR_buffer[ psEnc->sCmn.oldest_LBRR_idx ].payload, LBRRpayload, 
                nBytesLBRR * sizeof( SKP_uint8 ) );
            psEnc->sCmn.LBRR_buffer[ psEnc->sCmn.oldest_LBRR_idx ].nBytes = nBytesLBRR;
            
            psEnc->sCmn.LBRR_buffer[ psEnc->sCmn.oldest_LBRR_idx ].usage = sEncCtrl.sCmn.LBRR_usage;
            psEnc->sCmn.oldest_LBRR_idx = ( psEnc->sCmn.oldest_LBRR_idx + 1 ) & LBRR_IDX_MASK;

        } else {
            
            *pnBytesOut = 0;
            nBytes      = 0;
            ret = SKP_SILK_ENC_PAYLOAD_BUF_TOO_SHORT;
        }

        
        psEnc->sCmn.nFramesInPayloadBuf = 0;
    } else {
        
        *pnBytesOut = 0;

        
        frame_terminator = SKP_SILK_MORE_FRAMES;
        SKP_Silk_range_encoder( &psEnc->sCmn.sRC, frame_terminator, FrameTermination_CDF );

        
        SKP_Silk_range_coder_get_length( &psEnc->sCmn.sRC, &nBytes );
        
    }

    
    if( psEnc->sCmn.sRC.error ) {
        ret = SKP_SILK_ENC_INTERNAL_ERROR;
    }

    
    SKP_assert(  ( 8 * 1000 * ( (SKP_int64)nBytes - (SKP_int64)psEnc->sCmn.nBytesInPayloadBuf ) ) == 
        SKP_SAT32( 8 * 1000 * ( (SKP_int64)nBytes - (SKP_int64)psEnc->sCmn.nBytesInPayloadBuf ) ) );
    SKP_assert( psEnc->sCmn.TargetRate_bps > 0 );
    psEnc->BufferedInChannel_ms   += SKP_DIV32( 8 * 1000 * ( nBytes - psEnc->sCmn.nBytesInPayloadBuf ), psEnc->sCmn.TargetRate_bps );
    psEnc->BufferedInChannel_ms   -= FRAME_LENGTH_MS;
    psEnc->BufferedInChannel_ms    = SKP_LIMIT_int( psEnc->BufferedInChannel_ms, 0, 100 );
    psEnc->sCmn.nBytesInPayloadBuf = nBytes;

    if( psEnc->speech_activity_Q8 > SKP_FIX_CONST( WB_DETECT_ACTIVE_SPEECH_LEVEL_THRES, 8 ) ) {
        psEnc->sCmn.sSWBdetect.ActiveSpeech_ms = SKP_ADD_POS_SAT32( psEnc->sCmn.sSWBdetect.ActiveSpeech_ms, FRAME_LENGTH_MS ); 
    }


    return( ret );
}


void SKP_Silk_LBRR_encode_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl,     
    SKP_uint8                       *pCode,         
    SKP_int16                       *pnBytesOut,    
    SKP_int16                       xfw[]           
)
{
    SKP_int     TempGainsIndices[ NB_SUBFR ], frame_terminator;
    SKP_int     nBytes, nFramesInPayloadBuf;
    SKP_int32   TempGains_Q16[ NB_SUBFR ];
    SKP_int     typeOffset, LTP_scaleIndex, Rate_only_parameters = 0;
    
    
    
    SKP_Silk_LBRR_ctrl_FIX( psEnc, &psEncCtrl->sCmn );

    if( psEnc->sCmn.LBRR_enabled ) {
        
        SKP_memcpy( TempGainsIndices, psEncCtrl->sCmn.GainsIndices, NB_SUBFR * sizeof( SKP_int   ) );
        SKP_memcpy( TempGains_Q16,    psEncCtrl->Gains_Q16,         NB_SUBFR * sizeof( SKP_int32 ) );

        typeOffset     = psEnc->sCmn.typeOffsetPrev; 
        LTP_scaleIndex = psEncCtrl->sCmn.LTP_scaleIndex;

        
        if( psEnc->sCmn.fs_kHz == 8 ) {
            Rate_only_parameters = 13500;
        } else if( psEnc->sCmn.fs_kHz == 12 ) {
            Rate_only_parameters = 15500;
        } else if( psEnc->sCmn.fs_kHz == 16 ) {
            Rate_only_parameters = 17500;
        } else if( psEnc->sCmn.fs_kHz == 24 ) {
            Rate_only_parameters = 19500;
        } else {
            SKP_assert( 0 );
        }

        if( psEnc->sCmn.Complexity > 0 && psEnc->sCmn.TargetRate_bps > Rate_only_parameters ) {
            if( psEnc->sCmn.nFramesInPayloadBuf == 0 ) {
                
                SKP_memcpy( &psEnc->sCmn.sNSQ_LBRR, &psEnc->sCmn.sNSQ, sizeof( SKP_Silk_nsq_state ) );

                psEnc->sCmn.LBRRprevLastGainIndex = psEnc->sShape.LastGainIndex;
                
                psEncCtrl->sCmn.GainsIndices[ 0 ] = psEncCtrl->sCmn.GainsIndices[ 0 ] + psEnc->sCmn.LBRR_GainIncreases;
                psEncCtrl->sCmn.GainsIndices[ 0 ] = SKP_LIMIT_int( psEncCtrl->sCmn.GainsIndices[ 0 ], 0, N_LEVELS_QGAIN - 1 );
            }
            
            
            SKP_Silk_gains_dequant( psEncCtrl->Gains_Q16, psEncCtrl->sCmn.GainsIndices, 
                &psEnc->sCmn.LBRRprevLastGainIndex, psEnc->sCmn.nFramesInPayloadBuf );

            
            
            
            if( psEnc->sCmn.nStatesDelayedDecision > 1 || psEnc->sCmn.warping_Q16 > 0 ) {
                SKP_Silk_NSQ_del_dec( &psEnc->sCmn, &psEncCtrl->sCmn, &psEnc->sCmn.sNSQ_LBRR, xfw, psEnc->sCmn.q_LBRR, 
                    psEncCtrl->sCmn.NLSFInterpCoef_Q2, psEncCtrl->PredCoef_Q12[ 0 ], psEncCtrl->LTPCoef_Q14, 
                    psEncCtrl->AR2_Q13, psEncCtrl->HarmShapeGain_Q14, psEncCtrl->Tilt_Q14, psEncCtrl->LF_shp_Q14, 
                    psEncCtrl->Gains_Q16, psEncCtrl->Lambda_Q10, psEncCtrl->LTP_scale_Q14 );
            } else {
                SKP_Silk_NSQ( &psEnc->sCmn, &psEncCtrl->sCmn, &psEnc->sCmn.sNSQ_LBRR, xfw, psEnc->sCmn.q_LBRR, 
                    psEncCtrl->sCmn.NLSFInterpCoef_Q2, psEncCtrl->PredCoef_Q12[ 0 ], psEncCtrl->LTPCoef_Q14, 
                    psEncCtrl->AR2_Q13, psEncCtrl->HarmShapeGain_Q14, psEncCtrl->Tilt_Q14, psEncCtrl->LF_shp_Q14, 
                    psEncCtrl->Gains_Q16, psEncCtrl->Lambda_Q10, psEncCtrl->LTP_scale_Q14 );
            }
        } else {
            SKP_memset( psEnc->sCmn.q_LBRR, 0, psEnc->sCmn.frame_length * sizeof( SKP_int8 ) );
            psEncCtrl->sCmn.LTP_scaleIndex = 0;
        }
        
        
        
        if( psEnc->sCmn.nFramesInPayloadBuf == 0 ) {
            SKP_Silk_range_enc_init( &psEnc->sCmn.sRC_LBRR );
            psEnc->sCmn.nBytesInPayloadBuf = 0;
        }

        
        
        
        SKP_Silk_encode_parameters( &psEnc->sCmn, &psEncCtrl->sCmn, 
            &psEnc->sCmn.sRC_LBRR, psEnc->sCmn.q_LBRR );

        if( psEnc->sCmn.sRC_LBRR.error ) {
            
            nFramesInPayloadBuf = 0;
        } else {
            nFramesInPayloadBuf = psEnc->sCmn.nFramesInPayloadBuf + 1;
        }

        
        
        
        if( SKP_SMULBB( nFramesInPayloadBuf, FRAME_LENGTH_MS ) >= psEnc->sCmn.PacketSize_ms ) {

            
            frame_terminator = SKP_SILK_LAST_FRAME;

            
            SKP_Silk_range_encoder( &psEnc->sCmn.sRC_LBRR, frame_terminator, SKP_Silk_FrameTermination_CDF );

            
            SKP_Silk_range_coder_get_length( &psEnc->sCmn.sRC_LBRR, &nBytes );

            
            if( *pnBytesOut >= nBytes ) {
                SKP_Silk_range_enc_wrap_up( &psEnc->sCmn.sRC_LBRR );
                SKP_memcpy( pCode, psEnc->sCmn.sRC_LBRR.buffer, nBytes * sizeof( SKP_uint8 ) );

                *pnBytesOut = nBytes;
            } else {
                
                *pnBytesOut = 0;
                SKP_assert( 0 );
            }
        } else {
            
            *pnBytesOut = 0;

            
            frame_terminator = SKP_SILK_MORE_FRAMES;
            SKP_Silk_range_encoder( &psEnc->sCmn.sRC_LBRR, frame_terminator, SKP_Silk_FrameTermination_CDF );
        }

        
        SKP_memcpy( psEncCtrl->sCmn.GainsIndices, TempGainsIndices, NB_SUBFR * sizeof( SKP_int   ) );
        SKP_memcpy( psEncCtrl->Gains_Q16,         TempGains_Q16,    NB_SUBFR * sizeof( SKP_int32 ) );
    
        
        psEncCtrl->sCmn.LTP_scaleIndex = LTP_scaleIndex;
        psEnc->sCmn.typeOffsetPrev = typeOffset;
    }
}









void SKP_Silk_encode_parameters(
    SKP_Silk_encoder_state          *psEncC,        
    SKP_Silk_encoder_control        *psEncCtrlC,    
    SKP_Silk_range_coder_state      *psRC,          
    const SKP_int8                  *q              
)
{
    SKP_int   i, k, typeOffset;
    const SKP_Silk_NLSF_CB_struct *psNLSF_CB;


    
    
    
    
    if( psEncC->nFramesInPayloadBuf == 0 ) {
        
        for( i = 0; i < 3; i++ ) {
            if( SKP_Silk_SamplingRates_table[ i ] == psEncC->fs_kHz ) {
                break;
            }
        }
        SKP_Silk_range_encoder( psRC, i, SKP_Silk_SamplingRates_CDF );
    }

    
    
    
    typeOffset = 2 * psEncCtrlC->sigtype + psEncCtrlC->QuantOffsetType;
    if( psEncC->nFramesInPayloadBuf == 0 ) {
        
        SKP_Silk_range_encoder( psRC, typeOffset, SKP_Silk_type_offset_CDF );
    } else {
        
        SKP_Silk_range_encoder( psRC, typeOffset, SKP_Silk_type_offset_joint_CDF[ psEncC->typeOffsetPrev ] );
    }
    psEncC->typeOffsetPrev = typeOffset;

    
    
    
    
    if( psEncC->nFramesInPayloadBuf == 0 ) {
        
        SKP_Silk_range_encoder( psRC, psEncCtrlC->GainsIndices[ 0 ], SKP_Silk_gain_CDF[ psEncCtrlC->sigtype ] );
    } else {
        
        SKP_Silk_range_encoder( psRC, psEncCtrlC->GainsIndices[ 0 ], SKP_Silk_delta_gain_CDF );
    }

    
    for( i = 1; i < NB_SUBFR; i++ ) {
        SKP_Silk_range_encoder( psRC, psEncCtrlC->GainsIndices[ i ], SKP_Silk_delta_gain_CDF );
    }


    
    
    
    
    psNLSF_CB = psEncC->psNLSF_CB[ psEncCtrlC->sigtype ];
    SKP_Silk_range_encoder_multi( psRC, psEncCtrlC->NLSFIndices, psNLSF_CB->StartPtr, psNLSF_CB->nStages );

    
    SKP_assert( psEncC->useInterpolatedNLSFs == 1 || psEncCtrlC->NLSFInterpCoef_Q2 == ( 1 << 2 ) );
    SKP_Silk_range_encoder( psRC, psEncCtrlC->NLSFInterpCoef_Q2, SKP_Silk_NLSF_interpolation_factor_CDF );


    if( psEncCtrlC->sigtype == SIG_TYPE_VOICED ) {
        
        
        


        
        if( psEncC->fs_kHz == 8 ) {
            SKP_Silk_range_encoder( psRC, psEncCtrlC->lagIndex, SKP_Silk_pitch_lag_NB_CDF );
        } else if( psEncC->fs_kHz == 12 ) {
            SKP_Silk_range_encoder( psRC, psEncCtrlC->lagIndex, SKP_Silk_pitch_lag_MB_CDF );
        } else if( psEncC->fs_kHz == 16 ) {
            SKP_Silk_range_encoder( psRC, psEncCtrlC->lagIndex, SKP_Silk_pitch_lag_WB_CDF );
        } else {
            SKP_Silk_range_encoder( psRC, psEncCtrlC->lagIndex, SKP_Silk_pitch_lag_SWB_CDF );
        }


        
        if( psEncC->fs_kHz == 8 ) {
            
            SKP_Silk_range_encoder( psRC, psEncCtrlC->contourIndex, SKP_Silk_pitch_contour_NB_CDF );
        } else {
            
            SKP_Silk_range_encoder( psRC, psEncCtrlC->contourIndex, SKP_Silk_pitch_contour_CDF );
        }

        
        
        

        
        SKP_Silk_range_encoder( psRC, psEncCtrlC->PERIndex, SKP_Silk_LTP_per_index_CDF );

        
        for( k = 0; k < NB_SUBFR; k++ ) {
            SKP_Silk_range_encoder( psRC, psEncCtrlC->LTPIndex[ k ], SKP_Silk_LTP_gain_CDF_ptrs[ psEncCtrlC->PERIndex ] );
        }

        
        
        
        SKP_Silk_range_encoder( psRC, psEncCtrlC->LTP_scaleIndex, SKP_Silk_LTPscale_CDF );
    }


    
    
    
    SKP_Silk_range_encoder( psRC, psEncCtrlC->Seed, SKP_Silk_Seed_CDF );

    
    
    
    SKP_Silk_encode_pulses( psRC, psEncCtrlC->sigtype, psEncCtrlC->QuantOffsetType, q, psEncC->frame_length );


    
    
    
    SKP_Silk_range_encoder( psRC, psEncC->vadFlag, SKP_Silk_vadflag_CDF );
}










SKP_INLINE SKP_int combine_and_check(       
    SKP_int         *pulses_comb,           
    const SKP_int   *pulses_in,             
    SKP_int         max_pulses,             
    SKP_int         len                     
) 
{
    SKP_int k, sum;

    for( k = 0; k < len; k++ ) {
        sum = pulses_in[ 2 * k ] + pulses_in[ 2 * k + 1 ];
        if( sum > max_pulses ) {
            return 1;
        }
        pulses_comb[ k ] = sum;
    }

    return 0;
}


void SKP_Silk_encode_pulses(
    SKP_Silk_range_coder_state      *psRC,          
    const SKP_int                   sigtype,        
    const SKP_int                   QuantOffsetType,
    const SKP_int8                  q[],            
    const SKP_int                   frame_length    
)
{
    SKP_int   i, k, j, iter, bit, nLS, scale_down, RateLevelIndex = 0;
    SKP_int32 abs_q, minSumBits_Q6, sumBits_Q6;
    SKP_int   abs_pulses[ MAX_FRAME_LENGTH ];
    SKP_int   sum_pulses[ MAX_NB_SHELL_BLOCKS ];
    SKP_int   nRshifts[   MAX_NB_SHELL_BLOCKS ];
    SKP_int   pulses_comb[ 8 ];
    SKP_int   *abs_pulses_ptr;
    const SKP_int8 *pulses_ptr;
    const SKP_uint16 *cdf_ptr;
    const SKP_int16 *nBits_ptr;

    SKP_memset( pulses_comb, 0, 8 * sizeof( SKP_int ) ); 

    
    
    
    
    iter = frame_length / SHELL_CODEC_FRAME_LENGTH;
    
    
    for( i = 0; i < frame_length; i+=4 ) {
        abs_pulses[i+0] = ( SKP_int )SKP_abs( q[ i + 0 ] );
        abs_pulses[i+1] = ( SKP_int )SKP_abs( q[ i + 1 ] );
        abs_pulses[i+2] = ( SKP_int )SKP_abs( q[ i + 2 ] );
        abs_pulses[i+3] = ( SKP_int )SKP_abs( q[ i + 3 ] );
    }

    
    abs_pulses_ptr = abs_pulses;
    for( i = 0; i < iter; i++ ) {
        nRshifts[ i ] = 0;

        while( 1 ) {
            
            scale_down = combine_and_check( pulses_comb, abs_pulses_ptr, SKP_Silk_max_pulses_table[ 0 ], 8 );

            
            scale_down += combine_and_check( pulses_comb, pulses_comb, SKP_Silk_max_pulses_table[ 1 ], 4 );

            
            scale_down += combine_and_check( pulses_comb, pulses_comb, SKP_Silk_max_pulses_table[ 2 ], 2 );

            
            sum_pulses[ i ] = pulses_comb[ 0 ] + pulses_comb[ 1 ];
            if( sum_pulses[ i ] > SKP_Silk_max_pulses_table[ 3 ] ) {
                scale_down++;
            }

            if( scale_down ) {
                
                nRshifts[ i ]++;                
                for( k = 0; k < SHELL_CODEC_FRAME_LENGTH; k++ ) {
                    abs_pulses_ptr[ k ] = SKP_RSHIFT( abs_pulses_ptr[ k ], 1 );
                }
            } else {
                
                break;
            }
        }
        abs_pulses_ptr += SHELL_CODEC_FRAME_LENGTH;
    }

    
    
    
    
    minSumBits_Q6 = SKP_int32_MAX;
    for( k = 0; k < N_RATE_LEVELS - 1; k++ ) {
        nBits_ptr  = SKP_Silk_pulses_per_block_BITS_Q6[ k ];
        sumBits_Q6 = SKP_Silk_rate_levels_BITS_Q6[sigtype][ k ];
        for( i = 0; i < iter; i++ ) {
            if( nRshifts[ i ] > 0 ) {
                sumBits_Q6 += nBits_ptr[ MAX_PULSES + 1 ];
            } else {
                sumBits_Q6 += nBits_ptr[ sum_pulses[ i ] ];
            }
        }
        if( sumBits_Q6 < minSumBits_Q6 ) {
            minSumBits_Q6 = sumBits_Q6;
            RateLevelIndex = k;
        }
    }
    SKP_Silk_range_encoder( psRC, RateLevelIndex, SKP_Silk_rate_levels_CDF[ sigtype ] );

    
    
    
    cdf_ptr = SKP_Silk_pulses_per_block_CDF[ RateLevelIndex ];
    for( i = 0; i < iter; i++ ) {
        if( nRshifts[ i ] == 0 ) {
            SKP_Silk_range_encoder( psRC, sum_pulses[ i ], cdf_ptr );
        } else {
            SKP_Silk_range_encoder( psRC, MAX_PULSES + 1, cdf_ptr );
            for( k = 0; k < nRshifts[ i ] - 1; k++ ) {
                SKP_Silk_range_encoder( psRC, MAX_PULSES + 1, SKP_Silk_pulses_per_block_CDF[ N_RATE_LEVELS - 1 ] );
            }
            SKP_Silk_range_encoder( psRC, sum_pulses[ i ], SKP_Silk_pulses_per_block_CDF[ N_RATE_LEVELS - 1 ] );
        }
    }

    
    
    
    for( i = 0; i < iter; i++ ) {
        if( sum_pulses[ i ] > 0 ) {
            SKP_Silk_shell_encoder( psRC, &abs_pulses[ i * SHELL_CODEC_FRAME_LENGTH ] );
        }
    }

    
    
    
    for( i = 0; i < iter; i++ ) {
        if( nRshifts[ i ] > 0 ) {
            pulses_ptr = &q[ i * SHELL_CODEC_FRAME_LENGTH ];
            nLS = nRshifts[ i ] - 1;
            for( k = 0; k < SHELL_CODEC_FRAME_LENGTH; k++ ) {
                abs_q = (SKP_int8)SKP_abs( pulses_ptr[ k ] );
                for( j = nLS; j > 0; j-- ) {
                    bit = SKP_RSHIFT( abs_q, j ) & 1;
                    SKP_Silk_range_encoder( psRC, bit, SKP_Silk_lsb_CDF );
                }
                bit = abs_q & 1;
                SKP_Silk_range_encoder( psRC, bit, SKP_Silk_lsb_CDF );
            }
        }
    }

    
    
    
    SKP_Silk_encode_signs( psRC, q, frame_length, sigtype, QuantOffsetType, RateLevelIndex );
}








void SKP_Silk_find_LPC_FIX(
    SKP_int             NLSF_Q15[],             
    SKP_int             *interpIndex,           
    const SKP_int       prev_NLSFq_Q15[],       
    const SKP_int       useInterpolatedNLSFs,   
    const SKP_int       LPC_order,              
    const SKP_int16     x[],                    
    const SKP_int       subfr_length            
)
{
    SKP_int     k;
    SKP_int32   a_Q16[ MAX_LPC_ORDER ];
    SKP_int     isInterpLower, shift;
    SKP_int16   S[ MAX_LPC_ORDER ];
    SKP_int32   res_nrg0, res_nrg1;
    SKP_int     rshift0, rshift1; 

    
    SKP_int32   a_tmp_Q16[ MAX_LPC_ORDER ], res_nrg_interp, res_nrg, res_tmp_nrg;
    SKP_int     res_nrg_interp_Q, res_nrg_Q, res_tmp_nrg_Q;
    SKP_int16   a_tmp_Q12[ MAX_LPC_ORDER ];
    SKP_int     NLSF0_Q15[ MAX_LPC_ORDER ];
    SKP_int16   LPC_res[ ( MAX_FRAME_LENGTH + NB_SUBFR * MAX_LPC_ORDER ) / 2 ];

    
    *interpIndex = 4;

    
    SKP_Silk_burg_modified( &res_nrg, &res_nrg_Q, a_Q16, x, subfr_length, NB_SUBFR, SKP_FIX_CONST( FIND_LPC_COND_FAC, 32 ), LPC_order );

    SKP_Silk_bwexpander_32( a_Q16, LPC_order, SKP_FIX_CONST( FIND_LPC_CHIRP, 16 ) );

    if( useInterpolatedNLSFs == 1 ) {

        
        SKP_Silk_burg_modified( &res_tmp_nrg, &res_tmp_nrg_Q, a_tmp_Q16, x + ( NB_SUBFR >> 1 ) * subfr_length, 
            subfr_length, ( NB_SUBFR >> 1 ), SKP_FIX_CONST( FIND_LPC_COND_FAC, 32 ), LPC_order );

        SKP_Silk_bwexpander_32( a_tmp_Q16, LPC_order, SKP_FIX_CONST( FIND_LPC_CHIRP, 16 ) );

        
        
        shift = res_tmp_nrg_Q - res_nrg_Q;
        if( shift >= 0 ) {
            if( shift < 32 ) { 
                res_nrg = res_nrg - SKP_RSHIFT( res_tmp_nrg, shift );
            }
        } else {
            SKP_assert( shift > -32 ); 
            res_nrg   = SKP_RSHIFT( res_nrg, -shift ) - res_tmp_nrg;
            res_nrg_Q = res_tmp_nrg_Q; 
        }
        
        
        SKP_Silk_A2NLSF( NLSF_Q15, a_tmp_Q16, LPC_order );

        
        for( k = 3; k >= 0; k-- ) {
            
            SKP_Silk_interpolate( NLSF0_Q15, prev_NLSFq_Q15, NLSF_Q15, k, LPC_order );

            
            SKP_Silk_NLSF2A_stable( a_tmp_Q12, NLSF0_Q15, LPC_order );

            
            SKP_memset( S, 0, LPC_order * sizeof( SKP_int16 ) );
            SKP_Silk_LPC_analysis_filter( x, a_tmp_Q12, S, LPC_res, 2 * subfr_length, LPC_order );

            SKP_Silk_sum_sqr_shift( &res_nrg0, &rshift0, LPC_res + LPC_order,                subfr_length - LPC_order );
            SKP_Silk_sum_sqr_shift( &res_nrg1, &rshift1, LPC_res + LPC_order + subfr_length, subfr_length - LPC_order );

            
            shift = rshift0 - rshift1;
            if( shift >= 0 ) {
                res_nrg1         = SKP_RSHIFT( res_nrg1, shift );
                res_nrg_interp_Q = -rshift0;
            } else {
                res_nrg0         = SKP_RSHIFT( res_nrg0, -shift );
                res_nrg_interp_Q = -rshift1;
            }
            res_nrg_interp = SKP_ADD32( res_nrg0, res_nrg1 );

            
            shift = res_nrg_interp_Q - res_nrg_Q;
            if( shift >= 0 ) {
                if( SKP_RSHIFT( res_nrg_interp, shift ) < res_nrg ) {
                    isInterpLower = SKP_TRUE;
                } else {
                    isInterpLower = SKP_FALSE;
                }
            } else {
                if( -shift < 32 ) { 
                    if( res_nrg_interp < SKP_RSHIFT( res_nrg, -shift ) ) {
                        isInterpLower = SKP_TRUE;
                    } else {
                        isInterpLower = SKP_FALSE;
                    }
                } else {
                    isInterpLower = SKP_FALSE;
                }
            }

            
            if( isInterpLower == SKP_TRUE ) {
                
                res_nrg   = res_nrg_interp;
                res_nrg_Q = res_nrg_interp_Q;
                *interpIndex = k;
            }
        }
    }

    if( *interpIndex == 4 ) {
        
        SKP_Silk_A2NLSF( NLSF_Q15, a_Q16, LPC_order );
    }
}








#define LTP_CORRS_HEAD_ROOM                             2

void SKP_Silk_fit_LTP(
    SKP_int32 LTP_coefs_Q16[ LTP_ORDER ],
    SKP_int16 LTP_coefs_Q14[ LTP_ORDER ]
);

void SKP_Silk_find_LTP_FIX(
    SKP_int16           b_Q14[ NB_SUBFR * LTP_ORDER ],              
    SKP_int32           WLTP[ NB_SUBFR * LTP_ORDER * LTP_ORDER ],   
    SKP_int             *LTPredCodGain_Q7,                          
    const SKP_int16     r_first[],                                  
    const SKP_int16     r_last[],                                   
    const SKP_int       lag[ NB_SUBFR ],                            
    const SKP_int32     Wght_Q15[ NB_SUBFR ],                       
    const SKP_int       subfr_length,                               
    const SKP_int       mem_offset,                                 
    SKP_int             corr_rshifts[ NB_SUBFR ]                    
)
{
    SKP_int   i, k, lshift;
    const SKP_int16 *r_ptr, *lag_ptr;
    SKP_int16 *b_Q14_ptr;

    SKP_int32 regu;
    SKP_int32 *WLTP_ptr;
    SKP_int32 b_Q16[ LTP_ORDER ], delta_b_Q14[ LTP_ORDER ], d_Q14[ NB_SUBFR ], nrg[ NB_SUBFR ], g_Q26;
    SKP_int32 w[ NB_SUBFR ], WLTP_max, max_abs_d_Q14, max_w_bits;

    SKP_int32 temp32, denom32;
    SKP_int   extra_shifts;
    SKP_int   rr_shifts, maxRshifts, maxRshifts_wxtra, LZs;
    SKP_int32 LPC_res_nrg, LPC_LTP_res_nrg, div_Q16;
    SKP_int32 Rr[ LTP_ORDER ], rr[ NB_SUBFR ];
    SKP_int32 wd, m_Q12;
    
    b_Q14_ptr = b_Q14;
    WLTP_ptr  = WLTP;
    r_ptr     = &r_first[ mem_offset ];
    for( k = 0; k < NB_SUBFR; k++ ) {
        if( k == ( NB_SUBFR >> 1 ) ) { 
            r_ptr = &r_last[ mem_offset ];
        }
        lag_ptr = r_ptr - ( lag[ k ] + LTP_ORDER / 2 );

        SKP_Silk_sum_sqr_shift( &rr[ k ], &rr_shifts, r_ptr, subfr_length ); 

        
        LZs = SKP_Silk_CLZ32( rr[k] );
        if( LZs < LTP_CORRS_HEAD_ROOM ) {
            rr[ k ] = SKP_RSHIFT_ROUND( rr[ k ], LTP_CORRS_HEAD_ROOM - LZs );
            rr_shifts += ( LTP_CORRS_HEAD_ROOM - LZs );
        }
        corr_rshifts[ k ] = rr_shifts;
        SKP_Silk_corrMatrix_FIX( lag_ptr, subfr_length, LTP_ORDER, LTP_CORRS_HEAD_ROOM, WLTP_ptr, &corr_rshifts[ k ] );  

        
        SKP_Silk_corrVector_FIX( lag_ptr, r_ptr, subfr_length, LTP_ORDER, Rr, corr_rshifts[ k ] );  
        if( corr_rshifts[ k ] > rr_shifts ) {
            rr[ k ] = SKP_RSHIFT( rr[ k ], corr_rshifts[ k ] - rr_shifts ); 
        }
        SKP_assert( rr[ k ] >= 0 );

        regu = 1;
        regu = SKP_SMLAWB( regu, rr[ k ], SKP_FIX_CONST( LTP_DAMPING/3, 16 ) );
        regu = SKP_SMLAWB( regu, matrix_ptr( WLTP_ptr, 0, 0, LTP_ORDER ), SKP_FIX_CONST( LTP_DAMPING/3, 16 ) );
        regu = SKP_SMLAWB( regu, matrix_ptr( WLTP_ptr, LTP_ORDER-1, LTP_ORDER-1, LTP_ORDER ), SKP_FIX_CONST( LTP_DAMPING/3, 16 ) );
        SKP_Silk_regularize_correlations_FIX( WLTP_ptr, &rr[k], regu, LTP_ORDER );

        SKP_Silk_solve_LDL_FIX( WLTP_ptr, LTP_ORDER, Rr, b_Q16 ); 

        
        SKP_Silk_fit_LTP( b_Q16, b_Q14_ptr );

        
        nrg[ k ] = SKP_Silk_residual_energy16_covar_FIX( b_Q14_ptr, WLTP_ptr, Rr, rr[ k ], LTP_ORDER, 14 ); 

        
        extra_shifts = SKP_min_int( corr_rshifts[ k ], LTP_CORRS_HEAD_ROOM );
        denom32 = SKP_LSHIFT_SAT32( SKP_SMULWB( nrg[ k ], Wght_Q15[ k ] ), 1 + extra_shifts ) + 
            SKP_RSHIFT( SKP_SMULWB( subfr_length, 655 ), corr_rshifts[ k ] - extra_shifts );    
        denom32 = SKP_max( denom32, 1 );
        SKP_assert( ((SKP_int64)Wght_Q15[ k ] << 16 ) < SKP_int32_MAX );                        
        temp32 = SKP_DIV32( SKP_LSHIFT( ( SKP_int32 )Wght_Q15[ k ], 16 ), denom32 );            
        temp32 = SKP_RSHIFT( temp32, 31 + corr_rshifts[ k ] - extra_shifts - 26 );              
        
        
        WLTP_max = 0;
        for( i = 0; i < LTP_ORDER * LTP_ORDER; i++ ) {
            WLTP_max = SKP_max( WLTP_ptr[ i ], WLTP_max );
        }
        lshift = SKP_Silk_CLZ32( WLTP_max ) - 1 - 3; 
        SKP_assert( 26 - 18 + lshift >= 0 );
        if( 26 - 18 + lshift < 31 ) {
            temp32 = SKP_min_32( temp32, SKP_LSHIFT( ( SKP_int32 )1, 26 - 18 + lshift ) );
        }

        SKP_Silk_scale_vector32_Q26_lshift_18( WLTP_ptr, temp32, LTP_ORDER * LTP_ORDER ); 
        
        w[ k ] = matrix_ptr( WLTP_ptr, ( LTP_ORDER >> 1 ), ( LTP_ORDER >> 1 ), LTP_ORDER ); 
        SKP_assert( w[k] >= 0 );

        r_ptr     += subfr_length;
        b_Q14_ptr += LTP_ORDER;
        WLTP_ptr  += LTP_ORDER * LTP_ORDER;
    }

    maxRshifts = 0;
    for( k = 0; k < NB_SUBFR; k++ ) {
        maxRshifts = SKP_max_int( corr_rshifts[ k ], maxRshifts );
    }

    
    if( LTPredCodGain_Q7 != NULL ) {
        LPC_LTP_res_nrg = 0;
        LPC_res_nrg     = 0;
        SKP_assert( LTP_CORRS_HEAD_ROOM >= 2 ); 
        for( k = 0; k < NB_SUBFR; k++ ) {
            LPC_res_nrg     = SKP_ADD32( LPC_res_nrg,     SKP_RSHIFT( SKP_ADD32( SKP_SMULWB(  rr[ k ], Wght_Q15[ k ] ), 1 ), 1 + ( maxRshifts - corr_rshifts[ k ] ) ) ); 
            LPC_LTP_res_nrg = SKP_ADD32( LPC_LTP_res_nrg, SKP_RSHIFT( SKP_ADD32( SKP_SMULWB( nrg[ k ], Wght_Q15[ k ] ), 1 ), 1 + ( maxRshifts - corr_rshifts[ k ] ) ) ); 
        }
        LPC_LTP_res_nrg = SKP_max( LPC_LTP_res_nrg, 1 ); 

        div_Q16 = SKP_DIV32_varQ( LPC_res_nrg, LPC_LTP_res_nrg, 16 );
        *LTPredCodGain_Q7 = ( SKP_int )SKP_SMULBB( 3, SKP_Silk_lin2log( div_Q16 ) - ( 16 << 7 ) );

        SKP_assert( *LTPredCodGain_Q7 == ( SKP_int )SKP_SAT16( SKP_MUL( 3, SKP_Silk_lin2log( div_Q16 ) - ( 16 << 7 ) ) ) );
    }

    
    
    b_Q14_ptr = b_Q14;
    for( k = 0; k < NB_SUBFR; k++ ) {
        d_Q14[ k ] = 0;
        for( i = 0; i < LTP_ORDER; i++ ) {
            d_Q14[ k ] += b_Q14_ptr[ i ];
        }
        b_Q14_ptr += LTP_ORDER;
    }

    
        
    
    max_abs_d_Q14 = 0;
    max_w_bits    = 0;
    for( k = 0; k < NB_SUBFR; k++ ) {
        max_abs_d_Q14 = SKP_max_32( max_abs_d_Q14, SKP_abs( d_Q14[ k ] ) );
        
        
        max_w_bits = SKP_max_32( max_w_bits, 32 - SKP_Silk_CLZ32( w[ k ] ) + corr_rshifts[ k ] - maxRshifts ); 
    }

    
    SKP_assert( max_abs_d_Q14 <= ( 5 << 15 ) );

    
    extra_shifts = max_w_bits + 32 - SKP_Silk_CLZ32( max_abs_d_Q14 ) - 14;
    
    
    extra_shifts -= ( 32 - 1 - 2 + maxRshifts ); 
    extra_shifts = SKP_max_int( extra_shifts, 0 );

    maxRshifts_wxtra = maxRshifts + extra_shifts;
    
    temp32 = SKP_RSHIFT( 262, maxRshifts + extra_shifts ) + 1; 
    wd = 0;
    for( k = 0; k < NB_SUBFR; k++ ) {
        
        temp32 = SKP_ADD32( temp32,                     SKP_RSHIFT( w[ k ], maxRshifts_wxtra - corr_rshifts[ k ] ) );                    
        wd     = SKP_ADD32( wd, SKP_LSHIFT( SKP_SMULWW( SKP_RSHIFT( w[ k ], maxRshifts_wxtra - corr_rshifts[ k ] ), d_Q14[ k ] ), 2 ) ); 
    }
    m_Q12 = SKP_DIV32_varQ( wd, temp32, 12 );

    b_Q14_ptr = b_Q14;
    for( k = 0; k < NB_SUBFR; k++ ) {
        
        if( 2 - corr_rshifts[k] > 0 ) {
            temp32 = SKP_RSHIFT( w[ k ], 2 - corr_rshifts[ k ] );
        } else {
            temp32 = SKP_LSHIFT_SAT32( w[ k ], corr_rshifts[ k ] - 2 );
        }

        g_Q26 = SKP_MUL( 
            SKP_DIV32( 
                SKP_FIX_CONST( LTP_SMOOTHING, 26 ), 
                SKP_RSHIFT( SKP_FIX_CONST( LTP_SMOOTHING, 26 ), 10 ) + temp32 ),                                        
            SKP_LSHIFT_SAT32( SKP_SUB_SAT32( ( SKP_int32 )m_Q12, SKP_RSHIFT( d_Q14[ k ], 2 ) ), 4 ) );  

        temp32 = 0;
        for( i = 0; i < LTP_ORDER; i++ ) {
            delta_b_Q14[ i ] = SKP_max_16( b_Q14_ptr[ i ], 1638 );  
            temp32 += delta_b_Q14[ i ];                          
        }
        temp32 = SKP_DIV32( g_Q26, temp32 ); 
        for( i = 0; i < LTP_ORDER; i++ ) {
            b_Q14_ptr[ i ] = SKP_LIMIT_32( ( SKP_int32 )b_Q14_ptr[ i ] + SKP_SMULWB( SKP_LSHIFT_SAT32( temp32, 4 ), delta_b_Q14[ i ] ), -16000, 28000 );
        }
        b_Q14_ptr += LTP_ORDER;
    }
}

void SKP_Silk_fit_LTP(
    SKP_int32 LTP_coefs_Q16[ LTP_ORDER ],
    SKP_int16 LTP_coefs_Q14[ LTP_ORDER ]
)
{
    SKP_int i;

    for( i = 0; i < LTP_ORDER; i++ ) {
        LTP_coefs_Q14[ i ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( LTP_coefs_Q16[ i ], 2 ) );
    }
}








void SKP_Silk_find_pitch_lags_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl,     
    SKP_int16                       res[],          
    const SKP_int16                 x[]             
)
{
    SKP_Silk_predict_state_FIX *psPredSt = &psEnc->sPred;
    SKP_int   buf_len, i, scale;
    SKP_int32 thrhld_Q15, res_nrg;
    const SKP_int16 *x_buf, *x_buf_ptr;
    SKP_int16 Wsig[      FIND_PITCH_LPC_WIN_MAX ], *Wsig_ptr;
    SKP_int32 auto_corr[ MAX_FIND_PITCH_LPC_ORDER + 1 ];
    SKP_int16 rc_Q15[    MAX_FIND_PITCH_LPC_ORDER ];
    SKP_int32 A_Q24[     MAX_FIND_PITCH_LPC_ORDER ];
    SKP_int32 FiltState[ MAX_FIND_PITCH_LPC_ORDER ];
    SKP_int16 A_Q12[     MAX_FIND_PITCH_LPC_ORDER ];

    
    
    
    buf_len = SKP_ADD_LSHIFT( psEnc->sCmn.la_pitch, psEnc->sCmn.frame_length, 1 );

    
    SKP_assert( buf_len >= psPredSt->pitch_LPC_win_length );

    x_buf = x - psEnc->sCmn.frame_length;

    
    
    
    
    
    
    
    x_buf_ptr = x_buf + buf_len - psPredSt->pitch_LPC_win_length;
    Wsig_ptr  = Wsig;
    SKP_Silk_apply_sine_window( Wsig_ptr, x_buf_ptr, 1, psEnc->sCmn.la_pitch );

    
    Wsig_ptr  += psEnc->sCmn.la_pitch;
    x_buf_ptr += psEnc->sCmn.la_pitch;
    SKP_memcpy( Wsig_ptr, x_buf_ptr, ( psPredSt->pitch_LPC_win_length - SKP_LSHIFT( psEnc->sCmn.la_pitch, 1 ) ) * sizeof( SKP_int16 ) );

    
    Wsig_ptr  += psPredSt->pitch_LPC_win_length - SKP_LSHIFT( psEnc->sCmn.la_pitch, 1 );
    x_buf_ptr += psPredSt->pitch_LPC_win_length - SKP_LSHIFT( psEnc->sCmn.la_pitch, 1 );
    SKP_Silk_apply_sine_window( Wsig_ptr, x_buf_ptr, 2, psEnc->sCmn.la_pitch );

    
    SKP_Silk_autocorr( auto_corr, &scale, Wsig, psPredSt->pitch_LPC_win_length, psEnc->sCmn.pitchEstimationLPCOrder + 1 ); 
        
    
    auto_corr[ 0 ] = SKP_SMLAWB( auto_corr[ 0 ], auto_corr[ 0 ], SKP_FIX_CONST( FIND_PITCH_WHITE_NOISE_FRACTION, 16 ) );

    
    res_nrg = SKP_Silk_schur( rc_Q15, auto_corr, psEnc->sCmn.pitchEstimationLPCOrder );

    
    psEncCtrl->predGain_Q16 = SKP_DIV32_varQ( auto_corr[ 0 ], SKP_max_int( res_nrg, 1 ), 16 );

    
    SKP_Silk_k2a( A_Q24, rc_Q15, psEnc->sCmn.pitchEstimationLPCOrder );
    
    
    for( i = 0; i < psEnc->sCmn.pitchEstimationLPCOrder; i++ ) {
        A_Q12[ i ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT( A_Q24[ i ], 12 ) );
    }

    
    SKP_Silk_bwexpander( A_Q12, psEnc->sCmn.pitchEstimationLPCOrder, SKP_FIX_CONST( FIND_PITCH_BANDWITH_EXPANSION, 16 ) );
    
    
    
    
    SKP_memset( FiltState, 0, psEnc->sCmn.pitchEstimationLPCOrder * sizeof( SKP_int32 ) ); 
    SKP_Silk_MA_Prediction( x_buf, A_Q12, FiltState, res, buf_len, psEnc->sCmn.pitchEstimationLPCOrder );
    SKP_memset( res, 0, psEnc->sCmn.pitchEstimationLPCOrder * sizeof( SKP_int16 ) );

    
    thrhld_Q15 = SKP_FIX_CONST( 0.45, 15 );
    thrhld_Q15 = SKP_SMLABB( thrhld_Q15, SKP_FIX_CONST( -0.004, 15 ), psEnc->sCmn.pitchEstimationLPCOrder );
    thrhld_Q15 = SKP_SMLABB( thrhld_Q15, SKP_FIX_CONST( -0.1,   7  ), psEnc->speech_activity_Q8 );
    thrhld_Q15 = SKP_SMLABB( thrhld_Q15, SKP_FIX_CONST(  0.15,  15 ), psEnc->sCmn.prev_sigtype );
    thrhld_Q15 = SKP_SMLAWB( thrhld_Q15, SKP_FIX_CONST( -0.1,   16 ), psEncCtrl->input_tilt_Q15 );
    thrhld_Q15 = SKP_SAT16(  thrhld_Q15 );

    
    
    
    psEncCtrl->sCmn.sigtype = SKP_Silk_pitch_analysis_core( res, psEncCtrl->sCmn.pitchL, &psEncCtrl->sCmn.lagIndex, 
        &psEncCtrl->sCmn.contourIndex, &psEnc->LTPCorr_Q15, psEnc->sCmn.prevLag, psEnc->sCmn.pitchEstimationThreshold_Q16, 
        ( SKP_int16 )thrhld_Q15, psEnc->sCmn.fs_kHz, psEnc->sCmn.pitchEstimationComplexity, SKP_FALSE );
}







void SKP_Silk_find_pred_coefs_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl,     
    const SKP_int16                 res_pitch[]     
)
{
    SKP_int         i;
    SKP_int32       WLTP[ NB_SUBFR * LTP_ORDER * LTP_ORDER ];
    SKP_int32       invGains_Q16[ NB_SUBFR ], local_gains[ NB_SUBFR ], Wght_Q15[ NB_SUBFR ];
    SKP_int         NLSF_Q15[ MAX_LPC_ORDER ];
    const SKP_int16 *x_ptr;
    SKP_int16       *x_pre_ptr, LPC_in_pre[ NB_SUBFR * MAX_LPC_ORDER + MAX_FRAME_LENGTH ];
    SKP_int32       tmp, min_gain_Q16;
    SKP_int         LTP_corrs_rshift[ NB_SUBFR ];


    
    min_gain_Q16 = SKP_int32_MAX >> 6;
    for( i = 0; i < NB_SUBFR; i++ ) {
        min_gain_Q16 = SKP_min( min_gain_Q16, psEncCtrl->Gains_Q16[ i ] );
    }
    for( i = 0; i < NB_SUBFR; i++ ) {
        
        SKP_assert( psEncCtrl->Gains_Q16[ i ] > 0 );
        
        invGains_Q16[ i ] = SKP_DIV32_varQ( min_gain_Q16, psEncCtrl->Gains_Q16[ i ], 16 - 2 );

        
        invGains_Q16[ i ] = SKP_max( invGains_Q16[ i ], 363 ); 
        
        
        SKP_assert( invGains_Q16[ i ] == SKP_SAT16( invGains_Q16[ i ] ) );
        tmp = SKP_SMULWB( invGains_Q16[ i ], invGains_Q16[ i ] );
        Wght_Q15[ i ] = SKP_RSHIFT( tmp, 1 );

        
        local_gains[ i ] = SKP_DIV32( ( 1 << 16 ), invGains_Q16[ i ] );
    }

    if( psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED ) {
        
        
        
        SKP_assert( psEnc->sCmn.frame_length - psEnc->sCmn.predictLPCOrder >= psEncCtrl->sCmn.pitchL[ 0 ] + LTP_ORDER / 2 );

        
        SKP_Silk_find_LTP_FIX( psEncCtrl->LTPCoef_Q14, WLTP, &psEncCtrl->LTPredCodGain_Q7, res_pitch, 
            res_pitch + SKP_RSHIFT( psEnc->sCmn.frame_length, 1 ), psEncCtrl->sCmn.pitchL, Wght_Q15, 
            psEnc->sCmn.subfr_length, psEnc->sCmn.frame_length, LTP_corrs_rshift );


        
        SKP_Silk_quant_LTP_gains_FIX( psEncCtrl->LTPCoef_Q14, psEncCtrl->sCmn.LTPIndex, &psEncCtrl->sCmn.PERIndex, 
            WLTP, psEnc->mu_LTP_Q8, psEnc->sCmn.LTPQuantLowComplexity );

        
        SKP_Silk_LTP_scale_ctrl_FIX( psEnc, psEncCtrl );

        
        SKP_Silk_LTP_analysis_filter_FIX( LPC_in_pre, psEnc->x_buf + psEnc->sCmn.frame_length - psEnc->sCmn.predictLPCOrder, 
            psEncCtrl->LTPCoef_Q14, psEncCtrl->sCmn.pitchL, invGains_Q16, psEnc->sCmn.subfr_length, psEnc->sCmn.predictLPCOrder );

    } else {
        
        
        
        
        x_ptr     = psEnc->x_buf + psEnc->sCmn.frame_length - psEnc->sCmn.predictLPCOrder;
        x_pre_ptr = LPC_in_pre;
        for( i = 0; i < NB_SUBFR; i++ ) {
            SKP_Silk_scale_copy_vector16( x_pre_ptr, x_ptr, invGains_Q16[ i ], 
                psEnc->sCmn.subfr_length + psEnc->sCmn.predictLPCOrder );
            x_pre_ptr += psEnc->sCmn.subfr_length + psEnc->sCmn.predictLPCOrder;
            x_ptr     += psEnc->sCmn.subfr_length;
        }

        SKP_memset( psEncCtrl->LTPCoef_Q14, 0, NB_SUBFR * LTP_ORDER * sizeof( SKP_int16 ) );
        psEncCtrl->LTPredCodGain_Q7 = 0;
    }

    
    TIC(FIND_LPC)
    SKP_Silk_find_LPC_FIX( NLSF_Q15, &psEncCtrl->sCmn.NLSFInterpCoef_Q2, psEnc->sPred.prev_NLSFq_Q15, 
        psEnc->sCmn.useInterpolatedNLSFs * ( 1 - psEnc->sCmn.first_frame_after_reset ), psEnc->sCmn.predictLPCOrder, 
        LPC_in_pre, psEnc->sCmn.subfr_length + psEnc->sCmn.predictLPCOrder );
    TOC(FIND_LPC)


    
    TIC(PROCESS_LSFS)
        SKP_Silk_process_NLSFs_FIX( psEnc, psEncCtrl, NLSF_Q15 );
    TOC(PROCESS_LSFS)

    
    SKP_Silk_residual_energy_FIX( psEncCtrl->ResNrg, psEncCtrl->ResNrgQ, LPC_in_pre, psEncCtrl->PredCoef_Q12, local_gains,
        psEnc->sCmn.subfr_length, psEnc->sCmn.predictLPCOrder );

    
    SKP_memcpy( psEnc->sPred.prev_NLSFq_Q15, NLSF_Q15, psEnc->sCmn.predictLPCOrder * sizeof( SKP_int ) );

}







#define OFFSET          ( ( MIN_QGAIN_DB * 128 ) / 6 + 16 * 128 )
#define SCALE_Q16       ( ( 65536 * ( N_LEVELS_QGAIN - 1 ) ) / ( ( ( MAX_QGAIN_DB - MIN_QGAIN_DB ) * 128 ) / 6 ) )
#define INV_SCALE_Q16   ( ( 65536 * ( ( ( MAX_QGAIN_DB - MIN_QGAIN_DB ) * 128 ) / 6 ) ) / ( N_LEVELS_QGAIN - 1 ) )


void SKP_Silk_gains_quant(
    SKP_int                         ind[ NB_SUBFR ],        
    SKP_int32                       gain_Q16[ NB_SUBFR ],   
    SKP_int                         *prev_ind,              
    const SKP_int                   conditional             
)
{
    SKP_int k;

    for( k = 0; k < NB_SUBFR; k++ ) {
        
        ind[ k ] = SKP_SMULWB( SCALE_Q16, SKP_Silk_lin2log( gain_Q16[ k ] ) - OFFSET );

        
        if( ind[ k ] < *prev_ind ) {
            ind[ k ]++;
        }

        
        if( k == 0 && conditional == 0 ) {
            
            ind[ k ] = SKP_LIMIT_int( ind[ k ], 0, N_LEVELS_QGAIN - 1 );
            ind[ k ] = SKP_max_int( ind[ k ], *prev_ind + MIN_DELTA_GAIN_QUANT );
            *prev_ind = ind[ k ];
        } else {
            
            ind[ k ] = SKP_LIMIT_int( ind[ k ] - *prev_ind, MIN_DELTA_GAIN_QUANT, MAX_DELTA_GAIN_QUANT );
            
            *prev_ind += ind[ k ];
            
            ind[ k ] -= MIN_DELTA_GAIN_QUANT;
        }

        
        gain_Q16[ k ] = SKP_Silk_log2lin( SKP_min_32( SKP_SMULWB( INV_SCALE_Q16, *prev_ind ) + OFFSET, 3967 ) ); 
    }
}


void SKP_Silk_gains_dequant(
    SKP_int32                       gain_Q16[ NB_SUBFR ],   
    const SKP_int                   ind[ NB_SUBFR ],        
    SKP_int                         *prev_ind,              
    const SKP_int                   conditional             
)
{
    SKP_int   k;

    for( k = 0; k < NB_SUBFR; k++ ) {
        if( k == 0 && conditional == 0 ) {
            *prev_ind = ind[ k ];
        } else {
            
            *prev_ind += ind[ k ] + MIN_DELTA_GAIN_QUANT;
        }

        
        gain_Q16[ k ] = SKP_Silk_log2lin( SKP_min_32( SKP_SMULWB( INV_SCALE_Q16, *prev_ind ) + OFFSET, 3967 ) ); 
    }
}









SKP_int SKP_Silk_init_encoder_FIX(
    SKP_Silk_encoder_state_FIX  *psEnc                  
) {
    SKP_int ret = 0;
    
    SKP_memset( psEnc, 0, sizeof( SKP_Silk_encoder_state_FIX ) );

#if HIGH_PASS_INPUT
    psEnc->variable_HP_smth1_Q15 = 200844; 
    psEnc->variable_HP_smth2_Q15 = 200844; 
#endif

    
    psEnc->sCmn.first_frame_after_reset = 1;

    
    ret += SKP_Silk_VAD_Init( &psEnc->sCmn.sVAD );

    
    psEnc->sCmn.sNSQ.prev_inv_gain_Q16      = 65536;
    psEnc->sCmn.sNSQ_LBRR.prev_inv_gain_Q16 = 65536;

    return( ret );
}













#if (EMBEDDED_ARM<5) 
SKP_int32 SKP_Silk_inner_prod_aligned(
    const SKP_int16* const inVec1,  
    const SKP_int16* const inVec2,  
    const SKP_int             len   
)
{
    SKP_int   i; 
    SKP_int32 sum = 0;
    for( i = 0; i < len; i++ ) {
        sum = SKP_SMLABB( sum, inVec1[ i ], inVec2[ i ] );
    }
    return sum;
}
#endif

#if (EMBEDDED_ARM<5) 
SKP_int64 SKP_Silk_inner_prod16_aligned_64(
    const SKP_int16 *inVec1,         
    const SKP_int16 *inVec2,        
    const SKP_int   len             
)
{
    SKP_int   i; 
    SKP_int64 sum = 0;
    for( i = 0; i < len; i++ ) {
        sum = SKP_SMLALBB( sum, inVec1[ i ], inVec2[ i ] );
    }
    return sum;
}
#endif







void SKP_Silk_interpolate(
    SKP_int                         xi[ MAX_LPC_ORDER ],    
    const SKP_int                   x0[ MAX_LPC_ORDER ],    
    const SKP_int                   x1[ MAX_LPC_ORDER ],    
    const SKP_int                   ifact_Q2,               
    const SKP_int                   d                       
)
{
    SKP_int i;

    SKP_assert( ifact_Q2 >= 0 );
    SKP_assert( ifact_Q2 <= ( 1 << 2 ) );

    for( i = 0; i < d; i++ ) {
        xi[ i ] = ( SKP_int )( ( SKP_int32 )x0[ i ] + SKP_RSHIFT( SKP_MUL( ( SKP_int32 )x1[ i ] - ( SKP_int32 )x0[ i ], ifact_Q2 ), 2 ) );
    }
}








void SKP_Silk_k2a(
    SKP_int32            *A_Q24,                 
    const SKP_int16      *rc_Q15,                
    const SKP_int32      order                   
)
{
    SKP_int   k, n;
    SKP_int32 Atmp[ SKP_Silk_MAX_ORDER_LPC ];

    for( k = 0; k < order; k++ ) {
        for( n = 0; n < k; n++ ) {
            Atmp[ n ] = A_Q24[ n ];
        }
        for( n = 0; n < k; n++ ) {
            A_Q24[ n ] = SKP_SMLAWB( A_Q24[ n ], SKP_LSHIFT( Atmp[ k - n - 1 ], 1 ), rc_Q15[ k ] );
        }
        A_Q24[ k ] = -SKP_LSHIFT( (SKP_int32)rc_Q15[ k ], 9 );
    }
}








void SKP_Silk_k2a_Q16(
    SKP_int32            *A_Q24,                 
    const SKP_int32      *rc_Q16,                
    const SKP_int32      order                   
)
{
    SKP_int   k, n;
    SKP_int32 Atmp[ SKP_Silk_MAX_ORDER_LPC ];

    for( k = 0; k < order; k++ ) {
        for( n = 0; n < k; n++ ) {
            Atmp[ n ] = A_Q24[ n ];
        }
        for( n = 0; n < k; n++ ) {
            A_Q24[ n ] = SKP_SMLAWW( A_Q24[ n ], Atmp[ k - n - 1 ], rc_Q16[ k ] );
        }
        A_Q24[ k ] = -SKP_LSHIFT( rc_Q16[ k ], 8 );
    }
}






#if EMBEDDED_ARM<4

 
SKP_int32 SKP_Silk_lin2log( const SKP_int32 inLin )    
{
    SKP_int32 lz, frac_Q7;

    SKP_Silk_CLZ_FRAC( inLin, &lz, &frac_Q7 );

    
    return( SKP_LSHIFT( 31 - lz, 7 ) + SKP_SMLAWB( frac_Q7, SKP_MUL( frac_Q7, 128 - frac_Q7 ), 179 ) );
}
#endif









 
SKP_int32 SKP_Silk_log2lin( const SKP_int32 inLog_Q7 )     
{
    SKP_int32 out, frac_Q7;

    if( inLog_Q7 < 0 ) {
        return( 0 );
    } else if( inLog_Q7 >= ( 31 << 7 ) ) {
        
        return( SKP_int32_MAX );
    }

    out = SKP_LSHIFT( 1, SKP_RSHIFT( inLog_Q7, 7 ) );
    frac_Q7 = inLog_Q7 & 0x7F;
    if( inLog_Q7 < 2048 ) {
        
        out = SKP_ADD_RSHIFT( out, SKP_MUL( out, SKP_SMLAWB( frac_Q7, SKP_MUL( frac_Q7, 128 - frac_Q7 ), -174 ) ), 7 );
    } else {
        
        out = SKP_MLA( out, SKP_RSHIFT( out, 7 ), SKP_SMLAWB( frac_Q7, SKP_MUL( frac_Q7, 128 - frac_Q7 ), -174 ) );
    }
    return out;
}









SKP_INLINE SKP_int32 warped_gain( 
    const SKP_int32     *coefs_Q24, 
    SKP_int             lambda_Q16, 
    SKP_int             order 
) {
    SKP_int   i;
    SKP_int32 gain_Q24;

    lambda_Q16 = -lambda_Q16;
    gain_Q24 = coefs_Q24[ order - 1 ];
    for( i = order - 2; i >= 0; i-- ) {
        gain_Q24 = SKP_SMLAWB( coefs_Q24[ i ], gain_Q24, lambda_Q16 );
    }
    gain_Q24  = SKP_SMLAWB( SKP_FIX_CONST( 1.0, 24 ), gain_Q24, -lambda_Q16 );
    return SKP_INVERSE32_varQ( gain_Q24, 40 );
}



SKP_INLINE void limit_warped_coefs( 
    SKP_int32           *coefs_syn_Q24,
    SKP_int32           *coefs_ana_Q24,
    SKP_int             lambda_Q16,
    SKP_int32           limit_Q24,
    SKP_int             order
) {
    SKP_int   i, iter, ind = 0;
    SKP_int32 tmp, maxabs_Q24, chirp_Q16, gain_syn_Q16, gain_ana_Q16;
    SKP_int32 nom_Q16, den_Q24;

    
    lambda_Q16 = -lambda_Q16;
    for( i = order - 1; i > 0; i-- ) {
        coefs_syn_Q24[ i - 1 ] = SKP_SMLAWB( coefs_syn_Q24[ i - 1 ], coefs_syn_Q24[ i ], lambda_Q16 );
        coefs_ana_Q24[ i - 1 ] = SKP_SMLAWB( coefs_ana_Q24[ i - 1 ], coefs_ana_Q24[ i ], lambda_Q16 );
    }
    lambda_Q16 = -lambda_Q16;
    nom_Q16  = SKP_SMLAWB( SKP_FIX_CONST( 1.0, 16 ), -lambda_Q16,        lambda_Q16 );
    den_Q24  = SKP_SMLAWB( SKP_FIX_CONST( 1.0, 24 ), coefs_syn_Q24[ 0 ], lambda_Q16 );
    gain_syn_Q16 = SKP_DIV32_varQ( nom_Q16, den_Q24, 24 );
    den_Q24  = SKP_SMLAWB( SKP_FIX_CONST( 1.0, 24 ), coefs_ana_Q24[ 0 ], lambda_Q16 );
    gain_ana_Q16 = SKP_DIV32_varQ( nom_Q16, den_Q24, 24 );
    for( i = 0; i < order; i++ ) {
        coefs_syn_Q24[ i ] = SKP_SMULWW( gain_syn_Q16, coefs_syn_Q24[ i ] );
        coefs_ana_Q24[ i ] = SKP_SMULWW( gain_ana_Q16, coefs_ana_Q24[ i ] );
    }

    for( iter = 0; iter < 10; iter++ ) {
        
        maxabs_Q24 = -1;
        for( i = 0; i < order; i++ ) {
            tmp = SKP_max( SKP_abs_int32( coefs_syn_Q24[ i ] ), SKP_abs_int32( coefs_ana_Q24[ i ] ) );
            if( tmp > maxabs_Q24 ) {
                maxabs_Q24 = tmp;
                ind = i;
            }
        }
        if( maxabs_Q24 <= limit_Q24 ) {
            
            return;
        }

        
        for( i = 1; i < order; i++ ) {
            coefs_syn_Q24[ i - 1 ] = SKP_SMLAWB( coefs_syn_Q24[ i - 1 ], coefs_syn_Q24[ i ], lambda_Q16 );
            coefs_ana_Q24[ i - 1 ] = SKP_SMLAWB( coefs_ana_Q24[ i - 1 ], coefs_ana_Q24[ i ], lambda_Q16 );
        }
        gain_syn_Q16 = SKP_INVERSE32_varQ( gain_syn_Q16, 32 );
        gain_ana_Q16 = SKP_INVERSE32_varQ( gain_ana_Q16, 32 );
        for( i = 0; i < order; i++ ) {
            coefs_syn_Q24[ i ] = SKP_SMULWW( gain_syn_Q16, coefs_syn_Q24[ i ] );
            coefs_ana_Q24[ i ] = SKP_SMULWW( gain_ana_Q16, coefs_ana_Q24[ i ] );
        }

        
        chirp_Q16 = SKP_FIX_CONST( 0.99, 16 ) - SKP_DIV32_varQ(
            SKP_SMULWB( maxabs_Q24 - limit_Q24, SKP_SMLABB( SKP_FIX_CONST( 0.8, 10 ), SKP_FIX_CONST( 0.1, 10 ), iter ) ), 
            SKP_MUL( maxabs_Q24, ind + 1 ), 22 );
        SKP_Silk_bwexpander_32( coefs_syn_Q24, order, chirp_Q16 );
        SKP_Silk_bwexpander_32( coefs_ana_Q24, order, chirp_Q16 );

        
        lambda_Q16 = -lambda_Q16;
        for( i = order - 1; i > 0; i-- ) {
            coefs_syn_Q24[ i - 1 ] = SKP_SMLAWB( coefs_syn_Q24[ i - 1 ], coefs_syn_Q24[ i ], lambda_Q16 );
            coefs_ana_Q24[ i - 1 ] = SKP_SMLAWB( coefs_ana_Q24[ i - 1 ], coefs_ana_Q24[ i ], lambda_Q16 );
        }
        lambda_Q16 = -lambda_Q16;
        nom_Q16  = SKP_SMLAWB( SKP_FIX_CONST( 1.0, 16 ), -lambda_Q16,        lambda_Q16 );
        den_Q24  = SKP_SMLAWB( SKP_FIX_CONST( 1.0, 24 ), coefs_syn_Q24[ 0 ], lambda_Q16 );
        gain_syn_Q16 = SKP_DIV32_varQ( nom_Q16, den_Q24, 24 );
        den_Q24  = SKP_SMLAWB( SKP_FIX_CONST( 1.0, 24 ), coefs_ana_Q24[ 0 ], lambda_Q16 );
        gain_ana_Q16 = SKP_DIV32_varQ( nom_Q16, den_Q24, 24 );
        for( i = 0; i < order; i++ ) {
            coefs_syn_Q24[ i ] = SKP_SMULWW( gain_syn_Q16, coefs_syn_Q24[ i ] );
            coefs_ana_Q24[ i ] = SKP_SMULWW( gain_ana_Q16, coefs_ana_Q24[ i ] );
        }
    }
	SKP_assert( 0 );
}




void SKP_Silk_noise_shape_analysis_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl,     
    const SKP_int16                 *pitch_res,     
    const SKP_int16                 *x              
)
{
    SKP_Silk_shape_state_FIX *psShapeSt = &psEnc->sShape;
    SKP_int     k, i, nSamples, Qnrg, b_Q14, warping_Q16, scale = 0;
    SKP_int32   SNR_adj_dB_Q7, HarmBoost_Q16, HarmShapeGain_Q16, Tilt_Q16, tmp32;
    SKP_int32   nrg, pre_nrg_Q30, log_energy_Q7, log_energy_prev_Q7, energy_variation_Q7;
    SKP_int32   delta_Q16, BWExp1_Q16, BWExp2_Q16, gain_mult_Q16, gain_add_Q16, strength_Q16, b_Q8;
    SKP_int32   auto_corr[     MAX_SHAPE_LPC_ORDER + 1 ];
    SKP_int32   refl_coef_Q16[ MAX_SHAPE_LPC_ORDER ];
    SKP_int32   AR1_Q24[       MAX_SHAPE_LPC_ORDER ];
    SKP_int32   AR2_Q24[       MAX_SHAPE_LPC_ORDER ];
    SKP_int16   x_windowed[    SHAPE_LPC_WIN_MAX ];
    const SKP_int16 *x_ptr, *pitch_res_ptr;

    
    x_ptr = x - psEnc->sCmn.la_shape;

    
    
    
    
    psEncCtrl->current_SNR_dB_Q7 = psEnc->SNR_dB_Q7 - SKP_SMULWB( SKP_LSHIFT( ( SKP_int32 )psEnc->BufferedInChannel_ms, 7 ), 
        SKP_FIX_CONST( 0.05, 16 ) );

    
    if( psEnc->speech_activity_Q8 > SKP_FIX_CONST( LBRR_SPEECH_ACTIVITY_THRES, 8 ) ) {
        psEncCtrl->current_SNR_dB_Q7 -= SKP_RSHIFT( psEnc->inBandFEC_SNR_comp_Q8, 1 );
    }

    
    
    
    
    psEncCtrl->input_quality_Q14 = ( SKP_int )SKP_RSHIFT( ( SKP_int32 )psEncCtrl->input_quality_bands_Q15[ 0 ] 
        + psEncCtrl->input_quality_bands_Q15[ 1 ], 2 );

    
    psEncCtrl->coding_quality_Q14 = SKP_RSHIFT( SKP_Silk_sigm_Q15( SKP_RSHIFT_ROUND( psEncCtrl->current_SNR_dB_Q7 - 
        SKP_FIX_CONST( 18.0, 7 ), 4 ) ), 1 );

    
    b_Q8 = SKP_FIX_CONST( 1.0, 8 ) - psEnc->speech_activity_Q8;
    b_Q8 = SKP_SMULWB( SKP_LSHIFT( b_Q8, 8 ), b_Q8 );
    SNR_adj_dB_Q7 = SKP_SMLAWB( psEncCtrl->current_SNR_dB_Q7,
        SKP_SMULBB( SKP_FIX_CONST( -BG_SNR_DECR_dB, 7 ) >> ( 4 + 1 ), b_Q8 ),                                       
        SKP_SMULWB( SKP_FIX_CONST( 1.0, 14 ) + psEncCtrl->input_quality_Q14, psEncCtrl->coding_quality_Q14 ) );     

    if( psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED ) {
        
        SNR_adj_dB_Q7 = SKP_SMLAWB( SNR_adj_dB_Q7, SKP_FIX_CONST( HARM_SNR_INCR_dB, 8 ), psEnc->LTPCorr_Q15 );
    } else { 
        
        SNR_adj_dB_Q7 = SKP_SMLAWB( SNR_adj_dB_Q7, 
            SKP_SMLAWB( SKP_FIX_CONST( 6.0, 9 ), -SKP_FIX_CONST( 0.4, 18 ), psEncCtrl->current_SNR_dB_Q7 ),
            SKP_FIX_CONST( 1.0, 14 ) - psEncCtrl->input_quality_Q14 );
    }

    
    
    
    
    if( psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED ) {
        
        psEncCtrl->sCmn.QuantOffsetType = 0;
        psEncCtrl->sparseness_Q8 = 0;
    } else {
        
        nSamples = SKP_LSHIFT( psEnc->sCmn.fs_kHz, 1 );
        energy_variation_Q7 = 0;
        log_energy_prev_Q7  = 0;
        pitch_res_ptr = pitch_res;
        for( k = 0; k < FRAME_LENGTH_MS / 2; k++ ) {    
            SKP_Silk_sum_sqr_shift( &nrg, &scale, pitch_res_ptr, nSamples );
            nrg += SKP_RSHIFT( nSamples, scale );           
            
            log_energy_Q7 = SKP_Silk_lin2log( nrg );
            if( k > 0 ) {
                energy_variation_Q7 += SKP_abs( log_energy_Q7 - log_energy_prev_Q7 );
            }
            log_energy_prev_Q7 = log_energy_Q7;
            pitch_res_ptr += nSamples;
        }

        psEncCtrl->sparseness_Q8 = SKP_RSHIFT( SKP_Silk_sigm_Q15( SKP_SMULWB( energy_variation_Q7 - 
            SKP_FIX_CONST( 5.0, 7 ), SKP_FIX_CONST( 0.1, 16 ) ) ), 7 );

        
        if( psEncCtrl->sparseness_Q8 > SKP_FIX_CONST( SPARSENESS_THRESHOLD_QNT_OFFSET, 8 ) ) {
            psEncCtrl->sCmn.QuantOffsetType = 0;
        } else {
            psEncCtrl->sCmn.QuantOffsetType = 1;
        }
        
        
        SNR_adj_dB_Q7 = SKP_SMLAWB( SNR_adj_dB_Q7, SKP_FIX_CONST( SPARSE_SNR_INCR_dB, 15 ), psEncCtrl->sparseness_Q8 - SKP_FIX_CONST( 0.5, 8 ) );
    }

    
    
    
    
    strength_Q16 = SKP_SMULWB( psEncCtrl->predGain_Q16, SKP_FIX_CONST( FIND_PITCH_WHITE_NOISE_FRACTION, 16 ) );
    BWExp1_Q16 = BWExp2_Q16 = SKP_DIV32_varQ( SKP_FIX_CONST( BANDWIDTH_EXPANSION, 16 ), 
        SKP_SMLAWW( SKP_FIX_CONST( 1.0, 16 ), strength_Q16, strength_Q16 ), 16 );
    delta_Q16  = SKP_SMULWB( SKP_FIX_CONST( 1.0, 16 ) - SKP_SMULBB( 3, psEncCtrl->coding_quality_Q14 ), 
        SKP_FIX_CONST( LOW_RATE_BANDWIDTH_EXPANSION_DELTA, 16 ) );
    BWExp1_Q16 = SKP_SUB32( BWExp1_Q16, delta_Q16 );
    BWExp2_Q16 = SKP_ADD32( BWExp2_Q16, delta_Q16 );
    
    BWExp1_Q16 = SKP_DIV32_16( SKP_LSHIFT( BWExp1_Q16, 14 ), SKP_RSHIFT( BWExp2_Q16, 2 ) );

    if( psEnc->sCmn.warping_Q16 > 0 ) {
        
        warping_Q16 = SKP_SMLAWB( psEnc->sCmn.warping_Q16, psEncCtrl->coding_quality_Q14, SKP_FIX_CONST( 0.01, 18 ) );
    } else {
        warping_Q16 = 0;
    }

    
    
    
    for( k = 0; k < NB_SUBFR; k++ ) {
        
        SKP_int shift, slope_part, flat_part;
        flat_part = psEnc->sCmn.fs_kHz * 5;
        slope_part = SKP_RSHIFT( psEnc->sCmn.shapeWinLength - flat_part, 1 );

        SKP_Silk_apply_sine_window( x_windowed, x_ptr, 1, slope_part );
        shift = slope_part;
        SKP_memcpy( x_windowed + shift, x_ptr + shift, flat_part * sizeof(SKP_int16) );
        shift += flat_part;
        SKP_Silk_apply_sine_window( x_windowed + shift, x_ptr + shift, 2, slope_part );
        
        
        x_ptr += psEnc->sCmn.subfr_length;

        if( psEnc->sCmn.warping_Q16 > 0 ) {
            
            SKP_Silk_warped_autocorrelation_FIX( auto_corr, &scale, x_windowed, warping_Q16, psEnc->sCmn.shapeWinLength, psEnc->sCmn.shapingLPCOrder ); 
        } else {
            
            SKP_Silk_autocorr( auto_corr, &scale, x_windowed, psEnc->sCmn.shapeWinLength, psEnc->sCmn.shapingLPCOrder + 1 );
        }

        
        auto_corr[0] = SKP_ADD32( auto_corr[0], SKP_max_32( SKP_SMULWB( SKP_RSHIFT( auto_corr[ 0 ], 4 ), 
            SKP_FIX_CONST( SHAPE_WHITE_NOISE_FRACTION, 20 ) ), 1 ) ); 

        
        nrg = SKP_Silk_schur64( refl_coef_Q16, auto_corr, psEnc->sCmn.shapingLPCOrder );
        SKP_assert( nrg >= 0 );

        
        SKP_Silk_k2a_Q16( AR2_Q24, refl_coef_Q16, psEnc->sCmn.shapingLPCOrder );

        Qnrg = -scale;          
        SKP_assert( Qnrg >= -12 );
        SKP_assert( Qnrg <=  30 );

        
        if( Qnrg & 1 ) {
            Qnrg -= 1;
            nrg >>= 1;
        }

        tmp32 = SKP_Silk_SQRT_APPROX( nrg );
        Qnrg >>= 1;             

        psEncCtrl->Gains_Q16[ k ] = SKP_LSHIFT_SAT32( tmp32, 16 - Qnrg );

        if( psEnc->sCmn.warping_Q16 > 0 ) {
            
            gain_mult_Q16 = warped_gain( AR2_Q24, warping_Q16, psEnc->sCmn.shapingLPCOrder );
            SKP_assert( psEncCtrl->Gains_Q16[ k ] >= 0 );
            psEncCtrl->Gains_Q16[ k ] = SKP_SMULWW( psEncCtrl->Gains_Q16[ k ], gain_mult_Q16 );
            if( psEncCtrl->Gains_Q16[ k ] < 0 ) {
                psEncCtrl->Gains_Q16[ k ] = SKP_int32_MAX;
            }
        }

        
        SKP_Silk_bwexpander_32( AR2_Q24, psEnc->sCmn.shapingLPCOrder, BWExp2_Q16 );

        
        SKP_memcpy( AR1_Q24, AR2_Q24, psEnc->sCmn.shapingLPCOrder * sizeof( SKP_int32 ) );

        
        SKP_assert( BWExp1_Q16 <= SKP_FIX_CONST( 1.0, 16 ) );
        SKP_Silk_bwexpander_32( AR1_Q24, psEnc->sCmn.shapingLPCOrder, BWExp1_Q16 );

        
        SKP_Silk_LPC_inverse_pred_gain_Q24( &pre_nrg_Q30, AR2_Q24, psEnc->sCmn.shapingLPCOrder );
        SKP_Silk_LPC_inverse_pred_gain_Q24( &nrg,         AR1_Q24, psEnc->sCmn.shapingLPCOrder );

        
        pre_nrg_Q30 = SKP_LSHIFT32( SKP_SMULWB( pre_nrg_Q30, SKP_FIX_CONST( 0.7, 15 ) ), 1 );
        psEncCtrl->GainsPre_Q14[ k ] = ( SKP_int ) SKP_FIX_CONST( 0.3, 14 ) + SKP_DIV32_varQ( pre_nrg_Q30, nrg, 14 );

        
        limit_warped_coefs( AR2_Q24, AR1_Q24, warping_Q16, SKP_FIX_CONST( 3.999, 24 ), psEnc->sCmn.shapingLPCOrder );

        
        for( i = 0; i < psEnc->sCmn.shapingLPCOrder; i++ ) {
            psEncCtrl->AR1_Q13[ k * MAX_SHAPE_LPC_ORDER + i ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( AR1_Q24[ i ], 11 ) );
            psEncCtrl->AR2_Q13[ k * MAX_SHAPE_LPC_ORDER + i ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( AR2_Q24[ i ], 11 ) );
        }
    }

    
    
    
    
    gain_mult_Q16 = SKP_Silk_log2lin( -SKP_SMLAWB( -SKP_FIX_CONST( 16.0, 7 ), SNR_adj_dB_Q7,                            SKP_FIX_CONST( 0.16, 16 ) ) );
    gain_add_Q16  = SKP_Silk_log2lin(  SKP_SMLAWB(  SKP_FIX_CONST( 16.0, 7 ), SKP_FIX_CONST( NOISE_FLOOR_dB, 7 ),       SKP_FIX_CONST( 0.16, 16 ) ) );
    tmp32         = SKP_Silk_log2lin(  SKP_SMLAWB(  SKP_FIX_CONST( 16.0, 7 ), SKP_FIX_CONST( RELATIVE_MIN_GAIN_dB, 7 ), SKP_FIX_CONST( 0.16, 16 ) ) );
    tmp32 = SKP_SMULWW( psEnc->avgGain_Q16, tmp32 );
    gain_add_Q16 = SKP_ADD_SAT32( gain_add_Q16, tmp32 );
    SKP_assert( gain_mult_Q16 >= 0 );

    for( k = 0; k < NB_SUBFR; k++ ) {
        psEncCtrl->Gains_Q16[ k ] = SKP_SMULWW( psEncCtrl->Gains_Q16[ k ], gain_mult_Q16 );
        if( psEncCtrl->Gains_Q16[ k ] < 0 ) {
            psEncCtrl->Gains_Q16[ k ] = SKP_int32_MAX;
        }
    }

    for( k = 0; k < NB_SUBFR; k++ ) {
        psEncCtrl->Gains_Q16[ k ] = SKP_ADD_POS_SAT32( psEncCtrl->Gains_Q16[ k ], gain_add_Q16 );
        psEnc->avgGain_Q16 = SKP_ADD_SAT32( 
            psEnc->avgGain_Q16, 
            SKP_SMULWB(
                psEncCtrl->Gains_Q16[ k ] - psEnc->avgGain_Q16, 
                SKP_RSHIFT_ROUND( SKP_SMULBB( psEnc->speech_activity_Q8, SKP_FIX_CONST( GAIN_SMOOTHING_COEF, 10 ) ), 2 ) 
            ) );
    }

    
    
    
    gain_mult_Q16 = SKP_FIX_CONST( 1.0, 16 ) + SKP_RSHIFT_ROUND( SKP_MLA( SKP_FIX_CONST( INPUT_TILT, 26 ), 
        psEncCtrl->coding_quality_Q14, SKP_FIX_CONST( HIGH_RATE_INPUT_TILT, 12 ) ), 10 );

    if( psEncCtrl->input_tilt_Q15 <= 0 && psEncCtrl->sCmn.sigtype == SIG_TYPE_UNVOICED ) {
        if( psEnc->sCmn.fs_kHz == 24 ) {
            SKP_int32 essStrength_Q15 = SKP_SMULWW( -psEncCtrl->input_tilt_Q15, 
                SKP_SMULBB( psEnc->speech_activity_Q8, SKP_FIX_CONST( 1.0, 8 ) - psEncCtrl->sparseness_Q8 ) );
            tmp32 = SKP_Silk_log2lin( SKP_FIX_CONST( 16.0, 7 ) - SKP_SMULWB( essStrength_Q15, 
                SKP_SMULWB( SKP_FIX_CONST( DE_ESSER_COEF_SWB_dB, 7 ), SKP_FIX_CONST( 0.16, 17 ) ) ) );
            gain_mult_Q16 = SKP_SMULWW( gain_mult_Q16, tmp32 );
        } else if( psEnc->sCmn.fs_kHz == 16 ) {
            SKP_int32 essStrength_Q15 = SKP_SMULWW(-psEncCtrl->input_tilt_Q15, 
                SKP_SMULBB( psEnc->speech_activity_Q8, SKP_FIX_CONST( 1.0, 8 ) - psEncCtrl->sparseness_Q8 ));
            tmp32 = SKP_Silk_log2lin( SKP_FIX_CONST( 16.0, 7 ) - SKP_SMULWB( essStrength_Q15, 
                SKP_SMULWB( SKP_FIX_CONST( DE_ESSER_COEF_WB_dB, 7 ), SKP_FIX_CONST( 0.16, 17 ) ) ) );
            gain_mult_Q16 = SKP_SMULWW( gain_mult_Q16, tmp32 );
        } else {
            SKP_assert( psEnc->sCmn.fs_kHz == 12 || psEnc->sCmn.fs_kHz == 8 );
        }
    }

    for( k = 0; k < NB_SUBFR; k++ ) {
        psEncCtrl->GainsPre_Q14[ k ] = SKP_SMULWB( gain_mult_Q16, psEncCtrl->GainsPre_Q14[ k ] );
    }

    
    
    
    
    strength_Q16 = SKP_MUL( SKP_FIX_CONST( LOW_FREQ_SHAPING, 0 ), SKP_FIX_CONST( 1.0, 16 ) + 
        SKP_SMULBB( SKP_FIX_CONST( LOW_QUALITY_LOW_FREQ_SHAPING_DECR, 1 ), psEncCtrl->input_quality_bands_Q15[ 0 ] - SKP_FIX_CONST( 1.0, 15 ) ) );
    if( psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED ) {
        
        
        SKP_int fs_kHz_inv = SKP_DIV32_16( SKP_FIX_CONST( 0.2, 14 ), psEnc->sCmn.fs_kHz );
        for( k = 0; k < NB_SUBFR; k++ ) {
            b_Q14 = fs_kHz_inv + SKP_DIV32_16( SKP_FIX_CONST( 3.0, 14 ), psEncCtrl->sCmn.pitchL[ k ] ); 
            
            psEncCtrl->LF_shp_Q14[ k ]  = SKP_LSHIFT( SKP_FIX_CONST( 1.0, 14 ) - b_Q14 - SKP_SMULWB( strength_Q16, b_Q14 ), 16 );
            psEncCtrl->LF_shp_Q14[ k ] |= (SKP_uint16)( b_Q14 - SKP_FIX_CONST( 1.0, 14 ) );
        }
        SKP_assert( SKP_FIX_CONST( HARM_HP_NOISE_COEF, 24 ) < SKP_FIX_CONST( 0.5, 24 ) ); 
        Tilt_Q16 = - SKP_FIX_CONST( HP_NOISE_COEF, 16 ) - 
            SKP_SMULWB( SKP_FIX_CONST( 1.0, 16 ) - SKP_FIX_CONST( HP_NOISE_COEF, 16 ), 
                SKP_SMULWB( SKP_FIX_CONST( HARM_HP_NOISE_COEF, 24 ), psEnc->speech_activity_Q8 ) );
    } else {
        b_Q14 = SKP_DIV32_16( 21299, psEnc->sCmn.fs_kHz ); 
        
        psEncCtrl->LF_shp_Q14[ 0 ]  = SKP_LSHIFT( SKP_FIX_CONST( 1.0, 14 ) - b_Q14 - 
            SKP_SMULWB( strength_Q16, SKP_SMULWB( SKP_FIX_CONST( 0.6, 16 ), b_Q14 ) ), 16 );
        psEncCtrl->LF_shp_Q14[ 0 ] |= (SKP_uint16)( b_Q14 - SKP_FIX_CONST( 1.0, 14 ) );
        for( k = 1; k < NB_SUBFR; k++ ) {
            psEncCtrl->LF_shp_Q14[ k ] = psEncCtrl->LF_shp_Q14[ 0 ];
        }
        Tilt_Q16 = -SKP_FIX_CONST( HP_NOISE_COEF, 16 );
    }

    
    
    
    
    HarmBoost_Q16 = SKP_SMULWB( SKP_SMULWB( SKP_FIX_CONST( 1.0, 17 ) - SKP_LSHIFT( psEncCtrl->coding_quality_Q14, 3 ), 
        psEnc->LTPCorr_Q15 ), SKP_FIX_CONST( LOW_RATE_HARMONIC_BOOST, 16 ) );

    
    HarmBoost_Q16 = SKP_SMLAWB( HarmBoost_Q16, 
        SKP_FIX_CONST( 1.0, 16 ) - SKP_LSHIFT( psEncCtrl->input_quality_Q14, 2 ), SKP_FIX_CONST( LOW_INPUT_QUALITY_HARMONIC_BOOST, 16 ) );

    if( USE_HARM_SHAPING && psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED ) {
        
        HarmShapeGain_Q16 = SKP_SMLAWB( SKP_FIX_CONST( HARMONIC_SHAPING, 16 ), 
                SKP_FIX_CONST( 1.0, 16 ) - SKP_SMULWB( SKP_FIX_CONST( 1.0, 18 ) - SKP_LSHIFT( psEncCtrl->coding_quality_Q14, 4 ),
                psEncCtrl->input_quality_Q14 ), SKP_FIX_CONST( HIGH_RATE_OR_LOW_QUALITY_HARMONIC_SHAPING, 16 ) );

        
        HarmShapeGain_Q16 = SKP_SMULWB( SKP_LSHIFT( HarmShapeGain_Q16, 1 ), 
            SKP_Silk_SQRT_APPROX( SKP_LSHIFT( psEnc->LTPCorr_Q15, 15 ) ) );
    } else {
        HarmShapeGain_Q16 = 0;
    }

    
    
    
    for( k = 0; k < NB_SUBFR; k++ ) {
        psShapeSt->HarmBoost_smth_Q16 =
            SKP_SMLAWB( psShapeSt->HarmBoost_smth_Q16,     HarmBoost_Q16     - psShapeSt->HarmBoost_smth_Q16,     SKP_FIX_CONST( SUBFR_SMTH_COEF, 16 ) );
        psShapeSt->HarmShapeGain_smth_Q16 =
            SKP_SMLAWB( psShapeSt->HarmShapeGain_smth_Q16, HarmShapeGain_Q16 - psShapeSt->HarmShapeGain_smth_Q16, SKP_FIX_CONST( SUBFR_SMTH_COEF, 16 ) );
        psShapeSt->Tilt_smth_Q16 =
            SKP_SMLAWB( psShapeSt->Tilt_smth_Q16,          Tilt_Q16          - psShapeSt->Tilt_smth_Q16,          SKP_FIX_CONST( SUBFR_SMTH_COEF, 16 ) );

        psEncCtrl->HarmBoost_Q14[ k ]     = ( SKP_int )SKP_RSHIFT_ROUND( psShapeSt->HarmBoost_smth_Q16,     2 );
        psEncCtrl->HarmShapeGain_Q14[ k ] = ( SKP_int )SKP_RSHIFT_ROUND( psShapeSt->HarmShapeGain_smth_Q16, 2 );
        psEncCtrl->Tilt_Q14[ k ]          = ( SKP_int )SKP_RSHIFT_ROUND( psShapeSt->Tilt_smth_Q16,          2 );
    }
}









#ifndef SIGPROCFIX_PITCH_EST_DEFINES_H
#define SIGPROCFIX_PITCH_EST_DEFINES_H





#define PITCH_EST_SHORTLAG_BIAS_Q15         6554    
#define PITCH_EST_PREVLAG_BIAS_Q15          6554    
#define PITCH_EST_FLATCONTOUR_BIAS_Q20      52429   

#endif



#define SCRATCH_SIZE    22




void SKP_FIX_P_Ana_calc_corr_st3(
    SKP_int32        cross_corr_st3[PITCH_EST_NB_SUBFR][PITCH_EST_NB_CBKS_STAGE3_MAX][PITCH_EST_NB_STAGE3_LAGS],
    const SKP_int16  signal[],                        
    SKP_int          start_lag,                       
    SKP_int          sf_length,                       
    SKP_int          complexity                       
);

void SKP_FIX_P_Ana_calc_energy_st3(
    SKP_int32        energies_st3[PITCH_EST_NB_SUBFR][PITCH_EST_NB_CBKS_STAGE3_MAX][PITCH_EST_NB_STAGE3_LAGS],
    const SKP_int16  signal[],                        
    SKP_int          start_lag,                       
    SKP_int          sf_length,                       
    SKP_int          complexity                       
);

SKP_int32 SKP_FIX_P_Ana_find_scaling(
    const SKP_int16  *signal,
    const SKP_int    signal_length, 
    const SKP_int    sum_sqr_len
);




SKP_int SKP_Silk_pitch_analysis_core(  
    const SKP_int16  *signal,            
    SKP_int          *pitch_out,         
    SKP_int          *lagIndex,          
    SKP_int          *contourIndex,      
    SKP_int          *LTPCorr_Q15,       
    SKP_int          prevLag,            
    const SKP_int32  search_thres1_Q16,  
    const SKP_int    search_thres2_Q15,  
    const SKP_int    Fs_kHz,             
    const SKP_int    complexity,         
	const SKP_int	 forLJC			     
)
{
    SKP_int16 signal_8kHz[ PITCH_EST_MAX_FRAME_LENGTH_ST_2 ];
    SKP_int16 signal_4kHz[ PITCH_EST_MAX_FRAME_LENGTH_ST_1 ];
    SKP_int32 scratch_mem[ 3 * PITCH_EST_MAX_FRAME_LENGTH ];
    SKP_int16 *input_signal_ptr;
    SKP_int32 filt_state[ PITCH_EST_MAX_DECIMATE_STATE_LENGTH ];
    SKP_int   i, k, d, j;
    SKP_int16 C[ PITCH_EST_NB_SUBFR ][ ( PITCH_EST_MAX_LAG >> 1 ) + 5 ];
    const SKP_int16 *target_ptr, *basis_ptr;
    SKP_int32 cross_corr, normalizer, energy, shift, energy_basis, energy_target;
    SKP_int   d_srch[ PITCH_EST_D_SRCH_LENGTH ];
    SKP_int16 d_comp[ ( PITCH_EST_MAX_LAG >> 1 ) + 5 ];
    SKP_int   Cmax, length_d_srch, length_d_comp;
    SKP_int32 sum, threshold, temp32;
    SKP_int   CBimax, CBimax_new, CBimax_old, lag, start_lag, end_lag, lag_new;
    SKP_int32 CC[ PITCH_EST_NB_CBKS_STAGE2_EXT ], CCmax, CCmax_b, CCmax_new_b, CCmax_new;
    SKP_int32 energies_st3[  PITCH_EST_NB_SUBFR ][ PITCH_EST_NB_CBKS_STAGE3_MAX ][ PITCH_EST_NB_STAGE3_LAGS ];
    SKP_int32 crosscorr_st3[ PITCH_EST_NB_SUBFR ][ PITCH_EST_NB_CBKS_STAGE3_MAX ][ PITCH_EST_NB_STAGE3_LAGS ];
    SKP_int32 lag_counter;
    SKP_int   frame_length, frame_length_8kHz, frame_length_4kHz, max_sum_sq_length;
    SKP_int   sf_length, sf_length_8kHz;
    SKP_int   min_lag, min_lag_8kHz, min_lag_4kHz;
    SKP_int   max_lag, max_lag_8kHz, max_lag_4kHz;
    SKP_int32 contour_bias, diff;
    SKP_int32 lz, lshift;
    SKP_int   cbk_offset, cbk_size, nb_cbks_stage2;
    SKP_int32 delta_lag_log2_sqr_Q7, lag_log2_Q7, prevLag_log2_Q7, prev_lag_bias_Q15, corr_thres_Q15;

    
    SKP_assert( Fs_kHz == 8 || Fs_kHz == 12 || Fs_kHz == 16 || Fs_kHz == 24 );

    
    SKP_assert( complexity >= SKP_Silk_PITCH_EST_MIN_COMPLEX );
    SKP_assert( complexity <= SKP_Silk_PITCH_EST_MAX_COMPLEX );

    SKP_assert( search_thres1_Q16 >= 0 && search_thres1_Q16 <= (1<<16) );
    SKP_assert( search_thres2_Q15 >= 0 && search_thres2_Q15 <= (1<<15) );

    
    frame_length      = PITCH_EST_FRAME_LENGTH_MS * Fs_kHz;
    frame_length_4kHz = PITCH_EST_FRAME_LENGTH_MS * 4;
    frame_length_8kHz = PITCH_EST_FRAME_LENGTH_MS * 8;
    sf_length         = SKP_RSHIFT( frame_length,      3 );
    sf_length_8kHz    = SKP_RSHIFT( frame_length_8kHz, 3 );
    min_lag           = PITCH_EST_MIN_LAG_MS * Fs_kHz;
    min_lag_4kHz      = PITCH_EST_MIN_LAG_MS * 4;
    min_lag_8kHz      = PITCH_EST_MIN_LAG_MS * 8;
    max_lag           = PITCH_EST_MAX_LAG_MS * Fs_kHz;
    max_lag_4kHz      = PITCH_EST_MAX_LAG_MS * 4;
    max_lag_8kHz      = PITCH_EST_MAX_LAG_MS * 8;

    SKP_memset( C, 0, sizeof( SKP_int16 ) * PITCH_EST_NB_SUBFR * ( ( PITCH_EST_MAX_LAG >> 1 ) + 5) );
    
    
    if( Fs_kHz == 16 ) {
        SKP_memset( filt_state, 0, 2 * sizeof( SKP_int32 ) );
        SKP_Silk_resampler_down2( filt_state, signal_8kHz, signal, frame_length );
    } else if ( Fs_kHz == 12 ) {
        SKP_int32 R23[ 6 ];
        SKP_memset( R23, 0, 6 * sizeof( SKP_int32 ) );
        SKP_Silk_resampler_down2_3( R23, signal_8kHz, signal, PITCH_EST_FRAME_LENGTH_MS * 12 );
    } else if( Fs_kHz == 24 ) {
        SKP_int32 filt_state_fix[ 8 ];
        SKP_memset( filt_state_fix, 0, 8 * sizeof(SKP_int32) );
        SKP_Silk_resampler_down3( filt_state_fix, signal_8kHz, signal, 24 * PITCH_EST_FRAME_LENGTH_MS );
    } else {
        SKP_assert( Fs_kHz == 8 );
        SKP_memcpy( signal_8kHz, signal, frame_length_8kHz * sizeof(SKP_int16) );
    }
    
    SKP_memset( filt_state, 0, 2 * sizeof( SKP_int32 ) );
    SKP_Silk_resampler_down2( filt_state, signal_4kHz, signal_8kHz, frame_length_8kHz );

    
    for( i = frame_length_4kHz - 1; i > 0; i-- ) {
        signal_4kHz[ i ] = SKP_ADD_SAT16( signal_4kHz[ i ], signal_4kHz[ i - 1 ] );
    }

    
    
    
    max_sum_sq_length = SKP_max_32( sf_length_8kHz, SKP_RSHIFT( frame_length_4kHz, 1 ) );
    shift = SKP_FIX_P_Ana_find_scaling( signal_4kHz, frame_length_4kHz, max_sum_sq_length );
    if( shift > 0 ) {
        for( i = 0; i < frame_length_4kHz; i++ ) {
            signal_4kHz[ i ] = SKP_RSHIFT( signal_4kHz[ i ], shift );
        }
    }

    
    target_ptr = &signal_4kHz[ SKP_RSHIFT( frame_length_4kHz, 1 ) ];
    for( k = 0; k < 2; k++ ) {
        
        SKP_assert( target_ptr >= signal_4kHz );
        SKP_assert( target_ptr + sf_length_8kHz <= signal_4kHz + frame_length_4kHz );

        basis_ptr = target_ptr - min_lag_4kHz;

        
        SKP_assert( basis_ptr >= signal_4kHz );
        SKP_assert( basis_ptr + sf_length_8kHz <= signal_4kHz + frame_length_4kHz );

        normalizer = 0;
        cross_corr = 0;
        
        cross_corr = SKP_Silk_inner_prod_aligned( target_ptr, basis_ptr, sf_length_8kHz );
        normalizer = SKP_Silk_inner_prod_aligned( basis_ptr,  basis_ptr, sf_length_8kHz );
        normalizer = SKP_ADD_SAT32( normalizer, SKP_SMULBB( sf_length_8kHz, 4000 ) );

        temp32 = SKP_DIV32( cross_corr, SKP_Silk_SQRT_APPROX( normalizer ) + 1 );
        C[ k ][ min_lag_4kHz ] = (SKP_int16)SKP_SAT16( temp32 );        

        
        for( d = min_lag_4kHz + 1; d <= max_lag_4kHz; d++ ) {
            basis_ptr--;

            
            SKP_assert( basis_ptr >= signal_4kHz );
            SKP_assert( basis_ptr + sf_length_8kHz <= signal_4kHz + frame_length_4kHz );

            cross_corr = SKP_Silk_inner_prod_aligned( target_ptr, basis_ptr, sf_length_8kHz );

            
            normalizer +=
                SKP_SMULBB( basis_ptr[ 0 ], basis_ptr[ 0 ] ) - 
                SKP_SMULBB( basis_ptr[ sf_length_8kHz ], basis_ptr[ sf_length_8kHz ] ); 
    
            temp32 = SKP_DIV32( cross_corr, SKP_Silk_SQRT_APPROX( normalizer ) + 1 );
            C[ k ][ d ] = (SKP_int16)SKP_SAT16( temp32 );                        
        }
        
        target_ptr += sf_length_8kHz;
    }

    
    for( i = max_lag_4kHz; i >= min_lag_4kHz; i-- ) {
        sum = (SKP_int32)C[ 0 ][ i ] + (SKP_int32)C[ 1 ][ i ];                
        SKP_assert( SKP_RSHIFT( sum, 1 ) == SKP_SAT16( SKP_RSHIFT( sum, 1 ) ) );
        sum = SKP_RSHIFT( sum, 1 );                                           
        SKP_assert( SKP_LSHIFT( (SKP_int32)-i, 4 ) == SKP_SAT16( SKP_LSHIFT( (SKP_int32)-i, 4 ) ) );
        sum = SKP_SMLAWB( sum, sum, SKP_LSHIFT( -i, 4 ) );                    
        SKP_assert( sum == SKP_SAT16( sum ) );
        C[ 0 ][ i ] = (SKP_int16)sum;                                         
    }

    
    length_d_srch = 4 + 2 * complexity;
    SKP_assert( 3 * length_d_srch <= PITCH_EST_D_SRCH_LENGTH );
    SKP_Silk_insertion_sort_decreasing_int16( &C[ 0 ][ min_lag_4kHz ], d_srch, max_lag_4kHz - min_lag_4kHz + 1, length_d_srch );

    
    target_ptr = &signal_4kHz[ SKP_RSHIFT( frame_length_4kHz, 1 ) ];
    energy = SKP_Silk_inner_prod_aligned( target_ptr, target_ptr, SKP_RSHIFT( frame_length_4kHz, 1 ) );
    energy = SKP_ADD_POS_SAT32( energy, 1000 );                              
    Cmax = (SKP_int)C[ 0 ][ min_lag_4kHz ];                                  
    threshold = SKP_SMULBB( Cmax, Cmax );                                    
    
    if( SKP_RSHIFT( energy, 4 + 2 ) > threshold ) {                            
        SKP_memset( pitch_out, 0, PITCH_EST_NB_SUBFR * sizeof( SKP_int ) );
        *LTPCorr_Q15  = 0;
        *lagIndex     = 0;
        *contourIndex = 0;
        return 1;
    }

    threshold = SKP_SMULWB( search_thres1_Q16, Cmax );
    for( i = 0; i < length_d_srch; i++ ) {
        
        if( C[ 0 ][ min_lag_4kHz + i ] > threshold ) {
            d_srch[ i ] = ( d_srch[ i ] + min_lag_4kHz ) << 1;
        } else {
            length_d_srch = i;
            break;
        }
    }
    SKP_assert( length_d_srch > 0 );

    for( i = min_lag_8kHz - 5; i < max_lag_8kHz + 5; i++ ) {
        d_comp[ i ] = 0;
    }
    for( i = 0; i < length_d_srch; i++ ) {
        d_comp[ d_srch[ i ] ] = 1;
    }

    
    for( i = max_lag_8kHz + 3; i >= min_lag_8kHz; i-- ) {
        d_comp[ i ] += d_comp[ i - 1 ] + d_comp[ i - 2 ];
    }

    length_d_srch = 0;
    for( i = min_lag_8kHz; i < max_lag_8kHz + 1; i++ ) {    
        if( d_comp[ i + 1 ] > 0 ) {
            d_srch[ length_d_srch ] = i;
            length_d_srch++;
        }
    }

    
    for( i = max_lag_8kHz + 3; i >= min_lag_8kHz; i-- ) {
        d_comp[ i ] += d_comp[ i - 1 ] + d_comp[ i - 2 ] + d_comp[ i - 3 ];
    }

    length_d_comp = 0;
    for( i = min_lag_8kHz; i < max_lag_8kHz + 4; i++ ) {    
        if( d_comp[ i ] > 0 ) {
            d_comp[ length_d_comp ] = i - 2;
            length_d_comp++;
        }
    }

    

    
    
    shift = SKP_FIX_P_Ana_find_scaling( signal_8kHz, frame_length_8kHz, sf_length_8kHz );
    if( shift > 0 ) {
        for( i = 0; i < frame_length_8kHz; i++ ) {
            signal_8kHz[ i ] = SKP_RSHIFT( signal_8kHz[ i ], shift );
        }
    }

    
    SKP_memset( C, 0, PITCH_EST_NB_SUBFR * ( ( PITCH_EST_MAX_LAG >> 1 ) + 5 ) * sizeof( SKP_int16 ) );
    
    target_ptr = &signal_8kHz[ frame_length_4kHz ]; 
    for( k = 0; k < PITCH_EST_NB_SUBFR; k++ ) {

        
        SKP_assert( target_ptr >= signal_8kHz );
        SKP_assert( target_ptr + sf_length_8kHz <= signal_8kHz + frame_length_8kHz );

        energy_target = SKP_Silk_inner_prod_aligned( target_ptr, target_ptr, sf_length_8kHz );
        
        for( j = 0; j < length_d_comp; j++ ) {
            d = d_comp[ j ];
            basis_ptr = target_ptr - d;

            
            SKP_assert( basis_ptr >= signal_8kHz );
            SKP_assert( basis_ptr + sf_length_8kHz <= signal_8kHz + frame_length_8kHz );
        
            cross_corr   = SKP_Silk_inner_prod_aligned( target_ptr, basis_ptr, sf_length_8kHz );
            energy_basis = SKP_Silk_inner_prod_aligned( basis_ptr,  basis_ptr, sf_length_8kHz );
            if( cross_corr > 0 ) {
                energy = SKP_max( energy_target, energy_basis ); 
                lz = SKP_Silk_CLZ32( cross_corr );
                lshift = SKP_LIMIT_32( lz - 1, 0, 15 );
                temp32 = SKP_DIV32( SKP_LSHIFT( cross_corr, lshift ), SKP_RSHIFT( energy, 15 - lshift ) + 1 ); 
                SKP_assert( temp32 == SKP_SAT16( temp32 ) );
                temp32 = SKP_SMULWB( cross_corr, temp32 ); 
                temp32 = SKP_ADD_SAT32( temp32, temp32 );  
                lz = SKP_Silk_CLZ32( temp32 );
                lshift = SKP_LIMIT_32( lz - 1, 0, 15 );
                energy = SKP_min( energy_target, energy_basis );
                C[ k ][ d ] = SKP_DIV32( SKP_LSHIFT( temp32, lshift ), SKP_RSHIFT( energy, 15 - lshift ) + 1 ); 
            } else {
                C[ k ][ d ] = 0;
            }
        }
        target_ptr += sf_length_8kHz;
    }

    
    

    CCmax   = SKP_int32_MIN;
    CCmax_b = SKP_int32_MIN;

    CBimax = 0; 
    lag = -1;   

    if( prevLag > 0 ) {
        if( Fs_kHz == 12 ) {
            prevLag = SKP_DIV32_16( SKP_LSHIFT( prevLag, 1 ), 3 );
        } else if( Fs_kHz == 16 ) {
            prevLag = SKP_RSHIFT( prevLag, 1 );
        } else if( Fs_kHz == 24 ) {
            prevLag = SKP_DIV32_16( prevLag, 3 );
        }
        prevLag_log2_Q7 = SKP_Silk_lin2log( (SKP_int32)prevLag );
    } else {
        prevLag_log2_Q7 = 0;
    }
    SKP_assert( search_thres2_Q15 == SKP_SAT16( search_thres2_Q15 ) );
    corr_thres_Q15 = SKP_RSHIFT( SKP_SMULBB( search_thres2_Q15, search_thres2_Q15 ), 13 );

    
    if( Fs_kHz == 8 && complexity > SKP_Silk_PITCH_EST_MIN_COMPLEX ) {
        nb_cbks_stage2 = PITCH_EST_NB_CBKS_STAGE2_EXT;    
    } else {
        nb_cbks_stage2 = PITCH_EST_NB_CBKS_STAGE2;
    }

    for( k = 0; k < length_d_srch; k++ ) {
        d = d_srch[ k ];
        for( j = 0; j < nb_cbks_stage2; j++ ) {
            CC[ j ] = 0;
            for( i = 0; i < PITCH_EST_NB_SUBFR; i++ ) {
                
                CC[ j ] = CC[ j ] + (SKP_int32)C[ i ][ d + SKP_Silk_CB_lags_stage2[ i ][ j ] ];
            }
        }
        
        CCmax_new = SKP_int32_MIN;
        CBimax_new = 0;
        for( i = 0; i < nb_cbks_stage2; i++ ) {
            if( CC[ i ] > CCmax_new ) {
                CCmax_new = CC[ i ];
                CBimax_new = i;
            }
        }

        
        lag_log2_Q7 = SKP_Silk_lin2log( (SKP_int32)d ); 
	    SKP_assert( lag_log2_Q7 == SKP_SAT16( lag_log2_Q7 ) );
		SKP_assert( PITCH_EST_NB_SUBFR * PITCH_EST_SHORTLAG_BIAS_Q15 == SKP_SAT16( PITCH_EST_NB_SUBFR * PITCH_EST_SHORTLAG_BIAS_Q15 ) );

		if (forLJC) {
			CCmax_new_b = CCmax_new;
		} else {
			CCmax_new_b = CCmax_new - SKP_RSHIFT( SKP_SMULBB( PITCH_EST_NB_SUBFR * PITCH_EST_SHORTLAG_BIAS_Q15, lag_log2_Q7 ), 7 ); 
		}
		
        
        SKP_assert( PITCH_EST_NB_SUBFR * PITCH_EST_PREVLAG_BIAS_Q15 == SKP_SAT16( PITCH_EST_NB_SUBFR * PITCH_EST_PREVLAG_BIAS_Q15 ) );
        if( prevLag > 0 ) {
            delta_lag_log2_sqr_Q7 = lag_log2_Q7 - prevLag_log2_Q7;
            SKP_assert( delta_lag_log2_sqr_Q7 == SKP_SAT16( delta_lag_log2_sqr_Q7 ) );
            delta_lag_log2_sqr_Q7 = SKP_RSHIFT( SKP_SMULBB( delta_lag_log2_sqr_Q7, delta_lag_log2_sqr_Q7 ), 7 );
            prev_lag_bias_Q15 = SKP_RSHIFT( SKP_SMULBB( PITCH_EST_NB_SUBFR * PITCH_EST_PREVLAG_BIAS_Q15, ( *LTPCorr_Q15 ) ), 15 ); 
            prev_lag_bias_Q15 = SKP_DIV32( SKP_MUL( prev_lag_bias_Q15, delta_lag_log2_sqr_Q7 ), delta_lag_log2_sqr_Q7 + ( 1 << 6 ) );
            CCmax_new_b -= prev_lag_bias_Q15; 
        }

        if ( CCmax_new_b > CCmax_b                                          &&              
              CCmax_new > corr_thres_Q15                                    &&              
             SKP_Silk_CB_lags_stage2[ 0 ][ CBimax_new ] <= min_lag_8kHz                   
            ) {
            CCmax_b = CCmax_new_b;
            CCmax   = CCmax_new;
            lag     = d;
            CBimax  = CBimax_new;
        }
    }

    if( lag == -1 ) {
        
        SKP_memset( pitch_out, 0, PITCH_EST_NB_SUBFR * sizeof( SKP_int ) );
        *LTPCorr_Q15  = 0;
        *lagIndex     = 0;
        *contourIndex = 0;
        return 1;
    }

    if( Fs_kHz > 8 ) {

        
        
        shift = SKP_FIX_P_Ana_find_scaling( signal, frame_length, sf_length );
        if( shift > 0 ) {
            
            
            input_signal_ptr = (SKP_int16*)scratch_mem;
            for( i = 0; i < frame_length; i++ ) {
                input_signal_ptr[ i ] = SKP_RSHIFT( signal[ i ], shift );
            }
        } else {
            input_signal_ptr = (SKP_int16*)signal;
        }
        

        
                    
        CBimax_old = CBimax;
        
        SKP_assert( lag == SKP_SAT16( lag ) );
        if( Fs_kHz == 12 ) {
            lag = SKP_RSHIFT( SKP_SMULBB( lag, 3 ), 1 );
        } else if( Fs_kHz == 16 ) {
            lag = SKP_LSHIFT( lag, 1 );
        } else {
            lag = SKP_SMULBB( lag, 3 );
        }

        lag = SKP_LIMIT_int( lag, min_lag, max_lag );
        start_lag = SKP_max_int( lag - 2, min_lag );
        end_lag   = SKP_min_int( lag + 2, max_lag );
        lag_new   = lag;                                    
        CBimax    = 0;                                        
        SKP_assert( SKP_LSHIFT( CCmax, 13 ) >= 0 ); 
        *LTPCorr_Q15 = (SKP_int)SKP_Silk_SQRT_APPROX( SKP_LSHIFT( CCmax, 13 ) ); 

        CCmax = SKP_int32_MIN;
        
        for( k = 0; k < PITCH_EST_NB_SUBFR; k++ ) {
            pitch_out[ k ] = lag + 2 * SKP_Silk_CB_lags_stage2[ k ][ CBimax_old ];
        }
        
        SKP_FIX_P_Ana_calc_corr_st3(  crosscorr_st3, input_signal_ptr, start_lag, sf_length, complexity );
        SKP_FIX_P_Ana_calc_energy_st3( energies_st3, input_signal_ptr, start_lag, sf_length, complexity );

        lag_counter = 0;
        SKP_assert( lag == SKP_SAT16( lag ) );
        contour_bias = SKP_DIV32_16( PITCH_EST_FLATCONTOUR_BIAS_Q20, lag );

        
        cbk_size   = (SKP_int)SKP_Silk_cbk_sizes_stage3[   complexity ];
        cbk_offset = (SKP_int)SKP_Silk_cbk_offsets_stage3[ complexity ];

        for( d = start_lag; d <= end_lag; d++ ) {
            for( j = cbk_offset; j < ( cbk_offset + cbk_size ); j++ ) {
                cross_corr = 0;
                energy     = 0;
                for( k = 0; k < PITCH_EST_NB_SUBFR; k++ ) {
                    SKP_assert( PITCH_EST_NB_SUBFR == 4 );
                    energy     += SKP_RSHIFT( energies_st3[  k ][ j ][ lag_counter ], 2 ); 
                    SKP_assert( energy >= 0 );
                    cross_corr += SKP_RSHIFT( crosscorr_st3[ k ][ j ][ lag_counter ], 2 ); 
                }
                if( cross_corr > 0 ) {
                    
                    lz = SKP_Silk_CLZ32( cross_corr );
                    
                    lshift = SKP_LIMIT_32( lz - 1, 0, 13 );
                    CCmax_new = SKP_DIV32( SKP_LSHIFT( cross_corr, lshift ), SKP_RSHIFT( energy, 13 - lshift ) + 1 );
                    CCmax_new = SKP_SAT16( CCmax_new );
                    CCmax_new = SKP_SMULWB( cross_corr, CCmax_new );
                    
                    if( CCmax_new > SKP_RSHIFT( SKP_int32_MAX, 3 ) ) {
                        CCmax_new = SKP_int32_MAX;
                    } else {
                        CCmax_new = SKP_LSHIFT( CCmax_new, 3 );
                    }
                    
                    diff = j - SKP_RSHIFT( PITCH_EST_NB_CBKS_STAGE3_MAX, 1 );
                    diff = SKP_MUL( diff, diff );
                    diff = SKP_int16_MAX - SKP_RSHIFT( SKP_MUL( contour_bias, diff ), 5 ); 
                    SKP_assert( diff == SKP_SAT16( diff ) );
                    CCmax_new = SKP_LSHIFT( SKP_SMULWB( CCmax_new, diff ), 1 );
                } else {
                    CCmax_new = 0;
                }

                if( CCmax_new > CCmax                                               && 
                   ( d + (SKP_int)SKP_Silk_CB_lags_stage3[ 0 ][ j ] ) <= max_lag  
                   ) {
                    CCmax   = CCmax_new;
                    lag_new = d;
                    CBimax  = j;
                }
            }
            lag_counter++;
        }

        for( k = 0; k < PITCH_EST_NB_SUBFR; k++ ) {
            pitch_out[ k ] = lag_new + SKP_Silk_CB_lags_stage3[ k ][ CBimax ];
        }
        *lagIndex = lag_new - min_lag;
        *contourIndex = CBimax;
    } else {
        
        CCmax = SKP_max( CCmax, 0 );
        *LTPCorr_Q15 = (SKP_int)SKP_Silk_SQRT_APPROX( SKP_LSHIFT( CCmax, 13 ) ); 
        for( k = 0; k < PITCH_EST_NB_SUBFR; k++ ) {
            pitch_out[ k ] = lag + SKP_Silk_CB_lags_stage2[ k ][ CBimax ];
        }
        *lagIndex = lag - min_lag_8kHz;
        *contourIndex = CBimax;
    }
    SKP_assert( *lagIndex >= 0 );
    
    return 0;
}





void SKP_FIX_P_Ana_calc_corr_st3(
    SKP_int32        cross_corr_st3[ PITCH_EST_NB_SUBFR ][ PITCH_EST_NB_CBKS_STAGE3_MAX ][ PITCH_EST_NB_STAGE3_LAGS ],
    const SKP_int16  signal[],                        
    SKP_int          start_lag,                       
    SKP_int          sf_length,                       
    SKP_int          complexity                       
)
{
    const SKP_int16 *target_ptr, *basis_ptr;
    SKP_int32    cross_corr;
    SKP_int        i, j, k, lag_counter;
    SKP_int        cbk_offset, cbk_size, delta, idx;
    SKP_int32    scratch_mem[ SCRATCH_SIZE ];

    SKP_assert( complexity >= SKP_Silk_PITCH_EST_MIN_COMPLEX );
    SKP_assert( complexity <= SKP_Silk_PITCH_EST_MAX_COMPLEX );

    cbk_offset = SKP_Silk_cbk_offsets_stage3[ complexity ];
    cbk_size   = SKP_Silk_cbk_sizes_stage3[   complexity ];

    target_ptr = &signal[ SKP_LSHIFT( sf_length, 2 ) ]; 
    for( k = 0; k < PITCH_EST_NB_SUBFR; k++ ) {
        lag_counter = 0;

        
        for( j = SKP_Silk_Lag_range_stage3[ complexity ][ k ][ 0 ]; j <= SKP_Silk_Lag_range_stage3[ complexity ][ k ][ 1 ]; j++ ) {
            basis_ptr = target_ptr - ( start_lag + j );
            cross_corr = SKP_Silk_inner_prod_aligned( (SKP_int16*)target_ptr, (SKP_int16*)basis_ptr, sf_length );
            SKP_assert( lag_counter < SCRATCH_SIZE );
            scratch_mem[ lag_counter ] = cross_corr;
            lag_counter++;
        }

        delta = SKP_Silk_Lag_range_stage3[ complexity ][ k ][ 0 ];
        for( i = cbk_offset; i < ( cbk_offset + cbk_size ); i++ ) { 
            
            
            idx = SKP_Silk_CB_lags_stage3[ k ][ i ] - delta;
            for( j = 0; j < PITCH_EST_NB_STAGE3_LAGS; j++ ) {
                SKP_assert( idx + j < SCRATCH_SIZE );
                SKP_assert( idx + j < lag_counter );
                cross_corr_st3[ k ][ i ][ j ] = scratch_mem[ idx + j ];
            }
        }
        target_ptr += sf_length;
    }
}





void SKP_FIX_P_Ana_calc_energy_st3(
    SKP_int32        energies_st3[ PITCH_EST_NB_SUBFR ][ PITCH_EST_NB_CBKS_STAGE3_MAX ][ PITCH_EST_NB_STAGE3_LAGS ],
    const SKP_int16  signal[],                        
    SKP_int          start_lag,                       
    SKP_int          sf_length,                       
    SKP_int          complexity                       
)
{
    const SKP_int16 *target_ptr, *basis_ptr;
    SKP_int32    energy;
    SKP_int        k, i, j, lag_counter;
    SKP_int        cbk_offset, cbk_size, delta, idx;
    SKP_int32    scratch_mem[ SCRATCH_SIZE ];

    SKP_assert( complexity >= SKP_Silk_PITCH_EST_MIN_COMPLEX );
    SKP_assert( complexity <= SKP_Silk_PITCH_EST_MAX_COMPLEX );

    cbk_offset = SKP_Silk_cbk_offsets_stage3[ complexity ];
    cbk_size   = SKP_Silk_cbk_sizes_stage3[   complexity ];

    target_ptr = &signal[ SKP_LSHIFT( sf_length, 2 ) ];
    for( k = 0; k < PITCH_EST_NB_SUBFR; k++ ) {
        lag_counter = 0;

        
        basis_ptr = target_ptr - ( start_lag + SKP_Silk_Lag_range_stage3[ complexity ][ k ][ 0 ] );
        energy = SKP_Silk_inner_prod_aligned( basis_ptr, basis_ptr, sf_length );
        SKP_assert( energy >= 0 );
        scratch_mem[ lag_counter ] = energy;
        lag_counter++;

        for( i = 1; i < ( SKP_Silk_Lag_range_stage3[ complexity ][ k ][ 1 ] - SKP_Silk_Lag_range_stage3[ complexity ][ k ][ 0 ] + 1 ); i++ ) {
            
            energy -= SKP_SMULBB( basis_ptr[ sf_length - i ], basis_ptr[ sf_length - i ] );
            SKP_assert( energy >= 0 );

            
            energy = SKP_ADD_SAT32( energy, SKP_SMULBB( basis_ptr[ -i ], basis_ptr[ -i ] ) );
            SKP_assert( energy >= 0 );
            SKP_assert( lag_counter < SCRATCH_SIZE );
            scratch_mem[ lag_counter ] = energy;
            lag_counter++;
        }

        delta = SKP_Silk_Lag_range_stage3[ complexity ][ k ][ 0 ];
        for( i = cbk_offset; i < ( cbk_offset + cbk_size ); i++ ) { 
            
            
            idx = SKP_Silk_CB_lags_stage3[ k ][ i ] - delta;
            for( j = 0; j < PITCH_EST_NB_STAGE3_LAGS; j++ ) {
                SKP_assert( idx + j < SCRATCH_SIZE );
                SKP_assert( idx + j < lag_counter );
                energies_st3[ k ][ i ][ j ] = scratch_mem[ idx + j ];
                SKP_assert( energies_st3[ k ][ i ][ j ] >= 0.0f );
            }
        }
        target_ptr += sf_length;
    }
}

SKP_int32 SKP_FIX_P_Ana_find_scaling(
    const SKP_int16  *signal,
    const SKP_int    signal_length, 
    const SKP_int    sum_sqr_len
)
{
    SKP_int32 nbits, x_max;
    
    x_max = SKP_Silk_int16_array_maxabs( signal, signal_length );

    if( x_max < SKP_int16_MAX ) {
        
        nbits = 32 - SKP_Silk_CLZ32( SKP_SMULBB( x_max, x_max ) ); 
    } else {
        
        nbits = 30;
    }
    nbits += 17 - SKP_Silk_CLZ16( sum_sqr_len );

    
    if( nbits < 31 ) {
        return 0;
    } else {
        return( nbits - 30 );
    }
}











const SKP_int16 SKP_Silk_CB_lags_stage2[PITCH_EST_NB_SUBFR][PITCH_EST_NB_CBKS_STAGE2_EXT] =
{
    {0, 2,-1,-1,-1, 0, 0, 1, 1, 0, 1},
    {0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0},
    {0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0},
    {0,-1, 2, 1, 0, 1, 1, 0, 0,-1,-1} 
};

const SKP_int16 SKP_Silk_CB_lags_stage3[PITCH_EST_NB_SUBFR][PITCH_EST_NB_CBKS_STAGE3_MAX] =
{
    {-9,-7,-6,-5,-5,-4,-4,-3,-3,-2,-2,-2,-1,-1,-1, 0, 0, 0, 1, 1, 0, 1, 2, 2, 2, 3, 3, 4, 4, 5, 6, 5, 6, 8},
    {-3,-2,-2,-2,-1,-1,-1,-1,-1, 0, 0,-1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 2, 1, 2, 2, 2, 2, 3},
    { 3, 3, 2, 2, 2, 2, 1, 2, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,-1, 0, 0,-1,-1,-1,-1,-1,-2,-2,-2},
    { 9, 8, 6, 5, 6, 5, 4, 4, 3, 3, 2, 2, 2, 1, 0, 1, 1, 0, 0, 0,-1,-1,-1,-2,-2,-2,-3,-3,-4,-4,-5,-5,-6,-7}
 };

const SKP_int16 SKP_Silk_Lag_range_stage3[ SKP_Silk_PITCH_EST_MAX_COMPLEX + 1 ] [ PITCH_EST_NB_SUBFR ][ 2 ] =
{
    
    {
        {-2,6},
        {-1,5},
        {-1,5},
        {-2,7}
    },
    
    {
        {-4,8},
        {-1,6},
        {-1,6},
        {-4,9}
    },
    
    {
        {-9,12},
        {-3,7},
        {-2,7},
        {-7,13}
    }
};

const SKP_int16 SKP_Silk_cbk_sizes_stage3[SKP_Silk_PITCH_EST_MAX_COMPLEX + 1] = 
{
    PITCH_EST_NB_CBKS_STAGE3_MIN,
    PITCH_EST_NB_CBKS_STAGE3_MID,
    PITCH_EST_NB_CBKS_STAGE3_MAX
};

const SKP_int16 SKP_Silk_cbk_offsets_stage3[SKP_Silk_PITCH_EST_MAX_COMPLEX + 1] = 
{
    ((PITCH_EST_NB_CBKS_STAGE3_MAX - PITCH_EST_NB_CBKS_STAGE3_MIN) >> 1),
    ((PITCH_EST_NB_CBKS_STAGE3_MAX - PITCH_EST_NB_CBKS_STAGE3_MID) >> 1),
    0
};









SKP_INLINE void SKP_Silk_prefilt_FIX(
    SKP_Silk_prefilter_state_FIX *P,                    
    SKP_int32   st_res_Q12[],                           
    SKP_int16   xw[],                                   
    SKP_int32   HarmShapeFIRPacked_Q12,                 
    SKP_int     Tilt_Q14,                               
    SKP_int32   LF_shp_Q14,                             
    SKP_int     lag,                                    
    SKP_int     length                                  
);
#if EMBEDDED_ARM<6
void SKP_Silk_warped_LPC_analysis_filter_FIX(
          SKP_int32                 state[],            
          SKP_int16                 res[],              
    const SKP_int16                 coef_Q13[],         
    const SKP_int16                 input[],            
    const SKP_int16                 lambda_Q16,         
    const SKP_int                   length,             
    const SKP_int                   order               
)
{
    SKP_int     n, i;
    SKP_int32   acc_Q11, tmp1, tmp2;

    
    SKP_assert( ( order & 1 ) == 0 );

    for( n = 0; n < length; n++ ) {
          
        tmp2 = SKP_SMLAWB( state[ 0 ], state[ 1 ], lambda_Q16 );
        state[ 0 ] = SKP_LSHIFT( input[ n ], 14 );
        
        tmp1 = SKP_SMLAWB( state[ 1 ], state[ 2 ] - tmp2, lambda_Q16 );
        state[ 1 ] = tmp2;
        acc_Q11 = SKP_SMULWB( tmp2, coef_Q13[ 0 ] );
        
        for( i = 2; i < order; i += 2 ) {
            
            tmp2 = SKP_SMLAWB( state[ i ], state[ i + 1 ] - tmp1, lambda_Q16 );
            state[ i ] = tmp1;
            acc_Q11 = SKP_SMLAWB( acc_Q11, tmp1, coef_Q13[ i - 1 ] );
            
            tmp1 = SKP_SMLAWB( state[ i + 1 ], state[ i + 2 ] - tmp2, lambda_Q16 );
            state[ i + 1 ] = tmp2;
            acc_Q11 = SKP_SMLAWB( acc_Q11, tmp2, coef_Q13[ i ] );
        }
        state[ order ] = tmp1;
        acc_Q11 = SKP_SMLAWB( acc_Q11, tmp1, coef_Q13[ order - 1 ] );
        res[ n ] = ( SKP_int16 )SKP_SAT16( ( SKP_int32 )input[ n ] - SKP_RSHIFT_ROUND( acc_Q11, 11 ) );
    }
}
#endif

void SKP_Silk_prefilter_FIX(
    SKP_Silk_encoder_state_FIX          *psEnc,         
    const SKP_Silk_encoder_control_FIX  *psEncCtrl,     
    SKP_int16                           xw[],           
    const SKP_int16                     x[]             
)
{
    SKP_Silk_prefilter_state_FIX *P = &psEnc->sPrefilt;
    SKP_int   j, k, lag;
    SKP_int32 tmp_32;
    const SKP_int16 *AR1_shp_Q13;
    const SKP_int16 *px;
    SKP_int16 *pxw;
    SKP_int   HarmShapeGain_Q12, Tilt_Q14;
    SKP_int32 HarmShapeFIRPacked_Q12, LF_shp_Q14;
    SKP_int32 x_filt_Q12[ MAX_FRAME_LENGTH / NB_SUBFR ];
    SKP_int16 st_res[ ( MAX_FRAME_LENGTH / NB_SUBFR ) + MAX_SHAPE_LPC_ORDER ];
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
    SKP_int32 B_Q12;
#else
    SKP_int16 B_Q12[ 2 ];
#endif

    
    px  = x;
    pxw = xw;
    lag = P->lagPrev;
    for( k = 0; k < NB_SUBFR; k++ ) {
        
        if( psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED ) {
            lag = psEncCtrl->sCmn.pitchL[ k ];
        }

        
        HarmShapeGain_Q12 = SKP_SMULWB( psEncCtrl->HarmShapeGain_Q14[ k ], 16384 - psEncCtrl->HarmBoost_Q14[ k ] );
        SKP_assert( HarmShapeGain_Q12 >= 0 );
        HarmShapeFIRPacked_Q12  =                          SKP_RSHIFT( HarmShapeGain_Q12, 2 );
        HarmShapeFIRPacked_Q12 |= SKP_LSHIFT( ( SKP_int32 )SKP_RSHIFT( HarmShapeGain_Q12, 1 ), 16 );
        Tilt_Q14    = psEncCtrl->Tilt_Q14[   k ];
        LF_shp_Q14  = psEncCtrl->LF_shp_Q14[ k ];
        AR1_shp_Q13 = &psEncCtrl->AR1_Q13[   k * MAX_SHAPE_LPC_ORDER ];

        
        SKP_Silk_warped_LPC_analysis_filter_FIX( P->sAR_shp, st_res, AR1_shp_Q13, px, 
            psEnc->sCmn.warping_Q16, psEnc->sCmn.subfr_length, psEnc->sCmn.shapingLPCOrder );

        
#if !defined(_SYSTEM_IS_BIG_ENDIAN)
        
        
        
        
        B_Q12 = SKP_RSHIFT_ROUND( psEncCtrl->GainsPre_Q14[ k ], 2 );
        tmp_32 = SKP_SMLABB( SKP_FIX_CONST( INPUT_TILT, 26 ), psEncCtrl->HarmBoost_Q14[ k ], HarmShapeGain_Q12 );   
        tmp_32 = SKP_SMLABB( tmp_32, psEncCtrl->coding_quality_Q14, SKP_FIX_CONST( HIGH_RATE_INPUT_TILT, 12 ) );    
        tmp_32 = SKP_SMULWB( tmp_32, -psEncCtrl->GainsPre_Q14[ k ] );                                               
        tmp_32 = SKP_RSHIFT_ROUND( tmp_32, 12 );                                                                    
        B_Q12 |= SKP_LSHIFT( SKP_SAT16( tmp_32 ), 16 );

        x_filt_Q12[ 0 ] = SKP_SMLABT( SKP_SMULBB( st_res[ 0 ], B_Q12 ), P->sHarmHP, B_Q12 );
        for( j = 1; j < psEnc->sCmn.subfr_length; j++ ) {
            x_filt_Q12[ j ] = SKP_SMLABT( SKP_SMULBB( st_res[ j ], B_Q12 ), st_res[ j - 1 ], B_Q12 );
        }
#else
        B_Q12[ 0 ] = SKP_RSHIFT_ROUND( psEncCtrl->GainsPre_Q14[ k ], 2 );
        tmp_32 = SKP_SMLABB( SKP_FIX_CONST( INPUT_TILT, 26 ), psEncCtrl->HarmBoost_Q14[ k ], HarmShapeGain_Q12 );   
        tmp_32 = SKP_SMLABB( tmp_32, psEncCtrl->coding_quality_Q14, SKP_FIX_CONST( HIGH_RATE_INPUT_TILT, 12 ) );    
        tmp_32 = SKP_SMULWB( tmp_32, -psEncCtrl->GainsPre_Q14[ k ] );                                               
        tmp_32 = SKP_RSHIFT_ROUND( tmp_32, 12 );                                                                    
        B_Q12[ 1 ]= SKP_SAT16( tmp_32 );

        x_filt_Q12[ 0 ] = SKP_SMLABB( SKP_SMULBB( st_res[ 0 ], B_Q12[ 0 ] ), P->sHarmHP, B_Q12[ 1 ] );
        for( j = 1; j < psEnc->sCmn.subfr_length; j++ ) {
            x_filt_Q12[ j ] = SKP_SMLABB( SKP_SMULBB( st_res[ j ], B_Q12[ 0 ] ), st_res[ j - 1 ], B_Q12[ 1 ] );
        }
#endif
        P->sHarmHP = st_res[ psEnc->sCmn.subfr_length - 1 ];

        SKP_Silk_prefilt_FIX( P, x_filt_Q12, pxw, HarmShapeFIRPacked_Q12, Tilt_Q14, 
            LF_shp_Q14, lag, psEnc->sCmn.subfr_length );

        px  += psEnc->sCmn.subfr_length;
        pxw += psEnc->sCmn.subfr_length;
    }

    P->lagPrev = psEncCtrl->sCmn.pitchL[ NB_SUBFR - 1 ];
}


SKP_INLINE void SKP_Silk_prefilt_FIX(
    SKP_Silk_prefilter_state_FIX *P,                    
    SKP_int32   st_res_Q12[],                           
    SKP_int16   xw[],                                   
    SKP_int32   HarmShapeFIRPacked_Q12,                 
    SKP_int     Tilt_Q14,                               
    SKP_int32   LF_shp_Q14,                             
    SKP_int     lag,                                    
    SKP_int     length                                  
)
{
    SKP_int   i, idx, LTP_shp_buf_idx;
    SKP_int32 n_LTP_Q12, n_Tilt_Q10, n_LF_Q10;
    SKP_int32 sLF_MA_shp_Q12, sLF_AR_shp_Q12;
    SKP_int16 *LTP_shp_buf;

    
    LTP_shp_buf     = P->sLTP_shp;
    LTP_shp_buf_idx = P->sLTP_shp_buf_idx;
    sLF_AR_shp_Q12  = P->sLF_AR_shp_Q12;
    sLF_MA_shp_Q12  = P->sLF_MA_shp_Q12;

    for( i = 0; i < length; i++ ) {
        if( lag > 0 ) {
            
            SKP_assert( HARM_SHAPE_FIR_TAPS == 3 );
            idx = lag + LTP_shp_buf_idx;
            n_LTP_Q12 = SKP_SMULBB(            LTP_shp_buf[ ( idx - HARM_SHAPE_FIR_TAPS / 2 - 1) & LTP_MASK ], HarmShapeFIRPacked_Q12 );
            n_LTP_Q12 = SKP_SMLABT( n_LTP_Q12, LTP_shp_buf[ ( idx - HARM_SHAPE_FIR_TAPS / 2    ) & LTP_MASK ], HarmShapeFIRPacked_Q12 );
            n_LTP_Q12 = SKP_SMLABB( n_LTP_Q12, LTP_shp_buf[ ( idx - HARM_SHAPE_FIR_TAPS / 2 + 1) & LTP_MASK ], HarmShapeFIRPacked_Q12 );
        } else {
            n_LTP_Q12 = 0;
        }

        n_Tilt_Q10 = SKP_SMULWB( sLF_AR_shp_Q12, Tilt_Q14 );
        n_LF_Q10   = SKP_SMLAWB( SKP_SMULWT( sLF_AR_shp_Q12, LF_shp_Q14 ), sLF_MA_shp_Q12, LF_shp_Q14 );

        sLF_AR_shp_Q12 = SKP_SUB32( st_res_Q12[ i ], SKP_LSHIFT( n_Tilt_Q10, 2 ) );
        sLF_MA_shp_Q12 = SKP_SUB32( sLF_AR_shp_Q12,  SKP_LSHIFT( n_LF_Q10,   2 ) );

        LTP_shp_buf_idx = ( LTP_shp_buf_idx - 1 ) & LTP_MASK;
        LTP_shp_buf[ LTP_shp_buf_idx ] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( sLF_MA_shp_Q12, 12 ) );

        xw[i] = ( SKP_int16 )SKP_SAT16( SKP_RSHIFT_ROUND( SKP_SUB32( sLF_MA_shp_Q12, n_LTP_Q12 ), 12 ) );
    }

    
    P->sLF_AR_shp_Q12   = sLF_AR_shp_Q12;
    P->sLF_MA_shp_Q12   = sLF_MA_shp_Q12;
    P->sLTP_shp_buf_idx = LTP_shp_buf_idx;
}






 
void SKP_Silk_process_NLSFs_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,             
    SKP_Silk_encoder_control_FIX    *psEncCtrl,         
    SKP_int                         *pNLSF_Q15          
)
{
    SKP_int     doInterpolate;
    SKP_int     pNLSFW_Q6[ MAX_LPC_ORDER ];
    SKP_int     NLSF_mu_Q15, NLSF_mu_fluc_red_Q16;
    SKP_int32   i_sqr_Q15;
    const SKP_Silk_NLSF_CB_struct *psNLSF_CB;

    
    SKP_int     pNLSF0_temp_Q15[ MAX_LPC_ORDER ];
    SKP_int     pNLSFW0_temp_Q6[ MAX_LPC_ORDER ];
    SKP_int     i;

    SKP_assert( psEnc->speech_activity_Q8 >=   0 );
    SKP_assert( psEnc->speech_activity_Q8 <= 256 );
    SKP_assert( psEncCtrl->sparseness_Q8  >=   0 );
    SKP_assert( psEncCtrl->sparseness_Q8  <= 256 );
    SKP_assert( psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED || psEncCtrl->sCmn.sigtype == SIG_TYPE_UNVOICED );

    
    
    
    if( psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED ) {
        
        
        NLSF_mu_Q15          = SKP_SMLAWB(   66,   -8388, psEnc->speech_activity_Q8 );
        NLSF_mu_fluc_red_Q16 = SKP_SMLAWB( 6554, -838848, psEnc->speech_activity_Q8 );
    } else { 
        
        
        NLSF_mu_Q15          = SKP_SMLAWB(   164,   -33554, psEnc->speech_activity_Q8 );
        NLSF_mu_fluc_red_Q16 = SKP_SMLAWB( 13107, -1677696, psEnc->speech_activity_Q8 + psEncCtrl->sparseness_Q8 ); 
    }
    SKP_assert( NLSF_mu_Q15          >= 0     );
    SKP_assert( NLSF_mu_Q15          <= 164   );
    SKP_assert( NLSF_mu_fluc_red_Q16 >= 0     );
    SKP_assert( NLSF_mu_fluc_red_Q16 <= 13107 );

    NLSF_mu_Q15 = SKP_max( NLSF_mu_Q15, 1 );

    
    TIC(NLSF_weights_FIX)
    SKP_Silk_NLSF_VQ_weights_laroia( pNLSFW_Q6, pNLSF_Q15, psEnc->sCmn.predictLPCOrder );
    TOC(NLSF_weights_FIX)

    
    doInterpolate = ( psEnc->sCmn.useInterpolatedNLSFs == 1 ) && ( psEncCtrl->sCmn.NLSFInterpCoef_Q2 < ( 1 << 2 ) );
    if( doInterpolate ) {

        
        SKP_Silk_interpolate( pNLSF0_temp_Q15, psEnc->sPred.prev_NLSFq_Q15, pNLSF_Q15, 
            psEncCtrl->sCmn.NLSFInterpCoef_Q2, psEnc->sCmn.predictLPCOrder );

        
        TIC(NLSF_weights_FIX)
        SKP_Silk_NLSF_VQ_weights_laroia( pNLSFW0_temp_Q6, pNLSF0_temp_Q15, psEnc->sCmn.predictLPCOrder );
        TOC(NLSF_weights_FIX)

        
        i_sqr_Q15 = SKP_LSHIFT( SKP_SMULBB( psEncCtrl->sCmn.NLSFInterpCoef_Q2, psEncCtrl->sCmn.NLSFInterpCoef_Q2 ), 11 );
        for( i = 0; i < psEnc->sCmn.predictLPCOrder; i++ ) {
            pNLSFW_Q6[ i ] = SKP_SMLAWB( SKP_RSHIFT( pNLSFW_Q6[ i ], 1 ), pNLSFW0_temp_Q6[ i ], i_sqr_Q15 );
            SKP_assert( pNLSFW_Q6[ i ] <= SKP_int16_MAX );
            SKP_assert( pNLSFW_Q6[ i ] >= 1 );
        }
    }

    
    psNLSF_CB = psEnc->sCmn.psNLSF_CB[ psEncCtrl->sCmn.sigtype ];

    
    TIC(MSVQ_encode_FIX)
    SKP_Silk_NLSF_MSVQ_encode_FIX( psEncCtrl->sCmn.NLSFIndices, pNLSF_Q15, psNLSF_CB, 
        psEnc->sPred.prev_NLSFq_Q15, pNLSFW_Q6, NLSF_mu_Q15, NLSF_mu_fluc_red_Q16, 
        psEnc->sCmn.NLSF_MSVQ_Survivors, psEnc->sCmn.predictLPCOrder, psEnc->sCmn.first_frame_after_reset );
    TOC(MSVQ_encode_FIX)

    
    SKP_Silk_NLSF2A_stable( psEncCtrl->PredCoef_Q12[ 1 ], pNLSF_Q15, psEnc->sCmn.predictLPCOrder );

    if( doInterpolate ) {
        
        SKP_Silk_interpolate( pNLSF0_temp_Q15, psEnc->sPred.prev_NLSFq_Q15, pNLSF_Q15, 
            psEncCtrl->sCmn.NLSFInterpCoef_Q2, psEnc->sCmn.predictLPCOrder );

        
        SKP_Silk_NLSF2A_stable( psEncCtrl->PredCoef_Q12[ 0 ], pNLSF0_temp_Q15, psEnc->sCmn.predictLPCOrder );

    } else {
        
        SKP_memcpy( psEncCtrl->PredCoef_Q12[ 0 ], psEncCtrl->PredCoef_Q12[ 1 ], psEnc->sCmn.predictLPCOrder * sizeof( SKP_int16 ) );
    }
}








void SKP_Silk_process_gains_FIX(
    SKP_Silk_encoder_state_FIX      *psEnc,         
    SKP_Silk_encoder_control_FIX    *psEncCtrl      
)
{
    SKP_Silk_shape_state_FIX    *psShapeSt = &psEnc->sShape;
    SKP_int     k;
    SKP_int32   s_Q16, InvMaxSqrVal_Q16, gain, gain_squared, ResNrg, ResNrgPart, quant_offset_Q10;

    
    if( psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED ) {
        
        s_Q16 = -SKP_Silk_sigm_Q15( SKP_RSHIFT_ROUND( psEncCtrl->LTPredCodGain_Q7 - SKP_FIX_CONST( 12.0, 7 ), 4 ) );
        for( k = 0; k < NB_SUBFR; k++ ) {
            psEncCtrl->Gains_Q16[ k ] = SKP_SMLAWB( psEncCtrl->Gains_Q16[ k ], psEncCtrl->Gains_Q16[ k ], s_Q16 );
        }
    }

    
    InvMaxSqrVal_Q16 = SKP_DIV32_16( SKP_Silk_log2lin( 
        SKP_SMULWB( SKP_FIX_CONST( 70.0, 7 ) - psEncCtrl->current_SNR_dB_Q7, SKP_FIX_CONST( 0.33, 16 ) ) ), psEnc->sCmn.subfr_length );

    for( k = 0; k < NB_SUBFR; k++ ) {
        
        ResNrg     = psEncCtrl->ResNrg[ k ];
        ResNrgPart = SKP_SMULWW( ResNrg, InvMaxSqrVal_Q16 );
        if( psEncCtrl->ResNrgQ[ k ] > 0 ) {
            if( psEncCtrl->ResNrgQ[ k ] < 32 ) {
                ResNrgPart = SKP_RSHIFT_ROUND( ResNrgPart, psEncCtrl->ResNrgQ[ k ] );
            } else {
                ResNrgPart = 0;
            }
        } else if( psEncCtrl->ResNrgQ[k] != 0 ) {
            if( ResNrgPart > SKP_RSHIFT( SKP_int32_MAX, -psEncCtrl->ResNrgQ[ k ] ) ) {
                ResNrgPart = SKP_int32_MAX;
            } else {
                ResNrgPart = SKP_LSHIFT( ResNrgPart, -psEncCtrl->ResNrgQ[ k ] );
            }
        }
        gain = psEncCtrl->Gains_Q16[ k ];
        gain_squared = SKP_ADD_SAT32( ResNrgPart, SKP_SMMUL( gain, gain ) );
        if( gain_squared < SKP_int16_MAX ) {
            
            gain_squared = SKP_SMLAWW( SKP_LSHIFT( ResNrgPart, 16 ), gain, gain );
            SKP_assert( gain_squared > 0 );
            gain = SKP_Silk_SQRT_APPROX( gain_squared );                  
            psEncCtrl->Gains_Q16[ k ] = SKP_LSHIFT_SAT32( gain, 8 );        
        } else {
            gain = SKP_Silk_SQRT_APPROX( gain_squared );                  
            psEncCtrl->Gains_Q16[ k ] = SKP_LSHIFT_SAT32( gain, 16 );       
        }
    }

    
    SKP_Silk_gains_quant( psEncCtrl->sCmn.GainsIndices, psEncCtrl->Gains_Q16, 
        &psShapeSt->LastGainIndex, psEnc->sCmn.nFramesInPayloadBuf );
    
    if( psEncCtrl->sCmn.sigtype == SIG_TYPE_VOICED ) {
        if( psEncCtrl->LTPredCodGain_Q7 + SKP_RSHIFT( psEncCtrl->input_tilt_Q15, 8 ) > SKP_FIX_CONST( 1.0, 7 ) ) {
            psEncCtrl->sCmn.QuantOffsetType = 0;
        } else {
            psEncCtrl->sCmn.QuantOffsetType = 1;
        }
    }

    
    quant_offset_Q10 = SKP_Silk_Quantization_Offsets_Q10[ psEncCtrl->sCmn.sigtype ][ psEncCtrl->sCmn.QuantOffsetType ];
    psEncCtrl->Lambda_Q10 = SKP_FIX_CONST( LAMBDA_OFFSET, 10 )
                          + SKP_SMULBB( SKP_FIX_CONST( LAMBDA_DELAYED_DECISIONS, 10 ), psEnc->sCmn.nStatesDelayedDecision )
                          + SKP_SMULWB( SKP_FIX_CONST( LAMBDA_SPEECH_ACT,        18 ), psEnc->speech_activity_Q8          )
                          + SKP_SMULWB( SKP_FIX_CONST( LAMBDA_INPUT_QUALITY,     12 ), psEncCtrl->input_quality_Q14       )
                          + SKP_SMULWB( SKP_FIX_CONST( LAMBDA_CODING_QUALITY,    12 ), psEncCtrl->coding_quality_Q14      )
                          + SKP_SMULWB( SKP_FIX_CONST( LAMBDA_QUANT_OFFSET,      16 ), quant_offset_Q10                   );

    SKP_assert( psEncCtrl->Lambda_Q10 > 0 );
    SKP_assert( psEncCtrl->Lambda_Q10 < SKP_FIX_CONST( 2, 10 ) );
}






void SKP_Silk_quant_LTP_gains_FIX(
    SKP_int16               B_Q14[],                
    SKP_int                 cbk_index[],            
    SKP_int                 *periodicity_index,     
    const SKP_int32         W_Q18[],                
    SKP_int                 mu_Q8,                  
    SKP_int                 lowComplexity           
)
{
    SKP_int             j, k, temp_idx[ NB_SUBFR ], cbk_size;
    const SKP_int16     *cl_ptr;
    const SKP_int16     *cbk_ptr_Q14;
    const SKP_int16     *b_Q14_ptr;
    const SKP_int32     *W_Q18_ptr;
    SKP_int32           rate_dist_subfr, rate_dist, min_rate_dist;



    
    
    
    
    min_rate_dist = SKP_int32_MAX;
    for( k = 0; k < 3; k++ ) {
        cl_ptr      = SKP_Silk_LTP_gain_BITS_Q6_ptrs[ k ];
        cbk_ptr_Q14 = SKP_Silk_LTP_vq_ptrs_Q14[       k ];
        cbk_size    = SKP_Silk_LTP_vq_sizes[          k ];

        
        W_Q18_ptr = W_Q18;
        b_Q14_ptr = B_Q14;

        rate_dist = 0;
        for( j = 0; j < NB_SUBFR; j++ ) {

            SKP_Silk_VQ_WMat_EC_FIX(
                &temp_idx[ j ],         
                &rate_dist_subfr,       
                b_Q14_ptr,              
                W_Q18_ptr,              
                cbk_ptr_Q14,            
                cl_ptr,                 
                mu_Q8,                  
                cbk_size                
            );

            rate_dist = SKP_ADD_POS_SAT32( rate_dist, rate_dist_subfr );

            b_Q14_ptr += LTP_ORDER;
            W_Q18_ptr += LTP_ORDER * LTP_ORDER;
        }

        
        rate_dist = SKP_min( SKP_int32_MAX - 1, rate_dist );

        if( rate_dist < min_rate_dist ) {
            min_rate_dist = rate_dist;
            SKP_memcpy( cbk_index, temp_idx, NB_SUBFR * sizeof( SKP_int ) );
            *periodicity_index = k;
        }

        
        if( lowComplexity && ( rate_dist < SKP_Silk_LTP_gain_middle_avg_RD_Q14 ) ) {
            break;
        }
    }

    cbk_ptr_Q14 = SKP_Silk_LTP_vq_ptrs_Q14[ *periodicity_index ];
    for( j = 0; j < NB_SUBFR; j++ ) {
        for( k = 0; k < LTP_ORDER; k++ ) { 
            B_Q14[ j * LTP_ORDER + k ] = cbk_ptr_Q14[ SKP_MLA( k, cbk_index[ j ], LTP_ORDER ) ];
        }
    }
}








void SKP_Silk_range_encoder(
    SKP_Silk_range_coder_state      *psRC,              
    const SKP_int                   data,               
    const SKP_uint16                prob[]              
)
{
    SKP_uint32 low_Q16, high_Q16;
    SKP_uint32 base_tmp, range_Q32;

    
    SKP_uint32 base_Q32  = psRC->base_Q32;
    SKP_uint32 range_Q16 = psRC->range_Q16;
    SKP_int32  bufferIx  = psRC->bufferIx;
    SKP_uint8  *buffer   = psRC->buffer;

    if( psRC->error ) {
        return;
    }

    
    low_Q16  = prob[ data ];
    high_Q16 = prob[ data + 1 ];
    base_tmp = base_Q32; 
    base_Q32 += SKP_MUL_uint( range_Q16, low_Q16 );
    range_Q32 = SKP_MUL_uint( range_Q16, high_Q16 - low_Q16 );

    
    if( base_Q32 < base_tmp ) {
        
        SKP_int bufferIx_tmp = bufferIx;
        while( ( ++buffer[ --bufferIx_tmp ] ) == 0 );
    }

    
    if( range_Q32 & 0xFF000000 ) {
        
        range_Q16 = SKP_RSHIFT_uint( range_Q32, 16 );
    } else {
        if( range_Q32 & 0xFFFF0000 ) {
            
            range_Q16 = SKP_RSHIFT_uint( range_Q32, 8 );
        } else {
            
            range_Q16 = range_Q32;
            
            if( bufferIx >= psRC->bufferLength ) {
                psRC->error = RANGE_CODER_WRITE_BEYOND_BUFFER;
                return;
            }
            
            buffer[ bufferIx++ ] = (SKP_uint8)( SKP_RSHIFT_uint( base_Q32, 24 ) );
            base_Q32 = SKP_LSHIFT_ovflw( base_Q32, 8 );
        }
        
        if( bufferIx >= psRC->bufferLength ) {
            psRC->error = RANGE_CODER_WRITE_BEYOND_BUFFER;
            return;
        }
        
        buffer[ bufferIx++ ] = (SKP_uint8)( SKP_RSHIFT_uint( base_Q32, 24 ) );
        base_Q32 = SKP_LSHIFT_ovflw( base_Q32, 8 );
    }

    
    psRC->base_Q32  = base_Q32;
    psRC->range_Q16 = range_Q16;
    psRC->bufferIx  = bufferIx;
}


void SKP_Silk_range_encoder_multi(
    SKP_Silk_range_coder_state      *psRC,              
    const SKP_int                   data[],             
    const SKP_uint16 * const        prob[],             
    const SKP_int                   nSymbols            
)
{
    SKP_int k;
    for( k = 0; k < nSymbols; k++ ) {
        SKP_Silk_range_encoder( psRC, data[ k ], prob[ k ] );
    }
}


void SKP_Silk_range_decoder(
    SKP_int                         data[],             
    SKP_Silk_range_coder_state      *psRC,              
    const SKP_uint16                prob[],             
    SKP_int                         probIx              
)
{
    SKP_uint32 low_Q16, high_Q16;
    SKP_uint32 base_tmp, range_Q32;

    
    SKP_uint32 base_Q32  = psRC->base_Q32;
    SKP_uint32 range_Q16 = psRC->range_Q16;
    SKP_int32  bufferIx  = psRC->bufferIx;
    SKP_uint8  *buffer   = &psRC->buffer[ 4 ];

    if( psRC->error ) {
        
        *data = 0;
        return;
    }

    high_Q16 = prob[ probIx ];
    base_tmp = SKP_MUL_uint( range_Q16, high_Q16 );
    if( base_tmp > base_Q32 ) {
        while( 1 ) {
            low_Q16 = prob[ --probIx ];
            base_tmp = SKP_MUL_uint( range_Q16, low_Q16 );
            if( base_tmp <= base_Q32 ) {
                break;
            }
            high_Q16 = low_Q16;
            
            if( high_Q16 == 0 ) {
                psRC->error = RANGE_CODER_CDF_OUT_OF_RANGE;
                
                *data = 0;
                return;
            }
        }
    } else {
        while( 1 ) {
            low_Q16  = high_Q16;
            high_Q16 = prob[ ++probIx ];
            base_tmp = SKP_MUL_uint( range_Q16, high_Q16 );
            if( base_tmp > base_Q32 ) {
                probIx--;
                break;
            }
            
            if( high_Q16 == 0xFFFF ) {
                psRC->error = RANGE_CODER_CDF_OUT_OF_RANGE;
                
                *data = 0;
                return;
            }
        }
    }
    *data = probIx;
    base_Q32 -= SKP_MUL_uint( range_Q16, low_Q16 );
    range_Q32 = SKP_MUL_uint( range_Q16, high_Q16 - low_Q16 );

    
    if( range_Q32 & 0xFF000000 ) {
        
        range_Q16 = SKP_RSHIFT_uint( range_Q32, 16 );
    } else {
        if( range_Q32 & 0xFFFF0000 ) {
            
            range_Q16 = SKP_RSHIFT_uint( range_Q32, 8 );
            
            if( SKP_RSHIFT_uint( base_Q32, 24 ) ) {
                psRC->error = RANGE_CODER_NORMALIZATION_FAILED;
                
                *data = 0;
                return;
            }
        } else {
            
            range_Q16 = range_Q32;
            
            if( SKP_RSHIFT( base_Q32, 16 ) ) {
                psRC->error = RANGE_CODER_NORMALIZATION_FAILED;
                
                *data = 0;
                return;
            }
            
            base_Q32 = SKP_LSHIFT_uint( base_Q32, 8 );
            
            if( bufferIx < psRC->bufferLength ) {
                
                base_Q32 |= (SKP_uint32)buffer[ bufferIx++ ];
            }
        }
        
        base_Q32 = SKP_LSHIFT_uint( base_Q32, 8 );
        
        if( bufferIx < psRC->bufferLength ) {
            
            base_Q32 |= (SKP_uint32)buffer[ bufferIx++ ];
        }
    }

    
    if( range_Q16 == 0 ) {
        psRC->error = RANGE_CODER_ZERO_INTERVAL_WIDTH;
        
        *data = 0;
        return;
    }

    
    psRC->base_Q32  = base_Q32;
    psRC->range_Q16 = range_Q16;
    psRC->bufferIx  = bufferIx;
}


void SKP_Silk_range_decoder_multi(
    SKP_int                         data[],             
    SKP_Silk_range_coder_state      *psRC,              
    const SKP_uint16 * const        prob[],             
    const SKP_int                   probStartIx[],      
    const SKP_int                   nSymbols            
)
{
    SKP_int k;
    for( k = 0; k < nSymbols; k++ ) {
        SKP_Silk_range_decoder( &data[ k ], psRC, prob[ k ], probStartIx[ k ] );
    }
}


void SKP_Silk_range_enc_init(
    SKP_Silk_range_coder_state      *psRC               
)
{
    
    psRC->bufferLength = MAX_ARITHM_BYTES;
    psRC->range_Q16    = 0x0000FFFF;
    psRC->bufferIx     = 0;
    psRC->base_Q32     = 0;
    psRC->error        = 0;
}


void SKP_Silk_range_dec_init(
    SKP_Silk_range_coder_state      *psRC,              
    const SKP_uint8                 buffer[],           
    const SKP_int32                 bufferLength        
)
{
    
    if( ( bufferLength > MAX_ARITHM_BYTES ) || ( bufferLength < 0 ) ) {
        psRC->error = RANGE_CODER_DEC_PAYLOAD_TOO_LONG;
        return;
    }
    
    
    SKP_memcpy( psRC->buffer, buffer, bufferLength * sizeof( SKP_uint8 ) ); 
    psRC->bufferLength = bufferLength;
    psRC->bufferIx = 0;
    psRC->base_Q32 = 
        SKP_LSHIFT_uint( (SKP_uint32)buffer[ 0 ], 24 ) | 
        SKP_LSHIFT_uint( (SKP_uint32)buffer[ 1 ], 16 ) | 
        SKP_LSHIFT_uint( (SKP_uint32)buffer[ 2 ],  8 ) | 
                         (SKP_uint32)buffer[ 3 ];
    psRC->range_Q16 = 0x0000FFFF;
    psRC->error     = 0;
}


SKP_int SKP_Silk_range_coder_get_length(                
    const SKP_Silk_range_coder_state    *psRC,          
    SKP_int                             *nBytes         
)
{
    SKP_int nBits;

    
    nBits = SKP_LSHIFT( psRC->bufferIx, 3 ) + SKP_Silk_CLZ32( psRC->range_Q16 - 1 ) - 14;

    *nBytes = SKP_RSHIFT( nBits + 7, 3 );

    
    return nBits;
}


void SKP_Silk_range_enc_wrap_up(
    SKP_Silk_range_coder_state      *psRC               
)
{
    SKP_int bufferIx_tmp, bits_to_store, bits_in_stream, nBytes, mask;
    SKP_uint32 base_Q24;

    
    base_Q24 = SKP_RSHIFT_uint( psRC->base_Q32, 8 );

    bits_in_stream = SKP_Silk_range_coder_get_length( psRC, &nBytes );

    
    bits_to_store = bits_in_stream - SKP_LSHIFT( psRC->bufferIx, 3 );
    
    base_Q24 += SKP_RSHIFT_uint(  0x00800000, bits_to_store - 1 );
    base_Q24 &= SKP_LSHIFT_ovflw( 0xFFFFFFFF, 24 - bits_to_store );

    
    if( base_Q24 & 0x01000000 ) {
        
        bufferIx_tmp = psRC->bufferIx;
        while( ( ++( psRC->buffer[ --bufferIx_tmp ] ) ) == 0 );
    }

    
    if( psRC->bufferIx < psRC->bufferLength ) {
        psRC->buffer[ psRC->bufferIx++ ] = (SKP_uint8)SKP_RSHIFT_uint( base_Q24, 16 );
        if( bits_to_store > 8 ) {
            if( psRC->bufferIx < psRC->bufferLength ) {
                psRC->buffer[ psRC->bufferIx++ ] = (SKP_uint8)SKP_RSHIFT_uint( base_Q24, 8 );
            }
        }
    }

    
    if( bits_in_stream & 7 ) {
        mask = SKP_RSHIFT( 0xFF, bits_in_stream & 7 );
        if( nBytes - 1 < psRC->bufferLength ) {
            psRC->buffer[ nBytes - 1 ] |= mask;
        }
    }
}


void SKP_Silk_range_coder_check_after_decoding(
    SKP_Silk_range_coder_state      *psRC               
)
{
    SKP_int bits_in_stream, nBytes, mask;

    bits_in_stream = SKP_Silk_range_coder_get_length( psRC, &nBytes );

    
    if( nBytes - 1 >= psRC->bufferLength ) {
        psRC->error = RANGE_CODER_DECODER_CHECK_FAILED;
        return;
    }

    
    if( bits_in_stream & 7 ) {
        mask = SKP_RSHIFT( 0xFF, bits_in_stream & 7 );
        if( ( psRC->buffer[ nBytes - 1 ] & mask ) != mask ) {
            psRC->error = RANGE_CODER_DECODER_CHECK_FAILED;
            return;
        }
    }
}







void SKP_Silk_regularize_correlations_FIX(
    SKP_int32                       *XX,                
    SKP_int32                       *xx,                
    SKP_int32                       noise,              
    SKP_int                         D                   
)
{
    SKP_int i;
    for( i = 0; i < D; i++ ) {
        matrix_ptr( &XX[ 0 ], i, i, D ) = SKP_ADD32( matrix_ptr( &XX[ 0 ], i, i, D ), noise );
    }
    xx[ 0 ] += noise;
}













#ifndef SKP_Silk_RESAMPLER_H
#define SKP_Silk_RESAMPLER_H

#ifdef __cplusplus
extern "C" {
#endif








#ifndef _SKP_SILK_FIX_RESAMPLER_ROM_H_
#define _SKP_SILK_FIX_RESAMPLER_ROM_H_

#ifdef  __cplusplus
extern "C"
{
#endif




#define RESAMPLER_DOWN_ORDER_FIR                12
#define RESAMPLER_ORDER_FIR_144                 6



extern const SKP_int16 SKP_Silk_resampler_down2_0;
extern const SKP_int16 SKP_Silk_resampler_down2_1;


extern const SKP_int16 SKP_Silk_resampler_up2_lq_0;
extern const SKP_int16 SKP_Silk_resampler_up2_lq_1;


extern const SKP_int16 SKP_Silk_resampler_up2_hq_0[ 2 ];
extern const SKP_int16 SKP_Silk_resampler_up2_hq_1[ 2 ];
extern const SKP_int16 SKP_Silk_resampler_up2_hq_notch[ 4 ];


extern const SKP_int16 SKP_Silk_Resampler_3_4_COEFS[ 2 + 3 * RESAMPLER_DOWN_ORDER_FIR / 2 ];
extern const SKP_int16 SKP_Silk_Resampler_2_3_COEFS[ 2 + 2 * RESAMPLER_DOWN_ORDER_FIR / 2 ];
extern const SKP_int16 SKP_Silk_Resampler_1_2_COEFS[ 2 +     RESAMPLER_DOWN_ORDER_FIR / 2 ];
extern const SKP_int16 SKP_Silk_Resampler_3_8_COEFS[ 2 + 3 * RESAMPLER_DOWN_ORDER_FIR / 2 ];
extern const SKP_int16 SKP_Silk_Resampler_1_3_COEFS[ 2 +     RESAMPLER_DOWN_ORDER_FIR / 2 ];
extern const SKP_int16 SKP_Silk_Resampler_2_3_COEFS_LQ[ 2 + 2 * 2 ];
extern const SKP_int16 SKP_Silk_Resampler_1_3_COEFS_LQ[ 2 + 3 ];


extern const SKP_int16 SKP_Silk_Resampler_320_441_ARMA4_COEFS[ 7 ];
extern const SKP_int16 SKP_Silk_Resampler_240_441_ARMA4_COEFS[ 7 ];
extern const SKP_int16 SKP_Silk_Resampler_160_441_ARMA4_COEFS[ 7 ];
extern const SKP_int16 SKP_Silk_Resampler_120_441_ARMA4_COEFS[ 7 ];
extern const SKP_int16 SKP_Silk_Resampler_80_441_ARMA4_COEFS[ 7 ];


extern const SKP_int16 SKP_Silk_resampler_frac_FIR_144[ 144 ][ RESAMPLER_ORDER_FIR_144 / 2 ];

#ifdef  __cplusplus
}
#endif

#endif 


#define RESAMPLER_MAX_BATCH_SIZE_IN             480


void SKP_Silk_resampler_private_IIR_FIR(
	void	                        *SS,		    
	SKP_int16						out[],		    
	const SKP_int16					in[],		    
	SKP_int32					    inLen		    
);


void SKP_Silk_resampler_private_down_FIR(
	void	                        *SS,		    
	SKP_int16						out[],		    
	const SKP_int16					in[],		    
	SKP_int32					    inLen		    
);


void SKP_Silk_resampler_private_copy(
	void	                        *SS,		    
	SKP_int16						out[],		    
	const SKP_int16					in[],		    
	SKP_int32					    inLen		    
);


void SKP_Silk_resampler_private_up2_HQ_wrapper(
	void	                        *SS,		    
    SKP_int16                       *out,           
    const SKP_int16                 *in,            
    SKP_int32                       len             
);


void SKP_Silk_resampler_private_up2_HQ(
	SKP_int32	                    *S,			    
    SKP_int16                       *out,           
    const SKP_int16                 *in,            
    SKP_int32                       len             
);


void SKP_Silk_resampler_private_up4(
    SKP_int32                       *S,             
    SKP_int16                       *out,           
    const SKP_int16                 *in,            
    SKP_int32                       len             
);


void SKP_Silk_resampler_private_down4(
    SKP_int32                       *S,             
    SKP_int16                       *out,           
    const SKP_int16                 *in,            
    SKP_int32                       inLen           
);


void SKP_Silk_resampler_private_AR2(
	SKP_int32					    S[],		    
	SKP_int32					    out_Q8[],		
	const SKP_int16				    in[],			
	const SKP_int16				    A_Q14[],		
	SKP_int32				        len				
);


void SKP_Silk_resampler_private_ARMA4(
	SKP_int32					    S[],		    
	SKP_int16					    out[],		    
	const SKP_int16				    in[],			
	const SKP_int16				    Coef[],		    
	SKP_int32				        len				
);


#ifdef __cplusplus
}
#endif
#endif 



static SKP_int32 gcd(
    SKP_int32 a,
    SKP_int32 b
)
{
    SKP_int32 tmp;
    while( b > 0 ) {
        tmp = a - b * SKP_DIV32( a, b );
        a   = b;
        b   = tmp;
    }
    return a;
}


SKP_int SKP_Silk_resampler_init( 
	SKP_Silk_resampler_state_struct	*S,		    
	SKP_int32							Fs_Hz_in,	
	SKP_int32							Fs_Hz_out	
)
{
    SKP_int32 cycleLen, cyclesPerBatch, up2 = 0, down2 = 0;

	
	SKP_memset( S, 0, sizeof( SKP_Silk_resampler_state_struct ) );

	
#if RESAMPLER_SUPPORT_ABOVE_48KHZ
	if( Fs_Hz_in < 8000 || Fs_Hz_in > 192000 || Fs_Hz_out < 8000 || Fs_Hz_out > 192000 ) {
#else
    if( Fs_Hz_in < 8000 || Fs_Hz_in >  48000 || Fs_Hz_out < 8000 || Fs_Hz_out >  48000 ) {
#endif
		SKP_assert( 0 );
		return -1;
	}

#if RESAMPLER_SUPPORT_ABOVE_48KHZ
	
	if( Fs_Hz_in > 96000 ) {
		S->nPreDownsamplers = 2;
        S->down_pre_function = SKP_Silk_resampler_private_down4;
    } else if( Fs_Hz_in > 48000 ) {
		S->nPreDownsamplers = 1;
        S->down_pre_function = SKP_Silk_resampler_down2;
    } else {
		S->nPreDownsamplers = 0;
        S->down_pre_function = NULL;
    }

	if( Fs_Hz_out > 96000 ) {
		S->nPostUpsamplers = 2;
        S->up_post_function = SKP_Silk_resampler_private_up4;
    } else if( Fs_Hz_out > 48000 ) {
		S->nPostUpsamplers = 1;
        S->up_post_function = SKP_Silk_resampler_up2;
    } else {
		S->nPostUpsamplers = 0;
        S->up_post_function = NULL;
    }

    if( S->nPreDownsamplers + S->nPostUpsamplers > 0 ) {
        
	    S->ratio_Q16 = SKP_LSHIFT32( SKP_DIV32( SKP_LSHIFT32( Fs_Hz_out, 13 ), Fs_Hz_in ), 3 );
        
        while( SKP_SMULWW( S->ratio_Q16, Fs_Hz_in ) < Fs_Hz_out ) S->ratio_Q16++;

        
        S->batchSizePrePost = SKP_DIV32_16( Fs_Hz_in, 100 );

        
	    Fs_Hz_in  = SKP_RSHIFT( Fs_Hz_in,  S->nPreDownsamplers  );
	    Fs_Hz_out = SKP_RSHIFT( Fs_Hz_out, S->nPostUpsamplers  );
    }
#endif

    
    
    S->batchSize = SKP_DIV32_16( Fs_Hz_in, 100 );
    if( ( SKP_MUL( S->batchSize, 100 ) != Fs_Hz_in ) || ( Fs_Hz_in % 100 != 0 ) ) {
        
        cycleLen = SKP_DIV32( Fs_Hz_in, gcd( Fs_Hz_in, Fs_Hz_out ) );
        cyclesPerBatch = SKP_DIV32( RESAMPLER_MAX_BATCH_SIZE_IN, cycleLen );
        if( cyclesPerBatch == 0 ) {
            
            S->batchSize = RESAMPLER_MAX_BATCH_SIZE_IN;
            SKP_assert( 0 );
        } else {
            S->batchSize = SKP_MUL( cyclesPerBatch, cycleLen );
        }
    }


	
    if( Fs_Hz_out > Fs_Hz_in ) {
        
        if( Fs_Hz_out == SKP_MUL( Fs_Hz_in, 2 ) ) {                             
            
    	    S->resampler_function = SKP_Silk_resampler_private_up2_HQ_wrapper;
        } else {
	        
	        S->resampler_function = SKP_Silk_resampler_private_IIR_FIR;
            up2 = 1;
            if( Fs_Hz_in > 24000 ) {
                
                S->up2_function = SKP_Silk_resampler_up2;
            } else {
                
                S->up2_function = SKP_Silk_resampler_private_up2_HQ;
            }
        }
    } else if ( Fs_Hz_out < Fs_Hz_in ) {
        
        if( SKP_MUL( Fs_Hz_out, 4 ) == SKP_MUL( Fs_Hz_in, 3 ) ) {               
    	    S->FIR_Fracs = 3;
    	    S->Coefs = SKP_Silk_Resampler_3_4_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_down_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 3 ) == SKP_MUL( Fs_Hz_in, 2 ) ) {        
    	    S->FIR_Fracs = 2;
    	    S->Coefs = SKP_Silk_Resampler_2_3_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_down_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 2 ) == Fs_Hz_in ) {                      
    	    S->FIR_Fracs = 1;
    	    S->Coefs = SKP_Silk_Resampler_1_2_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_down_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 8 ) == SKP_MUL( Fs_Hz_in, 3 ) ) {        
    	    S->FIR_Fracs = 3;
    	    S->Coefs = SKP_Silk_Resampler_3_8_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_down_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 3 ) == Fs_Hz_in ) {                      
    	    S->FIR_Fracs = 1;
    	    S->Coefs = SKP_Silk_Resampler_1_3_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_down_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 4 ) == Fs_Hz_in ) {                      
    	    S->FIR_Fracs = 1;
            down2 = 1;
    	    S->Coefs = SKP_Silk_Resampler_1_2_COEFS;
            S->resampler_function = SKP_Silk_resampler_private_down_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 6 ) == Fs_Hz_in ) {                      
    	    S->FIR_Fracs = 1;
            down2 = 1;
    	    S->Coefs = SKP_Silk_Resampler_1_3_COEFS;
            S->resampler_function = SKP_Silk_resampler_private_down_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 441 ) == SKP_MUL( Fs_Hz_in, 80 ) ) {     
    	    S->Coefs = SKP_Silk_Resampler_80_441_ARMA4_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_IIR_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 441 ) == SKP_MUL( Fs_Hz_in, 120 ) ) {    
    	    S->Coefs = SKP_Silk_Resampler_120_441_ARMA4_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_IIR_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 441 ) == SKP_MUL( Fs_Hz_in, 160 ) ) {    
    	    S->Coefs = SKP_Silk_Resampler_160_441_ARMA4_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_IIR_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 441 ) == SKP_MUL( Fs_Hz_in, 240 ) ) {    
    	    S->Coefs = SKP_Silk_Resampler_240_441_ARMA4_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_IIR_FIR;
        } else if( SKP_MUL( Fs_Hz_out, 441 ) == SKP_MUL( Fs_Hz_in, 320 ) ) {    
    	    S->Coefs = SKP_Silk_Resampler_320_441_ARMA4_COEFS;
    	    S->resampler_function = SKP_Silk_resampler_private_IIR_FIR;
        } else {
	        
	        S->resampler_function = SKP_Silk_resampler_private_IIR_FIR;
            up2 = 1;
            if( Fs_Hz_in > 24000 ) {
                
                S->up2_function = SKP_Silk_resampler_up2;
            } else {
                
                S->up2_function = SKP_Silk_resampler_private_up2_HQ;
            }
        }
    } else {
        
        S->resampler_function = SKP_Silk_resampler_private_copy;
    }

    S->input2x = up2 | down2;

    
    S->invRatio_Q16 = SKP_LSHIFT32( SKP_DIV32( SKP_LSHIFT32( Fs_Hz_in, 14 + up2 - down2 ), Fs_Hz_out ), 2 );
    
    while( SKP_SMULWW( S->invRatio_Q16, SKP_LSHIFT32( Fs_Hz_out, down2 ) ) < SKP_LSHIFT32( Fs_Hz_in, up2 ) ) {
        S->invRatio_Q16++;
    }

	S->magic_number = 123456789;

	return 0;
}


SKP_int SKP_Silk_resampler_clear( 
	SKP_Silk_resampler_state_struct	*S		    
)
{
	
	SKP_memset( S->sDown2, 0, sizeof( S->sDown2 ) );
	SKP_memset( S->sIIR,   0, sizeof( S->sIIR ) );
	SKP_memset( S->sFIR,   0, sizeof( S->sFIR ) );
#if RESAMPLER_SUPPORT_ABOVE_48KHZ
	SKP_memset( S->sDownPre, 0, sizeof( S->sDownPre ) );
	SKP_memset( S->sUpPost,  0, sizeof( S->sUpPost ) );
#endif
    return 0;
}


SKP_int SKP_Silk_resampler( 
	SKP_Silk_resampler_state_struct	*S,		    
	SKP_int16							out[],	    
	const SKP_int16						in[],	    
	SKP_int32							inLen	    
)
{
	
    if( S->magic_number != 123456789 ) {
        SKP_assert( 0 );
        return -1;
    }

#if RESAMPLER_SUPPORT_ABOVE_48KHZ
	if( S->nPreDownsamplers + S->nPostUpsamplers > 0 ) {
		
        SKP_int32       nSamplesIn, nSamplesOut;
		SKP_int16		in_buf[ 480 ], out_buf[ 480 ];

        while( inLen > 0 ) {
            
    		nSamplesIn = SKP_min( inLen, S->batchSizePrePost );
            nSamplesOut = SKP_SMULWB( S->ratio_Q16, nSamplesIn );

            SKP_assert( SKP_RSHIFT32( nSamplesIn,  S->nPreDownsamplers ) <= 480 );
            SKP_assert( SKP_RSHIFT32( nSamplesOut, S->nPostUpsamplers  ) <= 480 );

    		if( S->nPreDownsamplers > 0 ) {
                S->down_pre_function( S->sDownPre, in_buf, in, nSamplesIn );
    		    if( S->nPostUpsamplers > 0 ) {
            		S->resampler_function( S, out_buf, in_buf, SKP_RSHIFT32( nSamplesIn, S->nPreDownsamplers ) );
                    S->up_post_function( S->sUpPost, out, out_buf, SKP_RSHIFT32( nSamplesOut, S->nPostUpsamplers ) );
                } else {
            		S->resampler_function( S, out, in_buf, SKP_RSHIFT32( nSamplesIn, S->nPreDownsamplers ) );
                }
            } else {
        		S->resampler_function( S, out_buf, in, SKP_RSHIFT32( nSamplesIn, S->nPreDownsamplers ) );
                S->up_post_function( S->sUpPost, out, out_buf, SKP_RSHIFT32( nSamplesOut, S->nPostUpsamplers ) );
            }

    		in += nSamplesIn;
            out += nSamplesOut;
	    	inLen -= nSamplesIn;
        }
	} else 
#endif
	{
		
		S->resampler_function( S, out, in, inLen );
	}

	return 0;
}









#if (EMBEDDED_ARM<5) 

void SKP_Silk_resampler_down2(
    SKP_int32                           *S,         
    SKP_int16                           *out,       
    const SKP_int16                     *in,        
    SKP_int32                           inLen       
)
{
    SKP_int32 k, len2 = SKP_RSHIFT32( inLen, 1 );
    SKP_int32 in32, out32, Y, X;

    SKP_assert( SKP_Silk_resampler_down2_0 > 0 );
    SKP_assert( SKP_Silk_resampler_down2_1 < 0 );

    
    for( k = 0; k < len2; k++ ) {
        
        in32 = SKP_LSHIFT( (SKP_int32)in[ 2 * k ], 10 );

        
        Y      = SKP_SUB32( in32, S[ 0 ] );
        X      = SKP_SMLAWB( Y, Y, SKP_Silk_resampler_down2_1 );
        out32  = SKP_ADD32( S[ 0 ], X );
        S[ 0 ] = SKP_ADD32( in32, X );

        
        in32 = SKP_LSHIFT( (SKP_int32)in[ 2 * k + 1 ], 10 );

        
        Y      = SKP_SUB32( in32, S[ 1 ] );
        X      = SKP_SMULWB( Y, SKP_Silk_resampler_down2_0 );
        out32  = SKP_ADD32( out32, S[ 1 ] );
        out32  = SKP_ADD32( out32, X );
        S[ 1 ] = SKP_ADD32( in32, X );

        
        out[ k ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( out32, 11 ) );
    }
}
#endif









#define ORDER_FIR                   4


void SKP_Silk_resampler_down2_3(
    SKP_int32                           *S,         
    SKP_int16                           *out,       
    const SKP_int16                     *in,        
    SKP_int32                           inLen       
)
{
	SKP_int32 nSamplesIn, counter, res_Q6;
	SKP_int32 buf[ RESAMPLER_MAX_BATCH_SIZE_IN + ORDER_FIR ];
	SKP_int32 *buf_ptr;

		
	SKP_memcpy( buf, S, ORDER_FIR * sizeof( SKP_int32 ) );

	
	while( 1 ) {
		nSamplesIn = SKP_min( inLen, RESAMPLER_MAX_BATCH_SIZE_IN );

	    
	    SKP_Silk_resampler_private_AR2( &S[ ORDER_FIR ], &buf[ ORDER_FIR ], in, 
            SKP_Silk_Resampler_2_3_COEFS_LQ, nSamplesIn );

		
        buf_ptr = buf;
        counter = nSamplesIn;
        while( counter > 2 ) {
            
		    res_Q6 = SKP_SMULWB(         buf_ptr[ 0 ], SKP_Silk_Resampler_2_3_COEFS_LQ[ 2 ] );
		    res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 1 ], SKP_Silk_Resampler_2_3_COEFS_LQ[ 3 ] );
		    res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 2 ], SKP_Silk_Resampler_2_3_COEFS_LQ[ 5 ] );
		    res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 3 ], SKP_Silk_Resampler_2_3_COEFS_LQ[ 4 ] );

            
            *out++ = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( res_Q6, 6 ) );

		    res_Q6 = SKP_SMULWB(         buf_ptr[ 1 ], SKP_Silk_Resampler_2_3_COEFS_LQ[ 4 ] );
		    res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 2 ], SKP_Silk_Resampler_2_3_COEFS_LQ[ 5 ] );
		    res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 3 ], SKP_Silk_Resampler_2_3_COEFS_LQ[ 3 ] );
		    res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 4 ], SKP_Silk_Resampler_2_3_COEFS_LQ[ 2 ] );

            
            *out++ = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( res_Q6, 6 ) );

            buf_ptr += 3;
            counter -= 3;
        }

		in += nSamplesIn;
		inLen -= nSamplesIn;

		if( inLen > 0 ) {
			
			SKP_memcpy( buf, &buf[ nSamplesIn ], ORDER_FIR * sizeof( SKP_int32 ) );
		} else {
			break;
		}
	}

	
	SKP_memcpy( S, &buf[ nSamplesIn ], ORDER_FIR * sizeof( SKP_int32 ) );
}









#define ORDER_FIR                   6


void SKP_Silk_resampler_down3(
    SKP_int32                           *S,         
    SKP_int16                           *out,       
    const SKP_int16                     *in,        
    SKP_int32                           inLen       
)
{
	SKP_int32 nSamplesIn, counter, res_Q6;
	SKP_int32 buf[ RESAMPLER_MAX_BATCH_SIZE_IN + ORDER_FIR ];
	SKP_int32 *buf_ptr;

		
	SKP_memcpy( buf, S, ORDER_FIR * sizeof( SKP_int32 ) );

	
	while( 1 ) {
		nSamplesIn = SKP_min( inLen, RESAMPLER_MAX_BATCH_SIZE_IN );

	    
	    SKP_Silk_resampler_private_AR2( &S[ ORDER_FIR ], &buf[ ORDER_FIR ], in, 
            SKP_Silk_Resampler_1_3_COEFS_LQ, nSamplesIn );

		
        buf_ptr = buf;
        counter = nSamplesIn;
        while( counter > 2 ) {
            
            res_Q6 = SKP_SMULWB(         SKP_ADD32( buf_ptr[ 0 ], buf_ptr[ 5 ] ), SKP_Silk_Resampler_1_3_COEFS_LQ[ 2 ] );
            res_Q6 = SKP_SMLAWB( res_Q6, SKP_ADD32( buf_ptr[ 1 ], buf_ptr[ 4 ] ), SKP_Silk_Resampler_1_3_COEFS_LQ[ 3 ] );
            res_Q6 = SKP_SMLAWB( res_Q6, SKP_ADD32( buf_ptr[ 2 ], buf_ptr[ 3 ] ), SKP_Silk_Resampler_1_3_COEFS_LQ[ 4 ] );

            
            *out++ = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( res_Q6, 6 ) );

            buf_ptr += 3;
            counter -= 3;
        }

		in += nSamplesIn;
		inLen -= nSamplesIn;

		if( inLen > 0 ) {
			
			SKP_memcpy( buf, &buf[ nSamplesIn ], ORDER_FIR * sizeof( SKP_int32 ) );
		} else {
			break;
		}
	}

	
	SKP_memcpy( S, &buf[ nSamplesIn ], ORDER_FIR * sizeof( SKP_int32 ) );
}









#if (EMBEDDED_ARM<5)  

void SKP_Silk_resampler_private_AR2(
	SKP_int32					    S[],		    
	SKP_int32					    out_Q8[],		
	const SKP_int16				    in[],			
	const SKP_int16				    A_Q14[],		
	SKP_int32				        len				
)
{
	SKP_int32	k;
	SKP_int32	out32;

	for( k = 0; k < len; k++ ) {
		out32       = SKP_ADD_LSHIFT32( S[ 0 ], (SKP_int32)in[ k ], 8 );
		out_Q8[ k ] = out32;
		out32       = SKP_LSHIFT( out32, 2 );
		S[ 0 ]      = SKP_SMLAWB( S[ 1 ], out32, A_Q14[ 0 ] );
		S[ 1 ]      = SKP_SMULWB( out32, A_Q14[ 1 ] );
	}
}
#endif















#if (EMBEDDED_ARM<5) 
void SKP_Silk_resampler_private_ARMA4(
	SKP_int32					    S[],		    
	SKP_int16					    out[],		    
	const SKP_int16				    in[],			
	const SKP_int16				    Coef[],		    
	SKP_int32				        len				
)
{
	SKP_int32 k;
	SKP_int32 in_Q8, out1_Q8, out2_Q8, X;

	for( k = 0; k < len; k++ ) {
        in_Q8  = SKP_LSHIFT32( (SKP_int32)in[ k ], 8 );

        
        out1_Q8 = SKP_ADD_LSHIFT32( in_Q8,   S[ 0 ], 2 );
        out2_Q8 = SKP_ADD_LSHIFT32( out1_Q8, S[ 2 ], 2 );

        
        X      = SKP_SMLAWB( S[ 1 ], in_Q8,   Coef[ 0 ] );
        S[ 0 ] = SKP_SMLAWB( X,      out1_Q8, Coef[ 2 ] );

        X      = SKP_SMLAWB( S[ 3 ], out1_Q8, Coef[ 1 ] );
        S[ 2 ] = SKP_SMLAWB( X,      out2_Q8, Coef[ 4 ] );

        S[ 1 ] = SKP_SMLAWB( SKP_RSHIFT32( in_Q8,   2 ), out1_Q8, Coef[ 3 ] );
        S[ 3 ] = SKP_SMLAWB( SKP_RSHIFT32( out1_Q8, 2 ), out2_Q8, Coef[ 5 ] );

        
        out[ k ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT32( SKP_SMLAWB( 128, out2_Q8, Coef[ 6 ] ), 8 ) );
	}
}
#endif









#if EMBEDDED_ARM<5
SKP_INLINE SKP_int16 *SKP_Silk_resampler_private_IIR_FIR_INTERPOL( 
			SKP_int16 * out, SKP_int16 * buf, SKP_int32 max_index_Q16 , SKP_int32 index_increment_Q16 ){
	SKP_int32 index_Q16, res_Q15;
	SKP_int16 *buf_ptr;
	SKP_int32 table_index;
	
	for( index_Q16 = 0; index_Q16 < max_index_Q16; index_Q16 += index_increment_Q16 ) {
        table_index = SKP_SMULWB( index_Q16 & 0xFFFF, 144 );
        buf_ptr = &buf[ index_Q16 >> 16 ];
            
        res_Q15 = SKP_SMULBB(          buf_ptr[ 0 ], SKP_Silk_resampler_frac_FIR_144[       table_index ][ 0 ] );
        res_Q15 = SKP_SMLABB( res_Q15, buf_ptr[ 1 ], SKP_Silk_resampler_frac_FIR_144[       table_index ][ 1 ] );
        res_Q15 = SKP_SMLABB( res_Q15, buf_ptr[ 2 ], SKP_Silk_resampler_frac_FIR_144[       table_index ][ 2 ] );
        res_Q15 = SKP_SMLABB( res_Q15, buf_ptr[ 3 ], SKP_Silk_resampler_frac_FIR_144[ 143 - table_index ][ 2 ] );
        res_Q15 = SKP_SMLABB( res_Q15, buf_ptr[ 4 ], SKP_Silk_resampler_frac_FIR_144[ 143 - table_index ][ 1 ] );
        res_Q15 = SKP_SMLABB( res_Q15, buf_ptr[ 5 ], SKP_Silk_resampler_frac_FIR_144[ 143 - table_index ][ 0 ] );          
		*out++ = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( res_Q15, 15 ) );
	}
	return out;	
}
#else
extern SKP_int16 *SKP_Silk_resampler_private_IIR_FIR_INTERPOL( 
			SKP_int16 * out, SKP_int16 * buf, SKP_int32 max_index_Q16 , SKP_int32 index_increment_Q16 );
#endif

void SKP_Silk_resampler_private_IIR_FIR(
	void	                        *SS,		    
	SKP_int16						out[],		    
	const SKP_int16					in[],		    
	SKP_int32					    inLen		    
)
{
    SKP_Silk_resampler_state_struct *S = (SKP_Silk_resampler_state_struct *)SS;
	SKP_int32 nSamplesIn;
	SKP_int32 max_index_Q16, index_increment_Q16;
	SKP_int16 buf[ 2 * RESAMPLER_MAX_BATCH_SIZE_IN + RESAMPLER_ORDER_FIR_144 ];
    

		
	SKP_memcpy( buf, S->sFIR, RESAMPLER_ORDER_FIR_144 * sizeof( SKP_int32 ) );

	
    index_increment_Q16 = S->invRatio_Q16;
	while( 1 ) {
		nSamplesIn = SKP_min( inLen, S->batchSize );

        if( S->input2x == 1 ) {
		    
            S->up2_function( S->sIIR, &buf[ RESAMPLER_ORDER_FIR_144 ], in, nSamplesIn );
        } else {
		    
            SKP_Silk_resampler_private_ARMA4( S->sIIR, &buf[ RESAMPLER_ORDER_FIR_144 ], in, S->Coefs, nSamplesIn );
        }

        max_index_Q16 = SKP_LSHIFT32( nSamplesIn, 16 + S->input2x );         
		out = SKP_Silk_resampler_private_IIR_FIR_INTERPOL(out, buf, max_index_Q16, index_increment_Q16);    
		in += nSamplesIn;
		inLen -= nSamplesIn;

		if( inLen > 0 ) {
			
			SKP_memcpy( buf, &buf[ nSamplesIn << S->input2x ], RESAMPLER_ORDER_FIR_144 * sizeof( SKP_int32 ) );
		} else {
			break;
		}
	}

	
	SKP_memcpy( S->sFIR, &buf[nSamplesIn << S->input2x ], RESAMPLER_ORDER_FIR_144 * sizeof( SKP_int32 ) );
}











void SKP_Silk_resampler_private_copy(
	void	                        *SS,		    
	SKP_int16						out[],		    
	const SKP_int16					in[],		    
	SKP_int32					    inLen		    
)
{
    SKP_memcpy( out, in, inLen * sizeof( SKP_int16 ) );
}










void SKP_Silk_resampler_private_down4(
    SKP_int32                       *S,             
    SKP_int16                       *out,           
    const SKP_int16                 *in,            
    SKP_int32                       inLen           
)
{
    SKP_int32 k, len4 = SKP_RSHIFT32( inLen, 2 );
    SKP_int32 in32, out32, Y, X;

    SKP_assert( SKP_Silk_resampler_down2_0 > 0 );
    SKP_assert( SKP_Silk_resampler_down2_1 < 0 );

    
    for( k = 0; k < len4; k++ ) {
        
        in32 = SKP_LSHIFT( SKP_ADD32( (SKP_int32)in[ 4 * k ], (SKP_int32)in[ 4 * k + 1 ] ), 9 );

        
        Y      = SKP_SUB32( in32, S[ 0 ] );
        X      = SKP_SMLAWB( Y, Y, SKP_Silk_resampler_down2_1 );
        out32  = SKP_ADD32( S[ 0 ], X );
        S[ 0 ] = SKP_ADD32( in32, X );

        
        in32 = SKP_LSHIFT( SKP_ADD32( (SKP_int32)in[ 4 * k + 2 ], (SKP_int32)in[ 4 * k + 3 ] ), 9 );

        
        Y      = SKP_SUB32( in32, S[ 1 ] );
        X      = SKP_SMULWB( Y, SKP_Silk_resampler_down2_0 );
        out32  = SKP_ADD32( out32, S[ 1 ] );
        out32  = SKP_ADD32( out32, X );
        S[ 1 ] = SKP_ADD32( in32, X );

        
        out[ k ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( out32, 11 ) );
    }
}








#if EMBEDDED_ARM<5
SKP_INLINE SKP_int16 *SKP_Silk_resampler_private_down_FIR_INTERPOL0(
	SKP_int16 *out, SKP_int32 *buf2, const SKP_int16 *FIR_Coefs, SKP_int32 max_index_Q16, SKP_int32 index_increment_Q16){
	
	SKP_int32 index_Q16, res_Q6;
	SKP_int32 *buf_ptr;
	for( index_Q16 = 0; index_Q16 < max_index_Q16; index_Q16 += index_increment_Q16 ) {
		
		buf_ptr = buf2 + SKP_RSHIFT( index_Q16, 16 );

		
		res_Q6 = SKP_SMULWB(         SKP_ADD32( buf_ptr[ 0 ], buf_ptr[ 11 ] ), FIR_Coefs[ 0 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, SKP_ADD32( buf_ptr[ 1 ], buf_ptr[ 10 ] ), FIR_Coefs[ 1 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, SKP_ADD32( buf_ptr[ 2 ], buf_ptr[  9 ] ), FIR_Coefs[ 2 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, SKP_ADD32( buf_ptr[ 3 ], buf_ptr[  8 ] ), FIR_Coefs[ 3 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, SKP_ADD32( buf_ptr[ 4 ], buf_ptr[  7 ] ), FIR_Coefs[ 4 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, SKP_ADD32( buf_ptr[ 5 ], buf_ptr[  6 ] ), FIR_Coefs[ 5 ] );

			    
		*out++ = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( res_Q6, 6 ) );
	}
	return out;
}

SKP_INLINE SKP_int16 *SKP_Silk_resampler_private_down_FIR_INTERPOL1(
	SKP_int16 *out, SKP_int32 *buf2, const SKP_int16 *FIR_Coefs, SKP_int32 max_index_Q16, SKP_int32 index_increment_Q16, SKP_int32 FIR_Fracs){
	
	SKP_int32 index_Q16, res_Q6;
	SKP_int32 *buf_ptr;
	SKP_int32 interpol_ind;
	const SKP_int16 *interpol_ptr;
	for( index_Q16 = 0; index_Q16 < max_index_Q16; index_Q16 += index_increment_Q16 ) {
		
		buf_ptr = buf2 + SKP_RSHIFT( index_Q16, 16 );

		
		interpol_ind = SKP_SMULWB( index_Q16 & 0xFFFF, FIR_Fracs );

		
		interpol_ptr = &FIR_Coefs[ RESAMPLER_DOWN_ORDER_FIR / 2 * interpol_ind ];
		res_Q6 = SKP_SMULWB(         buf_ptr[ 0 ], interpol_ptr[ 0 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 1 ], interpol_ptr[ 1 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 2 ], interpol_ptr[ 2 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 3 ], interpol_ptr[ 3 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 4 ], interpol_ptr[ 4 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 5 ], interpol_ptr[ 5 ] );
		interpol_ptr = &FIR_Coefs[ RESAMPLER_DOWN_ORDER_FIR / 2 * ( FIR_Fracs - 1 - interpol_ind ) ];
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 11 ], interpol_ptr[ 0 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[ 10 ], interpol_ptr[ 1 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[  9 ], interpol_ptr[ 2 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[  8 ], interpol_ptr[ 3 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[  7 ], interpol_ptr[ 4 ] );
		res_Q6 = SKP_SMLAWB( res_Q6, buf_ptr[  6 ], interpol_ptr[ 5 ] );

		
		*out++ = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( res_Q6, 6 ) );
	}
	return out;
}

#else
extern SKP_int16 *SKP_Silk_resampler_private_down_FIR_INTERPOL0(
	SKP_int16 *out, SKP_int32 *buf2, const SKP_int16 *FIR_Coefs, SKP_int32 max_index_Q16, SKP_int32 index_increment_Q16);
extern SKP_int16 *SKP_Silk_resampler_private_down_FIR_INTERPOL1(
	SKP_int16 *out, SKP_int32 *buf2, const SKP_int16 *FIR_Coefs, SKP_int32 max_index_Q16, SKP_int32 index_increment_Q16, SKP_int32 FIR_Fracs);	
#endif


void SKP_Silk_resampler_private_down_FIR(
	void	                        *SS,		    
	SKP_int16						out[],		    
	const SKP_int16					in[],		    
	SKP_int32					    inLen		    
)
{
    SKP_Silk_resampler_state_struct *S = (SKP_Silk_resampler_state_struct *)SS;
	SKP_int32 nSamplesIn;
	SKP_int32 max_index_Q16, index_increment_Q16;
	SKP_int16 buf1[ RESAMPLER_MAX_BATCH_SIZE_IN / 2 ];
	SKP_int32 buf2[ RESAMPLER_MAX_BATCH_SIZE_IN + RESAMPLER_DOWN_ORDER_FIR ];
	const SKP_int16 *FIR_Coefs;

		
	SKP_memcpy( buf2, S->sFIR, RESAMPLER_DOWN_ORDER_FIR * sizeof( SKP_int32 ) );

    FIR_Coefs = &S->Coefs[ 2 ];

	
    index_increment_Q16 = S->invRatio_Q16;
	while( 1 ) {
		nSamplesIn = SKP_min( inLen, S->batchSize );

        if( S->input2x == 1 ) {
            
            SKP_Silk_resampler_down2( S->sDown2, buf1, in, nSamplesIn );

            nSamplesIn = SKP_RSHIFT32( nSamplesIn, 1 );

		    
		    SKP_Silk_resampler_private_AR2( S->sIIR, &buf2[ RESAMPLER_DOWN_ORDER_FIR ], buf1, S->Coefs, nSamplesIn );
        } else {
		    
		    SKP_Silk_resampler_private_AR2( S->sIIR, &buf2[ RESAMPLER_DOWN_ORDER_FIR ], in, S->Coefs, nSamplesIn );
        }

        max_index_Q16 = SKP_LSHIFT32( nSamplesIn, 16 );

		
        if( S->FIR_Fracs == 1 ) {
    		out = SKP_Silk_resampler_private_down_FIR_INTERPOL0(out, buf2, FIR_Coefs, max_index_Q16, index_increment_Q16);
        } else {
    		out = SKP_Silk_resampler_private_down_FIR_INTERPOL1(out, buf2, FIR_Coefs, max_index_Q16, index_increment_Q16, S->FIR_Fracs);
        }
        
		in += nSamplesIn << S->input2x;
		inLen -= nSamplesIn << S->input2x;

		if( inLen > S->input2x ) {
			
			SKP_memcpy( buf2, &buf2[ nSamplesIn ], RESAMPLER_DOWN_ORDER_FIR * sizeof( SKP_int32 ) );
		} else {
			break;
		}
	}

	
	SKP_memcpy( S->sFIR, &buf2[ nSamplesIn ], RESAMPLER_DOWN_ORDER_FIR * sizeof( SKP_int32 ) );
}













#if (EMBEDDED_ARM<5) 
void SKP_Silk_resampler_private_up2_HQ(
	SKP_int32	                    *S,			    
    SKP_int16                       *out,           
    const SKP_int16                 *in,            
    SKP_int32                       len             
)
{
    SKP_int32 k;
    SKP_int32 in32, out32_1, out32_2, Y, X;

    SKP_assert( SKP_Silk_resampler_up2_hq_0[ 0 ] > 0 );
    SKP_assert( SKP_Silk_resampler_up2_hq_0[ 1 ] < 0 );
    SKP_assert( SKP_Silk_resampler_up2_hq_1[ 0 ] > 0 );
    SKP_assert( SKP_Silk_resampler_up2_hq_1[ 1 ] < 0 );
    
    
    for( k = 0; k < len; k++ ) {
        
        in32 = SKP_LSHIFT( (SKP_int32)in[ k ], 10 );

        
        Y       = SKP_SUB32( in32, S[ 0 ] );
        X       = SKP_SMULWB( Y, SKP_Silk_resampler_up2_hq_0[ 0 ] );
        out32_1 = SKP_ADD32( S[ 0 ], X );
        S[ 0 ]  = SKP_ADD32( in32, X );

        
        Y       = SKP_SUB32( out32_1, S[ 1 ] );
        X       = SKP_SMLAWB( Y, Y, SKP_Silk_resampler_up2_hq_0[ 1 ] );
        out32_2 = SKP_ADD32( S[ 1 ], X );
        S[ 1 ]  = SKP_ADD32( out32_1, X );

        
        out32_2 = SKP_SMLAWB( out32_2, S[ 5 ], SKP_Silk_resampler_up2_hq_notch[ 2 ] );
        out32_2 = SKP_SMLAWB( out32_2, S[ 4 ], SKP_Silk_resampler_up2_hq_notch[ 1 ] );
        out32_1 = SKP_SMLAWB( out32_2, S[ 4 ], SKP_Silk_resampler_up2_hq_notch[ 0 ] );
        S[ 5 ]  = SKP_SUB32(  out32_2, S[ 5 ] );
        
        
        out[ 2 * k ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT32( 
            SKP_SMLAWB( 256, out32_1, SKP_Silk_resampler_up2_hq_notch[ 3 ] ), 9 ) );

        
        Y       = SKP_SUB32( in32, S[ 2 ] );
        X       = SKP_SMULWB( Y, SKP_Silk_resampler_up2_hq_1[ 0 ] );
        out32_1 = SKP_ADD32( S[ 2 ], X );
        S[ 2 ]  = SKP_ADD32( in32, X );

        
        Y       = SKP_SUB32( out32_1, S[ 3 ] );
        X       = SKP_SMLAWB( Y, Y, SKP_Silk_resampler_up2_hq_1[ 1 ] );
        out32_2 = SKP_ADD32( S[ 3 ], X );
        S[ 3 ]  = SKP_ADD32( out32_1, X );

        
        out32_2 = SKP_SMLAWB( out32_2, S[ 4 ], SKP_Silk_resampler_up2_hq_notch[ 2 ] );
        out32_2 = SKP_SMLAWB( out32_2, S[ 5 ], SKP_Silk_resampler_up2_hq_notch[ 1 ] );
        out32_1 = SKP_SMLAWB( out32_2, S[ 5 ], SKP_Silk_resampler_up2_hq_notch[ 0 ] );
        S[ 4 ]  = SKP_SUB32(  out32_2, S[ 4 ] );
        
        
        out[ 2 * k + 1 ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT32( 
            SKP_SMLAWB( 256, out32_1, SKP_Silk_resampler_up2_hq_notch[ 3 ] ), 9 ) );
    }
}
#endif


void SKP_Silk_resampler_private_up2_HQ_wrapper(
	void	                        *SS,		    
    SKP_int16                       *out,           
    const SKP_int16                 *in,            
    SKP_int32                       len             
)
{
    SKP_Silk_resampler_state_struct *S = (SKP_Silk_resampler_state_struct *)SS;
    SKP_Silk_resampler_private_up2_HQ( S->sIIR, out, in, len );
}










void SKP_Silk_resampler_private_up4(
    SKP_int32                       *S,             
    SKP_int16                       *out,           
    const SKP_int16                 *in,            
    SKP_int32                       len             
)
{
    SKP_int32 k;
    SKP_int32 in32, out32, Y, X;
    SKP_int16 out16;

    SKP_assert( SKP_Silk_resampler_up2_lq_0 > 0 );
    SKP_assert( SKP_Silk_resampler_up2_lq_1 < 0 );

    
    for( k = 0; k < len; k++ ) {
        
        in32 = SKP_LSHIFT( (SKP_int32)in[ k ], 10 );

        
        Y      = SKP_SUB32( in32, S[ 0 ] );
        X      = SKP_SMULWB( Y, SKP_Silk_resampler_up2_lq_0 );
        out32  = SKP_ADD32( S[ 0 ], X );
        S[ 0 ] = SKP_ADD32( in32, X );

        
        out16 = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( out32, 10 ) );
        out[ 4 * k ]     = out16;
        out[ 4 * k + 1 ] = out16;

        
        Y      = SKP_SUB32( in32, S[ 1 ] );
        X      = SKP_SMLAWB( Y, Y, SKP_Silk_resampler_up2_lq_1 );
        out32  = SKP_ADD32( S[ 1 ], X );
        S[ 1 ] = SKP_ADD32( in32, X );

        
        out16 = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( out32, 10 ) );
        out[ 4 * k + 2 ] = out16;
        out[ 4 * k + 3 ] = out16;
    }
}









const SKP_int16 SKP_Silk_resampler_down2_0 = 9872;
const SKP_int16 SKP_Silk_resampler_down2_1 = 39809 - 65536;


const SKP_int16 SKP_Silk_resampler_up2_lq_0 = 8102;
const SKP_int16 SKP_Silk_resampler_up2_lq_1 = 36783 - 65536;


const SKP_int16 SKP_Silk_resampler_up2_hq_0[ 2 ] = {  4280, 33727 - 65536 };
const SKP_int16 SKP_Silk_resampler_up2_hq_1[ 2 ] = { 16295, 54015 - 65536 };



const SKP_int16 SKP_Silk_resampler_up2_hq_notch[ 4 ] = { 7864,  -3604,  13107,  28508 };



SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_3_4_COEFS[ 2 + 3 * RESAMPLER_DOWN_ORDER_FIR / 2 ] = {
	-18249, -12532,
	   -97,    284,   -495,    309,  10268,  20317,
	   -94,    156,    -48,   -720,   5984,  18278,
	   -45,     -4,    237,   -847,   2540,  14662,
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_2_3_COEFS[ 2 + 2 * RESAMPLER_DOWN_ORDER_FIR / 2 ] = {
	-11891, -12486,
	    20,    211,   -657,    688,   8423,  15911,
	   -44,    197,   -152,   -653,   3855,  13015,
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_1_2_COEFS[ 2 + RESAMPLER_DOWN_ORDER_FIR / 2 ] = {
	  2415, -13101,
	   158,   -295,   -400,   1265,   4832,   7968,
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_3_8_COEFS[ 2 + 3 * RESAMPLER_DOWN_ORDER_FIR / 2 ] = {
	 13270, -13738,
	  -294,   -123,    747,   2043,   3339,   3995,
	  -151,   -311,    414,   1583,   2947,   3877,
	   -33,   -389,    143,   1141,   2503,   3653,
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_1_3_COEFS[ 2 + RESAMPLER_DOWN_ORDER_FIR / 2 ] = {
	 16643, -14000,
	  -331,     19,    581,   1421,   2290,   2845,
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_2_3_COEFS_LQ[ 2 + 2 * 2 ] = {
	 -2797,  -6507,
	  4697,  10739,
	  1567,   8276,
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_1_3_COEFS_LQ[ 2 + 3 ] = {
	 16777,  -9792,
	   890,   1614,   2148,
};





SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_320_441_ARMA4_COEFS[ 7 ] = {
	 31454,  24746,  -9706,  -3386, -17911, -13243,  24797
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_240_441_ARMA4_COEFS[ 7 ] = {
	 28721,  11254,   3189,  -2546,  -1495, -12618,  11562
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_160_441_ARMA4_COEFS[ 7 ] = {
	 23492,  -6457,  14358,  -4856,  14654, -13008,   4456
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_120_441_ARMA4_COEFS[ 7 ] = {
	 19311, -15569,  19489,  -6950,  21441, -13559,   2370
};

SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_Resampler_80_441_ARMA4_COEFS[ 7 ] = {
	 13248, -23849,  24126,  -9486,  26806, -14286,   1065
};


SKP_DWORD_ALIGN const SKP_int16 SKP_Silk_resampler_frac_FIR_144[ 144 ][ RESAMPLER_ORDER_FIR_144 / 2 ] = {
	{ -647,  1884, 30078},
	{ -625,  1736, 30044},
	{ -603,  1591, 30005},
	{ -581,  1448, 29963},
	{ -559,  1308, 29917},
	{ -537,  1169, 29867},
	{ -515,  1032, 29813},
	{ -494,   898, 29755},
	{ -473,   766, 29693},
	{ -452,   636, 29627},
	{ -431,   508, 29558},
	{ -410,   383, 29484},
	{ -390,   260, 29407},
	{ -369,   139, 29327},
	{ -349,    20, 29242},
	{ -330,   -97, 29154},
	{ -310,  -211, 29062},
	{ -291,  -324, 28967},
	{ -271,  -434, 28868},
	{ -253,  -542, 28765},
	{ -234,  -647, 28659},
	{ -215,  -751, 28550},
	{ -197,  -852, 28436},
	{ -179,  -951, 28320},
	{ -162, -1048, 28200},
	{ -144, -1143, 28077},
	{ -127, -1235, 27950},
	{ -110, -1326, 27820},
	{  -94, -1414, 27687},
	{  -77, -1500, 27550},
	{  -61, -1584, 27410},
	{  -45, -1665, 27268},
	{  -30, -1745, 27122},
	{  -15, -1822, 26972},
	{    0, -1897, 26820},
	{   15, -1970, 26665},
	{   29, -2041, 26507},
	{   44, -2110, 26346},
	{   57, -2177, 26182},
	{   71, -2242, 26015},
	{   84, -2305, 25845},
	{   97, -2365, 25673},
	{  110, -2424, 25498},
	{  122, -2480, 25320},
	{  134, -2534, 25140},
	{  146, -2587, 24956},
	{  157, -2637, 24771},
	{  168, -2685, 24583},
	{  179, -2732, 24392},
	{  190, -2776, 24199},
	{  200, -2819, 24003},
	{  210, -2859, 23805},
	{  220, -2898, 23605},
	{  229, -2934, 23403},
	{  238, -2969, 23198},
	{  247, -3002, 22992},
	{  255, -3033, 22783},
	{  263, -3062, 22572},
	{  271, -3089, 22359},
	{  279, -3114, 22144},
	{  286, -3138, 21927},
	{  293, -3160, 21709},
	{  300, -3180, 21488},
	{  306, -3198, 21266},
	{  312, -3215, 21042},
	{  318, -3229, 20816},
	{  323, -3242, 20589},
	{  328, -3254, 20360},
	{  333, -3263, 20130},
	{  338, -3272, 19898},
	{  342, -3278, 19665},
	{  346, -3283, 19430},
	{  350, -3286, 19194},
	{  353, -3288, 18957},
	{  356, -3288, 18718},
	{  359, -3286, 18478},
	{  362, -3283, 18238},
	{  364, -3279, 17996},
	{  366, -3273, 17753},
	{  368, -3266, 17509},
	{  369, -3257, 17264},
	{  371, -3247, 17018},
	{  372, -3235, 16772},
	{  372, -3222, 16525},
	{  373, -3208, 16277},
	{  373, -3192, 16028},
	{  373, -3175, 15779},
	{  373, -3157, 15529},
	{  372, -3138, 15279},
	{  371, -3117, 15028},
	{  370, -3095, 14777},
	{  369, -3072, 14526},
	{  368, -3048, 14274},
	{  366, -3022, 14022},
	{  364, -2996, 13770},
	{  362, -2968, 13517},
	{  359, -2940, 13265},
	{  357, -2910, 13012},
	{  354, -2880, 12760},
	{  351, -2848, 12508},
	{  348, -2815, 12255},
	{  344, -2782, 12003},
	{  341, -2747, 11751},
	{  337, -2712, 11500},
	{  333, -2676, 11248},
	{  328, -2639, 10997},
	{  324, -2601, 10747},
	{  320, -2562, 10497},
	{  315, -2523, 10247},
	{  310, -2482,  9998},
	{  305, -2442,  9750},
	{  300, -2400,  9502},
	{  294, -2358,  9255},
	{  289, -2315,  9009},
	{  283, -2271,  8763},
	{  277, -2227,  8519},
	{  271, -2182,  8275},
	{  265, -2137,  8032},
	{  259, -2091,  7791},
	{  252, -2045,  7550},
	{  246, -1998,  7311},
	{  239, -1951,  7072},
	{  232, -1904,  6835},
	{  226, -1856,  6599},
	{  219, -1807,  6364},
	{  212, -1758,  6131},
	{  204, -1709,  5899},
	{  197, -1660,  5668},
	{  190, -1611,  5439},
	{  183, -1561,  5212},
	{  175, -1511,  4986},
	{  168, -1460,  4761},
	{  160, -1410,  4538},
	{  152, -1359,  4317},
	{  145, -1309,  4098},
	{  137, -1258,  3880},
	{  129, -1207,  3664},
	{  121, -1156,  3450},
	{  113, -1105,  3238},
	{  105, -1054,  3028},
	{   97, -1003,  2820},
	{   89,  -952,  2614},
	{   81,  -901,  2409},
	{   73,  -851,  2207},
};










#if EMBEDDED_ARM<5
void SKP_Silk_resampler_up2(
    SKP_int32                           *S,         
    SKP_int16                           *out,       
    const SKP_int16                     *in,        
    SKP_int32                           len         
)
{
    SKP_int32 k;
    SKP_int32 in32, out32, Y, X;

    SKP_assert( SKP_Silk_resampler_up2_lq_0 > 0 );
    SKP_assert( SKP_Silk_resampler_up2_lq_1 < 0 );
    
    for( k = 0; k < len; k++ ) {
        
        in32 = SKP_LSHIFT( (SKP_int32)in[ k ], 10 );

        
        Y      = SKP_SUB32( in32, S[ 0 ] );
        X      = SKP_SMULWB( Y, SKP_Silk_resampler_up2_lq_0 );
        out32  = SKP_ADD32( S[ 0 ], X );
        S[ 0 ] = SKP_ADD32( in32, X );

        
        out[ 2 * k ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( out32, 10 ) );

        
        Y      = SKP_SUB32( in32, S[ 1 ] );
        X      = SKP_SMLAWB( Y, Y, SKP_Silk_resampler_up2_lq_1 );
        out32  = SKP_ADD32( S[ 1 ], X );
        S[ 1 ] = SKP_ADD32( in32, X );

        
        out[ 2 * k + 1 ] = (SKP_int16)SKP_SAT16( SKP_RSHIFT_ROUND( out32, 10 ) );
    }
}
#endif







SKP_int32 SKP_Silk_residual_energy16_covar_FIX(
    const SKP_int16                 *c,                 
    const SKP_int32                 *wXX,               
    const SKP_int32                 *wXx,               
    SKP_int32                       wxx,                
    SKP_int                         D,                  
    SKP_int                         cQ                  
)
{
    SKP_int   i, j, lshifts, Qxtra;
    SKP_int32 c_max, w_max, tmp, tmp2, nrg;
    SKP_int   cn[ MAX_MATRIX_SIZE ]; 
    const SKP_int32 *pRow;

    
    SKP_assert( D >=  0 );
    SKP_assert( D <= 16 );
    SKP_assert( cQ >  0 );
    SKP_assert( cQ < 16 );

    lshifts = 16 - cQ;
    Qxtra = lshifts;

    c_max = 0;
    for( i = 0; i < D; i++ ) {
        c_max = SKP_max_32( c_max, SKP_abs( ( SKP_int32 )c[ i ] ) );
    }
    Qxtra = SKP_min_int( Qxtra, SKP_Silk_CLZ32( c_max ) - 17 );

    w_max = SKP_max_32( wXX[ 0 ], wXX[ D * D - 1 ] );
    Qxtra = SKP_min_int( Qxtra, SKP_Silk_CLZ32( SKP_MUL( D, SKP_RSHIFT( SKP_SMULWB( w_max, c_max ), 4 ) ) ) - 5 );
    Qxtra = SKP_max_int( Qxtra, 0 );
    for( i = 0; i < D; i++ ) {
        cn[ i ] = SKP_LSHIFT( ( SKP_int )c[ i ], Qxtra );
        SKP_assert( SKP_abs(cn[i]) <= ( SKP_int16_MAX + 1 ) ); 
    }
    lshifts -= Qxtra;

    
    tmp = 0;
    for( i = 0; i < D; i++ ) {
        tmp = SKP_SMLAWB( tmp, wXx[ i ], cn[ i ] );
    }
    nrg = SKP_RSHIFT( wxx, 1 + lshifts ) - tmp;                         

    
    tmp2 = 0;
    for( i = 0; i < D; i++ ) {
        tmp = 0;
        pRow = &wXX[ i * D ];
        for( j = i + 1; j < D; j++ ) {
            tmp = SKP_SMLAWB( tmp, pRow[ j ], cn[ j ] );
        }
        tmp  = SKP_SMLAWB( tmp,  SKP_RSHIFT( pRow[ i ], 1 ), cn[ i ] );
        tmp2 = SKP_SMLAWB( tmp2, tmp,                        cn[ i ] );
    }
    nrg = SKP_ADD_LSHIFT32( nrg, tmp2, lshifts );                       

    
    if( nrg < 1 ) {
        nrg = 1;
    } else if( nrg > SKP_RSHIFT( SKP_int32_MAX, lshifts + 2 ) ) {
        nrg = SKP_int32_MAX >> 1;
    } else {
        nrg = SKP_LSHIFT( nrg, lshifts + 1 );                           
    }
    return nrg;

}








void SKP_Silk_residual_energy_FIX(
          SKP_int32 nrgs[ NB_SUBFR ],           
          SKP_int   nrgsQ[ NB_SUBFR ],          
    const SKP_int16 x[],                        
          SKP_int16 a_Q12[ 2 ][ MAX_LPC_ORDER ],
    const SKP_int32 gains[ NB_SUBFR ],          
    const SKP_int   subfr_length,               
    const SKP_int   LPC_order                   
)
{
    SKP_int         offset, i, j, rshift, lz1, lz2;
    SKP_int16       *LPC_res_ptr, LPC_res[ ( MAX_FRAME_LENGTH + NB_SUBFR * MAX_LPC_ORDER ) / 2 ];
    const SKP_int16 *x_ptr;
    SKP_int16       S[ MAX_LPC_ORDER ];
    SKP_int32       tmp32;

    x_ptr  = x;
    offset = LPC_order + subfr_length;
    
    
    for( i = 0; i < 2; i++ ) {
        
        SKP_memset( S, 0, LPC_order * sizeof( SKP_int16 ) );
        SKP_Silk_LPC_analysis_filter( x_ptr, a_Q12[ i ], S, LPC_res, ( NB_SUBFR >> 1 ) * offset, LPC_order );

        
        LPC_res_ptr = LPC_res + LPC_order;
        for( j = 0; j < ( NB_SUBFR >> 1 ); j++ ) {
            
            SKP_Silk_sum_sqr_shift( &nrgs[ i * ( NB_SUBFR >> 1 ) + j ], &rshift, LPC_res_ptr, subfr_length ); 
            
            
            nrgsQ[ i * ( NB_SUBFR >> 1 ) + j ] = -rshift;
            
            
            LPC_res_ptr += offset;
        }
        
        x_ptr += ( NB_SUBFR >> 1 ) * offset;
    }

    
    for( i = 0; i < NB_SUBFR; i++ ) {
        
        lz1 = SKP_Silk_CLZ32( nrgs[  i ] ) - 1; 
        lz2 = SKP_Silk_CLZ32( gains[ i ] ) - 1; 
        
        tmp32 = SKP_LSHIFT32( gains[ i ], lz2 );

        
        tmp32 = SKP_SMMUL( tmp32, tmp32 ); 

        
        nrgs[ i ] = SKP_SMMUL( tmp32, SKP_LSHIFT32( nrgs[ i ], lz1 ) ); 
        nrgsQ[ i ] += lz1 + 2 * lz2 - 32 - 32;
    }
}







void SKP_Silk_scale_copy_vector16( 
    SKP_int16           *data_out, 
    const SKP_int16     *data_in, 
    SKP_int32           gain_Q16,                   
    const SKP_int       dataSize                    
)
{
    SKP_int  i;
    SKP_int32 tmp32;

    for( i = 0; i < dataSize; i++ ) {
        tmp32 = SKP_SMULWB( gain_Q16, data_in[ i ] );
        data_out[ i ] = (SKP_int16)SKP_CHECK_FIT16( tmp32 );
    }
}







void SKP_Silk_scale_vector32_Q26_lshift_18( 
    SKP_int32           *data1,                     
    SKP_int32           gain_Q26,                   
    SKP_int             dataSize                    
)
{
    SKP_int  i;

    for( i = 0; i < dataSize; i++ ) {
        data1[ i ] = (SKP_int32)SKP_CHECK_FIT32( SKP_RSHIFT64( SKP_SMULL( data1[ i ], gain_Q26 ), 8 ) );
    }
}









 
SKP_int32 SKP_Silk_schur(                     
    SKP_int16            *rc_Q15,               
    const SKP_int32      *c,                    
    const SKP_int32      order                  
)
{
    SKP_int        k, n, lz;
    SKP_int32    C[ SKP_Silk_MAX_ORDER_LPC + 1 ][ 2 ];
    SKP_int32    Ctmp1, Ctmp2, rc_tmp_Q15;

    
    lz = SKP_Silk_CLZ32( c[ 0 ] );

    
    if( lz < 2 ) {
        
        for( k = 0; k < order + 1; k++ ) {
            C[ k ][ 0 ] = C[ k ][ 1 ] = SKP_RSHIFT( c[ k ], 1 );
        }
    } else if( lz > 2 ) {
        
        lz -= 2; 
        for( k = 0; k < order + 1; k++ ) {
            C[ k ][ 0 ] = C[ k ][ 1 ] = SKP_LSHIFT( c[k], lz );
        }
    } else {
        
        for( k = 0; k < order + 1; k++ ) {
            C[ k ][ 0 ] = C[ k ][ 1 ] = c[ k ];
        }
    }

    for( k = 0; k < order; k++ ) {
        
        
        rc_tmp_Q15 = -SKP_DIV32_16( C[ k + 1 ][ 0 ], SKP_max_32( SKP_RSHIFT( C[ 0 ][ 1 ], 15 ), 1 ) );

        
        rc_tmp_Q15 = SKP_SAT16( rc_tmp_Q15 );

        
        rc_Q15[ k ] = (SKP_int16)rc_tmp_Q15;

        
        for( n = 0; n < order - k; n++ ) {
            Ctmp1 = C[ n + k + 1 ][ 0 ];
            Ctmp2 = C[ n ][ 1 ];
            C[ n + k + 1 ][ 0 ] = SKP_SMLAWB( Ctmp1, SKP_LSHIFT( Ctmp2, 1 ), rc_tmp_Q15 );
            C[ n ][ 1 ]         = SKP_SMLAWB( Ctmp2, SKP_LSHIFT( Ctmp1, 1 ), rc_tmp_Q15 );
        }
    }

    
    return C[0][1];
}








 
#if EMBEDDED_ARM<6
SKP_int32 SKP_Silk_schur64(                    
    SKP_int32            rc_Q16[],               
    const SKP_int32      c[],                    
    SKP_int32            order                   
)
{
    SKP_int   k, n;
    SKP_int32 C[ SKP_Silk_MAX_ORDER_LPC + 1 ][ 2 ];
    SKP_int32 Ctmp1_Q30, Ctmp2_Q30, rc_tmp_Q31;

    
    if( c[ 0 ] <= 0 ) {
        SKP_memset( rc_Q16, 0, order * sizeof( SKP_int32 ) );
        return 0;
    }
    
    for( k = 0; k < order + 1; k++ ) {
        C[ k ][ 0 ] = C[ k ][ 1 ] = c[ k ];
    }

    for( k = 0; k < order; k++ ) {
        
        rc_tmp_Q31 = SKP_DIV32_varQ( -C[ k + 1 ][ 0 ], C[ 0 ][ 1 ], 31 );

        
        rc_Q16[ k ] = SKP_RSHIFT_ROUND( rc_tmp_Q31, 15 );

        
        for( n = 0; n < order - k; n++ ) {
            Ctmp1_Q30 = C[ n + k + 1 ][ 0 ];
            Ctmp2_Q30 = C[ n ][ 1 ];
            
            
            C[ n + k + 1 ][ 0 ] = Ctmp1_Q30 + SKP_SMMUL( SKP_LSHIFT( Ctmp2_Q30, 1 ), rc_tmp_Q31 );
            C[ n ][ 1 ]         = Ctmp2_Q30 + SKP_SMMUL( SKP_LSHIFT( Ctmp1_Q30, 1 ), rc_tmp_Q31 );
        }
    }

    return C[ 0 ][ 1 ];
}
#endif








SKP_INLINE void combine_pulses(
    SKP_int         *out,   
    const SKP_int   *in,    
    const SKP_int   len     
)
{
    SKP_int k;
    for( k = 0; k < len; k++ ) {
        out[ k ] = in[ 2 * k ] + in[ 2 * k + 1 ];
    }
}

SKP_INLINE void encode_split(
    SKP_Silk_range_coder_state  *sRC,           
    const SKP_int               p_child1,       
    const SKP_int               p,              
    const SKP_uint16            *shell_table    
)
{
    const SKP_uint16 *cdf;

    if( p > 0 ) {
        cdf = &shell_table[ SKP_Silk_shell_code_table_offsets[ p ] ];
        SKP_Silk_range_encoder( sRC, p_child1, cdf );
    }
}

SKP_INLINE void decode_split(
    SKP_int                     *p_child1,      
    SKP_int                     *p_child2,      
    SKP_Silk_range_coder_state  *sRC,           
    const SKP_int               p,              
    const SKP_uint16            *shell_table    
)
{
    SKP_int cdf_middle;
    const SKP_uint16 *cdf;

    if( p > 0 ) {
        cdf_middle = SKP_RSHIFT( p, 1 );
        cdf = &shell_table[ SKP_Silk_shell_code_table_offsets[ p ] ];
        SKP_Silk_range_decoder( p_child1, sRC, cdf, cdf_middle );
        p_child2[ 0 ] = p - p_child1[ 0 ];
    } else {
        p_child1[ 0 ] = 0;
        p_child2[ 0 ] = 0;
    }
}


void SKP_Silk_shell_encoder(
    SKP_Silk_range_coder_state      *sRC,               
    const SKP_int                   *pulses0            
)
{
    SKP_int pulses1[ 8 ], pulses2[ 4 ], pulses3[ 2 ], pulses4[ 1 ];

    
    SKP_assert( SHELL_CODEC_FRAME_LENGTH == 16 );

    
    combine_pulses( pulses1, pulses0, 8 );
    combine_pulses( pulses2, pulses1, 4 );
    combine_pulses( pulses3, pulses2, 2 );
    combine_pulses( pulses4, pulses3, 1 );

    encode_split( sRC, pulses3[  0 ], pulses4[ 0 ], SKP_Silk_shell_code_table3 );

    encode_split( sRC, pulses2[  0 ], pulses3[ 0 ], SKP_Silk_shell_code_table2 );

    encode_split( sRC, pulses1[  0 ], pulses2[ 0 ], SKP_Silk_shell_code_table1 );
    encode_split( sRC, pulses0[  0 ], pulses1[ 0 ], SKP_Silk_shell_code_table0 );
    encode_split( sRC, pulses0[  2 ], pulses1[ 1 ], SKP_Silk_shell_code_table0 );

    encode_split( sRC, pulses1[  2 ], pulses2[ 1 ], SKP_Silk_shell_code_table1 );
    encode_split( sRC, pulses0[  4 ], pulses1[ 2 ], SKP_Silk_shell_code_table0 );
    encode_split( sRC, pulses0[  6 ], pulses1[ 3 ], SKP_Silk_shell_code_table0 );

    encode_split( sRC, pulses2[  2 ], pulses3[ 1 ], SKP_Silk_shell_code_table2 );

    encode_split( sRC, pulses1[  4 ], pulses2[ 2 ], SKP_Silk_shell_code_table1 );
    encode_split( sRC, pulses0[  8 ], pulses1[ 4 ], SKP_Silk_shell_code_table0 );
    encode_split( sRC, pulses0[ 10 ], pulses1[ 5 ], SKP_Silk_shell_code_table0 );

    encode_split( sRC, pulses1[  6 ], pulses2[ 3 ], SKP_Silk_shell_code_table1 );
    encode_split( sRC, pulses0[ 12 ], pulses1[ 6 ], SKP_Silk_shell_code_table0 );
    encode_split( sRC, pulses0[ 14 ], pulses1[ 7 ], SKP_Silk_shell_code_table0 );
}



void SKP_Silk_shell_decoder(
    SKP_int                         *pulses0,           
    SKP_Silk_range_coder_state      *sRC,               
    const SKP_int                   pulses4             
)
{
    SKP_int pulses3[ 2 ], pulses2[ 4 ], pulses1[ 8 ];

    
    SKP_assert( SHELL_CODEC_FRAME_LENGTH == 16 );

    decode_split( &pulses3[  0 ], &pulses3[  1 ], sRC, pulses4,      SKP_Silk_shell_code_table3 );

    decode_split( &pulses2[  0 ], &pulses2[  1 ], sRC, pulses3[ 0 ], SKP_Silk_shell_code_table2 );

    decode_split( &pulses1[  0 ], &pulses1[  1 ], sRC, pulses2[ 0 ], SKP_Silk_shell_code_table1 );
    decode_split( &pulses0[  0 ], &pulses0[  1 ], sRC, pulses1[ 0 ], SKP_Silk_shell_code_table0 );
    decode_split( &pulses0[  2 ], &pulses0[  3 ], sRC, pulses1[ 1 ], SKP_Silk_shell_code_table0 );

    decode_split( &pulses1[  2 ], &pulses1[  3 ], sRC, pulses2[ 1 ], SKP_Silk_shell_code_table1 );
    decode_split( &pulses0[  4 ], &pulses0[  5 ], sRC, pulses1[ 2 ], SKP_Silk_shell_code_table0 );
    decode_split( &pulses0[  6 ], &pulses0[  7 ], sRC, pulses1[ 3 ], SKP_Silk_shell_code_table0 );

    decode_split( &pulses2[  2 ], &pulses2[  3 ], sRC, pulses3[ 1 ], SKP_Silk_shell_code_table2 );

    decode_split( &pulses1[  4 ], &pulses1[  5 ], sRC, pulses2[ 2 ], SKP_Silk_shell_code_table1 );
    decode_split( &pulses0[  8 ], &pulses0[  9 ], sRC, pulses1[ 4 ], SKP_Silk_shell_code_table0 );
    decode_split( &pulses0[ 10 ], &pulses0[ 11 ], sRC, pulses1[ 5 ], SKP_Silk_shell_code_table0 );

    decode_split( &pulses1[  6 ], &pulses1[  7 ], sRC, pulses2[ 3 ], SKP_Silk_shell_code_table1 );
    decode_split( &pulses0[ 12 ], &pulses0[ 13 ], sRC, pulses1[ 6 ], SKP_Silk_shell_code_table0 );
    decode_split( &pulses0[ 14 ], &pulses0[ 15 ], sRC, pulses1[ 7 ], SKP_Silk_shell_code_table0 );
}






#if EMBEDDED_ARM<4




static const SKP_int32 sigm_LUT_slope_Q10[ 6 ] = {
    237, 153, 73, 30, 12, 7
};

static const SKP_int32 sigm_LUT_pos_Q15[ 6 ] = {
    16384, 23955, 28861, 31213, 32178, 32548
};

static const SKP_int32 sigm_LUT_neg_Q15[ 6 ] = {
    16384, 8812, 3906, 1554, 589, 219
};

SKP_int SKP_Silk_sigm_Q15( SKP_int in_Q5 ) 
{
    SKP_int ind;

    if( in_Q5 < 0 ) {
        
        in_Q5 = -in_Q5;
        if( in_Q5 >= 6 * 32 ) {
            return 0;        
        } else {
            
            ind = SKP_RSHIFT( in_Q5, 5 );
            return( sigm_LUT_neg_Q15[ ind ] - SKP_SMULBB( sigm_LUT_slope_Q10[ ind ], in_Q5 & 0x1F ) );
        }
    } else {
        
        if( in_Q5 >= 6 * 32 ) {
            return 32767;        
        } else {
            
            ind = SKP_RSHIFT( in_Q5, 5 );
            return( sigm_LUT_pos_Q15[ ind ] + SKP_SMULBB( sigm_LUT_slope_Q10[ ind ], in_Q5 & 0x1F ) );
        }
    }
}
#endif












typedef struct {
    SKP_int32 Q36_part;
    SKP_int32 Q48_part;
} inv_D_t;


SKP_INLINE void SKP_Silk_LDL_factorize_FIX(
    SKP_int32           *A,         
    SKP_int             M,          
    SKP_int32           *L_Q16,     
    inv_D_t             *inv_D      
);


SKP_INLINE void SKP_Silk_LS_SolveFirst_FIX(
    const SKP_int32     *L_Q16,     
    SKP_int             M,          
    const SKP_int32     *b,         
    SKP_int32           *x_Q16        
);


SKP_INLINE void SKP_Silk_LS_SolveLast_FIX(
    const SKP_int32     *L_Q16,     
    const SKP_int       M,          
    const SKP_int32     *b,         
    SKP_int32           *x_Q16        
);

SKP_INLINE void SKP_Silk_LS_divide_Q16_FIX(
    SKP_int32           T[],    
    inv_D_t             *inv_D, 
    SKP_int             M       
);


void SKP_Silk_solve_LDL_FIX(
    SKP_int32                       *A,                 
    SKP_int                         M,                  
    const SKP_int32                 *b,                 
    SKP_int32                       *x_Q16              
)
{
    SKP_int32 L_Q16[  MAX_MATRIX_SIZE * MAX_MATRIX_SIZE ]; 
    SKP_int32 Y[      MAX_MATRIX_SIZE ];
    inv_D_t   inv_D[  MAX_MATRIX_SIZE ];

    SKP_assert( M <= MAX_MATRIX_SIZE );

    
    SKP_Silk_LDL_factorize_FIX( A, M, L_Q16, inv_D );
        
    
    SKP_Silk_LS_SolveFirst_FIX( L_Q16, M, b, Y );

    
    SKP_Silk_LS_divide_Q16_FIX( Y, inv_D, M );

    
    SKP_Silk_LS_SolveLast_FIX( L_Q16, M, Y, x_Q16 );
}

SKP_INLINE void SKP_Silk_LDL_factorize_FIX(
    SKP_int32           *A,         
    SKP_int             M,          
    SKP_int32           *L_Q16,     
    inv_D_t             *inv_D      
)
{
    SKP_int   i, j, k, status, loop_count;
    const SKP_int32 *ptr1, *ptr2;
    SKP_int32 diag_min_value, tmp_32, err;
    SKP_int32 v_Q0[ MAX_MATRIX_SIZE ], D_Q0[ MAX_MATRIX_SIZE ];
    SKP_int32 one_div_diag_Q36, one_div_diag_Q40, one_div_diag_Q48;

    SKP_assert( M <= MAX_MATRIX_SIZE );

    status = 1;
    diag_min_value = SKP_max_32( SKP_SMMUL( SKP_ADD_SAT32( A[ 0 ], A[ SKP_SMULBB( M, M ) - 1 ] ), SKP_FIX_CONST( FIND_LTP_COND_FAC, 31 ) ), 1 << 9 );
    for( loop_count = 0; loop_count < M && status == 1; loop_count++ ) {
        status = 0;
        for( j = 0; j < M; j++ ) {
            ptr1 = matrix_adr( L_Q16, j, 0, M );
            tmp_32 = 0;
            for( i = 0; i < j; i++ ) {
                v_Q0[ i ] = SKP_SMULWW(         D_Q0[ i ], ptr1[ i ] ); 
                tmp_32    = SKP_SMLAWW( tmp_32, v_Q0[ i ], ptr1[ i ] ); 
            }
            tmp_32 = SKP_SUB32( matrix_ptr( A, j, j, M ), tmp_32 );

            if( tmp_32 < diag_min_value ) {
                tmp_32 = SKP_SUB32( SKP_SMULBB( loop_count + 1, diag_min_value ), tmp_32 );
                
                for( i = 0; i < M; i++ ) {
                    matrix_ptr( A, i, i, M ) = SKP_ADD32( matrix_ptr( A, i, i, M ), tmp_32 );
                }
                status = 1;
                break;
            }
            D_Q0[ j ] = tmp_32;                         
        
            
            one_div_diag_Q36 = SKP_INVERSE32_varQ( tmp_32, 36 );                    
            one_div_diag_Q40 = SKP_LSHIFT( one_div_diag_Q36, 4 );                   
            err = SKP_SUB32( 1 << 24, SKP_SMULWW( tmp_32, one_div_diag_Q40 ) );     
            one_div_diag_Q48 = SKP_SMULWW( err, one_div_diag_Q40 );                 

            
            inv_D[ j ].Q36_part = one_div_diag_Q36;
            inv_D[ j ].Q48_part = one_div_diag_Q48;

            matrix_ptr( L_Q16, j, j, M ) = 65536; 
            ptr1 = matrix_adr( A, j, 0, M );
            ptr2 = matrix_adr( L_Q16, j + 1, 0, M );
            for( i = j + 1; i < M; i++ ) { 
                tmp_32 = 0;
                for( k = 0; k < j; k++ ) {
                    tmp_32 = SKP_SMLAWW( tmp_32, v_Q0[ k ], ptr2[ k ] ); 
                }
                tmp_32 = SKP_SUB32( ptr1[ i ], tmp_32 ); 

                
                matrix_ptr( L_Q16, i, j, M ) = SKP_ADD32( SKP_SMMUL( tmp_32, one_div_diag_Q48 ),
                    SKP_RSHIFT( SKP_SMULWW( tmp_32, one_div_diag_Q36 ), 4 ) );

                
                ptr2 += M; 
            }
        }
    }

    SKP_assert( status == 0 );
}

SKP_INLINE void SKP_Silk_LS_divide_Q16_FIX(
    SKP_int32 T[],      
    inv_D_t *inv_D,     
    SKP_int M           
)
{
    SKP_int   i;
    SKP_int32 tmp_32;
    SKP_int32 one_div_diag_Q36, one_div_diag_Q48;

    for( i = 0; i < M; i++ ) {
        one_div_diag_Q36 = inv_D[ i ].Q36_part;
        one_div_diag_Q48 = inv_D[ i ].Q48_part;

        tmp_32 = T[ i ];
        T[ i ] = SKP_ADD32( SKP_SMMUL( tmp_32, one_div_diag_Q48 ), SKP_RSHIFT( SKP_SMULWW( tmp_32, one_div_diag_Q36 ), 4 ) );
    }
}


SKP_INLINE void SKP_Silk_LS_SolveFirst_FIX(
    const SKP_int32     *L_Q16, 
    SKP_int             M,      
    const SKP_int32     *b,     
    SKP_int32           *x_Q16    
)
{
    SKP_int i, j;
    const SKP_int32 *ptr32;
    SKP_int32 tmp_32;

    for( i = 0; i < M; i++ ) {
        ptr32 = matrix_adr( L_Q16, i, 0, M );
        tmp_32 = 0;
        for( j = 0; j < i; j++ ) {
            tmp_32 = SKP_SMLAWW( tmp_32, ptr32[ j ], x_Q16[ j ] );
        }
        x_Q16[ i ] = SKP_SUB32( b[ i ], tmp_32 );
    }
}


SKP_INLINE void SKP_Silk_LS_SolveLast_FIX(
    const SKP_int32     *L_Q16,     
    const SKP_int       M,          
    const SKP_int32     *b,         
    SKP_int32           *x_Q16        
)
{
    SKP_int i, j;
    const SKP_int32 *ptr32;
    SKP_int32 tmp_32;

    for( i = M - 1; i >= 0; i-- ) {
        ptr32 = matrix_adr( L_Q16, 0, i, M );
        tmp_32 = 0;
        for( j = M - 1; j > i; j-- ) {
            tmp_32 = SKP_SMLAWW( tmp_32, ptr32[ SKP_SMULBB( j, M ) ], x_Q16[ j ] );
        }
        x_Q16[ i ] = SKP_SUB32( b[ i ], tmp_32 );
    }
}










void SKP_Silk_insertion_sort_increasing(
    SKP_int32           *a,             
    SKP_int             *index,         
    const SKP_int       L,              
    const SKP_int       K               
)
{
    SKP_int32    value;
    SKP_int        i, j;

    
    SKP_assert( K >  0 );
    SKP_assert( L >  0 );
    SKP_assert( L >= K );

    
    for( i = 0; i < K; i++ ) {
        index[ i ] = i;
    }

    
    for( i = 1; i < K; i++ ) {
        value = a[ i ];
        for( j = i - 1; ( j >= 0 ) && ( value < a[ j ] ); j-- ) {
            a[ j + 1 ]     = a[ j ];     
            index[ j + 1 ] = index[ j ]; 
        }
        a[ j + 1 ]     = value; 
        index[ j + 1 ] = i;     
    }

    
    
    for( i = K; i < L; i++ ) {
        value = a[ i ];
        if( value < a[ K - 1 ] ) {
            for( j = K - 2; ( j >= 0 ) && ( value < a[ j ] ); j-- ) {
                a[ j + 1 ]     = a[ j ];     
                index[ j + 1 ] = index[ j ]; 
            }
            a[ j + 1 ]     = value; 
            index[ j + 1 ] = i;        
        }
    }
}

void SKP_Silk_insertion_sort_decreasing_int16(
    SKP_int16           *a,             
    SKP_int             *index,         
    const SKP_int       L,              
    const SKP_int       K               
)
{
    SKP_int i, j;
    SKP_int value;

    
    SKP_assert( K >  0 );
    SKP_assert( L >  0 );
    SKP_assert( L >= K );

    
    for( i = 0; i < K; i++ ) {
        index[ i ] = i;
    }

    
    for( i = 1; i < K; i++ ) {
        value = a[ i ];
        for( j = i - 1; ( j >= 0 ) && ( value > a[ j ] ); j-- ) {    
            a[ j + 1 ]     = a[ j ];     
            index[ j + 1 ] = index[ j ]; 
        }
        a[ j + 1 ]     = value; 
        index[ j + 1 ] = i;     
    }

    
    
    for( i = K; i < L; i++ ) {
        value = a[ i ];
        if( value > a[ K - 1 ] ) {
            for( j = K - 2; ( j >= 0 ) && ( value > a[ j ] ); j-- ) {    
                a[ j + 1 ]     = a[ j ];     
                index[ j + 1 ] = index[ j ]; 
            }
            a[ j + 1 ]     = value; 
            index[ j + 1 ] = i;     
        }
    }
}

void SKP_Silk_insertion_sort_increasing_all_values(
    SKP_int             *a,             
    const SKP_int       L               
)
{
    SKP_int    value;
    SKP_int    i, j;

    
    SKP_assert( L >  0 );

    
    for( i = 1; i < L; i++ ) {
        value = a[ i ];
        for( j = i - 1; ( j >= 0 ) && ( value < a[ j ] ); j-- ) {
            a[ j + 1 ] = a[ j ]; 
        }
        a[ j + 1 ] = value; 
    }
}








#if (EMBEDDED_ARM<5) 


void SKP_Silk_sum_sqr_shift(
    SKP_int32            *energy,            
    SKP_int              *shift,             
    const SKP_int16      *x,                 
    SKP_int              len                 
)
{
    SKP_int   i, shft;
    SKP_int32 in32, nrg_tmp, nrg;

    if( (SKP_int32)( (SKP_int_ptr_size)x & 2 ) != 0 ) {
        
        nrg = SKP_SMULBB( x[ 0 ], x[ 0 ] );
        i = 1;
    } else {
        nrg = 0;
        i   = 0;
    }
    shft = 0;
    len--;
    while( i < len ) {
        
        in32 = *( (SKP_int32 *)&x[ i ] );
        nrg = SKP_SMLABB_ovflw( nrg, in32, in32 );
        nrg = SKP_SMLATT_ovflw( nrg, in32, in32 );
        i += 2;
        if( nrg < 0 ) {
            
            nrg = (SKP_int32)SKP_RSHIFT_uint( (SKP_uint32)nrg, 2 );
            shft = 2;
            break;
        }
    }
    for( ; i < len; i += 2 ) {
        
        in32 = *( (SKP_int32 *)&x[ i ] );
        nrg_tmp = SKP_SMULBB( in32, in32 );
        nrg_tmp = SKP_SMLATT_ovflw( nrg_tmp, in32, in32 );
        nrg = (SKP_int32)SKP_ADD_RSHIFT_uint( nrg, (SKP_uint32)nrg_tmp, shft );
        if( nrg < 0 ) {
            
            nrg = (SKP_int32)SKP_RSHIFT_uint( (SKP_uint32)nrg, 2 );
            shft += 2;
        }
    }
    if( i == len ) {
        
        nrg_tmp = SKP_SMULBB( x[ i ], x[ i ] );
        nrg = (SKP_int32)SKP_ADD_RSHIFT_uint( nrg, nrg_tmp, shft );
    }

    
    if( nrg & 0xC0000000 ) {
        nrg = SKP_RSHIFT_uint( (SKP_uint32)nrg, 2 );
        shft += 2;
    }

    
    *shift  = shft;
    *energy = nrg;
}

#endif






const SKP_uint16 SKP_Silk_LTP_per_index_CDF[ 4 ] = {
         0,  20992,  40788,  65535
};

const SKP_int SKP_Silk_LTP_per_index_CDF_offset = 1;


const SKP_uint16 SKP_Silk_LTP_gain_CDF_0[ 11 ] = {
         0,  49380,  54463,  56494,  58437,  60101,  61683,  62985,
     64066,  64823,  65535
};

const SKP_uint16 SKP_Silk_LTP_gain_CDF_1[ 21 ] = {
         0,  25290,  30654,  35710,  40386,  42937,  45250,  47459,
     49411,  51348,  52974,  54517,  55976,  57423,  58865,  60285,
     61667,  62895,  63827,  64724,  65535
};

const SKP_uint16 SKP_Silk_LTP_gain_CDF_2[ 41 ] = {
         0,   4958,   9439,  13581,  17638,  21651,  25015,  28025,
     30287,  32406,  34330,  36240,  38130,  39790,  41281,  42764,
     44229,  45676,  47081,  48431,  49675,  50849,  51932,  52966,
     53957,  54936,  55869,  56789,  57708,  58504,  59285,  60043,
     60796,  61542,  62218,  62871,  63483,  64076,  64583,  65062,
     65535
};

const SKP_int SKP_Silk_LTP_gain_CDF_offsets[ 3 ] = {
         1,     3,     10
};

const SKP_int32 SKP_Silk_LTP_gain_middle_avg_RD_Q14 = 11010;

const SKP_int16 SKP_Silk_LTP_gain_BITS_Q6_0[ 10 ] = {
        26,    236,    321,    325,    339,    344,    362,    379,
       412,    418
};

const SKP_int16 SKP_Silk_LTP_gain_BITS_Q6_1[ 20 ] = {
        88,    231,    237,    244,    300,    309,    313,    324,
       325,    341,    346,    351,    352,    352,    354,    356,
       367,    393,    396,    406
};

const SKP_int16 SKP_Silk_LTP_gain_BITS_Q6_2[ 40 ] = {
       238,    248,    255,    257,    258,    274,    284,    311,
       317,    326,    326,    327,    339,    349,    350,    351,
       352,    355,    358,    366,    371,    379,    383,    387,
       388,    393,    394,    394,    407,    409,    412,    412,
       413,    422,    426,    432,    434,    449,    454,    455
};

const SKP_uint16 * const SKP_Silk_LTP_gain_CDF_ptrs[ NB_LTP_CBKS ] = {
    SKP_Silk_LTP_gain_CDF_0,
    SKP_Silk_LTP_gain_CDF_1,
    SKP_Silk_LTP_gain_CDF_2
};

const SKP_int16 * const SKP_Silk_LTP_gain_BITS_Q6_ptrs[ NB_LTP_CBKS ] = {
    SKP_Silk_LTP_gain_BITS_Q6_0,
    SKP_Silk_LTP_gain_BITS_Q6_1,
    SKP_Silk_LTP_gain_BITS_Q6_2
};

const SKP_int16 SKP_Silk_LTP_gain_vq_0_Q14[ 10 ][ 5 ] = 
{
{
       594,    984,   2840,   1021,    669
},
{
        10,     35,    304,     -1,     23
},
{
      -694,   1923,   4603,   2975,   2335
},
{
      2437,   3176,   3778,   1940,    481
},
{
       214,    -46,   7870,   4406,   -521
},
{
      -896,   4818,   8501,   1623,   -887
},
{
      -696,   3178,   6480,   -302,   1081
},
{
       517,    599,   1002,    567,    560
},
{
     -2075,   -834,   4712,   -340,    896
},
{
      1435,   -644,   3993,   -612,  -2063
}
};

const SKP_int16 SKP_Silk_LTP_gain_vq_1_Q14[ 20 ][ 5 ] = 
{
{
      1655,   2918,   5001,   3010,   1775
},
{
       113,    198,    856,    176,    178
},
{
      -843,   2479,   7858,   5371,    574
},
{
        59,   5356,   7648,   2850,   -315
},
{
      3840,   4851,   6527,   1583,  -1233
},
{
      1620,   1760,   2330,   1876,   2045
},
{
      -545,   1854,  11792,   1547,   -307
},
{
      -604,    689,   5369,   5074,   4265
},
{
       521,  -1331,   9829,   6209,  -1211
},
{
     -1315,   6747,   9929,  -1410,    546
},
{
       117,   -144,   2810,   1649,   5240
},
{
      5392,   3476,   2425,    -38,    633
},
{
        14,   -449,   5274,   3547,   -171
},
{
       -98,    395,   9114,   1676,    844
},
{
      -908,   3843,   8861,   -957,   1474
},
{
       396,   6747,   5379,   -329,   1269
},
{
      -335,   2830,   4281,    270,    -54
},
{
      1502,   5609,   8958,   6045,   2059
},
{
      -370,    479,   5267,   5726,   1174
},
{
      5237,  -1144,   6510,    455,    512
}
};

const SKP_int16 SKP_Silk_LTP_gain_vq_2_Q14[ 40 ][ 5 ] = 
{
{
      -278,    415,   9345,   7106,   -431
},
{
     -1006,   3863,   9524,   4724,   -871
},
{
      -954,   4624,  11722,    973,   -300
},
{
      -117,   7066,   8331,   1959,   -901
},
{
       593,   3412,   6070,   4914,   1567
},
{
        54,    -51,  12618,   4228,   -844
},
{
      3157,   4822,   5229,   2313,    717
},
{
      -244,   1161,  14198,    779,     69
},
{
     -1218,   5603,  12894,  -2301,   1001
},
{
      -132,   3960,   9526,    577,   1806
},
{
     -1633,   8815,  10484,  -2452,    895
},
{
       235,    450,   1243,    667,    437
},
{
       959,  -2630,  10897,   8772,  -1852
},
{
      2420,   2046,   8893,   4427,  -1569
},
{
        23,   7091,   8356,  -1285,   1508
},
{
     -1133,    835,   7662,   6043,   2800
},
{
       439,    391,  11016,   2253,   1362
},
{
     -1020,   2876,  13436,   4015,  -3020
},
{
      1060,  -2690,  13512,   5565,  -1394
},
{
     -1420,   8007,  11421,   -152,  -1672
},
{
      -893,   2895,  15434,  -1490,    159
},
{
     -1054,    428,  12208,   8538,  -3344
},
{
      1772,  -1304,   7593,   6185,    561
},
{
       525,  -1207,   6659,  11151,  -1170
},
{
       439,   2667,   4743,   2359,   5515
},
{
      2951,   7432,   7909,   -230,  -1564
},
{
       -72,   2140,   5477,   1391,   1580
},
{
       476,  -1312,  15912,   2174,  -1027
},
{
      5737,    441,   2493,   2043,   2757
},
{
       228,    -43,   1803,   6663,   7064
},
{
      4596,   9182,   1917,   -200,    203
},
{
      -704,  12039,   5451,  -1188,    542
},
{
      1782,  -1040,  10078,   7513,  -2767
},
{
     -2626,   7747,   9019,     62,   1710
},
{
       235,   -233,   2954,  10921,   1947
},
{
     10854,   2814,   1232,   -111,    222
},
{
      2267,   2778,  12325,    156,  -1658
},
{
     -2950,   8095,  16330,    268,  -3626
},
{
        67,   2083,   7950,    -80,  -2432
},
{
       518,    -66,   1718,    415,  11435
}
};

const SKP_int16 * const SKP_Silk_LTP_vq_ptrs_Q14[ NB_LTP_CBKS ] = {
    &SKP_Silk_LTP_gain_vq_0_Q14[ 0 ][ 0 ],
    &SKP_Silk_LTP_gain_vq_1_Q14[ 0 ][ 0 ],
    &SKP_Silk_LTP_gain_vq_2_Q14[ 0 ][ 0 ]
};
 
const SKP_int SKP_Silk_LTP_vq_sizes[ NB_LTP_CBKS ] = {
    10, 20, 40 
};














#ifndef SKP_SILK_TABLES_NLSF_CB0_10_H
#define SKP_SILK_TABLES_NLSF_CB0_10_H



#ifdef __cplusplus
extern "C"
{
#endif

#define NLSF_MSVQ_CB0_10_STAGES       6
#define NLSF_MSVQ_CB0_10_VECTORS      120


extern const SKP_uint16         SKP_Silk_NLSF_MSVQ_CB0_10_CDF[ NLSF_MSVQ_CB0_10_VECTORS + NLSF_MSVQ_CB0_10_STAGES ];
extern const SKP_uint16 * const SKP_Silk_NLSF_MSVQ_CB0_10_CDF_start_ptr[                  NLSF_MSVQ_CB0_10_STAGES ];
extern const SKP_int            SKP_Silk_NLSF_MSVQ_CB0_10_CDF_middle_idx[                 NLSF_MSVQ_CB0_10_STAGES ];

#ifdef __cplusplus
}
#endif

#endif



const SKP_uint16 SKP_Silk_NLSF_MSVQ_CB0_10_CDF[ NLSF_MSVQ_CB0_10_VECTORS + NLSF_MSVQ_CB0_10_STAGES ] =
{
            0,
         2658,
         4420,
         6107,
         7757,
         9408,
        10955,
        12502,
        13983,
        15432,
        16882,
        18331,
        19750,
        21108,
        22409,
        23709,
        25010,
        26256,
        27501,
        28747,
        29965,
        31158,
        32351,
        33544,
        34736,
        35904,
        36997,
        38091,
        39185,
        40232,
        41280,
        42327,
        43308,
        44290,
        45271,
        46232,
        47192,
        48132,
        49032,
        49913,
        50775,
        51618,
        52462,
        53287,
        54095,
        54885,
        55675,
        56449,
        57222,
        57979,
        58688,
        59382,
        60076,
        60726,
        61363,
        61946,
        62505,
        63052,
        63543,
        63983,
        64396,
        64766,
        65023,
        65279,
        65535,
            0,
         4977,
         9542,
        14106,
        18671,
        23041,
        27319,
        31596,
        35873,
        39969,
        43891,
        47813,
        51652,
        55490,
        59009,
        62307,
        65535,
            0,
         8571,
        17142,
        25529,
        33917,
        42124,
        49984,
        57844,
        65535,
            0,
         8732,
        17463,
        25825,
        34007,
        42189,
        50196,
        58032,
        65535,
            0,
         8948,
        17704,
        25733,
        33762,
        41791,
        49821,
        57678,
        65535,
            0,
         4374,
         8655,
        12936,
        17125,
        21313,
        25413,
        29512,
        33611,
        37710,
        41809,
        45820,
        49832,
        53843,
        57768,
        61694,
        65535
};

const SKP_uint16 * const SKP_Silk_NLSF_MSVQ_CB0_10_CDF_start_ptr[ NLSF_MSVQ_CB0_10_STAGES ] =
{
     &SKP_Silk_NLSF_MSVQ_CB0_10_CDF[   0 ],
     &SKP_Silk_NLSF_MSVQ_CB0_10_CDF[  65 ],
     &SKP_Silk_NLSF_MSVQ_CB0_10_CDF[  82 ],
     &SKP_Silk_NLSF_MSVQ_CB0_10_CDF[  91 ],
     &SKP_Silk_NLSF_MSVQ_CB0_10_CDF[ 100 ],
     &SKP_Silk_NLSF_MSVQ_CB0_10_CDF[ 109 ]
};

const SKP_int SKP_Silk_NLSF_MSVQ_CB0_10_CDF_middle_idx[ NLSF_MSVQ_CB0_10_STAGES ] =
{
      23,
       8,
       5,
       5,
       5,
       9
};

const SKP_int16 SKP_Silk_NLSF_MSVQ_CB0_10_rates_Q5[ NLSF_MSVQ_CB0_10_VECTORS ] =
{
              148,              167,
              169,              170,
              170,              173,
              173,              175,
              176,              176,
              176,              177,
              179,              181,
              181,              181,
              183,              183,
              183,              184,
              185,              185,
              185,              185,
              186,              189,
              189,              189,
              191,              191,
              191,              194,
              194,              194,
              195,              195,
              196,              198,
              199,              200,
              201,              201,
              202,              203,
              204,              204,
              205,              205,
              206,              209,
              210,              210,
              213,              214,
              218,              220,
              221,              226,
              231,              234,
              239,              256,
              256,              256,
              119,              123,
              123,              123,
              125,              126,
              126,              126,
              128,              130,
              130,              131,
              131,              135,
              138,              139,
               94,               94,
               95,               95,
               96,               98,
               98,               99,
               93,               93,
               95,               96,
               96,               97,
               98,              100,
               92,               93,
               97,               97,
               97,               97,
               98,               98,
              125,              126,
              126,              127,
              127,              128,
              128,              128,
              128,              128,
              129,              129,
              129,              130,
              130,              131
};

const SKP_int SKP_Silk_NLSF_MSVQ_CB0_10_ndelta_min_Q15[ 10 + 1 ] =
{
              563,
                3,
               22,
               20,
                3,
                3,
              132,
              119,
              358,
               86,
              964
};

const SKP_int16 SKP_Silk_NLSF_MSVQ_CB0_10_Q15[ 10 * NLSF_MSVQ_CB0_10_VECTORS ] =
{
             2210,             4023,
             6981,             9260,
            12573,            15687,
            19207,            22383,
            25981,            29142,
             3285,             4172,
             6116,            10856,
            15289,            16826,
            19701,            22010,
            24721,            29313,
             1554,             2511,
             6577,            10337,
            13837,            16511,
            20086,            23214,
            26480,            29464,
             3062,             4017,
             5771,            10037,
            13365,            14952,
            20140,            22891,
            25229,            29603,
             2085,             3457,
             5934,             8718,
            11501,            13670,
            17997,            21817,
            24935,            28745,
             2776,             4093,
             6421,            10413,
            15111,            16806,
            20825,            23826,
            26308,            29411,
             2717,             4034,
             5697,             8463,
            14301,            16354,
            19007,            23413,
            25812,            28506,
             2872,             3702,
             5881,            11034,
            17141,            18879,
            21146,            23451,
            25817,            29600,
             2999,             4015,
             7357,            11219,
            12866,            17307,
            20081,            22644,
            26774,            29107,
             2942,             3866,
             5918,            11915,
            13909,            16072,
            20453,            22279,
            27310,            29826,
             2271,             3527,
             6606,             9729,
            12943,            17382,
            20224,            22345,
            24602,            28290,
             2207,             3310,
             5844,             9339,
            11141,            15651,
            18576,            21177,
            25551,            28228,
             3963,             4975,
             6901,            11588,
            13466,            15577,
            19231,            21368,
            25510,            27759,
             2749,             3549,
             6966,            13808,
            15653,            17645,
            20090,            22599,
            26467,            28537,
             2126,             3504,
             5109,             9954,
            12550,            14620,
            19703,            21687,
            26457,            29106,
             3966,             5745,
             7442,             9757,
            14468,            16404,
            19135,            23048,
            25375,            28391,
             3197,             4751,
             6451,             9298,
            13038,            14874,
            17962,            20627,
            23835,            28464,
             3195,             4081,
             6499,            12252,
            14289,            16040,
            18357,            20730,
            26980,            29309,
             1533,             2471,
             4486,             7796,
            12332,            15758,
            19567,            22298,
            25673,            29051,
             2002,             2971,
             4985,             8083,
            13181,            15435,
            18237,            21517,
            24595,            28351,
             3808,             4925,
             6710,            10201,
            12011,            14300,
            18457,            20391,
            26525,            28956,
             2281,             3418,
             4979,             8726,
            15964,            18104,
            20250,            22771,
            25286,            28954,
             3051,             5479,
             7290,             9848,
            12744,            14503,
            18665,            23684,
            26065,            28947,
             2364,             3565,
             5502,             9621,
            14922,            16621,
            19005,            20996,
            26310,            29302,
             4093,             5212,
             6833,             9880,
            16303,            18286,
            20571,            23614,
            26067,            29128,
             2941,             3996,
             6038,            10638,
            12668,            14451,
            16798,            19392,
            26051,            28517,
             3863,             5212,
             7019,             9468,
            11039,            13214,
            19942,            22344,
            25126,            29539,
             4615,             6172,
             7853,            10252,
            12611,            14445,
            19719,            22441,
            24922,            29341,
             3566,             4512,
             6985,             8684,
            10544,            16097,
            18058,            22475,
            26066,            28167,
             4481,             5489,
             7432,            11414,
            13191,            15225,
            20161,            22258,
            26484,            29716,
             3320,             4320,
             6621,             9867,
            11581,            14034,
            21168,            23210,
            26588,            29903,
             3794,             4689,
             6916,             8655,
            10143,            16144,
            19568,            21588,
            27557,            29593,
             2446,             3276,
             5918,            12643,
            16601,            18013,
            21126,            23175,
            27300,            29634,
             2450,             3522,
             5437,             8560,
            15285,            19911,
            21826,            24097,
            26567,            29078,
             2580,             3796,
             5580,             8338,
             9969,            12675,
            18907,            22753,
            25450,            29292,
             3325,             4312,
             6241,             7709,
             9164,            14452,
            21665,            23797,
            27096,            29857,
             3338,             4163,
             7738,            11114,
            12668,            14753,
            16931,            22736,
            25671,            28093,
             3840,             4755,
             7755,            13471,
            15338,            17180,
            20077,            22353,
            27181,            29743,
             2504,             4079,
             8351,            12118,
            15046,            18595,
            21684,            24704,
            27519,            29937,
             5234,             6342,
             8267,            11821,
            15155,            16760,
            20667,            23488,
            25949,            29307,
             2681,             3562,
             6028,            10827,
            18458,            20458,
            22303,            24701,
            26912,            29956,
             3374,             4528,
             6230,             8256,
             9513,            12730,
            18666,            20720,
            26007,            28425,
             2731,             3629,
             8320,            12450,
            14112,            16431,
            18548,            22098,
            25329,            27718,
             3481,             4401,
             7321,             9319,
            11062,            13093,
            15121,            22315,
            26331,            28740,
             3577,             4945,
             6669,             8792,
            10299,            12645,
            19505,            24766,
            26996,            29634,
             4058,             5060,
             7288,            10190,
            11724,            13936,
            15849,            18539,
            26701,            29845,
             4262,             5390,
             7057,             8982,
            10187,            15264,
            20480,            22340,
            25958,            28072,
             3404,             4329,
             6629,             7946,
            10121,            17165,
            19640,            22244,
            25062,            27472,
             3157,             4168,
             6195,             9319,
            10771,            13325,
            15416,            19816,
            24672,            27634,
             2503,             3473,
             5130,             6767,
             8571,            14902,
            19033,            21926,
            26065,            28728,
             4133,             5102,
             7553,            10054,
            11757,            14924,
            17435,            20186,
            23987,            26272,
             4972,             6139,
             7894,             9633,
            11320,            14295,
            21737,            24306,
            26919,            29907,
             2958,             3816,
             6851,             9204,
            10895,            18052,
            20791,            23338,
            27556,            29609,
             5234,             6028,
             8034,            10154,
            11242,            14789,
            18948,            20966,
            26585,            29127,
             5241,             6838,
            10526,            12819,
            14681,            17328,
            19928,            22336,
            26193,            28697,
             3412,             4251,
             5988,             7094,
             9907,            18243,
            21669,            23777,
            26969,            29087,
             2470,             3217,
             7797,            15296,
            17365,            19135,
            21979,            24256,
            27322,            29442,
             4939,             5804,
             8145,            11809,
            13873,            15598,
            17234,            19423,
            26476,            29645,
             5051,             6167,
             8223,             9655,
            12159,            17995,
            20464,            22832,
            26616,            28462,
             4987,             5907,
             9319,            11245,
            13132,            15024,
            17485,            22687,
            26011,            28273,
             5137,             6884,
            11025,            14950,
            17191,            19425,
            21807,            24393,
            26938,            29288,
             7057,             7884,
             9528,            10483,
            10960,            14811,
            19070,            21675,
            25645,            28019,
             6759,             7160,
             8546,            11779,
            12295,            13023,
            16627,            21099,
            24697,            28287,
             3863,             9762,
            11068,            11445,
            12049,            13960,
            18085,            21507,
            25224,            28997,
              397,              335,
              651,             1168,
              640,              765,
              465,              331,
              214,             -194,
             -578,             -647,
             -657,              750,
              564,              613,
              549,              630,
              304,              -52,
              828,              922,
              443,              111,
              138,              124,
              169,               14,
              144,               83,
              132,               58,
             -413,             -752,
              869,              336,
              385,               69,
               56,              830,
             -227,             -266,
             -368,             -440,
            -1195,              163,
              126,             -228,
              802,              156,
              188,              120,
              376,               59,
             -358,             -558,
            -1326,             -254,
             -202,             -789,
              296,               92,
              -70,             -129,
             -718,            -1135,
              292,              -29,
             -631,              487,
             -157,             -153,
             -279,                2,
             -419,             -342,
              -34,             -514,
             -799,            -1571,
             -687,             -609,
             -546,             -130,
             -215,             -252,
             -446,             -574,
            -1337,              207,
              -72,               32,
              103,             -642,
              942,              733,
              187,               29,
             -211,             -814,
              143,              225,
               20,               24,
             -268,             -377,
             1623,             1133,
              667,              164,
              307,              366,
              187,               34,
               62,             -313,
             -832,            -1482,
            -1181,              483,
              -42,              -39,
             -450,            -1406,
             -587,              -52,
             -760,              334,
               98,              -60,
             -500,             -488,
            -1058,              299,
              131,             -250,
             -251,             -703,
             1037,              568,
             -413,             -265,
             1687,              573,
              345,              323,
               98,               61,
             -102,               31,
              135,              149,
              617,              365,
              -39,               34,
             -611,             1201,
             1421,              736,
             -414,             -393,
             -492,             -343,
             -316,             -532,
              528,              172,
               90,              322,
             -294,             -319,
             -541,              503,
              639,              401,
                1,             -149,
              -73,             -167,
              150,              118,
              308,              218,
              121,              195,
             -143,             -261,
            -1013,             -802,
              387,              436,
              130,             -427,
             -448,             -681,
              123,              -87,
             -251,             -113,
              274,              310,
              445,              501,
              354,              272,
              141,             -285,
              569,              656,
               37,              -49,
              251,             -386,
             -263,             1122,
              604,              606,
              336,               95,
               34,                0,
               85,              180,
              207,             -367,
             -622,             1070,
               -6,              -79,
             -160,              -92,
             -137,             -276,
             -323,             -371,
             -696,            -1036,
              407,              102,
              -86,             -214,
             -482,             -647,
              -28,             -291,
              -97,             -180,
             -250,             -435,
              -18,              -76,
             -332,              410,
              407,              168,
              539,              411,
              254,              111,
               58,             -145,
              200,               30,
              187,              116,
              131,             -367,
             -475,              781,
             -559,              561,
              195,             -115,
                8,             -168,
               30,               55,
             -122,              131,
               82,               -5,
             -273,              -50,
             -632,              668,
                4,               32,
              -26,             -279,
              315,              165,
              197,              377,
              155,              -41,
             -138,             -324,
             -109,             -617,
              360,               98,
              -53,             -319,
             -114,             -245,
              -82,              507,
              468,              263,
             -137,             -389,
              652,              354,
              -18,             -227,
             -462,             -135,
              317,               53,
              -16,               66,
              -72,             -126,
             -356,             -347,
             -328,              -72,
             -337,              324,
              152,              349,
              169,             -196,
              179,              254,
              260,              325,
              -74,              -80,
               75,              -31,
              270,              275,
               87,              278,
             -446,             -301,
              309,               71,
              -25,             -242,
              516,              161,
             -162,              -83,
              329,              230,
             -311,             -259,
              177,              -26,
             -462,               89,
              257,                6,
             -130,              -93,
             -456,             -317,
             -221,             -206,
             -417,             -182,
              -74,              234,
               48,              261,
              359,              231,
              258,               85,
             -282,              252,
             -147,             -222,
              251,             -207,
              443,              123,
             -417,              -36,
              273,             -241,
              240,             -112,
               44,             -167,
              126,             -124,
              -77,               58,
             -401,              333,
             -118,               82,
              126,              151,
             -433,              359,
             -130,             -102,
              131,             -244,
               86,               85,
             -462,              414,
             -240,               16,
              145,               28,
             -205,             -481,
              373,              293,
              -72,             -174,
               62,              259,
               -8,              -18,
              362,              233,
              185,               43,
              278,               27,
              193,              570,
             -248,              189,
               92,               31,
             -275,               -3,
              243,              176,
              438,              209,
              206,              -51,
               79,              109,
              168,             -185,
             -308,              -68,
             -618,              385,
             -310,             -108,
             -164,              165,
               61,             -152,
             -101,             -412,
             -268,             -257,
              -40,              -20,
              -28,             -158,
             -301,              271,
              380,             -338,
             -367,             -132,
               64,              114,
             -131,             -225,
             -156,             -260,
              -63,             -116,
              155,             -586,
             -202,              254,
             -287,              178,
              227,             -106,
             -294,              164,
              298,             -100,
              185,              317,
              193,              -45,
               28,               80,
              -87,             -433,
               22,              -48,
               48,             -237,
             -229,             -139,
              120,             -364,
              268,             -136,
              396,              125,
              130,              -89,
             -272,              118,
             -256,              -68,
             -451,              488,
              143,             -165,
              -48,             -190,
              106,              219,
               47,              435,
              245,               97,
               75,             -418,
              121,             -187,
              570,             -200,
             -351,              225,
              -21,             -217,
              234,             -111,
              194,               14,
              242,              118,
              140,             -397,
              355,              361,
              -45,             -195
};

const SKP_Silk_NLSF_CBS SKP_Silk_NLSF_CB0_10_Stage_info[ NLSF_MSVQ_CB0_10_STAGES ] =
{
        {  64, &SKP_Silk_NLSF_MSVQ_CB0_10_Q15[ 10 *   0 ], &SKP_Silk_NLSF_MSVQ_CB0_10_rates_Q5[   0 ] },
        {  16, &SKP_Silk_NLSF_MSVQ_CB0_10_Q15[ 10 *  64 ], &SKP_Silk_NLSF_MSVQ_CB0_10_rates_Q5[  64 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_10_Q15[ 10 *  80 ], &SKP_Silk_NLSF_MSVQ_CB0_10_rates_Q5[  80 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_10_Q15[ 10 *  88 ], &SKP_Silk_NLSF_MSVQ_CB0_10_rates_Q5[  88 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_10_Q15[ 10 *  96 ], &SKP_Silk_NLSF_MSVQ_CB0_10_rates_Q5[  96 ] },
        {  16, &SKP_Silk_NLSF_MSVQ_CB0_10_Q15[ 10 * 104 ], &SKP_Silk_NLSF_MSVQ_CB0_10_rates_Q5[ 104 ] }
};

const SKP_Silk_NLSF_CB_struct SKP_Silk_NLSF_CB0_10 =
{
        NLSF_MSVQ_CB0_10_STAGES,
        SKP_Silk_NLSF_CB0_10_Stage_info,
        SKP_Silk_NLSF_MSVQ_CB0_10_ndelta_min_Q15,
        SKP_Silk_NLSF_MSVQ_CB0_10_CDF,
        SKP_Silk_NLSF_MSVQ_CB0_10_CDF_start_ptr,
        SKP_Silk_NLSF_MSVQ_CB0_10_CDF_middle_idx
};















#ifndef SKP_SILK_TABLES_NLSF_CB0_16_H
#define SKP_SILK_TABLES_NLSF_CB0_16_H



#ifdef __cplusplus
extern "C"
{
#endif

#define NLSF_MSVQ_CB0_16_STAGES       10
#define NLSF_MSVQ_CB0_16_VECTORS      216


extern const SKP_uint16         SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ NLSF_MSVQ_CB0_16_VECTORS + NLSF_MSVQ_CB0_16_STAGES ];
extern const SKP_uint16 * const SKP_Silk_NLSF_MSVQ_CB0_16_CDF_start_ptr[                  NLSF_MSVQ_CB0_16_STAGES ];
extern const SKP_int            SKP_Silk_NLSF_MSVQ_CB0_16_CDF_middle_idx[                 NLSF_MSVQ_CB0_16_STAGES ];

#ifdef __cplusplus
}
#endif

#endif



const SKP_uint16 SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ NLSF_MSVQ_CB0_16_VECTORS + NLSF_MSVQ_CB0_16_STAGES ] =
{
            0,
         1449,
         2749,
         4022,
         5267,
         6434,
         7600,
         8647,
         9695,
        10742,
        11681,
        12601,
        13444,
        14251,
        15008,
        15764,
        16521,
        17261,
        18002,
        18710,
        19419,
        20128,
        20837,
        21531,
        22225,
        22919,
        23598,
        24277,
        24956,
        25620,
        26256,
        26865,
        27475,
        28071,
        28667,
        29263,
        29859,
        30443,
        31026,
        31597,
        32168,
        32727,
        33273,
        33808,
        34332,
        34855,
        35379,
        35902,
        36415,
        36927,
        37439,
        37941,
        38442,
        38932,
        39423,
        39914,
        40404,
        40884,
        41364,
        41844,
        42324,
        42805,
        43285,
        43754,
        44224,
        44694,
        45164,
        45623,
        46083,
        46543,
        46993,
        47443,
        47892,
        48333,
        48773,
        49213,
        49653,
        50084,
        50515,
        50946,
        51377,
        51798,
        52211,
        52614,
        53018,
        53422,
        53817,
        54212,
        54607,
        55002,
        55388,
        55775,
        56162,
        56548,
        56910,
        57273,
        57635,
        57997,
        58352,
        58698,
        59038,
        59370,
        59702,
        60014,
        60325,
        60630,
        60934,
        61239,
        61537,
        61822,
        62084,
        62346,
        62602,
        62837,
        63072,
        63302,
        63517,
        63732,
        63939,
        64145,
        64342,
        64528,
        64701,
        64867,
        65023,
        65151,
        65279,
        65407,
        65535,
            0,
         5099,
         9982,
        14760,
        19538,
        24213,
        28595,
        32976,
        36994,
        41012,
        44944,
        48791,
        52557,
        56009,
        59388,
        62694,
        65535,
            0,
         9955,
        19697,
        28825,
        36842,
        44686,
        52198,
        58939,
        65535,
            0,
         8949,
        17335,
        25720,
        33926,
        41957,
        49987,
        57845,
        65535,
            0,
         9724,
        18642,
        26998,
        35355,
        43532,
        51534,
        59365,
        65535,
            0,
         8750,
        17499,
        26249,
        34448,
        42471,
        50494,
        58178,
        65535,
            0,
         8730,
        17273,
        25816,
        34176,
        42536,
        50203,
        57869,
        65535,
            0,
         8769,
        17538,
        26307,
        34525,
        42742,
        50784,
        58319,
        65535,
            0,
         8736,
        17101,
        25466,
        33653,
        41839,
        50025,
        57864,
        65535,
            0,
         4368,
         8735,
        12918,
        17100,
        21283,
        25465,
        29558,
        33651,
        37744,
        41836,
        45929,
        50022,
        54027,
        57947,
        61782,
        65535
};

const SKP_uint16 * const SKP_Silk_NLSF_MSVQ_CB0_16_CDF_start_ptr[ NLSF_MSVQ_CB0_16_STAGES ] =
{
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[   0 ],
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ 129 ],
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ 146 ],
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ 155 ],
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ 164 ],
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ 173 ],
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ 182 ],
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ 191 ],
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ 200 ],
     &SKP_Silk_NLSF_MSVQ_CB0_16_CDF[ 209 ]
};

const SKP_int SKP_Silk_NLSF_MSVQ_CB0_16_CDF_middle_idx[ NLSF_MSVQ_CB0_16_STAGES ] =
{
      42,
       8,
       4,
       5,
       5,
       5,
       5,
       5,
       5,
       9
};

const SKP_int16 SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ NLSF_MSVQ_CB0_16_VECTORS ] =
{
              176,              181,
              182,              183,
              186,              186,
              191,              191,
              191,              196,
              197,              201,
              203,              206,
              206,              206,
              207,              207,
              209,              209,
              209,              209,
              210,              210,
              210,              211,
              211,              211,
              212,              214,
              216,              216,
              217,              217,
              217,              217,
              218,              218,
              219,              219,
              220,              221,
              222,              223,
              223,              223,
              223,              224,
              224,              224,
              225,              225,
              226,              226,
              226,              226,
              227,              227,
              227,              227,
              227,              227,
              228,              228,
              228,              228,
              229,              229,
              229,              230,
              230,              230,
              231,              231,
              231,              231,
              232,              232,
              232,              232,
              233,              234,
              235,              235,
              235,              236,
              236,              236,
              236,              237,
              237,              237,
              237,              240,
              240,              240,
              240,              241,
              242,              243,
              244,              244,
              247,              247,
              248,              248,
              248,              249,
              251,              255,
              255,              256,
              260,              260,
              261,              264,
              264,              266,
              266,              268,
              271,              274,
              276,              279,
              288,              288,
              288,              288,
              118,              120,
              121,              121,
              122,              125,
              125,              129,
              129,              130,
              131,              132,
              136,              137,
              138,              145,
               87,               88,
               91,               97,
               98,              100,
              105,              106,
               92,               95,
               95,               96,
               97,               97,
               98,               99,
               88,               92,
               95,               95,
               96,               97,
               98,              109,
               93,               93,
               93,               96,
               97,               97,
               99,              101,
               93,               94,
               94,               95,
               95,               99,
               99,               99,
               93,               93,
               93,               96,
               96,               97,
              100,              102,
               93,               95,
               95,               96,
               96,               96,
               98,               99,
              125,              125,
              127,              127,
              127,              127,
              128,              128,
              128,              128,
              128,              128,
              129,              130,
              131,              132
};

const SKP_int SKP_Silk_NLSF_MSVQ_CB0_16_ndelta_min_Q15[ 16 + 1 ] =
{
              266,
                3,
               40,
                3,
                3,
               16,
               78,
               89,
              107,
              141,
              188,
              146,
              272,
              240,
              235,
              215,
              632
};

const SKP_int16 SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * NLSF_MSVQ_CB0_16_VECTORS ] =
{
             1170,             2278,             3658,             5374,
             7666,             9113,            11298,            13304,
            15371,            17549,            19587,            21487,
            23798,            26038,            28318,            30201,
             1628,             2334,             4115,             6036,
             7818,             9544,            11777,            14021,
            15787,            17408,            19466,            21261,
            22886,            24565,            26714,            28059,
             1724,             2670,             4056,             6532,
             8357,            10119,            12093,            14061,
            16491,            18795,            20417,            22402,
            24251,            26224,            28410,            29956,
             1493,             3427,             4789,             6399,
             8435,            10168,            12000,            14066,
            16229,            18210,            20040,            22098,
            24153,            26095,            28183,            30121,
             1119,             2089,             4295,             6245,
             8691,            10741,            12688,            15057,
            17028,            18792,            20717,            22514,
            24497,            26548,            28619,            30630,
             1363,             2417,             3927,             5556,
             7422,             9315,            11879,            13767,
            16143,            18520,            20458,            22578,
            24539,            26436,            28318,            30318,
             1122,             2503,             5216,             7148,
             9310,            11078,            13175,            14800,
            16864,            18700,            20436,            22488,
            24572,            26602,            28555,            30426,
              600,             1317,             2970,             5609,
             7694,             9784,            12169,            14087,
            16379,            18378,            20551,            22686,
            24739,            26697,            28646,            30355,
              941,             1882,             4274,             5540,
             8482,             9858,            11940,            14287,
            16091,            18501,            20326,            22612,
            24711,            26638,            28814,            30430,
              635,             1699,             4376,             5948,
             8097,            10115,            12274,            14178,
            16111,            17813,            19695,            21773,
            23927,            25866,            28022,            30134,
             1408,             2222,             3524,             5615,
             7345,             8849,            10989,            12772,
            15352,            17026,            18919,            21062,
            23329,            25215,            27209,            29023,
              701,             1307,             3548,             6301,
             7744,             9574,            11227,            12978,
            15170,            17565,            19775,            22097,
            24230,            26335,            28377,            30231,
             1752,             2364,             4879,             6569,
             7813,             9796,            11199,            14290,
            15795,            18000,            20396,            22417,
            24308,            26124,            28360,            30633,
              901,             1629,             3356,             4635,
             7256,             8767,             9971,            11558,
            15215,            17544,            19523,            21852,
            23900,            25978,            28133,            30184,
              981,             1669,             3323,             4693,
             6213,             8692,            10614,            12956,
            15211,            17711,            19856,            22122,
            24344,            26592,            28723,            30481,
             1607,             2577,             4220,             5512,
             8532,            10388,            11627,            13671,
            15752,            17199,            19840,            21859,
            23494,            25786,            28091,            30131,
              811,             1471,             3144,             5041,
             7430,             9389,            11174,            13255,
            15157,            16741,            19583,            22167,
            24115,            26142,            28383,            30395,
             1543,             2144,             3629,             6347,
             7333,             9339,            10710,            13596,
            15099,            17340,            20102,            21886,
            23732,            25637,            27818,            29917,
              492,             1185,             2940,             5488,
             7095,             8751,            11596,            13579,
            16045,            18015,            20178,            22127,
            24265,            26406,            28484,            30357,
             1547,             2282,             3693,             6341,
             7758,             9607,            11848,            13236,
            16564,            18069,            19759,            21404,
            24110,            26606,            28786,            30655,
              685,             1338,             3409,             5262,
             6950,             9222,            11414,            14523,
            16337,            17893,            19436,            21298,
            23293,            25181,            27973,            30520,
              887,             1581,             3057,             4318,
             7192,             8617,            10047,            13106,
            16265,            17893,            20233,            22350,
            24379,            26384,            28314,            30189,
             2285,             3745,             5662,             7576,
             9323,            11320,            13239,            15191,
            17175,            19225,            21108,            22972,
            24821,            26655,            28561,            30460,
             1496,             2108,             3448,             6898,
             8328,             9656,            11252,            12823,
            14979,            16482,            18180,            20085,
            22962,            25160,            27705,            29629,
              575,             1261,             3861,             6627,
             8294,            10809,            12705,            14768,
            17076,            19047,            20978,            23055,
            24972,            26703,            28720,            30345,
             1682,             2213,             3882,             6238,
             7208,             9646,            10877,            13431,
            14805,            16213,            17941,            20873,
            23550,            25765,            27756,            29461,
              888,             1616,             3924,             5195,
             7206,             8647,             9842,            11473,
            16067,            18221,            20343,            22774,
            24503,            26412,            28054,            29731,
              805,             1454,             2683,             4472,
             7936,             9360,            11398,            14345,
            16205,            17832,            19453,            21646,
            23899,            25928,            28387,            30463,
             1640,             2383,             3484,             5082,
             6032,             8606,            11640,            12966,
            15842,            17368,            19346,            21182,
            23638,            25889,            28368,            30299,
             1632,             2204,             4510,             7580,
             8718,            10512,            11962,            14096,
            15640,            17194,            19143,            22247,
            24563,            26561,            28604,            30509,
             2043,             2612,             3985,             6851,
             8038,             9514,            10979,            12789,
            15426,            16728,            18899,            20277,
            22902,            26209,            28711,            30618,
             2224,             2798,             4465,             5320,
             7108,             9436,            10986,            13222,
            14599,            18317,            20141,            21843,
            23601,            25700,            28184,            30582,
              835,             1541,             4083,             5769,
             7386,             9399,            10971,            12456,
            15021,            18642,            20843,            23100,
            25292,            26966,            28952,            30422,
             1795,             2343,             4809,             5896,
             7178,             8545,            10223,            13370,
            14606,            16469,            18273,            20736,
            23645,            26257,            28224,            30390,
             1734,             2254,             4031,             5188,
             6506,             7872,             9651,            13025,
            14419,            17305,            19495,            22190,
            24403,            26302,            28195,            30177,
             1841,             2349,             3968,             4764,
             6376,             9825,            11048,            13345,
            14682,            16252,            18183,            21363,
            23918,            26156,            28031,            29935,
             1432,             2047,             5631,             6927,
             8198,             9675,            11358,            13506,
            14802,            16419,            18339,            22019,
            24124,            26177,            28130,            30586,
             1730,             2320,             3744,             4808,
             6007,             9666,            10997,            13622,
            15234,            17495,            20088,            22002,
            23603,            25400,            27379,            29254,
             1267,             1915,             5483,             6812,
             8229,             9919,            11589,            13337,
            14747,            17965,            20552,            22167,
            24519,            26819,            28883,            30642,
             1526,             2229,             4240,             7388,
             8953,            10450,            11899,            13718,
            16861,            18323,            20379,            22672,
            24797,            26906,            28906,            30622,
             2175,             2791,             4104,             6875,
             8612,             9798,            12152,            13536,
            15623,            17682,            19213,            21060,
            24382,            26760,            28633,            30248,
              454,             1231,             4339,             5738,
             7550,             9006,            10320,            13525,
            16005,            17849,            20071,            21992,
            23949,            26043,            28245,            30175,
             2250,             2791,             4230,             5283,
             6762,            10607,            11879,            13821,
            15797,            17264,            20029,            22266,
            24588,            26437,            28244,            30419,
             1696,             2216,             4308,             8385,
             9766,            11030,            12556,            14099,
            16322,            17640,            19166,            20590,
            23967,            26858,            28798,            30562,
             2452,             3236,             4369,             6118,
             7156,             9003,            11509,            12796,
            15749,            17291,            19491,            22241,
            24530,            26474,            28273,            30073,
             1811,             2541,             3555,             5480,
             9123,            10527,            11894,            13659,
            15262,            16899,            19366,            21069,
            22694,            24314,            27256,            29983,
             1553,             2246,             4559,             5500,
             6754,             7874,            11739,            13571,
            15188,            17879,            20281,            22510,
            24614,            26649,            28786,            30755,
             1982,             2768,             3834,             5964,
             8732,             9908,            11797,            14813,
            16311,            17946,            21097,            22851,
            24456,            26304,            28166,            29755,
             1824,             2529,             3817,             5449,
             6854,             8714,            10381,            12286,
            14194,            15774,            19524,            21374,
            23695,            26069,            28096,            30212,
             2212,             2854,             3947,             5898,
             9930,            11556,            12854,            14788,
            16328,            17700,            20321,            22098,
            23672,            25291,            26976,            28586,
             2023,             2599,             4024,             4916,
             6613,            11149,            12457,            14626,
            16320,            17822,            19673,            21172,
            23115,            26051,            28825,            30758,
             1628,             2206,             3467,             4364,
             8679,            10173,            11864,            13679,
            14998,            16938,            19207,            21364,
            23850,            26115,            28124,            30273,
             2014,             2603,             4114,             7254,
             8516,            10043,            11822,            13503,
            16329,            17826,            19697,            21280,
            23151,            24661,            26807,            30161,
             2376,             2980,             4422,             5770,
             7016,             9723,            11125,            13516,
            15485,            16985,            19160,            20587,
            24401,            27180,            29046,            30647,
             2454,             3502,             4624,             6019,
             7632,             8849,            10792,            13964,
            15523,            17085,            19611,            21238,
            22856,            25108,            28106,            29890,
             1573,             2274,             3308,             5999,
             8977,            10104,            12457,            14258,
            15749,            18180,            19974,            21253,
            23045,            25058,            27741,            30315,
             1943,             2730,             4140,             6160,
             7491,             8986,            11309,            12775,
            14820,            16558,            17909,            19757,
            21512,            23605,            27274,            29527,
             2021,             2582,             4494,             5835,
             6993,             8245,             9827,            14733,
            16462,            17894,            19647,            21083,
            23764,            26667,            29072,            30990,
             1052,             1775,             3218,             4378,
             7666,             9403,            11248,            13327,
            14972,            17962,            20758,            22354,
            25071,            27209,            29001,            30609,
             2218,             2866,             4223,             5352,
             6581,             9980,            11587,            13121,
            15193,            16583,            18386,            20080,
            22013,            25317,            28127,            29880,
             2146,             2840,             4397,             5840,
             7449,             8721,            10512,            11936,
            13595,            17253,            19310,            20891,
            23417,            25627,            27749,            30231,
             1972,             2619,             3756,             6367,
             7641,             8814,            12286,            13768,
            15309,            18036,            19557,            20904,
            22582,            24876,            27800,            30440,
             2005,             2577,             4272,             7373,
             8558,            10223,            11770,            13402,
            16502,            18000,            19645,            21104,
            22990,            26806,            29505,            30942,
             1153,             1822,             3724,             5443,
             6990,             8702,            10289,            11899,
            13856,            15315,            17601,            21064,
            23692,            26083,            28586,            30639,
             1304,             1869,             3318,             7195,
             9613,            10733,            12393,            13728,
            15822,            17474,            18882,            20692,
            23114,            25540,            27684,            29244,
             2093,             2691,             4018,             6658,
             7947,             9147,            10497,            11881,
            15888,            17821,            19333,            21233,
            23371,            25234,            27553,            29998,
              575,             1331,             5304,             6910,
             8425,            10086,            11577,            13498,
            16444,            18527,            20565,            22847,
            24914,            26692,            28759,            30157,
             1435,             2024,             3283,             4156,
             7611,            10592,            12049,            13927,
            15459,            18413,            20495,            22270,
            24222,            26093,            28065,            30099,
             1632,             2168,             5540,             7478,
             8630,            10391,            11644,            14321,
            15741,            17357,            18756,            20434,
            22799,            26060,            28542,            30696,
             1407,             2245,             3405,             5639,
             9419,            10685,            12104,            13495,
            15535,            18357,            19996,            21689,
            24351,            26550,            28853,            30564,
             1675,             2226,             4005,             8223,
             9975,            11155,            12822,            14316,
            16504,            18137,            19574,            21050,
            22759,            24912,            28296,            30634,
             1080,             1614,             3622,             7565,
             8748,            10303,            11713,            13848,
            15633,            17434,            19761,            21825,
            23571,            25393,            27406,            29063,
             1693,             2229,             3456,             4354,
             5670,            10890,            12563,            14167,
            15879,            17377,            19817,            21971,
            24094,            26131,            28298,            30099,
             2042,             2959,             4195,             5740,
             7106,             8267,            11126,            14973,
            16914,            18295,            20532,            21982,
            23711,            25769,            27609,            29351,
              984,             1612,             3808,             5265,
             6885,             8411,             9547,            10889,
            12522,            16520,            19549,            21639,
            23746,            26058,            28310,            30374,
             2036,             2538,             4166,             7761,
             9146,            10412,            12144,            13609,
            15588,            17169,            18559,            20113,
            21820,            24313,            28029,            30612,
             1871,             2355,             4061,             5143,
             7464,            10129,            11941,            15001,
            16680,            18354,            19957,            22279,
            24861,            26872,            28988,            30615,
             2566,             3161,             4643,             6227,
             7406,             9970,            11618,            13416,
            15889,            17364,            19121,            20817,
            22592,            24720,            28733,            31082,
             1700,             2327,             4828,             5939,
             7567,             9154,            11087,            12771,
            14209,            16121,            20222,            22671,
            24648,            26656,            28696,            30745,
             3169,             3873,             5046,             6868,
             8184,             9480,            12335,            14068,
            15774,            17971,            20231,            21711,
            23520,            25245,            27026,            28730,
             1564,             2391,             4229,             6730,
             8905,            10459,            13026,            15033,
            17265,            19809,            21849,            23741,
            25490,            27312,            29061,            30527,
             2864,             3559,             4719,             6441,
             9592,            11055,            12763,            14784,
            16428,            18164,            20486,            22262,
            24183,            26263,            28383,            30224,
             2673,             3449,             4581,             5983,
             6863,             8311,            12464,            13911,
            15738,            17791,            19416,            21182,
            24025,            26561,            28723,            30440,
             2419,             3049,             4274,             6384,
             8564,             9661,            11288,            12676,
            14447,            17578,            19816,            21231,
            23099,            25270,            26899,            28926,
             1278,             2001,             3000,             5353,
             9995,            11777,            13018,            14570,
            16050,            17762,            19982,            21617,
            23371,            25083,            27656,            30172,
              932,             1624,             2798,             4570,
             8592,             9988,            11552,            13050,
            16921,            18677,            20415,            22810,
            24817,            26819,            28804,            30385,
             2324,             2973,             4156,             5702,
             6919,             8806,            10259,            12503,
            15015,            16567,            19418,            21375,
            22943,            24550,            27024,            29849,
             1564,             2373,             3455,             4907,
             5975,             7436,            11786,            14505,
            16107,            18148,            20019,            21653,
            23740,            25814,            28578,            30372,
             3025,             3729,             4866,             6520,
             9487,            10943,            12358,            14258,
            16174,            17501,            19476,            21408,
            23227,            24906,            27347,            29407,
             1270,             1965,             6802,             7995,
             9204,            10828,            12507,            14230,
            15759,            17860,            20369,            22502,
            24633,            26514,            28535,            30525,
             2210,             2749,             4266,             7487,
             9878,            11018,            12823,            14431,
            16247,            18626,            20450,            22054,
            23739,            25291,            27074,            29169,
             1275,             1926,             4330,             6573,
             8441,            10920,            13260,            15008,
            16927,            18573,            20644,            22217,
            23983,            25474,            27372,            28645,
             3015,             3670,             5086,             6372,
             7888,             9309,            10966,            12642,
            14495,            16172,            18080,            19972,
            22454,            24899,            27362,            29975,
             2882,             3733,             5113,             6482,
             8125,             9685,            11598,            13288,
            15405,            17192,            20178,            22426,
            24801,            27014,            29212,            30811,
             2300,             2968,             4101,             5442,
             6327,             7910,            12455,            13862,
            15747,            17505,            19053,            20679,
            22615,            24658,            27499,            30065,
             2257,             2940,             4430,             5991,
             7042,             8364,             9414,            11224,
            15723,            17420,            19253,            21469,
            23915,            26053,            28430,            30384,
             1227,             2045,             3818,             5011,
             6990,             9231,            11024,            13011,
            17341,            19017,            20583,            22799,
            25195,            26876,            29351,            30805,
             1354,             1924,             3789,             8077,
            10453,            11639,            13352,            14817,
            16743,            18189,            20095,            22014,
            24593,            26677,            28647,            30256,
             3142,             4049,             6197,             7417,
             8753,            10156,            11533,            13181,
            15947,            17655,            19606,            21402,
            23487,            25659,            28123,            30304,
             1317,             2263,             4725,             7611,
             9667,            11634,            14143,            16258,
            18724,            20698,            22379,            24007,
            25775,            27251,            28930,            30593,
             1570,             2323,             3818,             6215,
             9893,            11556,            13070,            14631,
            16152,            18290,            21386,            23346,
            25114,            26923,            28712,            30168,
             2297,             3905,             6287,             8558,
            10668,            12766,            15019,            17102,
            19036,            20677,            22341,            23871,
            25478,            27085,            28851,            30520,
             1915,             2507,             4033,             5749,
             7059,             8871,            10659,            12198,
            13937,            15383,            16869,            18707,
            23175,            25818,            28514,            30501,
             2404,             2918,             5190,             6252,
             7426,             9887,            12387,            14795,
            16754,            18368,            20338,            22003,
            24236,            26456,            28490,            30397,
             1621,             2227,             3479,             5085,
             9425,            12892,            14246,            15652,
            17205,            18674,            20446,            22209,
            23778,            25867,            27931,            30093,
             1869,             2390,             4105,             7021,
            11221,            12775,            14059,            15590,
            17024,            18608,            20595,            22075,
            23649,            25154,            26914,            28671,
             2551,             3252,             4688,             6562,
             7869,             9125,            10475,            11800,
            15402,            18780,            20992,            22555,
            24289,            25968,            27465,            29232,
             2705,             3493,             4735,             6360,
             7905,             9352,            11538,            13430,
            15239,            16919,            18619,            20094,
            21800,            23342,            25200,            29257,
             2166,             2791,             4011,             5081,
             5896,             9038,            13407,            14703,
            16543,            18189,            19896,            21857,
            24872,            26971,            28955,            30514,
             1865,             3021,             4696,             6534,
             8343,             9914,            12789,            14103,
            16533,            17729,            21340,            22439,
            24873,            26330,            28428,            30154,
             3369,             4345,             6573,             8763,
            10309,            11713,            13367,            14784,
            16483,            18145,            19839,            21247,
            23292,            25477,            27555,            29447,
             1265,             2184,             5443,             7893,
            10591,            13139,            15105,            16639,
            18402,            19826,            21419,            22995,
            24719,            26437,            28363,            30125,
             1584,             2004,             3535,             4450,
             8662,            10764,            12832,            14978,
            16972,            18794,            20932,            22547,
            24636,            26521,            28701,            30567,
             3419,             4528,             6602,             7890,
             9508,            10875,            12771,            14357,
            16051,            18330,            20630,            22490,
            25070,            26936,            28946,            30542,
             1726,             2252,             4597,             6950,
             8379,             9823,            11363,            12794,
            14306,            15476,            16798,            18018,
            21671,            25550,            28148,            30367,
             3385,             3870,             5307,             6388,
             7141,             8684,            12695,            14939,
            16480,            18277,            20537,            22048,
            23947,            25965,            28214,            29956,
             2771,             3306,             4450,             5560,
             6453,             9493,            13548,            14754,
            16743,            18447,            20028,            21736,
            23746,            25353,            27141,            29066,
             3028,             3900,             6617,             7893,
             9211,            10480,            12047,            13583,
            15182,            16662,            18502,            20092,
            22190,            24358,            26302,            28957,
             2000,             2550,             4067,             6837,
             9628,            11002,            12594,            14098,
            15589,            17195,            18679,            20099,
            21530,            23085,            24641,            29022,
             2844,             3302,             5103,             6107,
             6911,             8598,            12416,            14054,
            16026,            18567,            20672,            22270,
            23952,            25771,            27658,            30026,
             4043,             5150,             7268,             9056,
            10916,            12638,            14543,            16184,
            17948,            19691,            21357,            22981,
            24825,            26591,            28479,            30233,
             2109,             2625,             4320,             5525,
             7454,            10220,            12980,            14698,
            17627,            19263,            20485,            22381,
            24279,            25777,            27847,            30458,
             1550,             2667,             6473,             9496,
            10985,            12352,            13795,            15233,
            17099,            18642,            20461,            22116,
            24197,            26291,            28403,            30132,
             2411,             3084,             4145,             5394,
             6367,             8154,            13125,            16049,
            17561,            19125,            21258,            22762,
            24459,            26317,            28255,            29702,
             4159,             4516,             5956,             7635,
             8254,             8980,            11208,            14133,
            16210,            17875,            20196,            21864,
            23840,            25747,            28058,            30012,
             2026,             2431,             2845,             3618,
             7950,             9802,            12721,            14460,
            16576,            18984,            21376,            23319,
            24961,            26718,            28971,            30640,
             3429,             3833,             4472,             4912,
             7723,            10386,            12981,            15322,
            16699,            18807,            20778,            22551,
            24627,            26494,            28334,            30482,
             4740,             5169,             5796,             6485,
             6998,             8830,            11777,            14414,
            16831,            18413,            20789,            22369,
            24236,            25835,            27807,            30021,
              150,              168,              -17,             -107,
             -142,             -229,             -320,             -406,
             -503,             -620,             -867,             -935,
             -902,             -680,             -398,             -114,
             -398,             -355,               49,              255,
              114,              260,              399,              264,
              317,              431,              514,              531,
              435,              356,              238,              106,
              -43,              -36,             -169,             -224,
             -391,             -633,             -776,             -970,
             -844,             -455,             -181,              -12,
               85,               85,              164,              195,
              122,               85,             -158,             -640,
             -903,                9,                7,             -124,
              149,               32,              220,              369,
              242,              115,               79,               84,
             -146,             -216,              -70,             1024,
              751,              574,              440,              377,
              352,              203,               30,               16,
               -3,               81,              161,              100,
             -148,             -176,              933,              750,
              404,              171,               -2,             -146,
             -411,             -442,             -541,             -552,
             -442,             -269,             -240,              -52,
              603,              635,              405,              178,
              215,               19,             -153,             -167,
             -290,             -219,              151,              271,
              151,              119,              303,              266,
              100,               69,             -293,             -657,
              939,              659,              442,              351,
              132,               98,              -16,               -1,
             -135,             -200,             -223,              -89,
              167,              154,              172,              237,
              -45,             -183,             -228,             -486,
              263,              608,              158,             -125,
             -390,             -227,             -118,               43,
             -457,             -392,             -769,             -840,
               20,             -117,             -194,             -189,
             -173,             -173,              -33,               32,
              174,              144,              115,              167,
               57,               44,               14,              147,
               96,              -54,             -142,             -129,
             -254,             -331,              304,              310,
              -52,             -419,             -846,            -1060,
              -88,             -123,             -202,             -343,
             -554,             -961,             -951,              327,
              159,               81,              255,              227,
              120,              203,              256,              192,
              164,              224,              290,              195,
              216,              209,              128,              832,
             1028,              889,              698,              504,
              408,              355,              218,               32,
             -115,              -84,             -276,             -100,
             -312,             -484,              899,              682,
              465,              456,              241,              -12,
             -275,             -425,             -461,             -367,
              -33,              -28,             -102,             -194,
             -527,              863,              906,              463,
              245,               13,             -212,             -305,
             -105,              163,              279,              176,
               93,               67,              115,              192,
               61,              -50,             -132,             -175,
             -224,             -271,             -629,             -252,
             1158,              972,              638,              280,
              300,              326,              143,             -152,
             -214,             -287,               53,              -42,
             -236,             -352,             -423,             -248,
             -129,             -163,             -178,             -119,
               85,               57,              514,              382,
              374,              402,              424,              423,
              271,              197,               97,               40,
               39,              -97,             -191,             -164,
             -230,             -256,             -410,              396,
              327,              127,               10,             -119,
             -167,             -291,             -274,             -141,
              -99,             -226,             -218,             -139,
             -224,             -209,             -268,             -442,
             -413,              222,               58,              521,
              344,              258,               76,              -42,
             -142,             -165,             -123,              -92,
               47,                8,               -3,             -191,
              -11,             -164,             -167,             -351,
             -740,              311,              538,              291,
              184,               29,             -105,                9,
              -30,              -54,              -17,              -77,
             -271,             -412,             -622,             -648,
              476,              186,              -66,             -197,
              -73,              -94,              -15,               47,
               28,              112,              -58,              -33,
               65,               19,               84,               86,
              276,              114,              472,              786,
              799,              625,              415,              178,
              -35,              -26,                5,                9,
               83,               39,               37,               39,
             -184,             -374,             -265,             -362,
             -501,              337,              716,              478,
              -60,             -125,             -163,              362,
               17,             -122,             -233,              279,
              138,              157,              318,              193,
              189,              209,              266,              252,
              -46,              -56,             -277,             -429,
              464,              386,              142,               44,
              -43,               66,              264,              182,
               47,               14,              -26,              -79,
               49,               15,             -128,             -203,
             -400,             -478,              325,               27,
              234,              411,              205,              129,
               12,               58,              123,               57,
              171,              137,               96,              128,
              -32,              134,              -12,               57,
              119,               26,              -22,             -165,
             -500,             -701,             -528,             -116,
               64,               -8,               97,               -9,
             -162,              -66,             -156,             -194,
             -303,             -546,             -341,              546,
              358,               95,               45,               76,
              270,              403,              205,              100,
              123,               50,              -53,             -144,
             -110,              -13,               32,             -228,
             -130,              353,              296,               56,
             -372,             -253,              365,               73,
               10,              -34,             -139,             -191,
              -96,                5,               44,              -85,
             -179,             -129,             -192,             -246,
              -85,             -110,             -155,              -44,
              -27,              145,              138,               79,
               32,             -148,             -577,             -634,
              191,               94,               -9,              -35,
              -77,              -84,              -56,             -171,
             -298,             -271,             -243,             -156,
             -328,             -235,              -76,             -128,
             -121,              129,               13,              -22,
               32,               45,             -248,              -65,
              193,              -81,              299,               57,
             -147,              192,             -165,             -354,
             -334,             -106,             -156,              -40,
               -3,              -68,              124,             -257,
               78,              124,              170,              412,
              227,              105,             -104,               12,
              154,              250,              274,              258,
                4,              -27,              235,              152,
               51,              338,              300,                7,
             -314,             -411,              215,              170,
               -9,              -93,              -77,               76,
               67,               54,              200,              315,
              163,               72,              -91,             -402,
              158,              187,             -156,              -91,
              290,              267,              167,               91,
              140,              171,              112,                9,
              -42,             -177,             -440,              385,
               80,               15,              172,              129,
               41,             -129,             -372,              -24,
              -75,              -30,             -170,               10,
             -118,               57,               78,             -101,
              232,              161,              123,              256,
              277,              101,             -192,             -629,
             -100,              -60,             -232,               66,
               13,              -13,              -80,             -239,
              239,               37,               32,               89,
             -319,             -579,              450,              360,
                3,              -29,             -299,              -89,
              -54,             -110,             -246,             -164,
                6,             -188,              338,              176,
              -92,              197,              137,              134,
               12,               -2,               56,             -183,
              114,              -36,             -131,             -204,
               75,              -25,             -174,              191,
              -15,             -290,             -429,             -267,
               79,               37,              106,               23,
             -384,              425,               70,              -14,
              212,              105,               15,               -2,
              -42,              -37,             -123,              108,
               28,              -48,              193,              197,
              173,              -33,               37,               73,
              -57,              256,              137,              -58,
             -430,             -228,              217,              -51,
              -10,              -58,               -6,               22,
              104,               61,             -119,              169,
              144,               16,              -46,             -394,
               60,              454,              -80,             -298,
              -65,               25,                0,              -24,
              -65,             -417,              465,              276,
               -3,             -194,              -13,              130,
               19,               -6,              -21,              -24,
             -180,              -53,              -85,               20,
              118,              147,              113,              -75,
             -289,              226,             -122,              227,
              270,              125,              109,              197,
              125,              138,               44,               60,
               25,              -55,             -167,              -32,
             -139,             -193,             -173,             -316,
              287,             -208,              253,              239,
               27,              -80,             -188,              -28,
             -182,             -235,              156,             -117,
              128,              -48,              -58,             -226,
              172,              181,              167,               19,
               62,               10,                2,              181,
              151,              108,              -16,              -11,
              -78,             -331,              411,              133,
               17,              104,               64,             -184,
               24,              -30,               -3,             -283,
              121,              204,               -8,             -199,
              -21,              -80,             -169,             -157,
             -191,             -136,               81,              155,
               14,             -131,              244,               74,
              -57,              -47,             -280,              347,
              111,              -77,             -128,             -142,
             -194,             -125,               -6,              -68,
               91,                1,               23,               14,
             -154,              -34,               23,              -38,
             -343,              503,              146,              -38,
              -46,              -41,               58,               31,
               63,              -48,             -117,               45,
               28,                1,              -89,               -5,
              -44,              -29,             -448,              487,
              204,               81,               46,             -106,
             -302,              380,              120,              -38,
              -12,              -39,               70,               -3,
               25,              -65,               30,              -11,
               34,              -15,               22,             -115,
                0,              -79,              -83,               45,
              114,               43,              150,               36,
              233,              149,              195,                5,
               25,              -52,             -475,              274,
               28,              -39,               -8,              -66,
             -255,              258,               56,              143,
              -45,             -190,              165,              -60,
               20,                2,              125,             -129,
               51,               -8,             -335,              288,
               38,               59,               25,              -42,
               23,             -118,             -112,               11,
              -55,             -133,             -109,               24,
             -105,               78,              -64,             -245,
              202,              -65,             -127,              162,
               40,              -94,               89,              -85,
             -119,             -103,               97,                9,
              -70,              -28,              194,               86,
             -112,              -92,             -114,               74,
              -49,               46,              -84,             -178,
              113,               52,             -205,              333,
               88,              222,               56,              -55,
               13,               86,                4,              -77,
              224,              114,             -105,              112,
              125,              -29,              -18,             -144,
               22,              -58,              -99,               28,
              114,              -66,              -32,             -169,
             -314,              285,               72,              -74,
              179,               28,              -79,             -182,
               13,              -55,              147,               13,
               12,              -54,               31,              -84,
              -17,              -75,             -228,               83,
             -375,              436,              110,              -63,
              -27,             -136,              169,              -56,
               -8,             -171,              184,              -42,
              148,               68,              204,              235,
              110,             -229,               91,              171,
              -43,               -3,              -26,              -99,
             -111,               71,             -170,              202,
              -67,              181,              -37,              109,
             -120,                3,              -55,             -260,
              -16,              152,               91,              142,
               42,               44,              134,               47,
               17,              -35,               22,               79,
             -169,               41,               46,              277,
              -93,              -49,             -126,               37,
             -103,              -34,              -22,              -90,
             -134,             -205,               92,               -9,
                1,             -195,             -239,               45,
               54,               18,              -23,               -1,
              -80,              -98,              -20,             -261,
              306,               72,               20,              -89,
             -217,               11,                6,              -82,
               89,               13,             -129,              -89,
               83,              -71,              -55,              130,
              -98,             -146,              -27,              -57,
               53,              275,               17,              170,
               -5,              -54,              132,              -64,
               72,              160,             -125,             -168,
               72,               40,              170,               78,
              248,              116,               20,               84,
               31,              -34,              190,               38,
               13,             -106,              225,               27,
             -168,               24,             -157,             -122,
              165,               11,             -161,             -213,
              -12,              -51,             -101,               42,
              101,               27,               55,              111,
               75,               71,              -96,               -1,
               65,             -277,              393,              -26,
              -44,              -68,              -84,              -66,
              -95,              235,              179,              -25,
              -41,               27,              -91,             -128,
             -222,              146,              -72,              -30,
              -24,               55,             -126,              -68,
              -58,             -127,               13,              -97,
             -106,              174,             -100,              155,
              101,             -146,              -21,              261,
               22,               38,              -66,               65,
                4,               70,               64,              144,
               59,              213,               71,             -337,
              303,              -52,               51,              -56,
                1,               10,              -15,               -5,
               34,               52,              228,              131,
              161,             -127,             -214,              238,
              123,               64,             -147,              -50,
              -34,             -127,              204,              162,
               85,               41,                5,             -140,
               73,             -150,               56,              -96,
              -66,              -20,                2,             -235,
               59,              -22,             -107,              150,
              -16,              -47,               -4,               81,
              -67,              167,              149,              149,
             -157,              288,             -156,              -27,
               -8,               18,               83,              -24,
              -41,             -167,              158,             -100,
               93,               53,              201,               15,
               42,              266,              278,              -12,
               -6,              -37,               85,                6,
               20,             -188,             -271,              107,
              -13,              -80,               51,              202,
              173,              -69,               78,             -188,
               46,                4,              153,               12,
             -138,              169,                5,              -58,
             -123,             -108,             -243,              150,
               10,             -191,              246,              -15,
               38,               25,              -10,               14,
               61,               50,             -206,             -215,
             -220,               90,                5,             -149,
             -219,               56,              142,               24,
             -376,               77,              -80,               75,
                6,               42,             -101,               16,
               56,               14,              -57,                3,
              -17,               80,               57,              -36,
               88,              -59,              -97,              -19,
             -148,               46,             -219,              226,
              114,               -4,              -72,              -15,
               37,              -49,              -28,              247,
               44,              123,               47,             -122,
              -38,               17,                4,             -113,
              -32,             -224,              154,             -134,
              196,               71,             -267,              -85,
               28,              -70,               89,             -120,
               99,               -2,               64,               76,
             -166,              -48,              189,              -35,
              -92,             -169,             -123,              339,
               38,              -25,               38,              -35,
              225,             -139,              -50,              -63,
              246,               60,             -185,             -109,
              -49,              -53,             -167,               51,
              149,               60,             -101,              -33,
               25,              -76,              120,               32,
              -30,              -83,              102,               91,
             -186,             -261,              131,             -197
};

const SKP_Silk_NLSF_CBS SKP_Silk_NLSF_CB0_16_Stage_info[ NLSF_MSVQ_CB0_16_STAGES ] =
{
        { 128, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 *   0 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[   0 ] },
        {  16, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * 128 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ 128 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * 144 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ 144 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * 152 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ 152 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * 160 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ 160 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * 168 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ 168 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * 176 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ 176 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * 184 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ 184 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * 192 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ 192 ] },
        {  16, &SKP_Silk_NLSF_MSVQ_CB0_16_Q15[ 16 * 200 ], &SKP_Silk_NLSF_MSVQ_CB0_16_rates_Q5[ 200 ] }
};

const SKP_Silk_NLSF_CB_struct SKP_Silk_NLSF_CB0_16 =
{
        NLSF_MSVQ_CB0_16_STAGES,
        SKP_Silk_NLSF_CB0_16_Stage_info,
        SKP_Silk_NLSF_MSVQ_CB0_16_ndelta_min_Q15,
        SKP_Silk_NLSF_MSVQ_CB0_16_CDF,
        SKP_Silk_NLSF_MSVQ_CB0_16_CDF_start_ptr,
        SKP_Silk_NLSF_MSVQ_CB0_16_CDF_middle_idx
};















#ifndef SKP_SILK_TABLES_NLSF_CB1_10_H
#define SKP_SILK_TABLES_NLSF_CB1_10_H



#ifdef __cplusplus
extern "C"
{
#endif

#define NLSF_MSVQ_CB1_10_STAGES       6
#define NLSF_MSVQ_CB1_10_VECTORS      72


extern const SKP_uint16         SKP_Silk_NLSF_MSVQ_CB1_10_CDF[ NLSF_MSVQ_CB1_10_VECTORS + NLSF_MSVQ_CB1_10_STAGES ];
extern const SKP_uint16 * const SKP_Silk_NLSF_MSVQ_CB1_10_CDF_start_ptr[                  NLSF_MSVQ_CB1_10_STAGES ];
extern const SKP_int            SKP_Silk_NLSF_MSVQ_CB1_10_CDF_middle_idx[                 NLSF_MSVQ_CB1_10_STAGES ];

#ifdef __cplusplus
}
#endif

#endif



const SKP_uint16 SKP_Silk_NLSF_MSVQ_CB1_10_CDF[ NLSF_MSVQ_CB1_10_VECTORS + NLSF_MSVQ_CB1_10_STAGES ] =
{
            0,
        17096,
        24130,
        28997,
        33179,
        36696,
        40213,
        42493,
        44252,
        45973,
        47551,
        49095,
        50542,
        51898,
        53196,
        54495,
        55685,
        56851,
        57749,
        58628,
        59435,
        60207,
        60741,
        61220,
        61700,
        62179,
        62659,
        63138,
        63617,
        64097,
        64576,
        65056,
        65535,
            0,
        20378,
        33032,
        40395,
        46721,
        51707,
        56585,
        61157,
        65535,
            0,
        15055,
        25472,
        35447,
        42501,
        48969,
        54773,
        60212,
        65535,
            0,
        12069,
        22440,
        32812,
        40145,
        46870,
        53595,
        59630,
        65535,
            0,
        10839,
        19954,
        27957,
        35961,
        43965,
        51465,
        58805,
        65535,
            0,
         8933,
        17674,
        26415,
        34785,
        42977,
        50820,
        58496,
        65535
};

const SKP_uint16 * const SKP_Silk_NLSF_MSVQ_CB1_10_CDF_start_ptr[ NLSF_MSVQ_CB1_10_STAGES ] =
{
     &SKP_Silk_NLSF_MSVQ_CB1_10_CDF[   0 ],
     &SKP_Silk_NLSF_MSVQ_CB1_10_CDF[  33 ],
     &SKP_Silk_NLSF_MSVQ_CB1_10_CDF[  42 ],
     &SKP_Silk_NLSF_MSVQ_CB1_10_CDF[  51 ],
     &SKP_Silk_NLSF_MSVQ_CB1_10_CDF[  60 ],
     &SKP_Silk_NLSF_MSVQ_CB1_10_CDF[  69 ]
};

const SKP_int SKP_Silk_NLSF_MSVQ_CB1_10_CDF_middle_idx[ NLSF_MSVQ_CB1_10_STAGES ] =
{
       5,
       3,
       4,
       4,
       5,
       5
};

const SKP_int16 SKP_Silk_NLSF_MSVQ_CB1_10_rates_Q5[ NLSF_MSVQ_CB1_10_VECTORS ] =
{
               62,              103,
              120,              127,
              135,              135,
              155,              167,
              168,              172,
              173,              176,
              179,              181,
              181,              185,
              186,              198,
              199,              203,
              205,              222,
              227,              227,
              227,              227,
              227,              227,
              227,              227,
              227,              227,
               54,               76,
              101,              108,
              119,              120,
              123,              125,
               68,               85,
               87,              103,
              107,              112,
              115,              116,
               78,               85,
               85,              101,
              105,              105,
              110,              111,
               83,               91,
               97,               97,
               97,              100,
              101,              105,
               92,               93,
               93,               95,
               96,               98,
               99,              103
};

const SKP_int SKP_Silk_NLSF_MSVQ_CB1_10_ndelta_min_Q15[ 10 + 1 ] =
{
              462,
                3,
               64,
               74,
               98,
               50,
               97,
               68,
              120,
               53,
              639
};

const SKP_int16 SKP_Silk_NLSF_MSVQ_CB1_10_Q15[ 10 * NLSF_MSVQ_CB1_10_VECTORS ] =
{
             1877,             4646,
             7712,            10745,
            13964,            17028,
            20239,            23182,
            26471,            29287,
             1612,             3278,
             7086,             9975,
            13228,            16264,
            19596,            22690,
            26037,            28965,
             2169,             3830,
             6460,             8958,
            11960,            14750,
            18408,            21659,
            25018,            28043,
             3680,             6024,
             8986,            12256,
            15201,            18188,
            21741,            24460,
            27484,            30059,
             2584,             5187,
             7799,            10902,
            13179,            15765,
            19017,            22431,
            25891,            28698,
             3731,             5751,
             8650,            11742,
            15090,            17407,
            20391,            23421,
            26228,            29247,
             2107,             6323,
             8915,            12226,
            14775,            17791,
            20664,            23679,
            26829,            29353,
             1677,             2870,
             5386,             8077,
            11817,            15176,
            18657,            22006,
            25513,            28689,
             2111,             3625,
             7027,            10588,
            14059,            17193,
            21137,            24260,
            27577,            30036,
             2428,             4010,
             5765,             9376,
            13805,            15821,
            19444,            22389,
            25295,            29310,
             2256,             4628,
             8377,            12441,
            15283,            19462,
            22257,            25551,
            28432,            30304,
             2352,             3675,
             6129,            11868,
            14551,            16655,
            19624,            21883,
            26526,            28849,
             5243,             7248,
            10558,            13269,
            15651,            17919,
            21141,            23827,
            27102,            29519,
             4422,             6725,
            10449,            13273,
            16124,            19921,
            22826,            26061,
            28763,            30583,
             4508,             6291,
             9504,            11809,
            13827,            15950,
            19077,            22084,
            25740,            28658,
             2540,             4297,
             8579,            13578,
            16634,            19101,
            21547,            23887,
            26777,            29146,
             3377,             6358,
            10224,            14518,
            17905,            21056,
            23637,            25784,
            28161,            30109,
             4177,             5942,
             8159,            10108,
            12130,            15470,
            20191,            23326,
            26782,            29359,
             2492,             3801,
             6144,             9825,
            16000,            18671,
            20893,            23663,
            25899,            28974,
             3011,             4727,
             6834,            10505,
            12465,            14496,
            17065,            20052,
            25265,            28057,
             4149,             7197,
            12338,            15076,
            18002,            20190,
            22187,            24723,
            27083,            29125,
             2975,             4578,
             6448,             8378,
             9671,            13225,
            19502,            22277,
            26058,            28850,
             4102,             5760,
             7744,             9484,
            10744,            12308,
            14677,            19607,
            24841,            28381,
             4931,             9287,
            12477,            13395,
            13712,            14351,
            16048,            19867,
            24188,            28994,
             4141,             7867,
            13140,            17720,
            20064,            21108,
            21692,            22722,
            23736,            27449,
             4011,             8720,
            13234,            16206,
            17601,            18289,
            18524,            19689,
            23234,            27882,
             3420,             5995,
            11230,            15117,
            15907,            16783,
            17762,            23347,
            26898,            29946,
             3080,             6786,
            10465,            13676,
            18059,            23615,
            27058,            29082,
            29563,            29905,
             3038,             5620,
             9266,            12870,
            18803,            19610,
            20010,            20802,
            23882,            29306,
             3314,             6420,
             9046,            13262,
            15869,            23117,
            23667,            24215,
            24487,            25915,
             3469,             6963,
            10103,            15282,
            20531,            23240,
            25024,            26021,
            26736,            27255,
             3041,             6459,
             9777,            12896,
            16315,            19410,
            24070,            29353,
            31795,            32075,
             -200,             -134,
             -113,             -204,
             -347,             -440,
             -352,             -211,
             -418,             -172,
             -313,               59,
              495,              772,
              721,              614,
              334,              444,
              225,              242,
              161,               16,
              274,              564,
              -73,             -188,
             -395,             -171,
              777,              508,
             1340,             1145,
              699,              196,
              223,              173,
               90,               25,
              -26,               18,
              133,             -105,
             -360,             -277,
              859,              634,
               41,             -557,
             -768,             -926,
             -601,            -1021,
            -1189,             -365,
              225,              107,
              374,              -50,
              433,              417,
              156,               39,
             -597,            -1397,
            -1594,             -592,
             -485,             -292,
              253,               87,
               -0,               -6,
              -25,             -345,
             -240,              120,
             1261,              946,
              166,             -277,
              241,              167,
              170,              429,
              518,              714,
              602,              254,
              134,               92,
             -152,             -324,
             -394,               49,
             -151,             -304,
             -724,             -657,
             -162,             -369,
              -35,                3,
               -2,             -312,
             -200,              -92,
             -227,              242,
              628,              565,
             -124,             1056,
              770,              101,
              -84,              -33,
                4,             -192,
             -272,                5,
             -627,             -977,
              419,              472,
               53,             -103,
              145,              322,
              -95,              -31,
             -100,             -303,
             -560,            -1067,
             -413,              714,
              283,                2,
             -223,             -367,
              523,              360,
              -38,             -115,
              378,             -591,
             -718,              448,
             -481,             -274,
              180,              -88,
             -581,             -157,
             -696,            -1265,
              394,             -479,
              -23,              124,
              -43,               19,
             -113,             -236,
             -412,             -659,
             -200,                2,
              -69,             -342,
              199,               55,
               58,              -36,
              -51,              -62,
              507,              507,
              427,              442,
               36,              601,
             -141,               68,
              274,              274,
               68,              -12,
               -4,               71,
             -193,             -464,
             -425,             -383,
              408,              203,
             -337,              236,
              410,              -59,
              -25,             -341,
             -449,               28,
               -9,               90,
              332,              -14,
             -905,               96,
             -540,             -242,
              679,              -59,
              192,              -24,
               60,             -217,
                5,              -37,
              179,              -20,
              311,              519,
              274,               72,
             -326,            -1030,
             -262,              213,
              380,               82,
              328,              411,
             -540,              574,
             -283,              151,
              181,             -402,
             -278,             -240,
             -110,             -227,
             -264,              -89,
             -250,             -259,
              -27,              106,
             -239,              -98,
             -390,              118,
               61,              104,
              294,              532,
               92,              -13,
               60,             -233,
              335,              541,
              307,              -26,
             -110,              -91,
             -231,             -460,
              170,              201,
               96,             -372,
              132,              435,
             -302,              216,
             -279,              -41,
               74,              190,
              368,              273,
             -186,             -608,
             -157,              159,
               12,              278,
              245,              307,
               25,             -187,
              -16,               55,
               30,             -163,
              548,             -307,
              106,               -5,
               27,              330,
             -416,              475,
              438,             -235,
              104,              137,
               21,               -5,
             -300,             -468,
              521,             -347,
              170,             -200,
             -219,              308,
             -122,             -133,
              219,              -16,
              359,              412,
              -89,             -111,
               48,              322,
              142,              177,
             -286,             -127,
              -39,              -63,
              -42,             -451,
              160,              308,
              -57,              193,
              -48,               74,
             -346,               59,
              -27,               27,
             -469,             -277,
             -344,              282,
              262,              122,
              171,             -249,
               27,              258,
              188,               -3,
               67,             -206,
             -284,              291,
             -117,              -88,
             -477,              375,
               50,              106,
               99,             -182,
              438,             -376,
             -401,              -49,
              119,              -23,
              -10,              -48,
             -116,             -200,
             -310,              121,
               73,                7,
              237,             -226,
              139,             -456,
              397,               35,
                3,             -108,
              323,              -75,
              332,              198,
              -99,              -21
};

const SKP_Silk_NLSF_CBS SKP_Silk_NLSF_CB1_10_Stage_info[ NLSF_MSVQ_CB1_10_STAGES ] =
{
        {  32, &SKP_Silk_NLSF_MSVQ_CB1_10_Q15[ 10 *   0 ], &SKP_Silk_NLSF_MSVQ_CB1_10_rates_Q5[   0 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_10_Q15[ 10 *  32 ], &SKP_Silk_NLSF_MSVQ_CB1_10_rates_Q5[  32 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_10_Q15[ 10 *  40 ], &SKP_Silk_NLSF_MSVQ_CB1_10_rates_Q5[  40 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_10_Q15[ 10 *  48 ], &SKP_Silk_NLSF_MSVQ_CB1_10_rates_Q5[  48 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_10_Q15[ 10 *  56 ], &SKP_Silk_NLSF_MSVQ_CB1_10_rates_Q5[  56 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_10_Q15[ 10 *  64 ], &SKP_Silk_NLSF_MSVQ_CB1_10_rates_Q5[  64 ] }
};

const SKP_Silk_NLSF_CB_struct SKP_Silk_NLSF_CB1_10 =
{
        NLSF_MSVQ_CB1_10_STAGES,
        SKP_Silk_NLSF_CB1_10_Stage_info,
        SKP_Silk_NLSF_MSVQ_CB1_10_ndelta_min_Q15,
        SKP_Silk_NLSF_MSVQ_CB1_10_CDF,
        SKP_Silk_NLSF_MSVQ_CB1_10_CDF_start_ptr,
        SKP_Silk_NLSF_MSVQ_CB1_10_CDF_middle_idx
};















#ifndef SKP_SILK_TABLES_NLSF_CB1_16_H
#define SKP_SILK_TABLES_NLSF_CB1_16_H



#ifdef __cplusplus
extern "C"
{
#endif

#define NLSF_MSVQ_CB1_16_STAGES       10
#define NLSF_MSVQ_CB1_16_VECTORS      104


extern const SKP_uint16         SKP_Silk_NLSF_MSVQ_CB1_16_CDF[ NLSF_MSVQ_CB1_16_VECTORS + NLSF_MSVQ_CB1_16_STAGES ];
extern const SKP_uint16 * const SKP_Silk_NLSF_MSVQ_CB1_16_CDF_start_ptr[                  NLSF_MSVQ_CB1_16_STAGES ];
extern const SKP_int            SKP_Silk_NLSF_MSVQ_CB1_16_CDF_middle_idx[                 NLSF_MSVQ_CB1_16_STAGES ];

#ifdef __cplusplus
}
#endif

#endif



const SKP_uint16 SKP_Silk_NLSF_MSVQ_CB1_16_CDF[ NLSF_MSVQ_CB1_16_VECTORS + NLSF_MSVQ_CB1_16_STAGES ] =
{
            0,
        19099,
        26957,
        30639,
        34242,
        37546,
        40447,
        43287,
        46005,
        48445,
        49865,
        51284,
        52673,
        53975,
        55221,
        56441,
        57267,
        58025,
        58648,
        59232,
        59768,
        60248,
        60729,
        61210,
        61690,
        62171,
        62651,
        63132,
        63613,
        64093,
        64574,
        65054,
        65535,
            0,
        28808,
        38775,
        46801,
        51785,
        55886,
        59410,
        62572,
        65535,
            0,
        27376,
        38639,
        45052,
        51465,
        55448,
        59021,
        62594,
        65535,
            0,
        33403,
        39569,
        45102,
        49961,
        54047,
        57959,
        61788,
        65535,
            0,
        25851,
        43356,
        47828,
        52204,
        55964,
        59413,
        62507,
        65535,
            0,
        34277,
        40337,
        45432,
        50311,
        54326,
        58171,
        61853,
        65535,
            0,
        33538,
        39865,
        45302,
        50076,
        54549,
        58478,
        62159,
        65535,
            0,
        27445,
        35258,
        40665,
        46072,
        51362,
        56540,
        61086,
        65535,
            0,
        22080,
        30779,
        37065,
        43085,
        48849,
        54613,
        60133,
        65535,
            0,
        13417,
        21748,
        30078,
        38231,
        46383,
        53091,
        59515,
        65535
};

const SKP_uint16 * const SKP_Silk_NLSF_MSVQ_CB1_16_CDF_start_ptr[ NLSF_MSVQ_CB1_16_STAGES ] =
{
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[   0 ],
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[  33 ],
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[  42 ],
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[  51 ],
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[  60 ],
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[  69 ],
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[  78 ],
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[  87 ],
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[  96 ],
     &SKP_Silk_NLSF_MSVQ_CB1_16_CDF[ 105 ]
};

const SKP_int SKP_Silk_NLSF_MSVQ_CB1_16_CDF_middle_idx[ NLSF_MSVQ_CB1_16_STAGES ] =
{
       5,
       2,
       2,
       2,
       2,
       2,
       2,
       3,
       3,
       4
};

const SKP_int16 SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[ NLSF_MSVQ_CB1_16_VECTORS ] =
{
               57,               98,
              133,              134,
              138,              144,
              145,              147,
              152,              177,
              177,              178,
              181,              183,
              184,              202,
              206,              215,
              218,              222,
              227,              227,
              227,              227,
              227,              227,
              227,              227,
              227,              227,
              227,              227,
               38,               87,
               97,              119,
              128,              135,
              140,              143,
               40,               81,
              107,              107,
              129,              134,
              134,              143,
               31,              109,
              114,              120,
              128,              130,
              131,              132,
               43,               61,
              124,              125,
              132,              136,
              141,              142,
               30,              110,
              118,              120,
              129,              131,
              133,              133,
               31,              108,
              115,              121,
              124,              130,
              133,              137,
               40,               98,
              115,              115,
              116,              117,
              123,              124,
               50,               93,
              108,              110,
              112,              112,
              114,              115,
               73,               95,
               95,               96,
               96,              105,
              107,              110
};

const SKP_int SKP_Silk_NLSF_MSVQ_CB1_16_ndelta_min_Q15[ 16 + 1 ] =
{
              148,
                3,
               60,
               68,
              117,
               86,
              121,
              124,
              152,
              153,
              207,
              151,
              225,
              239,
              126,
              183,
              792
};

const SKP_int16 SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 * NLSF_MSVQ_CB1_16_VECTORS ] =
{
             1309,             3060,             5071,             6996,
             9028,            10938,            12934,            14891,
            16933,            18854,            20792,            22764,
            24753,            26659,            28626,            30501,
             1264,             2745,             4610,             6408,
             8286,            10043,            12084,            14108,
            16118,            18163,            20095,            22164,
            24264,            26316,            28329,            30251,
             1044,             2080,             3672,             5179,
             7140,             9100,            11070,            13065,
            15423,            17790,            19931,            22101,
            24290,            26361,            28499,            30418,
             1131,             2476,             4478,             6149,
             7902,             9875,            11938,            13809,
            15869,            17730,            19948,            21707,
            23761,            25535,            27426,            28917,
             1040,             2004,             4026,             6100,
             8432,            10494,            12610,            14694,
            16797,            18775,            20799,            22782,
            24772,            26682,            28631,            30516,
             2310,             3812,             5913,             7933,
            10033,            11881,            13885,            15798,
            17751,            19576,            21482,            23276,
            25157,            27010,            28833,            30623,
             1254,             2847,             5013,             6781,
             8626,            10370,            12726,            14633,
            16281,            17852,            19870,            21472,
            23002,            24629,            26710,            27960,
             1468,             3059,             4987,             7026,
             8741,            10412,            12281,            14020,
            15970,            17723,            19640,            21522,
            23472,            25661,            27986,            30225,
             2171,             3566,             5605,             7384,
             9404,            11220,            13030,            14758,
            16687,            18417,            20346,            22091,
            24055,            26212,            28356,            30397,
             2409,             4676,             7543,             9786,
            11419,            12935,            14368,            15653,
            17366,            18943,            20762,            22477,
            24440,            26327,            28284,            30242,
             2354,             4222,             6820,             9107,
            11596,            13934,            15973,            17682,
            19158,            20517,            21991,            23420,
            25178,            26936,            28794,            30527,
             1323,             2414,             4184,             6039,
             7534,             9398,            11099,            13097,
            14799,            16451,            18434,            20887,
            23490,            25838,            28046,            30225,
             1361,             3243,             6048,             8511,
            11001,            13145,            15073,            16608,
            18126,            19381,            20912,            22607,
            24660,            26668,            28663,            30566,
             1216,             2648,             5901,             8422,
            10037,            11425,            12973,            14603,
            16686,            18600,            20555,            22415,
            24450,            26280,            28206,            30077,
             2417,             4048,             6316,             8433,
            10510,            12757,            15072,            17295,
            19573,            21503,            23329,            24782,
            26235,            27689,            29214,            30819,
             1012,             2345,             4991,             7377,
             9465,            11916,            14296,            16566,
            18672,            20544,            22292,            23838,
            25415,            27050,            28848,            30551,
             1937,             3693,             6267,             8019,
            10372,            12194,            14287,            15657,
            17431,            18864,            20769,            22206,
            24037,            25463,            27383,            28602,
             1969,             3305,             5017,             6726,
             8375,             9993,            11634,            13280,
            15078,            16751,            18464,            20119,
            21959,            23858,            26224,            29298,
             1198,             2647,             5428,             7423,
             9775,            12155,            14665,            16344,
            18121,            19790,            21557,            22847,
            24484,            25742,            27639,            28711,
             1636,             3353,             5447,             7597,
             9837,            11647,            13964,            16019,
            17862,            20116,            22319,            24037,
            25966,            28086,            29914,            31294,
             2676,             4105,             6378,             8223,
            10058,            11549,            13072,            14453,
            15956,            17355,            18931,            20402,
            22183,            23884,            25717,            27723,
             1373,             2593,             4449,             5633,
             7300,             8425,             9474,            10818,
            12769,            15722,            19002,            21429,
            23682,            25924,            28135,            30333,
             1596,             3183,             5378,             7164,
             8670,            10105,            11470,            12834,
            13991,            15042,            16642,            17903,
            20759,            25283,            27770,            30240,
             2037,             3987,             6237,             8117,
             9954,            12245,            14217,            15892,
            17775,            20114,            22314,            25942,
            26305,            26483,            26796,            28561,
             2181,             3858,             5760,             7924,
            10041,            11577,            13769,            15700,
            17429,            19879,            23583,            24538,
            25212,            25693,            28688,            30507,
             1992,             3882,             6474,             7883,
             9381,            12672,            14340,            15701,
            16658,            17832,            20850,            22885,
            24677,            26457,            28491,            30460,
             2391,             3988,             5448,             7432,
            11014,            12579,            13140,            14146,
            15898,            18592,            21104,            22993,
            24673,            27186,            28142,            29612,
             1713,             5102,             6989,             7798,
             8670,            10110,            12746,            14881,
            16709,            18407,            20126,            22107,
            24181,            26198,            28237,            30137,
             1612,             3617,             6148,             8359,
             9576,            11528,            14936,            17809,
            18287,            18729,            19001,            21111,
            24631,            26596,            28740,            30643,
             2266,             4168,             7862,             9546,
             9618,             9703,            10134,            13897,
            16265,            18432,            20587,            22605,
            24754,            26994,            29125,            30840,
             1840,             3917,             6272,             7809,
             9714,            11438,            13767,            15799,
            19244,            21972,            22980,            23180,
            23723,            25650,            29117,            31085,
             1458,             3612,             6008,             7488,
             9827,            11893,            14086,            15734,
            17440,            19535,            22424,            24767,
            29246,            29928,            30516,            30947,
             -102,             -121,              -31,               -6,
                5,               -2,                8,              -18,
               -4,                6,               14,               -2,
              -12,              -16,              -12,              -60,
             -126,             -353,             -574,             -677,
             -657,             -617,             -498,             -393,
             -348,             -277,             -225,             -164,
             -102,              -70,              -31,               33,
                4,              379,              387,              551,
              605,              620,              532,              482,
              442,              454,              385,              347,
              322,              299,              266,              200,
             1168,              951,              672,              246,
               60,             -161,             -259,             -234,
             -253,             -282,             -203,             -187,
             -155,             -176,             -198,             -178,
               10,              170,              393,              609,
              555,              208,             -330,             -571,
             -769,             -633,             -319,              -43,
               95,              105,              106,              116,
             -152,             -140,             -125,                5,
              173,              274,              264,              331,
              -37,             -293,             -609,             -786,
             -959,             -814,             -645,             -238,
              -91,               36,              -11,             -101,
             -279,             -227,              -40,               90,
              530,              677,              890,             1104,
              999,              835,              564,              295,
             -280,             -364,             -340,             -331,
             -284,              288,              761,              880,
              988,              627,              146,             -226,
             -203,             -181,             -142,               39,
               24,              -26,             -107,              -92,
             -161,             -135,             -131,              -88,
             -160,             -156,              -75,              -43,
              -36,               -6,              -33,               33,
             -324,             -415,             -108,              124,
              157,              191,              203,              197,
              144,              109,              152,              176,
              190,              122,              101,              159,
              663,              668,              480,              400,
              379,              444,              446,              458,
              343,              351,              310,              228,
              133,               44,               75,               63,
              -84,               39,              -29,               35,
              -94,             -233,             -261,             -354,
               77,              262,              -24,             -145,
             -333,             -409,             -404,             -597,
             -488,             -300,              910,              592,
              412,              120,              130,              -51,
              -37,              -77,             -172,             -181,
             -159,             -148,              -72,              -62,
              510,              516,              113,             -585,
            -1075,             -957,             -417,             -195,
                9,                7,              -88,             -173,
              -91,               54,               98,               95,
              -28,              197,             -527,             -621,
              157,              122,             -168,              147,
              309,              300,              336,              315,
              396,              408,              376,              106,
             -162,             -170,             -315,               98,
              821,              908,              570,              -33,
             -312,             -568,             -572,             -378,
             -107,               23,              156,               93,
             -129,              -87,               20,              -72,
              -37,               40,               21,               27,
               48,               75,               77,               65,
               46,               71,               66,               47,
              136,              344,              236,              322,
              170,              283,              269,              291,
              162,              -43,             -204,             -259,
             -240,             -305,             -350,             -312,
              447,              348,              345,              257,
               71,             -131,              -77,             -190,
             -202,              -40,               35,              133,
              261,              365,              438,              303,
               -8,               22,              140,              137,
             -300,             -641,             -764,             -268,
              -23,              -25,               73,             -162,
             -150,             -212,              -72,                6,
               39,               78,              104,              -93,
             -308,             -136,              117,              -71,
             -513,             -820,             -700,             -450,
             -161,              -23,               29,               78,
              337,              106,             -406,             -782,
             -112,              233,              383,               62,
             -126,                6,              -77,              -29,
             -146,             -123,              -51,              -27,
              -27,             -381,             -641,              402,
              539,                8,             -207,             -366,
              -36,              -27,             -204,             -227,
             -237,             -189,              -64,               51,
              -92,             -137,             -281,               62,
              233,               92,              148,              294,
              363,              416,              564,              625,
              370,              -36,             -469,             -462,
              102,              168,               32,              117,
              -21,               97,              139,               89,
              104,               35,                4,               82,
               66,               58,               73,               93,
              -76,             -320,             -236,             -189,
             -203,             -142,              -27,              -73,
                9,               -9,              -25,               12,
              -15,                4,                4,              -50,
              314,              180,              162,              -49,
              199,             -108,             -227,              -66,
             -447,              -67,             -264,             -394,
                5,               55,             -133,             -176,
             -116,             -241,              272,              109,
              282,              262,              192,              -64,
             -392,             -514,              156,              203,
              154,               72,              -34,             -160,
              -73,                3,              -33,             -431,
              321,               18,             -567,             -590,
             -108,               88,               66,               51,
              -31,             -193,              -46,               65,
              -29,              -23,              215,              -31,
              101,             -113,               32,              304,
               88,              320,              448,                5,
             -439,             -562,             -508,             -135,
              -13,             -171,               -8,              182,
              -99,             -181,             -149,              376,
              476,               64,             -396,             -652,
             -150,              176,              222,               65,
             -590,              719,              271,              399,
              245,               72,             -156,             -152,
             -176,               59,               94,              125,
               -9,               -7,                9,                1,
              -61,             -116,              -82,                1,
               79,               22,              -44,              -15,
              -48,              -65,              -62,             -101,
             -102,              -54,              -70,              -78,
              -80,              -25,              398,               71,
              139,               38,               90,              194,
              222,              249,              165,               94,
              221,              262,              163,               91,
             -206,              573,              200,             -287,
             -147,                5,              -18,              -85,
              -74,             -125,              -87,               85,
              141,                4,               -4,               28,
              234,               48,             -150,             -111,
             -506,              237,             -209,              345,
               94,             -124,               77,              121,
              143,               12,              -80,              -48,
              191,              144,              -93,              -65,
             -151,             -643,              435,              106,
               87,                7,               65,              102,
               94,               68,                5,               99,
              222,               93,               94,              355,
              -13,              -89,             -228,             -503,
              287,              109,              108,              449,
              253,              -29,             -109,             -116,
               15,              -73,              -20,              131,
             -147,               72,               59,             -150,
             -594,              273,              316,              132,
              199,              106,              198,              212,
              220,               82,               45,              -13,
              223,              137,              270,               38,
              252,              135,             -177,             -207,
             -360,             -102,              403,              406,
              -14,               83,               64,               51,
               -7,              -99,              -97,              -88,
             -124,              -65,               42,               32,
               28,               29,               12,               20,
              119,              -26,             -212,             -201,
              373,              251,              141,              103,
               36,              -52,               66,               18,
               -6,              -95,             -196,                5,
               98,              -85,             -108,              218,
             -164,               20,              356,              172,
               37,              266,               23,              112,
              -24,              -99,              -92,             -178,
               29,             -278,              388,              -60,
             -220,              300,              -13,              154,
              191,               15,              -37,             -110,
             -153,             -150,             -114,               -7,
              -94,              -31,              -62,             -177,
                4,              -70,               35,              453,
              147,             -247,             -328,              101,
               20,             -114,              147,              108,
             -119,             -109,             -102,             -238,
               55,             -102,              173,              -89,
              129,              138,             -330,             -160,
              485,              154,              -59,             -170,
              -20,              -34,             -261,              -40,
             -129,               77,              -84,               69,
               83,              160,              169,               63,
             -516,               30,              336,               52,
               -0,              -52,             -124,              158,
               19,              197,              -10,             -375,
              405,              285,              114,             -395,
              -47,              196,               62,               87,
             -106,              -65,              -75,              -69,
              -13,               34,               99,               59,
               83,               98,               44,                0,
               24,               18,               17,               70,
              -22,              194,              208,              144,
              -79,              -15,               32,             -104,
              -28,             -105,             -186,             -212,
             -228,              -79,              -76,               51,
              -71,               72,              118,              -34,
               -3,             -171,                5,                2,
             -108,             -125,               62,              -58,
               58,             -121,               73,             -466,
               92,               63,              -94,              -78,
              -76,              212,               36,             -225,
              -71,             -354,              152,              143,
              -79,             -246,              -51,              -31,
               -6,             -270,              240,              210,
               30,             -157,             -231,               74,
             -146,               88,             -273,              156,
               92,               56,               71,                2,
              318,              164,               32,             -110,
              -35,              -41,              -95,             -106,
               11,              132,              -68,               55,
              123,              -83,             -149,              212,
              132,                0,             -194,               55,
              206,             -108,             -353,              289,
             -195,                1,              233,              -22,
              -60,               20,               26,               68,
              166,               27,              -58,              130,
              112,              107,               27,             -165,
              115,              -93,              -37,               38,
               83,              483,               65,             -229,
              -13,              157,               85,               50,
              136,               10,               32,               83,
               82,               55,                5,               -9,
              -52,              -78,              -81,              -51,
               40,               18,             -127,             -224,
              -41,               53,             -210,             -113,
               24,              -17,             -187,              -89,
                8,              121,               83,               77,
               91,              -74,              -35,             -112,
             -161,             -173,              102,              132,
             -125,              -61,              103,             -260,
               52,              166,              -32,             -156,
              -87,              -56,               60,              -70,
             -124,              242,              114,             -251,
             -166,              201,              127,               28,
              -11,               23,              -80,             -115,
              -20,              -51,             -348,              340,
              -34,              133,               13,               92,
             -124,             -136,             -120,              -26,
               -6,               17,               28,               21,
              120,             -168,              160,              -35,
              115,               28,                9,                7,
              -56,               39,              156,              256,
              -18,                1,              277,               82,
              -70,             -144,              -88,              -13,
              -59,             -157,                8,             -134,
               21,              -40,               58,              -21,
              194,             -276,               97,              279,
              -56,             -140,              125,               57,
             -184,             -204,              -70,               -2,
              128,             -202,              -78,              230,
              -23,              161,             -102,                1,
                1,              180,              -31,              -86,
             -167,              -57,              -60,               27,
              -13,               99,              108,              111,
               76,               69,               34,              -21,
               53,               38,               34,               78,
               73,              219,               51,               15,
              -72,             -103,             -207,               30,
              213,              -14,               31,              -94,
              -40,             -144,               67,                4,
              105,               59,             -240,               25,
              244,               69,               58,               23,
              -24,               -5,              -15,             -133,
              -71,              -67,              181,               29,
              -45,              121,               96,               51,
              -72,              -53,               56,             -153,
              -27,               85,              183,              211,
              105,              -34,              -46,               43,
              -72,              -93,               36,             -128,
               29,              111,              -95,             -156,
             -179,             -235,               21,              -39,
              -71,              -33,              -61,             -252,
              230,             -131,              157,              -21,
              -85,              -28,             -123,               80,
             -160,               63,               47,               -6,
              -49,              -96,              -19,               17,
              -58,               17,               -0,              -13,
             -170,               25,              -35,               59,
               10,              -31,             -413,               81,
               62,               18,             -164,              245,
               92,             -165,               42,               26,
              126,             -248,              193,              -55,
               16,               39,               14,               50
};

const SKP_Silk_NLSF_CBS SKP_Silk_NLSF_CB1_16_Stage_info[ NLSF_MSVQ_CB1_16_STAGES ] =
{
        {  32, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *   0 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[   0 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *  32 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[  32 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *  40 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[  40 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *  48 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[  48 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *  56 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[  56 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *  64 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[  64 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *  72 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[  72 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *  80 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[  80 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *  88 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[  88 ] },
        {   8, &SKP_Silk_NLSF_MSVQ_CB1_16_Q15[ 16 *  96 ], &SKP_Silk_NLSF_MSVQ_CB1_16_rates_Q5[  96 ] }
};

const SKP_Silk_NLSF_CB_struct SKP_Silk_NLSF_CB1_16 =
{
        NLSF_MSVQ_CB1_16_STAGES,
        SKP_Silk_NLSF_CB1_16_Stage_info,
        SKP_Silk_NLSF_MSVQ_CB1_16_ndelta_min_Q15,
        SKP_Silk_NLSF_MSVQ_CB1_16_CDF,
        SKP_Silk_NLSF_MSVQ_CB1_16_CDF_start_ptr,
        SKP_Silk_NLSF_MSVQ_CB1_16_CDF_middle_idx
};







#ifdef __cplusplus
extern "C"
{
#endif

const SKP_uint16 SKP_Silk_gain_CDF[ 2 ][ 65 ] = 
{
{
         0,     18,     45,     94,    181,    320,    519,    777,
      1093,   1468,   1909,   2417,   2997,   3657,   4404,   5245,
      6185,   7228,   8384,   9664,  11069,  12596,  14244,  16022,
     17937,  19979,  22121,  24345,  26646,  29021,  31454,  33927,
     36438,  38982,  41538,  44068,  46532,  48904,  51160,  53265,
     55184,  56904,  58422,  59739,  60858,  61793,  62568,  63210,
     63738,  64165,  64504,  64769,  64976,  65133,  65249,  65330,
     65386,  65424,  65451,  65471,  65487,  65501,  65513,  65524,
     65535
},
{
         0,    214,    581,   1261,   2376,   3920,   5742,   7632,
      9449,  11157,  12780,  14352,  15897,  17427,  18949,  20462,
     21957,  23430,  24889,  26342,  27780,  29191,  30575,  31952,
     33345,  34763,  36200,  37642,  39083,  40519,  41930,  43291,
     44602,  45885,  47154,  48402,  49619,  50805,  51959,  53069,
     54127,  55140,  56128,  57101,  58056,  58979,  59859,  60692,
     61468,  62177,  62812,  63368,  63845,  64242,  64563,  64818,
     65023,  65184,  65306,  65391,  65447,  65482,  65505,  65521,
     65535
}
};

const SKP_int SKP_Silk_gain_CDF_offset = 32;


const SKP_uint16 SKP_Silk_delta_gain_CDF[ 46 ] = {
         0,   2358,   3856,   7023,  15376,  53058,  59135,  61555,
     62784,  63498,  63949,  64265,  64478,  64647,  64783,  64894,
     64986,  65052,  65113,  65169,  65213,  65252,  65284,  65314,
     65338,  65359,  65377,  65392,  65403,  65415,  65424,  65432,
     65440,  65448,  65455,  65462,  65470,  65477,  65484,  65491,
     65499,  65506,  65513,  65521,  65528,  65535
};

const SKP_int SKP_Silk_delta_gain_CDF_offset = 5;

#ifdef __cplusplus
}
#endif







#ifdef __cplusplus
extern "C"
{
#endif


const SKP_int32 TargetRate_table_NB[ TARGET_RATE_TAB_SZ ] = {
    0,      8000,   9000,   11000,  13000,  16000,  22000,  MAX_TARGET_RATE_BPS
};
const SKP_int32 TargetRate_table_MB[ TARGET_RATE_TAB_SZ ] = {
    0,      10000,  12000,  14000,  17000,  21000,  28000,  MAX_TARGET_RATE_BPS
};
const SKP_int32 TargetRate_table_WB[ TARGET_RATE_TAB_SZ ] = {
    0,      11000,  14000,  17000,  21000,  26000,  36000,  MAX_TARGET_RATE_BPS
};
const SKP_int32 TargetRate_table_SWB[ TARGET_RATE_TAB_SZ ] = {
    0,      13000,  16000,  19000,  25000,  32000,  46000,  MAX_TARGET_RATE_BPS
};
const SKP_int32 SNR_table_Q1[ TARGET_RATE_TAB_SZ ] = {
    19,     31,     35,     39,     43,     47,     54,     64
};

const SKP_int32 SNR_table_one_bit_per_sample_Q7[ 4 ] = {
    1984,   2240,   2408,   2708
};


const SKP_int16 SKP_Silk_SWB_detect_B_HP_Q13[ NB_SOS ][ 3 ] = {
    
    {575, -948, 575}, {575, -221, 575}, {575, 104, 575} 
};
const SKP_int16 SKP_Silk_SWB_detect_A_HP_Q13[ NB_SOS ][ 2 ] = {
    {14613, 6868}, {12883, 7337}, {11586, 7911}
    
};


const SKP_int16 SKP_Silk_Dec_A_HP_24[ DEC_HP_ORDER     ] = {-16220, 8030};              
const SKP_int16 SKP_Silk_Dec_B_HP_24[ DEC_HP_ORDER + 1 ] = {8000, -16000, 8000};        


const SKP_int16 SKP_Silk_Dec_A_HP_16[ DEC_HP_ORDER     ] = {-16127, 7940};              
const SKP_int16 SKP_Silk_Dec_B_HP_16[ DEC_HP_ORDER + 1 ] = {8000, -16000, 8000};        


const SKP_int16 SKP_Silk_Dec_A_HP_12[ DEC_HP_ORDER     ] = {-16043, 7859};              
const SKP_int16 SKP_Silk_Dec_B_HP_12[ DEC_HP_ORDER + 1 ] = {8000, -16000, 8000};        


const SKP_int16 SKP_Silk_Dec_A_HP_8[ DEC_HP_ORDER     ] = {-15885, 7710};               
const SKP_int16 SKP_Silk_Dec_B_HP_8[ DEC_HP_ORDER + 1 ] = {8000, -16000, 8000};         


const SKP_uint16 SKP_Silk_lsb_CDF[ 3 ] = {0,  40000,  65535};


const SKP_uint16 SKP_Silk_LTPscale_CDF[ 4 ] = {0,  32000,  48000,  65535};
const SKP_int    SKP_Silk_LTPscale_offset   = 2;


const SKP_uint16 SKP_Silk_vadflag_CDF[ 3 ] = {0,  22000,  65535}; 
const SKP_int    SKP_Silk_vadflag_offset   = 1;


const SKP_int    SKP_Silk_SamplingRates_table[ 4 ] = {8, 12, 16, 24};
const SKP_uint16 SKP_Silk_SamplingRates_CDF[ 5 ]   = {0,  16000,  32000,  48000,  65535};
const SKP_int    SKP_Silk_SamplingRates_offset     = 2;


const SKP_uint16 SKP_Silk_NLSF_interpolation_factor_CDF[ 6 ] = {0,   3706,   8703,  19226,  30926,  65535};
const SKP_int    SKP_Silk_NLSF_interpolation_factor_offset   = 4;


const SKP_uint16 SKP_Silk_FrameTermination_CDF[ 5 ] = {0, 20000, 45000, 56000, 65535};
const SKP_int    SKP_Silk_FrameTermination_offset   = 2;


const SKP_uint16 SKP_Silk_Seed_CDF[ 5 ] = {0, 16384, 32768, 49152, 65535};
const SKP_int    SKP_Silk_Seed_offset   = 2;


const SKP_int16  SKP_Silk_Quantization_Offsets_Q10[ 2 ][ 2 ] = {
    { OFFSET_VL_Q10, OFFSET_VH_Q10 }, { OFFSET_UVL_Q10, OFFSET_UVH_Q10 }
};


const SKP_int16 SKP_Silk_LTPScales_table_Q14[ 3 ] = { 15565, 11469, 8192 };

#if SWITCH_TRANSITION_FILTERING



const SKP_int32 SKP_Silk_Transition_LP_B_Q28[ TRANSITION_INT_NUM ][ TRANSITION_NB ] = 
{
{    250767114,  501534038,  250767114  },
{    209867381,  419732057,  209867381  },
{    170987846,  341967853,  170987846  },
{    131531482,  263046905,  131531482  },
{     89306658,  178584282,   89306658  }
};


const SKP_int32 SKP_Silk_Transition_LP_A_Q28[ TRANSITION_INT_NUM ][ TRANSITION_NA ] = 
{
{    506393414,  239854379  },
{    411067935,  169683996  },
{    306733530,  116694253  },
{    185807084,   77959395  },
{     35497197,   57401098  }
};
#endif

#ifdef __cplusplus
}
#endif







const SKP_uint16 SKP_Silk_pitch_lag_NB_CDF[ 8 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) + 2 ] = {
         0,    194,    395,    608,    841,   1099,   1391,   1724,
      2105,   2544,   3047,   3624,   4282,   5027,   5865,   6799,
      7833,   8965,  10193,  11510,  12910,  14379,  15905,  17473,
     19065,  20664,  22252,  23814,  25335,  26802,  28206,  29541,
     30803,  31992,  33110,  34163,  35156,  36098,  36997,  37861,
     38698,  39515,  40319,  41115,  41906,  42696,  43485,  44273,
     45061,  45847,  46630,  47406,  48175,  48933,  49679,  50411,
     51126,  51824,  52502,  53161,  53799,  54416,  55011,  55584,
     56136,  56666,  57174,  57661,  58126,  58570,  58993,  59394,
     59775,  60134,  60472,  60790,  61087,  61363,  61620,  61856,
     62075,  62275,  62458,  62625,  62778,  62918,  63045,  63162,
     63269,  63368,  63459,  63544,  63623,  63698,  63769,  63836,
     63901,  63963,  64023,  64081,  64138,  64194,  64248,  64301,
     64354,  64406,  64457,  64508,  64558,  64608,  64657,  64706,
     64754,  64803,  64851,  64899,  64946,  64994,  65041,  65088,
     65135,  65181,  65227,  65272,  65317,  65361,  65405,  65449,
     65492,  65535
};

const SKP_int SKP_Silk_pitch_lag_NB_CDF_offset = 43;

const SKP_uint16 SKP_Silk_pitch_contour_NB_CDF[ 12 ] = {
         0,  14445,  18587,  25628,  30013,  34859,  40597,  48426,
     54460,  59033,  62990,  65535
};

const SKP_int SKP_Silk_pitch_contour_NB_CDF_offset = 5;

const SKP_uint16 SKP_Silk_pitch_lag_MB_CDF[ 12 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) + 2 ] = {
         0,    132,    266,    402,    542,    686,    838,    997,
      1167,   1349,   1546,   1760,   1993,   2248,   2528,   2835,
      3173,   3544,   3951,   4397,   4882,   5411,   5984,   6604,
      7270,   7984,   8745,   9552,  10405,  11300,  12235,  13206,
     14209,  15239,  16289,  17355,  18430,  19507,  20579,  21642,
     22688,  23712,  24710,  25677,  26610,  27507,  28366,  29188,
     29971,  30717,  31427,  32104,  32751,  33370,  33964,  34537,
     35091,  35630,  36157,  36675,  37186,  37692,  38195,  38697,
     39199,  39701,  40206,  40713,  41222,  41733,  42247,  42761,
     43277,  43793,  44309,  44824,  45336,  45845,  46351,  46851,
     47347,  47836,  48319,  48795,  49264,  49724,  50177,  50621,
     51057,  51484,  51902,  52312,  52714,  53106,  53490,  53866,
     54233,  54592,  54942,  55284,  55618,  55944,  56261,  56571,
     56873,  57167,  57453,  57731,  58001,  58263,  58516,  58762,
     58998,  59226,  59446,  59656,  59857,  60050,  60233,  60408,
     60574,  60732,  60882,  61024,  61159,  61288,  61410,  61526,
     61636,  61742,  61843,  61940,  62033,  62123,  62210,  62293,
     62374,  62452,  62528,  62602,  62674,  62744,  62812,  62879,
     62945,  63009,  63072,  63135,  63196,  63256,  63316,  63375,
     63434,  63491,  63549,  63605,  63661,  63717,  63772,  63827,
     63881,  63935,  63988,  64041,  64094,  64147,  64199,  64252,
     64304,  64356,  64409,  64461,  64513,  64565,  64617,  64669,
     64721,  64773,  64824,  64875,  64925,  64975,  65024,  65072,
     65121,  65168,  65215,  65262,  65308,  65354,  65399,  65445,
     65490,  65535
};

const SKP_int SKP_Silk_pitch_lag_MB_CDF_offset = 64;

const SKP_uint16 SKP_Silk_pitch_lag_WB_CDF[ 16 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) + 2 ] = {
         0,    106,    213,    321,    429,    539,    651,    766,
       884,   1005,   1132,   1264,   1403,   1549,   1705,   1870,
      2047,   2236,   2439,   2658,   2893,   3147,   3420,   3714,
      4030,   4370,   4736,   5127,   5546,   5993,   6470,   6978,
      7516,   8086,   8687,   9320,   9985,  10680,  11405,  12158,
     12938,  13744,  14572,  15420,  16286,  17166,  18057,  18955,
     19857,  20759,  21657,  22547,  23427,  24293,  25141,  25969,
     26774,  27555,  28310,  29037,  29736,  30406,  31048,  31662,
     32248,  32808,  33343,  33855,  34345,  34815,  35268,  35704,
     36127,  36537,  36938,  37330,  37715,  38095,  38471,  38844,
     39216,  39588,  39959,  40332,  40707,  41084,  41463,  41844,
     42229,  42615,  43005,  43397,  43791,  44186,  44583,  44982,
     45381,  45780,  46179,  46578,  46975,  47371,  47765,  48156,
     48545,  48930,  49312,  49690,  50064,  50433,  50798,  51158,
     51513,  51862,  52206,  52544,  52877,  53204,  53526,  53842,
     54152,  54457,  54756,  55050,  55338,  55621,  55898,  56170,
     56436,  56697,  56953,  57204,  57449,  57689,  57924,  58154,
     58378,  58598,  58812,  59022,  59226,  59426,  59620,  59810,
     59994,  60173,  60348,  60517,  60681,  60840,  60993,  61141,
     61284,  61421,  61553,  61679,  61800,  61916,  62026,  62131,
     62231,  62326,  62417,  62503,  62585,  62663,  62737,  62807,
     62874,  62938,  62999,  63057,  63113,  63166,  63217,  63266,
     63314,  63359,  63404,  63446,  63488,  63528,  63567,  63605,
     63642,  63678,  63713,  63748,  63781,  63815,  63847,  63879,
     63911,  63942,  63973,  64003,  64033,  64063,  64092,  64121,
     64150,  64179,  64207,  64235,  64263,  64291,  64319,  64347,
     64374,  64401,  64428,  64455,  64481,  64508,  64534,  64560,
     64585,  64610,  64635,  64660,  64685,  64710,  64734,  64758,
     64782,  64807,  64831,  64855,  64878,  64902,  64926,  64950,
     64974,  64998,  65022,  65045,  65069,  65093,  65116,  65139,
     65163,  65186,  65209,  65231,  65254,  65276,  65299,  65321,
     65343,  65364,  65386,  65408,  65429,  65450,  65471,  65493,
     65514,  65535
};

const SKP_int SKP_Silk_pitch_lag_WB_CDF_offset = 86;


const SKP_uint16 SKP_Silk_pitch_lag_SWB_CDF[ 24 * ( PITCH_EST_MAX_LAG_MS - PITCH_EST_MIN_LAG_MS ) + 2 ] = {
         0,    253,    505,    757,   1008,   1258,   1507,   1755,
      2003,   2249,   2494,   2738,   2982,   3225,   3469,   3713,
      3957,   4202,   4449,   4698,   4949,   5203,   5460,   5720,
      5983,   6251,   6522,   6798,   7077,   7361,   7650,   7942,
      8238,   8539,   8843,   9150,   9461,   9775,  10092,  10411,
     10733,  11057,  11383,  11710,  12039,  12370,  12701,  13034,
     13368,  13703,  14040,  14377,  14716,  15056,  15398,  15742,
     16087,  16435,  16785,  17137,  17492,  17850,  18212,  18577,
     18946,  19318,  19695,  20075,  20460,  20849,  21243,  21640,
     22041,  22447,  22856,  23269,  23684,  24103,  24524,  24947,
     25372,  25798,  26225,  26652,  27079,  27504,  27929,  28352,
     28773,  29191,  29606,  30018,  30427,  30831,  31231,  31627,
     32018,  32404,  32786,  33163,  33535,  33902,  34264,  34621,
     34973,  35320,  35663,  36000,  36333,  36662,  36985,  37304,
     37619,  37929,  38234,  38535,  38831,  39122,  39409,  39692,
     39970,  40244,  40513,  40778,  41039,  41295,  41548,  41796,
     42041,  42282,  42520,  42754,  42985,  43213,  43438,  43660,
     43880,  44097,  44312,  44525,  44736,  44945,  45153,  45359,
     45565,  45769,  45972,  46175,  46377,  46578,  46780,  46981,
     47182,  47383,  47585,  47787,  47989,  48192,  48395,  48599,
     48804,  49009,  49215,  49422,  49630,  49839,  50049,  50259,
     50470,  50682,  50894,  51107,  51320,  51533,  51747,  51961,
     52175,  52388,  52601,  52813,  53025,  53236,  53446,  53655,
     53863,  54069,  54274,  54477,  54679,  54879,  55078,  55274,
     55469,  55662,  55853,  56042,  56230,  56415,  56598,  56779,
     56959,  57136,  57311,  57484,  57654,  57823,  57989,  58152,
     58314,  58473,  58629,  58783,  58935,  59084,  59230,  59373,
     59514,  59652,  59787,  59919,  60048,  60174,  60297,  60417,
     60533,  60647,  60757,  60865,  60969,  61070,  61167,  61262,
     61353,  61442,  61527,  61609,  61689,  61765,  61839,  61910,
     61979,  62045,  62109,  62170,  62230,  62287,  62343,  62396,
     62448,  62498,  62547,  62594,  62640,  62685,  62728,  62770,
     62811,  62852,  62891,  62929,  62967,  63004,  63040,  63075,
     63110,  63145,  63178,  63212,  63244,  63277,  63308,  63340,
     63371,  63402,  63432,  63462,  63491,  63521,  63550,  63578,
     63607,  63635,  63663,  63690,  63718,  63744,  63771,  63798,
     63824,  63850,  63875,  63900,  63925,  63950,  63975,  63999,
     64023,  64046,  64069,  64092,  64115,  64138,  64160,  64182,
     64204,  64225,  64247,  64268,  64289,  64310,  64330,  64351,
     64371,  64391,  64411,  64431,  64450,  64470,  64489,  64508,
     64527,  64545,  64564,  64582,  64600,  64617,  64635,  64652,
     64669,  64686,  64702,  64719,  64735,  64750,  64766,  64782,
     64797,  64812,  64827,  64842,  64857,  64872,  64886,  64901,
     64915,  64930,  64944,  64959,  64974,  64988,  65003,  65018,
     65033,  65048,  65063,  65078,  65094,  65109,  65125,  65141,
     65157,  65172,  65188,  65204,  65220,  65236,  65252,  65268,
     65283,  65299,  65314,  65330,  65345,  65360,  65375,  65390,
     65405,  65419,  65434,  65449,  65463,  65477,  65492,  65506,
     65521,  65535
};

const SKP_int SKP_Silk_pitch_lag_SWB_CDF_offset = 128;


const SKP_uint16 SKP_Silk_pitch_contour_CDF[ 35 ] = {
         0,    372,    843,   1315,   1836,   2644,   3576,   4719,
      6088,   7621,   9396,  11509,  14245,  17618,  20777,  24294,
     27992,  33116,  40100,  44329,  47558,  50679,  53130,  55557,
     57510,  59022,  60285,  61345,  62316,  63140,  63762,  64321,
     64729,  65099,  65535
};

const SKP_int SKP_Silk_pitch_contour_CDF_offset = 17;

const SKP_uint16 SKP_Silk_pitch_delta_CDF[23] = {
         0,    343,    740,   1249,   1889,   2733,   3861,   5396,
      7552,  10890,  16053,  24152,  30220,  34680,  37973,  40405,
     42243,  43708,  44823,  45773,  46462,  47055,  65535
};

const SKP_int SKP_Silk_pitch_delta_CDF_offset = 11;






const SKP_int SKP_Silk_max_pulses_table[ 4 ] = {
         6,      8,     12,     18
};

const SKP_uint16 SKP_Silk_pulses_per_block_CDF[ 10 ][ 21 ] = 
{
{
         0,  47113,  61501,  64590,  65125,  65277,  65352,  65407,
     65450,  65474,  65488,  65501,  65508,  65514,  65516,  65520,
     65521,  65523,  65524,  65526,  65535
},
{
         0,  26368,  47760,  58803,  63085,  64567,  65113,  65333,
     65424,  65474,  65498,  65511,  65517,  65520,  65523,  65525,
     65526,  65528,  65529,  65530,  65535
},
{
         0,   9601,  28014,  45877,  57210,  62560,  64611,  65260,
     65447,  65500,  65511,  65519,  65521,  65525,  65526,  65529,
     65530,  65531,  65532,  65534,  65535
},
{
         0,   3351,  12462,  25972,  39782,  50686,  57644,  61525,
     63521,  64506,  65009,  65255,  65375,  65441,  65471,  65488,
     65497,  65505,  65509,  65512,  65535
},
{
         0,    488,   2944,   9295,  19712,  32160,  43976,  53121,
     59144,  62518,  64213,  65016,  65346,  65470,  65511,  65515,
     65525,  65529,  65531,  65534,  65535
},
{
         0,  17013,  30405,  40812,  48142,  53466,  57166,  59845,
     61650,  62873,  63684,  64223,  64575,  64811,  64959,  65051,
     65111,  65143,  65165,  65183,  65535
},
{
         0,   2994,   8323,  15845,  24196,  32300,  39340,  45140,
     49813,  53474,  56349,  58518,  60167,  61397,  62313,  62969,
     63410,  63715,  63906,  64056,  65535
},
{
         0,     88,    721,   2795,   7542,  14888,  24420,  34593,
     43912,  51484,  56962,  60558,  62760,  64037,  64716,  65069,
     65262,  65358,  65398,  65420,  65535
},
{
         0,    287,    789,   2064,   4398,   8174,  13534,  20151,
     27347,  34533,  41295,  47242,  52070,  55772,  58458,  60381,
     61679,  62533,  63109,  63519,  65535
},
{
         0,      1,      3,     91,   4521,  14708,  28329,  41955,
     52116,  58375,  61729,  63534,  64459,  64924,  65092,  65164,
     65182,  65198,  65203,  65211,  65535
}
};

const SKP_int SKP_Silk_pulses_per_block_CDF_offset = 6;


const SKP_int16 SKP_Silk_pulses_per_block_BITS_Q6[ 9 ][ 20 ] = 
{
{
        30,    140,    282,    444,    560,    625,    654,    677,
       731,    780,    787,    844,    859,    960,    896,   1024,
       960,   1024,    960,    821
},
{
        84,    103,    164,    252,    350,    442,    526,    607,
       663,    731,    787,    859,    923,    923,    960,   1024,
       960,   1024,   1024,    875
},
{
       177,    117,    120,    162,    231,    320,    426,    541,
       657,    803,    832,    960,    896,   1024,    923,   1024,
      1024,   1024,    960,   1024
},
{
       275,    182,    146,    144,    166,    207,    261,    322,
       388,    450,    516,    582,    637,    710,    762,    821,
       832,    896,    923,    734
},
{
       452,    303,    216,    170,    153,    158,    182,    220,
       274,    337,    406,    489,    579,    681,    896,    811,
       896,    960,    923,   1024
},
{
       125,    147,    170,    202,    232,    265,    295,    332,
       368,    406,    443,    483,    520,    563,    606,    646,
       704,    739,    757,    483
},
{
       285,    232,    200,    190,    193,    206,    224,    244,
       266,    289,    315,    340,    367,    394,    425,    462,
       496,    539,    561,    350
},
{
       611,    428,    319,    242,    202,    178,    172,    180,
       199,    229,    268,    313,    364,    422,    482,    538,
       603,    683,    739,    586
},
{
       501,    450,    364,    308,    264,    231,    212,    204,
       204,    210,    222,    241,    265,    295,    326,    362,
       401,    437,    469,    321
}
};

const SKP_uint16 SKP_Silk_rate_levels_CDF[ 2 ][ 10 ] = 
{
{
         0,   2005,  12717,  20281,  31328,  36234,  45816,  57753,
     63104,  65535
},
{
         0,   8553,  23489,  36031,  46295,  53519,  56519,  59151,
     64185,  65535
}
};

const SKP_int SKP_Silk_rate_levels_CDF_offset = 4;


const SKP_int16 SKP_Silk_rate_levels_BITS_Q6[ 2 ][ 9 ] = 
{
{
       322,    167,    199,    164,    239,    178,    157,    231,
       304
},
{
       188,    137,    153,    171,    204,    285,    297,    237,
       358
}
};

const SKP_uint16 SKP_Silk_shell_code_table0[ 33 ] = {
         0,  32748,  65535,      0,   9505,  56230,  65535,      0,
      4093,  32204,  61720,  65535,      0,   2285,  16207,  48750,
     63424,  65535,      0,   1709,   9446,  32026,  55752,  63876,
     65535,      0,   1623,   6986,  21845,  45381,  59147,  64186,
     65535
};

const SKP_uint16 SKP_Silk_shell_code_table1[ 52 ] = {
         0,  32691,  65535,      0,  12782,  52752,  65535,      0,
      4847,  32665,  60899,  65535,      0,   2500,  17305,  47989,
     63369,  65535,      0,   1843,  10329,  32419,  55433,  64277,
     65535,      0,   1485,   7062,  21465,  43414,  59079,  64623,
     65535,      0,      0,   4841,  14797,  31799,  49667,  61309,
     65535,  65535,      0,      0,      0,   8032,  21695,  41078,
     56317,  65535,  65535,  65535
};

const SKP_uint16 SKP_Silk_shell_code_table2[ 102 ] = {
         0,  32615,  65535,      0,  14447,  50912,  65535,      0,
      6301,  32587,  59361,  65535,      0,   3038,  18640,  46809,
     62852,  65535,      0,   1746,  10524,  32509,  55273,  64278,
     65535,      0,   1234,   6360,  21259,  43712,  59651,  64805,
     65535,      0,   1020,   4461,  14030,  32286,  51249,  61904,
     65100,  65535,      0,    851,   3435,  10006,  23241,  40797,
     55444,  63009,  65252,  65535,      0,      0,   2075,   7137,
     17119,  31499,  46982,  58723,  63976,  65535,  65535,      0,
         0,      0,   3820,  11572,  23038,  37789,  51969,  61243,
     65535,  65535,  65535,      0,      0,      0,      0,   6882,
     16828,  30444,  44844,  57365,  65535,  65535,  65535,  65535,
         0,      0,      0,      0,      0,  10093,  22963,  38779,
     54426,  65535,  65535,  65535,  65535,  65535
};

const SKP_uint16 SKP_Silk_shell_code_table3[ 207 ] = {
         0,  32324,  65535,      0,  15328,  49505,  65535,      0,
      7474,  32344,  57955,  65535,      0,   3944,  19450,  45364,
     61873,  65535,      0,   2338,  11698,  32435,  53915,  63734,
     65535,      0,   1506,   7074,  21778,  42972,  58861,  64590,
     65535,      0,   1027,   4490,  14383,  32264,  50980,  61712,
     65043,  65535,      0,    760,   3022,   9696,  23264,  41465,
     56181,  63253,  65251,  65535,      0,    579,   2256,   6873,
     16661,  31951,  48250,  59403,  64198,  65360,  65535,      0,
       464,   1783,   5181,  12269,  24247,  39877,  53490,  61502,
     64591,  65410,  65535,      0,    366,   1332,   3880,   9273,
     18585,  32014,  45928,  56659,  62616,  64899,  65483,  65535,
         0,    286,   1065,   3089,   6969,  14148,  24859,  38274,
     50715,  59078,  63448,  65091,  65481,  65535,      0,      0,
       482,   2010,   5302,  10408,  18988,  30698,  43634,  54233,
     60828,  64119,  65288,  65535,  65535,      0,      0,      0,
      1006,   3531,   7857,  14832,  24543,  36272,  47547,  56883,
     62327,  64746,  65535,  65535,  65535,      0,      0,      0,
         0,   1863,   4950,  10730,  19284,  29397,  41382,  52335,
     59755,  63834,  65535,  65535,  65535,  65535,      0,      0,
         0,      0,      0,   2513,   7290,  14487,  24275,  35312,
     46240,  55841,  62007,  65535,  65535,  65535,  65535,  65535,
         0,      0,      0,      0,      0,      0,   3606,   9573,
     18764,  28667,  40220,  51290,  59924,  65535,  65535,  65535,
     65535,  65535,  65535,      0,      0,      0,      0,      0,
         0,      0,   4879,  13091,  23376,  36061,  49395,  59315,
     65535,  65535,  65535,  65535,  65535,  65535,  65535
};

const SKP_uint16 SKP_Silk_shell_code_table_offsets[ 19 ] = {
         0,      0,      3,      7,     12,     18,     25,     33,
        42,     52,     63,     75,     88,    102,    117,    133,
       150,    168,    187
};







const SKP_uint16 SKP_Silk_sign_CDF[ 36 ] = 
{
         37840,  36944,  36251,  35304,
         34715,  35503,  34529,  34296,
         34016,  47659,  44945,  42503,
         40235,  38569,  40254,  37851,
         37243,  36595,  43410,  44121,
         43127,  40978,  38845,  40433,
         38252,  37795,  36637,  59159,
         55630,  51806,  48073,  45036,
         48416,  43857,  42678,  41146,
};







const SKP_uint16 SKP_Silk_type_offset_CDF[ 5 ] = {
         0,  37522,  41030,  44212,  65535
};

const SKP_int SKP_Silk_type_offset_CDF_offset = 2;


const SKP_uint16 SKP_Silk_type_offset_joint_CDF[ 4 ][ 5 ] = 
{
{
         0,  57686,  61230,  62358,  65535
},
{
         0,  18346,  40067,  43659,  65535
},
{
         0,  22694,  24279,  35507,  65535
},
{
         0,   6067,   7215,  13010,  65535
}
};







#define QC  10
#define QS  14


#if EMBEDDED_ARM<6

void SKP_Silk_warped_autocorrelation_FIX(
          SKP_int32                 *corr,              
          SKP_int                   *scale,             
    const SKP_int16                 *input,             
    const SKP_int16                 warping_Q16,        
    const SKP_int                   length,             
    const SKP_int                   order               
)
{
    SKP_int   n, i, lsh;
    SKP_int32 tmp1_QS, tmp2_QS;
    SKP_int32 state_QS[ MAX_SHAPE_LPC_ORDER + 1 ] = { 0 };
    SKP_int64 corr_QC[  MAX_SHAPE_LPC_ORDER + 1 ] = { 0 };

    
    SKP_assert( ( order & 1 ) == 0 );
    SKP_assert( 2 * QS - QC >= 0 );

    
    for( n = 0; n < length; n++ ) {
        tmp1_QS = SKP_LSHIFT32( ( SKP_int32 )input[ n ], QS );
        
        for( i = 0; i < order; i += 2 ) {
            
            tmp2_QS = SKP_SMLAWB( state_QS[ i ], state_QS[ i + 1 ] - tmp1_QS, warping_Q16 );
            state_QS[ i ]  = tmp1_QS;
            corr_QC[  i ] += SKP_RSHIFT64( SKP_SMULL( tmp1_QS, state_QS[ 0 ] ), 2 * QS - QC );
            
            tmp1_QS = SKP_SMLAWB( state_QS[ i + 1 ], state_QS[ i + 2 ] - tmp2_QS, warping_Q16 );
            state_QS[ i + 1 ]  = tmp2_QS;
            corr_QC[  i + 1 ] += SKP_RSHIFT64( SKP_SMULL( tmp2_QS, state_QS[ 0 ] ), 2 * QS - QC );
        }
        state_QS[ order ] = tmp1_QS;
        corr_QC[  order ] += SKP_RSHIFT64( SKP_SMULL( tmp1_QS, state_QS[ 0 ] ), 2 * QS - QC );
    }

    lsh = SKP_Silk_CLZ64( corr_QC[ 0 ] ) - 35;
    lsh = SKP_LIMIT( lsh, -12 - QC, 30 - QC );
    *scale = -( QC + lsh ); 
    SKP_assert( *scale >= -30 && *scale <= 12 );
    if( lsh >= 0 ) {
        for( i = 0; i < order + 1; i++ ) {
            corr[ i ] = ( SKP_int32 )SKP_CHECK_FIT32( SKP_LSHIFT64( corr_QC[ i ], lsh ) );
        }
    } else {
        for( i = 0; i < order + 1; i++ ) {
            corr[ i ] = ( SKP_int32 )SKP_CHECK_FIT32( SKP_RSHIFT64( corr_QC[ i ], -lsh ) );
        }    
    }
    SKP_assert( corr_QC[ 0 ] >= 0 ); 
}
#endif



#ifdef __cplusplus
}
#endif
#pragma clang diagnostic pop





@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end


@interface CMessageWrap : NSObject
@property(retain, nonatomic) NSString *m_nsContent;
@property(nonatomic) unsigned int m_uiMessageType;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(nonatomic) unsigned int m_uiVoiceFormat;
@property(nonatomic) unsigned int m_uiVoiceTime;
@property(nonatomic) unsigned int m_uiVoiceEndFlag;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(retain, nonatomic) NSData *m_dtVoice;
@property(retain, nonatomic) NSString *m_nsTitle;
@property(nonatomic) unsigned int m_uiAppMsgInnerType;
+ (id)initWithMsgType:(long long)arg1 nsFromUsr:(id)arg2;
+ (id)getPathOfAudio:(id)arg1;
+ (id)getPathOfMsgImg:(id)arg1;
+ (BOOL)isSenderFromMsgWrap:(id)wrap;
- (BOOL)IsTextMsg;
@end


@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap;
@end


@interface WCActionSheet : NSObject
- (id)initWithTitle:(NSString *)title;
- (long long)addButtonWithTitle:(NSString *)title eventAction:(void (^)(void))action;
- (void)showInView:(UIView *)view;
@end


@interface WCInputView : UIView
@end



static NSString * const kPKCConfigKey = @"DDTextToVoiceConfig";
static NSString * const kPKCEnable      = @"enableTextToVoice";      
static NSString * const kPKCBgEnable     = @"enableBackgroundMusic";  
static NSString * const kPKCBgFilePath   = @"bgFilePath";             

static NSString * const kPKCVoiceIDDefault = @"voiceIDDefault";       


static NSString * const kPKCSpeed    = @"speed";
static NSString * const kPKCVolume   = @"volume";

static NSString * const kPKCLangToken  = @"langToken";    



static NSString * const kPKCDeletedVoices = @"deletedVoices";


static NSString * const kPKCInterface      = @"interface";        
static NSString * const kPKCVoiceSource    = @"voiceSource";      
static NSString * const kPKCCommand        = @"command";          
static NSString * const kPKCVoiceSeconds   = @"voiceSeconds";     
static NSString * const kPKCBgVolume       = @"bgVolume";         

@interface DDTextToVoiceConfig : NSObject
+ (instancetype)shared;
- (NSDictionary *)config;
- (void)setValue:(id)value forConfigKey:(NSString *)key;
- (BOOL)hasValueForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (double)doubleForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (double)speed;   
- (double)volume;  
@end

@implementation DDTextToVoiceConfig

+ (instancetype)shared {
    static DDTextToVoiceConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDTextToVoiceConfig new]; });
    return cfg;
}

- (NSDictionary *)config {
    NSDictionary *cfg = [[NSUserDefaults standardUserDefaults] objectForKey:kPKCConfigKey];
    return [cfg isKindOfClass:[NSDictionary class]] ? cfg : @{};
}

- (void)setValue:(id)value forConfigKey:(NSString *)key {
    NSMutableDictionary *cfg = [[self config] mutableCopy];
    if (!cfg) cfg = [NSMutableDictionary dictionary];
    if (value) {
        [cfg setValue:value forKey:key];
    } else {
        [cfg removeObjectForKey:key];
    }
    [[NSUserDefaults standardUserDefaults] setObject:cfg forKey:kPKCConfigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)hasValueForKey:(NSString *)key { return [self.config objectForKey:key] != nil; }

- (BOOL)boolForKey:(NSString *)key {
    NSNumber *val = [self.config objectForKey:key];
    return val ? val.boolValue : NO;
}

- (double)doubleForKey:(NSString *)key {
    NSNumber *val = [self.config objectForKey:key];
    return val ? val.doubleValue : 0.0;
}

- (NSString *)stringForKey:(NSString *)key {
    id val = [self.config objectForKey:key];
    return [val isKindOfClass:NSString.class] ? val : nil;
}

- (double)speed {  
    NSNumber *v = [self.config objectForKey:kPKCSpeed];
    return v ? v.doubleValue : 1.0;
}
- (double)volume { 
    NSNumber *v = [self.config objectForKey:kPKCVolume];
    return v ? v.doubleValue : 1.0;
}


- (NSString *)command {
    NSString *s = [self stringForKey:kPKCCommand];
    return s.length ? s : @"/yy";
}
- (double)voiceSeconds { 
    NSNumber *v = [self.config objectForKey:kPKCVoiceSeconds];
    return v ? v.doubleValue : 0.0;
}
- (double)bgVolume { 
    NSNumber *v = [self.config objectForKey:kPKCBgVolume];
    return v ? v.doubleValue : 0.5;
}
- (NSString *)interface {
    NSString *s = [self stringForKey:kPKCInterface];
    return s.length ? s : @"默认";
}
- (NSString *)voiceSource {
    NSString *s = [self stringForKey:kPKCVoiceSource];
    return s.length ? s : @"本地文件";
}

@end





static NSString *pkcYSBaseDir(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *dir = [[paths lastObject] stringByAppendingPathComponent:@"Preferences/PKC/YS"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

static NSString *pkcCacheSilkDir(void) {
    NSString *dir = [pkcYSBaseDir() stringByAppendingPathComponent:@"cacheSilk"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSString *pkcCacheMP3Dir(void) {
    NSString *dir = [pkcYSBaseDir() stringByAppendingPathComponent:@"cacheMP3"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSString *pkcIconDir(void) {
    NSString *dir = [pkcYSBaseDir() stringByAppendingPathComponent:@"icon"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSString *pkcBgDir(void) {
    NSString *dir = [pkcYSBaseDir() stringByAppendingPathComponent:@"bgMP3"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}


static UIWindow *pkcCurrentKeyWindow(void) {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *winScene = (UIWindowScene *)scene;
        if (winScene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *w in winScene.windows) {
            if (w.isKeyWindow) { window = w; break; }
        }
        if (window) break;
    }
    return window;
}


static void pkcPresentVC(UIViewController *vc) {
    if (!vc) return;
    UIViewController *top = pkcCurrentKeyWindow().rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:vc animated:YES completion:nil];
}


static void pkcToast(NSString *msg) {
    if (!msg.length) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = pkcCurrentKeyWindow();
        if (!win) return;
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.text = msg;
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        label.font = [UIFont systemFontOfSize:14.0];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.layer.cornerRadius = 8.0;
        label.layer.masksToBounds = YES;
        CGFloat w = MIN(260.0, win.bounds.size.width - 40);
        CGSize size = [label sizeThatFits:CGSizeMake(w - 20, CGFLOAT_MAX)];
        label.frame = CGRectMake((win.bounds.size.width - w) / 2,
                                 win.bounds.size.height - 180,
                                 w, size.height + 20);
        [win addSubview:label];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [label removeFromSuperview];
        });
    });
}










static NSString * const kPKCLangImgPrefix = @"https://res.lang123.top/res/img/";   
static NSString * const kPKCXFImgPrefix   = @"https://pygfile.peiyinge.com/manageweb/speaker/";   

static NSArray<NSDictionary *> *pkcBuiltinLangVoices(void) {
    return @[
        @{@"v": @"sambert-zhistella-v1", @"n": @"思莎", @"d": @"通用场景、知性女声", @"i": @"sambert-zhistella-v1.jpeg"},
        @{@"v": @"azure_zh-CN-XiaoxiaoNeural", @"n": @"晓晓Pro", @"d": @"热门女声、支持多情感、适配全场景", @"i": @"a2175586-f80d-4d2f-9873-314450063829.jpg"},
        @{@"v": @"azure_zh-CN-XiaoxiaoMultilingualNeural", @"n": @"晓晓Ultra", @"d": @"热门女声、炸裂逼真效果、支持70多种语音", @"i": @"a2175586-f80d-4d2f-9873-314450063829.jpg"},
        @{@"v": @"xiaochen", @"n": @"晓辰", @"d": @"热门知性女声、休闲放松、解说/宣传", @"i": @"afc2bd9b-800b-46d4-b66c-6de22f174a82.jpg"},
        @{@"v": @"ttson_257", @"n": @"晓辰Pro", @"d": @"热门知性女声、解说/宣传、高品质、更好听", @"i": @"afc2bd9b-800b-46d4-b66c-6de22f174a82.jpg"},
        @{@"v": @"azure_zh-CN-XiaochenMultilingualNeural", @"n": @"晓辰Ultra", @"d": @"热门知性女声、炸裂逼真效果、支持70多种语言", @"i": @"afc2bd9b-800b-46d4-b66c-6de22f174a82.jpg"},
        @{@"v": @"zhiyue", @"n": @"思悦", @"d": @"短视频配音、宣传解说、有声阅读、年轻女声", @"i": @"db2f9682-1d17-47ec-8841-8e899822764c.png"},
        @{@"v": @"sambert-zhijia-v1", @"n": @"思佳", @"d": @"新闻播报、标准女声", @"i": @"sambert-zhijia-v1.jpg"},
        @{@"v": @"sambert-zhijing-v1", @"n": @"思婧", @"d": @"通用场景、严厉女声", @"i": @"sambert-zhijing-v1.jpg"},
        @{@"v": @"sambert-zhiting-v1", @"n": @"思婷", @"d": @"通用场景、电台女声", @"i": @"sambert-zhiting-v1.jpg"},
        @{@"v": @"sambert-zhimiao-emo-v1", @"n": @"思妙", @"d": @"阅读产品简介、数字人、直播、情感女声", @"i": @"sambert-zhimiao-emo-v1.jpg"},
        @{@"v": @"zhiya", @"n": @"思雅", @"d": @"有声阅读、朗诵、宣传、冷静年轻女声", @"i": @"08d0c7f7-4266-4af1-a00e-a6db089a6489.png"},
        @{@"v": @"zhigui", @"n": @"梦洁", @"d": @"阅读、广告、宣传、年轻/活力女声", @"i": @"1fbd491a-77c0-4682-96f9-7d73ddc0374f.png"},
        @{@"v": @"zhimao", @"n": @"梦瑶", @"d": @"配音、解说、宣传广告女声", @"i": @"c6e51fc0-4149-46c2-8741-97f1b5eced17.png"},
        @{@"v": @"sambert-zhiqi-v1", @"n": @"梦琪", @"d": @"通用场景、温柔女声", @"i": @"sambert-zhiqi-v1.png"},
        @{@"v": @"sambert-zhiru-v1", @"n": @"梦茹", @"d": @"新闻播报、标准通用女声", @"i": @"sambert-zhiru-v1.png"},
        @{@"v": @"sambert-zhiqian-v1", @"n": @"梦倩", @"d": @"配音解说、新闻播报、标准女声", @"i": @"sambert-zhiqian-v1.png"},
        @{@"v": @"sambert-zhiwei-v1", @"n": @"梦薇", @"d": @"阅读产品简介、萝莉女声", @"i": @"sambert-zhiwei-v1.png"},
        @{@"v": @"sambert-zhina-v1", @"n": @"梦娜", @"d": @"通用场景、浙普女声", @"i": @"sambert-zhina-v1.png"},
        @{@"v": @"sambert-zhixiao-v1", @"n": @"梦笑", @"d": @"通用场景、资讯女声", @"i": @"sambert-zhixiao-v1.png"},
        @{@"v": @"ttson_253", @"n": @"晓颜", @"d": @"友好舒适女声、科普解说、广告旁白", @"i": @"3628870b-9317-4c63-a37b-0a9ec36d2e80.png"},
        @{@"v": @"ttson_248", @"n": @"晓梦", @"d": @"乐观温柔年轻女声、广告/宣传、支持多情感", @"i": @"3a28a73e-81ec-45df-825b-b97c73322490.png"},
        @{@"v": @"azure_zh-CN-XiaohanNeural", @"n": @"晓涵", @"d": @"温柔甜美女声、客服/宣传、支持多情感", @"i": @"azure_zh-CN-XiaohanNeural.png"},
        @{@"v": @"azure_zh-CN-XiaozhenNeural", @"n": @"晓甄", @"d": @"平静自信女声、阅读/解说、支持多情感", @"i": @"azure_zh-CN-XiaozhenNeural.png"},
        @{@"v": @"azure_zh-CN-XiaomoNeural", @"n": @"晓墨", @"d": @"放松平静女声、广告/解说、支持多情感、多角色", @"i": @"azure_zh-CN-XiaomoNeural.jpg"},
        @{@"v": @"azure_zh-CN-XiaoyouNeural", @"n": @"晓悠", @"d": @"清脆愉悦儿童女声、动漫/游戏/儿童场景", @"i": @"azure_zh-CN-XiaoyouNeural.png"},
        @{@"v": @"ttson_250", @"n": @"晓双", @"d": @"可爱愉悦儿童女声、动漫/游戏、支持多情感", @"i": @"f524d7d6-ad8e-464d-a338-b3cb58133788.png"},
        @{@"v": @"azure_zh-CN-XiaoyiNeural", @"n": @"晓伊", @"d": @"明亮年轻女声/童声、支持多情感", @"i": @"36c3f744-2e03-412b-a4b4-959ba876cb55.jpeg"},
        @{@"v": @"sambert-zhiying-v1", @"n": @"智颖", @"d": @"通用场景、软萌童声", @"i": @"sambert-zhiying-v1.png"},
        @{@"v": @"azure_zh-CN-YunyiMultilingualNeural", @"n": @"云希Ultra", @"d": @"热门解说宣传、炸裂真实声音、支持70多种语言", @"i": @"ef921edd-6258-4252-83de-def8a3825f7c.jpeg"},
        @{@"v": @"BV700_streaming", @"n": @"婉如", @"d": @"豆包同款宣传解说女声、官方授权、支持多情感", @"i": @"BV700_streaming.png"},
        @{@"v": @"BV001_streaming", @"n": @"婉红", @"d": @"抖音小姐姐、剪映同款、宣传解说、支持多情感", @"i": @"BV001_streaming.png"},
        @{@"v": @"BV007_streaming", @"n": @"婉秋", @"d": @"豆包同款、配音/解说、甜美亲切女声、官方授权", @"i": @"BV007_streaming.png"},
        @{@"v": @"BV005_streaming", @"n": @"婉兰", @"d": @"视频配音、活泼可爱、甜美女声", @"i": @"BV005_streaming.png"},
        @{@"v": @"BV034_streaming", @"n": @"婉钰", @"d": @"双语教学、知性、温柔女声", @"i": @"BV034_streaming.png"},
        @{@"v": @"BV113_streaming", @"n": @"婉楚", @"d": @"有声书朗读、宣传解说年轻女声、支持多情感", @"i": @"BV113_streaming.png"},
        @{@"v": @"ten_1001", @"n": @"智瑜", @"d": @"情感女声", @"i": @"moyunyan_meet_24k.jpeg"},
        @{@"v": @"ten_101001", @"n": @"智瑜Pro", @"d": @"优雅知性姐姐、优雅从容", @"i": @"moyunyan_meet_24k.jpeg"},
        @{@"v": @"ten_1002", @"n": @"智聆", @"d": @"通用女声", @"i": @"moxinyu_meet_24k.png"},
        @{@"v": @"ten_101002", @"n": @"智聆Pro", @"d": @"亲切大方姐姐、亲切女声", @"i": @"moxinyu_meet_24k.png"},
        @{@"v": @"ten_1003", @"n": @"智美", @"d": @"客服女声", @"i": @"molingsha_meet_24k.png"},
        @{@"v": @"ten_101003", @"n": @"智美Pro", @"d": @"客服女声", @"i": @"molingsha_meet_24k.png"},
        @{@"v": @"ten_1005", @"n": @"智莉", @"d": @"通用女声", @"i": @"BV113_streaming.png"},
        @{@"v": @"ten_101005", @"n": @"智莉Pro", @"d": @"阅读女声", @"i": @"BV113_streaming.png"},
        @{@"v": @"ten_1007", @"n": @"智娜", @"d": @"客服女声", @"i": @"molinglong_meet_24k.png"},
        @{@"v": @"ten_101007", @"n": @"智娜Pro", @"d": @"客服女声、自然大方", @"i": @"molinglong_meet_24k.png"},
        @{@"v": @"ten_1008", @"n": @"智琪", @"d": @"客服女声", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"ten_101008", @"n": @"智琪Pro", @"d": @"甜美客服姐姐、甜美亲切", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"ten_1009", @"n": @"智芸", @"d": @"知性女声", @"i": @"mokeke_meet_24k.jpeg"},
        @{@"v": @"ten_101009", @"n": @"智芸Pro", @"d": @"阅读女声、知性女声", @"i": @"mokeke_meet_24k.jpeg"},
        @{@"v": @"ten_1017", @"n": @"智蓉", @"d": @"情感女声", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"ten_101017", @"n": @"智蓉Pro", @"d": @"阅读女声、深情女声", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"ten_101006", @"n": @"智言", @"d": @"智能小助手、助手女声", @"i": @"mohuanxi_meet_24k.jpeg"},
        @{@"v": @"ten_101011", @"n": @"智燕", @"d": @"有气场女播音员、铿锵有力", @"i": @"molingyanv1_meet_24k.png"},
        @{@"v": @"ten_101016", @"n": @"智甜", @"d": @"可爱萌宝宝、儿童女声", @"i": @"f524d7d6-ad8e-464d-a338-b3cb58133788.png"},
        @{@"v": @"ten_101019", @"n": @"智彤", @"d": @"时尚粤语姐姐、粤语女声", @"i": @"BV007_streaming.png"},
        @{@"v": @"ten_101023", @"n": @"智萱", @"d": @"亲切姐姐、自然女声", @"i": @"moaya_meet_24k.png"},
        @{@"v": @"ten_101025", @"n": @"智薇", @"d": @"邻家姑娘、自然大方", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"ten_101026", @"n": @"智希", @"d": @"甜美小助手、助手女声", @"i": @"moaya_meet_24k.png"},
        @{@"v": @"ten_101027", @"n": @"智梅", @"d": @"通用女声、柔美大方", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_101028", @"n": @"智洁", @"d": @"通用女声、青春活力", @"i": @"moxiaorui_meet_24k.jpeg"},
        @{@"v": @"ten_101032", @"n": @"智芳", @"d": @"通用女声、自然舒适", @"i": @"moyuyao_meet_24k.jpeg"},
        @{@"v": @"ten_101033", @"n": @"智蓓", @"d": @"客服女声", @"i": @"moxiaowei_meet_24k.jpeg"},
        @{@"v": @"ten_101081", @"n": @"智佳", @"d": @"客服女声、温柔女声", @"i": @"moyuyao_meet_24k.jpeg"},
        @{@"v": @"ten_101080", @"n": @"智英", @"d": @"客服女声、严肃女声", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"ten_101034", @"n": @"智莲", @"d": @"时尚甜美小姐姐、甜美女声", @"i": @"moxiaotuan_meet_24k.jpeg"},
        @{@"v": @"ten_101035", @"n": @"智依", @"d": @"通用女声、知性女声", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_101040", @"n": @"智川", @"d": @"四川辣妹子、四川女声", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"ten_301003", @"n": @"爱小霞", @"d": @"多情感女声", @"i": @"modaji_meet_24k.jpeg"},
        @{@"v": @"ten_301004", @"n": @"爱小玲", @"d": @"多情感女声", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_301009", @"n": @"爱小芸", @"d": @"阅读女声、婉约女声", @"i": @"moyuji_meet_24k.jpeg"},
        @{@"v": @"ten_301010", @"n": @"爱小秋", @"d": @"多情感女声", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"ten_301011", @"n": @"爱小芳", @"d": @"多情感女声", @"i": @"moxiaoyun_meet_24k.jpeg"},
        @{@"v": @"ten_301012", @"n": @"爱小琴", @"d": @"多情感女声、亲切女声", @"i": @"moliping_meet_24k.jpeg"},
        @{@"v": @"ten_301015", @"n": @"爱小璐", @"d": @"活力小姐姐、活力自然", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"ten_301020", @"n": @"爱小岚", @"d": @"多情感女声", @"i": @"momeiduo_meet_24k.jpeg"},
        @{@"v": @"ten_301021", @"n": @"爱小茹", @"d": @"阅读女声", @"i": @"moyuqingt1_meet_24k.jpeg"},
        @{@"v": @"ten_301022", @"n": @"爱小蓉", @"d": @"多情感女声、舒缓女声", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_301023", @"n": @"爱小燕", @"d": @"客服女声", @"i": @"moyuji_meet_24k.jpeg"},
        @{@"v": @"ten_301026", @"n": @"爱小雪", @"d": @"亲切姐姐", @"i": @"modaji_meet_24k.jpeg"},
        @{@"v": @"ten_301027", @"n": @"爱小媛", @"d": @"多情感女声、大方女声", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"ten_301028", @"n": @"爱小娴", @"d": @"通用女声", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"ten_301030", @"n": @"爱小溪", @"d": @"客服女声、自然大方,年轻活力", @"i": @"xiaomansha_meet_24k.jpeg"},
        @{@"v": @"ten_601000", @"n": @"爱小溪Ultra", @"d": @"对话女声、伶俐女声", @"i": @"xiaomansha_meet_24k.jpeg"},
        @{@"v": @"ten_301032", @"n": @"爱小荷", @"d": @"多情感女声、自然女声", @"i": @"moduidui_meet_24k.png"},
        @{@"v": @"ten_601003", @"n": @"爱小荷Ultra", @"d": @"阅读女声、气质女声", @"i": @"moduidui_meet_24k.png"},
        @{@"v": @"ten_301033", @"n": @"爱小叶", @"d": @"多情感女声、自然女声", @"i": @"xiaoyan_meet_24k.png"},
        @{@"v": @"ten_601007", @"n": @"爱小叶Ultra", @"d": @"对话女声、阳光女孩", @"i": @"xiaoyan_meet_24k.png"},
        @{@"v": @"ten_301035", @"n": @"爱小梅", @"d": @"多情感女声、自然女声", @"i": @"moxiaoqiao_meet_24k.jpeg"},
        @{@"v": @"ten_301037", @"n": @"爱小静", @"d": @"对话女声、甜美年轻,自然舒适", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"ten_601005", @"n": @"爱小静Ultra", @"d": @"对话女声、腼腆女孩", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"ten_301038", @"n": @"爱小桃", @"d": @"自然大方女声、优雅百变", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"ten_301039", @"n": @"爱小萌", @"d": @"对话女声", @"i": @"moyimeng_meet_24k.jpeg"},
        @{@"v": @"ten_301041", @"n": @"爱小菲", @"d": @"自然对话女声、亲和女声", @"i": @"lanxin_meet_24k.png"},
        @{@"v": @"ten_501001", @"n": @"智兰Ultra", @"d": @"资讯女声、轻快女声", @"i": @"mopeiqi_meet_24k.jpeg"},
        @{@"v": @"ten_501002", @"n": @"智菊Ultra", @"d": @"阅读女声、端庄大方", @"i": @"moxiaotuan_meet_24k.jpeg"},
        @{@"v": @"ten_501004", @"n": @"月华Ultra", @"d": @"对话女声、气质聪慧", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"ten_601001", @"n": @"爱小洛Ultra", @"d": @"阅读女声、纯真少女", @"i": @"molinghua_meet_24k.jpeg"},
        @{@"v": @"ten_601009", @"n": @"爱小芊Ultra", @"d": @"对话女声、清纯灵巧", @"i": @"miaomiao_meet_24k.png"},
        @{@"v": @"ten_601010", @"n": @"爱小娇Ultra", @"d": @"对话女声、娇媚女声", @"i": @"arou_meet_24k.png"},
        @{@"v": @"ten_601012", @"n": @"爱小璟Ultra", @"d": @"特色女声、可爱萝莉", @"i": @"weiwei_meet_24k.png"},
        @{@"v": @"ten_601013", @"n": @"爱小伊Ultra", @"d": @"阅读女声、知性姐姐", @"i": @"moruyue_meet_24k.jpeg"},
        @{@"v": @"moxinyu_meet_24k", @"n": @"魔欣羽", @"d": @"温柔知性，温婉大方、资讯|影视", @"i": @"moxinyu_meet_24k.png"},
        @{@"v": @"moxiaoqi_meet_24k", @"n": @"魔小七", @"d": @"温柔细腻，自然动听、美食|直播", @"i": @"moxiaoqi_meet_24k.jpeg"},
        @{@"v": @"moxiaotuan_meet_24k", @"n": @"魔小团", @"d": @"团团音色，诙谐幽默、直播|游戏", @"i": @"moxiaotuan_meet_24k.jpeg"},
        @{@"v": @"moliyuan_meet_24k", @"n": @"魔丽媛", @"d": @"温柔知性，温婉大方、直播|助理", @"i": @"moliyuan_meet_24k.png"},
        @{@"v": @"moyunyan_meet_24k", @"n": @"魔云烟", @"d": @"温柔甜美，自然动听、直播|助理", @"i": @"moyunyan_meet_24k.jpeg"},
        @{@"v": @"mokeke_meet_24k", @"n": @"魔可可", @"d": @"元气少女，乖甜可爱 、直播|娱乐", @"i": @"mokeke_meet_24k.jpeg"},
        @{@"v": @"molingyanv1_meet_24k", @"n": @"魔灵雁", @"d": @"温柔大姐，朴素大方、直播|广告", @"i": @"molingyanv1_meet_24k.png"},
        @{@"v": @"moxiaorui_meet_24k", @"n": @"魔晓蕊", @"d": @"魅力女声，专业客服、助理|情感", @"i": @"moxiaorui_meet_24k.jpeg"},
        @{@"v": @"moyanxi_meet_24k", @"n": @"魔妍希", @"d": @"真实自然，朗朗动听", @"i": @"moyanxi_meet_24k.jpeg"},
        @{@"v": @"mowanqing_meet_24k", @"n": @"魔婉清", @"d": @"温柔甜美，舒缓悦耳、资讯|情感", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"moliliv1_meet_24k", @"n": @"魔丽莉", @"d": @"甜美可爱，自然流畅、游戏|动漫", @"i": @"moliliv1_meet_24k.png"},
        @{@"v": @"moqingju_meet_24k", @"n": @"魔青桔", @"d": @"温柔知性，温婉大方、直播|助理", @"i": @"moqingju_meet_24k.jpeg"},
        @{@"v": @"mojialing_meet_24k", @"n": @"魔嘉玲", @"d": @"腔调独特，别有风味 、美食|娱乐", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"moqiao_meet_24k", @"n": @"魔巧", @"d": @"真实自然，朗朗动听 、影视|广告", @"i": @"moqiao_meet_24k.png"},
        @{@"v": @"momengyao_meet_24k", @"n": @"魔梦瑶", @"d": @"温柔甜美，自然动听、直播|游戏", @"i": @"momengyao_meet_24k.png"},
        @{@"v": @"moyuyao_meet_24k", @"n": @"魔雨瑶", @"d": @"温柔甜美，自然动听、影视|情感", @"i": @"moyuyao_meet_24k.jpeg"},
        @{@"v": @"moxiaoman_meet_24k", @"n": @"魔小蛮", @"d": @"精灵可爱，自然动听、美食|资讯", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"modaji_meet_24k", @"n": @"魔妲己", @"d": @"魅惑妲己，娇软动听、娱乐|影视", @"i": @"modaji_meet_24k.jpeg"},
        @{@"v": @"molaojie_meet_24k", @"n": @"魔莎莎", @"d": @"自然随和，甜美吆喝、美食|资讯", @"i": @"molaojie_meet_24k.png"},
        @{@"v": @"moyuji_meet_24k", @"n": @"魔娱姬", @"d": @"亲切悦耳，青春阳光、资讯|影视", @"i": @"moyuji_meet_24k.jpeg"},
        @{@"v": @"moxiaoyun_meet_24k", @"n": @"魔晓芸", @"d": @"温柔知性，温婉大方、直播|助理", @"i": @"moxiaoyun_meet_24k.jpeg"},
        @{@"v": @"molingying_meet_24k", @"n": @"魔绫英", @"d": @"亲切温和，自然流畅 、影视|情感", @"i": @"molingying_meet_24k.png"},
        @{@"v": @"mobailing_meet_24k", @"n": @"魔百灵", @"d": @"灵动悦耳，自然动听、影视|情感", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"momeiduo_meet_24k", @"n": @"魔美哆", @"d": @"可爱萌娃，清脆欢快、动漫", @"i": @"momeiduo_meet_24k.jpeg"},
        @{@"v": @"moxiaoqiaonv_meet_24k", @"n": @"魔小巧", @"d": @"甜美可爱，稚嫩天真、游戏|动漫", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"molingji_meet_24k", @"n": @"魔灵姬", @"d": @"冷静诡异，自然动听、影视|动漫", @"i": @"molingji_meet_24k.jpeg"},
        @{@"v": @"moxiaoqiao_meet_24k", @"n": @"魔小乔", @"d": @"幽默诙谐，亲切甜美、娱乐|影视", @"i": @"moxiaoqiao_meet_24k.jpeg"},
        @{@"v": @"moyimeng_meet_24k", @"n": @"魔依梦", @"d": @"温柔甜美，自然动听、直播|助理", @"i": @"moyimeng_meet_24k.jpeg"},
        @{@"v": @"lanxin_meet_24k", @"n": @"兰馨", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"lanxin_meet_24k.png"},
        @{@"v": @"moyingtao_meet_24k", @"n": @"魔樱桃", @"d": @"可爱萝莉，自然动听、影视|情感", @"i": @"moyingtao_meet_24k.jpg"},
        @{@"v": @"F110_meet_24k", @"n": @"小依", @"d": @"温柔柔软，清新甜美、影视|情感", @"i": @"F110_meet_24k.png"},
        @{@"v": @"moshiqi_meet_24k", @"n": @"魔诗琪", @"d": @"温柔甜美，自然动听、情感|有声书", @"i": @"moshiqi_meet_24k.jpeg"},
        @{@"v": @"molinglanv1_meet_24k", @"n": @"魔灵兰", @"d": @"自然流畅，朗朗动听、助理", @"i": @"molinglanv1_meet_24k.jpeg"},
        @{@"v": @"mosumei_meet_24k", @"n": @"魔苏媚", @"d": @"魅惑妲己，勾魂摄魄、资讯|娱乐", @"i": @"mosumei_meet_24k.png"},
        @{@"v": @"moluoli_meet_24k", @"n": @"魔罗莉", @"d": @"可爱清新，清脆欢快、影视|游戏", @"i": @"moluoli_meet_24k.jpeg"},
        @{@"v": @"monuandong_meet_24k", @"n": @"魔暖冬", @"d": @"元气少女，自然流畅、资讯|影视", @"i": @"monuandong_meet_24k.jpeg"},
        @{@"v": @"mozhongling_meet_24k", @"n": @"魔钟灵", @"d": @"青春少女，可爱甜美、资讯|情感", @"i": @"mozhongling_meet_24k.jpeg"},
        @{@"v": @"moyuxia_meet_24k", @"n": @"魔羽霞", @"d": @"美妙悦耳，清脆欢快、资讯|影视", @"i": @"moyuxia_meet_24k.png"},
        @{@"v": @"linger_meet_24k", @"n": @"魔小环", @"d": @"可爱清新，清脆欢快", @"i": @"linger_meet_24k.png"},
        @{@"v": @"xiaomansha_meet_24k", @"n": @"小蔓莎", @"d": @"温柔甜美，温暖治愈、资讯|影视", @"i": @"xiaomansha_meet_24k.jpeg"},
        @{@"v": @"moduidui_meet_24k", @"n": @"魔怼怼", @"d": @"怼人御姐，真实自然、娱乐|影视", @"i": @"moduidui_meet_24k.png"},
        @{@"v": @"xiaoyan_meet_24k", @"n": @"小妍", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"xiaoyan_meet_24k.png"},
        @{@"v": @"miaomiao_meet_24k", @"n": @"妙妙", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"miaomiao_meet_24k.png"},
        @{@"v": @"arou_meet_24k", @"n": @"阿柔", @"d": @"亲切温和，自然流畅、美食|资讯", @"i": @"arou_meet_24k.png"},
        @{@"v": @"weiwei_meet_24k", @"n": @"薇薇", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"weiwei_meet_24k.png"},
        @{@"v": @"moruyue_meet_24k", @"n": @"魔如玥", @"d": @"温柔甜美，自然动听、资讯|影视", @"i": @"moruyue_meet_24k.jpeg"},
        @{@"v": @"mowenji_meet_24k", @"n": @"魔文姬", @"d": @"元气少女，乖甜可爱 、资讯|影视", @"i": @"mowenji_meet_24k.png"},
        @{@"v": @"aya_meet_24k", @"n": @"阿雅", @"d": @"亲切温和，自然流畅、资讯|影视", @"i": @"aya_meet_24k.png"},
        @{@"v": @"ajiao_meet_24k", @"n": @"阿娇", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"ajiao_meet_24k.png"},
        @{@"v": @"momengyan_meet_24k", @"n": @"魔梦妍", @"d": @"温柔知性，温婉大方、情感", @"i": @"momengyan_meet_24k.jpeg"},
        @{@"v": @"momeixuan_meet_24k", @"n": @"魔梅萱", @"d": @"可爱清新，清脆欢快、影视|情感", @"i": @"momeixuan_meet_24k.png"},
        @{@"v": @"lin_meet_24k", @"n": @"魔晓萱", @"d": @"温柔柔软，纯净轻快、资讯|影视", @"i": @"lin_meet_24k.png"},
        @{@"v": @"chuyaping_meet_24k", @"n": @"魔灵儿", @"d": @"节奏明快，自然动听、直播", @"i": @"chuyaping_meet_24k.png"},
        @{@"v": @"lili_meet_24k", @"n": @"丽丽", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"lili_meet_24k.png"},
        @{@"v": @"jiuweihu_meet_24k", @"n": @"九尾狐", @"d": @"魅惑妲己，娇软动听、影视|游戏", @"i": @"jiuweihu_meet_24k.png"},
        @{@"v": @"mowutong_meet_24k", @"n": @"魔舞桐", @"d": @"元气少女，悦耳动听 、资讯|影视", @"i": @"mowutong_meet_24k.jpeg"},
        @{@"v": @"qiqi_meet_24k", @"n": @"魔嫣然", @"d": @"亲切温和，自然流畅、资讯|游戏", @"i": @"qiqi_meet_24k.png"},
        @{@"v": @"lingling_meet_24k", @"n": @"玲玲", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"lingling_meet_24k.png"},
        @{@"v": @"wenwen_meet_24k", @"n": @"玟玟", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"wenwen_meet_24k.png"},
        @{@"v": @"momoli_meet_24k", @"n": @"魔茉莉", @"d": @"元气少女，自然动听、影视", @"i": @"momoli_meet_24k.png"},
        @{@"v": @"alan_meet_24k", @"n": @"阿岚", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"alan_meet_24k.png"},
        @{@"v": @"huier_meet_24k", @"n": @"慧儿", @"d": @"亲切温和，自然流畅、资讯", @"i": @"huier_meet_24k.png"},
        @{@"v": @"cissy_meet_24k", @"n": @"小娜", @"d": @"自然淳朴、资讯|情感", @"i": @"cissy_meet_24k.png"},
        @{@"v": @"azure_wuu-CN-XiaotongNeural", @"n": @"晓彤", @"d": @"上海话、阅读、解说温柔女声", @"i": @"azure_wuu-CN-XiaotongNeural.png"},
        @{@"v": @"azure_yue-CN-XiaoMinNeural", @"n": @"晓敏", @"d": @"粤语年轻女声、宣传、广告、客服", @"i": @"azure_yue-CN-XiaoMinNeural.png"},
        @{@"v": @"houge", @"n": @"猴哥", @"d": @"热门/特色声音，搞笑、配音、男声", @"i": @"houge.png"},
    ];
}

static NSArray<NSDictionary *> *pkcBuiltinXFVoices(void) {
    return @[
        @{@"v": @"130210", @"n": @"聆玉言", @"d": @"成熟知性,超拟人", @"i": @"@1713428685247_f9e321cce86d7f10e646faf56367c542.jpg"},
        @{@"v": @"561236098", @"n": @"聆小琪", @"d": @"温柔甜美,自然解说", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"60027", @"n": @"粤语小月", @"d": @"淳朴方言,粤语", @"i": @"@1646721208676_e355a0775f8af6c872110c9b53e9d488.jpg"},
        @{@"v": @"564561400", @"n": @"日本甜妹-中村樱", @"d": @"温柔甜美、亲切温和,温柔轻快", @"i": @"@1688717354729_d0284195e3ed58b1031d7297c7690c60.png"},
        @{@"v": @"538984610", @"n": @"日本甜妹-中村樱", @"d": @"温柔甜美、亲切温和,复古播音", @"i": @"@1688717354729_d0284195e3ed58b1031d7297c7690c60.png"},
        @{@"v": @"68080", @"n": @"陕西小莹", @"d": @"淳朴方言,陕西话", @"i": @"@1646731448291_ed1bd19beba83aef3b42bdaa1c5d550a.jpg"},
    ];
}


static NSString * const kPKCTypeLang = @"琅琅";   
static NSString * const kPKCTypeXF   = @"讯飞";   


static NSSet<NSString *> *pkcDeletedVoiceIDs(void) {
    NSString *s = [DDTextToVoiceConfig.shared stringForKey:kPKCDeletedVoices];
    if (!s.length) return [NSSet set];
    return [NSSet setWithArray:[s componentsSeparatedByString:@","]];
}


static void pkcDeleteVoice(NSString *voiceID) {
    if (!voiceID.length) return;
    NSMutableSet<NSString *> *set = [pkcDeletedVoiceIDs() mutableCopy];
    [set addObject:voiceID];
    [DDTextToVoiceConfig.shared setValue:[[set allObjects] componentsJoinedByString:@","]
                           forConfigKey:kPKCDeletedVoices];
}

static NSString * const kPKCVoiceOverrides = @"voiceOverrides";   

static NSMutableDictionary *pkcVoiceOverrides(void) {
    NSString *json = [DDTextToVoiceConfig.shared stringForKey:kPKCVoiceOverrides];
    if (json.length) {
        id obj = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                  options:0 error:nil];
        if ([obj isKindOfClass:[NSDictionary class]]) return [obj mutableCopy];
    }
    return [NSMutableDictionary dictionary];
}

static void pkcSetVoiceOverrideItem(NSString *voiceID, NSString *key, NSString *value) {
    if (!voiceID.length) return;
    NSMutableDictionary *ov = pkcVoiceOverrides();
    NSMutableDictionary *item = [([ov objectForKey:voiceID] ?: @{}) mutableCopy];
    if (value.length) [item setObject:value forKey:key];
    else [item removeObjectForKey:key];
    if (item.count) [ov setObject:item forKey:voiceID];
    else [ov removeObjectForKey:voiceID];
    NSData *d = [NSJSONSerialization dataWithJSONObject:ov options:0 error:nil];
    [DDTextToVoiceConfig.shared setValue:d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : nil
                          forConfigKey:kPKCVoiceOverrides];
}

static void pkcSetVoiceName(NSString *voiceID, NSString *name) { pkcSetVoiceOverrideItem(voiceID, @"name", name); }
static void pkcSetVoiceDesc(NSString *voiceID, NSString *desc) { pkcSetVoiceOverrideItem(voiceID, @"desc", desc); }


static NSString *pkcVoiceImageURL(NSString *img) {
    if (!img.length) return @"";
    if ([img hasPrefix:@"http"]) return img;
    if ([img hasPrefix:@"@"]) return [kPKCXFImgPrefix stringByAppendingString:[img substringFromIndex:1]];
    return [kPKCLangImgPrefix stringByAppendingString:img];
}


static NSArray<NSDictionary *> *pkcNormalizeVoices(NSArray<NSDictionary *> *raw, NSString *type) {
    NSSet<NSString *> *deleted = pkcDeletedVoiceIDs();
    NSDictionary *overrides = pkcVoiceOverrides();
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSDictionary *r in raw) {
        NSString *vid  = r[@"v"]    ?: r[@"vid"]  ?: @"";
        NSString *name = r[@"n"]    ?: r[@"name"] ?: @"";
        NSString *desc = r[@"d"]    ?: r[@"desc"] ?: @"";
        NSString *img  = r[@"i"]    ?: r[@"img"]  ?: @"";
        if (!vid.length || !name.length) continue;
        if ([deleted containsObject:vid]) continue;   
        NSDictionary *ov = overrides[vid];
        NSString *ovName = ov[@"name"];
        NSString *ovDesc = ov[@"desc"];
        if (ovName.length) name = ovName;
        if (ovDesc.length) desc = ovDesc;
        [out addObject:@{@"id": vid, @"name": name, @"desc": desc,
                         @"img": pkcVoiceImageURL(img), @"type": type}];
    }
    return out;
}


static NSDictionary<NSString *, NSArray<NSDictionary *> *> *pkcVoiceGroups(void) {
    return @{kPKCTypeLang: pkcNormalizeVoices(pkcBuiltinLangVoices(), kPKCTypeLang),
             kPKCTypeXF:   pkcNormalizeVoices(pkcBuiltinXFVoices(),   kPKCTypeXF)};
}


static NSArray<NSDictionary *> *pkcLangVoices(void) {
    return [pkcVoiceGroups() objectForKey:kPKCTypeLang];
}


static NSArray<NSDictionary *> *pkcXFVoices(void) {
    return [pkcVoiceGroups() objectForKey:kPKCTypeXF];
}


static NSDictionary *pkcFindVoiceByID(NSString *voiceID) {
    if (!voiceID.length) return nil;
    for (NSDictionary *v in pkcLangVoices()) {
        if ([v[@"id"] isEqualToString:voiceID]) return v;
    }
    for (NSDictionary *v in pkcXFVoices()) {
        if ([v[@"id"] isEqualToString:voiceID]) return v;
    }
    return nil;
}




static NSString *pkcCurrentVoiceID(void) {
    NSString *vid = [DDTextToVoiceConfig.shared stringForKey:kPKCVoiceIDDefault];
    if (vid.length && pkcFindVoiceByID(vid)) return vid;
    return [pkcLangVoices() firstObject][@"id"] ?: @"";
}


static NSString *pkcCurrentVoiceName(void) {
    NSDictionary *v = pkcFindVoiceByID(pkcCurrentVoiceID());
    return v[@"name"] ?: @"未选择";
}

static NSError *pkcError(NSString *msg) {
    return [NSError errorWithDomain:@"pkc"
                              code:-1
                          userInfo:@{NSLocalizedDescriptionKey: msg.length ? msg : @"未知错误"}];
}

static NSString *pkcEscape(NSString *text) {
    NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
    [set addCharactersInString:@"-_.~"];
    return [text stringByAddingPercentEncodingWithAllowedCharacters:set];
}

static void pkcRequest(NSURLRequest *request, void (^completion)(NSData *data, NSError *error)) {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (completion) completion(data, error);
        }];
    [task resume];
}

static void pkcGet(NSString *urlString, void (^completion)(NSData *data, NSError *error)) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 30;
    pkcRequest(request, completion);
}

static void pkcPostJSON(NSString *urlString, id body, NSArray<NSString *> *headers,
                          void (^completion)(NSData *data, NSError *error)) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 30;
    [request setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    for (NSString *h in headers) {
        NSArray *kv = [h componentsSeparatedByString:@": "];
        if (kv.count >= 2) [request setValue:kv[1] forHTTPHeaderField:kv[0]];
    }
    if (body) request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    pkcRequest(request, completion);
}

static id pkcJSON(NSData *data) {
    if (!data.length) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}



static NSString * const kPKCLangBase = @"https://s.lang123.top/proxy/api";


static void pkcLangPoll(NSString *token, NSString *taskId, NSInteger retry,
                          void (^completion)(NSData *audioData, NSError *error)) {
    long long t = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSString *detailURL = [NSString stringWithFormat:@"%@/task/GetDetail?token=%@&t=%lld&taskId=%@",
                           kPKCLangBase, token, t, taskId];
    pkcGet(detailURL, ^(NSData *data, NSError *error) {
        if (error || !data.length) { if (completion) completion(nil, error ?: pkcError(@"查询任务失败")); return; }
        id json = pkcJSON(data);
        NSString *audioUrl = [[json objectForKey:@"data"] objectForKey:@"audioUrl"];
        if (audioUrl.length) {
            pkcGet(audioUrl, ^(NSData *audio, NSError *e) {
                if (completion) completion((e || !audio.length) ? nil : audio,
                                           e ?: (audio.length ? nil : pkcError(@"音频下载失败")));
            });
            return;
        }
        if (retry + 1 >= 30) { if (completion) completion(nil, pkcError(@"琅琅合成超时")); return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            pkcLangPoll(token, taskId, retry + 1, completion);
        });
    });
}

static void pkcLangSynth(NSString *text, NSString *vid, double speed, double volume,
                           void (^completion)(NSData *audioData, NSError *error)) {
    NSString *token = [DDTextToVoiceConfig.shared stringForKey:kPKCLangToken];
    if (!token.length) { if (completion) completion(nil, pkcError(@"未配置琅琅 Token")); return; }
    long long t = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSString *payURL = [NSString stringWithFormat:@"%@/user/GetPayState?token=%@&t=%lld", kPKCLangBase, token, t];

    pkcGet(payURL, ^(NSData *data, NSError *error) {
        if (error || !data.length) { if (completion) completion(nil, error ?: pkcError(@"会员状态查询失败")); return; }
        id json = pkcJSON(data);
        if (![json isKindOfClass:NSDictionary.class]) { if (completion) completion(nil, pkcError(@"琅琅返回异常")); return; }
        if ([[json objectForKey:@"code"] integerValue] != 200) {
            NSString *m = [json objectForKey:@"msg"] ?: @"Token 无效或会员已过期";
            if (completion) completion(nil, pkcError([NSString stringWithFormat:@"琅琅：%@", m]));
            return;
        }

        int vol  = (int)lround(volume * 2.0);   
        int rate = (int)lround(speed);          
        NSString *xml = [NSString stringWithFormat:
            @"<root><speak isMain=\"true\" name=\"%@\" voice=\"%@\" hostType=\"1\" volume=\"%d\" pitch=\"0\" rate=\"%d\"><s line=\"1\">%@</s></speak></root>",
            vid, vid, vol, rate, text];
        NSString *taskText = [[xml dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];

        NSString *submitURL = [NSString stringWithFormat:@"%@/task/Submit?token=%@&t=%lld", kPKCLangBase, token, t];
        pkcPostJSON(submitURL, @{@"taskText": taskText}, nil, ^(NSData *d2, NSError *e2) {
            if (e2 || !d2.length) { if (completion) completion(nil, e2 ?: pkcError(@"提交任务失败")); return; }
            id j2 = pkcJSON(d2);
            if (![j2 isKindOfClass:NSDictionary.class] || [[j2 objectForKey:@"code"] integerValue] != 200) {
                NSString *m = [j2 objectForKey:@"msg"] ?: @"提交任务被拒绝";
                if (completion) completion(nil, pkcError([NSString stringWithFormat:@"琅琅：%@", m]));
                return;
            }
            id dObj = [j2 objectForKey:@"data"];
            NSString *taskId = [dObj objectForKey:@"taskId"] ?: [j2 objectForKey:@"taskId"];
            if (!taskId) { if (completion) completion(nil, pkcError(@"未取到 taskId")); return; }

            pkcLangPoll(token, taskId, 0, completion);
        });
    });
}



static NSString * const kPKCXFHost = @"https://peiyin.xunfei.cn";
static NSString * const kPKCXFSid  = @"BCB18B513D2E8D8C8759AB03C36ED647";
static NSString * const kPKCXFUA   = @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36";

static NSArray<NSString *> *pkcXFHeaders(void) {
    return @[@"Host: peiyin.xunfei.cn",
             @"Origin: http://peiyin.xunfei.cn",
             @"Pragma: no-cache",
             @"Referer: http://peiyin.xunfei.cn/",
             [NSString stringWithFormat:@"User-Agent: %@", kPKCXFUA]];
}

static void pkcXFSynth(NSString *text, NSString *vid, double speed, double volume,
                         void (^completion)(NSData *audioData, NSError *error)) {
    NSString *exchangeURL = [kPKCXFHost stringByAppendingString:@"/web-server/exchange"];
    pkcPostJSON(exchangeURL, @{}, pkcXFHeaders(), ^(NSData *d1, NSError *e1) {
        if (e1 || !d1.length) { if (completion) completion(nil, e1 ?: pkcError(@"讯飞 exchange 失败")); return; }
        id ex = pkcJSON(d1);
        if (![ex isKindOfClass:NSDictionary.class]) ex = @{};

        NSDictionary *body = @{
            @"req":  ex,
            @"text": [NSString stringWithFormat:@"[te50][n0]%@", text],
            @"vid":  vid ?: @"",
        };
        NSString *signURL = [kPKCXFHost stringByAppendingString:@"/web-server/1.0/works_synth_sign"];
        pkcPostJSON(signURL, body, pkcXFHeaders(), ^(NSData *d2, NSError *e2) {
            if (e2 || !d2.length) { if (completion) completion(nil, e2 ?: pkcError(@"讯飞签名失败")); return; }
            id j2 = pkcJSON(d2);
            if (![j2 isKindOfClass:NSDictionary.class]) { if (completion) completion(nil, pkcError(@"讯飞签名返回异常")); return; }
            if ([[j2 objectForKey:@"status"] integerValue] != 0) {
                NSString *m = [j2 objectForKey:@"message"] ?: [j2 objectForKey:@"msg"] ?: @"签名被拒绝";
                if (completion) completion(nil, pkcError([NSString stringWithFormat:@"讯飞：%@", m]));
                return;
            }
            NSString *sign = [j2 objectForKey:@"sign"];
            if (!sign.length) sign = [[j2 objectForKey:@"data"] objectForKey:@"sign"];
            if (!sign.length) { if (completion) completion(nil, pkcError(@"讯飞未返回 sign")); return; }

            
            NSString *uid = @"";
            NSString *ts  = [NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
            int vol = (int)lround(volume * 20.0);        
            int spd = (int)lround((speed - 1.0) * 10.0); 
            NSString *url = [NSString stringWithFormat:
                @"%@/synth?uid=%@&ts=%@&sign=%@&vid=%@&f=v2&cc=0000&sid=%@&volume=%d&speed=%d&content=%@&listen=2",
                kPKCXFHost, uid, ts, sign, vid, kPKCXFSid, vol, spd, pkcEscape(text)];
            pkcGet(url, ^(NSData *audio, NSError *e3) {
                if (completion) completion((e3 || !audio.length) ? nil : audio,
                                           e3 ?: (audio.length ? nil : pkcError(@"讯飞音频下载失败")));
            });
        });
    });
}


static void pkcSynthesizeWithVoice(NSString *text, NSString *voiceID, double speed, double volume,
                                     void (^completion)(NSData *audioData, NSError *error)) {
    if (!text.length) { if (completion) completion(nil, pkcError(@"文本为空")); return; }
    NSDictionary *v = pkcFindVoiceByID(voiceID);
    NSString *type = v[@"type"] ?: kPKCTypeLang;   
    if ([type isEqualToString:kPKCTypeXF]) pkcXFSynth(text, voiceID, speed, volume, completion);
    else                                     pkcLangSynth(text, voiceID, speed, volume, completion);
}




static AVAudioPlayer *gpkcPreviewPlayer = nil;
static void pkcStopPreview(void) { [gpkcPreviewPlayer stop]; gpkcPreviewPlayer = nil; }


static void pkcLoadVoiceIcon(NSString *imgURL, NSString *vid, void (^setImage)(UIImage *img)) {
    if (!setImage) return;
    if (!imgURL.length) { setImage(nil); return; }
    NSString *ext = [imgURL pathExtension].length ? [imgURL pathExtension] : @"png";
    NSString *cache = [[pkcIconDir() stringByAppendingPathComponent:vid] stringByAppendingPathExtension:ext];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:cache]) {
        UIImage *img = [UIImage imageWithContentsOfFile:cache];
        if (img) { setImage(img); return; }
    }
    pkcGet(imgURL, ^(NSData *data, NSError *e) {
        if (data.length) {
            [data writeToFile:cache atomically:YES];
            UIImage *img = [UIImage imageWithData:data];
            if (img) dispatch_async(dispatch_get_main_queue(), ^{ setImage(img); });
        }
    });
}



static void pkcPreviewVoice(NSDictionary *voice, void (^done)(BOOL ok, NSString *err)) {
    if (!voice) { if (done) done(NO, @"音色无效"); return; }
    NSString *vid = voice[@"id"];
    if (!vid.length) { if (done) done(NO, @"音色无效"); return; }
    NSString *cache = [[pkcCacheMP3Dir() stringByAppendingPathComponent:vid] stringByAppendingPathExtension:@"mp3"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:cache]) {
        NSError *e = nil;
        AVAudioPlayer *p = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:cache] error:&e];
        if (p) {
            pkcStopPreview();
            gpkcPreviewPlayer = p; p.numberOfLoops = 0; [p play];
            if (done) done(YES, nil);
            return;
        }
    }
    NSString *demo = @"你好，这是音色试听。";
    pkcSynthesizeWithVoice(demo, vid, 1.0, 1.0, ^(NSData *audio, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err || !audio.length) { if (done) done(NO, err.localizedDescription ?: @"试听失败"); return; }
            [audio writeToFile:cache atomically:YES];
            NSError *e = nil;
            AVAudioPlayer *p = [[AVAudioPlayer alloc] initWithData:audio error:&e];
            if (p) {
                pkcStopPreview();
                gpkcPreviewPlayer = p; p.numberOfLoops = 0; [p play];
                if (done) done(YES, nil);
            } else {
                if (done) done(NO, @"试听播放失败");
            }
        });
    });
}




static AVAudioPlayer *pkcBgPlayer(void) {
    static AVAudioPlayer *player = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *bgPath = [DDTextToVoiceConfig.shared stringForKey:kPKCBgFilePath];
        if (bgPath.length && [[NSFileManager defaultManager] fileExistsAtPath:bgPath]) {
            player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:bgPath] error:nil];
            player.numberOfLoops = -1;
        }
    });
    return player;
}

static void pkcPlayBackgroundMusic(void) {
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    if (![cfg boolForKey:kPKCBgEnable]) return;
    AVAudioPlayer *p = pkcBgPlayer();
    if (p) {
        p.volume = cfg.bgVolume;   
        [p play];
    }
}

static void pkcStopBackgroundMusic(void) {
    AVAudioPlayer *p = pkcBgPlayer();
    if (p && p.playing) [p stop];
}




static NSInteger pkcCleanDir(NSString *dir) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil] ?: @[];
    NSInteger n = 0;
    for (NSString *f in files) {
        if ([fm removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil]) n++;
    }
    return n;
}


static void pkcCleanCache(void) {
    NSInteger n = 0;
    n += pkcCleanDir(pkcCacheSilkDir());
    n += pkcCleanDir(pkcCacheMP3Dir());
    n += pkcCleanDir(pkcIconDir());
    n += pkcCleanDir(pkcBgDir());
    pkcToast([NSString stringWithFormat:@"缓存已清理：%ld 项", (long)n]);
}


static void pkcShowChoice(NSString *title, NSArray<NSString *> *options, NSString *current,
                          void (^pick)(NSString *value)) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                              message:nil
                                                       preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *opt in options) {
        BOOL sel = current.length && [current isEqualToString:opt];
        [a addAction:[UIAlertAction actionWithTitle:sel ? [NSString stringWithFormat:@"✓ %@", opt] : opt
                                              style:UIAlertActionStyleDefault
                                            handler:^(__unused UIAlertAction *x) { if (pick) pick(opt); }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    pkcPresentVC(a);
}






#define pkc_SILK_SAMPLE_RATE   24000
#define pkc_SILK_FRAME_MS      20
#define pkc_SILK_MAX_FRAME_BYTES 250


static NSData *pkcPCMToSilk(const int16_t *pcm, NSUInteger totalSamples, int sampleRate, int *outDurationMs) {
    if (!pcm || totalSamples == 0) return nil;

    SKP_int32 encSizeBytes = 0;
    if (SKP_Silk_SDK_Get_Encoder_Size(&encSizeBytes) != 0 || encSizeBytes <= 0) return nil;

    void *psEnc = malloc((size_t)encSizeBytes);
    if (!psEnc) return nil;
    memset(psEnc, 0, (size_t)encSizeBytes);

    SKP_int encStatus = 0;
    if (SKP_Silk_SDK_InitEncoder(psEnc, &encStatus) != 0) { free(psEnc); return nil; }

    SKP_SILK_SDK_EncControlStruct encControl;
    memset(&encControl, 0, sizeof(encControl));
    encControl.API_sampleRate        = sampleRate;
    encControl.maxInternalSampleRate = pkc_SILK_SAMPLE_RATE;
    encControl.packetSize            = (sampleRate * pkc_SILK_FRAME_MS) / 1000;
    encControl.packetLossPercentage  = 0;
    encControl.useInBandFEC          = 0;
    encControl.useDTX                = 0;
    encControl.complexity            = 2;
    encControl.bitRate               = 0;   

    NSUInteger frameSize = (NSUInteger)encControl.packetSize;
    if (frameSize == 0) { free(psEnc); return nil; }

    SKP_int16 *frameBuf = (SKP_int16 *)calloc(frameSize, sizeof(SKP_int16));
    if (!frameBuf) { free(psEnc); return nil; }

    NSMutableData *out = [NSMutableData data];
    const char header[] = "#!SILK_V3";
    [out appendBytes:header length:strlen(header)];

    SKP_uint8 payload[pkc_SILK_MAX_FRAME_BYTES];
    NSUInteger offset = 0;
    NSUInteger frames = 0;

    while (offset < totalSamples) {
        NSUInteger n = MIN(frameSize, totalSamples - offset);
        memset(frameBuf, 0, frameSize * sizeof(SKP_int16));
        memcpy(frameBuf, pcm + offset, n * sizeof(SKP_int16));

        SKP_int16 nBytes = 0;
        SKP_int ret = SKP_Silk_SDK_Encode(psEnc, &encControl, frameBuf, (SKP_int16)frameSize, payload, &nBytes);
        if (ret != 0) break;
        if (nBytes > 0) {
            
            int16_t lenLE = (int16_t)nBytes;
            [out appendBytes:&lenLE length:sizeof(lenLE)];
            [out appendBytes:payload length:(NSUInteger)nBytes];
            frames++;
        }
        offset += n;
    }

    free(frameBuf);
    free(psEnc);

    if (outDurationMs) *outDurationMs = (int)(frames * pkc_SILK_FRAME_MS);
    return (frames > 0) ? out : nil;
}


static NSData *pkcDecodeMP3ToPCM(NSData *mp3Data, int targetSampleRate) {
    if (!mp3Data.length) return nil;
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"pkc_%ld.mp3", (long)time(NULL)]];
    if (![mp3Data writeToFile:tmpPath atomically:YES]) return nil;

    NSURL *url = [NSURL fileURLWithPath:tmpPath];
    ExtAudioFileRef audioFile = NULL;
    if (ExtAudioFileOpenURL((__bridge CFURLRef)url, &audioFile) != noErr) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
        return nil;
    }

    AudioStreamBasicDescription clientFormat;
    memset(&clientFormat, 0, sizeof(clientFormat));
    clientFormat.mSampleRate       = (Float64)targetSampleRate;
    clientFormat.mFormatID         = kAudioFormatLinearPCM;
    clientFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    clientFormat.mChannelsPerFrame = 1;
    clientFormat.mBitsPerChannel   = 16;
    clientFormat.mFramesPerPacket  = 1;
    clientFormat.mBytesPerFrame    = 2;
    clientFormat.mBytesPerPacket   = 2;

    if (ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat,
                                sizeof(clientFormat), &clientFormat) != noErr) {
        ExtAudioFileDispose(audioFile);
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
        return nil;
    }

    NSMutableData *pcm = [NSMutableData data];
    const NSUInteger chunkFrames = 4096;
    int16_t *buffer = (int16_t *)malloc(chunkFrames * sizeof(int16_t));
    if (buffer) {
        AudioBufferList bufferList;
        memset(&bufferList, 0, sizeof(bufferList));
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mNumberChannels = 1;
        bufferList.mBuffers[0].mData = buffer;

        while (1) {
            UInt32 frames = (UInt32)chunkFrames;
            bufferList.mBuffers[0].mDataByteSize = (UInt32)(chunkFrames * sizeof(int16_t));
            if (ExtAudioFileRead(audioFile, &frames, &bufferList) != noErr || frames == 0) break;
            [pcm appendBytes:buffer length:(NSUInteger)frames * sizeof(int16_t)];
        }
        free(buffer);
    }

    ExtAudioFileDispose(audioFile);
    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
    return pcm.length ? pcm : nil;
}



static NSData *pkcMp3ToSilk(NSData *mp3Data, double targetSeconds, int *outDurationMs) {
    NSData *pcm = pkcDecodeMP3ToPCM(mp3Data, pkc_SILK_SAMPLE_RATE);
    if (!pcm.length) return nil;
    
    if (targetSeconds > 0) {
        NSUInteger targetSamples = (NSUInteger)(targetSeconds * pkc_SILK_SAMPLE_RATE);
        NSUInteger curSamples = pcm.length / sizeof(int16_t);
        if (targetSamples > curSamples) {
            NSMutableData *padded = [NSMutableData dataWithCapacity:targetSamples * sizeof(int16_t)];
            [padded appendData:pcm];
            [padded increaseLengthBy:(targetSamples - curSamples) * sizeof(int16_t)];
            pcm = padded;
        }
    }
    int dur = 0;
    NSData *silk = pkcPCMToSilk((const int16_t *)pcm.bytes, pcm.length / sizeof(int16_t),
                                pkc_SILK_SAMPLE_RATE, &dur);
    if (outDurationMs) *outDurationMs = (targetSeconds > 0) ? (int)(targetSeconds * 1000) : dur;
    return silk;
}






static BOOL pkcSendVoiceMessage(NSData *silkData, NSString *toUser, int durationMs) {
    if (!silkData.length || !toUser.length) return NO;
    Class msgWrapCls = objc_getClass("CMessageWrap");
    Class msgMgrCls  = objc_getClass("CMessageMgr");
    if (!msgWrapCls || !msgMgrCls) return NO;

    CMessageWrap *wrap = [msgWrapCls initWithMsgType:34 nsFromUsr:nil];
    if (!wrap) return NO;
    wrap.m_nsToUsr = toUser;
    wrap.m_uiVoiceFormat = 4;      
    wrap.m_uiVoiceEndFlag = 1;
    wrap.m_uiCreateTime = (unsigned int)time(NULL);
    wrap.m_uiVoiceTime = (unsigned int)(durationMs > 0 ? durationMs : 1000);  
    wrap.m_dtVoice = silkData;

    id mgr = [[msgMgrCls alloc] init];
    if (!mgr) return NO;
    [mgr AddMsg:toUser MsgWrap:wrap];
    return YES;
}



static void pkcConvertAndSend(NSString *text, NSString *toUser) {
    if (!text.length) return;
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    if (![cfg boolForKey:kPKCEnable]) {
        pkcToast(@"请先在插件设置中启用文字转语音");
        return;
    }
    NSString *voiceID = pkcCurrentVoiceID();
    pkcToast(@"正在合成语音…");

    pkcSynthesizeWithVoice(text, voiceID, cfg.speed, cfg.volume, ^(NSData *audioData, NSError *error) {
        if (error || !audioData.length) {
            dispatch_async(dispatch_get_main_queue(), ^{
                pkcToast(error ? [NSString stringWithFormat:@"合成失败：%@", error.localizedDescription] : @"合成失败");
            });
            return;
        }
        
        NSString *baseName = [NSString stringWithFormat:@"ttv_%ld", (long)time(NULL)];
        NSString *mp3Path = [[pkcCacheMP3Dir() stringByAppendingPathComponent:baseName]
                             stringByAppendingPathExtension:@"mp3"];
        [audioData writeToFile:mp3Path atomically:YES];

        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            int durationMs = 0;
            NSData *silk = pkcMp3ToSilk(audioData, cfg.voiceSeconds, &durationMs);
            if (silk.length) {
                NSString *silkPath = [[pkcCacheSilkDir() stringByAppendingPathComponent:baseName]
                                      stringByAppendingPathExtension:@"silk"];
                [silk writeToFile:silkPath atomically:YES];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!silk.length) {
                    pkcToast(@"silk 转码失败，已保存 mp3");
                    return;
                }
                pkcPlayBackgroundMusic();
                if (toUser.length) {
                    BOOL ok = pkcSendVoiceMessage(silk, toUser, durationMs);
                    pkcToast(ok ? @"语音已发送" : @"语音已保存(发送失败)");
                } else {
                    pkcToast([NSString stringWithFormat:@"语音已保存：%@.silk", baseName]);
                }
            });
        });
    });
}



static void pkcPromptTextAndConvert(NSString *toUser) {
    UIWindow *win = pkcCurrentKeyWindow();
    if (!win) return;
    UIViewController *vc = win.rootViewController;
    if (!vc) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"文字转语音"
                                                                  message:@"输入要转成语音的文字"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"输入文字…";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"转语音" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *text = [alert.textFields firstObject].text;
        if (text.length) pkcConvertAndSend(text, toUser);
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}


static void pkcShowInputMenu(NSString *toUser) {
    UIWindow *win = pkcCurrentKeyWindow();
    if (!win) return;
    Class sheetCls = objc_getClass("WCActionSheet");
    WCActionSheet *sheet = [(WCActionSheet *)[sheetCls alloc] initWithTitle:@"文字转语音"];
    if (!sheet) return;
    [sheet addButtonWithTitle:@"文字转语音" eventAction:^{
        pkcPromptTextAndConvert(toUser);
    }];
    [sheet addButtonWithTitle:@"取消" eventAction:^{}];
    [sheet showInView:win];
}



%hook CMessageMgr

- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap {
    BOOL shouldSend = YES;
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    Class msgWrapCls = objc_getClass("CMessageWrap");
    if ([cfg boolForKey:kPKCEnable] && wrap && msgWrapCls && [msgWrapCls isSenderFromMsgWrap:wrap]) {
        if (wrap.m_uiMessageType == 1 && wrap.m_nsContent.length) {
            NSString *content = [wrap.m_nsContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            NSString *cmd = DDTextToVoiceConfig.shared.command;
            if (cmd.length && [content hasPrefix:cmd]) {
                NSString *text = [[content substringFromIndex:cmd.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (text.length) {
                    NSString *toUser = usr.length ? usr : wrap.m_nsToUsr;
                    pkcConvertAndSend(text, toUser);
                    shouldSend = NO;
                }
            }
        }
    }
    if (shouldSend) { %orig; }
}

%end





static void pkcEnsureLongPress(UIView *view) {
    if (!view) return;
    NSString *key = @"pkcLongPress";
    NSObject *holder = (NSObject *)view;
    if (objc_getAssociatedObject(holder, (__bridge const void *)(key))) return; 
    objc_setAssociatedObject(holder, (__bridge const void *)(key), @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:view
                                        action:@selector(pkcLongPress:)];
    lp.minimumPressDuration = 0.6;
    [view addGestureRecognizer:lp];
}

%hook WCInputView



- (void)didMoveToWindow {
    %orig;
    if (self.window) pkcEnsureLongPress(self);
}

%end


@interface UIView (pkcLongPress)
- (void)pkcLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation UIView (pkcLongPress)
- (void)pkcLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    pkcShowInputMenu(nil);
}
@end



@interface WCTableViewManager : NSObject
@property(retain, nonatomic) NSMutableArray *sections;
- (instancetype)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)clearAllSection;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
@property(retain, nonatomic) NSMutableArray *cells;
@property(copy, nonatomic) NSString *footerTitle;
+ (id)defaultSection;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
@end

@class pkcVoiceListViewController;

@interface DDTextToVoiceSettingsViewController : UIViewController <UIDocumentPickerDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDTextToVoiceSettingsViewController

- (void)ensureTableViewMgr {
    if (_tableViewMgr) return;
    Class mgrCls = objc_getClass("WCTableViewManager");
    _tableViewMgr = [(WCTableViewManager *)[mgrCls alloc] initWithFrame:[UIScreen mainScreen].bounds
                                                                  style:UITableViewStyleInsetGrouped];
}

- (instancetype)init {
    if (self = [super init]) {
        [self ensureTableViewMgr];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD文字转语音";
    [self ensureTableViewMgr];
    if (!_tableViewMgr) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
}

- (void)buildTable {
    if (!_tableViewMgr) return;
    [self.tableViewMgr clearAllSection];
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    Class secCls = objc_getClass("WCTableViewSectionManager");
    Class cellCls = objc_getClass("WCTableViewCellManager");

    
    WCTableViewSectionManager *sec1 = [secCls defaultSection];
    [sec1 addCell:[cellCls switchCellForSel:@selector(toggleEnable:)
                                     target:self
                                      title:@"1. 启用文字转语音"
                                         on:[cfg boolForKey:kPKCEnable]]];
    [sec1 addCell:[cellCls normalCellForSel:@selector(setVoice:)
                                     target:self
                                      title:[NSString stringWithFormat:@"2. 设置音色(%@)", pkcCurrentVoiceName()]]];
    [sec1 addCell:[cellCls normalCellForSel:@selector(setCommand:)
                                     target:self
                                      title:[NSString stringWithFormat:@"3. 转语音命令：%@", cfg.command]]];
    [sec1 setFooterTitle:[NSString stringWithFormat:@"聊天发送「%@ 文字」即转成语音并发送", cfg.command]];
    [self.tableViewMgr addSection:sec1];

    
    WCTableViewSectionManager *sec2 = [secCls defaultSection];
    [sec2 addCell:[cellCls normalCellForSel:@selector(setInterface:)
                                     target:self
                                      title:[NSString stringWithFormat:@"4. 接口选择：%@", cfg.interface]]];
    [sec2 addCell:[cellCls normalCellForSel:@selector(setVoiceSource:)
                                     target:self
                                      title:[NSString stringWithFormat:@"5. 音色来源：%@", cfg.voiceSource]]];
    [sec2 setFooterTitle:@"默认本地音色（琅琅+讯飞）；外部接口/来源为占位，未启用"];
    [self.tableViewMgr addSection:sec2];

    
    WCTableViewSectionManager *sec3 = [secCls defaultSection];
    [sec3 addCell:[cellCls normalCellForSel:@selector(setSpeed:)
                                     target:self
                                      title:[NSString stringWithFormat:@"6. 语速：%.2f", cfg.speed]]];
    [sec3 addCell:[cellCls normalCellForSel:@selector(setVolume:)
                                     target:self
                                      title:[NSString stringWithFormat:@"7. 音量：%.2f", cfg.volume]]];
    [sec3 addCell:[cellCls normalCellForSel:@selector(setVoiceSeconds:)
                                     target:self
                                      title:[NSString stringWithFormat:@"8. 自定义语音秒数：%@",
                                             cfg.voiceSeconds > 0 ? [NSString stringWithFormat:@"%.0f 秒", cfg.voiceSeconds] : @"自然"]]];
    [self.tableViewMgr addSection:sec3];

    
    WCTableViewSectionManager *sec4 = [secCls defaultSection];
    [sec4 addCell:[cellCls switchCellForSel:@selector(toggleBg:)
                                     target:self
                                      title:@"9. 启用背景音"
                                         on:[cfg boolForKey:kPKCBgEnable]]];
    [sec4 addCell:[cellCls normalCellForSel:@selector(importBg:)
                                     target:self
                                      title:@"10. 导入背景音"]];
    [sec4 addCell:[cellCls normalCellForSel:@selector(setBg:)
                                     target:self
                                      title:@"11. 设置背景音"]];
    [sec4 addCell:[cellCls normalCellForSel:@selector(setBgVolume:)
                                     target:self
                                      title:[NSString stringWithFormat:@"12. 背景音量：%.2f", cfg.bgVolume]]];
    [self.tableViewMgr addSection:sec4];

    
    WCTableViewSectionManager *sec5 = [secCls defaultSection];
    [sec5 addCell:[cellCls normalCellForSel:@selector(cleanSilk:)
                                     target:self
                                      title:@"13. 清理语音缓存(silk)"]];
    [sec5 addCell:[cellCls normalCellForSel:@selector(cleanMP3:)
                                     target:self
                                      title:@"14. 清理试听/合成(mp3)"]];
    [sec5 addCell:[cellCls normalCellForSel:@selector(cleanIcon:)
                                     target:self
                                      title:@"15. 清理音色图标"]];
    [sec5 addCell:[cellCls normalCellForSel:@selector(cleanBg:)
                                     target:self
                                      title:@"16. 清理背景音"]];
    [sec5 addCell:[cellCls normalCellForSel:@selector(cleanAll:)
                                     target:self
                                      title:@"17. 清理全部缓存"]];
    [self.tableViewMgr addSection:sec5];

    [self.tableViewMgr reloadTableView];
}


- (void)toggleEnable:(UISwitch *)sender {
    [DDTextToVoiceConfig.shared setValue:sender.isOn ? @(1) : nil forConfigKey:kPKCEnable];
    [self buildTable];
}


- (void)setVoice:(id)sender {
    pkcVoiceListViewController *vc = [[pkcVoiceListViewController alloc] init];
    vc.groups  = pkcVoiceGroups();
    vc.sections = @[kPKCTypeLang, kPKCTypeXF];
    vc.onSelect = ^(NSString *vid, NSString *name) {
        [DDTextToVoiceConfig.shared setValue:vid forConfigKey:kPKCVoiceIDDefault];
        pkcToast([NSString stringWithFormat:@"已设置音色：%@", name]);
        [self buildTable];
    };
    vc.onDeleted = ^{ [self buildTable]; };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    vc.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"完成"
                                         style:UIBarButtonItemStyleDone
                                       handler:^(__unused id a) { [nav dismissViewControllerAnimated:YES completion:nil]; }];
    pkcPresentVC(nav);
}


- (void)dd_editConfig:(NSString *)key title:(NSString *)title placeholder:(NSString *)ph secure:(BOOL)secure {
    UIWindow *win = pkcCurrentKeyWindow();
    UIViewController *vc = win.rootViewController;
    if (!vc) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = ph;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.secureTextEntry = secure;
        tf.text = [DDTextToVoiceConfig.shared stringForKey:key] ?: @"";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *text = [alert.textFields firstObject].text;
        [DDTextToVoiceConfig.shared setValue:text.length ? text : nil forConfigKey:key];
        pkcToast(@"已保存");
        [self buildTable];
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}


- (void)toggleBg:(UISwitch *)sender {
    [DDTextToVoiceConfig.shared setValue:sender.isOn ? @(1) : nil forConfigKey:kPKCBgEnable];
    if (sender.isOn) pkcPlayBackgroundMusic(); else pkcStopBackgroundMusic();
    [self buildTable];
}



- (void)importBg:(id)sender {
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.audio"]
                                                               inMode:UIDocumentPickerModeImport];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    pkcPresentVC(picker);
}


- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    for (NSURL *url in urls) {
        if (![url startAccessingSecurityScopedResource]) continue;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *name = [url lastPathComponent];
        NSString *dest = [pkcBgDir() stringByAppendingPathComponent:name];
        [fm removeItemAtPath:dest error:nil];
        BOOL ok = [fm copyItemAtPath:url.path toPath:dest error:nil];
        [url stopAccessingSecurityScopedResource];
        if (ok) {
            [DDTextToVoiceConfig.shared setValue:dest forConfigKey:kPKCBgFilePath];
            pkcToast([NSString stringWithFormat:@"已导入背景音：%@", name]);
        } else {
            pkcToast(@"背景音导入失败");
        }
        break;
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    
}


- (void)setBg:(id)sender {
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    NSArray *bgs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pkcBgDir() error:nil];
    UIWindow *win = pkcCurrentKeyWindow();
    if (!win) return;
    Class sheetCls = objc_getClass("WCActionSheet");
    WCActionSheet *sheet = [(WCActionSheet *)[sheetCls alloc] initWithTitle:@"选择背景音"];
    if (!sheet) return;
    for (NSString *name in bgs) {
        [sheet addButtonWithTitle:name eventAction:^{
            [cfg setValue:[pkcBgDir() stringByAppendingPathComponent:name] forConfigKey:kPKCBgFilePath];
            pkcToast(@"背景音已设置");
        }];
    }
    [sheet showInView:win];
}


- (void)setCommand:(id)sender {
    [self dd_editConfig:kPKCCommand title:@"转语音命令" placeholder:@"/yy（发送此前缀文字即转语音）" secure:NO];
}


- (void)setInterface:(id)sender {
    NSArray *opts = @[@"默认", @"接口1", @"接口2", @"接口3", @"接口4", @"接口5"];
    pkcShowChoice(@"接口选择", opts, DDTextToVoiceConfig.shared.interface, ^(NSString *v) {
        [DDTextToVoiceConfig.shared setValue:v forConfigKey:kPKCInterface];
        pkcToast([NSString stringWithFormat:@"接口：%@", v]);
        [self buildTable];
    });
}


- (void)setVoiceSource:(id)sender {
    NSArray *opts = @[@"本地文件", @"默认接口", @"自定接口"];
    pkcShowChoice(@"音色来源", opts, DDTextToVoiceConfig.shared.voiceSource, ^(NSString *v) {
        [DDTextToVoiceConfig.shared setValue:v forConfigKey:kPKCVoiceSource];
        if (![v isEqualToString:@"本地文件"]) {
            pkcToast(@"外部音色来源未启用，已使用本地音色");
        }
        [self buildTable];
    });
}


- (void)setSpeed:(id)sender {
    [self dd_editNumberConfig:kPKCSpeed title:@"语速" placeholder:@"1.0" min:0.5 max:2.0];
}


- (void)setVolume:(id)sender {
    [self dd_editNumberConfig:kPKCVolume title:@"音量" placeholder:@"1.0" min:0.0 max:2.0];
}


- (void)setVoiceSeconds:(id)sender {
    [self dd_editNumberConfig:kPKCVoiceSeconds title:@"自定义语音秒数" placeholder:@"0（自然时长）" min:0.0 max:60.0];
}


- (void)setBgVolume:(id)sender {
    [self dd_editNumberConfig:kPKCBgVolume title:@"背景音量" placeholder:@"0.5" min:0.0 max:1.0];
}


- (void)cleanSilk:(id)sender { [self dd_cleanDir:pkcCacheSilkDir() label:@"语音缓存"]; }
- (void)cleanMP3:(id)sender  { [self dd_cleanDir:pkcCacheMP3Dir() label:@"试听/合成"]; }
- (void)cleanIcon:(id)sender { [self dd_cleanDir:pkcIconDir() label:@"音色图标"]; }
- (void)cleanBg:(id)sender   { [self dd_cleanDir:pkcBgDir() label:@"背景音"]; }
- (void)cleanAll:(id)sender  { pkcCleanCache(); }


- (void)dd_editNumberConfig:(NSString *)key title:(NSString *)title placeholder:(NSString *)ph min:(double)min max:(double)max {
    UIWindow *win = pkcCurrentKeyWindow();
    UIViewController *vc = win.rootViewController; if (!vc) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:[NSString stringWithFormat:@"范围 %.2f ~ %.2f（0 表示默认）", min, max]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = ph; tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        NSNumber *cur = [DDTextToVoiceConfig.shared.config objectForKey:key];
        tf.text = cur ? [NSString stringWithFormat:@"%g", cur.doubleValue] : @"";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *t = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        double v = t.length ? t.doubleValue : 0;
        if (v < min) v = min; if (v > max) v = max;
        [DDTextToVoiceConfig.shared setValue:@(v) forConfigKey:key];
        pkcToast(@"已保存"); [self buildTable];
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}


- (void)dd_cleanDir:(NSString *)dir label:(NSString *)label {
    NSInteger n = pkcCleanDir(dir);
    pkcToast([NSString stringWithFormat:@"已清理%@：%ld 项", label, (long)n]);
}

@end



@interface pkcVoiceCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, copy)   NSDictionary *voice;
- (void)configure:(NSDictionary *)voice selected:(BOOL)sel;
@end

@implementation pkcVoiceCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 11, 44, 44)];
        _iconView.layer.cornerRadius = 22; _iconView.clipsToBounds = YES;
        _iconView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1];
        _iconView.contentMode = UIViewContentModeScaleAspectFill;
        [self.contentView addSubview:_iconView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(68, 10, 260, 20)];
        _nameLabel.font = [UIFont boldSystemFontOfSize:16];
        [self.contentView addSubview:_nameLabel];

        _descLabel = [[UILabel alloc] initWithFrame:CGRectMake(68, 32, 260, 26)];
        _descLabel.font = [UIFont systemFontOfSize:12];
        _descLabel.textColor = [UIColor grayColor];
        _descLabel.numberOfLines = 2;
        [self.contentView addSubview:_descLabel];
    }
    return self;
}

- (void)configure:(NSDictionary *)voice selected:(BOOL)sel {
    _voice = voice;
    NSString *name = voice[@"name"] ?: @"";
    _nameLabel.text = sel ? [NSString stringWithFormat:@"✓ %@", name] : name;
    _nameLabel.textColor = sel ? [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1]
                               : [UIColor blackColor];
    _descLabel.text = voice[@"desc"] ?: @"";
    _iconView.image = nil;
    __weak typeof(self) w = self;
    pkcLoadVoiceIcon(voice[@"img"], voice[@"id"], ^(UIImage *img) {
        if (w && img) w.iconView.image = img;
    });
}

@end

@interface pkcVoiceListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy)   NSArray<NSString *> *sections;   
@property (nonatomic, copy)   NSDictionary<NSString *, NSArray<NSDictionary *> *> *groups;
@property (nonatomic, copy)   void (^onSelect)(NSString *vid, NSString *name);
@property (nonatomic, copy)   void (^onDeleted)(void);
@end

@implementation pkcVoiceListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择音色";
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[pkcVoiceCell class] forCellReuseIdentifier:@"vcell"];
    [self.view addSubview:self.tableView];
    [self setupLangTokenBarButton];
}


- (void)setupLangTokenBarButton {
    if (![self.sections containsObject:kPKCTypeLang]) return;

    UIButton *tokenBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [tokenBtn setTitle:@"Token" forState:UIControlStateNormal];
    tokenBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [tokenBtn addTarget:self action:@selector(showLangTokenInput:) forControlEvents:UIControlEventTouchUpInside];

    UIButton *getBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [getBtn setTitle:@"获取 Token" forState:UIControlStateNormal];
    getBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [getBtn addTarget:self action:@selector(openLangTokenWebsite:) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[tokenBtn, getBtn]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentTrailing;
    stack.distribution = UIStackViewDistributionEqualSpacing;
    stack.spacing = 2;
    [stack sizeToFit];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:stack];
}

- (void)showLangTokenInput:(id)sender {
    UIWindow *win = pkcCurrentKeyWindow();
    UIViewController *vc = win.rootViewController; if (!vc) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"琅琅 Token"
                                                                   message:@"在 lang123.top 登录后，进入个人信息复制 token"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"粘贴 Token";
        tf.text = [DDTextToVoiceConfig.shared stringForKey:kPKCLangToken] ?: @"";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.secureTextEntry = YES;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *t = [[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] copy];
        [DDTextToVoiceConfig.shared setValue:t.length ? t : nil forConfigKey:kPKCLangToken];
        pkcToast(t.length ? @"Token 已保存" : @"Token 已清空");
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}

- (void)openLangTokenWebsite:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://lang123.top"];
    if (!url) return;
    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(openURL:options:completionHandler:)]) {
        [app openURL:url options:@{} completionHandler:nil];
    } else if ([app canOpenURL:url]) {
        [app openURL:url];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self.groups[self.sections[section]] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *name = self.sections[section];
    return [NSString stringWithFormat:@"%@ (%lu)", name, (unsigned long)[self.groups[name] count]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 66;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    pkcVoiceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"vcell" forIndexPath:indexPath];
    NSDictionary *voice = self.groups[self.sections[indexPath.section]][indexPath.row];
    BOOL sel = [voice[@"id"] isEqualToString:pkcCurrentVoiceID()];
    [cell configure:voice selected:sel];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}


- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *voice = self.groups[self.sections[indexPath.section]][indexPath.row];
    NSString *vid = voice[@"id"] ?: @"";
    NSString *name = voice[@"name"] ?: @"";
    __weak typeof(self) w = self;

    UIContextualAction *set = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                       title:@"设定"
                                                                     handler:^(__unused UIContextualAction *a, __unused UIView *v, void (^done)(BOOL)) {
        if (w.onSelect) w.onSelect(vid, name);
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationNone];
        pkcToast([NSString stringWithFormat:@"已设定：%@", name]);
        done(YES);
    }];
    set.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1];

    UIContextualAction *preview = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                           title:@"试听"
                                                                         handler:^(__unused UIContextualAction *a, __unused UIView *v, void (^done)(BOOL)) {
        pkcToast(@"试听中…");
        pkcPreviewVoice(voice, ^(BOOL ok, NSString *err) {
            if (!ok) pkcToast(err ?: @"试听失败");
        });
        done(YES);
    }];
    preview.backgroundColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1];

    UIContextualAction *edit = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:@"编辑"
                                                                       handler:^(__unused UIContextualAction *a, __unused UIView *v, void (^done)(BOOL)) {
        [w showEditAlertForVoice:voice atIndexPath:indexPath];
        done(YES);
    }];
    edit.backgroundColor = [UIColor colorWithRed:1.0 green:0.58 blue:0.0 alpha:1];

    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                       title:@"删除"
                                                                     handler:^(__unused UIContextualAction *a, __unused UIView *v, void (^done)(BOOL)) {
        pkcDeleteVoice(vid);
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        if (w.onDeleted) w.onDeleted();
        done(YES);
    }];

    return [UISwipeActionsConfiguration configurationWithActions:@[del, edit, preview, set]];
}

- (void)showEditAlertForVoice:(NSDictionary *)voice atIndexPath:(NSIndexPath *)indexPath {
    UIWindow *win = pkcCurrentKeyWindow();
    UIViewController *vc = win.rootViewController; if (!vc) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"编辑音色"
                                                                     message:@"修改显示名称和描述"
                                                              preferredStyle:UIAlertControllerStyleAlert];
    NSString *vid = voice[@"id"] ?: @"";
    NSString *curName = voice[@"name"] ?: @"";
    NSString *curDesc = voice[@"desc"] ?: @"";
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"显示名称";
        tf.text = curName;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"描述";
        tf.text = curDesc;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) w = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *newName = [alert.textFields[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *newDesc = [alert.textFields[1].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![newName isEqualToString:curName]) pkcSetVoiceName(vid, newName);
        if (![newDesc isEqualToString:curDesc]) pkcSetVoiceDesc(vid, newDesc);
        w.groups = pkcVoiceGroups();
        [w.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        if (w.onDeleted) w.onDeleted();
        pkcToast(@"已保存");
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}

@end








static __strong CMessageWrap *pkcLongPressedWrap = nil;

@interface MMMenuController : NSObject
- (void)setMenuItems:(NSArray *)items;
- (void)setTargetView:(UIView *)view;
@end

@interface BaseMessageCellView : UIView
@end

%hook MMMenuController
- (void)setMenuItems:(NSArray *)items {
    NSMutableArray *arr = [items mutableCopy] ?: [NSMutableArray array];
    BOOL has = NO;
    for (UIMenuItem *it in arr) {
        if ([it isKindOfClass:[UIMenuItem class]] && [it.title isEqualToString:@"转语音"]) { has = YES; break; }
    }
    if (!has) {
        [arr addObject:[[UIMenuItem alloc] initWithTitle:@"转语音" action:@selector(pkcTransToVoice:)]];
    }
    %orig(arr);
}
- (void)setTargetView:(UIView *)view {
    %orig;
    pkcLongPressedWrap = nil;
    UIView *v = view;
    while (v) {
        CMessageWrap *w = nil;
        if ([v respondsToSelector:@selector(messageWrap)])     { @try { w = [v messageWrap]; }     @catch (id e) { w = nil; } }
        if (!w && [v respondsToSelector:@selector(m_messageWrap)]) { @try { w = [v m_messageWrap]; } @catch (id e) { w = nil; } }
        if (w) { pkcLongPressedWrap = w; break; }
        v = v.superview ?: (UIView *)[v nextResponder];
        if (!v) break;
    }
}
%end

%hook BaseMessageCellView
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(pkcTransToVoice:)) return YES;
    return %orig;
}
- (void)pkcTransToVoice:(id)sender {
    CMessageWrap *wrap = pkcLongPressedWrap;
    if (!wrap) { pkcToast(@"未获取到消息内容"); return; }
    if (wrap.m_uiMessageType == 1 && wrap.m_nsContent.length) {
        
        BOOL isSender = [objc_getClass("CMessageWrap") isSenderFromMsgWrap:wrap];
        NSString *toUser = (isSender ? wrap.m_nsToUsr : wrap.m_nsFromUsr) ?: wrap.m_nsToUsr ?: @"";
        pkcConvertAndSend(wrap.m_nsContent, toUser);
    } else {
        pkcToast(@"仅支持文字消息转语音");
    }
}
%end



%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD文字转语音"
                                                      version:@"1.1.0"
                                                   controller:@"DDTextToVoiceSettingsViewController"];
        }
    }
}
