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
//  Decompress raw LZSA2 block
//  inputs:
//  * %ds:%si: raw LZSA2 block
//  * %es:%di: output buffer
//  ---------------------------------------------------------------------------

	.code16
lzsa2_decompress:
	//pushw	%di		// remember decompression offset
	//cld			// make string operations (lods, movs, stos..) move forward

	xorw	%cx, %cx
	movw	$0x100, %bx
	xorw	%bp, %bp

lzsa2_decode_token:
	movw	%cx, %ax	// clear %ah - %cx is zero from above or from after rep movsb in lzsa2_copy_match
	lodsb			// read token byte: XYZ|LL|MMMM
	movw	%ax,%dx		// keep token in %dl
	
	andb	$0x18, %al	// isolate literals length in token (LL)
#ifdef ONLY8086
	movb	$3, %cl
	shrb	%cl, %al	// shift literals length into place
#else
	shrb	$3, %al		// shift literals length into place
#endif

	cmpb	$3, %al		// LITERALS_RUN_LEN_V2?
	jne	lzsa2_got_literals	// no, we have the full literals count from the token, go copy

	call	lzsa2_get_nibble	// get extra literals length nibble
	addb	%cl, %al	// add len from token to nibble 
	cmpb	$0x12, %al      // LITERALS_RUN_LEN_V2 + 15 ?
	jne	lzsa2_got_literals	// if not, we have the full literals count, go copy
	lodsb                   // grab extra length byte
	addb	$0x12, %al	// overflow?
	jnc	lzsa2_got_literals	// if not, we have the full literals count, go copy

	lodsw			// grab 16-bit extra length

lzsa2_got_literals:
	xchgw	%ax, %cx
	rep movsb		// copy %cx literals from %ds:%si to %es:%di

	testb	$0xC0, %dl	// check match offset size in token (X bit)
	js	lzsa2_rep_match_or_large_offset

	//cmpb	$0x40, %dl	// check if this is a 5 or 9-bit offset (Y bit)
				// discovered via the test with bit 6 set
	xchgw	%ax, %cx	// clear %ah - %cx was zero from the rep movsb above
	jne	lzsa2_offset_9_bit

				// 5 bit offset
	cmpb	$0x20, %dl	// test bit 5
	call	lzsa2_get_nibble_x
	jmp	lzsa2_dec_offset_top

lzsa2_offset_9_bit:		// 9 bit offset
	lodsb			// get 8 bit offset from stream in A
	decb	%ah		// set offset bits 15-8 to 1
	testb	$0x20, %dl	// test bit Z (offset bit 8)
	je	lzsa2_get_match_length
lzsa2_dec_offset_top:
	decb	%ah		// clear bit 8 if Z bit is clear
				// or set offset bits 15-8 to 1
	jmp	lzsa2_get_match_length

lzsa2_rep_match_or_large_offset:
	//cmpb	$0xC0, %dl	// check if this is a 13-bit offset or a 16-bit offset/rep match (Y bit)
	jpe	lzsa2_rep_match_or_16_bit

				// 13 bit offset

	cmpb	$0xA0, %dl	// test bit 5 (knowing that bit 7 is also set)
	xchgb	%al, %ah
	call	lzsa2_get_nibble_x
	subb	$2, %al		// substract 512
	jmp	lzsa2_get_match_length_1

lzsa2_rep_match_or_16_bit:
	testb	$0x20, %dl	// test bit Z (offset bit 8)
	jne	lzsa2_repeat_match	// rep-match

				// 16 bit offset
	lodsb			// Get 2-byte match offset

lzsa2_get_match_length_1:
	xchgb	%al, %ah
	lodsb			// load match offset bits 0-7

lzsa2_get_match_length:
	xchgw	%ax, %bp	// %bp: offset
lzsa2_repeat_match:
	xchgw	%ax, %dx	// %ax: original token
	andb	$7, %al		// isolate match length in token (MMM)
	addb	$2, %al		// add MIN_MATCH_SIZE_V2

	cmpb	$9, %al		// MIN_MATCH_SIZE_V2 + MATCH_RUN_LEN_V2?
	jne	lzsa2_got_matchlen	// no, we have the full match length from the token, go copy

	call	lzsa2_get_nibble	// get extra literals length nibble
	addb	%cl, %al	// add len from token to nibble 
	cmpb	$0x18, %al	// MIN_MATCH_SIZE_V2 + MATCH_RUN_LEN_V2 + 15?
	jne	lzsa2_got_matchlen	// no, we have the full match length from the token, go copy

	lodsb			// grab extra length byte
	addb	$0x18, %al	// overflow?
	jnc	lzsa2_got_matchlen	// if not, we have the entire length
	je	lzsa2_done_decompressing	// detect EOD code

	lodsw			// grab 16-bit length

lzsa2_got_matchlen:
	xchgw	%ax, %cx	// copy match length into %cx
	xchgw	%ax, %si	// save %si (current pointer to compressed data)
	leaw	(%bx,%di), %si	// %es:%si now points at back reference in output data
	rep movsb %es:(%si), %es:(%di)		// copy match
	xchgw	%ax, %si	// restore %si
	jmp	lzsa2_decode_token	// go decode another token

//lzsa2_done_decompressing:
//	popw	%ax		// retrieve the original decompression offset
//	xchgw	%ax, %di	// compute decompressed size
//	subw	%di, %ax
//	ret			// done

lzsa2_get_nibble_x:
	cmc			// carry set if bit 4 was set
	rcrb	$1, %al
	call	lzsa2_get_nibble	// get nibble for offset bits 0-3
	orb	%cl, %al	// merge nibble
	rolb	$1, %al
	xorb	$0xE1, %al	// set offset bits 7-5 to 1
lzsa2_done_decompressing:
	ret

lzsa2_get_nibble:
	negb	%bh		// nibble ready?
	jns	lzsa2_has_nibble
	
	xchgw	%ax, %bx
	lodsb			// load two nibbles
	xchgw	%ax, %bx

lzsa2_has_nibble:
#ifdef ONLY8086
	movb	$4, %cl		// swap 4 high and low bits of nibble
	rorb	%cl, %bl
#else
	rorb	$4, %bl
#endif
	movb	$0xF, %cl
	andb	%bl, %cl
	ret
