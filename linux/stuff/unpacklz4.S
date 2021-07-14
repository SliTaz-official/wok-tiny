// objdump -D -b binary -mi386 -Maddr16,data16 mbr

	.code16
	.org	0

// LZ4 LZSA1 LZSA2 or LZMA
#define COMPRESSION_LZ4
#define HOLE		0x4000
#define DS_OFS		0x0200

start:
	cld
#define packed_moved	HOLE+0x200+packed
	movw	$packed_moved-next, %di
	xorw	%si, %si
	movw	%di, %cx
	pushw	%ds
	popw	%es
	rep movsb %ds:(%si), %es:(%di)	// move setup
	pushw	%cs			// CS
	pushw	%cx			// IP = 0
	//pushaw
	call	packed_moved
next:
	popw	%bx
	leaw	DS_OFS+start-next(%bx), %di
	leaw	DS_OFS+packed-next(%bx,%si), %si
#if  defined(COMPRESSION_LZMA)
	call	unlzma
#elif defined(COMPRESSION_LZSA2)
	call	unlzsa2
#elif defined(COMPRESSION_LZSA1)
	call	unlzsa1
#else

#define ARCHIVE_MAGICNUMBER	0x184C2102
#define NEGATIVE_OFFSETS	0	// non standard hack
#define LENGTH_16BITS		0	// non standard hack
#define BYTE_RLE		0

lz4main:
	lodsl				// get chunkSize
	//cmpl	$ARCHIVE_MAGICNUMBER, %eax
	//je	lz4main
	//lodsw
	addw	%si, %ax
	xchgw	%ax, %dx
	//lodsw
	jmp	lz4chunk		// %cx = 0

lz4len:					// get length in %cx
	andw	$0xF, %ax
	cmpb	$0xF, %al
	xchgw	%ax, %cx
	jne	lz4quit
lz4len2:
	lodsb
	addw	%ax, %cx
	cmpb	$0xFF, %al
#if LENGTH_16BITS
	jne	lz4quit
	lodsw
	addw	%ax, %cx
#else
	je	lz4len2
#endif
lz4quit:
	ret

#if BYTE_RLE
	movb	-1(%di), %al
	rep stosb %es:(%di)		// fill string
	jmp	lz4chunk
#endif

lz4string:
	lodsw				// get string offset
	xchgw	%ax, %bx
	call	lz4len			// get string length
	add	$4, %cx			// minimum match is 4
#if BYTE_RLE
	decw	%bx
	jz	lz4rle
# if NEGATIVE_OFFSETS
	incw	%bx
# else
	notw	%bx
# endif
#endif
	pushw	%si
#if NEGATIVE_OFFSETS || BYTE_RLE
	leaw	(%bx,%di), %si
#else
	movw	%di, %si
	subw	%bx, %si
#endif
#ifdef USE_MOVSW
# if NEGATIVE_OFFSETS || BYTE_RLE
	cmpw	$-2, %bx
	jb	lzs4_move_words
# else
	cmpw	$2, %bx
	ja	lzs4_move_words
# endif
	lodsw	%es:(%si)
	je	lzs4_store_word	
	movb	%al, %ah
lzs4_store_word:
	shrw	$1, %cx
	rep stosw %es:(%di)
	adcw	%cx, %cx
	rep stosb %es:(%di)
lzs4_move_words:
	shrw	$1, %cx
	rep movsw %es:(%si), %es:(%di)
	adcw	%cx, %cx
#endif
	rep movsb %es:(%si), %es:(%di)	// copy string
	popw	%si

lz4chunk:				// uncompress chunk
	lodsb				// get token
	movb	%al, %bl
	shrb	$4, %al
	call	lz4len			// get literal length
#ifdef USE_MOVSW
	shrw	$1, %cx
	rep movsw %ds:(%si), %es:(%di)
	adcw	%cx, %cx
#endif
	rep movsb %ds:(%si), %es:(%di)	// copy literals
	cmpw	%dx, %si
	jb	lz4string
#endif
done:
	movw	$0x020E, %di
	movsw				// version string
	movw	$0x01F1, %di
	movsb				// setup size
	//popaw
	retf

#if  defined(COMPRESSION_LZMA)
#define FLAT16		1
#define FLAT16OUT	1
#define NO_LZMA_HEADER	1
unlzma:
#include "unlzma.S"
#elif defined(COMPRESSION_LZSA2)
unlzsa2:
#include "unlzsa2.S"
#elif defined(COMPRESSION_LZSA1)
unlzsa1:
#include "unlzsa1.S"
#endif

packed:
