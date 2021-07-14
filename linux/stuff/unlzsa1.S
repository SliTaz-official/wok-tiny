//  based on
//  decompress_small.S - space-efficient decompressor implementation for 8088
//
//  Copyright (C) 2019 Emmanuel Marty
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source distribution.

//  ---------------------------------------------------------------------------
//  Decompress raw LZSA1 block
//  inputs:
//  * %ds:%si: raw LZSA1 block
//  * %es:%di: output buffer
//  ---------------------------------------------------------------------------

	.code16
lzsa1_decompress:
	//pushw	%di		// remember decompression offset
	//cld			// make string operations (lods, movs, stos..) move forward

lzsa1_decode_token:
	xorb	%ah, %ah	// clear %ah
	lodsb			// read token byte: O|LLL|MMMM
	movw	%ax,%bx		// keep token in %bl
	
	andb	$0x70, %al	// isolate literals length in token (LLL)
	je	lzsa1_check_offset_size	// if LLL=0, we have no literals; goto match
#ifdef ONLY8086
	movb	$4, %cl
	shrb	%cl, %al	// shift literals length into place
#else
	shrb	$4, %al		// shift literals length into place
#endif

	cmpb	$7, %al		// LITERALS_RUN_LEN?
	jne	lzsa1_got_literals	// no, we have the full literals count from the token, go copy

	lodsb                   // grab extra length byte
	addb	$7, %al		// add LITERALS_RUN_LEN
	jnc	lzsa1_got_literals	// if no overflow, we have the full literals count, go copy
	je	lzsa1_big_literals

	movb	$1, %ah		// add 256 (I'd prefer 'xchgb %al, %ah'	max 1791 instead of 511)
	lodsb			// grab single extra length byte
	.byte	0x3C		// mask lodsw with cmpb $0xAD, %al
				// (*like jmp short lzsa1_got_literals but faster)

lzsa1_big_literals:
	lodsw			// grab 16-bit extra length

lzsa1_got_literals:
	xchgw	%ax, %cx
#ifdef USE_MOVSW
	shrw	$1, %cx
	rep movsw
	adcw	%cx, %cx
#endif
	rep movsb		// copy %cx literals from %ds:%si to %es:%di

lzsa1_check_offset_size:
	testb	%bl, %bl	// check match offset size in token (O bit)
	js	lzsa1_get_long_offset

	decw	%cx
	xchgw	%ax, %cx	// %ah to 0xff - %cx was zero from the rep movsb above
	lodsb
	.byte	0x3C		// mask lodsw with cmpb $0xAD, %al
				// (*like jmp short lzsa1_get_match_length but faster)

lzsa1_get_long_offset:
	lodsw			// Get 2-byte match offset

lzsa1_get_match_length:
	xchgw	%ax, %bx	// %bx: match offset  %ax: original token
	andb	$0xF, %al	// isolate match length in token (MMMM)
	addb	$3, %al		// add MIN_MATCH_SIZE

	cmpb	$0x12, %al	// MATCH_RUN_LEN?
	jne	lzsa1_got_matchlen	// no, we have the full match length from the token, go copy

	lodsb			// grab extra length byte
	addb	$0x12, %al	// add MIN_MATCH_SIZE + MATCH_RUN_LEN
	jnc	lzsa1_got_matchlen	// if no overflow, we have the entire length
	je	lzsa1_big_matchlen       

	movb	$1, %ah		// add 256 (I'd prefer 'xchgb %al, %ah'	max 3071 instead of 511)
	lodsb			// grab single extra length byte
	.byte	0x3C		// mask lodsw with cmpb $0xAD, %al
				// (*like jmp short lzsa1_got_matchlen but faster)
lzsa1_big_matchlen:
	lodsw			// grab 16-bit length

lzsa1_got_matchlen:
	xchgw	%ax, %cx	// copy match length into %cx
	jcxz	lzsa1_done_decompressing	// bail if we hit EOD
	xchgw	%ax, %si	// save %si (current pointer to compressed data)
	leaw	(%bx,%di), %si	// %es:%si now points at back reference in output data
#ifdef USE_MOVSW
	cmpw	$-2, %bx
	jae	lzsa1_store
	shrw	$1, %cx
	rep movsw %es:(%si), %es:(%di)
	adcw	%cx, %cx
#endif
	rep movsb %es:(%si), %es:(%di)		// copy match
	xchgw	%ax, %si	// restore %ds:%si
	jmp	lzsa1_decode_token	// go decode another token
#ifdef USE_MOVSW
lzsa1_store:
	je	lzsa1_store_word
	lodsb	%es:(%si)
	movb	%al, %ah	
	.byte	0x3D		// mask lodsw with cmpb $0x26AD, %ax
				// (*like jmp short lzsa1_store_byte but faster)
lzsa1_store_word:
	lodsw	%es:(%si)
lzsa1_store_byte:
	shrw	$1, %cx
	rep	stosw
	adcw	%cx, %cx
	rep	stosb
	xchgw	%ax, %si	// restore %ds:%si
	jmp	lzsa1_decode_token	// go decode another token
#endif

lzsa1_done_decompressing:
//	popw	%ax		// retrieve the original decompression offset
//	xchgw	%ax, %di	// compute decompressed size
//	subw	%di, %ax
	ret			// done
